-- Disabled stub for mode_item_generic. The -- prefix in the filename keeps Dota from loading it, so Valve default behavior is used.
local a = GetBot()
local b = a:GetUnitName()
if
	a == nil
	or a:IsInvulnerable()
	or not a:IsHero()
	or not a:IsAlive()
	or not string.find(b, "hero")
	or a:IsIllusion()
then
	return
end
function GetDesire()
	return BOT_MODE_DESIRE_NONE
end
