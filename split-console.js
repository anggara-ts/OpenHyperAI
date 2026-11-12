// Split Dota's -condebug logs into one file per game.
//
// Usage:
//   node split-console.js [path\to\dota\game\dota] [--out <dir>]
//
// Once a match gets an ID, Dota stops writing console.log and continues in
// console.<matchid>.log ("Tearing off console log, will continue using suffix").
// console.log itself only holds the menu and signon, so this reads the per-match files.
//
// The bots print these markers (FuncLib/systems/match_trace.lua):
//   [OHA-MATCH] start team=radiant ...   hero selection began
//   [OHA-MATCH] game  team=radiant ... radiant=a,b,c,d,e dire=f,g,h,i,j
//   [OHA-MATCH] end   team=radiant ... winner=dire
//
// Each team prints its own markers, and every bot prints "game", so repeats are normal.
// A new game opens on a start/game marker when no game is open, the open game has
// ended, or that team goes back a phase (start < game < end). Lines before the first
// marker are dropped; lines after "end" stay with that game until the next game opens.
//
// Every run re-reads all the per-match logs and rewrites the game-*.log files.

const fs = require("fs");
const path = require("path");

const DEFAULT_DIR = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\dota 2 beta\\game\\dota";
const MARKER = /\[OHA-MATCH\] (start|game|end) team=(\w+)(.*)$/;
const PHASE_RANK = { start: 0, game: 1, end: 2 };

function parseArgs(argv) {
	let dir = null;
	let out = path.join(__dirname, "match-logs");
	for (let i = 0; i < argv.length; i++) {
		if (argv[i] === "--out") {
			out = path.resolve(argv[++i]);
		} else if (dir === null) {
			dir = path.resolve(argv[i]);
		}
	}
	return { dir: dir || DEFAULT_DIR, out };
}

// console.<matchid>.log, oldest first, so game numbers follow match order.
function matchLogs(dir) {
	return fs
		.readdirSync(dir)
		.filter((name) => /^console\.\d+\.log$/.test(name))
		.map((name) => ({ name, time: fs.statSync(path.join(dir, name)).mtimeMs }))
		.sort((a, b) => a.time - b.time)
		.map((entry) => path.join(dir, entry.name));
}

function field(text, name) {
	const m = text.match(new RegExp("\\b" + name + "=(\\S+)"));
	return m ? m[1] : null;
}

function newGame(number) {
	return { number, lines: [], rank: {}, ended: false, winner: null, version: null, radiant: null, dire: null };
}

async function main() {
	const { dir, out } = parseArgs(process.argv.slice(2));
	const logs = fs.existsSync(dir) ? matchLogs(dir) : [];
	if (logs.length === 0) {
		console.error(`No console.<matchid>.log files in ${dir}`);
		console.error("Pass the folder: node split-console.js <path\\to\\dota\\game\\dota>");
		process.exit(1);
	}
	fs.mkdirSync(out, { recursive: true });
	for (const name of fs.readdirSync(out)) {
		if (/^game-\d+.*\.log$/.test(name)) {
			fs.unlinkSync(path.join(out, name));
		}
	}

	const games = [];
	let current = null;
	const lines = [];
	for (const log of logs) {
		const id = path.basename(log).match(/^console\.(\d+)\.log$/)[1];
		for (const line of fs.readFileSync(log, "utf8").split(/\r?\n/)) {
			lines.push({ line, id });
		}
	}
	for (const { line, id } of lines) {
		const m = line.match(MARKER);
		if (m) {
			const [, phase, team, rest] = m;
			const rank = PHASE_RANK[phase];
			const wentBack = current !== null && current.rank[team] !== undefined && rank < current.rank[team];
			if (phase !== "end" && (current === null || current.ended || wentBack)) {
				current = newGame(games.length + 1);
				games.push(current);
			}
			if (current !== null) {
				current.rank[team] = Math.max(current.rank[team] ?? rank, rank);
				current.matchId = current.matchId || id;
				current.version = current.version || field(rest, "version");
				if (phase === "game") {
					current.radiant = current.radiant || field(rest, "radiant");
					current.dire = current.dire || field(rest, "dire");
				} else if (phase === "end") {
					current.ended = true;
					current.winner = current.winner || field(rest, "winner");
				}
			}
		}
		if (current !== null) {
			current.lines.push(line);
			current.matchId = current.matchId || id;
		}
	}

	const index = [];
	for (const g of games) {
		const num = String(g.number).padStart(3, "0");
		const result = g.ended ? `${g.winner || "unknown"}-win` : "unfinished";
		const file = `game-${num}_${result}.log`;
		fs.writeFileSync(path.join(out, file), g.lines.join("\n") + "\n", "utf8");
		index.push(
			`${file}\tlines=${g.lines.length}\tmatch=${g.matchId || "?"}\tversion=${g.version || "?"}\tradiant=${g.radiant || "?"}\tdire=${g.dire || "?"}`
		);
	}
	fs.writeFileSync(path.join(out, "index.txt"), index.join("\n") + "\n", "utf8");
	console.log(`${games.length} game(s) written to ${out}`);
	for (const row of index) {
		console.log("  " + row);
	}
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
