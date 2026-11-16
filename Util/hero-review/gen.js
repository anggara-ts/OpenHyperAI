// Builds hero-review.html (the 2026-11-16 patch review report) from report_batch1..8.md, written by
// eight reviewer agents following BRIEF.md, and the page.tpl.html template.
// Usage: node Util/hero-review/gen.js
const fs = require("fs");
const D = __dirname;
const names = {};
for (const l of fs.readFileSync(D + "/heroes.tsv", "utf8").split(/\r?\n/)) {
  const p = l.split("\t");
  if (p.length >= 3) names[p[1].replace("npc_dota_hero_", "")] = p[2];
}
const heroes = [];
for (let b = 1; b <= 8; b++) {
  const txt = fs.readFileSync(`${D}/report_batch${b}.md`, "utf8").split(/\r?\n/);
  let cur = null;
  for (const l of txt) {
    let m = l.match(/^HERO:\s*(\S+)\s*\|\s*STATUS:\s*(CHANGED|FLAGGED|OK)\s*(?:-\s*(.*))?$/);
    if (m) {
      cur = { key: m[1], name: names[m[1]] || m[1], status: m[2], batch: b, note: m[3] || "", changes: [], flags: [] };
      heroes.push(cur);
      continue;
    }
    m = l.match(/^- (CHANGE|FLAG):\s*(.*)$/);
    if (m && cur) {
      const [what, why] = m[2].split(/\s*\|\s*WHY:\s*/);
      (m[1] === "CHANGE" ? cur.changes : cur.flags).push({ what: what.trim(), why: (why || "").trim() });
      continue;
    }
    m = l.match(/^- (.*)$/);
    if (m && cur) cur.flags.push({ what: m[1].trim(), why: "", note: true });
  }
}
// coordinator edits made after the reviewers
const extra = {
  invoker: { what: "No-target (radial) Deafening Blast only when talent special_bonus_unique_invoker_2 is learned; it was cast that way from level 25", why: "Datafeed: radial Deafening Blast comes from that talent. The default talent build takes another talent, so a level-25 Invoker ordered a no-target cast of a point spell." },
  death_prophet: { what: "Removed the starting Circlet from pos 2, 4 and 5", why: "User report, game 033: at 20:00 she still carried it. Nothing in her builds turns a Circlet into anything." },
};
for (const h of heroes) if (extra[h.key]) { h.changes.push(extra[h.key]); h.status = "CHANGED"; }
heroes.sort((a, b) => a.name.localeCompare(b.name));
const shared = [
  { file: "item_purchase_generic.lua", what: "A Circlet that nothing left in the build uses is sold from 15:00", why: "20 build lists across 17 heroes buy a Circlet (or a Double Circlet) that is never made into a Wraith Band, Null Talisman or Bracer, so it sat in the bag all game." },
  { file: "FuncLib/general_utils/positioning.lua", what: "GetBestRetreatTree returns the tree it found", why: "It assigned an undefined global (aI = loc), so it never returned a tree and Timbersaw's Timber Chain retreat never fired." },
  { file: "FuncLib/data/spell_list.lua", what: "jakiro_liquid_frost renamed to jakiro_liquid_ice", why: "The datafeed name is jakiro_liquid_ice; Jakiro's hero file now uses that name too." },
];
const open = [
  { what: "Vector-targeted spells are cast at a point", why: "The bot API has no vector-target order (runtime dump). Affects Windranger Gale Force, Pangolier Swashbuckle, Tusk Walrus Kick, Puck Illusory Orb and similar." },
  { what: "Many support positions reuse the carry build", why: "pos 4/5 aliases of pos 1 (Sven, Riki, Phantom Assassin, Luna, Templar Assassin, Faceless Void and others). Kunkka and Snapfire got real support builds; the rest need a build redesign." },
  { what: "Lifestealer pos 4/5 builds are carry items", why: "Basher, MKB, Assault, Abyssal on a support build." },
  { what: "chen_summon_convert is still in spell_list.lua", why: "Removed from the game; Chen's ConsiderSummonConvert never fires. Harmless." },
  { what: "Stale abilities that resolve to the safe dummy", why: "tinker_keen_teleport (Tinker never teleports home), faceless_void_time_zone, clinkz_tar_bomb, shredder_twisted_chakram, brewmaster_primal_companion, antimage_counterspell_ally. None crash; the code around them is dead." },
  { what: "Abilities that are never cast", why: "Huskar Berserker's Blood Shard active, Lycan Wolf Bite (Scepter), Tiny Blink + Toss combo." },
  { what: "Newly live branches, untested in a game", why: "Lifestealer Infest, Clinkz Burning Army, Jakiro Liquid Ice, Clockwerk hook-to-ally, Night Stalker Shard creep-eat, Tiny Tree Volley, Spirit Breaker Planar Pocket, Shadow Demon Demonic Cleanse, Lone Druid Entangle, Necrophos Ghost Shroud engage." },
];
const counts = { CHANGED: 0, FLAGGED: 0, OK: 0 };
let nChanges = 0, nFlags = 0;
for (const h of heroes) { counts[h.status]++; nChanges += h.changes.length; nFlags += h.flags.filter(f => !f.note).length; }
const data = { heroes, shared, open, counts, nChanges, nFlags, total: heroes.length };
const tpl = fs.readFileSync(D + "/page.tpl.html", "utf8");
fs.writeFileSync(D + "/hero-review.html", tpl.replace("/*DATA*/null", JSON.stringify(data).replace(/</g, "\\u003c")));
console.log(heroes.length, counts, nChanges, nFlags);
