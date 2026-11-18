-- Pudge: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
-- 1 Meat Hook, 2 Rot, 3 Meat Shield (pudge_flesh_heap), 6 Dismember. Entries skip talent levels;
-- Dismember stays at 6, 12 and 17. One point each in Hook, Rot, Meat Shield at levels 1-3, then
-- Meat Shield maxed (7), Rot (11), Meat Hook last (16). Same for every position (user call).
local PUDGE_SKILLS = { 1, 2, 3, 3, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 }
local tAllAbilityBuildList = { PUDGE_SKILLS, PUDGE_SKILLS, PUDGE_SKILLS }
local nAbilityBuildList = tAllAbilityBuildList[2]
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_3" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
if sRole == "pos_4" then
	nAbilityBuildList = tAllAbilityBuildList[3]
end
if sRole == "pos_5" then
	nAbilityBuildList = tAllAbilityBuildList[3]
end
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
if sRole == "pos_2" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
if sRole == "pos_3" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
if sRole == "pos_4" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[3])
end
if sRole == "pos_5" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[3])
end
local sTeamAura = "item_team_aura"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_bracer",
	"item_bottle",
	"item_magic_wand",
	"item_boots",
	"item_blink",
	"item_ultimate_scepter",
	"item_pipe",
	"item_travel_boots",
	"item_bloodstone",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_magic_wand",
	"item_boots",
	"item_bracer",
	"item_phase_boots",
	"item_blink",
	"item_pipe",
	"item_ultimate_scepter",
	"item_shivas_guard",
	sTeamAura,
	"item_black_king_bar",
	"item_travel_boots",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_tranquil_boots",
	"item_magic_wand",
	"item_rod_of_atos",
	"item_blink",
	"item_aghanims_shard",
	"item_boots_of_bearing",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_lotus_orb",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_flask",
	"item_enchanted_mango",
	"item_wind_lace",
	"item_blood_grenade",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_pipe",
	"item_blink",
	"item_aether_lens",
	"item_force_staff",
	"item_lotus_orb",
	"item_gungir",
	"item_overwhelming_blink",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_bracer",
	"item_magic_wand",
	"item_bracer",
	"item_boots",
	"item_blink",
	"item_ultimate_scepter",
	"item_pipe",
	"item_travel_boots",
	"item_bloodstone",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_aghanims_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minion)
	Minion.MinionThink(minion)
end
local squishyHookTargets = {
	["npc_dota_hero_sniper"] = true,
	["npc_dota_hero_drow_ranger"] = true,
	["npc_dota_hero_templar_assassin"] = true,
	["npc_dota_hero_nevermore"] = true,
	["npc_dota_hero_zuus"] = true,
	["npc_dota_hero_lina"] = true,
	["npc_dota_hero_silencer"] = true,
	["npc_dota_hero_arc_warden"] = true,
}
local meatHookDesire, meatHookLocation
local rotDesire
local meatShieldDesire
local dismemberDesire, dismemberTarget
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
-- Rot read as off right after it was turned on (game 020: "rot-on" 10 times a second while
-- farming, "rot-off" 11 times all game), so every think toggled it again and it flickered. It
-- counts as on when the toggle state or Rot's buff on Pudge says so, and it is toggled at most
-- once every 1.5s.
local function RotOn(rot)
	if rot == nil then
		return false
	end
	local ok, isOn = pcall(function()
		return rot:GetToggleState()
	end)
	return (ok and isOn == true) or GetBot():HasModifier("modifier_pudge_rot")
end
function X.ToggleRot(rot)
	local now = DotaTime()
	if now - (bot._rotToggleAt or -99) < 1.5 then
		return false
	end
	bot._rotToggleAt = now
	bot:Action_UseAbility(rot)
	return true
end
-- Hook follow-up (#73, game 043): the maintainer saw Pudge turn away after a landed hook. The hook goes out from any
-- mode (laning, farm, roam), and that mode walked him off on the next think. Landed = within 3s of the hook, an
-- enemy hero who was 600+ away at the cast is now within 350 of Pudge (or has the hook debuff; the modifier name
-- is not in the game files, so the distance test is the one that counts). Then for 3s: Rot on, Dismember if it can
-- be cast, else attack him. Not under 30% HP or with two more enemy heroes than allies around.
-- Logs: [OHA-PUDGE] hook-result landed|missed, follow=dismember|attack|none.
local function PudgeLine(fmt, ...)
	pcall(print, string.format("[OHA-PUDGE] t=%.0f " .. fmt, DotaTime(), ...))
end
local function ShortName(unit)
	return (string.gsub(unit:GetUnitName(), "npc_dota_hero_", ""))
end
function X.NoteHookCast()
	if bot._hookTrack ~= nil and DotaTime() - bot._hookTrack.at < 1 then
		return
	end
	local far = {}
	for _, enemyHero in pairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) and GetUnitToUnitDistance(bot, enemyHero) > 600 then
			far[enemyHero:GetUnitName()] = true
		end
	end
	bot._hookTrack = { at = DotaTime(), far = far }
end
function X.TrackHook()
	local track = bot._hookTrack
	if track == nil then
		return
	end
	if DotaTime() - track.at > 3 then
		bot._hookTrack = nil
		PudgeLine("hook-result missed mode=%d", bot:GetActiveMode())
		return
	end
	for _, enemyHero in pairs(bot:GetNearbyHeroes(350, true, BOT_MODE_NONE) or {}) do
		local debuff = Fu.IsValidHero(enemyHero) and enemyHero:HasModifier("modifier_pudge_meat_hook")
		if Fu.IsValidHero(enemyHero) and (track.far[enemyHero:GetUnitName()] or debuff) then
			bot._hookTrack = nil
			bot._hookFollow = { target = enemyHero, untilTime = DotaTime() + 3, logged = false }
			PudgeLine(
				"hook-result landed target=%s after=%.1f mode=%d hp=%.2f foes=%d allies=%d debuff=%s",
				ShortName(enemyHero),
				DotaTime() - track.at,
				bot:GetActiveMode(),
				Fu.GetHP(bot),
				#(bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}),
				#(bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {}) - 1,
				tostring(debuff)
			)
			return
		end
	end
end
-- Returns true when it gave an order.
function X.FollowHook(rotAbility, dismemberAbility, hpRatio)
	local follow = bot._hookFollow
	if follow == nil then
		return false
	end
	local target = follow.target
	if DotaTime() > follow.untilTime or not Fu.IsValidHero(target) or not target:IsAlive() then
		bot._hookFollow = nil
		return false
	end
	local foes = #(bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {})
	local friends = #(bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {})
	if hpRatio < 0.3 or foes >= friends + 2 then
		bot._hookFollow = nil
		PudgeLine(
			"follow=none why=unsafe target=%s hp=%.2f foes=%d allies=%d",
			ShortName(target),
			hpRatio,
			foes,
			friends - 1
		)
		return false
	end
	local castRange = dismemberAbility:GetCastRange() + 100
	if Fu.CanCastAbility(dismemberAbility) and GetUnitToUnitDistance(bot, target) <= castRange then
		bot._hookFollow = nil
		PudgeLine("follow=dismember target=%s", ShortName(target))
		bot:Action_ClearActions(false)
		if hpRatio > 0.3 and Fu.CanCastAbility(rotAbility) and not RotOn(rotAbility) then
			bot:ActionQueue_UseAbility(rotAbility)
		end
		bot:ActionQueue_UseAbilityOnEntity(dismemberAbility, target)
		return true
	end
	if hpRatio > 0.3 and not RotOn(rotAbility) and X.ToggleRot(rotAbility) then
		return true
	end
	if not follow.logged then
		follow.logged = true
		PudgeLine("follow=attack target=%s dist=%d", ShortName(target), GetUnitToUnitDistance(bot, target))
	end
	bot:Action_AttackUnit(target, true)
	return true
end
function X.SkillsComplement()
	pcall(X.TrackHook)
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	local meatHookAbility = SafeAbility(bot:GetAbilityByName("pudge_meat_hook"), "pudge_meat_hook", "pudge")
	local rotAbility = SafeAbility(bot:GetAbilityByName("pudge_rot"), "pudge_rot", "pudge")
	local meatShieldAbility = SafeAbility(bot:GetAbilityByName("pudge_flesh_heap"), "pudge_flesh_heap", "pudge")
	local dismemberAbility = SafeAbility(bot:GetAbilityByName("pudge_dismember"), "pudge_dismember", "pudge")
	botTarget = Fu.GetProperTarget(bot)
	local hpRatio = Fu.GetHP(bot)
	local rotRadius = rotAbility:GetSpecialValueInt("rot_radius")
	local enemiesInRotRange = Fu.GetNearbyHeroes(bot, rotRadius + 50, true, BOT_MODE_NONE)
	if X.BlinkComboStep(rotAbility, meatShieldAbility, dismemberAbility) then
		return
	end
	if X.FollowHook(rotAbility, dismemberAbility, hpRatio) then
		return
	end
	if X.BlinkHookStep(meatHookAbility) then
		return
	end
	if X.TryBlink(rotAbility, meatShieldAbility, dismemberAbility) then
		return
	end
	if X.TryBlinkHook(meatHookAbility) then
		return
	end
	meatShieldDesire =
		X.ConsiderMeatShield(meatShieldAbility, rotAbility, botTarget, hpRatio, rotRadius, enemiesInRotRange)
	if meatShieldDesire > 0 then
		bot:Action_UseAbility(meatShieldAbility)
		return
	end
	if RotOn(rotAbility) and #enemiesInRotRange <= 0 then
		if X.ToggleRot(rotAbility) then
			return
		end
	end
	meatHookDesire, meatHookLocation =
		X.ConsiderMeatHook(meatHookAbility, rotAbility, dismemberAbility, botTarget, hpRatio, enemiesInRotRange)
	if meatHookDesire > 0 then
		X.LogPudge("hook", hpRatio)
		X.NoteHookCast()
		bot:Action_UseAbilityOnLocation(meatHookAbility, meatHookLocation)
		return
	end
	rotDesire = X.ConsiderRot(rotAbility, botTarget, hpRatio, rotRadius, enemiesInRotRange)
	if rotDesire > 0 then
		if X.ToggleRot(rotAbility) then
			X.LogPudge(RotOn(rotAbility) and "rot-off" or "rot-on", hpRatio)
			return
		end
	end
	dismemberDesire, dismemberTarget = X.ConsiderDismember(dismemberAbility, botTarget, hpRatio, enemiesInRotRange)
	if dismemberDesire > 0 then
		X.LogPudge(
			"dismember "
				.. (
					Fu.IsValid(dismemberTarget)
						and (string.gsub(dismemberTarget:GetUnitName(), "npc_dota_hero_", ""))
					or "?"
				),
			hpRatio
		)
		bot:Action_ClearActions(false)
		if Fu.CanCastAbility(meatShieldAbility) and not bot:HasModifier("modifier_pudge_flesh_heap_block") then
			bot:ActionQueue_UseAbility(meatShieldAbility)
		end
		if hpRatio > 0.3 and Fu.CanCastAbility(rotAbility) and not RotOn(rotAbility) then
			bot:ActionQueue_UseAbility(rotAbility)
		end
		bot:ActionQueue_UseAbilityOnEntity(dismemberAbility, dismemberTarget)
		return
	end
end
-- After an engage blink, for 3s: Meat Shield, then Rot on, then Dismember on the blink target,
-- one order per think. Ends when Dismember goes out, the target is gone, or the 3s run out.
function X.BlinkComboStep(rot, shield, dismember)
	local comboState = bot._pudgeCombo
	if comboState == nil then
		return false
	end
	local comboTarget = comboState.target
	if DotaTime() - comboState.at > 3 or not Fu.IsValidHero(comboTarget) or not comboTarget:IsAlive() then
		bot._pudgeCombo = nil
		return false
	end
	if not comboState.shield then
		comboState.shield = true
		if shield ~= nil and Fu.CanCastAbility(shield) and not bot:HasModifier("modifier_pudge_flesh_heap_block") then
			X.LogPudge("blink-combo shield", Fu.GetHP(bot))
			bot:Action_UseAbility(shield)
			return true
		end
	end
	if not comboState.rot then
		comboState.rot = true
		if rot ~= nil and rot:IsTrained() and rot:IsFullyCastable() and not RotOn(rot) then
			if X.ToggleRot(rot) then
				X.LogPudge("blink-combo rot", Fu.GetHP(bot))
				return true
			end
		end
	end
	bot._pudgeCombo = nil
	if dismember ~= nil and Fu.CanCastAbility(dismember) and Fu.CanCastOnMagicImmune(comboTarget) then
		X.LogPudge(
			"blink-combo dismember " .. (string.gsub(comboTarget:GetUnitName(), "npc_dota_hero_", "")),
			Fu.GetHP(bot)
		)
		bot:Action_UseAbilityOnEntity(dismember, comboTarget)
		return true
	end
	return false
end
function X.TryBlink(rot, shield, dismember)
	if not Fu.CanBlinkDagger(bot) or bot.Blink == nil or bot:IsRooted() then
		return false
	end
	local blink = bot.Blink
	local range = 1200
	if blink:GetName() == "item_arcane_blink" then
		range = 1400
	end
	if isRetreating and bot:DistanceFromFountain() > 900 then
		local enemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		local ancient = GetAncient(GetTeam())
		if enemies ~= nil and #enemies >= 1 and ancient ~= nil then
			local dest = Fu.GetLocationTowardDistanceLocation(bot, ancient:GetLocation(), range)
			if IsLocationPassable(dest) then
				bot:Action_UseAbilityOnLocation(blink, dest)
				return true
			end
		end
	end
	-- Engage blink (chase or initiate), user call: no "target below 60% / disabled / alone" gate
	-- any more, which kept him from initiating. Needs 40%+ HP, and our heroes near the target
	-- (Pudge always counted) at least as many as theirs. The whole combo is queued at once:
	-- blink to point blank -> Meat Shield -> Rot on -> Dismember. It used to be the blink alone,
	-- and the next think could hook or Rot first.
	if
		isGoingOnSomeone
		and Fu.GetHP(bot) >= 0.4
		and Fu.IsValidHero(botTarget)
		and not Fu.IsSuspiciousIllusion(botTarget)
	then
		local dist = GetUnitToUnitDistance(bot, botTarget)
		if
			dist > 350
			and dist <= range + 150
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(botTarget:GetLocation())
		then
			local friends = 1
			for _, ally in pairs(Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1100) or {}) do
				if ally ~= bot then
					friends = friends + 1
				end
			end
			local foes = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1100) or {}
			if friends >= #foes then
				local dest = botTarget:GetLocation()
				if dist > range then
					dest = Fu.GetLocationTowardDistanceLocation(bot, botTarget:GetLocation(), range - 50)
				end
				if IsLocationPassable(dest) then
					-- One step per think after this (see BlinkComboStep): a queue behind the blink is
					-- wiped by the next order from the spell think or the mode.
					bot._pudgeCombo = { target = botTarget, at = DotaTime(), shield = false, rot = false }
					X.LogPudge(
						"blink-combo start target="
							.. (string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", ""))
							.. " dist="
							.. math.floor(dist),
						Fu.GetHP(bot)
					)
					bot:Action_UseAbilityOnLocation(blink, dest)
					return true
				end
			end
		end
	end
	return false
end
-- Blink then hook (user call): an enemy hero Pudge cannot hook from where he stands (out of range,
-- or a unit in the way) but could from a blink away. Blink to a spot on a ring around the target
-- (hook range - 250) that has a clear hook line, no enemy hero within 500, and is closest to an
-- allied hero or one of our towers (one of those within 1200), so the target is pulled into our
-- side; hook on the next think. Not while retreating, 50%+ HP, mana for the hook.
-- Logged: [OHA-PUDGE] blink-hook.
local function HookLineClear(from, to, width, target)
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
		if
			Fu.IsValid(unit)
			and unit ~= bot
			and unit ~= target
			and not unit:IsBuilding()
			and not string.find(unit:GetUnitName(), "ward")
			and GetUnitToLocationDistance(unit, from) <= 1600
		then
			local lineInfo = PointToLineDistance(from, to, unit:GetLocation())
			if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= width + unit:GetBoundingRadius() then
				return false
			end
		end
	end
	return true
end
local function NearestAnchor(point)
	local best = math.huge
	for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
		if ally ~= bot and ally:IsAlive() and not ally:IsIllusion() then
			best = math.min(best, GetUnitToLocationDistance(ally, point))
		end
	end
	for _, tower in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
		if tower ~= nil and tower:IsAlive() and tower:IsTower() then
			best = math.min(best, GetUnitToLocationDistance(tower, point))
		end
	end
	return best
end
function X.TryBlinkHook(hook)
	if not Fu.CanBlinkDagger(bot) or bot.Blink == nil or bot:IsRooted() or not Fu.CanCastAbility(hook) then
		return false
	end
	if isRetreating or Fu.GetHP(bot) < 0.5 or bot:GetMana() < hook:GetManaCost() then
		return false
	end
	local blinkRange = bot.Blink:GetName() == "item_arcane_blink" and 1400 or 1200
	local hookRange = Fu.GetProperCastRange(false, bot, hook:GetCastRange())
	local width = hook:GetSpecialValueInt("hook_width")
	local target = nil
	for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
		if
			Fu.IsValidHero(enemy)
			and not Fu.IsSuspiciousIllusion(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and not enemy:IsInvulnerable()
		then
			local distance = GetUnitToUnitDistance(bot, enemy)
			local hookableNow = distance <= hookRange - 100
				and HookLineClear(bot:GetLocation(), enemy:GetLocation(), width, enemy)
			if
				not hookableNow
				and distance > hookRange - 100 - blinkRange
				and distance <= blinkRange + hookRange - 250
			then
				if target == nil or Fu.GetHP(enemy) < Fu.GetHP(target) then
					target = enemy
				end
			end
		end
	end
	if target == nil then
		return false
	end
	local targetLocation = target:GetLocation()
	local ring = hookRange - 250
	local best, bestScore = nil, 1200
	for deg = 0, 330, 30 do
		local rad = math.rad(deg)
		local point =
			Vector(targetLocation.x + math.cos(rad) * ring, targetLocation.y + math.sin(rad) * ring, targetLocation.z)
		if
			GetUnitToLocationDistance(bot, point) <= blinkRange
			and IsLocationPassable(point)
			and #(Fu.GetEnemiesNearLoc(point, 500) or {}) == 0
			and HookLineClear(point, targetLocation, width, target)
		then
			local score = NearestAnchor(point)
			if score < bestScore then
				best, bestScore = point, score
			end
		end
	end
	if best == nil then
		return false
	end
	bot._pudgeBlinkHook = { target = target, at = DotaTime() }
	pcall(
		print,
		string.format(
			"[OHA-PUDGE] t=%.0f blink-hook start target=%s dist=%d anchor=%d",
			DotaTime(),
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			math.floor(GetUnitToUnitDistance(bot, target)),
			math.floor(bestScore)
		)
	)
	bot:Action_UseAbilityOnLocation(bot.Blink, best)
	return true
end
-- The hook after a blink-hook blink (Blink is instant; this runs on the next think).
function X.BlinkHookStep(hook)
	local blinkHookState = bot._pudgeBlinkHook
	if blinkHookState == nil then
		return false
	end
	bot._pudgeBlinkHook = nil
	local target = blinkHookState.target
	if
		DotaTime() - blinkHookState.at > 1.5
		or not Fu.IsValidHero(target)
		or not target:IsAlive()
		or not Fu.CanCastAbility(hook)
	then
		return false
	end
	local speed = math.max(1, hook:GetSpecialValueInt("hook_speed"))
	local distance = GetUnitToUnitDistance(bot, target)
	X.NoteHookCast()
	bot:Action_UseAbilityOnLocation(hook, target:GetExtrapolatedLocation(hook:GetCastPoint() + distance / speed))
	pcall(
		print,
		string.format(
			"[OHA-PUDGE] t=%.0f blink-hook hook target=%s dist=%d",
			DotaTime(),
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			math.floor(distance)
		)
	)
	return true
end
-- [OHA-PUDGE] one line per cast decision, with HP, mode and the heroes around him.
-- The combo, hooks, Rot and Dismember work as intended: no longer printed (call sites kept).
local LOG_PUDGE = false
function X.LogPudge(what, hp)
	if not LOG_PUDGE then
		return
	end
	pcall(function()
		local foes = #(Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {})
		local friends = #(Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) or {})
		print(
			string.format(
				"[OHA-PUDGE] t=%.0f %s hp=%.2f mode=%d engaging=%s retreating=%s foes=%d allies=%d",
				DotaTime(),
				what,
				hp or Fu.GetHP(bot),
				bot:GetActiveMode(),
				tostring(isGoingOnSomeone and true or false),
				tostring(isRetreating and true or false),
				foes,
				friends - 1
			)
		)
	end)
end
function X.ConsiderMeatHook(meatHookAbility, rotAbility, dismemberAbility, botTarget, hpRatio, enemiesInRotRange)
	if not meatHookAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, meatHookAbility:GetCastRange())
	local castPoint = meatHookAbility:GetCastPoint()
	local hookWidth = meatHookAbility:GetSpecialValueInt("hook_width")
	local hookSpeed = meatHookAbility:GetSpecialValueInt("hook_speed")
	local damage = meatHookAbility:GetSpecialValueInt("damage")
	local manaCost = meatHookAbility:GetManaCost()
	local tpTarget = Fu.GetTPTarget(bot, castRange)
	if tpTarget and not Fu.IsUnitBetweenMeAndLocation(bot, tpTarget, tpTarget:GetLocation(), hookWidth) then
		return BOT_ACTION_DESIRE_HIGH, tpTarget:GetLocation()
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
			if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
				if not Fu.IsUnitBetweenMeAndLocation(bot, enemyHero, enemyHero:GetLocation(), hookWidth) then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
			if enemyHero:HasModifier("modifier_teleporting") then
				local tpRemaining = Fu.GetModifierTime(enemyHero, "modifier_teleporting")
				local hookTravelTime = GetUnitToUnitDistance(bot, enemyHero) / hookSpeed + castPoint
				if
					tpRemaining > hookTravelTime
					and not Fu.IsUnitBetweenMeAndLocation(bot, enemyHero, enemyHero:GetLocation(), hookWidth)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PURE)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				local hitDelay = GetUnitToUnitDistance(bot, enemyHero) / hookSpeed + castPoint
				local predictedLocation = Fu.GetCorrectLoc(enemyHero, hitDelay)
				if
					not Fu.IsUnitBetweenMeAndLocation(bot, enemyHero, predictedLocation, hookWidth)
					and not Fu.IsLocationInChrono(predictedLocation)
					and not Fu.IsLocationInBlackHole(predictedLocation)
				then
					return BOT_ACTION_DESIRE_HIGH, predictedLocation
				end
			end
		end
	end
	-- Engage hooks need 40%+ HP: the hook drags an enemy onto him, which is a fight he has to win.
	if isGoingOnSomeone and hpRatio >= 0.4 then
		local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, true, 5)
		local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					nearbyAllyHeroes ~= nil
					and enemyAllies ~= nil
					and #nearbyAllyHeroes >= #enemyAllies
					and squishyHookTargets[enemyHero:GetUnitName()]
				then
					local hitDelay = GetUnitToUnitDistance(bot, enemyHero) / hookSpeed + castPoint
					local predictedLocation = Fu.GetCorrectLoc(enemyHero, hitDelay)
					if
						not Fu.IsUnitBetweenMeAndLocation(bot, enemyHero, predictedLocation, hookWidth)
						and not Fu.IsLocationInChrono(predictedLocation)
						and not Fu.IsLocationInBlackHole(predictedLocation)
					then
						return BOT_ACTION_DESIRE_HIGH, predictedLocation
					end
				end
			end
		end
		if
			Fu.IsValidTarget(strongestEnemy)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local enemyAllies = Fu.GetNearbyHeroes(strongestEnemy, 1200, false, BOT_MODE_NONE)
			if nearbyAllyHeroes ~= nil and enemyAllies ~= nil and #nearbyAllyHeroes >= #enemyAllies then
				local hitDelay = GetUnitToUnitDistance(bot, strongestEnemy) / hookSpeed + castPoint
				local predictedLocation = Fu.GetCorrectLoc(strongestEnemy, hitDelay)
				if
					not Fu.IsUnitBetweenMeAndLocation(bot, strongestEnemy, predictedLocation, hookWidth)
					and not Fu.IsLocationInChrono(predictedLocation)
					and not Fu.IsLocationInBlackHole(predictedLocation)
				then
					return BOT_ACTION_DESIRE_HIGH, predictedLocation
				end
			end
		end
	end
	if Fu.IsLaning(bot) then
		local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { rotAbility, dismemberAbility })
		if Fu.GetMP(bot) < manaThreshold then
		else
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and not Fu.IsRunning(creep)
					and Fu.CanBeAttacked(creep)
					and Fu.IsKeyWordUnit("siege", creep)
					and creep:GetHealth() <= damage
				then
					local nearbyEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
					if
						(
							Fu.IsValid(nearbyEnemyHeroes[1])
								and GetUnitToUnitDistance(nearbyEnemyHeroes[1], creep) < 500
							or not Fu.IsInRange(bot, creep, bot:GetAttackRange() + 25)
						)
						and not Fu.IsUnitBetweenMeAndLocation(bot, creep, creep:GetLocation(), hookWidth)
						and (Fu.IsCore(bot) or not Fu.IsCore(bot) and not Fu.IsThereCoreNearby(1200))
					then
						return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
					end
				end
			end
			local allyTowers = bot:GetNearbyTowers(700, false)
			local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			if
				Fu.IsValidBuilding(allyTowers[1])
				and Fu.IsValidHero(enemiesInCastRange[1])
				and Fu.IsInRange(bot, allyTowers[1], 500)
			then
				local towerTarget = allyTowers[1]:GetAttackTarget()
				if towerTarget == nil then
					for _, enemyHero in pairs(enemiesInCastRange) do
						if
							Fu.IsValidHero(enemyHero)
							and not Fu.IsSuspiciousIllusion(enemyHero)
							and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
							and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
						then
							local hitDelay = GetUnitToUnitDistance(bot, enemyHero) / hookSpeed + castPoint
							local predictedLocation = Fu.GetCorrectLoc(enemyHero, hitDelay)
							if not Fu.IsUnitBetweenMeAndLocation(bot, enemyHero, predictedLocation, hookWidth) then
								return BOT_ACTION_DESIRE_HIGH, predictedLocation
							end
						end
					end
				end
			end
		end
	end
	local alliesInHookRange = bot:GetNearbyHeroes(castRange, false, BOT_MODE_NONE)
	for _, ally in pairs(alliesInHookRange) do
		if
			Fu.IsValidHero(ally)
			and not ally:IsIllusion()
			and (ally:HasModifier("modifier_enigma_black_hole_pull") or ally:HasModifier(
				"modifier_faceless_void_chronosphere_freeze"
			))
			and not Fu.IsUnitBetweenMeAndLocation(bot, ally, ally:GetLocation(), hookWidth)
		then
			return BOT_ACTION_DESIRE_HIGH, ally:GetLocation()
		end
		-- Save hook on an ally running from a chaser (user call, rework): the ally must be in hook
		-- range and 400+ away (a pull worth having), the chaser within 700 of the ALLY (it used to be
		-- "within half a hook range of Pudge", so it fired only with the enemy already on Pudge and
		-- never checked the ally's own distance), and Pudge 300+ closer to safety than the ally (it
		-- was half a hook range, keeping Pudge too far back). Logged: [OHA-PUDGE] ally-hook.
		local allyDist = GetUnitToUnitDistance(bot, ally)
		if
			Fu.IsValidHero(ally)
			and ally ~= bot
			and not ally:IsIllusion()
			and Fu.IsRetreating(ally)
			and ally:WasRecentlyDamagedByAnyHero(2.1)
			and Fu.IsRunning(ally)
			and Fu.GetMP(bot) > 0.31
			and allyDist >= 400
			and allyDist <= castRange
		then
			local chaser = nil
			for _, enemy in pairs(ally:GetNearbyHeroes(700, true, BOT_MODE_NONE) or {}) do
				if
					Fu.IsValidHero(enemy)
					and not Fu.IsSuspiciousIllusion(enemy)
					and not Fu.IsDisabled(enemy)
					and not Fu.IsTaunted(enemy)
					and enemy:IsFacingLocation(ally:GetLocation(), 30)
					and not enemy:HasModifier("modifier_enigma_black_hole_pull")
					and not enemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not enemy:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					chaser = enemy
					break
				end
			end
			local escapeLocation = Fu.GetEscapeLoc()
			if
				chaser ~= nil
				and GetUnitToLocationDistance(ally, escapeLocation) - GetUnitToLocationDistance(bot, escapeLocation) >= 300
				and not Fu.IsUnitBetweenMeAndLocation(bot, ally, ally:GetLocation(), hookWidth)
			then
				pcall(
					print,
					string.format(
						"[OHA-PUDGE] t=%.0f ally-hook %s chaser=%s dist=%d",
						DotaTime(),
						(string.gsub(ally:GetUnitName(), "npc_dota_hero_", "")),
						(string.gsub(chaser:GetUnitName(), "npc_dota_hero_", "")),
						math.floor(allyDist)
					)
				)
				return BOT_ACTION_DESIRE_HIGH, ally:GetLocation()
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and not Fu.IsUnitBetweenMeAndLocation(bot, botTarget, botTarget:GetLocation(), hookWidth)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 400)
			and isAttacking
			and not Fu.IsUnitBetweenMeAndLocation(bot, botTarget, botTarget:GetLocation(), hookWidth)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderRot(rotAbility, botTarget, hpRatio, rotRadius, enemiesInRotRange)
	if not rotAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if RotOn(rotAbility) and #enemiesInRotRange <= 0 then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Rot hurts Pudge too (Valve data: non-lethal self damage). In fights it stayed on at any HP;
	-- now off below 30% while engaging and below 40% while running away.
	local rotFloor = isRetreating and 0.4 or 0.3
	if (isGoingOnSomeone or isRetreating) and hpRatio < rotFloor then
		if RotOn(rotAbility) then
			return BOT_ACTION_DESIRE_HIGH
		end
		return BOT_ACTION_DESIRE_NONE
	end
	if isGoingOnSomeone then
		for _, enemyHero in pairs(enemiesInRotRange) do
			if
				Fu.IsValidHero(enemyHero)
				and (Fu.CanCastOnNonMagicImmune(enemyHero) or #enemiesInRotRange >= 2)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				if RotOn(rotAbility) == false then
					return BOT_ACTION_DESIRE_HIGH
				else
					return BOT_ACTION_DESIRE_NONE
				end
			end
		end
	end
	if isRetreating then
		for _, enemyHero in pairs(enemiesInRotRange) do
			if
				Fu.IsValidHero(enemyHero)
				and (Fu.CanCastOnNonMagicImmune(enemyHero) or #enemiesInRotRange >= 2)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				if RotOn(rotAbility) == false then
					return BOT_ACTION_DESIRE_HIGH
				else
					return BOT_ACTION_DESIRE_NONE
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(rotRadius, true)
		if laneCreeps ~= nil then
			if #laneCreeps >= 1 and RotOn(rotAbility) == false and isAttacking and hpRatio > 0.2 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#laneCreeps == 0 or hpRatio < 0.2) and RotOn(rotAbility) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(rotRadius)
		if neutralCreeps ~= nil then
			if #neutralCreeps >= 1 and RotOn(rotAbility) == false and isAttacking and hpRatio > 0.35 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#neutralCreeps == 0 or hpRatio < 0.35) and RotOn(rotAbility) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(rotRadius, true)
		if laneCreeps ~= nil then
			if #laneCreeps >= 1 and RotOn(rotAbility) == false and isAttacking and hpRatio > 0.2 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#laneCreeps == 0 or hpRatio < 0.2) and RotOn(rotAbility) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsLaning(bot) and (Fu.IsCore(bot) or not Fu.IsCore(bot) and not Fu.IsThereNonSelfCoreNearby(1200)) then
		local laneCreeps = bot:GetNearbyLaneCreeps(rotRadius, true)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if laneCreeps ~= nil and nearbyEnemyHeroes ~= nil and #nearbyEnemyHeroes == 0 then
			if #laneCreeps >= 1 and RotOn(rotAbility) == false and isAttacking and hpRatio > 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#laneCreeps == 0 or hpRatio < 0.5) and RotOn(rotAbility) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, rotRadius)
			and isAttacking
			and hpRatio > 0.4
		then
			if RotOn(rotAbility) == false and hpRatio > 0.4 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if hpRatio < 0.4 and RotOn(rotAbility) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, rotRadius) and isAttacking then
			if RotOn(rotAbility) == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				if hpRatio < 0.65 and RotOn(rotAbility) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderMeatShield(meatShieldAbility, rotAbility, botTarget, hpRatio, rotRadius, enemiesInRotRange)
	if not Fu.CanCastAbility(meatShieldAbility) or bot:HasModifier("modifier_pudge_flesh_heap_block") then
		return BOT_ACTION_DESIRE_NONE
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
	local engaged = nearbyEnemies ~= nil
		and #nearbyEnemies >= 1
		and (
			isGoingOnSomeone
			or isRetreating
			or bot:WasRecentlyDamagedByAnyHero(2.0)
			or bot:WasRecentlyDamagedByTower(1.5)
		)
	if engaged then
		return BOT_ACTION_DESIRE_HIGH
	end
	local rotOn = RotOn(rotAbility)
	local wantsRot = not rotOn and X.ConsiderRot(rotAbility, botTarget, hpRatio, rotRadius, enemiesInRotRange) > 0
	if (rotOn or wantsRot) and ((enemiesInRotRange ~= nil and #enemiesInRotRange >= 1) or hpRatio < 0.7) then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderDismember(dismemberAbility, botTarget, hpRatio, enemiesInRotRange)
	if not dismemberAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, dismemberAbility:GetCastRange())
	local strength = bot:GetAttributeValue(ATTRIBUTE_STRENGTH)
	local strengthDamageMultiplier = dismemberAbility:GetSpecialValueFloat("strength_damage")
	local channelTime = dismemberAbility:GetSpecialValueFloat("AbilityChannelTime")
	local damage = dismemberAbility:GetSpecialValueInt("dismember_damage") + strength * strengthDamageMultiplier
	if isGoingOnSomeone then
		local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, true, 5)
		if
			Fu.IsValidTarget(strongestEnemy)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_abaddon_borrowed_time")
			and not strongestEnemy:HasModifier("modifier_dazzle_shallow_grave")
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
			and not strongestEnemy:HasModifier("modifier_templar_assassin_refraction_absorb")
			and (Fu.CanCastOnNonMagicImmune(strongestEnemy) or Fu.CanCastOnMagicImmune(strongestEnemy))
		then
			local enemyAllies = Fu.GetNearbyHeroes(strongestEnemy, 1200, false, BOT_MODE_NONE)
			if nearbyAllyHeroes ~= nil and enemyAllies ~= nil and #nearbyAllyHeroes >= #enemyAllies then
				return BOT_ACTION_DESIRE_HIGH, strongestEnemy
			end
		end
	end
	if isRetreating then
		local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local weakestEnemy = Fu.GetAttackableWeakestUnit(bot, castRange, true, true)
		if
			Fu.IsValidTarget(weakestEnemy)
			and not Fu.IsSuspiciousIllusion(weakestEnemy)
			and not weakestEnemy:HasModifier("modifier_abaddon_borrowed_time")
			and not weakestEnemy:HasModifier("modifier_dazzle_shallow_grave")
			and not weakestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
			and not weakestEnemy:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			-- Running away: only a Dismember that kills. It went on the weakest enemy whenever the
			-- enemies outnumbered us, or below 20% HP, which kept him channelling 2.75s in place
			-- while outnumbered.
			if
				Fu.IsInRange(bot, weakestEnemy, castRange)
				and Fu.WillKillTarget(weakestEnemy, damage, DAMAGE_TYPE_MAGICAL, channelTime)
			then
				return BOT_ACTION_DESIRE_HIGH, weakestEnemy
			end
		end
	end
	if Fu.IsInLaningPhase(bot) then
		local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange + 100, true, BOT_MODE_NONE)
		local enemyTowers = bot:GetNearbyTowers(700, true)
		if enemiesInCastRange ~= nil and #enemiesInCastRange == 1 and enemyTowers ~= nil and #enemyTowers == 0 then
			if
				Fu.IsValidHero(enemiesInCastRange[1])
				and Fu.WillKillTarget(enemiesInCastRange[1], damage, DAMAGE_TYPE_MAGICAL, channelTime)
				and not Fu.IsSuspiciousIllusion(enemiesInCastRange[1])
				and not enemiesInCastRange[1]:HasModifier("modifier_abaddon_borrowed_time")
				and not enemiesInCastRange[1]:HasModifier("modifier_dazzle_shallow_grave")
				and not enemiesInCastRange[1]:HasModifier("modifier_oracle_false_promise_timer")
				and not enemiesInCastRange[1]:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesInCastRange[1]
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
