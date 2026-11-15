-- Charge count for charge-based hero abilities (Lich Sacrifice, ...).
-- The bot API has no ability-charge read: GetCurrentCharges is documented for items only, and
-- GetCurrentAbilityCharges does not exist (every Techies log showed the fallback value). So the
-- count is kept here from the restore time and our own casts, and corrected by what the API does
-- show: an ability that is not castable while the hero is free to cast has 0 charges left.
local ChargeTracker = {}

local state = {}

local function Key(bot, ability)
	return tostring(bot:GetPlayerID()) .. ":" .. ability:GetName()
end

local function Log(bot, ability, s, why)
	pcall(print, string.format(
		"[OHA-CHARGES] t=%.0f %s %s n=%d why=%s next=%s",
		DotaTime(),
		(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
		ability:GetName(),
		s.n,
		why,
		s.nextAt ~= nil and string.format("%.0f", s.nextAt) or "-"
	))
end

local function Spend(bot, ability, s, restoreTime, why)
	s.n = math.max(0, s.n - 1)
	if s.nextAt == nil then
		s.nextAt = DotaTime() + restoreTime
	end
	s.pendingAt = nil
	s.pendingTarget = nil
	Log(bot, ability, s, why)
end

-- Call every think, also while casting, so the cast phase is seen.
-- maxCharges and restoreTime come from Valve data; startEmpty: no charges when first learned.
function ChargeTracker.Get(bot, ability, maxCharges, restoreTime, startEmpty)
	if bot == nil or ability == nil or not ability:IsTrained() then
		return 0
	end
	local now = DotaTime()
	local k = Key(bot, ability)
	local s = state[k]
	if s == nil then
		s = { n = maxCharges, inPhase = false }
		if startEmpty then
			s.n = 0
			s.nextAt = now + restoreTime
		end
		state[k] = s
		Log(bot, ability, s, "learned")
	end
	while s.nextAt ~= nil and now >= s.nextAt and s.n < maxCharges do
		s.n = s.n + 1
		s.nextAt = s.n < maxCharges and s.nextAt + restoreTime or nil
		Log(bot, ability, s, "restore")
	end
	-- A cast: the cast phase was seen and has ended, or (if the phase was missed) the target of
	-- an order we issued died within 1.5s.
	local phase = ability:IsInAbilityPhase()
	if s.inPhase and not phase then
		Spend(bot, ability, s, restoreTime, "cast")
	elseif s.pendingAt ~= nil then
		if now > s.pendingAt + 1.5 then
			s.pendingAt = nil
			s.pendingTarget = nil
		elseif not phase and s.pendingTarget ~= nil and not s.pendingTarget:IsAlive() then
			Spend(bot, ability, s, restoreTime, "cast-target-died")
		end
	end
	s.inPhase = phase
	if phase then
		s.pendingAt = nil
	end
	-- Correct with what the API shows, only when the hero is free to cast.
	local free = bot:IsAlive()
		and not phase
		and not bot:IsSilenced()
		and not bot:IsStunned()
		and not bot:IsHexed()
		and not bot:IsChanneling()
	if free then
		local castable = ability:IsFullyCastable()
		if not castable and s.n > 0 then
			s.n = 0
			if s.nextAt == nil then
				s.nextAt = now + restoreTime
			end
			Log(bot, ability, s, "resync-empty")
		elseif castable and s.n == 0 then
			s.n = 1
			Log(bot, ability, s, "resync-one")
		end
	end
	return s.n
end

-- Record a cast order, so a cast is still counted if its cast phase is never seen.
function ChargeTracker.Issued(bot, ability, target)
	if bot == nil or ability == nil then
		return
	end
	local s = state[Key(bot, ability)]
	if s ~= nil then
		s.pendingAt = DotaTime()
		s.pendingTarget = target
	end
end

return ChargeTracker
