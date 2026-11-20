-- Neutral items (ability_item_usage_generic.lua): every neutral with an active in the 7.42 pool has a use rule,
-- and the rules added for 7.42 (#116) run in the stub without an error.
local T = ...
local Stub = T.stub

-- The 20 neutrals whose AbilityBehavior is not PASSIVE, from scripts/npc/neutral_items.txt and items.txt (7.42).
local ACTIVE_NEUTRALS = {
	"item_ash_legion_shield",
	"item_red_ledger",
	"item_polliwog_charm",
	"item_seeds_of_serenity",
	"item_kobold_cup",
	"item_stonefeather_satchel",
	"item_pogo_stick",
	"item_psychic_headband",
	"item_metamorphic_mandible",
	"item_jidi_pollen_bag",
	"item_brick",
	"item_crippling_crossbow",
	"item_mana_draught",
	"item_idol_of_screeauk",
	"item_fallen_sky",
	"item_flicker",
	"item_minotaur_horn",
	"item_heavy_blade",
	"item_demonicon",
	"item_riftshadow_prism",
}

local function loadUsage(opts)
	Stub.reset(opts)
	local ok, usage = Stub.load("ability_item_usage_generic")
	if not ok then
		error(tostring(usage), 0)
	end
	return usage
end

local function printedUse(itemName, why)
	for _, line in ipairs(Stub.printed) do
		if
			string.find(line, "[OHA-NEUTRAL]", 1, true)
			and string.find(line, "use item=" .. itemName .. " why=" .. why, 1, true)
		then
			return true
		end
	end
	return false
end

T.test("neutral items: every 7.42 active neutral has a use rule", function()
	local Usage = loadUsage({ hero = "npc_dota_hero_lich" })
	for _, itemName in ipairs(ACTIVE_NEUTRALS) do
		T.eq(type(Usage.ConsiderItemDesire[itemName]), "function", itemName .. " rule")
	end
end)

T.test("neutral items: Red Ledger replaces only a list that paid nothing for 240 s", function()
	local Usage = loadUsage({ hero = "npc_dota_hero_weaver", time = 1200 })
	local ledger = Stub.newAbility("item_red_ledger", Stub.bot)
	local rule = Usage.ConsiderItemDesire["item_red_ledger"]
	T.eq(rule(ledger), BOT_ACTION_DESIRE_NONE, "first look only records the list")
	Stub.time = 1200 + 120
	T.eq(rule(ledger), BOT_ACTION_DESIRE_NONE, "120 s without a bounty is not stale yet")
	Stub.time = 1200 + 241
	local desire, _, castType = rule(ledger)
	T.ok(desire > 0, "stale list is replaced")
	T.eq(castType, "none", "Red Ledger cast type")
	T.ok(printedUse("item_red_ledger", "stale-list"), "the use is logged")
	T.eq(rule(ledger), BOT_ACTION_DESIRE_NONE, "the new list gets its own 240 s")
end)

T.test("neutral items: Kobold Cup and Brick stay unused with nothing going on", function()
	local Usage = loadUsage({ hero = "npc_dota_hero_ringmaster" })
	local cup = Stub.newAbility("item_kobold_cup", Stub.bot)
	local brick = Stub.newAbility("item_brick", Stub.bot)
	T.eq(Usage.ConsiderItemDesire["item_kobold_cup"](cup), BOT_ACTION_DESIRE_NONE, "Kobold Cup idle")
	T.eq(Usage.ConsiderItemDesire["item_brick"](brick), BOT_ACTION_DESIRE_NONE, "Brick idle")
end)

T.test("neutral items: Kobold Cup helps an ally beside the bot run from an enemy", function()
	local Usage = loadUsage({ hero = "npc_dota_hero_ringmaster", slot = 5, time = 900 })
	local bot = Stub.bot
	local ally = Stub.teams[bot:GetTeam()][1]
	local enemy = Stub.teams[bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT][1]
	ally._loc = bot:GetLocation() + Vector(300, 0, 0)
	enemy._loc = bot:GetLocation() + Vector(700, 0, 0)
	ally.GetActiveMode = function()
		return BOT_MODE_RETREAT
	end
	ally.GetActiveModeDesire = function()
		return 0.9
	end
	ally.WasRecentlyDamagedByAnyHero = function()
		return true
	end
	ally.DistanceFromFountain = function()
		return 5000
	end
	local cup = Stub.newAbility("item_kobold_cup", bot)
	local rule = Usage.ConsiderItemDesire["item_kobold_cup"]
	local desire, _, castType, why = rule(cup)
	T.ok(desire > 0, "used for the ally")
	T.eq(castType, "none", "Kobold Cup cast type")
	T.eq(why, "ally-escape", "reason")
	T.ok(printedUse("item_kobold_cup", "ally-escape"), "the use is logged")
	T.eq(rule(cup), BOT_ACTION_DESIRE_NONE, "no second order within the retry gap")
end)

T.test("neutral items: Brick is thrown at the bot's target in a fight (through ItemUsageThink)", function()
	local Usage = loadUsage({ hero = "npc_dota_hero_clinkz", time = 1600 })
	local bot = Stub.bot
	local enemy = Stub.teams[bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT][1]
	enemy._loc = bot:GetLocation() + Vector(500, 0, 0)
	bot.GetActiveMode = function()
		return BOT_MODE_ATTACK
	end
	bot.GetTarget = function()
		return enemy
	end
	local brick = Stub.newAbility("item_brick", bot)
	brick.IsFullyCastable = function()
		return true
	end
	brick.IsTrained = function()
		return true
	end
	brick.GetCastRange = function()
		return 600
	end
	brick.GetSpecialValueInt = function(_, key)
		return key == "damage" and 150 or 200
	end
	bot._items[16] = brick
	local orderedItem, orderedTarget = nil, nil
	bot.Action_UseAbilityOnEntity = function(_, item, target)
		orderedItem, orderedTarget = item, target
	end
	Usage.ItemUsageThink()
	T.eq(orderedItem, brick, "Brick ordered")
	T.eq(orderedTarget, enemy, "on the bot's target")
	T.ok(printedUse("item_brick", "fight"), "the use is logged")
end)
