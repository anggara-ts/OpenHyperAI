-- OHA_MUTED (FuncLib/systems/global_overrides.lua): proven log lines are dropped before they are printed.
-- Real lines from games 038/039: the muted ones must not print, the ones still under watch must print.
local T = ...
local Stub = T.stub

local function capture()
	Stub.reset({ hero = "npc_dota_hero_lich" })
	require(GetScriptDirectory() .. "/FuncLib/systems/global_overrides")
	local printed = {}
	local raw = _G.OHA_RAW_PRINT
	_G.OHA_RAW_PRINT = function(msg)
		printed[#printed + 1] = msg
	end
	return printed, function()
		_G.OHA_RAW_PRINT = raw
	end
end

local MUTED = {
	"[OHA-EVASIVE] t=54 kez enter hp=1.00 foes= casting= tracking= linear=mirana_arrow zones=",
	"[OHA-RETREAT] t=155 night_stalker over-evasive start hp=0.39 enemies=1 allies=1 hit=true mode=19 desire=1.25",
	"[OHA-PUSH] t=847 alchemist behind-stop lane=1 tier=2 alive=4/5 nw=13970/9020 lvl=6.8/7.8",
	"[OHA-FARM] t=1322 tusk base-siege-hold siege=5 at=-4640,-4144 dist=1280 farm=0.05",
	"[OHA-FARM] t=636 alchemist enemy-half-withdraw why=finish mode=17 at=-201,61 to=822,918 alive=5/5",
	"[OHA-ATTACK] t=172 kez follow-skip no-fight ally=tusk allyMode=3 dist=227",
	"[OHA-KITE] t=134 rubick from monkey_king dist=238 step=250 since=0.43 window=0.42-0.94 spa=1.36",
	"[OHA-MONKEY_KING] t=111 spring-skip why=cannot-use-ability(using) active=none mods= hidden=false cd=0.0",
	"[OHA-NS] t=349 feast result started=true goldDelta=39 cdAt=0.1 reissues=0 dist=135 creepAlive=false",
	"[OHA-MEEPO] t=161 clone rune-skip body-in-fight dist=47",
	"[OHA-MEEPO] t=161 clone farm-skip body-in-fight dist=47 enemies=1 allies=1",
	"[OHA-LANE] t=16 alchemist harass-step by=tusk dist=238 step=150 hp=0.80",
	"[OHA-SHREDDER] t=82 retreat whirling-death enemies=1 allies=1 hp=0.48",
	"[OHA-EMBER_SPIRIT] t=496 retreat to remnant 1128 away (farthest toward fountain)",
	"[OHA-TUSK] t=3240 buddies-retreat chaser=keeper_of_the_light ally=shredder enemies=1",
	"[OHA-RETREAT] t=7 meepo healthy-fight-kept hp=1.00 allies=1 visible=1 recent=2 hit=false",
	"[OHA-FARM] t=541 obsidian_destroyer enemy-camp-uncovered lane=3 campToAncient=9903 waveToAncient=12591 at=3978,-5027",
	"[OHA-DEFEND] t=642 rubick chat-skip why=already-held lane=3 allies=3 enemies=2",
}
local KEPT = {
	"[OHA-FARM] t=631 alchemist enemy-half-withdraw why=outnumbered mode=16 at=-870,-657 to=822,918 alive=5/5",
	"[OHA-RETREAT] t=913 meepo hard-retreat hold hp=0.17 allies=2 pressure=3 mode=4",
	"[OHA-RETREAT] t=1115 meepo desire=0.70 line=201 hp=1.00 mp=0.97 enemies1200=2 allies1200=3",
	"[OHA-DEFEND] t=1321 kez group-up lane=mid siege=5 at=-4640,-4144 grouped=1 engaged=1 dist=587",
	"[OHA-FLIP] t=1521 rubick changes=26 moved=797 at=840,-3696 hp=1.00 enemies=0",
	"[OHA-ITEM] t=2374 rubick pull-check promote dust result=reverted slot=6 dest=4(mekansm)",
	"[OHA-FORAGE] t=1191 keeper_of_the_light eat item_foragers_health slot0",
	"[OHA-PUCK] t=73 jaunt why=solo-no-tower target=ember_spirit hp=0.58",
	"[OHA-RETREAT] t=1834 abaddon hard-retreat healthy-outnumbered hp=0.85 allies=1 visible=3 hit=true",
	"[OHA-PUSH] t=1834 abaddon wait-outside-tower why=backdoor tower=npc_dota_goodguys_tower2_mid dist=994 range=868",
	"[OHA-LANE] t=300 lion lasthit-skip why=low-hp creep=creep_goodguys_melee by=lina hp=0.35 walk=0",
	"[OHA-MEEPO] t=240 poof-skip why=no-target",
	"[OHA-BUYBACK] t=2326 meepo buyback why=enemies-at-base pos=2 anc=1.00 remaining=62 gold=1695",
	"[OHA-ERROR] t=11.2 meepo Think: attempt to index a nil value",
}

T.test("OHA_MUTED drops the proven lines", function()
	local printed, restore = capture()
	for _, line in ipairs(MUTED) do
		print(line)
	end
	restore()
	T.eq(#printed, 0, "muted lines printed: " .. table.concat(printed, " | "))
end)

T.test("OHA_MUTED keeps the lines still under watch", function()
	local printed, restore = capture()
	for _, line in ipairs(KEPT) do
		print(line)
	end
	restore()
	T.eq(#printed, #KEPT, "kept lines printed")
end)
