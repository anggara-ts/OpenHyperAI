-- Making room for a Roshan item (#15): Item.TryPickupRoshanDrop / Item.RoshanDropDesire.
-- Game 051: one Banner cost Keeper three items, because every think dropped another item until the first
-- drop order landed, and only the last one was remembered.
local T = ...
local Stub = T.stub

local COSTS = {
	item_boots = 500,
	item_magic_wand = 450,
	item_ogre_axe = 1000,
	item_force_staff = 2200,
	item_glimmer_cape = 2150,
	item_ultimate_scepter = 4200,
	item_ward_observer = 0,
}

-- A hero with a bag, and a ground the drop / pick-up orders act on only when the test says so (land()).
local function scene(mainItems, backpackItems)
	local unit = Stub.reset({ hero = "npc_dota_hero_keeper_of_the_light" })
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	local world = { bag = {}, ground = {}, orders = {}, pending = nil }
	local function newItem(name)
		return {
			GetName = function()
				return name
			end,
			IsNull = function()
				return false
			end,
		}
	end
	for index, name in ipairs(mainItems) do
		world.bag[index - 1] = newItem(name)
	end
	for index, name in ipairs(backpackItems) do
		world.bag[5 + index] = newItem(name)
	end
	unit.GetItemInSlot = function(_, slot)
		return world.bag[slot]
	end
	unit.FindItemSlot = function(_, name)
		for slot = 0, 8 do
			if world.bag[slot] ~= nil and world.bag[slot]:GetName() == name then
				return slot
			end
		end
		return -1
	end
	unit.Action_DropItem = function(_, item)
		world.orders[#world.orders + 1] = "drop " .. item:GetName()
		world.pending = { kind = "drop", item = item }
	end
	unit.Action_PickUpItem = function(_, item)
		world.orders[#world.orders + 1] = "pick " .. item:GetName()
		world.pending = { kind = "pick", item = item }
	end
	unit.Action_MoveToLocation = function()
		world.orders[#world.orders + 1] = "move"
	end
	_G.GetItemCost = function(name)
		return COSTS[name] or 0
	end
	_G.GetDroppedItemList = function()
		return world.ground
	end
	Item.ShouldClaimRoshanDrop = function()
		return true
	end
	function world.putOnGround(name)
		world.ground[#world.ground + 1] = { item = newItem(name), location = unit:GetLocation() }
	end
	-- The last order takes effect.
	function world.land()
		local order = world.pending
		world.pending = nil
		if order == nil then
			return
		end
		if order.kind == "drop" then
			for slot = 0, 8 do
				if world.bag[slot] == order.item then
					world.bag[slot] = nil
				end
			end
			world.ground[#world.ground + 1] = { item = order.item, location = unit:GetLocation() }
		else
			for index, drop in ipairs(world.ground) do
				if drop.item == order.item then
					table.remove(world.ground, index)
					break
				end
			end
			for _, slot in ipairs({ 0, 1, 2, 3, 4, 5, 6, 7, 8 }) do
				if world.bag[slot] == nil then
					world.bag[slot] = order.item
					break
				end
			end
		end
	end
	function world.printed(pattern)
		local count = 0
		for _, line in ipairs(Stub.printed) do
			if string.find(line, pattern) then
				count = count + 1
			end
		end
		return count
	end
	return unit, Item, world
end

local FULL_MAIN = {
	"item_boots",
	"item_magic_wand",
	"item_ogre_axe",
	"item_force_staff",
	"item_glimmer_cape",
	"item_ultimate_scepter",
}

T.test("roshan drop: one item is dropped for the Banner, however often the think runs", function()
	local unit, Item, world = scene(FULL_MAIN, { "item_ward_observer" })
	world.putOnGround("item_roshans_banner")
	Stub.time = 2294
	for _ = 1, 6 do
		T.ok(Item.TryPickupRoshanDrop(unit), "busy with the Banner")
		Stub.time = Stub.time + 0.1
	end
	T.eq(table.concat(world.orders, ","), "drop item_magic_wand", "one drop order, the cheapest main item")
	T.eq(world.printed("room dropped magic_wand for=banner cost=450 backpack%-free=2"), 1, "the drop is logged")
	world.land()
	T.ok(Item.TryPickupRoshanDrop(unit), "takes the Banner")
	T.eq(world.orders[#world.orders], "pick item_roshans_banner", "into the freed slot")
	world.land()
	Stub.time = Stub.time + 1.5
	T.eq(Item.RoshanDropDesire(unit), 0.97, "the desire stays up for the dropped item")
	T.ok(Item.TryPickupRoshanDrop(unit), "fetches the dropped item")
	T.eq(world.orders[#world.orders], "pick item_magic_wand", "the Magic Wand again")
	world.land()
	T.ok(not Item.TryPickupRoshanDrop(unit), "done")
	T.eq(world.printed("room picked%-up magic_wand"), 1, "the pick-up is logged")
	T.eq(Item.RoshanDropDesire(unit), 0, "nothing left to do")
	T.eq(unit:FindItemSlot("item_magic_wand"), 7, "it came back into the backpack")
end)

T.test("roshan drop: a full backpack leaves the Banner alone but still makes room for the Aegis", function()
	local unit, Item, world = scene(FULL_MAIN, { "item_ward_observer", "item_ward_observer", "item_ward_observer" })
	world.putOnGround("item_roshans_banner")
	Stub.time = 2294
	T.ok(not Item.TryPickupRoshanDrop(unit), "no room: the Banner is left")
	T.eq(#world.orders, 0, "nothing is dropped")
	T.eq(world.printed("room skip roshans_banner why=bag%-full"), 1, "the skip is logged")
	T.eq(Item.RoshanDropDesire(unit), 0, "and the bot does not stand at it")
	world.ground = {}
	world.putOnGround("item_aegis")
	Stub.time = Stub.time + 31
	T.ok(Item.TryPickupRoshanDrop(unit), "the Aegis is worth an item")
	T.eq(table.concat(world.orders, ","), "drop item_magic_wand", "one drop")
end)

T.test("roshan drop: a dropped item nobody can reach is given up with a line", function()
	local unit, Item, world = scene(FULL_MAIN, {})
	world.putOnGround("item_aegis")
	Stub.time = 3757
	Item.TryPickupRoshanDrop(unit)
	world.land()
	Item.TryPickupRoshanDrop(unit)
	world.land()
	Stub.time = Stub.time + 31
	T.ok(not Item.TryPickupRoshanDrop(unit), "gives up after 30s")
	T.eq(world.printed("room lost magic_wand why=timeout"), 1, "the loss is logged")
	T.eq(Item.RoshanDropDesire(unit), 0, "the desire drops")
end)
