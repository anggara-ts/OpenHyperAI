#!/usr/bin/env node
// Item facts from the game file, for the build generator and its tests (#38).
//
//   node Util/item-builds/game-items.js <path to scripts/npc/items.txt>
//
// Reads the installed game's items.txt (inside the VPKs: scripts/npc/items.txt) and writes
//   Util/item-builds/items.json       cost, parts, active or passive, purchasable, for generate.js
//   Tests/data/item_recipes_742.lua   cost and parts, for Tests/test_item_build_sim.lua and the stub's GetItemComponents
// Rerun it after a patch that changes items, then rerun generate.js.
// "parts" is the first requirement set of the item's recipe, plus the recipe itself when it costs gold: what the
// bot buys for the item (Item[name] in FuncLib/systems/item.lua comes from the engine's GetItemComponents).
"use strict";
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "..");
const source = process.argv[2];
if (!source || !fs.existsSync(source)) {
	console.error("usage: node Util/item-builds/game-items.js <path to scripts/npc/items.txt>");
	process.exit(1);
}

// Valve KeyValues: "key" "value" pairs and "key" { ... } blocks, // comments.
function parseKeyValues(text) {
	let at = 0;
	const size = text.length;
	const skip = () => {
		for (;;) {
			while (at < size && /\s/.test(text[at])) at++;
			if (text[at] === "/" && text[at + 1] === "/") {
				while (at < size && text[at] !== "\n") at++;
				continue;
			}
			break;
		}
	};
	const token = () => {
		skip();
		if (at >= size) return null;
		const ch = text[at];
		if (ch === "{" || ch === "}") {
			at++;
			return ch;
		}
		if (ch === '"') {
			let end = at + 1;
			let value = "";
			while (end < size && text[end] !== '"') {
				if (text.charCodeAt(end) === 92) {
					value += text[end + 1];
					end += 2;
					continue;
				}
				value += text[end++];
			}
			at = end + 1;
			return { value };
		}
		let end = at;
		while (end < size && !/[\s{}"]/.test(text[end])) end++;
		const value = text.slice(at, end);
		at = end;
		return { value };
	};
	const block = () => {
		const out = {};
		for (;;) {
			const key = token();
			if (key === null || key === "}") return out;
			const value = token();
			out[key.value] = value === "{" ? block() : value.value;
			skip();
			if (text[at] === "[") {
				while (at < size && text[at] !== "]") at++;
				at++;
			}
		}
	};
	return block();
}

const parsed = parseKeyValues(fs.readFileSync(source, "utf8"));
const kv = parsed.DOTAAbilities || parsed;
const items = {};
const recipeOf = {};
for (const [name, entry] of Object.entries(kv)) {
	if (!/^item_recipe_/.test(name) || typeof entry !== "object" || !entry.ItemResult || !entry.ItemRequirements) continue;
	const sets = Object.keys(entry.ItemRequirements)
		.sort()
		.map((key) =>
			entry.ItemRequirements[key]
				.split(";")
				.map((part) => part.replace("*", "").trim())
				.filter(Boolean),
		)
		.filter((set) => set.length > 0);
	if (sets.length === 0) continue;
	recipeOf[entry.ItemResult] = { recipe: name, cost: Number(entry.ItemCost || 0), sets };
}
for (const [name, entry] of Object.entries(kv)) {
	if (!/^item_/.test(name) || typeof entry !== "object") continue;
	const purchasable = entry.ItemPurchasable !== "0" && entry.IsObsolete !== "1" && entry.ItemIsNeutralActiveDrop !== "1";
	const neutral = entry.ItemIsNeutralActiveDrop === "1" || entry.ItemIsNeutralPassiveDrop === "1";
	const item = { cost: Number(entry.ItemCost || 0) };
	if (!purchasable || neutral || entry.ItemCost === undefined) item.buy = false;
	const behavior = entry.AbilityBehavior || "";
	if (behavior !== "" && !/PASSIVE/.test(behavior)) item.active = true;
	const recipe = recipeOf[name];
	if (recipe) {
		item.parts = [...recipe.sets[0], ...(recipe.cost > 0 ? [recipe.recipe] : [])];
		if (recipe.sets.length > 1) item.otherSets = recipe.sets.slice(1);
	}
	items[name] = item;
}
const names = Object.keys(items).sort();
const json = ["{", '\t"source": "scripts/npc/items.txt (written by Util/item-builds/game-items.js)",', '\t"items": {'];
names.forEach((name, index) => {
	json.push(`\t\t${JSON.stringify(name)}: ${JSON.stringify(items[name])}${index < names.length - 1 ? "," : ""}`);
});
json.push("\t}", "}", "");
fs.writeFileSync(path.join(__dirname, "items.json"), json.join("\n"));

const lua = [
	"-- Generated from scripts/npc/items.txt of Dota 7.42 by Util/item-builds/game-items.js: do not edit by hand.",
	"-- [item name] = { cost = gold, parts = what its recipe takes (the recipe itself last, when it costs gold) }.",
	"-- Only items a hero can buy, their parts and their recipes.",
	"return {",
];
for (const name of names) {
	const item = items[name];
	if (item.buy === false) continue;
	const parts = item.parts ? `, parts = { ${item.parts.map((part) => JSON.stringify(part)).join(", ")} }` : "";
	lua.push(`\t${name} = { cost = ${item.cost}${parts} },`);
}
lua.push("}", "");
fs.writeFileSync(path.join(ROOT, "Tests", "data", "item_recipes_742.lua"), lua.join("\n"));
console.log(`${names.length} items: Util/item-builds/items.json, Tests/data/item_recipes_742.lua`);
