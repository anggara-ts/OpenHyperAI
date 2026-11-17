#!/usr/bin/env node
// In-game verification tracker for PRs that are not tested in a game yet.
// Data: Util/verify/tracker.json (git-ignored: it is local test state, and it quotes match-log lines).
//
//   node Util/verify.js add <pr>              import the PR's "How to verify in game" list (via gh)
//   node Util/verify.js check <game.log> [--game NNN]
//                                              count each pending item's log tag in a game log
//   node Util/verify.js set <pr> <item|all> <pass|fail|pending|skip> [note...]
//   node Util/verify.js show [pr]             status table; a PR is ready when every item is pass/skip
//   node Util/verify.js done <pr>             drop a merged PR from the tracker
//
// An item's patterns are the backticked parts of its line, e.g. `[OHA-KITE]` or
// `[OHA-RETREAT] over-evasive`. A log line matches a pattern when it contains every word of it
// (words with "=", "...", "/" or "|" are ignored, so `feast result reissues=` matches on the tag and "feast result").
// Seeing a tag is evidence, not proof: the reviewer still sets pass/fail after reading the lines.
"use strict";
const fs = require("fs");
const path = require("path");
const cp = require("child_process");

const DIR = path.join(__dirname, "verify");
const FILE = path.join(DIR, "tracker.json");
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

function parseVerify(body) {
	const lines = body.split(/\r?\n/);
	const start = lines.findIndex((l) => /^##\s+How to verify in game/i.test(l));
	if (start < 0) return [];
	const items = [];
	for (let i = start + 1; i < lines.length; i++) {
		const l = lines[i];
		if (/^##\s/.test(l)) break;
		const m = l.match(/^\s*[-*]\s+(.*)$/);
		if (!m) continue;
		const text = m[1].trim();
		const patterns = [...text.matchAll(/`([^`]+)`/g)].map((x) => x[1]).filter((p) => /\[OHA-/.test(p) || /\w/.test(p));
		items.push({ text, patterns, status: "pending", note: "", seen: {} });
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
	db.prs[j.number] = {
		title: j.title,
		branch: j.headRefName,
		url: j.url,
		added: new Date().toISOString().slice(0, 10),
		items,
	};
	save(db);
	console.log(`PR #${j.number}: ${items.length} item(s) tracked`);
}

function cmdCheck(log, game) {
	const db = load();
	const text = fs.readFileSync(log, "utf8").split(/\r?\n/);
	const g = game || path.basename(log).replace(/\.log$/, "");
	for (const [num, pr] of Object.entries(db.prs)) {
		console.log(`\n#${num} ${pr.title}`);
		pr.items.forEach((it, idx) => {
			if (it.status === "pass" || it.status === "skip") {
				console.log(`  ${idx + 1}. [${it.status}] ${it.text}`);
				return;
			}
			const counts = it.patterns.map((p) => {
				const ws = words(p);
				const hits = ws.length ? text.filter((l) => ws.every((w) => l.includes(w))) : [];
				return { p, n: hits.length, sample: hits.slice(0, 2).map((h) => h.replace(/^.*?\[VScript\]\s*/, "").slice(0, 160)) };
			});
			it.seen[g] = Object.fromEntries(counts.map((c) => [c.p, c.n]));
			const total = counts.reduce((a, c) => a + c.n, 0);
			console.log(`  ${idx + 1}. [${it.status}] ${total ? "SEEN" : "not seen"}  ${it.text}`);
			for (const c of counts) {
				console.log(`       ${c.n.toString().padStart(5)}  ${c.p}`);
				for (const s of c.sample) console.log(`              ${s}`);
			}
		});
	}
	save(db);
}

function cmdSet(pr, which, status, note) {
	const db = load();
	const p = db.prs[pr];
	if (!p) throw new Error(`PR #${pr} not tracked`);
	const idxs = which === "all" ? p.items.map((_, i) => i) : [Number(which) - 1];
	for (const i of idxs) {
		if (!p.items[i]) throw new Error(`no item ${which}`);
		p.items[i].status = status;
		if (note) p.items[i].note = note;
	}
	save(db);
	cmdShow(pr);
}

function cmdShow(only) {
	const db = load();
	for (const [num, pr] of Object.entries(db.prs)) {
		if (only && String(only) !== num) continue;
		const done = pr.items.length > 0 && pr.items.every((i) => i.status === "pass" || i.status === "skip");
		console.log(`#${num} ${done ? "READY TO MERGE" : "testing"}  ${pr.title}  (${pr.branch})`);
		pr.items.forEach((it, idx) => {
			const games = Object.keys(it.seen || {}).join(",");
			console.log(`  ${idx + 1}. [${it.status}] ${it.text}${it.note ? `  -- ${it.note}` : ""}${games ? `  (games: ${games})` : ""}`);
		});
	}
}

function cmdDone(pr) {
	const db = load();
	delete db.prs[pr];
	save(db);
	console.log(`PR #${pr} removed`);
}

const [, , cmd, ...a] = process.argv;
try {
	if (cmd === "add") cmdAdd(a[0]);
	else if (cmd === "check") {
		const gi = a.indexOf("--game");
		cmdCheck(a[0], gi >= 0 ? a[gi + 1] : null);
	} else if (cmd === "set") cmdSet(a[0], a[1], a[2], a.slice(3).join(" "));
	else if (cmd === "show") cmdShow(a[0]);
	else if (cmd === "done") cmdDone(a[0]);
	else {
		console.log(fs.readFileSync(__filename, "utf8").split("\n").slice(1, 17).join("\n"));
		process.exit(1);
	}
} catch (e) {
	console.error(e.message);
	process.exit(1);
}
