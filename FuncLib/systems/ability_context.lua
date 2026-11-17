-- Shared bot system: ability context.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = {}
-- Cornered: running has stopped working. Retreating (or below 40% HP) with 3+ enemy heroes
-- within 900, at most one ally close by, and no way out (rooted, slowed to 250 or less, or low
-- and being hit with 2+ enemies on him). Centaur 1v4 and Earthshaker in five enemies (37:00)
-- kept running under heavy slows with Stampede / Echo Slam unused.
function AbilityContext.IsCornered(unit)
	if unit == nil or not unit:IsAlive() or unit:IsIllusion() then
		return false, nil
	end
	local hp = Fu.GetHP(unit)
	if not Fu.IsRetreating(unit) and hp >= 0.4 then
		return false, nil
	end
	local foes = {}
	for _, enemy in pairs(Fu.GetNearbyHeroes(unit, 900, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
			foes[#foes + 1] = enemy
		end
	end
	if #foes < 3 then
		return false, nil
	end
	local friends = 0
	for _, ally in pairs(Fu.GetNearbyHeroes(unit, 1200, false, BOT_MODE_NONE) or {}) do
		if ally ~= unit and Fu.IsValidHero(ally) and not ally:IsIllusion() then
			friends = friends + 1
		end
	end
	if friends > 1 or friends >= #foes - 1 then
		return false, nil
	end
	local close = 0
	for _, enemy in ipairs(foes) do
		if GetUnitToUnitDistance(unit, enemy) <= 500 then
			close = close + 1
		end
	end
	local trapped = unit:IsRooted()
		or unit:GetCurrentMovementSpeed() <= 250
		or hp < 0.35 and unit:WasRecentlyDamagedByAnyHero(1.5) and close >= 2
	if not trapped then
		return false, nil
	end
	local nearest, best = nil, 99999
	for _, enemy in ipairs(foes) do
		local dist = GetUnitToUnitDistance(unit, enemy)
		if dist < best then
			nearest, best = enemy, dist
		end
	end
	if DotaTime() >= (unit._corneredLogAt or -999) then
		unit._corneredLogAt = DotaTime() + 5
		pcall(print, string.format(
			"[OHA-CORNERED] t=%.0f %s enemies=%d allies=%d hp=%.2f ms=%d rooted=%s",
			DotaTime(),
			(string.gsub(unit:GetUnitName(), "npc_dota_hero_", "")),
			#foes,
			friends,
			hp,
			math.floor(unit:GetCurrentMovementSpeed()),
			tostring(unit:IsRooted())
		))
	end
	return true, nearest, foes
end
function AbilityContext.Build(bot)
	local ctx = {
		bot = bot,
		target = Fu.GetProperTarget(bot),
		enemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {},
		allies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE) or {},
		hp = Fu.GetHP(bot),
		mp = Fu.GetMP(bot),
		level = bot:GetLevel(),
		mana = bot:GetMana(),
		maxMana = bot:GetMaxMana(),
		attackRange = bot:GetAttackRange(),
		isRetreating = Fu.IsRetreating(bot),
		isTeamFight = Fu.IsInTeamFight(bot, 1200),
		isEngaging = Fu.IsGoingOnSomeone(bot),
	}
	-- Cornered: hero scripts read these flags, so add the "fight" spells on top of the "run"
	-- ones and give them the nearest enemy as target. Retreating stays on, so real escapes that
	-- still work under slows (Blink, Leap, Phase Shift) are not lost.
	local cornered, nearest = AbilityContext.IsCornered(bot)
	ctx.cornered = cornered
	if cornered then
		ctx.isEngaging = true
		ctx.isTeamFight = true
		if not Fu.IsValidHero(ctx.target) then
			ctx.target = nearest
		end
	end
	ctx.aetherRange = 0
	local aetherLens = Fu.IsItemAvailable("item_aether_lens")
	if aetherLens ~= nil then
		ctx.aetherRange = 250
	end
	return ctx
end
return AbilityContext
