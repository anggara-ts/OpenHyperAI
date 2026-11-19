-- Patch 7.42 removed or replaced these abilities. A hero script that still looks one up or casts it runs
-- dead code (the lookup returns a placeholder and logs a warning every think). Source: Valve patch notes
-- feed (patchnotes) and the herodata datafeed, 2026-11-19.
local T = ...

local removed = {
	["juggernaut_swift_slash"] = "Swiftslash was removed",
	["meepo_megameepo"] = "MegaMeepo was removed",
	["meepo_megameepo_fling"] = "MegaMeepo Fling was removed",
	["furion_curse_of_the_forest"] = "Curse of the Oldgrowth is a passive now, nothing to cast",
}

T.test("no hero file looks up an ability that 7.42 removed", function()
	for _, path in ipairs(T.files("^BotsLib/hero_[%w_]+%.lua$")) do
		local src = T.read(path)
		for name, why in pairs(removed) do
			T.ok(not string.find(src, name, 1, true), path .. " still uses " .. name .. " (" .. why .. ")")
		end
	end
end)
