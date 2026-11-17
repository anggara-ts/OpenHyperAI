// Lists heroes weighted above 50 at pos 4/5 whose pos 4/5 item build has no support items.
// Usage: node Util/role-weights/gen.js (writes rows.json), then node Util/role-weights/supcheck.js
const fs=require("fs");const path=require("path");const REPO=path.resolve(__dirname,"../..");
const rows=JSON.parse(fs.readFileSync(__dirname+"/rows.json","utf8"));
const key2npc={};for(const m of fs.readFileSync(REPO+"/FuncLib/dota/heroes.lua","utf8").matchAll(/\w+\.HeroName\.(\w+)\s*=\s*"([^"]+)"/g))key2npc[m[1]]=m[2];
const sup=/priest_outfit|mage_outfit|item_ward_|blood_grenade|item_glimmer|item_force_staff|item_mekansm|item_guardian_greaves|item_pipe|item_solar_crest|item_spirit_vessel|item_urn|item_tranquil|item_arcane_boots|item_holy_locket|item_boots_of_bearing|item_lotus/;
const out=[];
for(const r of rows){const f=REPO+"/BotsLib/hero_"+key2npc[r.key].replace("npc_dota_hero_","")+".lua";if(!fs.existsSync(f)){out.push("NOFILE "+f);continue;}const s=fs.readFileSync(f,"utf8");
 const lists={};for(const m of s.matchAll(/\["(pos_[1-5])"\]\s*=\s*\{([^}]*)\}/g))lists[m[1]]=m[2];
 for(const m of s.matchAll(/\["(pos_[1-5])"\]\s*=\s*\w+\["(pos_[1-5])"\]/g))if(!lists[m[1]])lists[m[1]]=lists[m[2]]||"";
 for(const p of [4,5]){ if(r.neu[p-1]<=50) continue; const body=lists["pos_"+p];
  if(body===undefined) out.push(r.name+" pos"+p+"="+r.neu[p-1]+" (no list found)"); else if(!sup.test(body)) out.push(r.name+" pos"+p+"="+r.neu[p-1]+" core-style build");}
}
console.log(out.join("\n")||"all supports have support builds");
