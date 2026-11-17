#!/usr/bin/env node
// In-game verification tracker for PRs that are not tested in a game yet.
// Data: Util/verify/tracker.json (git-ignored: it is local test state, and it quotes match-log lines).
//
//   node Util/verify.js add <pr>              import the PR's "How to verify in game" list (via gh); re-adding
//                                              keeps the status/notes of items whose text did not change
//   node Util/verify.js check <game.log> [--game NNN] [--prs 4,5]   (--prs: only the PRs in that game's build;
//                                              Util/after-game.js passes it from git ancestry)
//                                              count each item's log tags in a game log, apply `expect` rules
//   node Util/verify.js set <pr> <item|all> <pass|fail|pending|skip> [note...]   (also ticks the PR checkbox)
//   node Util/verify.js sync [pr...]              tick the "How to verify in game" checkboxes from the tracker
//                                              (set and check do this by themselves)
//   node Util/verify.js expect <pr> <item> "<rules>"   set an item's rules ("none" clears), see below
//   node Util/verify.js heroes <pr> <item> lion,mirana   heroes the item needs on the field ("none" clears)
//   node Util/verify.js show [pr]             status table; a PR is ready when every item is pass/skip
//   node Util/verify.js mute-suggest <pr>     OHA_MUTED entries (FuncLib/systems/global_overrides.lua) for the
//                                              log lines of the PR's passed items
//   node Util/verify.js done <pr>             drop a merged PR from the tracker
//   node Util/verify.js lineup [--suggest [--write]] [--file <general.lua>]
//                                              test lineup in Customize/general.lua: which slots serve a PR still
//                                              in testing (keep) and which can go back to "Random" (free).
//                                              --suggest: put heroes that pending items need into free slots
//                                              (best role by pick rate, Util/role-weights/rows.json); --write edits
//                                              only those lines (parse check: set LUAPARSE=<path to luaparse>)
//
// An item's patterns are the backticked parts of its line, e.g. `[OHA-KITE]` or
// `[OHA-RETREAT] over-evasive`. A log line matches a pattern when it contains every word of it
// (words with "=", "...", "/" or "|" are ignored, so `feast result reissues=` matches on the tag and "feast result").
// Seeing a tag is evidence, not proof: the reviewer still sets pass/fail after reading the lines, unless the
// item has `expect` rules. Rules, joined with ";" (in the PR body: an HTML comment at the end of the bullet,
// `<!-- expect: seen>=1; allyDist<=500 -->`, `<!-- heroes: lion,mirana -->` or `<!-- expect: ...; heroes: ... -->`):
//   seen>=N           at least N matching lines (all patterns together); field rules imply seen>=1
//   absent            no line may match (violation -> fail)
//   key<=X key>=X key==X key!=X key<X key>X
//                     every matched line that has `key=value` must satisfy it (violation -> fail, offenders listed)
// `check` auto-passes a pending item whose rules hold, auto-fails a pending or passed item that breaks one, and
// never touches skip. Items without rules are manual. Items with `heroes` stay pending (never fail) in a game
// where none of those heroes played (`npc_dota_hero_<name>` not in the log).
// Rules see every backticked part of the bullet, so give an item with `absent` or field rules one tagged pattern,
// and only `check` a log from a build that contained the PR (Util/verify/test-build.json `included`): an older
// build trivially passes `absent`. A manual pass on an item with rules is re-checked by the next `check`; to
// override, clear the rule (`expect <pr> <item> none`) or set skip.
"use strict";
const fs = require("fs");
const path = require("path");
const cp = require("child_process");

const DIR = path.join(__dirname, "verify");
const FILE = path.join(DIR, "tracker.json");
const ROOT = path.join(__dirname, "..");
const LINEUP = path.join(ROOT, "Customize", "general.lua");
const OVERRIDES = path.join(ROOT, "FuncLib", "systems", "global_overrides.lua");
const HEROES_TSV = path.join(__dirname, "role-weights", "heroes.tsv");
const ROWS = path.join(__dirname, "role-weights", "rows.json");
const GH = process.env.GH || (process.platform === "win32" ? "C:\\Program Files\\GitHub CLI\\gh.exe" : "gh");

function load() {
	try {
		return JSON.parse(fs.readFileSync(FILE, "utf8"));
	} catch (e) {
		return { prs: {} };
	}
}
function save(db) {
	fs.mkdirSync(DIR, { recursive: true });
	fs.writeFileSync(FILE, JSON.stringify(db, null, 2) + "\n");
}
function gh(args) {
	return cp.execFileSync(GH, args, { encoding: "utf8" });
}
const isReady = (pr) => pr.items.length > 0 && pr.items.every((i) => i.status === "pass" || i.status === "skip");
const stripLog = (l) => l.replace(/^.*?\[VScript\]\s*/, "");

// ---------- heroes ----------

const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
let heroTable;
// short npc name ("keeper_of_the_light") <-> display name ("Keeper of the Light") from heroes.tsv
function heroes() {
	if (heroTable) return heroTable;
	heroTable = { byKey: new Map(), display: new Map() };
	try {
		for (const l of fs.readFileSync(HEROES_TSV, "utf8").split(/\r?\n/)) {
			const [, npc, name] = l.split("\t");
			if (!npc || !name) continue;
			const short = npc.replace(/^npc_dota_hero_/, "");
			heroTable.byKey.set(norm(short), short);
			heroTable.byKey.set(norm(name), short);
			heroTable.display.set(short, name);
		}
	} catch (e) {
		// no table: names are used as given
	}
	return heroTable;
}
function resolveHero(name) {
	const raw = name.trim().replace(/^npc_dota_hero_/, "");
	const short = heroes().byKey.get(norm(raw));
	if (!short && heroes().byKey.size) console.log(`warning: unknown hero "${name}" (not in Util/role-weights/heroes.tsv)`);
	return short || raw.toLowerCase();
}
function parseHeroList(s) {
	return s
		.split(",")
		.map((h) => h.trim())
		.filter(Boolean)
		.map(resolveHero)
		.filter((h, i, all) => all.indexOf(h) === i);
}

// ---------- expect rules ----------

function parseRules(str) {
	const r = { seen: null, absent: false, fields: [] };
	for (const part of (str || "").split(";").map((s) => s.trim()).filter(Boolean)) {
		if (part === "absent") {
			r.absent = true;
			continue;
		}
		const m = part.match(/^([A-Za-z_][\w.]*)\s*(<=|>=|==|!=|<|>)\s*(\S+)$/);
		if (!m) throw new Error(`bad expect rule "${part}" (seen>=N, absent, key<=X, key>=X, key==X, key!=X)`);
		if (m[1] === "seen") {
			if (!/^\d+$/.test(m[3])) throw new Error(`seen needs a number: "${part}"`);
			r.seen = { op: m[2], n: Number(m[3]) };
		} else r.fields.push({ key: m[1], op: m[2], val: m[3] });
	}
	return r;
}
function cmpOp(a, op, b) {
	switch (op) {
		case "<=":
			return a <= b;
		case ">=":
			return a >= b;
		case "==":
			return a === b;
		case "!=":
			return a !== b;
		case "<":
			return a < b;
		case ">":
			return a > b;
	}
	return false;
}
const numeric = (v) => v !== "" && Number.isFinite(Number(v));
// One rule against one value: numbers compare as numbers, ==/!= also compare text.
function holds(value, op, want) {
	if (numeric(want) && numeric(value)) return cmpOp(Number(value), op, Number(want));
	if (op === "==" || op === "!=") return cmpOp(value, op, want);
	return false; // ordering on a non-number
}
// Split a comment-delimited spec ("expect: a; b; heroes: x,y") into rules and heroes.
function splitSpec(body) {
	const rules = [];
	let heroList = null;
	for (const raw of body.replace(/^\s*expect\s*:/i, "").split(";")) {
		const part = raw.trim();
		const h = part.match(/^heroes\s*:\s*(.*)$/i);
		if (h) heroList = parseHeroList(h[1]);
		else if (part) rules.push(part.replace(/^expect\s*:\s*/i, ""));
	}
	return { expect: rules.join("; "), heroes: heroList };
}

// Evaluate an item against one log. Returns { verdict: "pass"|"fail"|null, why: [...], offenders: [...] }.
// matched: [{ n: lineNo, line }] lines matching any pattern; total: hit count over all patterns (as SEEN shows).
function evaluate(it, matched, total, heroesInLog) {
	const out = { verdict: null, why: [], offenders: [] };
	if (it.heroes && it.heroes.length) {
		const present = it.heroes.filter((h) => heroesInLog.has(h));
		if (!present.length) {
			out.why.push(`none of ${it.heroes.join(",")} played: stays pending`);
			out.gated = true;
			return out;
		}
		out.why.push(`heroes in game: ${present.join(",")}`);
	}
	if (!it.expect) return out;
	const r = parseRules(it.expect);
	let violated = false;
	let unproven = false;
	if (r.absent && total > 0) {
		violated = true;
		out.why.push(`absent: ${total} line(s) matched`);
		out.offenders.push(...matched.slice(0, 5));
	}
	for (const f of r.fields) {
		const re = new RegExp(`(?:^|\\s)${f.key.replace(/[.]/g, "\\.")}=(\\S*)`);
		const withKey = matched.map((m) => ({ ...m, v: (m.line.match(re) || [])[1] })).filter((m) => m.v !== undefined);
		const bad = withKey.filter((m) => !holds(m.v, f.op, f.val));
		if (!withKey.length) {
			unproven = true;
			out.why.push(`${f.key}${f.op}${f.val}: no matched line has ${f.key}=`);
		} else if (bad.length) {
			violated = true;
			out.why.push(`${f.key}${f.op}${f.val}: ${bad.length}/${withKey.length} line(s) break it`);
			out.offenders.push(...bad.slice(0, 5));
		} else out.why.push(`${f.key}${f.op}${f.val}: all ${withKey.length} line(s) ok`);
	}
	const seen = r.seen || (r.fields.length ? { op: ">=", n: 1 } : null);
	if (seen) {
		if (cmpOp(total, seen.op, seen.n)) out.why.push(`seen ${total} (${seen.op}${seen.n})`);
		else {
			unproven = true;
			out.why.push(`seen ${total}, want ${seen.op}${seen.n}`);
		}
	}
	if (violated) out.verdict = "fail";
	else if (!unproven && (seen || r.absent)) out.verdict = "pass";
	return out;
}

// ---------- PR body ----------

function parseVerify(body) {
	const lines = body.split(/\r?\n/);
	const start = lines.findIndex((l) => /^##\s+How to verify in game/i.test(l));
	if (start < 0) return [];
	const items = [];
	for (let i = start + 1; i < lines.length; i++) {
		const l = lines[i];
		if (/^##\s/.test(l)) break;
		const m = l.match(/^\s*[-*]\s+(?:\[[ xX]\]\s+)?(.*)$/);
		if (!m) continue;
		let expect = "";
		let heroList = null;
		const text = m[1]
			.replace(/<!--([\s\S]*?)-->/g, (all, inner) => {
				if (!/^\s*(expect|heroes)\s*:/i.test(inner)) return "";
				const s = splitSpec(inner);
				if (s.expect) expect = expect ? `${expect}; ${s.expect}` : s.expect;
				if (s.heroes) heroList = s.heroes;
				return "";
			})
			.trim();
		if (expect) parseRules(expect); // throws on a typo
		const patterns = [...text.matchAll(/`([^`]+)`/g)].map((x) => x[1]).filter((p) => /\[OHA-/.test(p) || /\w/.test(p));
		const item = { text, patterns, status: "pending", note: "", seen: {} };
		if (expect) item.expect = expect;
		if (heroList) item.heroes = heroList;
		items.push(item);
	}
	return items;
}

function words(pattern) {
	return pattern
		.split(/\s+/)
		.filter((w) => w && !/[=|/]|\.\.\./.test(w))
		.map((w) => w.replace(/[(),]/g, ""));
}

function cmdAdd(pr) {
	const j = JSON.parse(gh(["pr", "view", String(pr), "--json", "number,title,headRefName,body,url"]));
	const db = load();
	const items = parseVerify(j.body || "");
	const old = db.prs[j.number];
	let kept = 0;
	if (old) {
		for (const it of items) {
			const o = old.items.find((x) => x.text === it.text);
			if (!o) continue;
			kept++;
			for (const k of ["status", "note", "seen", "samples", "auto"]) if (o[k] !== undefined) it[k] = o[k];
			if (!it.expect && o.expect) it.expect = o.expect;
			if (!it.heroes && o.heroes) it.heroes = o.heroes;
		}
	}
	db.prs[j.number] = {
		title: j.title,
		branch: j.headRefName,
		url: j.url,
		added: (old && old.added) || new Date().toISOString().slice(0, 10),
		items,
	};
	save(db);
	const rules = items.filter((i) => i.expect || i.heroes).length;
	console.log(`PR #${j.number}: ${items.length} item(s) tracked${rules ? `, ${rules} with expect/heroes` : ""}${old ? `, ${kept} kept their status` : ""}`);
}

// ---------- check ----------

function cmdCheck(log, game, only) {
	const db = load();
	const text = fs.readFileSync(log, "utf8").split(/\r?\n/);
	const g = game || path.basename(log).replace(/\.log$/, "");
	const heroesInLog = new Set();
	for (const l of text) for (const m of l.matchAll(/npc_dota_hero_([a-z0-9_]+)/g)) heroesInLog.add(m[1]);
	for (const [num, pr] of Object.entries(db.prs)) {
		// --prs: only PRs that were in the build this log came from. A PR missing from the build must not be
		// auto-passed by an `absent` rule or counted as "not seen".
		if (only && !only.includes(num)) {
			console.log(`\n#${num} ${pr.title}  (not in this game's build: skipped)`);
			continue;
		}
		console.log(`\n#${num} ${pr.title}`);
		pr.items.forEach((it, idx) => {
			const ruled = !!(it.expect || (it.heroes && it.heroes.length));
			if (it.status === "skip" || (it.status === "pass" && !it.expect)) {
				console.log(`  ${idx + 1}. [${it.status}] ${it.text}`);
				return;
			}
			const hitIdx = new Set();
			const counts = it.patterns.map((p) => {
				const ws = words(p);
				const hits = [];
				if (ws.length)
					text.forEach((l, i) => {
						if (ws.every((w) => l.includes(w))) {
							hits.push(i);
							hitIdx.add(i);
						}
					});
				return { p, n: hits.length, sample: hits.slice(0, 2).map((i) => stripLog(text[i]).slice(0, 160)) };
			});
			it.seen[g] = Object.fromEntries(counts.map((c) => [c.p, c.n]));
			it.samples = it.samples || {};
			for (const c of counts) if (c.sample.length) it.samples[c.p] = c.sample[0];
			const total = counts.reduce((a, c) => a + c.n, 0);
			let auto = "";
			if (ruled) {
				const matched = [...hitIdx].sort((a, b) => a - b).map((i) => ({ n: i + 1, line: stripLog(text[i]) }));
				const ev = evaluate(it, matched, total, heroesInLog);
				if (ev.verdict === "pass" && it.status === "pending") {
					it.status = "pass";
					it.auto = g;
					it.note = `auto pass (game ${g}): ${ev.why.join("; ")}`;
					auto = "  -> AUTO PASS";
				} else if (ev.verdict === "fail" && (it.status === "pending" || it.status === "pass")) {
					it.status = "fail";
					it.auto = g;
					it.note = `auto fail (game ${g}): ${ev.why.join("; ")}`;
					auto = "  -> AUTO FAIL";
				}
				it.lastCheck = { game: g, why: ev.why };
				console.log(`  ${idx + 1}. [${it.status}] ${total ? "SEEN" : "not seen"}${auto}  ${it.text}`);
				console.log(`       rules: ${[it.expect, it.heroes && `heroes: ${it.heroes.join(",")}`].filter(Boolean).join("; ")}`);
				for (const w of ev.why) console.log(`         - ${w}`);
				for (const o of ev.offenders) console.log(`         ! L${o.n}: ${o.line.slice(0, 160)}`);
			} else console.log(`  ${idx + 1}. [${it.status}] ${total ? "SEEN" : "not seen"}  ${it.text}`);
			for (const c of counts) {
				console.log(`       ${c.n.toString().padStart(5)}  ${c.p}`);
				for (const s of c.sample) console.log(`              ${s}`);
			}
		});
	}
	save(db);
	for (const num of Object.keys(db.prs)) if (!only || only.includes(num)) syncPrBody(num);
}

// ---------- set / expect / heroes / show / done ----------

function getItem(db, pr, which) {
	const p = db.prs[pr];
	if (!p) throw new Error(`PR #${pr} not tracked`);
	const it = p.items[Number(which) - 1];
	if (!it) throw new Error(`no item ${which} in #${pr}`);
	return it;
}

// The PR description mirrors the tracker: in "How to verify in game", an item that passed or was skipped
// gets [x], the others [ ] (plain bullets become checkboxes). The tracker stays the source of truth;
// GitHub shows the ticked count on the PR. Offline or without gh it only warns.
function syncPrBody(pr) {
	const p = load().prs[pr];
	if (!p) return;
	let body;
	try {
		body = JSON.parse(gh(["pr", "view", String(pr), "--json", "body"])).body || "";
	} catch (e) {
		console.log(`sync #${pr}: could not read the PR (${String(e.message).split("\n")[0]})`);
		return;
	}
	const lines = body.split(/\r?\n/);
	const start = lines.findIndex((l) => /^##\s+How to verify in game/i.test(l));
	if (start < 0) return;
	const parsed = parseVerify(body);
	let k = 0;
	let changed = 0;
	for (let i = start + 1; i < lines.length && k < parsed.length; i++) {
		if (/^##\s/.test(lines[i])) break;
		const m = lines[i].match(/^(\s*[-*]\s+)(?:\[[ xX]\]\s+)?(.*)$/);
		if (!m) continue;
		const item = p.items.find((x) => x.text === parsed[k].text);
		k++;
		const done = !!item && (item.status === "pass" || item.status === "skip");
		const next = `${m[1]}[${done ? "x" : " "}] ${m[2]}`;
		if (next !== lines[i]) {
			lines[i] = next;
			changed++;
		}
	}
	// Ready (every item pass or skip): tick "Tested in a local game (game NNN)", say at the top whether it can
	// merge now or what blocks it, and set the "Ready to merge" label. A PR is blocked by a tracked PR that is
	// not ready and whose own commits are all in this branch (stacked); it must merge first.
	const ready = isReady(p);
	const games = [...new Set(p.items.flatMap((x) => [...String(x.note || "").matchAll(/game (\d{3})/g)].map((m) => m[1])))];
	const gameText = games.length ? `game ${games.join(", ")}` : "game ?";
	for (let i = 0; i < lines.length; i++) {
		const m = lines[i].match(/^(\s*[-*]\s+)\[([ xX])\]\s+Tested in a local game\b.*$/);
		if (!m) continue;
		const next = ready ? `${m[1]}[x] Tested in a local game (${gameText})` : lines[i];
		if (next !== lines[i]) {
			lines[i] = next;
			changed++;
		}
	}
	const MARK = "<!-- oha-merge-status -->";
	let statusLine = "";
	if (ready) {
		const blockers = blockingPrs(pr);
		statusLine = blockers.length
			? `> **Ready to merge, blocked by ${blockers.map((n) => "#" + n).join(", ")}**: every in-game item passed or was skipped (${gameText}), but this branch contains ${blockers.length > 1 ? "their" : "its"} commits and ${blockers.length > 1 ? "they are" : "it is"} not ready yet. It merges right after. ${MARK}`
			: `> **Ready to merge**: every in-game item passed or was skipped (${gameText}). ${MARK}`;
	}
	const at = lines.findIndex((l) => l.includes(MARK));
	if (at >= 0 && lines[at] !== statusLine) {
		if (statusLine) lines[at] = statusLine;
		else lines.splice(at, lines[at + 1] === "" ? 2 : 1);
		changed++;
	} else if (at < 0 && statusLine) {
		lines.unshift(statusLine, "");
		changed++;
	}
	setReadyLabel(pr, ready);
	if (!changed) return;
	try {
		cp.execFileSync(GH, ["pr", "edit", String(pr), "--body-file", "-"], { encoding: "utf8", input: lines.join("\n") });
		console.log(`sync #${pr}: ${changed} checkbox line(s) updated in the PR description`);
	} catch (e) {
		console.log(`sync #${pr}: could not edit the PR (${String(e.message).split("\n")[0]})`);
	}
}

// Tracked PRs that are not ready and whose own (non-merge) commits are all in this PR's branch.
function blockingPrs(pr) {
	const db = load();
	const me = db.prs[pr];
	if (!me || !me.branch) return [];
	const git = (args) => cp.spawnSync("git", args, { cwd: ROOT, encoding: "utf8" });
	const out = [];
	for (const [n, q] of Object.entries(db.prs)) {
		if (n === String(pr) || !q.branch || isReady(q)) continue;
		const own = (git(["rev-list", "--no-merges", `origin/main..origin/${q.branch}`]).stdout || "").split(/\r?\n/).filter(Boolean);
		if (own.length && own.every((c) => git(["merge-base", "--is-ancestor", c, `origin/${me.branch}`]).status === 0)) out.push(n);
	}
	return out;
}

const READY_LABEL = "Ready to merge";
function setReadyLabel(pr, ready) {
	const run = (args) => cp.spawnSync(GH, args, { encoding: "utf8" });
	if (ready) {
		run(["label", "create", READY_LABEL, "--color", "0E8A16", "--description", "Every in-game check passed; merges when nothing blocks it"]);
		run(["pr", "edit", String(pr), "--add-label", READY_LABEL]);
	} else {
		run(["pr", "edit", String(pr), "--remove-label", READY_LABEL]);
	}
}

function cmdSet(pr, which, status, note) {
	const db = load();
	const p = db.prs[pr];
	if (!p) throw new Error(`PR #${pr} not tracked`);
	if (!["pass", "fail", "pending", "skip"].includes(status)) throw new Error(`status must be pass, fail, pending or skip`);
	const idxs = which === "all" ? p.items.map((_, i) => i) : [Number(which) - 1];
	for (const i of idxs) {
		if (!p.items[i]) throw new Error(`no item ${which}`);
		p.items[i].status = status;
		delete p.items[i].auto;
		if (note) p.items[i].note = note;
	}
	save(db);
	syncPrBody(pr);
	cmdShow(pr);
}

function cmdExpect(pr, which, rules) {
	const db = load();
	const it = getItem(db, pr, which);
	if (!rules || /^(none|-)$/i.test(rules.trim())) delete it.expect;
	else {
		const s = splitSpec(rules);
		if (s.expect) {
			parseRules(s.expect);
			it.expect = s.expect;
		} else delete it.expect;
		if (s.heroes) it.heroes = s.heroes;
	}
	save(db);
	console.log(`#${pr} item ${which}: expect ${it.expect || "(none: manual)"}${it.heroes ? `; heroes ${it.heroes.join(",")}` : ""}`);
}

function cmdHeroes(pr, which, list) {
	const db = load();
	const it = getItem(db, pr, which);
	if (!list || /^(none|-)$/i.test(list.trim())) delete it.heroes;
	else it.heroes = parseHeroList(list);
	save(db);
	console.log(`#${pr} item ${which}: heroes ${it.heroes ? it.heroes.join(",") : "(none)"}`);
}

function cmdShow(only) {
	const db = load();
	for (const [num, pr] of Object.entries(db.prs)) {
		if (only && String(only) !== num) continue;
		const done = isReady(pr);
		console.log(`#${num} ${done ? "READY TO MERGE" : "testing"}  ${pr.title}  (${pr.branch})`);
		pr.items.forEach((it, idx) => {
			const games = Object.keys(it.seen || {}).join(",");
			const rules = [it.expect && `expect ${it.expect}`, it.heroes && `heroes ${it.heroes.join(",")}`].filter(Boolean).join("; ");
			console.log(
				`  ${idx + 1}. [${it.status}] ${it.text}${rules ? `  {${rules}}` : ""}${it.note ? `  -- ${it.note}` : ""}${games ? `  (games: ${games})` : ""}`,
			);
		});
		if (done) {
			const tags = [...new Set(muteCandidates(pr).map((c) => `${c.tag}${c.rest ? ` ${c.rest}` : ""}`))];
			if (tags.length) {
				console.log(`  mute suggestion (OHA_MUTED, FuncLib/systems/global_overrides.lua): ${tags.join(", ")}`);
				console.log(`  exact entries: node Util/verify.js mute-suggest ${num}`);
			}
		}
	}
}

function cmdDone(pr) {
	const db = load();
	delete db.prs[pr];
	save(db);
	console.log(`PR #${pr} removed`);
}

// ---------- mute-suggest ----------

const luaEscape = (s) => s.replace(/[\^$()%.[\]*+\-?]/g, "%$&");
// Enough of Lua patterns for OHA_MUTED entries: %-classes, escapes, ".", "-" (lazy), sets, anchors.
function luaToRegex(p) {
	const cls = { a: "A-Za-z", d: "0-9", l: "a-z", s: "\\s", u: "A-Z", w: "A-Za-z0-9", x: "A-Fa-f0-9", p: "!-/:-@\\[-`{-~", c: "\\x00-\\x1f" };
	let out = "";
	for (let i = 0; i < p.length; i++) {
		const c = p[i];
		if (c === "%") {
			const n = p[++i];
			const k = cls[n.toLowerCase()];
			if (k) out += n === n.toLowerCase() ? `[${k}]` : `[^${k}]`;
			else out += n.replace(/[\\^$.*+?()[\]{}|/-]/g, "\\$&");
		} else if (c === "-" && i > 0) out += "*?";
		else if (c === "^" && i === 0) out += "^";
		else if (c === ".") out += "[\\s\\S]";
		else if (c === "[") {
			const j = p.indexOf("]", i + 2);
			out += p.slice(i, j + 1).replace(/%/g, "\\");
			i = j;
		} else if ("*+?".includes(c)) out += c;
		else out += c.replace(/[\\^$.*+?()[\]{}|/-]/g, "\\$&");
	}
	return new RegExp(out);
}

// Patterns of a PR's passed items, with the [OHA-*] tag (a pattern without one inherits the item's previous tag).
function muteCandidates(pr) {
	const out = [];
	pr.items.forEach((it, idx) => {
		if (it.status !== "pass") return;
		let tag = null;
		for (const p of it.patterns) {
			const m = p.match(/\[OHA-[A-Z0-9_]+\]/);
			if (m) tag = m[0];
			if (!tag) continue;
			const tokens = p.replace(tag, "").trim().split(/\s+/).filter(Boolean);
			const cut = tokens.findIndex((t) => /\.\.\.|[/|]/.test(t));
			const rest = (cut < 0 ? tokens : tokens.slice(0, cut)).join(" ");
			// the log matcher ignores key= words, so a matched line may not carry them: also try without
			const eq = tokens.findIndex((t) => t.includes("="));
			const loose = eq >= 0 && (cut < 0 || eq < cut) ? tokens.slice(0, eq).join(" ") : rest;
			out.push({ item: idx + 1, text: it.text, p, tag, rest, loose, sample: it.samples && it.samples[p] });
		}
	});
	return out;
}

function mutedEntries() {
	const src = fs.readFileSync(OVERRIDES, "utf8");
	const m = src.match(/local OHA_MUTED = \{([\s\S]*?)\n\}/);
	if (!m) throw new Error(`OHA_MUTED not found in ${path.relative(ROOT, OVERRIDES)}`);
	return [...m[1].matchAll(/^\s*"((?:[^"\\]|\\.)*)"/gm)].map((x) => x[1]);
}

function cmdMuteSuggest(prNum) {
	const db = load();
	const pr = db.prs[prNum];
	if (!pr) throw new Error(`PR #${prNum} not tracked`);
	if (!isReady(pr)) console.log(`note: #${prNum} is not ready to merge yet; listing its passed items only`);
	const existing = mutedEntries();
	const cands = muteCandidates(pr);
	if (!cands.length) {
		console.log(`#${prNum}: no passed item with an [OHA-*] tag`);
		return;
	}
	console.log(`-- add to OHA_MUTED in FuncLib/systems/global_overrides.lua (PR #${prNum}):`);
	const seen = new Set();
	for (const c of cands) {
		const head = `^${luaEscape(c.tag)}`;
		let pat;
		let how = "";
		if (!c.rest) {
			pat = head;
			how = "  -- WHOLE TAG: mutes every line of it, new ones too";
		}
		else if (c.sample) {
			const forms = [];
			for (const r of new Set([c.rest, c.loose].filter(Boolean)))
				forms.push(`${head} ${luaEscape(r)}`, `${head} t=%S+ ${luaEscape(r)}`, `${head} t=%S+ %S+ ${luaEscape(r)}`, `${head}.-${luaEscape(r)}`);
			pat = forms.find((f) => luaToRegex(f).test(c.sample));
			if (!pat) {
				pat = forms[3]; // the .- form of the full words
				how = "  -- CHECK: does not match the sample line";
			}
		} else {
			pat = `${head}.-${luaEscape(c.rest)}`;
			how = "  -- no sample line (run check on a game log first): generic form";
		}
		if (seen.has(pat)) continue;
		seen.add(pat);
		const same = existing.includes(pat);
		const cover = !same && c.sample && existing.find((e) => luaToRegex(e).test(c.sample));
		const label = `#${prNum}.${c.item} ${c.p}`;
		if (same) console.log(`\t-- already muted: "${pat}" (${label})`);
		else if (cover) console.log(`\t-- already covered by "${cover}" (${label})`);
		else console.log(`\t"${pat}", -- ${label}${how}`);
		if (c.sample) console.log(`\t--   sample: ${c.sample.slice(0, 140)}`);
	}
}

// ---------- lineup ----------

// Slots of Customize.Radiant_Heros / Dire_Heros with their byte offsets in the file. A slot is needed while any
// TEST-tagged number is a tracked PR that is not ready; otherwise it can go back to "Random".
function parseLineup(src, db) {
	const slots = [];
	const lineRe = /[^\n]*\n|[^\n]+$/g;
	const lines = [];
	for (let m; (m = lineRe.exec(src)) && m[0] !== ""; ) {
		const full = m[0];
		const body = full.replace(/\r?\n$/, "");
		lines.push({ start: m.index, end: m.index + body.length, body, eol: full.slice(body.length) });
	}
	for (const side of ["Radiant", "Dire"]) {
		const open = lines.findIndex((l) => new RegExp(`^Customize\\.${side}_Heros\\s*=\\s*\\{`).test(l.body));
		if (open < 0) continue;
		let close = open + 1;
		while (close < lines.length && !/^\}/.test(lines[close].body)) close++;
		const heroLines = lines.slice(open + 1, close).filter((l) => /^\s*"/.test(l.body));
		for (let pos = 1; pos <= 5; pos++) {
			const l = heroLines[pos - 1];
			const slot = { side, pos, line: l, closeAt: lines[close] ? lines[close].start : src.length, eol: (lines[open] || {}).eol || "\n" };
			if (!l) {
				Object.assign(slot, { hero: null, free: true, state: "FREE (not set)" });
				slots.push(slot);
				continue;
			}
			const hero = (l.body.match(/"([^"]+)"/) || [])[1];
			slot.hero = hero === "Random" ? null : hero.replace(/^npc_dota_hero_/, "");
			slot.indent = l.body.match(/^\s*/)[0];
			const tag = l.body.match(/TEST\s+((?:#\d+\s*)+):?\s*(.*)$/);
			if (hero === "Random") Object.assign(slot, { free: true, state: "FREE (Random)" });
			else if (!tag) Object.assign(slot, { free: false, state: `${slot.hero} (no TEST tag)` });
			else {
				const nums = [...tag[1].matchAll(/#(\d+)/g)].map((x) => x[1]);
				const states = nums.map((n) => (db.prs[n] ? `#${n} ${isReady(db.prs[n]) ? "ready" : "testing"}` : `#${n} untracked`));
				const needed = nums.some((n) => db.prs[n] && !isReady(db.prs[n]));
				Object.assign(slot, {
					free: !needed,
					nums,
					state: `${slot.hero}  [${states.join(", ")}]  ${needed ? "keep" : "can free"}  ${tag[2]}`,
				});
			}
			slots.push(slot);
		}
	}
	return slots;
}

function rolePickRates() {
	const rows = JSON.parse(fs.readFileSync(ROWS, "utf8"));
	const byName = new Map(rows.map((r) => [norm(r.name), r]));
	return (short) => {
		const row = byName.get(norm(heroes().display.get(short) || short)) || byName.get(norm(short));
		return row ? row.roles.map((x) => x.pr || 0) : null;
	};
}

function tagLine(indent, hero, pos, needs) {
	const nums = [...new Set(needs.map((n) => Number(n.pr)))].sort((a, b) => a - b).map((n) => `#${n}`);
	const what = needs
		.map((n) => n.text.replace(/`/g, "").replace(/\s+/g, " ").trim())
		.join("; ")
		.slice(0, 140);
	return `${indent}"npc_dota_hero_${hero}", -- pos ${pos} -- TEST ${nums.join(" ")}: ${what}`;
}

function parseCheck(file) {
	let lp;
	try {
		lp = require(process.env.LUAPARSE || "luaparse");
	} catch (e) {
		console.log("parse check skipped: set LUAPARSE=<path to node_modules/luaparse> (or run luajit -b on the file)");
		return true;
	}
	try {
		lp.parse(fs.readFileSync(file, "utf8"), { luaVersion: "LuaJIT" });
		console.log(`parse check: ${path.basename(file)} OK`);
		return true;
	} catch (e) {
		console.log(`parse check FAILED: ${e.message}`);
		return false;
	}
}

function cmdLineup(opts) {
	const db = load();
	const file = opts.file ? path.resolve(opts.file) : LINEUP;
	const src = fs.readFileSync(file, "utf8");
	const slots = parseLineup(src, db);
	for (const side of ["Radiant", "Dire"]) {
		console.log(side);
		for (const s of slots.filter((x) => x.side === side)) console.log(`  pos ${s.pos}: ${s.state}`);
	}
	if (!opts.suggest) return;

	// items still to test that name heroes, from PRs not ready
	const needs = [];
	for (const [num, pr] of Object.entries(db.prs)) {
		if (isReady(pr)) continue;
		pr.items.forEach((it, idx) => {
			if (it.status === "pending" && it.heroes && it.heroes.length) needs.push({ pr: num, item: idx + 1, text: it.text, heroes: it.heroes });
		});
	}
	console.log("\nSuggest");
	if (!needs.length) {
		console.log("  no pending item names heroes (node Util/verify.js heroes <pr> <item> a,b)");
		return;
	}
	const inLineup = new Map(slots.filter((s) => s.hero).map((s) => [s.hero, s]));
	const edits = []; // { slot, hero, needs }
	const open = [];
	for (const n of needs) {
		const here = n.heroes.find((h) => inLineup.has(h));
		if (!here) {
			open.push(n);
			continue;
		}
		const s = inLineup.get(here);
		if (s.free && s.line) {
			// in a slot that could be freed: re-tag it so it stays for this test
			let e = edits.find((x) => x.slot === s);
			if (!e) edits.push((e = { slot: s, hero: here, needs: [], retag: true }));
			e.needs.push(n);
		} else console.log(`  #${n.pr}.${n.item}: ${here} already in the lineup (${s.side} pos ${s.pos})`);
	}
	const reserved = new Set(edits.map((e) => e.slot));
	const pr = rolePickRates();
	const placed = new Map(); // hero -> edit
	for (;;) {
		const pending = open.filter((n) => !n.heroes.some((h) => placed.has(h)));
		if (!pending.length) break;
		let best = null;
		for (const n of pending)
			for (const h of n.heroes) {
				const rates = pr(h);
				for (const s of slots) {
					if (!s.free || reserved.has(s)) continue;
					const score = rates ? rates[s.pos - 1] : 0;
					if (!best || score > best.score) best = { h, s, score };
				}
			}
		if (!best) {
			for (const n of pending) console.log(`  #${n.pr}.${n.item}: no free slot for ${n.heroes.join(" / ")}: wait for the next game`);
			break;
		}
		const e = { slot: best.s, hero: best.h, needs: pending.filter((n) => n.heroes.includes(best.h)), score: best.score };
		edits.push(e);
		reserved.add(best.s);
		placed.set(best.h, e);
	}
	for (const e of edits) {
		e.text = tagLine(e.slot.indent || "\t", e.hero, e.slot.pos, e.needs);
		let why = e.retag ? "re-tag (hero already there)" : `pick rate at pos ${e.slot.pos}: ${e.score}%`;
		const rates = !e.retag && pr(e.hero);
		if (rates && e.score < 5) {
			const top = rates.indexOf(Math.max(...rates)) + 1;
			why += ` (OFF-ROLE: main role is pos ${top} at ${rates[top - 1]}%, no free slot there)`;
		} else if (!e.retag && !rates) why += " (hero not in rows.json)";
		console.log(`  ${e.slot.side} pos ${e.slot.pos} (was ${e.slot.state.replace(/\s+/g, " ").slice(0, 60)}), ${why}:`);
		console.log(`    ${e.text.trim()}`);
	}
	if (!edits.length || !opts.write) {
		if (edits.length) console.log("  (--write puts these lines into the file)");
		return;
	}
	// apply from the end of the file so earlier offsets stay valid; unset slots are appended before "}"
	let out = src;
	const ordered = [...edits].sort((a, b) => (b.slot.line ? b.slot.line.start : b.slot.closeAt) - (a.slot.line ? a.slot.line.start : a.slot.closeAt) || b.slot.pos - a.slot.pos);
	for (const e of ordered) {
		if (e.slot.line) out = out.slice(0, e.slot.line.start) + e.text + out.slice(e.slot.line.end);
		else {
			const sideSlots = slots.filter((s) => s.side === e.slot.side && s.line);
			if (e.slot.pos !== sideSlots.length + 1 + edits.filter((x) => x.slot.side === e.slot.side && !x.slot.line && x.slot.pos < e.slot.pos).length)
				throw new Error(`${e.slot.side} pos ${e.slot.pos}: earlier positions are unset, add them first`);
			out = out.slice(0, e.slot.closeAt) + e.text + e.slot.eol + out.slice(e.slot.closeAt);
		}
	}
	fs.writeFileSync(file, out);
	if (!parseCheck(file)) {
		fs.writeFileSync(file, src);
		throw new Error(`restored ${file}: the edited file did not parse`);
	}
	console.log(`wrote ${edits.length} line(s) to ${path.relative(ROOT, file) || file}`);
}

// ---------- main ----------

function main(argv) {
	const [cmd, ...a] = argv;
	if (cmd === "add") cmdAdd(a[0]);
	else if (cmd === "check") {
		const gi = a.indexOf("--game");
		const pi = a.indexOf("--prs");
		const only = pi >= 0 && a[pi + 1] ? a[pi + 1].split(",").map((x) => x.replace(/^#/, "").trim()).filter(Boolean) : null;
		cmdCheck(a[0], gi >= 0 ? a[gi + 1] : null, only);
	} else if (cmd === "set") cmdSet(a[0], a[1], a[2], a.slice(3).join(" "));
	else if (cmd === "expect") cmdExpect(a[0], a[1], a.slice(2).join(" "));
	else if (cmd === "heroes") cmdHeroes(a[0], a[1], a.slice(2).join(","));
	else if (cmd === "show") cmdShow(a[0]);
	else if (cmd === "sync") for (const n of a.length ? a : Object.keys(load().prs)) syncPrBody(n);
	else if (cmd === "mute-suggest") cmdMuteSuggest(a[0]);
	else if (cmd === "done") cmdDone(a[0]);
	else if (cmd === "lineup") {
		const fi = a.indexOf("--file");
		cmdLineup({ suggest: a.includes("--suggest"), write: a.includes("--write"), file: fi >= 0 ? a[fi + 1] : null });
	} else {
		const head = fs.readFileSync(__filename, "utf8").split(/\r?\n/).slice(1);
		console.log(head.slice(0, head.findIndex((l) => !l.startsWith("//"))).join("\n"));
		process.exit(1);
	}
}

if (require.main === module) {
	try {
		main(process.argv.slice(2));
	} catch (e) {
		console.error(e.message);
		process.exit(1);
	}
}
module.exports = { parseVerify, parseRules, evaluate, splitSpec, luaToRegex, luaEscape, parseLineup };
