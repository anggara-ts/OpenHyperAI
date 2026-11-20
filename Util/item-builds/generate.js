#!/usr/bin/env node
// Whole item builds from match data (#38): every hero's buy list, for every position, rebuilt from Stratz.
//
//   node Util/item-builds/generate.js [hero ...] [--write] [--fetch] [--week YYYY-MM-DD] [--patch 7.41f]
//                                     [--explain] [--report <file.md>]
//
//   (no flag)   dry run: builds every list, prints what would change, writes nothing but status.json
//   --write     rewrites the build blocks in BotsLib/hero_<name>.lua, the sell lists that need a new pair and
//               URN_BUILDS in FuncLib/systems/item_strategy.lua; run StyLua on BotsLib afterwards
//   --fetch     fetches what the cache lacks (STRATZ_TOKEN in the repo's .env; never printed)
//   --week      a day inside the Stratz week to use; the cache remembers its week and refuses another one
//   --explain   prints every decision for the heroes named
//   --report    writes the old-to-new table (for the PR text)
//
// Data: Util/item-builds/cache/raw/ (git-ignored; see lib/data.js). Game facts: items.json (game-items.js).
// Decisions the data must not override: pins.json. What a list looks like and why: lib/build.js.
// What was done per hero and position: status.json (read by Tests/test_item_build_sim.lua).
"use strict";
const fs = require("fs");
const path = require("path");
const Game = require("./lib/game");
const Data = require("./lib/data");
const HeroFile = require("./lib/herofile");
const { makeSim } = require("./lib/sim");
const { makeBuilder } = require("./lib/build");

const ROOT = Game.ROOT;
const argv = process.argv.slice(2);
const flag = (name) => argv.includes(name);
const option = (name) => (argv.indexOf(name) >= 0 ? argv[argv.indexOf(name) + 1] : undefined);
const ONLY = argv.filter((arg, i) => !arg.startsWith("--") && !["--week", "--patch", "--report"].includes(argv[i - 1]));
// Under this many matches a hero/position is noise (the count at minute 0, not Stratz's default minute-35 row).
const MIN_MATCHES = 1000;
const GROUPS = { 1: [2, 3], 2: [1, 3], 3: [2, 1], 4: [5], 5: [4] };
const URN_FAMILY = ["item_urn_of_shadows", "item_spirit_vessel", "item_essence_distiller"];

function weekLabel(week) {
	const date = new Date(week + "T12:00:00Z");
	return `${date.getUTCDate()} ${date.toLocaleString("en-GB", { month: "short", timeZone: "UTC" })} ${date.getUTCFullYear()}`;
}
const thousands = (n) => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
const short = (name) => String(name).replace(/^item_/, "");
// "2_qe" (Invoker's second mid list) is a list of position 2.
const posNumber = (pos) => Number(String(pos)[0]);

async function main() {
	const game = Game.load();
	const sim = makeSim(game);
	const builder = makeBuilder(game, sim);
	const pinFile = JSON.parse(fs.readFileSync(path.join(__dirname, "pins.json"), "utf8"));
	const constants = await Data.constants(flag("--fetch"));
	const known = Data.meta();
	const week = option("--week") || (known && known.week);
	const patch = option("--patch") || (known && known.patch) || "?";
	if (!week) throw new Error("no --week given and the cache has no _meta.json");
	if (known && known.week !== week) throw new Error(`cache/raw holds the week of ${known.week}, not ${week}: move it away, then --fetch`);
	const heroId = new Map(constants.heroes.map((hero) => [hero.shortName, hero]));
	const itemName = new Map(constants.items.map((item) => [item.id, "item_" + item.shortName]));
	const files = fs
		.readdirSync(path.join(ROOT, "BotsLib"))
		.filter((name) => /^hero_[a-z0-9_]+\.lua$/.test(name))
		.map((name) => name.slice(5, -4))
		.filter((hero) => heroId.has(hero) && (!ONLY.length || ONLY.includes(hero)));
	if (flag("--fetch")) {
		const fetched = await Data.fetchMissing(files.map((hero) => heroId.get(hero)), week, patch, (hero) => process.stdout.write(hero + " "));
		console.log(`\nfetched ${fetched} file(s)`);
	}
	const label = `Stratz ${patch}, week of ${weekLabel(week)}`;
	const pinsFor = (hero, pos) => {
		const merged = { reasons: [] };
		for (const pin of pinFile.pins) {
			if (pin.hero !== hero || (pin.pos && !pin.pos.includes(pos))) continue;
			for (const key of ["require", "forbid", "before", "adjacent"]) if (pin[key]) merged[key] = [...(merged[key] || []), ...pin[key]];
			for (const key of ["boots", "start", "next", "keep"]) if (pin[key] !== undefined) merged[key] = pin[key];
			merged.reasons.push(pin.reason);
		}
		return merged;
	};

	const status = { source: label, week, patch, minMatches: MIN_MATCHES, heroes: {} };
	const report = [];
	const urn = {};
	const totals = { data: 0, neighbour: 0, alias: 0, kept: 0 };
	const missingFromGame = new Set();
	let changedFiles = 0;

	for (const hero of files) {
		const filePath = path.join(ROOT, "BotsLib", `hero_${hero}.lua`);
		const source = fs.readFileSync(filePath, "utf8");
		const file = HeroFile.parse(hero, source, game);
		const heroUses = new Set();
		const codeAt = source.indexOf("SetUserHeroInit");
		for (const m of source.slice(Math.max(0, codeAt)).matchAll(/"(item_[a-z0-9_]+)"/g)) heroUses.add(m[1]);
		const heroStatus = (status.heroes[hero] = {});
		const explain = flag("--explain") && ONLY.length > 0;
		const canPair = !!(file.sell && file.sell.plain);
		const oldPairs = file.sell ? file.sell.pairs.filter(([a, b]) => game.items[a] && game.items[b]) : [];
		const positions = Object.keys(file.positions).sort();
		const datas = {};
		for (const pos of positions) datas[pos] = Data.position(hero, posNumber(pos), itemName);
		for (const data of Object.values(datas)) for (const name of Object.keys((data || {}).items || {})) if (!game.items[name]) missingFromGame.add(name);
		const oldEntries = (pos) => {
			const position = file.positions[pos];
			return position.source ? position.source.entries : null;
		};
		const resolve = (entries) => entries.map((entry) => entry.name || (file.variables[entry.variable] || [])[0]).filter(Boolean);

		// What each position does: its own data, a neighbour's, the alias it already is, or the old list.
		const plan = {};
		for (const pos of positions) {
			const position = file.positions[pos];
			const pin = pinsFor(hero, posNumber(pos));
			const own = datas[pos];
			const matches = own ? own.matches : 0;
			const old = oldEntries(pos);
			if (pin.keep) plan[pos] = { status: "kept", reason: pin.reasons.join("; "), matches };
			else if (!old || (position.kind === "block" && position.odd) || (position.source && position.source.odd)) {
				plan[pos] = { status: "kept", reason: "the list is not a plain table the generator can rewrite", matches };
			} else if (matches >= MIN_MATCHES) plan[pos] = { status: "data", matches, from: pos };
			else {
				const neighbour = (GROUPS[pos] || []).filter((other) => datas[other] && datas[other].matches >= MIN_MATCHES && file.positions[other]).sort((a, b) => datas[b].matches - datas[a].matches)[0];
				if (neighbour) plan[pos] = { status: "neighbour", matches, from: String(neighbour) };
				else if (position.kind === "alias") plan[pos] = { status: "alias", matches, to: position.to, reason: `${matches} matches and no position of its group has ${MIN_MATCHES}: follows pos ${position.to} as before` };
				else plan[pos] = { status: "kept", matches, reason: `${matches} matches and no position of its group has ${MIN_MATCHES}` };
			}
		}

		// An alias that ends at a kept list is kept with it.
		for (const pos of positions) {
			let at = pos;
			for (let hop = 0; hop < 5 && plan[at] && plan[at].status === "alias"; hop++) at = plan[at].to;
			if (plan[pos].status === "alias" && (!plan[at] || plan[at].status === "kept")) {
				plan[pos] = { status: "kept", matches: plan[pos].matches, reason: `follows pos ${plan[pos].to} as before, and that list is kept` };
			}
		}

		// Build, sharing one sell list between the positions; a pair that hurts another position is banned and all
		// positions are built again.
		const banned = new Set();
		let built = {};
		let pairs = oldPairs.slice();
		for (let attempt = 0; attempt < 12; attempt++) {
			let restart = false;
			built = {};
			pairs = oldPairs.slice();
			for (const pos of positions) {
				const todo = plan[pos];
				if (todo.status !== "data" && todo.status !== "neighbour") continue;
				if (explain) console.log(`== ${hero} pos ${pos} (${todo.status}, data of pos ${todo.from}, ${datas[todo.from].matches} matches)`);
				const result = builder.build({
					hero,
					pos: posNumber(pos),
					data: datas[todo.from],
					old: oldEntries(pos),
					variables: file.variables,
					pin: pinsFor(hero, posNumber(pos)),
					handPairs: oldPairs,
					waits: game.farm[hero] || [],
					sellPairs: pairs,
					banned,
					canPair,
					heroUses,
					explain,
				});
				if (result.restart) {
					restart = true;
					break;
				}
				for (const pair of result.newPairs) if (!pairs.some((p) => p[0] === pair[0] && p[1] === pair[1])) pairs.push(pair);
				built[pos] = result;
			}
			if (restart) continue;
			// Every finished list again, with the whole sell list and no new pairs.
			let hurt = null;
			for (const pos of positions) {
				const names = built[pos] ? built[pos].entries : plan[pos].status === "alias" && built[plan[pos].to] ? built[plan[pos].to].entries : null;
				if (!names) continue;
				let lists = [[]];
				for (const entry of names) {
					if (!entry.variable) lists.forEach((list) => list.push(entry.name));
					else {
						const fixedNames = new Set(names.map((other) => other.name).filter(Boolean));
						lists = lists.flatMap((list) => (entry.options.length ? entry.options : [null]).map((o) => (o && !fixedNames.has(o) ? [...list, o] : list.slice())));
					}
				}
				for (const list of lists.slice(0, 40)) {
					const check = sim.simulate(list, { pos: posNumber(pos), sellPairs: pairs });
					const bad = check.violations.find((violation) => violation.kind !== "no-op");
					if (!bad) continue;
					const culprit = bad.pair ? pairs.find(([trigger, victim]) => trigger === bad.pair[0] && victim === bad.pair[1]) : undefined;
					hurt = hurt || { pos, bad, culprit };
				}
			}
			if (!hurt) break;
			if (hurt.culprit && !oldPairs.includes(hurt.culprit)) banned.add(`${hurt.culprit[0]}>${hurt.culprit[1]}`);
			else if (hurt.culprit) oldPairs.splice(oldPairs.indexOf(hurt.culprit), 1);
			else {
				if (built[hurt.pos]) {
					built[hurt.pos].ok = false;
					built[hurt.pos].problems.push(`${hurt.bad.kind} at ${hurt.bad.entry}: ${hurt.bad.detail}`);
				} else plan[hurt.pos] = { ...plan[hurt.pos], problem: `${hurt.bad.kind} at ${hurt.bad.entry}: ${hurt.bad.detail}` };
				break;
			}
		}

		// A list that still fails keeps the old one.
		const changes = {};
		const finalNames = {};
		for (const pos of positions) {
			const todo = plan[pos];
			const position = file.positions[pos];
			const old = oldEntries(pos);
			const result = built[pos];
			if (result && !result.ok) {
				plan[pos] = { status: "kept", matches: todo.matches, reason: `the rebuilt list fails the checks: ${result.problems.slice(0, 2).join("; ")}` };
			}
		}
		for (const pos of positions) {
			const todo = plan[pos];
			const position = file.positions[pos];
			const old = oldEntries(pos);
			const result = built[pos];
			const oldNames = old ? resolve(old) : [];
			const info = (heroStatus[pos] = { status: todo.status, matches: todo.matches });
			if (todo.status === "data" || todo.status === "neighbour") {
				const from = datas[todo.from];
				const comment =
					todo.status === "data"
						? [`-- ${label}: pos ${pos}, ${thousands(from.matches)} matches ${HeroFile.MARK}.`]
						: [`-- ${label}: pos ${pos} has ${thousands(todo.matches)} matches, built from pos ${todo.from} (${thousands(from.matches)}) ${HeroFile.MARK}.`];
				const inside = (pinFile.comment_inside || []).includes(`${hero}:${pos}`);
				const entries = result.entries.map((entry) => {
					const before = old.find((o) => (entry.name && o.name === entry.name) || (entry.variable && o.variable === entry.variable));
					return { name: entry.name, variable: entry.variable, comment: before ? before.comment : "", lead: before ? before.lead : [] };
				});
				if (inside && entries.length) entries[0].lead = [...comment, ...entries[0].lead.filter((line) => !line.includes(HeroFile.MARK))];
				// Same list as the neighbour it was built from, and that one stands above it in the file: an alias line.
				const target = todo.status === "neighbour" && built[todo.from] && file.positions[todo.from].open < position.open ? built[todo.from] : null;
				const same = target && JSON.stringify(target.entries.map((e) => e.name || e.variable)) === JSON.stringify(result.entries.map((e) => e.name || e.variable));
				changes[pos] = same && file.style.alias ? { comment: inside ? [] : comment, aliasTo: todo.from } : { comment: inside ? [] : comment, entries };
				info.from = posNumber(todo.from);
				info.fromMatches = from.matches;
				info.notes = result.notes;
				info.dropped = result.dropped;
				info.gaps = result.gaps;
				info.cost = result.cost;
				finalNames[pos] = result.entries;
				// Farm-rule items this list does not buy (it did not buy them before either): the rule's net-worth cap ends the wait.
				// (A random or team pick may still hold one of them; only what every game buys counts here.)
				const bought = new Set(result.entries.flatMap((entry) => (entry.name ? [...sim.closure(entry.name)] : [])));
				const missing = (game.farm[hero] || []).filter((wait) => !wait.listAware && !bought.has(wait.item));
				if (missing.length) info.farmWaitsNotBought = missing.map((wait) => `${wait.item} (until ${wait.cap === null ? "NEVER ENDS" : wait.cap})`);
			} else {
				info.reason = todo.reason;
				if (todo.problem) info.problem = todo.problem;
				if (todo.status === "alias") info.to = Number(todo.to);
			}
			if (/^[0-9]$/.test(pos)) totals[todo.status]++;
			else info.note = "a second list of this position, picked at random in game; not one of the counted position lists";
			if (todo.status === "data" || todo.status === "neighbour") {
				const now = result.entries.map((entry) => entry.name || entry.variable);
				report.push({ hero, pos, status: todo.status, matches: todo.matches, from: todo.from, old: oldNames, now, notes: result.notes, dropped: result.dropped });
			} else {
				const row = { hero, pos, status: todo.status, matches: todo.matches, reason: todo.reason, old: oldNames, now: null, notes: [] };
				if (todo.status === "kept" && todo.matches >= MIN_MATCHES && option("--report")) {
					const idea = builder.build({ hero, pos: posNumber(pos), handPairs: oldPairs, data: datas[pos], old: [], variables: {}, pin: {}, waits: game.farm[hero] || [], sellPairs: oldPairs, banned, canPair: false, heroUses });
					row.proposal = idea.entries.map((entry) => entry.name);
				}
				report.push(row);
			}
		}
		// Urn owners: every position whose final list holds an Urn, a Spirit Vessel or an Essence Distiller.
		for (const pos of positions) {
			let at = pos;
			for (let hop = 0; hop < 5 && !finalNames[at] && plan[at].status === "alias"; hop++) at = plan[at].to;
			const names = finalNames[at] ? finalNames[at].map((entry) => entry.name) : oldEntries(pos) ? resolve(oldEntries(pos)) : null;
			if (names === null) urn[hero] = urn[hero] || "keep";
			else if (names.some((name) => name && [...sim.closure(name)].some((part) => URN_FAMILY.includes(part)))) {
				if (urn[hero] !== "keep" && /^[0-9]$/.test(pos)) (urn[hero] = urn[hero] || []).push(Number(pos));
			}
		}
		// The hand-written pairs stay (minus one that sold what a new list needs); the generator's own follow its marker.
		const ownPairs = pairs.filter((pair) => !oldPairs.includes(pair));
		const handChanged = file.sell && oldPairs.length !== file.sell.pairs.length;
		const rewriteSell = canPair && (ownPairs.length > 0 || file.sell.hasOwn || handChanged);
		const text = HeroFile.render(file, changes, rewriteSell ? { hand: oldPairs, own: ownPairs } : null);
		if (ownPairs.length) heroStatus.sell = ownPairs.map((pair) => pair.join(" > "));
		if (handChanged) heroStatus.sellDropped = file.sell.pairs.filter((pair) => !oldPairs.includes(pair)).map((pair) => pair.join(" > "));
		if (text !== source) {
			changedFiles++;
			if (flag("--write")) fs.writeFileSync(filePath, text);
		}
		if (explain) {
			for (const pos of positions) {
				const row = report.find((r) => r.hero === hero && String(r.pos) === pos);
				console.log(`-- ${hero} pos ${pos}: ${row.status} (${row.matches} matches)${row.reason ? " " + row.reason : ""}`);
				console.log(`   old: ${row.old.map(short).join(" ")}`);
				if (row.now) console.log(`   new: ${row.now.map(short).join(" ")}`);
				if (built[pos]) {
					console.log("   " + built[pos].entries.map((e) => `${short(e.name || e.variable)}@${Math.round(e.minute)}${e.rate ? "/" + Math.round(e.rate * 100) + "%" : ""}${e.reached ? ">" + Math.round(e.reached) : ""}${e.topUp ? "+" : ""}`).join(" "));
					for (const note of [...built[pos].notes, ...built[pos].dropped.map((d) => "dropped " + d), ...built[pos].gaps]) console.log("   . " + note);
					if (!built[pos].ok) console.log("   FAILED: " + built[pos].problems.join("; "));
				}
			}
			console.log(`   sell: ${pairs.map((pair) => pair.map(short).join(">")).join(", ")}`);
		}
	}

	// URN_BUILDS in item_strategy.lua follows the lists.
	if (!ONLY.length) {
		const strategyPath = path.join(ROOT, "FuncLib", "systems", "item_strategy.lua");
		const strategy = fs.readFileSync(strategyPath, "utf8");
		const start = strategy.indexOf("local URN_BUILDS = {");
		const end = strategy.indexOf("\n}", start);
		const before = {};
		for (const m of strategy.slice(start, end).matchAll(/npc_dota_hero_([a-z_]+) = \{([^}]*)\}/g)) before[m[1]] = m[2].trim();
		const rows = [];
		for (const hero of [...new Set([...Object.keys(before), ...Object.keys(urn)])].sort()) {
			const value = urn[hero] === "keep" || (urn[hero] === undefined && !status.heroes[hero]) ? before[hero] : urn[hero] ? urn[hero].sort().join(", ") : null;
			if (value) rows.push(`\tnpc_dota_hero_${hero} = { ${value} },`);
		}
		const text = strategy.slice(0, start) + "local URN_BUILDS = {\n" + rows.join("\n") + strategy.slice(end);
		status.urn = rows.length;
		if (text !== strategy) {
			changedFiles++;
			if (flag("--write")) fs.writeFileSync(strategyPath, text);
		}
	}

	status.totals = totals;
	if (!ONLY.length) {
		const lines = ["{", `\t"source": ${JSON.stringify(status.source)},`, `\t"week": ${JSON.stringify(week)},`, `\t"patch": ${JSON.stringify(patch)},`, `\t"minMatches": ${MIN_MATCHES},`, `\t"totals": ${JSON.stringify(totals)},`, '\t"heroes": {'];
		const heroes = Object.keys(status.heroes).sort();
		heroes.forEach((hero, i) => {
			lines.push(`\t\t${JSON.stringify(hero)}: {`);
			const keys = Object.keys(status.heroes[hero]);
			keys.forEach((key, j) => lines.push(`\t\t\t${JSON.stringify(key)}: ${JSON.stringify(status.heroes[hero][key])}${j < keys.length - 1 ? "," : ""}`));
			lines.push(`\t\t}${i < heroes.length - 1 ? "," : ""}`);
		});
		lines.push("\t}", "}", "");
		fs.writeFileSync(path.join(__dirname, "status.json"), lines.join("\n"));
	}
	if (option("--report")) {
		const file = option("--report");
		if (/\.json$/.test(file)) fs.writeFileSync(file, JSON.stringify(report));
		else {
			const out = [`Source: ${label}. Lists: ${JSON.stringify(totals)}.`, "", "| Hero | Pos | Matches | How | Before | Now |", "|---|---|---|---|---|---|"];
			for (const row of report) {
				const how = row.status === "data" ? "data" : row.status === "neighbour" ? `from pos ${row.from}` : row.status === "alias" ? "follows another position" : "kept";
				out.push(`| ${row.hero} | ${row.pos} | ${thousands(row.matches)} | ${how} | ${row.old.map(short).join(", ")} | ${row.now ? row.now.map(short).join(", ") : "unchanged: " + row.reason} |`);
			}
			fs.writeFileSync(file, out.join("\n") + "\n");
		}
	}
	if (Data.unknownIds.size) console.log(`${Data.unknownIds.size} item id(s) in the data are not in the Stratz constants (delete cache/stratz_constants.json and run --fetch): ${[...Data.unknownIds].slice(0, 12).join(", ")}`);
	if (missingFromGame.size) console.log(`items in the data that items.json does not have (run game-items.js on the current items.txt): ${[...missingFromGame].slice(0, 12).join(", ")}`);
	console.log(`${files.length} hero files, lists: ${JSON.stringify(totals)}; ${changedFiles} file(s) ${flag("--write") ? "written" : "would change"}`);
}

main().catch((error) => {
	console.error(error.message);
	process.exit(1);
});
