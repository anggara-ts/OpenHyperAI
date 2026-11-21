-- FuncLib/systems/refresher_rules.lua: the mana a Refresher Orb / Shard refresh needs (#47).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_zuus" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/refresher_rules")
end

T.test("refresher: the refresher's own cost counts with the recast", function()
	local R = rules()
	-- 7.42 game files: Orb 325 mana, Shard 200.
	T.eq(R.ManaNeeded(325, { 150 }), 475, "Orb + a 150-mana ultimate")
	T.eq(R.ManaNeeded(200, { 150 }), 350, "Shard + a 150-mana ultimate")
	T.eq(R.ManaNeeded(325, { 150, 100 }), 575, "Orb + ultimate + one more spell")
	T.eq(R.ManaNeeded(325, nil), 325, "no recast list")
end)

T.test("refresher: the old 2x-ultimate check let a refresh through that left no mana to recast", function()
	local R = rules()
	-- 300 mana, 150-mana ultimate: the old rule (mana >= 2 x 150) passed; after the 325-mana Orb nothing is left.
	T.eq(R.ManaOk(300, 325, { 150 }), false, "300 mana is not enough for Orb + ultimate")
	T.eq(R.ManaOk(475, 325, { 150 }), true, "475 mana is exactly enough")
	T.eq(R.ManaOk(400, 200, { 150 }), true, "the Shard is cheaper")
end)

local function spell(name, fields)
	local s = { name = name, learned = true, passive = false, toggle = false, cooldown = 12, cost = 100 }
	for k, v in pairs(fields or {}) do
		s[k] = v
	end
	return s
end

T.test("refresher: which spells count as useful (maintainer, 2026-11-21)", function()
	local R = rules()
	T.eq(R.IsUseful(spell("lion_impale")), true, "learned, active, 12s cooldown")
	T.eq(R.IsUseful(spell("lion_impale", { learned = false })), false, "not learned")
	T.eq(R.IsUseful(spell("x", { passive = true })), false, "passive")
	T.eq(R.IsUseful(spell("x", { toggle = true })), false, "toggle")
	T.eq(R.IsUseful(spell("x", { cooldown = 7 })), false, "cooldown under 8s")
	T.eq(R.IsUseful(spell("x", { cooldown = 8 })), true, "8s counts")
	T.eq(R.IsUseful(spell("item_refresher")), false, "the refresher itself")
	T.eq(R.IsUseful(spell("special_bonus_x", { talent = true })), false, "talent")
	T.eq(R.IsUseful(spell("x", { hidden = true })), false, "hidden slot")
end)

T.test("refresher: the combo mana counts the spells on cooldown, the ultimate once", function()
	local R = rules()
	local spells = {
		spell("ult", { ultimate = true, onCooldown = true, cost = 150 }),
		spell("stun", { onCooldown = true, cost = 100 }),
		spell("nuke", { ready = true, cost = 120 }),
		spell("aura", { passive = true, onCooldown = true, cost = 0 }),
		spell("short", { cooldown = 5, onCooldown = true, cost = 50 }),
	}
	local othersReady, needed, readyNames, comboNames = R.Combo(325, "ult", 150, spells)
	T.eq(othersReady, 1, "the nuke is still ready")
	T.eq(needed, 325 + 150 + 100, "Orb + ultimate + the stun on cooldown (the ready nuke is not refreshed)")
	T.eq(readyNames[1], "nuke", "ready names")
	T.eq(table.concat(comboNames, "+"), "ult+stun", "combo names")
	local none, onlyUlt = R.Combo(200, "ult", 150, {})
	T.eq(none, 0, "no other spells")
	T.eq(onlyUlt, 350, "Shard + ultimate")
end)

T.test("refresher: a ready spell holds the refresh up to 1s", function()
	local R = rules()
	local state = {}
	T.eq(R.HoldStep(state, 100, 0), "go", "nothing ready: refresh now")
	local step, started = R.HoldStep(state, 100, 1)
	T.eq(step, "hold", "a spell is ready: hold")
	T.eq(started, true, "the hold starts (log once)")
	local _, again = R.HoldStep(state, 100.5, 1)
	T.eq(again, false, "the same hold")
	T.eq(R.HoldStep(state, 100.5, 1), "hold", "0.5s: still holding")
	T.eq(R.HoldStep(state, 101.1, 1), "go", "after 1s: refresh even with the spell unused")
	T.eq(R.HoldStep(state, 100.6, 0), "go", "the spell went out: refresh")
	-- A later fight: an old hold doesn't skip the wait.
	T.eq(R.HoldStep(state, 110, 1), "hold", "a hold older than 5s starts again")
	R.ResetHold(state)
	T.eq(state.holdAt, nil, "reset after the refresh / when the fight ends")
	T.eq(R.HoldStep(state, 111, 1), "hold", "after a reset the next refresh holds again")
end)

T.test("refresher: movement spells neither hold the refresh nor count in its mana", function()
	local R = rules()
	T.eq(R.IsUseful(spell("zuus_heavenly_jump")), false, "Heavenly Jump")
	T.eq(R.IsUseful(spell("antimage_blink")), false, "Blink")
	-- Game 067, t=3818: Zeus, Thundergod's Wrath used, Nimbus on cooldown, Heavenly Jump ready (costs here are
	-- placeholders, the game read needed=1100).
	local spells = {
		spell("zuus_arc_lightning", { cooldown = 1.6, ready = true, cost = 80 }),
		spell("zuus_lightning_bolt", { cooldown = 6, ready = true, cost = 125 }),
		spell("zuus_heavenly_jump", { cooldown = 14, ready = true, cost = 100 }),
		spell("zuus_cloud", { cooldown = 40, onCooldown = true, cost = 275 }),
		spell("zuus_thundergods_wrath", { ultimate = true, cooldown = 130, onCooldown = true, cost = 400 }),
	}
	local othersReady, needed, readyNames, comboNames = R.Combo(325, "zuus_thundergods_wrath", 400, spells)
	T.eq(othersReady, 0, "the ready jump doesn't hold the refresh")
	T.eq(#readyNames, 0, "no ready names")
	T.eq(needed, 325 + 400 + 275, "Orb + Wrath + Nimbus")
	T.eq(table.concat(comboNames, "+"), "zuus_thundergods_wrath+zuus_cloud", "combo")
	T.eq(R.HoldStep({}, 3818, othersReady), "go", "refresh at once")
	-- On cooldown it isn't paid for either.
	spells[3].ready, spells[3].onCooldown = false, true
	local _, needed2 = R.Combo(325, "zuus_thundergods_wrath", 400, spells)
	T.eq(needed2, needed, "a jump on cooldown adds no mana")
end)
