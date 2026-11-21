-- Skill builds (#45).
--
-- 1. Every hero's level-up list (sSkillList), built from the hero's real ability slots
--    (Tests/data/hero_abilities.lua, from the game files), must be learnable in order:
--      * every entry is an ability the hero has and can put a point in (not an innate, a Shard / Scepter
--        ability or one that another ability levels), and never past its max level;
--      * no entry needs a higher hero level than the point it is learned with (it would hold every later
--        point back until that level);
--      * the ultimate is taken with the first point the game allows (hero level 6 / 12 / 18), unless the
--        hero is listed in ULTIMATE_LATE with the reason;
--      * the four tiers' first talents are the 10th, 15th, 18th and 19th point (the 18th and 19th point
--        come with hero levels 20 and 25), each from its own tier.
--    Hero level needed for a rank: basic abilities 1 / 3 / 5 / 7, ultimates 6 / 12 / 18 (the engine's
--    defaults, what GetHeroLevelRequiredToUpgrade reports for them); the game files override it for a few.
-- 2. The helpers in FuncLib/systems/skill.lua that the level-up code uses.
-- 3. The level-up code itself (ability_item_usage_generic.lua), levelling a hero from 1 to 30.
local T = ...
local Stub = T.stub

local HERO_ABILITIES = assert(loadstring(T.read("Tests/data/hero_abilities.lua"), "hero_abilities"))()
local NOT_LEARNABLE = 64 -- ABILITY_BEHAVIOR_NOT_LEARNABLE
local MAX_BUILDS = 4 -- a hero file picks one of at most this many builds with RandomInt

-- "name|flags|max level|hero level for rank 1|hero levels between ranks|linked ability" -> a table.
local function parseAbility(entry)
	local fields = {}
	for field in string.gmatch(entry .. "|", "([^|]*)|") do
		fields[#fields + 1] = field
	end
	local flags = fields[2] or ""
	local ability = {
		name = fields[1],
		talent = string.find(fields[1], "^special_bonus") ~= nil,
		ultimate = string.find(flags, "u") ~= nil,
		hidden = string.find(flags, "h") ~= nil,
		notLearnable = string.find(flags, "n") ~= nil,
		innate = string.find(flags, "i") ~= nil,
		dependent = string.find(flags, "d") ~= nil,
		linked = fields[6] ~= "" and fields[6] or nil,
	}
	ability.maxLevel = tonumber(fields[3]) or (ability.talent and 1) or (ability.ultimate and 3) or 4
	ability.firstLevel = tonumber(fields[4]) or (ability.ultimate and 6 or 1)
	ability.levelsBetween = tonumber(fields[5]) or (ability.ultimate and 6 or 2)
	ability.behavior = ability.notLearnable and NOT_LEARNABLE or 0
	return ability
end

-- The hero's abilities in slot order and by name. Linked abilities (Troll Warlord's two Whirling Axes,
-- Dark Willow's Bedlam and Terrorize, ...) get their ranks together: they share a `group`.
local function heroAbilities(short)
	local entries = HERO_ABILITIES[short]
	if entries == nil then
		error("no ability data for " .. short .. " (run Util/skill-builds/gen-fixture.js)", 0)
	end
	local list, byName, talentCount = {}, {}, 0
	for index, entry in ipairs(entries) do
		local ability = parseAbility(entry)
		list[index] = ability
		byName[ability.name] = ability
		ability.group = ability.name
		if ability.talent and ability.name ~= "special_bonus_attributes" then
			talentCount = talentCount + 1
			ability.talentTier = math.floor((talentCount + 1) / 2) -- 1..4: hero level 10 / 15 / 20 / 25
		end
	end
	local changed = true
	while changed do
		changed = false
		for _, ability in ipairs(list) do
			local other = ability.linked and byName[ability.linked]
			if other ~= nil and other.group ~= ability.group then
				local group = other.group < ability.group and other.group or ability.group
				other.group, ability.group = group, group
				changed = true
			end
		end
	end
	return list, byName
end

-- Hero files that are not checked here, with the reason.
local NOT_CHECKED = {
	hero_lone_druid_bear = "the Spirit Bear's file: a unit, not a hero with a skill build",
	hero_invoker = "own rules: three orbs with seven ranks, an extra point at 6 / 12 / 18, no ranks on Invoke",
	hero_meepo = "own rules: Divided We Stand's hero levels (the game files say 4 / 11 / 18, its list is hand-made in skill.lua)",
}

-- Builds that take an ultimate rank later than the game allows, on purpose: [file][rank] = reason.
local ULTIMATE_LATE = {
	hero_naga_siren = {
		[1] = "carry Naga skips Song of the Siren early: 17% have it at level 6, the median is level 10 "
			.. "(Stratz, week of 12-18 Nov 2026, pos 1, 19,360 matches)",
	},
}

-- Known bugs that this PR cannot fix yet: [file] = reason. Reported as XFAIL; remove when fixed.
local KNOWN_BROKEN = {}

-- The problems of one level-up list, as a list of strings.
local function problems(skillList, byName, ultimateLate)
	local found = {}
	local count = 0
	for index in pairs(skillList) do
		count = math.max(count, index)
	end
	local rank = {}
	local talentsSeen = 0
	for point = 1, count do
		local name = skillList[point]
		local ability = name and byName[name]
		if name == nil then
			found[#found + 1] = "point "
				.. point
				.. " is empty (the build names an ability slot the hero does not have)"
		elseif ability == nil then
			found[#found + 1] = "point " .. point .. ": " .. tostring(name) .. " is not an ability of this hero"
		elseif ability.talent then
			talentsSeen = talentsSeen + 1
			local wanted = ({ 10, 15, 18, 19 })[talentsSeen]
			if wanted ~= nil and point ~= wanted then
				found[#found + 1] = string.format("talent %d is point %d, not %d", talentsSeen, point, wanted)
			end
			if talentsSeen <= 4 and ability.talentTier ~= talentsSeen then
				found[#found + 1] = string.format("talent %d (%s) is not from tier %d", talentsSeen, name, talentsSeen)
			end
		else
			local group = ability.group
			rank[group] = (rank[group] or 0) + 1
			if ability.notLearnable or ability.dependent then
				found[#found + 1] = "point " .. point .. ": " .. name .. " cannot be levelled with a point"
			elseif ability.innate and ability.maxLevel == 1 then
				found[#found + 1] = "point " .. point .. ": " .. name .. " is an innate with one rank"
			elseif ability.hidden and ability.maxLevel == 1 then
				found[#found + 1] = "point " .. point .. ": " .. name .. " is a Shard / Scepter or hidden ability"
			elseif rank[group] > ability.maxLevel then
				found[#found + 1] =
					string.format("point %d: %s rank %d is past its max level", point, name, rank[group])
			else
				local needed = ability.firstLevel + (rank[group] - 1) * ability.levelsBetween
				-- Points 1-16 come with hero levels 1-16; the 17th is the first that can be level 18.
				local level = point <= 16 and point or (point == 17 and 18 or nil)
				if level ~= nil and needed > level then
					found[#found + 1] = string.format(
						"point %d: %s rank %d needs hero level %d (every later point waits for it)",
						point,
						name,
						rank[group],
						needed
					)
				elseif ability.ultimate and level ~= needed and not (ultimateLate and ultimateLate[rank[group]]) then
					found[#found + 1] = string.format(
						"ultimate rank %d is point %d%s, the game allows it at hero level %d",
						rank[group],
						point,
						level and "" or " (after level 18)",
						needed
					)
				end
			end
		end
	end
	for _, ability in pairs(byName) do
		local learnable = ability.ultimate and not ability.hidden and not ability.notLearnable
		if learnable and (rank[ability.group] or 0) < ability.maxLevel then
			found[#found + 1] =
				string.format("%s only gets %d of %d ranks", ability.name, rank[ability.group] or 0, ability.maxLevel)
		end
	end
	return found
end

-- Loads the hero file as team slot `slot` with RandomInt answering `pick` (a hero file with several builds
-- chooses one with RandomInt). Returns its level-up list and the largest choice RandomInt was asked for.
local function skillListOf(file, unitName, abilityList, slot, pick)
	local unit = Stub.reset({ hero = unitName, slot = slot })
	Stub.setSlots(unit, abilityList)
	local choices = 1
	_G.RandomInt = function(low, high)
		if low == 1 and high > choices then
			choices = high
		end
		return math.max(low, math.min(high, pick))
	end
	local ok, result = Stub.load("BotsLib/" .. file)
	if not ok then
		error("as pos " .. slot .. ": " .. tostring(result), 0)
	end
	return result.sSkillList, choices
end

for _, path in ipairs(T.files("^BotsLib/hero_[%w_]+%.lua$")) do
	local file = string.match(path, "^BotsLib/(hero_[%w_]+)%.lua$")
	local short = string.gsub(file, "^hero_", "")
	local unitName = "npc_dota_" .. file
	local function case()
		local abilityList, byName = heroAbilities(short)
		local seen, report = {}, {}
		for slot = 1, 5 do
			local pick, choices = 1, 1
			while pick <= math.min(choices, MAX_BUILDS) do
				local skillList
				skillList, choices = skillListOf(file, unitName, abilityList, slot, pick)
				T.eq(type(skillList), "table", file .. ".sSkillList (pos " .. slot .. ")")
				local names = {}
				for point = 1, 30 do
					names[point] = tostring(skillList[point])
				end
				local key = table.concat(names, ",")
				if not seen[key] then
					seen[key] = true
					for _, problem in ipairs(problems(skillList, byName, ULTIMATE_LATE[file])) do
						report[#report + 1] = "pos " .. slot .. " build " .. pick .. ": " .. problem
					end
				end
				pick = pick + 1
			end
		end
		if #report > 0 then
			error(table.concat(report, "\n"), 0)
		end
	end
	if NOT_CHECKED[file] == nil then
		if KNOWN_BROKEN[file] then
			T.xfail("skill build " .. file, KNOWN_BROKEN[file], case)
		else
			T.test("skill build " .. file, case)
		end
	end
end

T.test("the skill build checks catch a bad list", function()
	local _, byName = heroAbilities("lich")
	local good = {}
	for _, name in ipairs({ 1, 2, 1, 3, 1, 6, 1, 2, 2, 0, 2, 6, 3, 3, 0, 3, 6 }) do
		good[#good + 1] = ({
			[0] = "special_bonus_unique_lich_8",
			"lich_frost_nova",
			"lich_frost_shield",
			"lich_sinister_gaze",
			[6] = "lich_chain_frost",
		})[name]
	end
	good[15] = "special_bonus_unique_lich_2"
	T.eq(#problems(good, byName), 0, "problems of a correct Lich list")
	local function with(point, name)
		local list = {}
		for index, value in ipairs(good) do
			list[index] = value
		end
		list[point] = name
		return table.concat(problems(list, byName), "\n")
	end
	T.ok(string.find(with(2, "lich_frost_nova"), "rank 2 needs hero level 3", 1, true), "a rank too early")
	T.ok(string.find(with(4, "lich_death_charge"), "cannot be levelled", 1, true), "an innate that takes no point")
	T.ok(string.find(with(4, "lich_ice_spire"), "Shard / Scepter", 1, true), "a Shard ability")
	T.ok(string.find(with(13, "lich_frost_nova"), "past its max level", 1, true), "a fifth rank")
	T.ok(string.find(with(6, "lich_sinister_gaze"), "ultimate rank 1 is point 12", 1, true), "a late ultimate")
	T.ok(
		string.find(with(10, "special_bonus_unique_lich_2"), "is not from tier 1", 1, true),
		"a talent of another tier"
	)
end)

-- 2. Helpers ---------------------------------------------------------------------------------------

T.test("Skill.GetTalentHeroLevel: tier levels, 27 for a tier's second talent", function()
	Stub.reset({ hero = "npc_dota_hero_lich" })
	local Skill = require(GetScriptDirectory() .. "/FuncLib/systems/skill")
	local talents = { "a10", "b10", "a15", "b15", "a20", "b20", "a25", "b25", "special_bonus_attributes" }
	local learned = {}
	local function isLearned(name)
		return learned[name] == true
	end
	for index, level in ipairs({ 10, 10, 15, 15, 20, 20, 25, 25 }) do
		T.eq(Skill.GetTalentHeroLevel(talents, talents[index], isLearned), level, talents[index])
	end
	learned.a15 = true
	T.eq(Skill.GetTalentHeroLevel(talents, "b15", isLearned), 27, "second talent of the level 15 tier")
	T.eq(Skill.GetTalentHeroLevel(talents, "a20", isLearned), 20, "another tier is not affected")
	learned.b25 = true
	T.eq(Skill.GetTalentHeroLevel(talents, "a25", isLearned), 27, "second talent, the right one learned first")
	T.eq(Skill.GetTalentHeroLevel(talents, "special_bonus_attributes", isLearned), nil, "attributes are no talent tier")
	T.eq(Skill.GetTalentHeroLevel(talents, "lich_frost_nova", isLearned), nil, "an ability")
end)

T.test("Skill.GetRemainingSkillList drops what is learned, by each ability's level", function()
	Stub.reset({ hero = "npc_dota_hero_lich" })
	local Skill = require(GetScriptDirectory() .. "/FuncLib/systems/skill")
	local list = { "q", "w", "q", "e", "q", "r", "q", "w", "w", "t10", "w", "r", "e", "e", "t15", "e", "r", "t20" }
	local levels = { q = 4, w = 4, e = 3, r = 2, t10 = 1, t15 = 1 }
	local remaining = Skill.GetRemainingSkillList(list, function(name)
		return levels[name]
	end)
	-- Hero level 18 with every point spent but the newest: 16 entries are learned. The old count
	-- (hero level minus unspent points = 17) would have dropped Chain Frost's third rank too.
	T.eq(table.concat(remaining, ","), "e,r,t20", "what is left at level 18")
	T.eq(#Skill.GetRemainingSkillList(list, function()
		return 0
	end), #list, "nothing learned: the whole list")
	-- A list with a hole (a build that names a missing ability slot) keeps what comes after the hole.
	local holed = { "q", nil, "w", "q" }
	T.eq(
		table.concat(
			Skill.GetRemainingSkillList(holed, function(name)
				return name == "q" and 1 or 0
			end),
			","
		),
		"w,q",
		"list with a hole"
	)
end)

-- 3. The level-up code -----------------------------------------------------------------------------

-- Levels Lich from 1 to 30 through AbilityLevelUpThink with a small model of the game: one ability point
-- per hero level except 17, 19, 21-24 and 26, ranks at their hero levels, a tier's first talent at
-- 10 / 15 / 20 / 25 and the second from 27. `api` is what the two ability calls the old code trusted answer
-- for a talent; `refuseBefore` makes the game itself refuse a tier's first talent before that hero level;
-- `dropFirstOrderAt` loses the first talent order sent at that hero level. A hero level lasts 24s here.
local NO_POINT = { [17] = true, [19] = true, [21] = true, [22] = true, [23] = true, [24] = true, [26] = true }
local function levelLich(api, refuseBefore, dropFirstOrderAt, noPoint)
	noPoint = noPoint or NO_POINT
	local unit = Stub.reset({ hero = "npc_dota_hero_lich", slot = 5 })
	local abilityList, byName = heroAbilities("lich")
	Stub.setSlots(unit, abilityList)
	local heroLevel, points = 1, 1
	local learnedAt = {}
	local function allowed(ability, data)
		local level = ability._learned or 0
		if data.talent then
			if data.talentTier == nil or level >= 1 then
				return false
			end
			local tierLevel = ({ 10, 15, 20, 25 })[data.talentTier]
			for _, other in pairs(byName) do
				if
					other ~= data
					and other.talentTier == data.talentTier
					and (unit:GetAbilityByName(other.name)._learned or 0) > 0
				then
					return heroLevel >= 27
				end
			end
			return heroLevel >= math.max(tierLevel, refuseBefore and refuseBefore[data.talentTier] or 0)
		end
		if data.notLearnable or data.hidden or level >= data.maxLevel then
			return false
		end
		return heroLevel >= data.firstLevel + level * data.levelsBetween
	end
	for _, data in ipairs(abilityList) do
		local ability = unit:GetAbilityByName(data.name)
		ability.GetLevel = function(self)
			return self._learned or 0
		end
		ability.CanAbilityBeUpgraded = function(self)
			if data.talent and api.canUpgrade ~= nil then
				return api.canUpgrade(data, heroLevel)
			end
			return allowed(self, data)
		end
		ability.GetHeroLevelRequiredToUpgrade = function(self)
			if data.talent and api.required ~= nil then
				return api.required(data, heroLevel)
			end
			return data.firstLevel + (self._learned or 0) * data.levelsBetween
		end
	end
	unit.GetLevel = function()
		return heroLevel
	end
	unit.GetAbilityPoints = function()
		return points
	end
	unit.ActionImmediate_LevelAbility = function(self, name)
		local ability = self:GetAbilityByName(name)
		if byName[name].talent and heroLevel == dropFirstOrderAt then
			dropFirstOrderAt = nil
			return
		end
		if points > 0 and allowed(ability, byName[name]) then
			ability._learned = (ability._learned or 0) + 1
			points = points - 1
			learnedAt[#learnedAt + 1] = name .. "@" .. heroLevel
		end
	end
	local ok, err = Stub.load("ability_item_usage_generic")
	T.ok(ok, "ability_item_usage_generic loads: " .. tostring(err))
	local think = _G.AbilityLevelUpThink
	for level = 1, 30 do
		heroLevel = level
		if level > 1 and not noPoint[level] then
			points = points + 1
		end
		for _ = 1, 12 do
			Stub.time = Stub.time + 2
			think()
		end
	end
	local printed = {}
	for _, line in ipairs(Stub.printed) do
		if string.find(line, "^%[OHA%-TALENT%]") or string.find(line, "^%[OHA%-SKILL%]") then
			printed[#printed + 1] = line
		end
	end
	return learnedAt, table.concat(printed, "\n"), points
end

-- Lich, pos 5: tiers t10 = left ... (hero_lich.lua): the list's talents in order.
local LICH_LEVELS = "lich_frost_nova@1,lich_frost_shield@2,lich_frost_nova@3,lich_sinister_gaze@4,lich_frost_nova@5,"
	.. "lich_chain_frost@6,lich_frost_nova@7,lich_frost_shield@8,lich_frost_shield@9,T@10,lich_frost_shield@11,"
	.. "lich_chain_frost@12,lich_sinister_gaze@13,lich_sinister_gaze@14,T@15,lich_sinister_gaze@16,"
	.. "lich_chain_frost@18,T@20,T@25,T@27,T@28,T@29,T@30"
local function shortened(learnedAt)
	local out = {}
	for index, entry in ipairs(learnedAt) do
		out[index] = string.gsub(entry, "^special_bonus_[%w_]+", "T")
	end
	return table.concat(out, ",")
end

T.test("level-up: talents at 10 / 15 / 20 / 25 and 27-30 when the engine API answers well", function()
	local learnedAt, printed, points = levelLich({})
	T.eq(shortened(learnedAt), LICH_LEVELS, "what Lich learned at which hero level")
	T.eq(points, 0, "unspent points at level 30")
	T.ok(not string.find(printed, " rejected ", 1, true), "no rejected talent order:\n" .. printed)
	T.ok(not string.find(printed, "late=[1-9]"), "no late talent:\n" .. printed)
	T.ok(not string.find(printed, "%[OHA%-SKILL%] t=%d+ lich waiting"), "no entry held the list back:\n" .. printed)
	local ranksAt7 =
		"ranks-7 level=7 points=0 lich_frost_nova=4 lich_frost_shield=1 lich_sinister_gaze=1 lich_chain_frost=1"
	T.ok(string.find(printed, ranksAt7, 1, true), "the ranks line at level 7:\n" .. printed)
	T.ok(string.find(printed, "ranks-18 level=18 points=0", 1, true), "the ranks line at level 18:\n" .. printed)
	local _, learnedLines = string.gsub(printed, "%[OHA%-TALENT%] t=%d+ lich learned=", "")
	T.eq(learnedLines, 8, "[OHA-TALENT] learned= lines")
end)

T.test("level-up: a talent does not wait for GetHeroLevelRequiredToUpgrade / CanAbilityBeUpgraded", function()
	-- Game 050: the second / third / fourth talent came at hero level 18 / 25 / 26. The engine calls
	-- answering like that must not hold a talent the game accepts.
	local lateLevel = { 10, 18, 25, 26 }
	local learnedAt, printed = levelLich({
		required = function(data)
			return lateLevel[data.talentTier] or 99
		end,
		canUpgrade = function(data, heroLevel)
			return heroLevel >= (lateLevel[data.talentTier] or 99)
		end,
	})
	T.eq(shortened(learnedAt), LICH_LEVELS, "what Lich learned at which hero level")
	T.ok(
		string.find(printed, "level=15 late=0 required=18 canUpgrade=false", 1, true),
		"the log names what the engine said:\n" .. printed
	)
end)

T.test("level-up: a talent order that gets lost is sent again", function()
	local learnedAt, printed = levelLich({}, nil, 15)
	T.eq(shortened(learnedAt), LICH_LEVELS, "what Lich learned at which hero level")
	T.ok(string.find(printed, "level=15 late=0", 1, true), "learned at 15:\n" .. printed)
end)

T.test("level-up: a talent the game refuses stays in the list and is retried each hero level", function()
	local learnedAt, printed, points = levelLich({}, { 10, 18, 25, 26 })
	local order = shortened(learnedAt)
	-- The ultimate goes first from level 15 (Skill.GetLatePriorityIndex), then the talent the game now accepts.
	T.ok(
		string.find(order, "lich_sinister_gaze@14,lich_chain_frost@18,T@18,", 1, true),
		"Chain Frost, then the level 15 talent, at 18: " .. order
	)
	T.ok(string.find(order, ",T@25,T@26,T@27,T@28,T@29,T@30", 1, true), "the later talents: " .. order)
	T.ok(string.find(order, "lich_chain_frost@18", 1, true), "Chain Frost rank 3 at 18: " .. order)
	T.eq(points, 0, "unspent points at level 30")
	for _, level in ipairs({ 15, 16, 17 }) do
		T.ok(
			string.find(printed, "rejected talent=special_bonus_unique_lich_%w+ level=" .. level),
			"rejected at " .. level .. ":\n" .. printed
		)
	end
	T.ok(string.find(printed, "level=18 late=3", 1, true), "late= on the learned line:\n" .. printed)
	T.ok(
		string.find(printed, "%[OHA%-SKILL%] t=%d+ lich waiting ability=special_bonus"),
		"the waiting entry is named:\n" .. printed
	)
end)

T.test(
	"level-up: with a bot's real points (none at 15-17 and 19-22) the ultimate comes at 18, talents from 23",
	function()
		-- Games 050 and 051: the game spends a bot's levels 15-17 and 19-22 on the attribute bonus by itself.
		local botNoPoint = { [15] = true, [16] = true, [17] = true, [19] = true, [20] = true, [21] = true, [22] = true }
		local learnedAt, printed, points = levelLich({}, nil, nil, botNoPoint)
		local order = shortened(learnedAt)
		T.ok(
			string.find(
				order,
				"lich_sinister_gaze@14,lich_chain_frost@18,T@23,T@24,T@25,lich_sinister_gaze@26,T@27,T@28,T@29,T@30",
				1,
				true
			),
			"Chain Frost rank 3 at 18, the talents at 23 / 24 / 25, the last basic rank at 26: " .. order
		)
		T.eq(points, 0, "unspent points at level 30")
		T.ok(string.find(printed, "promote entry=lich_chain_frost why=ultimate from=3 level=18", 1, true), printed)
		T.ok(string.find(printed, "why=talent from=2 level=24", 1, true), printed)
		T.ok(string.find(printed, "level-up level=15 points=0 attr=", 1, true), "the level-up line: " .. printed)
	end
)

T.test("Skill.GetLatePriorityIndex: ultimate from 15, an open talent before a basic rank from 23", function()
	Stub.reset({ hero = "npc_dota_hero_lich" })
	local Skill = require(GetScriptDirectory() .. "/FuncLib/systems/skill")
	local list = { "t15", "e", "r", "t20", "t25" }
	local talentLevels = { t15 = 15, t20 = 20, t25 = 25 }
	local function pick(skillList, heroLevel, ultimateReady)
		local index, reason = Skill.GetLatePriorityIndex(skillList, heroLevel, function(name)
			return ultimateReady and name == "r"
		end, function(name)
			return talentLevels[name]
		end)
		return index .. ":" .. tostring(reason)
	end
	T.eq(pick(list, 14, true), "1:nil", "before level 15 the list order stands")
	T.eq(pick(list, 18, true), "3:ultimate", "the ultimate goes first at 18")
	T.eq(pick(list, 16, false), "1:nil", "an ultimate that cannot be learned yet does not")
	T.eq(pick({ "r", "e" }, 18, true), "1:nil", "the ultimate is already first")
	T.eq(pick({ "e", "t20", "t25" }, 22, false), "1:nil", "before level 23 a basic rank keeps its place")
	T.eq(pick({ "e", "t20", "t25" }, 24, false), "2:talent", "level 24: the level 20 talent before the basic rank")
	T.eq(pick({ "e", "t25" }, 24, false), "1:nil", "a talent whose level is not reached stays behind")
	T.eq(pick({ "t25", "e" }, 24, false), "1:nil", "a talent at the head is left to the talent code")
end)
