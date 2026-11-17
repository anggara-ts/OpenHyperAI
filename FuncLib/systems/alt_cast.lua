-- Shared bot system: the alt-cast state of an ability (#36).
-- The bot API's cast orders have no alt flag. The datafeed calls alt-cast a state ("can be put on alt-cast",
-- "in the alt-cast state"), like autocast, and Grimstroke's experiment showed the engine accepts ToggleAutoCast()
-- on an alt-castable ability (game 029: [OHA-GRIM] stroke-altcast set after=true). Whether the cast then behaves as
-- alt-cast is what the next games check: every change is logged, and heroes log the state at each cast.
local AltCast = {}

-- Turn the ability's alt/autocast state to `wanted`, toggling only when it differs. Checked at most every 5s per
-- ability (a death can reset it). Returns the state after the check (nil when it can't be read).
function AltCast.Ensure(bot, ability, wanted)
	if bot == nil or ability == nil or ability:IsNull() or not ability:IsTrained() then
		return nil
	end
	local name = ability:GetName()
	bot._altCastAt = bot._altCastAt or {}
	local now = DotaTime()
	if bot._altCastAt[name] ~= nil and now - bot._altCastAt[name] < 5 then
		return nil
	end
	bot._altCastAt[name] = now
	local okBefore, before = pcall(function()
		return ability:GetAutoCastState()
	end)
	if not okBefore or before == wanted then
		return okBefore and before or nil
	end
	pcall(function()
		ability:ToggleAutoCast()
	end)
	local okAfter, after = pcall(function()
		return ability:GetAutoCastState()
	end)
	pcall(
		print,
		string.format(
			"[OHA-ALTCAST] t=%.0f %s %s wanted=%s before=%s after=%s",
			now,
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			name,
			tostring(wanted),
			tostring(before),
			tostring(okAfter and after)
		)
	)
	return okAfter and after or nil
end

-- The current state, for cast logs (nil when it can't be read).
function AltCast.State(ability)
	if ability == nil or ability:IsNull() then
		return nil
	end
	local ok, state = pcall(function()
		return ability:GetAutoCastState()
	end)
	return ok and state or nil
end

return AltCast
