// Reads and rewrites the build blocks of BotsLib/hero_<name>.lua: sRoleItemsBuyList["pos_N"] = { ... }, the
// alias lines between positions, X["sSellList"], and the random-pick locals a list may name (sUtility and the like).
// Nothing else in the file is touched.
"use strict";

const MARK = "(Util/item-builds/generate.js)";
const SELL_MARK = "Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):";
const ENTRY = /^"((?:item|PvN)_[A-Za-z0-9_]+)",?\s*(--.*)?$/;
const VARIABLE = /^([A-Za-z_][A-Za-z0-9_]*),?\s*(--.*)?$/;
const literals = (text) => [...text.matchAll(/"(item_[a-z0-9_]+)"/g)].map((m) => m[1]);

// Two layouts: the usual one, and Io's buildHeroConfig table.
const STYLES = [
	{
		name: "standard",
		open: /^sRoleItemsBuyList\["pos_(\d)"\] = \{$/,
		close: "}",
		alias: /^sRoleItemsBuyList\["pos_(\d)"\] = sRoleItemsBuyList\["pos_(\d)"\]$/,
		openLine: (pos) => `sRoleItemsBuyList["pos_${pos}"] = {`,
		aliasLine: (pos, to) => `sRoleItemsBuyList["pos_${pos}"] = sRoleItemsBuyList["pos_${to}"]`,
		indent: "",
		sellOpen: /^X\["sSellList"\] = \{(.*)$/,
		sellLine: (body) => `X["sSellList"] = {${body}`,
	},
	{
		name: "config",
		open: /^\t\tpos_(\d) = \{$/,
		close: "\t\t},",
		alias: null,
		openLine: (pos) => `\t\tpos_${pos} = {`,
		indent: "\t\t",
		sellOpen: /^\tsell = \{(.*)$/,
		sellLine: (body) => `\tsell = {${body}`,
	},
];

function parse(hero, source, game) {
	const lines = source.split("\n");
	const style = STYLES.find((s) => lines.some((line) => s.open.test(line))) || STYLES[0];
	const file = { hero, lines, style, positions: {}, variables: {}, sell: null, odd: [] };
	for (let i = 0; i < lines.length; i++) {
		const open = lines[i].match(style.open);
		if (open) {
			let end = i + 1;
			while (end < lines.length && lines[end] !== style.close) end++;
			const entries = [];
			let lead = [];
			let odd = null;
			for (let j = i + 1; j < end; j++) {
				const text = lines[j].trim();
				if (text === "") continue;
				if (text.startsWith("--")) {
					lead.push(text);
					continue;
				}
				const item = text.match(ENTRY);
				const variable = item ? null : text.match(VARIABLE);
				if (item) entries.push({ name: item[1], comment: item[2] || "", lead });
				else if (variable) entries.push({ variable: variable[1], comment: variable[2] || "", lead });
				else odd = odd || `line ${j + 1}: ${text.slice(0, 60)}`;
				lead = [];
			}
			// The generator's own comment lines right above the block are replaced with it.
			let start = i;
			while (start > 0 && lines[start - 1].trim().startsWith("-- ") && lines[start - 1].includes(MARK)) start--;
			file.positions[open[1]] = { kind: "block", start, open: i, end, entries, odd };
			i = end;
			continue;
		}
		const alias = style.alias && lines[i].match(style.alias);
		if (alias) {
			let start = i;
			while (start > 0 && lines[start - 1].trim().startsWith("-- ") && lines[start - 1].includes(MARK)) start--;
			file.positions[alias[1]] = { kind: "alias", start, open: i, end: i, to: alias[2] };
			continue;
		}
		// A position set some other way (Arc Warden: one of two lists picked at random): known, never rewritten.
		const other = style.name === "standard" && lines[i].match(/^sRoleItemsBuyList\["pos_(\d)"\] = (?!\{$)/);
		if (other) {
			file.positions[other[1]] = { kind: "other", start: i, open: i, end: i, odd: lines[i].trim() };
			continue;
		}
		const sell = lines[i].match(style.sellOpen);
		if (sell && !file.sell) {
			let end = i;
			while (!/\}/.test(lines[end]) && end < lines.length - 1) end++;
			// Pairs after the generator's marker line are its own: written again on every run, never read back.
			const own = lines.slice(i, end + 1).findIndex((line) => line.includes(SELL_MARK));
			const text = lines.slice(i, own >= 0 ? i + own : end + 1).join("\n");
			const tail = lines[end].slice(lines[end].indexOf("}"));
			file.sell = { start: i, end, pairs: [], tail, plain: !/--/.test(text), hasOwn: own >= 0 };
			const list = literals(text);
			for (let k = 1; k < list.length; k += 2) file.sell.pairs.push([list[k - 1], list[k]]);
			if (list.length % 2 === 1) file.sell.plain = false;
		}
		if (/sRoleItemsBuyList\["pos_\d[^"]+"\]|sRoleItemsBuyList\["pos_\d"\] = (?!\{$|sRoleItemsBuyList\["pos_\d"\]$)/.test(lines[i])) {
			file.odd.push(`line ${i + 1}: ${lines[i].trim().slice(0, 70)}`);
		}
	}
	// Resolve aliases to the block they end at.
	for (const [pos, position] of Object.entries(file.positions)) {
		let at = position;
		const seen = new Set([pos]);
		while (at && at.kind === "alias" && !seen.has(at.to)) {
			seen.add(at.to);
			at = file.positions[at.to];
		}
		position.source = at && at.kind === "block" ? at : null;
	}
	// The picks a list names by variable: every item the local may hold; null = it may hold nothing.
	for (const position of Object.values(file.positions)) {
		for (const entry of position.entries || []) {
			if (!entry.variable || file.variables[entry.variable]) continue;
			const definition = lines.find((line) => new RegExp(`^local ${entry.variable} = `).test(line)) || "";
			let options = literals(definition);
			const viaList = definition.match(/= ([A-Za-z_][A-Za-z0-9_]*)\[RandomInt/);
			if (options.length === 0 && viaList) options = literals(lines.find((line) => new RegExp(`^local ${viaList[1]} = `).test(line)) || "");
			if (options.includes("item_team_aura")) options = [...(game.flex[hero] || []), null];
			else if (/or false\s*$/.test(definition)) options.push(null);
			file.variables[entry.variable] = options;
		}
	}
	return file;
}

// Replace the statements of the given positions and the sell list. changes: { pos: { comment: [lines],
// entries: [{ name | variable, comment, lead }] } | { comment, aliasTo } }. sell: { hand: the hand-written pairs,
// own: the pairs the generator adds after its marker line } ([[trigger, victim]]), or null to leave the list alone.
function render(file, changes, sell) {
	const { style } = file;
	const edits = [];
	for (const [pos, change] of Object.entries(changes)) {
		const position = file.positions[pos];
		const out = (change.comment || []).map((line) => style.indent + line);
		if (change.aliasTo) out.push(style.aliasLine(pos, change.aliasTo));
		else {
			out.push(style.openLine(pos));
			for (const entry of change.entries) {
				for (const lead of entry.lead || []) out.push(`${style.indent}\t${lead}`);
				const value = entry.variable || JSON.stringify(entry.name);
				out.push(`${style.indent}\t${value},${entry.comment ? " " + entry.comment : ""}`);
			}
			out.push(style.close);
		}
		edits.push({ start: position.start, end: position.end, out });
	}
	if (sell && file.sell) {
		const body = sell.hand.map(([a, b]) => `${JSON.stringify(a)}, ${JSON.stringify(b)}`).join(", ");
		const oneLine = style.sellLine(body === "" ? "" : ` ${body} `) + file.sell.tail;
		const out = [];
		if (sell.own.length === 0 && oneLine.length <= 120) out.push(oneLine);
		else {
			out.push(style.sellLine(""));
			const indent = style.name === "config" ? "\t" : "";
			for (const [a, b] of sell.hand) out.push(`${indent}\t${JSON.stringify(a)},`, `${indent}\t${JSON.stringify(b)},`);
			if (sell.own.length) out.push(`${indent}\t-- ${SELL_MARK}`);
			for (const [a, b] of sell.own) out.push(`${indent}\t${JSON.stringify(a)},`, `${indent}\t${JSON.stringify(b)},`);
			out.push(indent + file.sell.tail);
		}
		edits.push({ start: file.sell.start, end: file.sell.end, out });
	}
	const lines = file.lines.slice();
	for (const edit of edits.sort((a, b) => b.start - a.start)) lines.splice(edit.start, edit.end - edit.start + 1, ...edit.out);
	return lines.join("\n");
}

module.exports = { parse, render, MARK, SELL_MARK };
