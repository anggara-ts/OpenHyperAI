#!/usr/bin/env node
// Mode flip-flop report (#165) from a game log's [OHA-FLIP], [OHA-ROAMSTAT] and [OHA-HUNT] lines.
//
//   node Util/flip-report.js <game.log> [<game.log> ...]
//   node Util/flip-report.js --self-test        parses Tests/data/flip_report_sample.txt and checks the totals
//
// [OHA-FLIP] (ability_item_usage_generic.lua, Usage.LogModeFlip): a bot that changed mode 6+ times in 20s while
// moving under 800; lists every mode with its desire and the game second it started, "farm:0.60@123". Since #165 a
// team_roam entry also names the team roam rule that won it: "team_roam:0.50@124(snipe,raw=1.50,cap=push)", or
// "team_roam:0.64@124(hunt-carry/lane)" when uncapped. Older logs have no rule: those steps count as "?".
// [OHA-ROAMSTAT] (mode_team_roam_generic.lua, FuncLib/systems/roam_stats.lua): once per game minute per bot, every
// time team roam became the active mode: by rule, previous / next mode, how long it lasted, the hunt switching
// itself off (huntSelfOff), the cap lifting once team roam runs (capLift) and whether a snipe got a last hit.
// [OHA-HUNT] (FuncLib/systems/hunt_trace.lua): Clinkz / Nyx Assassin / Spirit Breaker from the spell to the hit.
// Prints Markdown. Util/after-game.js puts summary() into the review skeleton.
"use strict";
const fs = require("fs");
const path = require("path");

const FLIP = /\[OHA-FLIP\] t=(-?\d+) (\S+) changes=(\d+) moved=(\d+) .*?enemies=(\d+) modes=(\S+)/;
const ENTRY = /^([a-z_0-9]+):(-?[\d.]+)@(-?\d+)((?:\([^)]*\))*)$/;
const ROAMSTAT = /\[OHA-ROAMSTAT\] t=(-?\d+) (\S+) (min=.*)$/;
const HUNT = /\[OHA-HUNT\] t=(-?\d+) (\S+) (start|mode-change|interrupt|end) ?(.*)$/;
const T_FIELD = /\[OHA-[A-Z0-9_]+\] t=(-?\d+)/;

function fields(text) {
	const o = {};
	for (const m of String(text).matchAll(/(\w+)=(\S+)/g)) o[m[1]] = m[2];
	return o;
}
// "farm:3,push_tower_mid:2" -> { farm: 3, push_tower_mid: 2 }; "farm:2/3" -> { farm: [2, 3] }; "-" -> {}
function countMap(text) {
	const o = {};
	if (!text || text === "-") return o;
	for (const part of text.split(",")) {
		const at = part.lastIndexOf(":");
		if (at < 0) continue;
		const key = part.slice(0, at);
		const val = part.slice(at + 1);
		if (val.includes("/")) {
			const [got, tries] = val.split("/").map(Number);
			o[key] = [got, tries];
		} else o[key] = Number(val);
	}
	return o;
}
function parseEntry(text) {
	const m = text.match(ENTRY);
	if (!m) return null;
	const e = { mode: m[1], des: Number(m[2]), t: Number(m[3]), farmLeft: null, rule: null, raw: null, cap: null };
	for (const note of m[4].match(/\([^)]*\)/g) || []) {
		const inner = note.slice(1, -1);
		if (inner.startsWith("farm-left:")) e.farmLeft = inner.slice(10);
		else {
			const [rule, ...rest] = inner.split(",");
			e.rule = rule;
			for (const kv of rest) {
				const [k, v] = kv.split("=");
				if (k === "raw") e.raw = Number(v);
				if (k === "cap") e.cap = v;
			}
		}
	}
	if (e.mode === "team_roam" && e.rule && e.cap == null) {
		e.cap = "none";
		e.raw = e.des;
	}
	return e;
}

// Lines (strings) -> { flips, roamstats, hunts, tMax, heroes }
function parse(lines) {
	const out = { flips: [], roamstats: [], hunts: [], tMax: 0, heroes: new Set() };
	for (const line of lines) {
		const tm = line.match(T_FIELD);
		if (tm) out.tMax = Math.max(out.tMax, Number(tm[1]));
		let m = line.match(FLIP);
		if (m) {
			const seq = m[6].split(">").map(parseEntry).filter(Boolean);
			out.flips.push({ t: Number(m[1]), hero: m[2], changes: Number(m[3]), moved: Number(m[4]), enemies: Number(m[5]), seq });
			out.heroes.add(m[2]);
			continue;
		}
		m = line.match(ROAMSTAT);
		if (m) {
			const f = fields(m[3]);
			const num = (k) => Number(f[k] || 0);
			const lh = (f.snipeLH || "0/0").split("/").map(Number);
			out.roamstats.push({
				t: Number(m[1]),
				hero: m[2],
				min: num("min"),
				acts: num("acts"),
				byRule: countMap(f.byRule),
				prevMode: countMap(f.prevMode),
				nextMode: countMap(f.nextMode),
				dwell: [num("dwell0"), num("dwell1"), num("dwell2_3"), num("dwell4p")],
				huntToAttack: num("huntToAttack"),
				huntSelfOff: num("huntSelfOff"),
				huntGateOff: num("huntGateOff"),
				huntGone: num("huntGone"),
				capLift: num("capLift"),
				snipeGot: lh[0] || 0,
				snipeTries: lh[1] || 0,
				snipeByPrev: countMap(f.snipeLHbyPrev),
			});
			out.heroes.add(m[2]);
			continue;
		}
		m = line.match(HUNT);
		if (m) out.hunts.push({ t: Number(m[1]), hero: m[2], kind: m[3], ...fields(m[4]) });
	}
	// The flip rate's denominator: the last game second times the bots (at least 10), as #165 measured it, also on
	// new logs (ROAMSTAT lines skip pre-game and partial minutes; they are only the activations' denominator).
	out.botMinutes = (out.tMax / 60) * Math.max(out.heroes.size, 10);
	return out;
}
// Several games' parse() results -> one.
function merge(list) {
	const out = { flips: [], roamstats: [], hunts: [], tMax: 0, heroes: new Set(), botMinutes: 0 };
	for (const p of list) {
		out.flips.push(...p.flips);
		out.roamstats.push(...p.roamstats);
		out.hunts.push(...p.hunts);
		out.tMax = Math.max(out.tMax, p.tMax);
		for (const h of p.heroes) out.heroes.add(h);
		out.botMinutes += p.botMinutes;
	}
	return out;
}

const add = (o, k, n = 1) => (o[k] = (o[k] || 0) + n);
const dwellKey = (d) => (d <= 0 ? "0s" : d <= 1 ? "1s" : d <= 3 ? "2-3s" : ">3s");

function aggregate(p) {
	const a = {
		windows: p.flips.length,
		botMinutes: p.botMinutes,
		pairs: {},
		steps: {},
		dwell: {},
		roamSteps: {},
		roamRule: {},
		annotated: 0,
		roam: null,
		hunts: null,
	};
	for (const f of p.flips) {
		const s = f.seq;
		for (let i = 0; i < s.length; i++) {
			add(a.steps, `${s[i].mode}:${s[i].des.toFixed(2)}`);
			if (i > 0) {
				add(a.pairs, [s[i - 1].mode, s[i].mode].sort().join(" <> "));
				add(a.dwell, dwellKey(s[i].t - s[i - 1].t));
			}
			if (s[i].mode !== "team_roam") continue;
			if (s[i].rule) a.annotated++;
			const rule = s[i].rule || "?";
			const capText = s[i].cap && s[i].cap !== "none" ? ` cap=${s[i].cap} raw=${s[i].raw.toFixed(2)}` : "";
			add(a.roamSteps, `${s[i].des.toFixed(2)} ${rule}${capText}`);
			const r = (a.roamRule[rule] = a.roamRule[rule] || { n: 0, prev: {}, next: {}, dwell: {} });
			r.n++;
			if (i > 0) add(r.prev, s[i - 1].mode);
			if (i < s.length - 1) {
				add(r.next, s[i + 1].mode);
				add(r.dwell, dwellKey(s[i + 1].t - s[i].t));
			}
		}
	}
	if (p.roamstats.length) {
		const r = {
			lines: p.roamstats.length,
			acts: 0,
			byRule: {},
			prevMode: {},
			nextMode: {},
			dwell: [0, 0, 0, 0],
			huntActs: 0,
			huntToAttack: 0,
			huntSelfOff: 0,
			huntGateOff: 0,
			huntGone: 0,
			capLift: 0,
			snipeGot: 0,
			snipeTries: 0,
			snipeByPrev: {},
		};
		for (const s of p.roamstats) {
			r.acts += s.acts;
			for (const [k, v] of Object.entries(s.byRule)) {
				add(r.byRule, k, v);
				if (k.startsWith("hunt-")) r.huntActs += v;
			}
			for (const [k, v] of Object.entries(s.prevMode)) add(r.prevMode, k, v);
			for (const [k, v] of Object.entries(s.nextMode)) add(r.nextMode, k, v);
			s.dwell.forEach((v, i) => (r.dwell[i] += v));
			for (const k of ["huntToAttack", "huntSelfOff", "huntGateOff", "huntGone", "capLift", "snipeGot", "snipeTries"]) r[k] += s[k];
			for (const [k, [got, tries]] of Object.entries(s.snipeByPrev)) {
				const b = (r.snipeByPrev[k] = r.snipeByPrev[k] || [0, 0]);
				b[0] += got;
				b[1] += tries;
			}
		}
		a.roam = r;
	}
	if (p.hunts.length) {
		const h = { byHero: {}, traces: [] };
		const open = {};
		for (const e of p.hunts) {
			const s = (h.byHero[e.hero] = h.byHero[e.hero] || { starts: 0, ends: {}, lasted: 0, ended: 0, changes: 0, snipe: 0, other: 0 });
			if (e.kind === "start") {
				s.starts++;
				open[e.hero] = { hero: e.hero, t: e.t, spell: e.spell, target: e.target, steps: [`start ${e.mode} dist=${e.dist}`] };
				continue;
			}
			const tr = open[e.hero];
			if (e.kind === "mode-change" && tr) tr.steps.push(`${e.to} dist=${e.dist}`);
			if (e.kind === "interrupt" && tr) tr.steps.push(`interrupt by=${e.by} ${e.unit}`);
			if (e.kind === "end") {
				add(s.ends, e.why);
				s.ended++;
				s.lasted += Number(e.lasted || 0);
				s.changes += Number(e.changes || 0);
				s.snipe += Number(e.snipe || 0) > 0 ? 1 : 0;
				s.other += Number(e.other || 0) > 0 ? 1 : 0;
				if (tr) {
					tr.steps.push(`end ${e.why} dist=${e.dist} lasted=${e.lasted}`);
					h.traces.push(tr);
				}
				delete open[e.hero];
			}
		}
		a.hunts = h;
	}
	return a;
}

function pct(n, d) {
	return d ? `${((n / d) * 100).toFixed(0)}%` : "-";
}
function top(o, n, total) {
	const rows = Object.entries(o).sort((x, y) => y[1] - x[1] || (x[0] < y[0] ? -1 : 1));
	return rows
		.slice(0, n)
		.map(([k, v]) => `${k} ${v}${total ? ` (${pct(v, total)})` : ""}`)
		.join(", ");
}
function table(head, rows) {
	return [`| ${head.join(" | ")} |`, `|${head.map(() => "---").join("|")}|`].concat(rows.map((r) => `| ${r.join(" | ")} |`)).join("\n");
}

function render(a) {
	const out = [];
	const per10 = a.botMinutes ? ((a.windows / a.botMinutes) * 10).toFixed(2) : "-";
	out.push(`${a.windows} [OHA-FLIP] windows, ${per10} per 10 bot-minutes (${a.botMinutes.toFixed(0)} bot-minutes).`);
	if (a.windows) {
		out.push("", `Top mode pairs: ${top(a.pairs, 10)}`);
		out.push("", `How long a mode lasted before the next change: ${top(a.dwell, 4)}`);
		out.push("", `Top steps (mode:desire): ${top(a.steps, 12)}`);
		const roamTotal = Object.values(a.roamSteps).reduce((x, y) => x + y, 0);
		out.push("", `team_roam steps by rule (${a.annotated} of ${roamTotal} annotated):`, "");
		out.push(
			table(
				["desire / rule / cap", "steps"],
				Object.entries(a.roamSteps)
					.sort((x, y) => y[1] - x[1])
					.slice(0, 15)
					.map(([k, v]) => [k, v])
			)
		);
		out.push("", "team_roam steps by rule, previous / next mode and dwell:", "");
		out.push(
			table(
				["rule", "steps", "from", "to", "dwell"],
				Object.entries(a.roamRule)
					.sort((x, y) => y[1].n - x[1].n)
					.slice(0, 12)
					.map(([k, r]) => [k, r.n, top(r.prev, 3, r.n), top(r.next, 3, r.n), top(r.dwell, 4)])
			)
		);
	}
	const r = a.roam;
	if (r) {
		out.push("", `[OHA-ROAMSTAT]: ${r.lines} bot-minutes, ${r.acts} team roam activations (${(r.acts / r.lines).toFixed(1)} per bot-minute).`);
		out.push("", `- by rule: ${top(r.byRule, 12, r.acts)}`);
		out.push(`- from: ${top(r.prevMode, 6, r.acts)}`);
		out.push(`- to: ${top(r.nextMode, 6, r.acts)}`);
		const dw = r.dwell.reduce((x, y) => x + y, 0);
		out.push(`- lasted: 0s ${r.dwell[0]} (${pct(r.dwell[0], dw)}), 1s ${r.dwell[1]} (${pct(r.dwell[1], dw)}), 2-3s ${r.dwell[2]} (${pct(r.dwell[2], dw)}), 4s+ ${r.dwell[3]} (${pct(r.dwell[3], dw)})`);
		out.push(
			`- hunt activations ${r.huntActs}: off through the mode gate on the next think with the target still valid (huntSelfOff) ${r.huntSelfOff} (${pct(r.huntSelfOff, r.huntActs)}), gate off at all ${r.huntGateOff} (${pct(r.huntGateOff, r.huntActs)}), target gone ${r.huntGone} (${pct(r.huntGone, r.huntActs)}), handed to attack ${r.huntToAttack} (${pct(r.huntToAttack, r.huntActs)})`
		);
		out.push(`- won capped and uncapped on the next think (capLift): ${r.capLift} (${pct(r.capLift, r.acts)} of activations)`);
		const byPrev = Object.entries(r.snipeByPrev)
			.sort((x, y) => y[1][1] - x[1][1])
			.map(([k, [got, tries]]) => `${k} ${got}/${tries}`)
			.join(", ");
		out.push(`- snipe got a last hit within 1.5s: ${r.snipeGot}/${r.snipeTries} (${pct(r.snipeGot, r.snipeTries)}); by previous mode: ${byPrev || "-"}`);
	} else {
		out.push("", "No [OHA-ROAMSTAT] lines (build before #165's diagnostics).");
	}
	const h = a.hunts;
	if (h) {
		out.push("", "[OHA-HUNT] by hero:", "");
		out.push(
			table(
				["hero", "hunts", "ended", "why", "avg lasted", "mode changes", "with snipe", "with other attack"],
				Object.entries(h.byHero).map(([k, s]) => [
					k,
					s.starts,
					s.ended,
					top(s.ends, 5),
					s.ended ? (s.lasted / s.ended).toFixed(1) + "s" : "-",
					s.changes,
					s.snipe,
					s.other,
				])
			)
		);
		if (h.traces.length) {
			out.push("", "Hunt traces (first 12):", "");
			for (const tr of h.traces.slice(0, 12)) out.push(`- t=${tr.t} ${tr.hero} ${tr.spell} -> ${tr.target}: ${tr.steps.join(" > ")}`);
		}
	} else {
		out.push("", "No [OHA-HUNT] lines (no Clinkz / Nyx Assassin / Spirit Breaker hunt, or a build before #165's diagnostics).");
	}
	return out.join("\n");
}

function summary(lines) {
	return render(aggregate(parse(lines)));
}

function readLines(file) {
	return fs.readFileSync(file, "latin1").split(/\r?\n/);
}

function selfTest() {
	const file = path.join(__dirname, "..", "Tests", "data", "flip_report_sample.txt");
	const p = parse(readLines(file));
	const a = aggregate(p);
	const checks = [
		["FLIP windows", a.windows, 2],
		["annotated team_roam steps", a.annotated, 3],
		["snipe step capped", a.roamSteps["0.50 snipe cap=push raw=1.50"], 1],
		["old-format team_roam step", a.roamSteps["0.64 ?"], 1],
		["pair farm <> team_roam", a.pairs["farm <> team_roam"], 4],
		["ROAMSTAT lines", a.roam && a.roam.lines, 2],
		["activations", a.roam && a.roam.acts, 7],
		["snipe acts", a.roam && a.roam.byRule.snipe, 4],
		["hunt acts", a.roam && a.roam.huntActs, 3],
		["huntSelfOff", a.roam && a.roam.huntSelfOff, 2],
		["capLift", a.roam && a.roam.capLift, 1],
		["snipe tries", a.roam && a.roam.snipeTries, 4],
		["snipe got", a.roam && a.roam.snipeGot, 3],
		["snipe from farm", a.roam && a.roam.snipeByPrev.farm.join("/"), "2/2"],
		["hunts by nyx", a.hunts && a.hunts.byHero.nyx_assassin.starts, 1],
		["nyx end hit", a.hunts && a.hunts.byHero.nyx_assassin.ends.hit, 1],
		["nyx with snipe", a.hunts && a.hunts.byHero.nyx_assassin.snipe, 1],
		["traces", a.hunts && a.hunts.traces.length, 2],
	];
	let failed = 0;
	for (const [name, got, want] of checks) {
		const ok = got === want;
		if (!ok) failed++;
		console.log(`${ok ? "ok  " : "FAIL"} ${name}: ${JSON.stringify(got)}${ok ? "" : ` (want ${JSON.stringify(want)})`}`);
	}
	render(a);
	console.log(failed ? `${failed} failed` : "all passed");
	return failed === 0;
}

if (require.main === module) {
	const args = process.argv.slice(2);
	if (args.includes("--self-test")) process.exit(selfTest() ? 0 : 1);
	if (!args.length) {
		console.error("usage: node Util/flip-report.js <game.log> [...] | --self-test");
		process.exit(2);
	}
	console.log(render(aggregate(merge(args.map((f) => parse(readLines(f)))))));
}
module.exports = { parse, merge, aggregate, render, summary };
