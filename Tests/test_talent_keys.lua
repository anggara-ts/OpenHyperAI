-- Talent bonus reads (#46).
--
-- 1. Since 7.3x a unique talent (special_bonus_unique_*) has no values of its own: the 7.42 game files put its bonus
--    inside the ability it changes, and the ability's own read includes it once learned (talent_watch.lua). So
--    talent:GetSpecialValueInt("value") on a unique talent reads 0. Only the generic stat talents
--    (special_bonus_strength_15, special_bonus_hp_250, ...) have a "value". A hero file must not read "value" from a
--    unique talent, nor from a hero ability (none of the abilities these files read has a "value" key).
-- 2. FuncLib/systems/talent_watch.lua: the verdict and the [OHA-TALENT] line.
local T = ...
local Stub = T.stub

local HERO_ABILITIES = assert(loadstring(T.read("Tests/data/hero_abilities.lua"), "hero_abilities"))()

-- Hero files with a "value" read on a unique talent that this fix does not touch yet: the file belongs to another
-- open PR, or the read is a new finding filed on #46. Remove a hero here when its read is fixed (the test XPASSes).
local PENDING = {
	bounty_hunter = "talent 3 is Shadow Walk damage reduction, read as Shuriken Toss damage (new on #46)",
	dawnbreaker = "Celestial Hammer range and speed talent (new on #46)",
	dazzle = "Poison Touch damage talent (new on #46)",
	lina = "Light Strike Array damage talent (new on #46)",
	lion = "Finger of Death damage-per-kill talent (new on #46)",
	omniknight = "Purification heal talent (file in PR #118)",
	pugna = "Nether Blast damage talent (file in PR #158)",
	shadow_shaman = "Ether Shock damage talent (new on #46)",
	tidehunter = "Gush damage talent (file in PR #120)",
}

local function slotNames(hero)
	local names = {}
	for i, entry in ipairs(HERO_ABILITIES[hero] or {}) do
		names[i] = string.match(entry, "^[^|]+")
	end
	return names
end

-- sTalentList as Fu.Skill.GetTalentList builds it: the talents in slot order.
local function talentList(hero)
	local talents = {}
	for _, name in ipairs(slotNames(hero)) do
		if string.find(name, "^special_bonus") then
			talents[#talents + 1] = name
		end
	end
	return talents
end

-- handle variable -> talent name, from the ways the hero files look talents up.
local function talentHandles(src, hero)
	local handles = {}
	local talents = talentList(hero)
	local slots = slotNames(hero)
	for var, index in string.gmatch(src, "([%w_]+)%s*=%s*SafeAbility%(%s*bot:GetAbilityByName%(sTalentList%[(%d+)%]%)") do
		handles[var] = talents[tonumber(index)] or ("sTalentList[" .. index .. "]")
	end
	for var, name in
		string.gmatch(src, '([%w_]+)%s*=%s*SafeAbility%(%s*bot:GetAbilityByName%("(special_bonus[%w_]+)"%)')
	do
		handles[var] = name
	end
	for var, name in string.gmatch(src, '([%w_]+)%s*=%s*bot:GetAbilityByName%("(special_bonus[%w_]+)"%)') do
		handles[var] = name
	end
	for var, slot in string.gmatch(src, "([%w_]+)%s*=%s*bot:GetAbilityInSlot%((%d+)%)") do
		handles[var] = slots[tonumber(slot) + 1] or ("slot " .. slot)
	end
	return handles
end

-- The "value" reads in a hero file that read 0: on a unique talent, or on anything that is not a talent.
local function badValueReads(path)
	local hero = string.match(path, "hero_([%w_]+)%.lua$")
	local src = T.read(path)
	local handles = talentHandles(src, hero)
	local bad = {}
	for var in string.gmatch(src, '([%w_]+):GetSpecialValue%a+%(%s*"value"%s*%)') do
		local name = handles[var]
		local generic = name ~= nil
			and string.find(name, "^special_bonus_") ~= nil
			and string.find(name, "^special_bonus_unique_") == nil
		if not generic then
			bad[#bad + 1] = var .. " (" .. tostring(name or "not a talent") .. ")"
		end
	end
	return bad
end

T.test('hero files read no "value" from a unique talent or an ability', function()
	for _, path in ipairs(T.files("^BotsLib/hero_[%w_]+%.lua$")) do
		local hero = string.match(path, "hero_([%w_]+)%.lua$")
		if PENDING[hero] == nil then
			local bad = badValueReads(path)
			T.ok(#bad == 0, path .. ' reads "value" (0 in 7.42) from ' .. table.concat(bad, ", "))
		end
	end
end)

for hero, reason in pairs(PENDING) do
	T.xfail('talent "value" read: ' .. hero, reason, function()
		local bad = badValueReads("BotsLib/hero_" .. hero .. ".lua")
		T.ok(#bad == 0, hero .. ' reads "value" from ' .. table.concat(bad, ", "))
	end)
end

T.test("the scan finds the old reads (axe f[7], Luna f[6], Enigma's ability)", function()
	local axe = 'local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "axe")\n'
		.. 'radius = radius + talent7:GetSpecialValueInt("value")\n'
	T.eq(talentHandles(axe, "axe").talent7, "special_bonus_unique_axe_2", "axe talent 7")
	local luna = 'local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "luna")\n'
	T.eq(talentHandles(luna, "luna").talent6, "special_bonus_unique_luna_lunar_orbit_speed_damage", "luna talent 6")
	local morph = "local agilityTalent = bot:GetAbilityInSlot(14)\n"
	T.eq(talentHandles(morph, "morphling").agilityTalent ~= nil, true, "slot lookups resolve")
end)

-- 2. talent_watch.lua -----------------------------------------------------------------------------------------

local function watch()
	Stub.reset({ hero = "npc_dota_hero_axe" })
	package.loaded[GetScriptDirectory() .. "/FuncLib/systems/talent_watch"] = nil
	return require(GetScriptDirectory() .. "/FuncLib/systems/talent_watch")
end

T.test("talent watch: verdict", function()
	local W = watch()
	T.eq(W.Verdict(315, 385, 70, 4, 4), "yes", "bonus included")
	T.eq(W.Verdict(315, 315, 70, 4, 4), "no", "bonus not included")
	T.eq(W.Verdict(0.55, 0.85, 0.3, 1, 1), "yes", "float bonus")
	T.eq(W.Verdict(315, 385, 70, 3, 4), "unknown", "ability levelled in the same sample")
	T.eq(W.Verdict(nil, 385, 70, nil, 4), "unknown", "learned before the first sample")
	T.eq(W.Verdict(315, 340, 70, 4, 4), "other", "some other change")
	T.eq(W.Verdict(0, 0, 70, 0, 0), "unknown", "ability not learned yet")
end)

T.test("talent watch: every watched talent and ability is the hero's (7.42 slots)", function()
	local W = watch()
	for hero, list in pairs(W.WATCH) do
		local names = {}
		for _, name in ipairs(slotNames(hero)) do
			names[name] = true
		end
		T.ok(HERO_ABILITIES[hero] ~= nil, hero .. " is a hero")
		for _, entry in ipairs(list) do
			T.ok(names[entry.talent], hero .. " has " .. entry.talent)
			T.ok(names[entry.ability], hero .. " has " .. entry.ability)
		end
	end
end)

T.test("talent watch: one [OHA-TALENT] line when the talent is learned", function()
	local W = watch()
	local bot = GetBot()
	local talent = bot:GetAbilityByName("special_bonus_unique_axe_2")
	local call = bot:GetAbilityByName("axe_berserkers_call")
	local trained, radius = false, 315
	talent.IsTrained = function()
		return trained
	end
	call.GetSpecialValueFloat = function()
		return radius
	end
	call.GetLevel = function()
		return 4
	end
	local lines = {}
	local rawPrint = print
	_G.print = function(line)
		lines[#lines + 1] = line
	end
	local ok, err = pcall(function()
		Stub.time = 600
		W.Tick(bot)
		trained, radius = true, 385
		Stub.time = 600.5
		W.Tick(bot) -- throttled: nothing yet
		Stub.time = 601
		W.Tick(bot)
		Stub.time = 610
		W.Tick(bot) -- printed once only
	end)
	_G.print = rawPrint
	assert(ok, err)
	T.eq(#lines, 1, "one line")
	T.ok(string.find(lines[1] or "", "[OHA-TALENT] t=601 axe talent=special_bonus_unique_axe_2", 1, true), lines[1])
	T.ok(
		string.find(lines[1] or "", "before=315.00 after=385.00 linked=70 included=yes talentValue=0.00", 1, true),
		lines[1]
	)
end)
