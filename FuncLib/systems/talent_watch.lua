-- Talent bonuses and GetSpecialValueInt (#46).
--
-- Since 7.3x a unique talent has no values of its own: the game files put the bonus inside the ability it changes,
-- e.g. axe_berserkers_call "radius" { "value" "315" "special_bonus_unique_axe_2" "+70" } (7.42 hero files in
-- pak01_dir.vpk). The Valve datafeed lists no special values for these talents. So a hero script that adds
-- talent:GetSpecialValueInt("value") (or any other key) to the ability's value adds 0.
--
-- The ability's own value already includes the learned talent: in games 014-018 Lich's Frost Shield read
-- GetSpecialValueInt("AbilityCharges") = 2 (the [OHA-CHARGES] probe's runtimeMax) once he had learned
-- special_bonus_unique_lich_4, and the game files give it "value" "0" "+2" with that talent. Hero scripts read the
-- ability's value and add nothing for the talent.
--
-- To prove that for ordinary keys too, TalentWatch.Tick samples the watched values once a second and prints one line
-- when the talent is learned: [OHA-TALENT] t= <hero> talent= ability= key= before= after= linked= included=yes|no|...
local TalentWatch = {}

-- hero -> what to watch: the talent, the ability and key it changes, and the linked bonus from the 7.42 hero files.
TalentWatch.WATCH = {
	axe = { { talent = "special_bonus_unique_axe_2", ability = "axe_berserkers_call", key = "radius", linked = 70 } },
	bane = {
		{ talent = "special_bonus_unique_bane_2", ability = "bane_brain_sap", key = "brain_sap_damage", linked = 275 },
	},
	enigma = {
		{ talent = "special_bonus_unique_enigma_2", ability = "enigma_malefice", key = "stun_instances", linked = 4 },
		{ talent = "special_bonus_unique_enigma_9", ability = "enigma_midnight_pulse", key = "radius", linked = 200 },
	},
	lich = { { talent = "special_bonus_unique_lich_6", ability = "lich_frost_nova", key = "aoe_damage", linked = 125 } },
	luna = {
		{ talent = "special_bonus_unique_luna_1", ability = "luna_lucent_beam", key = "beam_damage", linked = 80 },
	},
	ogre_magi = {
		{
			talent = "special_bonus_unique_ogre_magi_2",
			ability = "ogre_magi_fireblast",
			key = "fireblast_damage",
			linked = 125,
		},
	},
	riki = {
		{
			talent = "special_bonus_unique_riki_1",
			ability = "riki_innate_backstab",
			key = "damage_multiplier",
			linked = 0.3,
		},
	},
	silencer = {
		{ talent = "special_bonus_unique_silencer_4", ability = "silencer_last_word", key = "radius", linked = 250 },
	},
}

-- Whether the value read after the talent was learned includes the linked bonus. before/after: the ability's value
-- in the samples just before and just after; levelBefore/levelAfter: the ability's level then (a level-up in the
-- same second changes the value too, so that sample proves nothing).
function TalentWatch.Verdict(before, after, linked, levelBefore, levelAfter)
	if before == nil or after == nil or levelBefore ~= levelAfter then
		return "unknown"
	end
	local diff = after - before
	local tolerance = math.max(0.001, math.abs(linked) * 0.01)
	if math.abs(diff - linked) <= tolerance then
		return "yes"
	end
	if math.abs(diff) <= tolerance then
		return "no"
	end
	return "other"
end

local function Short(bot)
	return (string.gsub(bot:GetUnitName(), "npc_dota_hero_", ""))
end

local function Sample(bot, entry, state)
	local talent = bot:GetAbilityByName(entry.talent)
	local ability = bot:GetAbilityByName(entry.ability)
	if talent == nil or ability == nil or talent:IsNull() or ability:IsNull() then
		state.done = true
		return
	end
	local value = ability:GetSpecialValueFloat(entry.key)
	local level = ability:GetLevel()
	if talent:IsTrained() then
		print(
			string.format(
				"[OHA-TALENT] t=%.0f %s talent=%s ability=%s key=%s before=%s after=%s linked=%s included=%s",
				DotaTime(),
				Short(bot),
				entry.talent,
				entry.ability,
				entry.key,
				state.value ~= nil and string.format("%.2f", state.value) or "-",
				string.format("%.2f", value),
				tostring(entry.linked),
				TalentWatch.Verdict(state.value, value, entry.linked, state.level, level)
			)
		)
		state.done = true
		return
	end
	state.value = value
	state.level = level
end

-- Once per think from the hero script; samples at most once a second and stops after the line is printed.
function TalentWatch.Tick(bot)
	if DotaTime() < (bot._talentWatchAt or -999) then
		return
	end
	bot._talentWatchAt = DotaTime() + 1
	local list = TalentWatch.WATCH[Short(bot)]
	if list == nil then
		return
	end
	bot._talentWatch = bot._talentWatch or {}
	for i, entry in ipairs(list) do
		local state = bot._talentWatch[i] or {}
		bot._talentWatch[i] = state
		if not state.done then
			pcall(Sample, bot, entry, state)
		end
	end
end

return TalentWatch
