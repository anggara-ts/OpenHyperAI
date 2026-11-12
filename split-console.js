// Split Dota's -condebug console.log into one file per game.
//
// Usage:
//   node split-console.js [path\to\console.log] [--out <dir>]
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
// console.log keeps growing across games, so every run re-splits the whole file and
// rewrites the game-*.log files in the output folder.

const fs = require("fs");
const path = require("path");
const readline = require("readline");

const DEFAULT_LOG = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\dota 2 beta\\game\\dota\\console.log";
const MARKER = /\[OHA-MATCH\] (start|game|end) team=(\w+)(.*)$/;
const PHASE_RANK = { start: 0, game: 1, end: 2 };

function parseArgs(argv) {
	let input = null;
	let out = path.join(__dirname, "match-logs");
	for (let i = 0; i < argv.length; i++) {
		if (argv[i] === "--out") {
			out = path.resolve(argv[++i]);
		} else if (input === null) {
			input = path.resolve(argv[i]);
		}
	}
	return { input: input || DEFAULT_LOG, out };
}

function field(text, name) {
	const m = text.match(new RegExp("\\b" + name + "=(\\S+)"));
	return m ? m[1] : null;
}

function newGame(number) {
	return { number, lines: [], rank: {}, ended: false, winner: null, version: null, radiant: null, dire: null };
}

async function main() {
	const { input, out } = parseArgs(process.argv.slice(2));
	if (!fs.existsSync(input)) {
		console.error(`console.log not found: ${input}`);
		console.error("Pass the path: node split-console.js <path\\to\\console.log>");
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
	const rl = readline.createInterface({ input: fs.createReadStream(input, "utf8"), crlfDelay: Infinity });
	for await (const line of rl) {
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
		}
	}

	const index = [];
	for (const g of games) {
		const num = String(g.number).padStart(3, "0");
		const result = g.ended ? `${g.winner || "unknown"}-win` : "unfinished";
		const file = `game-${num}_${result}.log`;
		fs.writeFileSync(path.join(out, file), g.lines.join("\n") + "\n", "utf8");
		index.push(
			`${file}\tlines=${g.lines.length}\tversion=${g.version || "?"}\tradiant=${g.radiant || "?"}\tdire=${g.dire || "?"}`
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
