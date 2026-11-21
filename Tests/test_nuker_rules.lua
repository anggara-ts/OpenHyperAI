-- FuncLib/systems/nuker_rules.lua: Death Prophet's Crypt Swarm mana rules and Lina's solo combo (#47).
-- Values from Valve's datafeed (hero_id 43 Death Prophet, hero_id 25 Lina).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_lina" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/nuker_rules")
end

T.test("ultimate reserve: kept only while the ultimate is learned, idle and coming", function()
	local R = rules()
	T.eq(R.UltReserve(false, 200, 0, false), 0, "Exorcism not learned")
	T.eq(R.UltReserve(true, 200, 0, false), 200, "Exorcism ready")
	T.eq(R.UltReserve(true, 300, 10, false), 300, "Exorcism back in 10s")
	T.eq(R.UltReserve(true, 300, 60, false), 0, "Exorcism back in 60s")
	T.eq(R.UltReserve(true, 300, 0, true), 0, "Exorcism already running")
end)

T.test("fight reserve: kept only while she has the ultimate's mana", function()
	local R = rules()
	T.eq(R.FightReserve(400, 300), 300, "400 mana, Exorcism 300: keep it")
	T.eq(R.FightReserve(250, 300), 0, "250 mana, Exorcism 300: she can't cast it anyway, fight on")
	T.eq(R.FightReserve(250, 0), 0, "no ultimate coming")
end)

T.test("can spend: the reserve stays after the cast", function()
	local R = rules()
	T.eq(R.CanSpend(300, 90, 200), true, "300 - 90 leaves 210 >= 200")
	T.eq(R.CanSpend(280, 90, 200), false, "280 - 90 leaves 190 < 200")
end)

T.test("spare mana: regen pays the swarm back within its cooldown, or mana is full", function()
	local R = rules()
	-- Level 1: Crypt Swarm 80 mana, 10s cooldown, base regen 1.7/s (datafeed): only full mana counts.
	T.eq(R.SpareMana(300, 363, 80, 10, 1.7, 0), false, "83% mana, 17 mana per cooldown")
	T.eq(R.SpareMana(340, 363, 80, 10, 1.7, 0), true, "94% mana: regen wasted")
	-- Later: Crypt Swarm 110 mana, 7s cooldown, 16 mana/s regen pays it back.
	T.eq(R.SpareMana(700, 1500, 110, 7, 16, 0), true, "regen 16/s * 7s = 112 >= 110")
	T.eq(R.SpareMana(700, 1500, 110, 7, 15, 0), false, "regen 15/s * 7s = 105 < 110")
	-- The reserve (Exorcism 300 + Silence 110) holds even at full mana.
	T.eq(R.SpareMana(450, 480, 110, 7, 2, 410), false, "full mana but 340 left < 410 kept")
	T.eq(R.SpareMana(480, 500, 60, 7, 2, 410), true, "full mana, 420 left >= 410 kept")
	T.eq(R.SpareMana(nil, 500, 60, 7, 2, 0), false, "no mana read")
end)

T.test("lane harass: Dragon Slave goes when it pushes the enemy under 60%", function()
	local R = rules()
	T.eq(R.HarassPushesOut(500, 600, 80), false, "420 of 600 = 70%")
	T.eq(R.HarassPushesOut(440, 600, 80), true, "360 of 600 = 60%")
	T.eq(R.HarassPushesOut(400, 600, 50), true, "350 of 600 = 58%")
	T.eq(R.HarassPushesOut(500, 600, 50), false, "450 of 600 = 75%")
	T.eq(R.HarassPushesOut(100, 0, 50), false, "no max HP")
end)

local function combo(overrides)
	local s = {
		disabled = false,
		hp = 800,
		mana = 700,
		lsaReady = true,
		lsaInRange = true,
		lsaCost = 100,
		lsaDamage = 80 * 0.75,
		slaveReady = true,
		slaveInRange = true,
		slaveCost = 90,
		slaveDamage = 245 * 0.75,
		lagunaReady = true,
		lagunaInRange = true,
		lagunaCost = 150,
		lagunaDamage = 360 * 0.75,
	}
	for key, value in pairs(overrides) do
		s[key] = value
	end
	return s
end

T.test("lina combo: LSA opens it on a free target the combo nearly kills", function()
	local R = rules()
	-- 60 + 184 + 270 = 514 damage; 600 HP needs 510 (85%).
	local step, why = R.LinaComboStep(combo({ hp = 600 }))
	T.eq(step, "lsa", "step")
	T.eq(why, "kill", "why")
	T.eq(R.LinaComboStep(combo({ hp = 800 })), nil, "514 of 800 is not near a kill")
end)

T.test("lina combo: a held target gets the next spell in order", function()
	local R = rules()
	local step, why = R.LinaComboStep(combo({ hp = 600, disabled = true }))
	T.eq(step, "lsa", "held: LSA still first (chains the stun)")
	T.eq(why, "disabled", "why")
	step = R.LinaComboStep(combo({ hp = 400, disabled = true, lsaReady = false }))
	T.eq(step, "slave", "LSA used: Dragon Slave next")
	step = R.LinaComboStep(combo({ hp = 300, disabled = true, lsaReady = false, slaveReady = false }))
	T.eq(step, "laguna", "then Laguna Blade")
	step = R.LinaComboStep(combo({ hp = 400, disabled = true, lsaInRange = false }))
	T.eq(step, "slave", "out of LSA range: Dragon Slave first")
end)

T.test("lina combo: once opened it runs to Laguna Blade on the held target", function()
	local R = rules()
	-- Opens at 600 HP: 60 + 184 + 270 = 514 >= 510.
	T.eq(R.LinaComboStep(combo({ hp = 600 })), "lsa", "open")
	-- LSA on its way (pending), on cooldown: Slave + Laguna = 454 < 510, but the combo is committed.
	T.eq(R.LinaComboStep(combo({ hp = 600, lsaReady = false })), nil, "not committed: the damage check alone stalls")
	local step, why = R.LinaComboStep(combo({ hp = 600, lsaReady = false, disabled = true, committed = true }))
	T.eq(step, "slave", "committed: Dragon Slave next")
	T.eq(why, "disabled", "why")
	-- LSA and Slave landed: 600 - 60 - 184 = 356 HP; Laguna's 270 is under 85% of it, still goes.
	step = R.LinaComboStep(combo({ hp = 356, lsaReady = false, slaveReady = false, disabled = true, committed = true }))
	T.eq(step, "laguna", "committed: Laguna Blade last")
	-- The stun ended (or LSA missed): back to the damage check.
	T.eq(
		R.LinaComboStep(combo({ hp = 356, lsaReady = false, slaveReady = false, committed = true })),
		nil,
		"committed but free: no Laguna"
	)
end)

T.test("lina combo: no stun to open it, or not enough mana, means no combo", function()
	local R = rules()
	T.eq(R.LinaComboStep(combo({ hp = 400, lsaReady = false })), nil, "free target, no LSA")
	T.eq(R.LinaComboStep(combo({ hp = 400, lsaInRange = false })), nil, "free target, LSA out of range")
	-- 200 mana: LSA (100) + Slave (90), no Laguna: 244 damage of 600 HP.
	T.eq(R.LinaComboStep(combo({ hp = 600, mana = 200 })), nil, "mana for LSA + Slave only")
	T.eq(R.LinaComboStep(combo({ hp = 280, mana = 200 })), "lsa", "LSA + Slave nearly kill 280 HP")
	T.eq(R.LinaComboStep(combo({ hp = 0 })), nil, "dead target")
end)
