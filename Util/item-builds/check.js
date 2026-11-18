#!/usr/bin/env node
// Item-build second opinion (#38, #9): compares each hero's item lists in BotsLib/hero_<name>.lua with Stratz
// match data, per position.
//
//   node Util/item-builds/check.js [hero ...] [--week YYYY-MM-DD] [--bracket <RankBracketBasicEnum>] [--refresh]
//
// Source: Stratz only (maintainer's decision, 2026-11-18), STRATZ_TOKEN in the repo's .env (see .env.example;
// the token is never printed). Cached in Util/item-builds/cache/ (git-ignored); --refresh refetches.
//   - constants { heroes items }: hero ids, item ids, recipes (their components).
//   - heroStats.itemFullPurchase (with matchLimit: 0), itemBootPurchase and itemStartingPurchase (heroId, positionIds,
//     week, bracketBasicIds):
//     - `week` picks one week's bucket (a unix time inside it); without it Stratz returns the latest week.
//     - `bracketBasicIds` is a rank bracket, e.g. DIVINE_IMMORTAL; without it, all ranks.
//     - matchLimit 0 returns every item: the default hides all but the few most-bought ones (keeper_of_the_light
//       pos 5: 4 items by default, 114 with matchLimit 0).
//     - Rows are per purchase minute (`time`) and per purchase number (`instance`); only the first purchase
//       (instance 0) is counted, so a re-bought item is counted once.
// The report never edits a build. Per hero and position it lists:
//   rare     items in our list that the data barely buys (below 2% of the most-bought item's matches)
//   missing  items the data buys often (top 8, finished items) that our list never buys
//   low-win  common items with a win rate 3+ points under the hero's average: popularity is not proof
// Output: Util/item-builds/report.md and a short summary on the console.
"use strict";
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "..");
const CACHE = path.join(__dirname, "cache");
const argv = process.argv.slice(2);
const REFRESH = argv.includes("--refresh");
const option = (name) => {
	const i = argv.indexOf(name);
	return i >= 0 ? argv[i + 1] : undefined;
};
const WEEK = option("--week");
const BRACKET = option("--bracket");
const ONLY = argv.filter((a, i) => !a.startsWith("--") && !["--week", "--bracket"].includes(argv[i - 1]));
// Consumables, components and wards: never "missing", never "rare".
const IGNORE = /^(tango|clarity|flask|faerie_fire|enchanted_mango|ward_|smoke|dust|tpscroll|blood_grenade|branches|circlet|gauntlets|slippers|mantle|recipe_|famango|great_famango|greater_famango|bottle|aghanims_shard|ultimate_scepter_2|moon_shard|travel_boots_2)/;

try {
	process.loadEnvFile(path.join(ROOT, ".env"));
} catch (e) {
	// no .env: checked below
}
const TOKEN = process.env.STRATZ_TOKEN || "";
if (!TOKEN) {
	console.error("STRATZ_TOKEN is not set: put it in the repo's .env (see .env.example and CONTRIBUTING.md step 6).");
	process.exit(1);
}
let weekArg = "";
if (WEEK) {
	const t = Date.parse(WEEK + "T12:00:00Z");
	if (Number.isNaN(t)) {
		console.error(`--week ${WEEK}: use YYYY-MM-DD`);
		process.exit(1);
	}
	weekArg = `, week: ${Math.floor(t / 1000)}`;
}
if (BRACKET && !/^[A-Z_]+$/.test(BRACKET)) {
	console.error(`--bracket ${BRACKET}: use a RankBracketBasicEnum name, e.g. DIVINE_IMMORTAL`);
	process.exit(1);
}
const bracketArg = BRACKET ? `, bracketBasicIds: [${BRACKET}]` : "";
const filterKey = `${WEEK || "latest"}_${BRACKET || "all"}`;
fs.mkdirSync(CACHE, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function cached(name, fetcher) {
	const file = path.join(CACHE, name + ".json");
	if (!REFRESH && fs.existsSync(file)) return JSON.parse(fs.readFileSync(file, "utf8"));
	const data = await fetcher();
	fs.writeFileSync(file, JSON.stringify(data));
	return data;
}
async function stratz(query) {
	for (let attempt = 0; attempt < 3; attempt++) {
		const r = await fetch("https://api.stratz.com/graphql", {
			method: "POST",
			headers: { "Content-Type": "application/json", Authorization: "Bearer " + TOKEN, "User-Agent": "STRATZ_API" },
			body: JSON.stringify({ query }),
		});
		if (r.status === 429) {
			await sleep(5000);
			continue;
		}
		if (!r.ok) throw new Error(`Stratz: HTTP ${r.status}`);
		const j = await r.json();
		if (j.errors && j.errors.length) throw new Error(`Stratz: ${j.errors[0].message}`);
		return j.data;
	}
	throw new Error("Stratz: rate limited");
}

// Our builds: sRoleItemsBuyList["pos_N"] = { "item_x", ... } (aliases like = sRoleItemsBuyList["pos_1"] resolved).
function readBuilds(file) {
	const src = fs.readFileSync(file, "utf8");
	const lists = {};
	for (const m of src.matchAll(/sRoleItemsBuyList\["pos_(\d)"\]\s*=\s*\{([\s\S]*?)\n\}/g)) {
		lists[m[1]] = [...m[2].matchAll(/"item_([a-z0-9_]+)"/g)].map((x) => x[1]);
	}
	for (const m of src.matchAll(/sRoleItemsBuyList\["pos_(\d)"\]\s*=\s*sRoleItemsBuyList\["pos_(\d)"\]/g)) {
		if (lists[m[2]]) lists[m[1]] = lists[m[2]];
	}
	return lists;
}

async function main() {
	const constants = await cached("stratz_constants", async () => {
		const d = await stratz("{ constants { heroes { id shortName displayName } items { id shortName components { componentId } } } }");
		return d.constants;
	});
	const itemName = new Map(constants.items.map((i) => [i.id, i.shortName]));
	const knownItems = new Set(itemName.values());
	// Components of other items (from the recipes): never "missing", the finished item is what counts.
	const components = new Set();
	for (const it of constants.items) for (const c of it.components || []) if (itemName.has(c.componentId)) components.add(itemName.get(c.componentId));
	// Levels of one item (dagon_2 .. dagon_5) count as that item.
	const base = (n) => n.replace(/_\d$/, "");
	const byName = new Map(constants.heroes.map((h) => [h.shortName, h]));
	const files = fs
		.readdirSync(path.join(ROOT, "BotsLib"))
		.filter((f) => /^hero_[a-z0-9_]+\.lua$/.test(f))
		.map((f) => f.slice(5, -4))
		.filter((n) => !ONLY.length || ONLY.includes(n));
	const out = [
		"# Item-build second opinion",
		"",
		`Generated ${new Date().toISOString().slice(0, 16)}Z by \`node Util/item-builds/check.js\`. Source: Stratz per position, ${WEEK ? `the week of ${WEEK}` : "the latest week"}, ${BRACKET ? BRACKET : "all ranks"}. A second opinion, not a source to copy: check before changing a build (#9, #38).`,
		"",
	];
	let flagged = 0;
	let checked = 0;
	for (const key of files) {
		const hero = byName.get(key);
		if (!hero) continue;
		const lists = readBuilds(path.join(ROOT, "BotsLib", `hero_${key}.lua`));
		if (!Object.keys(lists).length) continue;
		checked++;
		const lines = [];
		for (const [pos, items] of Object.entries(lists).sort()) {
			const st = await cached(`stratz_${filterKey}_${hero.id}_${pos}`, async () => {
				await sleep(400);
				const args = `heroId: ${hero.id}, positionIds: [POSITION_${pos}]${weekArg}${bracketArg}`;
				const d = await stratz(
					`{ heroStats { full: itemFullPurchase(${args}, matchLimit: 0) { itemId matchCount winCount instance } boots: itemBootPurchase(${args}) { itemId matchCount winCount instance } starting: itemStartingPurchase(${args}) { itemId matchCount winCount instance wasGiven } } }`
				);
				const agg = {};
				// Each list: sum the rows of one item and purchase number (full purchases come per minute), keep the
				// lowest purchase number. Boots and starting items are not in the full purchases (Sven pos 1: Quelling
				// Blade and Power Treads 0 there), so an item takes its biggest count over the three lists.
				for (const list of ["full", "boots", "starting"]) {
					const byItem = {};
					for (const r of (d.heroStats && d.heroStats[list]) || []) {
						const name = itemName.get(r.itemId);
						if (!name || r.wasGiven) continue;
						const slot = (byItem[name] = byItem[name] || {});
						const row = (slot[r.instance] = slot[r.instance] || { m: 0, w: 0 });
						row.m += r.matchCount || 0;
						row.w += r.winCount || 0;
					}
					for (const [name, slot] of Object.entries(byItem)) {
						const first = slot[Math.min(...Object.keys(slot).map(Number))];
						if (!agg[name] || first.m > agg[name].m) agg[name] = first;
					}
				}
				return agg;
			});
			const counts = Object.values(st);
			if (!counts.length) {
				lines.push(`- **pos ${pos}** no Stratz data for this position.`);
				continue;
			}
			const stMax = Math.max(1, ...counts.map((a) => a.m));
			const stAvgWin = counts.reduce((s, a) => s + a.w, 0) / Math.max(1, counts.reduce((s, a) => s + a.m, 0));
			const family = (i) => Object.entries(st).filter(([n]) => base(n) === base(i)).reduce((s, [, a]) => s + a.m, 0);
			const ours = [...new Set(items)].filter((i) => !IGNORE.test(i) && knownItems.has(i));
			const rare = ours.filter((i) => family(i) < stMax * 0.02).map((i) => `${i} (${family(i)} of ${stMax})`);
			const ranked = Object.entries(st)
				.map(([n, a]) => [n, a.m])
				.filter(([n]) => !IGNORE.test(n))
				.sort((a, b) => b[1] - a[1]);
			const ourBases = new Set(items.map(base));
			const missing = [...new Set(ranked.filter(([n]) => !components.has(n)).slice(0, 8).map(([n]) => base(n)))].filter((n) => !ourBases.has(n));
			const lowWin = ranked
				.slice(0, 8)
				.filter(([n]) => st[n].m >= 50 && st[n].w / st[n].m < stAvgWin - 0.03)
				.map(([n]) => `${n} ${((st[n].w / st[n].m) * 100).toFixed(0)}%`);
			if (rare.length || missing.length || lowWin.length) {
				flagged++;
				lines.push(`- **pos ${pos}**${rare.length ? ` rare: ${rare.join(", ")}.` : ""}${missing.length ? ` missing: ${missing.join(", ")}.` : ""}${lowWin.length ? ` low-win: ${lowWin.join(", ")}.` : ""}`);
			}
		}
		if (lines.length) out.push(`## ${hero.displayName} (\`${key}\`)`, ...lines, "");
	}
	fs.writeFileSync(path.join(__dirname, "report.md"), out.join("\n") + "\n");
	console.log(`${checked} heroes checked, ${flagged} hero-positions flagged -> Util/item-builds/report.md`);
}
main().catch((e) => {
	console.error(String(e.message || e));
	process.exit(1);
});
