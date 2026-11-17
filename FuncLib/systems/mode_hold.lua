-- Mode desire hold. Game 031, 40:39-41:01: Doom and Disruptor flipped farm / retreat / assemble /
-- team roam every 1-4s (Doom walked 2709 in 8s and ended 45 from where he started), because the
-- active mode's desire dipped for a moment and another low mode (0.10-0.22) took over, then the
-- first one came back.
-- While a mode is the active one, a dip below its last good desire is bridged for up to 2s at 95%
-- of that value. A higher mode still wins at once, and a dip that lasts longer than 2s goes through.
local M = {}
local HOLD_SECONDS = 2.0
-- Game 030 (build 061): of 324 bridges, 167 kept a bot retreating after the danger was gone and 55
-- held an override desire (1.0+, e.g. team roam 1.42 after its target was gone), which blocks every
-- other mode. Only ordinary desires (0.05-0.9) are held.
local HOLD_MAX = 0.9
function M.Hold(bot, key, mode, desire, cond)
	if bot == nil or type(desire) ~= "number" then
		return desire
	end
	-- An optional condition (retreat: only while hurt).
	if cond ~= nil and not cond(bot) then
		if bot._modeHold ~= nil then
			bot._modeHold[key] = nil
		end
		return desire
	end
	local now = DotaTime()
	bot._modeHold = bot._modeHold or {}
	local held = bot._modeHold[key]
	if not bot:IsAlive() or bot:GetActiveMode() ~= mode then
		bot._modeHold[key] = nil
		return desire
	end
	if held == nil or desire >= held.d * 0.95 then
		if desire > 0.05 and desire <= HOLD_MAX then
			bot._modeHold[key] = { d = desire, t = now }
		end
		return desire
	end
	if now - held.t <= HOLD_SECONDS then
		-- The [OHA-HOLD] bridge print (game 029) is gone: games 036/037 showed the hold runs (489 lines).
		return held.d * 0.95
	end
	bot._modeHold[key] = nil
	return desire
end
-- Wraps a mode file's GetDesire.
function M.Wrap(getDesire, key, mode, cond)
	if getDesire == nil or mode == nil then
		return getDesire
	end
	return function(...)
		local desire = getDesire(...)
		local ok, heldDesire = pcall(M.Hold, GetBot(), key, mode, desire, cond)
		if ok then
			return heldDesire
		end
		return desire
	end
end
return M
