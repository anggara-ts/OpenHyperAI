-- BotsLib/hero_nevermore.lua: Requiem and the near raze when Shadow Fiend is rooted or hit in melee (game 052,
-- 10:50: rooted by Earthbind, two Meepo bodies on him, no spell cast, 97% to 15% HP).
local T = ...
local Stub = T.stub

local function shadowFiend()
	Stub.reset({ hero = "npc_dota_hero_nevermore", slot = 2 })
	local ok, result = Stub.load("BotsLib/hero_nevermore")
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

local function situation(changes)
	local s = { rooted = false, hitByHeroes = false, enemies350 = 0, hp = 0.9, souls = 15 }
	for key, value in pairs(changes) do
		s[key] = value
	end
	return s
end

T.test("nevermore: danger is rooted or hit, with enemies close", function()
	local X = shadowFiend()
	local reason = X.DangerReason
	T.eq(reason(situation({ rooted = true, enemies350 = 2 })), "rooted", "rooted, two bodies on him")
	T.eq(reason(situation({ hitByHeroes = true, enemies350 = 2 })), "melee", "hit, two heroes close")
	T.eq(reason(situation({ hitByHeroes = true, enemies350 = 1, hp = 0.4 })), "melee", "hit, one hero, low HP")
	T.eq(reason(situation({ hitByHeroes = true, enemies350 = 1 })), nil, "hit, one hero, healthy")
	T.eq(reason(situation({ rooted = true, enemies350 = 0, hp = 0.2 })), nil, "rooted, nobody near")
	T.eq(reason(situation({ enemies350 = 3 })), nil, "neither rooted nor hit")
end)

T.test("nevermore: danger Requiem needs a few souls, not ten", function()
	local X = shadowFiend()
	local reason = X.RequiemDangerReason
	T.eq(reason(situation({ rooted = true, enemies350 = 2, souls = 6 })), "rooted", "6 souls, healthy")
	T.eq(
		reason(situation({ rooted = true, enemies350 = 2, souls = X.REQUIEM_DANGER_MIN_SOULS })),
		"rooted",
		"at the floor"
	)
	T.eq(
		reason(situation({ rooted = true, enemies350 = 2, souls = X.REQUIEM_DANGER_MIN_SOULS - 1 })),
		nil,
		"too few lines to fear anyone"
	)
	T.eq(reason(situation({ rooted = true, enemies350 = 2, souls = 0 })), nil, "no souls, no lines")
end)

T.test("nevermore: SkillsComplement runs with the stub", function()
	local X = shadowFiend()
	X.SkillsComplement()
	T.ok(true)
end)
