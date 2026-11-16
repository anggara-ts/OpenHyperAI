// Regenerates URN_BUILDS in FuncLib/systems/item_strategy.lua: for every BotsLib/hero_*.lua, the
// positions whose buy list (with outfit / bundle entries expanded through the item.lua table) has
// Urn of Shadows, Spirit Vessel or Essence Distiller. A bot cannot read an ally's build at runtime,
// so the list is kept in the file; run this after any build change.
//
// Usage: node Util/urn-builds.js          (prints the table)
//        node Util/urn-builds.js --write  (also rewrites it in item_strategy.lua)
const fs = require("fs");
const path = require("path");
const REPO = path.resolve(__dirname, "..");
const URN = new Set(["item_urn_of_shadows", "item_spirit_vessel", "item_essence_distiller"]);

const itemLua = fs.readFileSync(REPO + "/FuncLib/systems/item.lua", "utf8");
const comp = {};
for (const m of itemLua.matchAll(/b\["(item_[a-z0-9_]+)"\]\s*=\s*\{([^}]*)\}/g)) {
  comp[m[1]] = [...m[2].matchAll(/"(item_[a-z0-9_]+)"/g)].map(x => x[1]);
}
const hasUrn = (name, d = 0) => URN.has(name) || (d < 5 && (comp[name] || []).some(x => hasUrn(x, d + 1)));

const rows = [];
for (const f of fs.readdirSync(REPO + "/BotsLib").filter(x => /^hero_.*\.lua$/.test(x)).sort()) {
  const hero = f.replace(/^hero_|\.lua$/g, "");
  if (hero === "lone_druid_bear") continue;
  const s = fs.readFileSync(REPO + "/BotsLib/" + f, "utf8");
  // pos tables: X["pos_N"] = { ... }  and aliases X["pos_N"] = Y["pos_M"]
  const lists = {};
  for (const m of s.matchAll(/\["(pos_[1-5])"\]\s*=\s*\{([^}]*)\}/g)) lists[m[1]] = lists[m[1]] || m[2];
  for (const m of s.matchAll(/\b(pos_[1-5])\s*=\s*\{([^}]*)\}/g)) lists[m[1]] = lists[m[1]] || m[2];
  for (let pass = 0; pass < 3; pass++) {
    for (const m of s.matchAll(/\["(pos_[1-5])"\]\s*=\s*\w+\["(pos_[1-5])"\]/g)) if (!lists[m[1]] && lists[m[2]]) lists[m[1]] = lists[m[2]];
  }
  const pos = [];
  for (let p = 1; p <= 5; p++) {
    const body = lists["pos_" + p];
    if (!body) continue;
    const items = [...body.matchAll(/"(item_[a-z0-9_]+)"/g)].map(x => x[1]);
    if (items.some(x => hasUrn(x))) pos.push(p);
  }
  if (pos.length) rows.push([hero, pos]);
}
const table = "local URN_BUILDS = {\n" + rows.map(([h, p]) => `\tnpc_dota_hero_${h} = { ${p.join(", ")} },`).join("\n") + "\n}";
console.log(table);
if (process.argv.includes("--write")) {
  const f = REPO + "/FuncLib/systems/item_strategy.lua";
  const src = fs.readFileSync(f, "utf8").replace(/\r\n/g, "\n");
  const out = src.replace(/local URN_BUILDS = \{\n[\s\S]*?\n\}/, table);
  if (out === src) throw new Error("URN_BUILDS block not found or unchanged");
  fs.writeFileSync(f, out);
  console.log("written to", f);
}
