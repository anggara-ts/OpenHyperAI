// Rough Lua block-balance check: counts block openers (function, if, do) against "end", and
// repeat against until, after stripping comments and strings. A gap other than 0, or a gap that
// differs from the committed version of the same file, points at a missing or extra "end".
// It is a token count, not a parser: compare against `git show HEAD:<file>` rather than trusting
// the absolute number.
//
// Usage: node Util/luabal.js <file.lua> [more.lua ...]
const fs = require("fs");

function bal(src) {
	// long comments and long strings, then line comments, then quoted strings
	src = src.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g, "").replace(/\[(=*)\[[\s\S]*?\]\1\]/g, '""');
	src = src.replace(/--[^\n]*/g, "");
	src = src.replace(/"(\\.|[^"\\\n])*"/g, '""').replace(/'(\\.|[^'\\\n])*'/g, "''");
	const tok = src.match(/[A-Za-z_][A-Za-z0-9_]*/g) || [];
	let open = 0, end = 0, until = 0, rep = 0;
	for (const t of tok) {
		// "while ... do" and "for ... do" count through "do"; "elseif" is its own token
		if (t === "function" || t === "if" || t === "do") open++;
		else if (t === "end") end++;
		else if (t === "repeat") rep++;
		else if (t === "until") until++;
	}
	return { open, end, gap: open - end, repeat: rep, until };
}

for (const f of process.argv.slice(2)) {
	console.log(f, JSON.stringify(bal(fs.readFileSync(f, "utf8"))));
}
