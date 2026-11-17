#!/usr/bin/env node
// Item-build second opinion (#38): compares each hero's item lists in BotsLib/hero_<name>.lua with match data.
//
//   node Util/item-builds/check.js [hero ...] [--refresh]
//
// Sources (cached in Util/item-builds/cache/, git-ignored; --refresh refetches):
//   - OpenDota  /api/heroes/<id>/itemPopularity : items bought per game stage (no position split). No key needed.
//   - Stratz    heroStats.itemFullPurchase per position (POSITION_1..5): only with STRATZ_TOKEN in the repo's .env
//               (see .env.example; the token is never printed).
//   - Dotabuff blocks scripts; paste data by hand if wanted (not read here).
// The report never edits a build. Per hero and position it lists:
//   rare     items in our list that the data barely buys (below 2% of the most-bought item, in every source we have)
//   missing  items the data buys often (top 8, finished items) that our list never buys
//   low-win  (Stratz) common items with a win rate 3+ points under the hero's average: popularity is not proof
// Output: Util/item-builds/report.md and a short summary on the console.
"use strict";
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "..");
const CACHE = path.join(__dirname, "cache");
const REFRESH = process.argv.includes("--refresh");
const ONLY = process.argv.slice(2).filter((a) => !a.startsWith("--"));
const UA = { "User-Agent": "oha-item-builds" };
// Consumables, components and wards: never "missing", never "rare".
const IGNORE = /^(tango|clarity|flask|faerie_fire|enchanted_mango|ward_|smoke|dust|tpscroll|blood_grenade|branches|circlet|gauntlets|slippers|mantle|recipe_|famango|great_famango|greater_famango|bottle|aghanims_shard|ultimate_scepter_2|moon_shard|travel_boots_2)/;

try {
	process.loadEnvFile(path.join(ROOT, ".env"));
} catch (e) {
	// no .env: OpenDota only
}
fs.mkdirSync(CACHE, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function cached(name, fetcher) {
	const file = path.join(CACHE, name + ".json");
	if (!REFRESH && fs.existsSync(file)) return JSON.parse(fs.readFileSync(file, "utf8"));
	const data = await fetcher();
	fs.writeFileSync(file, JSON.stringify(data));
	return data;
}
async function getJson(url, opts) {
	for (let attempt = 0; attempt < 3; attempt++) {
		const r = await fetch(url, opts);
		if (r.status === 429) {
			await sleep(5000);
			continue;
		}
		if (!r.ok) throw new Error(`${url}: HTTP ${r.status}`);
		return r.json();
	}
	throw new Error(`${url}: rate limited`);
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
	const heroes = await cached("heroes", () => getJson("https://api.opendota.com/api/heroes", { headers: UA }));
	const itemIds = await cached("item_ids", () => getJson("https://api.opendota.com/api/constants/item_ids", { headers: UA }));
	// Components of other items (OpenDota constants): never "missing", the finished item is what counts.
	const itemsConst = await cached("items", () => getJson("https://api.opendota.com/api/constants/items", { headers: UA }));
	const components = new Set();
	for (const it of Object.values(itemsConst)) for (const c of it.components || []) components.add(c);
	// Levels of one item (dagon_2 .. dagon_5) count as that item.
	const base = (n) => n.replace(/_\d$/, "");
	const byName = new Map(heroes.map((h) => [h.name.replace("npc_dota_hero_", ""), h]));
	const token = process.env.STRATZ_TOKEN || "";
	const files = fs
		.readdirSync(path.join(ROOT, "BotsLib"))
		.filter((f) => /^hero_[a-z0-9_]+\.lua$/.test(f))
		.map((f) => f.slice(5, -4))
		.filter((n) => !ONLY.length || ONLY.includes(n));
	const out = [
		"# Item-build second opinion",
		"",
		`Generated ${new Date().toISOString().slice(0, 16)}Z by \`node Util/item-builds/check.js\`. Sources: OpenDota item popularity${token ? " + Stratz per position" : " (no STRATZ_TOKEN: no per-position data)"}. A second opinion, not a source to copy: check before changing a build (#9, #38).`,
		"",
	];
	let flagged = 0;
	for (const key of files) {
		const hero = byName.get(key);
		if (!hero) continue;
		const lists = readBuilds(path.join(ROOT, "BotsLib", `hero_${key}.lua`));
		if (!Object.keys(lists).length) continue;
		const pop = await cached(`od_${hero.id}`, async () => {
			await sleep(1100);
			return getJson(`https://api.opendota.com/api/heroes/${hero.id}/itemPopularity`, { headers: UA });
		});
		const odCount = {};
		for (const phase of ["start_game_items", "early_game_items", "mid_game_items", "late_game_items"]) {
			for (const [id, n] of Object.entries(pop[phase] || {})) {
				const name = itemIds[id];
				if (name) odCount[name] = (odCount[name] || 0) + n;
			}
		}
		const odMax = Math.max(1, ...Object.values(odCount));
		const lines = [];
		for (const [pos, items] of Object.entries(lists).sort()) {
			let st = null;
			if (token) {
				st = await cached(`stratz_${hero.id}_${pos}`, async () => {
					await sleep(400);
					const q = `{ heroStats { itemFullPurchase(heroId: ${hero.id}, positionIds: [POSITION_${pos}]) { itemId matchCount winCount } } }`;
					const j = await getJson("https://api.stratz.com/graphql", {
						method: "POST",
						headers: { "Content-Type": "application/json", Authorization: "Bearer " + token, "User-Agent": "STRATZ_API" },
						body: JSON.stringify({ query: q }),
					});
					const agg = {};
					for (const r of (j.data && j.data.heroStats && j.data.heroStats.itemFullPurchase) || []) {
						const name = itemIds[r.itemId];
						if (!name) continue;
						agg[name] = agg[name] || { m: 0, w: 0 };
						agg[name].m += r.matchCount;
						agg[name].w += r.winCount;
					}
					return agg;
				});
			}
			const stMax = st ? Math.max(1, ...Object.values(st).map((a) => a.m)) : 1;
			const stAvgWin = st ? Object.values(st).reduce((s, a) => s + a.w, 0) / Math.max(1, Object.values(st).reduce((s, a) => s + a.m, 0)) : 0;
			const ours = [...new Set(items)].filter((i) => !IGNORE.test(i) && itemIds && Object.values(itemIds).includes(i));
			// Rare from OpenDota only: Stratz returns just the most common full purchases, so an item absent there
			// is not evidence. The Stratz count is shown beside it when there is one.
			const odFamily = (i) => Object.entries(odCount).filter(([n]) => base(n) === base(i)).reduce((s2, [, c]) => s2 + c, 0);
			// OpenDota's sample is small (game 040 check: Magic Wand "rare" there, 88k Sven pos 1 matches on Stratz), so
			// an item Stratz counts in at least 2% of the top item's matches is never rare.
			const rare = ours
				.filter((i) => odFamily(i) < odMax * 0.02 && !(st && st[i] && st[i].m >= stMax * 0.02))
				.map((i) => (st && st[i] ? `${i} (stratz ${st[i].m})` : i));
			const ranked = (st ? Object.entries(st).map(([n, a]) => [n, a.m]) : Object.entries(odCount)).filter(([n]) => !IGNORE.test(n)).sort((a, b) => b[1] - a[1]);
			const ourBases = new Set(items.map(base));
			const missing = [...new Set(ranked.filter(([n]) => !components.has(n)).slice(0, 8).map(([n]) => base(n)))].filter((n) => !ourBases.has(n));
			const lowWin = st ? ranked.slice(0, 8).filter(([n]) => st[n].m >= 50 && st[n].w / st[n].m < stAvgWin - 0.03).map(([n]) => `${n} ${((st[n].w / st[n].m) * 100).toFixed(0)}%`) : [];
			if (rare.length || missing.length || lowWin.length) {
				flagged++;
				lines.push(`- **pos ${pos}**${rare.length ? ` rare: ${rare.join(", ")}.` : ""}${missing.length ? ` missing: ${missing.join(", ")}.` : ""}${lowWin.length ? ` low-win: ${lowWin.join(", ")}.` : ""}`);
			}
		}
		if (lines.length) out.push(`## ${hero.localized_name} (\`${key}\`)`, ...lines, "");
	}
	fs.writeFileSync(path.join(__dirname, "report.md"), out.join("\n") + "\n");
	console.log(`${files.length} heroes checked, ${flagged} hero-positions flagged -> Util/item-builds/report.md`);
}
main().catch((e) => {
	console.error(String(e.message || e));
	process.exit(1);
});
