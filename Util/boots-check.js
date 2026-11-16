// Lists hero positions whose buy list ends up with more than one pair of boots. Outfits and
// bundles are expanded through the item.lua table. Boot lines: Phase, Power Treads, Arcane (and
// its Guardian Greaves), Tranquil (and its Boots of Bearing). Boots of Travel is a late
// replacement (the generic code sells the old boots) and is not counted.
// Usage: node Util/boots-check.js
const fs = require("fs");
const path = require("path");
const REPO = path.resolve(__dirname, "..");
const itemLua = fs.readFileSync(REPO + "/FuncLib/systems/item.lua", "utf8");
const comp = {};
for (const m of itemLua.matchAll(/b\["(item_[a-z0-9_]+)"\]\s*=\s*\{([^}]*)\}/g)) {
  comp[m[1]] = [...m[2].matchAll(/"(item_[a-z0-9_]+)"/g)].map(x => x[1]);
}
const LINE = (n) => {
  if (n === "item_phase_boots") return "phase";
  if (/^item_power_treads/.test(n)) return "treads";
  if (n === "item_arcane_boots" || n === "item_guardian_greaves") return "arcane";
  if (n === "item_tranquil_boots" || n === "item_boots_of_bearing") return "tranquil";
  return null;
};
// Top-level entries: expand bundles/outfits (not real recipes of the boots themselves).
const expand = (n, d = 0) => {
  if (LINE(n)) return [n];
  if (d < 4 && comp[n] && /outfit|double|team_aura/.test(n)) return comp[n].flatMap(x => expand(x, d + 1));
  return [n];
};
const out = [];
for (const f of fs.readdirSync(REPO + "/BotsLib").filter(x => /^hero_.*\.lua$/.test(x)).sort()) {
  const s = fs.readFileSync(REPO + "/BotsLib/" + f, "utf8");
  const lists = {};
  for (const m of s.matchAll(/(\w+)\["(pos_[1-5]\w*)"\]\s*=\s*\{([^}]*)\}/g)) lists[m[1] + "." + m[2]] = m[3];
  for (const m of s.matchAll(/\b(pos_[1-5]\w*)\s*=\s*\{([^}]*)\}/g)) lists["tbl." + m[1]] = lists["tbl." + m[1]] || m[2];
  for (const [k, body] of Object.entries(lists)) {
    const items = [...body.matchAll(/"(item_[a-z0-9_]+)"/g)].map(x => x[1]).flatMap(x => expand(x));
    const lines = [...new Set(items.map(LINE).filter(Boolean))];
    if (lines.length > 1) out.push(`${f.replace(/^hero_|\.lua$/g, "")} ${k}: ${lines.join(" + ")}`);
    // Aura boots are kept when Boots of Travel arrive; item_purchase_generic skips Travel for a bot
    // that owns them, so a Travel entry after them is dead weight in the list.
    const aura = items.find(x => x === "item_guardian_greaves" || x === "item_boots_of_bearing");
    if (aura && items.some(x => /^item_travel_boots/.test(x))) out.push(`${f.replace(/^hero_|\.lua$/g, "")} ${k}: ${aura.replace("item_", "")} + travel_boots (Travel is skipped in game)`);
  }
}
console.log(out.length ? out.join("\n") : "no position buys more than one pair of boots");
