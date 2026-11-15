-- Shared bot system: ability context.
local a = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local b = {}
-- Cornered: running has stopped working. Retreating (or below 40% HP) with 3+ enemy heroes
-- within 900, at most one ally close by, and no way out (rooted, slowed to 250 or less, or low
-- and being hit with 2+ enemies on him). Centaur 1v4 and Earthshaker in five enemies (37:00)
-- kept running under heavy slows with Stampede / Echo Slam unused.
function b.IsCornered(c)
	if c == nil or not c:IsAlive() or c:IsIllusion() then
		return false, nil
	end
	local hp = a.GetHP(c)
	if not a.IsRetreating(c) and hp >= 0.4 then
		return false, nil
	end
	local foes = {}
	for _, e in pairs(a.GetNearbyHeroes(c, 900, true, BOT_MODE_NONE) or {}) do
		if a.IsValidHero(e) and not a.IsSuspiciousIllusion(e) then
			foes[#foes + 1] = e
		end
	end
	if #foes < 3 then
		return false, nil
	end
	local friends = 0
	for _, ally in pairs(a.GetNearbyHeroes(c, 1200, false, BOT_MODE_NONE) or {}) do
		if ally ~= c and a.IsValidHero(ally) and not ally:IsIllusion() then
			friends = friends + 1
		end
	end
	if friends > 1 or friends >= #foes - 1 then
		return false, nil
	end
	local close = 0
	for _, e in ipairs(foes) do
		if GetUnitToUnitDistance(c, e) <= 500 then
			close = close + 1
		end
	end
	local trapped = c:IsRooted()
		or c:GetCurrentMovementSpeed() <= 250
		or hp < 0.35 and c:WasRecentlyDamagedByAnyHero(1.5) and close >= 2
	if not trapped then
		return false, nil
	end
	local nearest, best = nil, 99999
	for _, e in ipairs(foes) do
		local dist = GetUnitToUnitDistance(c, e)
		if dist < best then
			nearest, best = e, dist
		end
	end
	if DotaTime() >= (c._corneredLogAt or -999) then
		c._corneredLogAt = DotaTime() + 5
		pcall(print, string.format(
			"[OHA-CORNERED] t=%.0f %s enemies=%d allies=%d hp=%.2f ms=%d rooted=%s",
			DotaTime(),
			(string.gsub(c:GetUnitName(), "npc_dota_hero_", "")),
			#foes,
			friends,
			hp,
			math.floor(c:GetCurrentMovementSpeed()),
			tostring(c:IsRooted())
		))
	end
	return true, nearest, foes
end
function b.Build(c)
	local d = {
		bot = c,
		target = a.GetProperTarget(c),
		enemies = a.GetNearbyHeroes(c, 1600, true, BOT_MODE_NONE) or {},
		allies = a.GetNearbyHeroes(c, 1600, false, BOT_MODE_NONE) or {},
		hp = a.GetHP(c),
		mp = a.GetMP(c),
		level = c:GetLevel(),
		mana = c:GetMana(),
		maxMana = c:GetMaxMana(),
		attackRange = c:GetAttackRange(),
		isRetreating = a.IsRetreating(c),
		isTeamFight = a.IsInTeamFight(c, 1200),
		isEngaging = a.IsGoingOnSomeone(c),
	}
	-- Cornered: hero scripts read these flags, so add the "fight" spells on top of the "run"
	-- ones and give them the nearest enemy as target. Retreating stays on, so real escapes that
	-- still work under slows (Blink, Leap, Phase Shift) are not lost.
	local cornered, nearest = b.IsCornered(c)
	d.cornered = cornered
	if cornered then
		d.isEngaging = true
		d.isTeamFight = true
		if not a.IsValidHero(d.target) then
			d.target = nearest
		end
	end
	d.aetherRange = 0
	local e = a.IsItemAvailable("item_aether_lens")
	if e ~= nil then
		d.aetherRange = 250
	end
	return d
end
return b
