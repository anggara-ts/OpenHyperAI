#!/usr/bin/env node
// Writes Tests/data/hero_abilities.lua: every hero's ability slots as the engine has them, from the game
// files, for Tests/test_skill_builds.lua.
//
//   node Util/skill-builds/gen-fixture.js <game files> [patch name]
//
// <game files> is either a folder holding scripts/npc/npc_abilities.txt and scripts/npc/heroes/*.txt
// (extracted from "dota 2 beta/game/dota/pak01_dir.vpk" with any VPK tool), or one text file with those
// files one after the other. Run it again after a patch that changes a hero's abilities.
//
// The slot order was checked against the game: the bots' own dump ([OHA-API] abilities <hero>, 20 heroes
// in two 7.42 games) lists the same abilities in the same order, with the same hidden ones.
"use strict";
const fs = require("fs");
const path = require("path");

function parseKeyValues(text) {
	let i = 0;
	const n = text.length;
	function skip() {
		for (;;) {
			while (i < n && /\s/.test(text[i])) i++;
			if (text[i] === "/" && text[i + 1] === "/") {
				while (i < n && text[i] !== "\n") i++;
			} else if (text[i] === "#") {
				while (i < n && text[i] !== "\n") i++; // "#base" lines and the "#####" file headers
			} else {
				return;
			}
		}
	}
	function token() {
		skip();
		if (i >= n) return null;
		const c = text[i];
		if (c === "{" || c === "}") {
			i++;
			return c;
		}
		if (c === '"') {
			const end = text.indexOf('"', i + 1);
			const s = text.slice(i + 1, end);
			i = end + 1;
			return { s };
		}
		let j = i;
		while (j < n && !/[\s{}"]/.test(text[j])) j++;
		const s = text.slice(i, j);
		i = j;
		return { s };
	}
	function object() {
		const o = {};
		for (;;) {
			const key = token();
			if (key === null || key === "}") return o;
			const value = token();
			if (value === "{") {
				const child = object();
				o[key.s] = typeof o[key.s] === "object" ? Object.assign(o[key.s], child) : child;
			} else {
				o[key.s] = value.s;
			}
		}
	}
	return object();
}

function readGameFiles(source) {
	if (fs.statSync(source).isDirectory()) {
		const npc = [path.join(source, "scripts", "npc"), path.join(source, "npc"), source].find((dir) =>
			fs.existsSync(path.join(dir, "npc_abilities.txt")),
		);
		if (!npc) throw new Error("no npc_abilities.txt under " + source);
		const files = [path.join(npc, "npc_abilities.txt")];
		for (const name of fs.readdirSync(path.join(npc, "heroes")).sort()) {
			if (/\.txt$/.test(name)) files.push(path.join(npc, "heroes", name));
		}
		return files.map((file) => fs.readFileSync(file, "utf8"));
	}
	return fs
		.readFileSync(source, "utf8")
		.split(/^#####.*$/m)
		.filter((part) => /"DOTA(Abilities|Heroes)"/.test(part));
}

const [source, patch] = process.argv.slice(2);
if (!source) {
	console.error("usage: node Util/skill-builds/gen-fixture.js <game files> [patch name]");
	process.exit(2);
}
const heroes = {};
const abilities = {};
for (const text of readGameFiles(source)) {
	const root = parseKeyValues(text);
	for (const [name, value] of Object.entries(root.DOTAAbilities || {})) {
		if (typeof value === "object") abilities[name] = Object.assign(abilities[name] || {}, value);
	}
	for (const [name, value] of Object.entries(root.DOTAHeroes || {})) {
		if (typeof value !== "object") continue;
		for (const [abilityName, ability] of Object.entries(value.AbilityDefinitions || {})) {
			if (typeof ability === "object") abilities[abilityName] = Object.assign(abilities[abilityName] || {}, ability);
		}
		heroes[name] = Object.assign(heroes[name] || {}, value);
	}
}

// One ability as "name|flags|max level|hero level for rank 1|hero levels between ranks|linked ability",
// trailing empty fields left out (a linked ability gets its ranks together with this one: LinkedAbility). Flags: u ultimate, h hidden at the start (also Shard / Scepter abilities),
// n not learnable, i innate, d levelled by another ability (DependentOnAbility).
function describe(name) {
	const ability = abilities[name] || {};
	const behavior = ability.AbilityBehavior || "";
	const granted = ability.IsGrantedByShard === "1" || ability.IsGrantedByScepter === "1";
	let flags = "";
	if (/ABILITY_TYPE_ULTIMATE/.test(ability.AbilityType || "")) flags += "u";
	if (/DOTA_ABILITY_BEHAVIOR_HIDDEN/.test(behavior) || granted) flags += "h";
	if (/DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE/.test(behavior)) flags += "n";
	if (ability.Innate === "1") flags += "i";
	if (ability.DependentOnAbility) flags += "d";
	const fields = [
		name,
		flags,
		ability.MaxLevel || "",
		ability.RequiredLevel || "",
		ability.LevelsBetweenUpgrades || "",
		ability.LinkedAbility || "",
	];
	while (fields.length > 1 && fields[fields.length - 1] === "") fields.pop();
	return fields.join("|");
}

const base = heroes.npc_dota_hero_base || {};
const lines = [];
let count = 0;
for (const heroName of Object.keys(heroes).sort()) {
	if (heroName === "npc_dota_hero_base" || heroName === "npc_dota_hero_target_dummy") continue;
	const hero = Object.assign({}, base, heroes[heroName]);
	const slots = [];
	for (let number = 1; number <= 35; number++) {
		const name = hero["Ability" + number];
		if (name) slots.push(describe(name)); // the engine packs the slots: an unset AbilityN takes none
	}
	if (slots.length === 0) continue;
	count++;
	lines.push("\t" + heroName.replace(/^npc_dota_hero_/, "") + " = {");
	for (const slot of slots) lines.push('\t\t"' + slot + '",');
	lines.push("\t},");
}
const header = [
	"-- Every hero's ability slots as the engine has them (slot 0 first), from the game files" +
		(patch ? " of patch " + patch : "") +
		".",
	"-- Generated by Util/skill-builds/gen-fixture.js; do not edit by hand, run it again after a patch.",
	'-- An entry is "name|flags|max level|hero level for rank 1|hero levels between ranks|linked ability" with',
	"-- trailing empty fields left out. Flags: u ultimate, h hidden at the start (also Shard / Scepter",
	"-- abilities), n not learnable, i innate, d levelled by another ability. A linked ability gets its ranks",
	"-- together with this one.",
	"-- stylua: ignore",
	"return {",
];
const out = path.join(__dirname, "..", "..", "Tests", "data", "hero_abilities.lua");
fs.writeFileSync(out, header.concat(lines, ["}", ""]).join("\n"));
console.log(count + " heroes -> " + path.relative(process.cwd(), out));
