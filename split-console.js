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
// The bots' "end" marker often never prints, so the engine's own end lines also close a
// game: "Building: npc_dota_goodguys_fort destroyed at <t>", "winning_team: ..." and
// "match_outcome: k_EMatchOutcome_...Victory".
//
// Each team prints its own markers, and every bot prints "game", so repeats are normal.
// A new game opens on a start/game marker when no game is open, the open game has
// ended, or that team goes back a phase (start < game < end). Lines before the first
// marker are dropped; lines after "end" stay with that game until the next game opens.
//
// Every run re-reads all the per-match logs and rewrites the game-*.log files.
// Each game also gets a game-NNN_*.summary.txt: buildings lost, deaths, buybacks,
// low-health pushes, kill pushes held for a base threat, base-defense desires
// ([OHA-DEFEND]), Roshan boosts, lotus trips, stuck runes, and grouped script errors.
// The full log stays beside it for a line-level look.

const fs = require("fs");
const path = require("path");

const DEFAULT_DIR = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\dota 2 beta\\game\\dota";
const MARKER = /\[OHA-MATCH\] (start|game|end) team=(\w+)(.*)$/;
const PHASE_RANK = { start: 0, game: 1, end: 2 };
const BUILDING = /Building: npc_dota_(goodguys|badguys)_(\w+) destroyed at (\d+(?:\.\d+)?)/;
const WINNING_TEAM = /winning_team: DOTA_GC_TEAM_(GOOD|BAD)_GUYS/;
const MATCH_OUTCOME = /match_outcome: k_EMatchOutcome_(Rad|Dire)Victory/;

// The engine's end-of-game lines. Returns { winner, t } or null.
function engineEnd(line) {
	let m = line.match(BUILDING);
	if (m && m[2] === "fort") {
		return { winner: m[1] === "goodguys" ? "dire" : "radiant", t: Number(m[3]), by: "fort" };
	}
	m = line.match(WINNING_TEAM);
	if (m) {
		return { winner: m[1] === "GOOD" ? "radiant" : "dire", t: null, by: "winning_team" };
	}
	m = line.match(MATCH_OUTCOME);
	if (m) {
		return { winner: m[1] === "Rad" ? "radiant" : "dire", t: null, by: "match_outcome" };
	}
	return null;
}

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
	return {
		number,
		lines: [],
		rank: {},
		ended: false,
		winner: null,
		endBy: null,
		endClock: null,
		version: null,
		radiant: null,
		dire: null,
	};
}

function vscript(line) {
	const at = line.indexOf("[VScript]");
	if (at < 0) {
		return null;
	}
	return line.slice(at + "[VScript]".length).trim();
}

function clockOf(text) {
	const m = text.match(/\bt=(-?\d+(?:\.\d+)?)/);
	return m ? Number(m[1]) : null;
}

function fmtClock(t) {
	if (t == null || Number.isNaN(t)) {
		return "?";
	}
	const sign = t < 0 ? "-" : "";
	const abs = Math.abs(t);
	const m = Math.floor(abs / 60);
	const s = Math.floor(abs % 60);
	return sign + m + ":" + String(s).padStart(2, "0");
}

function otherTeam(team) {
	return team === "radiant" ? "dire" : "radiant";
}

function parseFight(body) {
	const t = clockOf(body);
	let m = body.match(/\[OHA-FIGHT\] t=[-\d.]+ (\w+) death (\w+) respawn=(\S+) known=(\w+)/);
	if (m) {
		return { kind: "death", t, observer: m[1], hero: m[2], respawn: m[3], known: m[4] };
	}
	m = body.match(/\[OHA-FIGHT\] t=[-\d.]+ (\w+) (buyback|aegis|early-respawn) (\w+) deadFor=(\S+)/);
	if (m) {
		return { kind: m[2], t, observer: m[1], hero: m[3], deadFor: m[4] };
	}
	m = body.match(
		/\[OHA-FIGHT\] t=[-\d.]+ (\w+) push (\w+) lane=(\d+) was=([-\d.]+) floor=([-\d.]+) dead=(\d+) \(([^)]*)\) allies=(\d+) enemies=(\d+) hp=([-\d.]+)/
	);
	if (m) {
		return {
			kind: "push",
			t,
			observer: m[1],
			hero: m[2],
			lane: m[3],
			floor: Number(m[5]),
			dead: m[6],
			names: m[7],
			allies: m[8],
			enemies: m[9],
			hp: Number(m[10]),
		};
	}
	m = body.match(/\[OHA-FIGHT\] t=[-\d.]+ (\w+) push-held (\w+) lane=(\d+) dead=(\d+) \(([^)]*)\) why=(\S+)/);
	if (m) {
		return { kind: "push-held", t, observer: m[1], hero: m[2], lane: m[3], dead: m[4], names: m[5], why: m[6] };
	}
	m = body.match(/\[OHA-FIGHT\] t=[-\d.]+ (\w+) rosh (\w+) was=([-\d.]+) floor=([-\d.]+) dead=(\d+) \(([^)]*)\)/);
	if (m) {
		return { kind: "rosh", t, observer: m[1], hero: m[2], floor: m[4], dead: m[5], names: m[6] };
	}
	return null;
}

function summarize(g) {
	const bodies = [];
	let vscriptCount = 0;
	const tags = {};
	const errors = new Map();
	for (const line of g.lines) {
		const body = vscript(line);
		if (body) {
			vscriptCount++;
			bodies.push(body);
			const tag = body.match(/\[(OHA-[A-Z]+|ROSH|WARN)\]/);
			if (tag) {
				tags[tag[1]] = (tags[tag[1]] || 0) + 1;
			}
		}
		if (/Script Runtime|\[WARN\]|expected hscript|parameter \d+:/.test(line)) {
			const key = (body || line.replace(/^\S+ \S+ /, "")).slice(0, 160);
			errors.set(key, (errors.get(key) || 0) + 1);
		}
	}

	const buildings = [];
	for (const line of g.lines) {
		const m = line.match(BUILDING);
		if (m) {
			buildings.push({ side: m[1] === "goodguys" ? "radiant" : "dire", name: m[2], t: Number(m[3]) });
		}
	}

	const fights = bodies.map(parseFight).filter(Boolean);
	const deaths = fights.filter((f) => f.kind === "death");
	const returns = fights.filter((f) => f.kind === "buyback" || f.kind === "aegis" || f.kind === "early-respawn");
	const pushes = fights.filter((f) => f.kind === "push");
	const roshes = fights.filter((f) => f.kind === "rosh");
	const clocks = bodies.map(clockOf).filter((t) => t != null);
	const t0 = clocks.length ? Math.min(...clocks) : null;
	let t1 = clocks.length ? Math.max(...clocks) : null;
	if (g.endClock != null && (t1 == null || g.endClock > t1)) {
		t1 = g.endClock;
	}

	const out = [];
	out.push(`match ${g.matchId || "?"}`);
	out.push(`version ${g.version || "?"}`);
	out.push(
		`result ${g.ended ? g.winner || "unknown" : "unfinished"}` +
			(g.ended ? `  (from ${g.endBy || "?"}${g.endClock != null ? " at " + fmtClock(g.endClock) : ""})` : "")
	);
	out.push(`radiant ${g.radiant || "?"}`);
	out.push(`dire ${g.dire || "?"}`);
	out.push(`clock ${fmtClock(t0)} .. ${fmtClock(t1)}`);
	out.push(`lines ${g.lines.length}  vscript ${vscriptCount}`);
	out.push(`tags ${Object.entries(tags).map(([k, v]) => k + "=" + v).join(" ") || "none"}`);
	out.push("");

	const bySide = { radiant: {}, dire: {} };
	out.push(`deaths ${deaths.length}`);
	for (const d of deaths) {
		const side = otherTeam(d.observer);
		bySide[side][d.hero] = (bySide[side][d.hero] || 0) + 1;
		out.push(`  ${fmtClock(d.t)}  ${side} ${d.hero}  respawn=${d.respawn} known=${d.known}`);
	}
	for (const side of ["radiant", "dire"]) {
		const rows = Object.entries(bySide[side]);
		const total = rows.reduce((n, [, c]) => n + c, 0);
		out.push(
			`  ${side} total ${total}` +
				(rows.length ? "  " + rows.map(([h, c]) => h + " " + c).join(", ") : "")
		);
	}
	out.push("");

	const lost = { radiant: 0, dire: 0 };
	for (const b of buildings) {
		lost[b.side]++;
	}
	out.push(`buildings ${buildings.length}  radiant lost ${lost.radiant}, dire lost ${lost.dire}`);
	for (const b of buildings) {
		out.push(`  ${fmtClock(b.t)}  ${b.side} ${b.name}`);
	}
	out.push("");

	out.push(`returns ${returns.length}`);
	for (const r of returns) {
		out.push(`  ${fmtClock(r.t)}  ${r.kind} ${otherTeam(r.observer)} ${r.hero}  deadFor=${r.deadFor}`);
	}
	out.push("");

	const waves = [];
	for (const p of pushes) {
		if (p.hp >= 0.5 && p.floor < 0.99) {
			continue;
		}
		const prev = waves[waves.length - 1];
		if (
			prev &&
			prev.observer === p.observer &&
			prev.names === p.names &&
			prev.floor === p.floor &&
			p.t - prev.t1 <= 12
		) {
			prev.t1 = p.t;
			prev.n++;
			if (p.hp < prev.minHp) {
				prev.minHp = p.hp;
				prev.minHero = p.hero;
			}
			continue;
		}
		waves.push({
			observer: p.observer,
			names: p.names,
			floor: p.floor,
			dead: p.dead,
			lane: p.lane,
			allies: p.allies,
			enemies: p.enemies,
			t0: p.t,
			t1: p.t,
			n: 1,
			minHp: p.hp,
			minHero: p.hero,
		});
	}
	out.push(`pushes ${pushes.length}  waves ${waves.length} (hp under 0.50, or floor 0.99, merged per team)`);
	for (const w of waves) {
		const why = w.minHp < 0.5 ? "low-hp" : "multi-kill";
		const range = w.t0 === w.t1 ? fmtClock(w.t0) : `${fmtClock(w.t0)}-${fmtClock(w.t1)}`;
		out.push(
			`  ${range}  ${why}  ${w.observer} floor=${w.floor.toFixed(2)} lane=${w.lane} dead=${w.dead} (${w.names}) allies=${w.allies} enemies=${w.enemies} lowest=${w.minHero} ${w.minHp.toFixed(2)} x${w.n}`
		);
	}
	out.push("");

	// Kill-push floors held back because our own base was being hit.
	const held = [];
	for (const f of fights) {
		if (f.kind !== "push-held") {
			continue;
		}
		const prev = held[held.length - 1];
		if (prev && prev.observer === f.observer && prev.why === f.why && f.t - prev.t1 <= 12) {
			prev.t1 = f.t;
			prev.n++;
			prev.heroes.add(f.hero);
			continue;
		}
		held.push({ observer: f.observer, why: f.why, names: f.names, t0: f.t, t1: f.t, n: 1, heroes: new Set([f.hero]) });
	}
	out.push(`push held for base ${held.reduce((n, h) => n + h.n, 0)}  spans ${held.length}`);
	for (const h of held) {
		const range = h.t0 === h.t1 ? fmtClock(h.t0) : `${fmtClock(h.t0)}-${fmtClock(h.t1)}`;
		out.push(`  ${range}  ${h.observer} why=${h.why} dead=(${h.names}) heroes=${[...h.heroes].join(",")} x${h.n}`);
	}
	out.push("");

	// Base defense: every bot's three lane desires while our base was being hit.
	const defend = bodies.filter((b) => b.includes("[OHA-DEFEND]"));
	out.push(`base defense ${defend.length}`);
	for (const b of defend.slice(0, 80)) {
		out.push(`  ${fmtClock(clockOf(b))}  ${b.replace(/\[OHA-DEFEND\] t=[-\d.]+ /, "")}`);
	}
	if (defend.length > 80) {
		out.push(`  ... ${defend.length - 80} more`);
	}
	out.push("");

	const spans = [];
	for (const r of roshes) {
		const prev = spans[spans.length - 1];
		if (prev && prev.observer === r.observer && prev.names === r.names && prev.floor === r.floor && r.t - prev.t1 <= 20) {
			prev.t1 = r.t;
			prev.n++;
		} else {
			spans.push({ observer: r.observer, names: r.names, floor: r.floor, dead: r.dead, t0: r.t, t1: r.t, n: 1 });
		}
	}
	out.push(`roshan boosts ${roshes.length}  spans ${spans.length}`);
	for (const s of spans) {
		const range = s.t0 === s.t1 ? fmtClock(s.t0) : `${fmtClock(s.t0)}-${fmtClock(s.t1)}`;
		out.push(`  ${range}  ${s.observer} dead=${s.dead} (${s.names}) floor=${s.floor} x${s.n}`);
	}
	out.push("");

	// Purchases: each hero's buy order, plus recipe holds, stray recipes and dropped items.
	const buyOrder = new Map();
	const buyEvents = [];
	for (const b of bodies) {
		const m = b.match(/\[OHA-BUY\] t=[-\d.]+ (\S+) (\S+) (\S+)/);
		if (!m) {
			continue;
		}
		const [, hero, kind, item] = m;
		if (kind === "bought") {
			if (!buyOrder.has(hero)) {
				buyOrder.set(hero, []);
			}
			buyOrder.get(hero).push(item);
		} else {
			buyEvents.push(`  ${fmtClock(clockOf(b))}  ${b.replace(/\[OHA-BUY\] t=[-\d.]+ /, "")}`);
		}
	}
	out.push(`purchases ${[...buyOrder.values()].reduce((n, l) => n + l.length, 0)}  recipe/drop events ${buyEvents.length}`);
	for (const [hero, items] of buyOrder) {
		out.push(`  ${hero}: ${items.slice(0, 40).join(" ")}${items.length > 40 ? " ..." : ""}`);
	}
	out.push(...buyEvents.slice(0, 60));
	if (buyEvents.length > 60) {
		out.push(`  ... ${buyEvents.length - 60} more`);
	}
	out.push("");

	const items = bodies.filter((b) => b.includes("[OHA-ITEM]"));
	out.push(`item swaps ${items.length}`);
	for (const b of items.slice(0, 60)) {
		out.push(`  ${fmtClock(clockOf(b))}  ${b.replace(/\[OHA-ITEM\] t=[-\d.]+ /, "")}`);
	}
	if (items.length > 60) {
		out.push(`  ... ${items.length - 60} more`);
	}
	out.push("");

	// Teleports: reason, from, to, and which lane the target was on vs the bot's lane.
	const tps = bodies.filter((b) => b.includes("[OHA-TP]"));
	out.push(`teleports ${tps.length}`);
	for (const b of tps.slice(0, 80)) {
		out.push(`  ${fmtClock(clockOf(b))}  ${b.replace(/\[OHA-TP\] (t=[-\d.]+ )?/, "")}`);
	}
	if (tps.length > 80) {
		out.push(`  ... ${tps.length - 80} more`);
	}
	out.push("");

	// Tusk escape snowballs (with what triggered each), wave clears and Tag Team.
	const tusk = bodies.filter((b) => b.includes("[OHA-TUSK]"));
	out.push(`tusk ${tusk.length}`);
	for (const b of tusk.slice(0, 40)) {
		out.push(`  ${fmtClock(clockOf(b))}  ${b.replace(/\[OHA-TUSK\] t=[-\d.]+ /, "")}`);
	}
	out.push("");

	// Casts the bots tried but the guard refused: hidden abilities, missing or wrong targets.
	const casts = bodies.filter((b) => b.includes("[OHA-CAST]"));
	out.push(`refused casts ${casts.length}`);
	for (const b of casts.slice(0, 60)) {
		out.push(`  ${fmtClock(clockOf(b))}  ${b.replace(/\[OHA-CAST\] t=[-\d.]+ /, "")}`);
	}
	if (casts.length > 60) {
		out.push(`  ... ${casts.length - 60} more`);
	}
	out.push("");

	// Roshan calls: when each bot's desire turned on or off and why, gather status, commits.
	const rosh = bodies.filter((b) => b.includes("[OHA-ROSH]"));
	out.push(`roshan calls ${rosh.length}`);
	for (const b of rosh.slice(0, 150)) {
		out.push(`  ${fmtClock(clockOf(b))}  ${b.replace(/\[OHA-ROSH\] t=[-\d.]+ /, "")}`);
	}
	if (rosh.length > 150) {
		out.push(`  ... ${rosh.length - 150} more`);
	}
	out.push("");

	const lane = bodies.filter((b) => b.includes("[OHA-LANE]"));
	out.push(`laning ${lane.length}`);
	for (const b of lane.slice(0, 160)) {
		out.push(`  ${fmtClock(clockOf(b))}  ${b.replace(/\[OHA-LANE\] t=[-\d.]+ /, "")}`);
	}
	if (lane.length > 160) {
		out.push(`  ... ${lane.length - 160} more`);
	}
	out.push("");

	const lotus = bodies.filter((b) => b.includes("[OHA-LOTUS]"));
	out.push(`lotus ${lotus.length}`);
	for (const b of lotus) {
		const t = clockOf(b);
		out.push(`  ${fmtClock(t)}  ${b.replace("[OHA-LOTUS] ", "")}`);
	}
	out.push("");

	const stuck = [];
	let runeLines = 0;
	for (const b of bodies) {
		if (!b.includes("[OHA-RUNE]")) {
			continue;
		}
		runeLines++;
		const m = b.match(/\[OHA-RUNE\] (\S+) t=[-\d.]+ .*stuck=(\d+)/);
		const t = clockOf(b);
		if (m && Number(m[2]) > 0 && t != null && t > 0) {
			stuck.push(`  ${fmtClock(t)}  ${m[1]} stuck=${m[2]}  ${b.replace(/\[OHA-RUNE\] \S+ /, "")}`);
		}
	}
	out.push(`runes ${runeLines}  stuck after horn ${stuck.length}`);
	out.push(...stuck.slice(0, 40));
	if (stuck.length > 40) {
		out.push(`  ... ${stuck.length - 40} more`);
	}
	out.push("");

	out.push(`script errors ${[...errors.values()].reduce((n, c) => n + c, 0)}`);
	const ranked = [...errors.entries()].sort((a, b) => b[1] - a[1]);
	for (const [key, count] of ranked.slice(0, 12)) {
		out.push(`  x${count}  ${key}`);
	}
	out.push("");
	return out.join("\n") + "\n";
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
		if (/^game-\d+.*\.(log|summary\.txt)$/.test(name)) {
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
					current.endBy = current.endBy || "bot marker";
				}
			}
		}
		if (current !== null) {
			const end = engineEnd(line);
			if (end) {
				current.ended = true;
				if (!current.winner || current.winner === "unknown") {
					current.winner = end.winner;
				}
				current.endBy = current.endBy || end.by;
				if (end.t != null) {
					current.endClock = end.t;
				}
			}
			current.lines.push(line);
			current.matchId = current.matchId || id;
		}
	}

	const index = [];
	for (const g of games) {
		const num = String(g.number).padStart(3, "0");
		const result = g.ended ? `${g.winner || "unknown"}-win` : "unfinished";
		const file = `game-${num}_${result}.log`;
		const summary = `game-${num}_${result}.summary.txt`;
		fs.writeFileSync(path.join(out, file), g.lines.join("\n") + "\n", "utf8");
		fs.writeFileSync(path.join(out, summary), summarize(g), "utf8");
		index.push(
			`${file}\tlines=${g.lines.length}\tmatch=${g.matchId || "?"}\tversion=${g.version || "?"}\tradiant=${g.radiant || "?"}\tdire=${g.dire || "?"}\tsummary=${summary}`
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
