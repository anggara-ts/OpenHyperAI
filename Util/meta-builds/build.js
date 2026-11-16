// Builds one review file per hero (heroes/<hero>.txt, git-ignored) from dotabuff_slim.txt, for the
// item / skill build review against the Dotabuff meta (see BRIEF.md and reports/).
// Usage: node Util/meta-builds/build.js
//
// dotabuff_slim.txt was read in Chrome from https://www.dotabuff.com/heroes/<slug>/items and
// /builds (2026-11-17, serially; the site answers plain fetches with 403). Format: line 1
// "D|name^name^..." item dictionary; then per hero
// "slug|<top item matches>k|idx:share,...|Ability/Ability/...|<one char per level 1..15,18, '~' = under 40% picked>".
// Share = matches played relative to the hero's most played item. Win rate is left out on purpose
// (survivorship bias: Aegis / Rapier look strong, components and cheap items look weak).
// itemlist.json is the Valve datafeed item list (https://www.dota2.com/datafeed/itemlist?language=english).
const fs = require("fs");
const path = require("path");
const REPO = path.resolve(__dirname, "../..");
const D = __dirname;
const lines = fs.readFileSync(D + "/dotabuff_slim.txt", "utf8").trim().split(/\r?\n/);
const dict = lines[0].slice(2).split("^");
const raw = JSON.parse(fs.readFileSync(D + "/itemlist.json", "utf8"));
const findArr = o => Array.isArray(o) ? o : (o && typeof o === "object" ? Object.values(o).map(findArr).find(Boolean) : null);
const items = findArr(raw) || [];
const byName = {}, neutral = {};
for (const it of items) if (it.name_english_loc) { byName[it.name_english_loc.toLowerCase()] = it.name; if (it.neutral_item_tier >= 0) neutral[it.name] = true; }
const valid = new Set(items.map(it => it.name).filter(Boolean));
const heroes = {};
for (const l of fs.readFileSync(REPO + "/Util/role-weights/heroes.tsv", "utf8").split(/\r?\n/)) {
  const p = l.split("\t");
  if (p.length >= 3) heroes[p[2].toLowerCase().replace(/'/g, "").replace(/[^a-z0-9]+/g, "-")] = p[1].replace("npc_dota_hero_", "");
}
const alias = { "centaur-warrunner": "centaur", "treant-protector": "treant", "underlord": "abyssal_underlord", "natures-prophet": "furion", "outworld-destroyer": "obsidian_destroyer", "windranger": "windrunner", "clockwerk": "rattletrap", "io": "wisp", "zeus": "zuus", "wraith-king": "skeleton_king", "shadow-fiend": "nevermore", "queen-of-pain": "queenofpain", "vengeful-spirit": "vengefulspirit", "doom": "doom_bringer", "lifestealer": "life_stealer", "necrophos": "necrolyte", "magnus": "magnataur", "timbersaw": "shredder", "anti-mage": "antimage" };
const levels = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 18];
fs.mkdirSync(D + "/heroes", { recursive: true });
const done = [], unknown = new Set();
for (const line of lines.slice(1)) {
  const [slug, topK, itemStr, abilStr, seq] = line.split("|");
  const hero = heroes[slug] || alias[slug];
  if (!hero || !fs.existsSync(REPO + "/BotsLib/hero_" + hero + ".lua")) { console.log("unmatched", slug, hero); continue; }
  const out = [];
  out.push(`HERO ${hero}  (dotabuff ${slug}, last-patch data)  file BotsLib/hero_${hero}.lua`);
  out.push(`Most played items, all positions (share = matches played relative to the most played item, ${topK} matches). Win rate deliberately left out.`);
  out.push(`  [N] = neutral item (not bought, ignore); [?] = no shop item matched`);
  for (const pair of itemStr.split(",")) {
    const [i, share] = pair.split(":");
    const name = dict[+i];
    const key = byName[name.toLowerCase()];
    let tag = "";
    if (!key) { tag = "[?]"; unknown.add(name); }
    else if (neutral[key] || !valid.has(key) || key.startsWith("item_enhancement")) tag = "[N]";
    out.push(`  ${String(share).padStart(3)}%  ${(key || "-").padEnd(30)} ${name} ${tag}`);
  }
  const abil = abilStr.split("/");
  const steps = seq.match(/\d~?/g) || [];
  out.push(`Most picked ability per level (~ = picked under 40% at that level, usually a talent level; ignore):`);
  out.push("  " + steps.map((s, k) => `${levels[k]}:${abil[+s[0]]}${s.endsWith("~") ? "~" : ""}`).join(" | "));
  fs.writeFileSync(D + "/heroes/" + hero + ".txt", out.join("\n") + "\n");
  done.push(hero);
}
fs.writeFileSync(D + "/heroes/_index.txt", done.sort().join("\n") + "\n");
console.log("written", done.length, "| unknown names:", [...unknown].join(", "));
