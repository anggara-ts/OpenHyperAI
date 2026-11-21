-- FuncLib/systems/team_roam_rules.lua (#165, mode flip-flops): team roam's desire cut, which hunts stay a mode, the
-- running hunt's exit rules, when the last-hit overlay holds back, and the special-unit cap below retreat.
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_zuus" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/team_roam_rules")
end

T.test("team roam rules: desire cut as adjustDesire did", function()
	local R = rules()
	T.eq(R.AdjustDesire(1.5, true, false), 0.5, "snipe while pushing")
	T.eq(R.AdjustDesire(1.5, false, true), 0.72, "snipe in the laning phase")
	T.eq(R.AdjustDesire(1.5, true, true), 0.5, "pushing first")
	T.eq(R.AdjustDesire(0.64, false, true), 0.64, "the hunt's 0.64 is not cut in lane")
	T.eq(R.AdjustDesire(0.64, true, false), 0.5, "but is while pushing")
	T.eq(R.AdjustDesire(1.5, false, false), 1.5, "no cut")
end)

T.test("team roam rules: only hero and courier hunts need the mode", function()
	local R = rules()
	T.ok(R.HuntNeedsMode("hero"), "hero")
	T.ok(R.HuntNeedsMode("courier"), "courier")
	for _, kind in ipairs({ "lane", "deny", "neutral", "building", "ally", "?" }) do
		T.ok(not R.HuntNeedsMode(kind), kind .. ": overlay")
	end
end)

T.test("team roam rules: a running hunt keeps the mode until an exit rule", function()
	local R = rules()
	local ranged, melee = R.HuntKeepRange(600), R.HuntKeepRange(150)
	T.near(ranged, 1350, 0.01, "ranged keep range")
	T.near(melee, 675, 0.01, "melee keep range")
	T.eq(R.HuntExitWhy(true, 500, ranged, 2, 1), nil, "valid, close, not outnumbered: keep")
	T.eq(R.HuntExitWhy(true, 1200, ranged, 1, 1), nil, "even numbers: keep")
	T.eq(R.HuntExitWhy(false, 0, ranged, 2, 1), "lost", "dead / not visible")
	T.eq(R.HuntExitWhy(true, 1400, ranged, 2, 1), "range", "ran out of 1.5x range")
	T.eq(R.HuntExitWhy(true, 700, melee, 2, 1), "range", "melee range is shorter")
	T.eq(R.HuntExitWhy(true, 500, ranged, 1, 2), "outnumbered", "backup arrived")
	-- The sticky hero hunt starts at up to 1600: a melee hero at 1000 keeps it (1.5x the start distance).
	local meleeFar = R.HuntKeepRange(150, 1000)
	T.near(meleeFar, 1500, 0.01, "melee started at 1000")
	T.eq(R.HuntExitWhy(true, 1000, meleeFar, 2, 1), nil, "not ended on its first think")
	T.eq(R.HuntExitWhy(true, 1600, meleeFar, 2, 1), "range", "ran away")
end)

T.test("team roam rules: the last-hit overlay holds back", function()
	local R = rules()
	local function state(over)
		local s = { desire = 1.5, modeDesire = 0.6 }
		for k, v in pairs(over or {}) do
			s[k] = v
		end
		return s
	end
	T.eq(R.OverlaySkipWhy(state()), nil, "snipe 1.50 over farm 0.60: hit")
	T.eq(R.OverlaySkipWhy(state({ desire = 0.72, modeDesire = 0.95 })), "mode", "lane-cut snipe under attack 0.95")
	T.eq(R.OverlaySkipWhy(state({ desire = 1.5, modeDesire = 1.5 })), "mode", "tie with Vendetta's 1.50 hold")
	T.eq(R.OverlaySkipWhy(state({ retreat = true, modeDesire = 0.3 })), "retreat", "retreat at any desire")
	T.eq(R.OverlaySkipWhy(state({ evasive = true })), "evasive", "dodging")
	T.eq(R.OverlaySkipWhy(state({ invisible = true })), "invisible", "Skeleton Walk / Shadow Blade")
	T.eq(R.OverlaySkipWhy(state({ charging = true, modeDesire = 1.2 })), "charging", "Charge of Darkness")
	T.eq(R.OverlaySkipWhy(state({ channeling = true, busy = true })), "channel", "channeling before busy")
	T.eq(R.OverlaySkipWhy(state({ busy = true })), "busy", "casting")
	T.eq(R.OverlaySkipWhy(state({ heroFight = true })), "fight", "attack mode on an enemy hero in range")
	T.eq(R.OverlaySkipWhy(state({ charging = true, heroFight = true })), "charging", "a hunting spell first")
	T.eq(R.OverlaySkipWhy({ modeDesire = 0.6 }), "mode", "no desire")
end)

T.test("team roam rules: special units never above retreat when outnumbered", function()
	local R = rules()
	-- Game 063, 15:38: Zeus, full HP, hard retreat 0.70 (2 allies, 4 enemies); a special unit at 0.96.
	local d, cut = R.SpecialUnitCap(0.96, 2, 4, 0.70, false)
	T.ok(cut and d < 0.70, "Zeus 15:38 capped below retreat: " .. tostring(d))
	T.near(d, 0.65, 0.001, "retreat - 0.05")
	d, cut = R.SpecialUnitCap(0.96, 1, 4, 1.0, false)
	T.ok(cut and d < 1.0, "alone, retreat 1.0")
	d, cut = R.SpecialUnitCap(0.96, 3, 2, 0.70, false)
	T.eq(d, 0.96, "we outnumber them: no cap")
	T.ok(not cut, "not cut")
	d, cut = R.SpecialUnitCap(0.96, 1, 3, 0, false)
	T.eq(d, 0.96, "retreat wants nothing: no cap")
	d, cut = R.SpecialUnitCap(0.96, 1, 3, nil, false)
	T.eq(d, 0.96, "retreat unknown: no cap")
	d, cut = R.SpecialUnitCap(1.2, 1, 3, 0.9, true)
	T.eq(d, 1.2, "serpent ward escape is exempt")
	d, cut = R.SpecialUnitCap(0.4, 1, 3, 0.9, false)
	T.eq(d, 0.4, "already below retreat")
	T.ok(not cut, "not cut")
	d = R.SpecialUnitCap(0.9, 1, 3, 0.03, false)
	T.eq(d, 0, "never negative")
end)

T.test("team roam rules: which modes the overlay can hold, and the snipe's path", function()
	local R = rules()
	for _, mode in ipairs({ "laning", "farm", "push_tower_mid", "assemble", "rune", "ward", "roshan", "team_roam" }) do
		T.ok(R.ModeHoldable(mode, false), mode .. ": Lua Think")
	end
	for _, mode in ipairs({ "defend_tower_top", "item", "side_shop", "roam", "defend_ally", "evasive_maneuvers" }) do
		T.ok(not R.ModeHoldable(mode, false), mode .. ": Valve's Think")
	end
	T.ok(not R.ModeHoldable("attack", false), "Valve's attack mode")
	T.ok(not R.ModeHoldable("attack", nil), "Valve's attack mode (flag unset)")
	T.ok(R.ModeHoldable("attack", true), "our attack override")
	-- SnipePath(holdable, heroFight, hunting, modeWinRunning)
	T.eq(R.SnipePath(true, false, false, false), "overlay", "farm: the overlay")
	T.eq(R.SnipePath(false, false, false, false), "mode", "Valve's defend: win the mode as before")
	T.eq(R.SnipePath(true, false, false, true), "mode", "team roam won it with the snipe: keep the mode")
	T.eq(R.SnipePath(false, true, false, false), "none", "attack on an enemy hero in range: no snipe")
	T.eq(R.SnipePath(true, false, true, true), "none", "hunting spell trace open: no snipe")
end)

T.test("team roam rules: the overlay's hold on a hit", function()
	local R = rules()
	local function hold(over)
		local o = { now = 100.2, since = 100, alive = true, lastAttack = 99, ownAttack = 99, windup = 0.35 }
		for k, v in pairs(over or {}) do
			o[k] = v
		end
		return R.OverlayHoldWhy(o)
	end
	T.eq(hold(), nil, "walking to the creep: held")
	T.eq(hold({ lastAttack = 100.1 }), nil, "attack started 0.1s ago: in the wind-up, held")
	T.eq(hold({ lastAttack = 99.8 }), "hit", "attack 0.4s ago: released")
	T.eq(hold({ alive = false }), "dead", "the creep died")
	T.eq(hold({ free = true }), "free", "retreat / dodging")
	T.eq(hold({ now = 101.0 }), "cap", "1s without an attack")
	T.eq(hold({ now = 100.99 }), nil, "just under the cap")
	T.eq(R.HOLD_CAP, 1.0, "cap")
end)

T.test("team roam rules: courier hunt in the laning phase (#165, game 067)", function()
	local R = rules()
	local function c(over)
		local base = {
			dist = 800,
			attackRange = 650,
			level = 5,
			laning = true,
			pushing = false,
			enemiesNearCourier = 0,
			retreating = false,
			onRune = false,
			hp = 0.9,
		}
		for k, v in pairs(over or {}) do
			base[k] = v
		end
		return base
	end
	-- Team roam's attack range 650 (+50 included) at level 5: the old range was 680; lane range is 1050.
	T.eq(R.CourierRange(650, 5, false), 680, "after laning: attack range + 2x level + 20")
	T.eq(R.CourierRange(650, 5, true), 1050, "in lane: attack range + 400")
	T.eq(R.CourierSkipWhy(c()), nil, "a courier 800 away in lane, nobody near it: hunt")
	T.eq(R.CourierSkipWhy(c({ dist = 1100 })), "range", "beyond attack range + 400")
	T.eq(R.CourierSkipWhy(c({ enemiesNearCourier = 1 })), "enemies", "an enemy hero by the courier")
	T.eq(R.CourierSkipWhy(c({ onRune = true })), "rune", "walking to or holding a rune")
	T.eq(R.CourierSkipWhy(c({ retreating = true })), "retreat", "retreating")
	T.eq(R.CourierSkipWhy(c({ hp = 0.25 })), "hp", "low HP")
	T.eq(R.CourierSkipWhy(c({ pushing = true })), "pushing", "pushing")
	T.eq(R.CourierSkipWhy(c({ laning = false, dist = 800 })), "range", "after laning the old range holds")
	T.eq(
		R.CourierSkipWhy(c({ laning = false, dist = 600, enemiesNearCourier = 2 })),
		nil,
		"after laning: no enemy check"
	)
end)

T.test("team roam rules: a new overlay hit skips long hunt walks and snipes an allied core reaches first", function()
	local R = rules()
	T.eq(R.NewHitSkipWhy("hunt-carry/lane", 453, {}), "far", "a hunt-* walk of 453 (game 067 push misses)")
	T.eq(R.NewHitSkipWhy("hunt-support/lane", 72, {}), nil, "a short hunt-* walk")
	T.eq(R.NewHitSkipWhy("snipe", 453, {}), nil, "the walk cap is for hunt-* only")
	T.eq(R.NewHitSkipWhy("snipe", 200, { 50 }), "ally-first", "an allied core closer to its swing")
	T.eq(R.NewHitSkipWhy("snipe", 200, { 250, 300 }), nil, "allied cores farther from their swing")
	T.eq(R.NewHitSkipWhy("snipe", 0, { -100 }), nil, "already in range: still swings")
	T.eq(R.NewHitSkipWhy("hunt-carry/lane", 100, { -100 }), nil, "ally-first is for the snipe only")
end)
