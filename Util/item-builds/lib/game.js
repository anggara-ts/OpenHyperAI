// What the bot scripts and the game file say about items: recipes, our bundles, sell rules, use rules, farm rules.
// Read by generate.js; everything here comes from the repo's own files, so the simulation follows the code.
"use strict";
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "..", "..");
const read = (file) => fs.readFileSync(path.join(ROOT, file), "utf8");
const names = (text) => [...text.matchAll(/"((?:item|PvN)_[A-Za-z0-9_]+)"/g)].map((m) => m[1]);

function load() {
	const items = JSON.parse(read("Util/item-builds/items.json")).items;
	const itemLua = read("FuncLib/systems/item.lua");

	// Item["item_x"] = { ... }: our bundles and the recipes spelled out by hand. They win over the engine's recipe.
	const bundle = {};
	for (const m of itemLua.matchAll(/^Item\["((?:item|PvN)_[A-Za-z0-9_]+)"\]\s*=\s*\{([\s\S]*?)\}/gm)) bundle[m[1]] = names(m[2]);
	// The engine's recipe (GetItemComponents) for every name in sCompositeItems, recipes last.
	const compositeAt = itemLua.indexOf("local sCompositeItems = {");
	const composite = names(itemLua.slice(compositeAt, itemLua.indexOf("\n}", compositeAt)));
	for (const name of composite) {
		if (bundle[name] || !items[name] || !items[name].parts) continue;
		const parts = items[name].parts;
		bundle[name] = [...parts.filter((p) => !/^item_recipe_/.test(p)), ...parts.filter((p) => /^item_recipe_/.test(p))];
	}
	const table = (name) => {
		const at = itemLua.indexOf(`Item["${name}"] =`);
		return at < 0 ? [] : names(itemLua.slice(at, itemLua.indexOf("}", at)));
	};
	const aliasAt = itemLua.indexOf("local itemAliases = {");
	const alias = {};
	for (const m of itemLua.slice(aliasAt, itemLua.indexOf("\n}", aliasAt)).matchAll(/\["(item_[a-z0-9_]+)"\]\s*=\s*"(item_[a-z0-9_]+)"/g)) alias[m[1]] = m[2];
	const pairs = (list) => {
		const out = [];
		for (let i = 1; i < list.length; i += 2) out.push([list[i - 1], list[i]]);
		return out;
	};

	// Items the item-use script has a rule for.
	const usage = new Set();
	for (const m of read("ability_item_usage_generic.lua").matchAll(/ConsiderItemDesire\["(item_[a-z0-9_]+)"\]/g)) usage.add(m[1]);

	// Farm rules: Site.ConsiderIsTimeToFarm.<hero> farms while `not HasItem(bot, "item_x")`. cap = the net worth
	// (or "gold" / "part" for a rule gated on gold or on a held part) that ends the wait; null = it never ends.
	const site = read("FuncLib/data/site.lua");
	const farm = {};
	const delegate = {};
	for (const m of site.matchAll(/^Site\.ConsiderIsTimeToFarm\.npc_dota_hero_([a-z_]+) = function\(\)([\s\S]*?)\n^end/gm)) {
		const to = m[2].match(/return Site\.ConsiderIsTimeToFarm\.npc_dota_hero_([a-z_]+)\(\)/);
		if (to) {
			delegate[m[1]] = to[1];
			continue;
		}
		const waits = [];
		for (const c of m[2].matchAll(/if ([^\n]*?) then/g)) {
			for (const w of c[1].matchAll(/not HasItem\(bot, "(item_[a-z0-9_]+)"\)/g)) {
				const worth = c[1].match(/netWorth\s*<=?\s*(\d+)/);
				const gated = /GetGold\(\)/.test(c[1]) ? "gold" : /(^|and )HasItem\(bot/.test(c[1].replace(/not HasItem/g, "")) ? "part" : null;
				waits.push({ item: w[1], cap: worth ? Number(worth[1]) : gated });
			}
		}
		farm[m[1]] = waits;
	}
	for (const [hero, to] of Object.entries(delegate)) farm[hero] = (farm[to] || []).map((w) => ({ ...w, via: to }));

	// Team items: the placeholder a build may hold, and who may keep an Urn.
	const strategy = read("FuncLib/systems/item_strategy.lua");
	const flex = {};
	const flexAt = strategy.indexOf("local FLEX = {");
	for (const m of strategy.slice(flexAt, strategy.indexOf("\n}", flexAt)).matchAll(/npc_dota_hero_([a-z_]+) = \{([^}]*)\}/g)) flex[m[1]] = names(m[2]);

	return {
		items,
		bundle,
		alias,
		usage,
		farm,
		flex,
		globalSellPairs: pairs(table("sSellList")),
		earlyItems: new Set(table("tEarlyItem")),
		supportSellWhenFull: new Set(table("tSupportSellWhenFull")),
		earlyBoots: new Set(table("tEarlyBoots")),
	};
}

module.exports = { load, ROOT, names };
