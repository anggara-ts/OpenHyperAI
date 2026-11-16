-- Casts abilities and uses items while the bot is already in some other mode.
local a = {}
local b = GetBot()
local c = b:GetUnitName()
if b == nil or b:IsInvulnerable() or not b:IsHero() or not string.find(c, "hero") or b:IsIllusion() then
	return
end
if not b.frameProcessTime then
	b.frameProcessTime = 0.1
end
local d = GetTeam()
local e = 10 == 10
local f = require(GetScriptDirectory() .. "/FuncLib/func_utils")
-- Logs switched off once their feature works (the TP diag lines, game 029).
local function NoLog() end
local g = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local h = dofile(GetScriptDirectory() .. "/BotsLib/" .. string.gsub(c, "npc_dota_", ""))
local i = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local j = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")
local ChargeTracker = require(GetScriptDirectory() .. "/FuncLib/systems/charge_tracker")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
j.ThinkLess = j.Enable and j.ThinkLess or 1
local lastHumanPingTime = -1
local function LogHumanPing()
	local myId = b:GetPlayerID()
	local loggerId = nil
	for _, pid in ipairs(GetTeamPlayers(GetTeam())) do
		local member = GetTeamMember(pid)
		if member ~= nil and member:IsBot() and not member:IsIllusion() and member:IsAlive() then
			local id = member:GetPlayerID()
			if loggerId == nil or id < loggerId then
				loggerId = id
			end
		end
	end
	if loggerId ~= myId then
		return
	end
	local human, ping = g.GetHumanPing()
	if human == nil or ping == nil or ping.location == nil or ping.time == nil or ping.time == 0 then
		return
	end
	if ping.time == lastHumanPingTime or GameTime() - ping.time > 1.5 then
		lastHumanPingTime = ping.time
		return
	end
	lastHumanPingTime = ping.time
	local loc = ping.location
	print(string.format(
		"[OHA-PING] %.0f %.0f %.0f normal=%s t=%.1f",
		loc.x,
		loc.y,
		loc.z or 0,
		tostring(ping.normal_ping),
		DotaTime()
	))
end
-- When already attacking a valid target and not in danger, skip heavy item/ability
-- rescans for ~3 engine frames * ThinkLess (DotaTime-based, not wall clock).
local THINK_SAMPLE_FRAME = 0.033
local function ShouldThrottleHeavyThink()
	local thinkLess = tonumber(j.ThinkLess) or 1
	if thinkLess <= 0 then
		return false
	end
	local now = DotaTime()
	local tgt = b:GetAttackTarget()
	local locked = tgt ~= nil
		and not tgt:IsNull()
		and tgt:IsAlive()
		and not tgt:IsInvulnerable()
		and GetUnitToUnitDistance(b, tgt) <= 1600
	local urgent = not locked
		or b:GetHealth() / math.max(1, b:GetMaxHealth()) < 0.45
		or b:WasRecentlyDamagedByAnyHero(1.2)
		or b:WasRecentlyDamagedByTower(1.2)
		or b:WasRecentlyDamagedByCreep(1.0)
	-- Urgent / no target: every tick. Locked & safe: every ~3 ticks * ThinkLess.
	local interval = urgent and 0 or (THINK_SAMPLE_FRAME * 3 * math.max(1, thinkLess))
	local last = b._ohaHeavyThinkAt or -100
	if now - last < interval then
		return true
	end
	b._ohaHeavyThinkAt = now
	return false
end
local k, l = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/dispel")
if not k then
	l = nil
end
if GAMEMODE_TURBO == nil then
	GAMEMODE_TURBO = 23
end
if GAMEMODE_ARDM == nil then
	GAMEMODE_ARDM = 20
end
if h == nil then
	log("[ERROR] BotBuild is nil for %s - hero file failed to load. No items/abilities.", c)
	return
end
local m = h["bDeafaultAbility"]
local n = h["bDeafaultItem"]
local o = h["sSkillList"]
local p = Vector(-6619, -6336, 384)
local q = Vector(6928, 6372, 392)
local r = false
local s = nil
local t = {
	["kez_echo_slash"] = "kez_falcon_rush",
	["kez_falcon_rush"] = "kez_echo_slash",
	["kez_grappling_claw"] = "kez_talon_toss",
	["kez_talon_toss"] = "kez_grappling_claw",
	["kez_kazurai_katana"] = "kez_shodo_sai",
	["kez_shodo_sai"] = "kez_kazurai_katana",
	["kez_raptor_dance"] = "kez_ravens_veil",
	["kez_ravens_veil"] = "kez_raptor_dance",
}
local function u(v)
	local w = string.gsub(c, "npc_dota_", "")
	log("[Reload] %s for %s, loading BotsLib/%s", v, c, w)
	local x, y = pcall(dofile, GetScriptDirectory() .. "/BotsLib/" .. w)
	if x and y ~= nil then
		h = y
		m = h["bDeafaultAbility"]
		n = h["bDeafaultItem"]
		if y["sSkillList"] ~= nil and #y["sSkillList"] > 0 then
			local z = y["sSkillList"]
			local A = b:GetLevel()
			local B = A - b:GetAbilityPoints()
			local C = {}
			for D = B + 1, #z do
				table.insert(C, z[D])
			end
			if #C > 0 then
				o = C
			else
				o = f.Utils.CombineTablesUnique(f.Skill.GetTalentList(b), f.Skill.GetAbilityList(b))
			end
			log("[Reload] Skill list: %s entries remaining (spent %s points)", #o, B)
		end
	else
		log("[Reload] dofile FAILED for %s: %s", w, y)
	end
end
local function E()
	local F, G, H = f.IsStaleARDMHero(b, c)
	if F then
		log("[ARDM] Stale ability script: this=%s, current=%s", c, H)
		return true
	end
	if H ~= c then
		log("[ARDM] Hero swap detected: %s -> %s", c, H)
		b = G
		c = H
		r = true
	elseif G ~= b then
		b = G
	end
	if r and b:IsAlive() then
		r = false
		local w = string.gsub(c, "npc_dota_", "")
		log("[ARDM] Loading BotsLib/%s.lua for %s", w, c)
		local x, y = pcall(dofile, GetScriptDirectory() .. "/BotsLib/" .. w)
		if not x then
			log("[ARDM] dofile FAILED for %s: %s", w, y)
		end
		if x and y ~= nil and y["sSkillList"] ~= nil and #y["sSkillList"] > 0 then
			h = y
			m = h["bDeafaultAbility"]
			n = h["bDeafaultItem"]
			o = h["sSkillList"]
			log("[ARDM] Loaded BotsLib for %s with %s skill entries, first: %s", c, #o, o[1])
		else
			local I = f.Skill.GetAbilityList(b)
			local J = f.Skill.GetTalentList(b)
			log("[ARDM] BotsLib load failed or empty for %s, abilities: %s, talents: %s", c, #I, #J)
			if #I > 0 then
				h = nil
				m = false
				n = false
				o = f.Utils.CombineTablesUnique(J, I)
				log("[ARDM] Using generic build for %s with %s entries", c, #o)
			else
				log("[ARDM] Abilities not ready for %s, retrying next frame", c)
				r = true
			end
		end
	elseif r and not b:IsAlive() then
		log("[ARDM] Waiting for %s to respawn", c)
	end
	return false
end
local function K()
	if GetGameState() ~= GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
		return
	end
	if f.CanNotUseAbility(b) then
		return
	end
	local L = f.GetPosition(b)
	if s == nil then
		s = L
		if
			b.isBear == nil
			and GetGameMode() ~= GAMEMODE_1V1MID
			and GetGameState() == GAME_STATE_PRE_GAME
			and b.announcedRole ~= L
		then
			pcall(function()
				b:ActionImmediate_Chat(i.Get("say_play_pos") .. tostring(L), false)
				b.announcedRole = L
			end)
		end
	elseif L ~= s then
		log("[PosSwap] %s position changed: pos%s -> pos%s", c, s, L)
		s = L
		u("Position swap to pos" .. L)
		b.needPurchaseRebuild = true
		if b.isBear == nil and b.announcedRole ~= L then
			pcall(function()
				b:ActionImmediate_Chat(i.Get("say_play_pos") .. tostring(L), false)
				b.announcedRole = L
			end)
		end
	end
	if b:GetLevel() >= 30 and c == "npc_dota_hero_bloodseeker" then
		return
	end
	if DotaTime() < 15 then
		b.theRole = f.Role.GetCurrentSuitableRole(b, c)
	end
	local M = b:GetLocation()
	if
		b:IsAlive()
		and DotaTime() > 90
		and b:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO
		and not IsLocationPassable(M)
	then
		if b.stuckLoc == nil then
			b.stuckLoc = M
			b.stuckTime = DotaTime()
		elseif b.stuckLoc ~= M then
			b.stuckLoc = M
			b.stuckTime = DotaTime()
		end
	else
		b.stuckTime = nil
		b.stuckLoc = nil
	end
	if b.needRefreshAbilitiesFor737 ~= nil and h ~= nil then
		o = h["sSkillList"]
		if not b.needRefreshAbilitiesFor737 then
			b.needRefreshAbilitiesFor737 = nil
		end
	end
	local A = b:GetLevel()
	if GetGameMode() == GAMEMODE_ARDM and b:GetAbilityPoints() > 0 then
		if #o > 0 then
			log(
				"[ARDM] %s Lv%s has %s ability points, skill list has %s entries, next: %s",
				c,
				A,
				b:GetAbilityPoints(),
				#o,
				o[1]
			)
		else
			log("[ARDM] %s Lv%s has %s ability points, skill list has %s entries", c, A, b:GetAbilityPoints(), #o)
		end
	end
	if #o >= 1 and b:GetAbilityPoints() > 0 then
		if f.IsTryingtoUseAbility(b) then
			return
		end
		local N = o[1]
		if N == nil then
			log("[WARN] Nil entry in sAbilityLevelUpList for %s, removing", c)
			table.remove(o, 1)
			return
		end
		local O = b:GetAbilityByName(N)
		if O == nil and GetGameMode() == GAMEMODE_ARDM then
			local I = f.Skill.GetAbilityList(b)
			local J = f.Skill.GetTalentList(b)
			if #I >= 3 then
				log(
					"[ARDM] Ability '%s' not found on %s, rebuilding skill list (abilities: %s, talents: %s)",
					N,
					c,
					#I,
					#J
				)
				o = f.Utils.CombineTablesUnique(J, I)
				return
			else
				log("[ARDM] Abilities not ready for %s (%s), waiting", c, #I)
				return
			end
		end
		if O ~= nil and O:IsHidden() then
			local P = t[N]
			if P then
				local Q = b:GetAbilityByName(P)
				if Q ~= nil and not Q:IsHidden() then
					O = Q
					N = P
				end
			end
		end
		if N == "phoenix_fire_spirits" then
			local R = b:GetAbilityByName("phoenix_launch_fire_spirit")
			if R ~= nil and not R:IsHidden() then
				return
			end
		end
		if N == "alchemist_unstable_concoction" then
			local S = b:GetAbilityByName("alchemist_unstable_concoction_throw")
			if S ~= nil and not S:IsHidden() then
				return
			end
		end
		if O == nil then
			log("[WARN] Ability %s not found on %s, skipping", N, c)
			table.remove(o, 1)
			return
		end
		-- The server rejects a train order for anything the hero cannot learn right now
		-- ("Ability is not owned by specified unit"). Only send one that will land.
		local function CanLearn(ab)
			return ab ~= nil
				and not ab:IsNull()
				and not ab:IsHidden()
				and ab:GetName() ~= "generic_hidden"
				and not g.AbilityBehaviorHasFlag(ab:GetBehavior(), DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE or 64)
				and ab:CanAbilityBeUpgraded()
				and ab:GetLevel() < ab:GetMaxLevel()
				and A >= ab:GetHeroLevelRequiredToUpgrade()
		end
		local function FallbackAbility()
			local best = nil
			for slot = 0, 25 do
				local ab = b:GetAbilityInSlot(slot)
				if CanLearn(ab) then
					if ab:IsUltimate() then
						return ab
					end
					if not ab:IsTalent() and (best == nil or best:IsTalent() or ab:GetLevel() < best:GetLevel()) then
						best = ab
					elseif best == nil then
						best = ab
					end
				end
			end
			return best
		end
		if CanLearn(O) then
			b:ActionImmediate_LevelAbility(O:GetName())
			table.remove(o, 1)
		elseif
			N == "generic_hidden"
			or O:IsHidden() and A >= 25
			or g.AbilityBehaviorHasFlag(O:GetBehavior(), DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE or 64)
			or O:GetLevel() >= O:GetMaxLevel()
		then
			-- This entry can never be learned. Spend the point on something that can.
			table.remove(o, 1)
			local fb = FallbackAbility()
			log("[WARN] %s cannot learn %s, using %s instead", c, N, fb and fb:GetName() or "nothing")
			if fb ~= nil then
				b:ActionImmediate_LevelAbility(fb:GetName())
			end
		elseif not O:IsHidden() and A >= O:GetHeroLevelRequiredToUpgrade() then
			table.remove(o, 1)
			local fb = FallbackAbility()
			log("[WARN] %s cannot upgrade %s now, using %s instead", c, N, fb and fb:GetName() or "nothing")
			if fb ~= nil then
				b:ActionImmediate_LevelAbility(fb:GetName())
			end
		else
			log("[WARN] Skipped to level up ability %s for %s for this time because it may fail.", N, c)
			if A > 25 then
				log("[WARN] Ignore ability %s for %s because it may always fail.", N, c)
				table.remove(o, 1)
			end
		end
	end
	if A > 25 and A < 30 and b:GetAbilityPoints() >= 1 and #o <= 3 then
		o = f.Utils.CombineTablesUnique(f.Skill.GetTalentList(b), f.Skill.GetAbilityList(b))
	end
	if GetGameMode() == GAMEMODE_ARDM and #o == 0 and b:GetAbilityPoints() > 0 then
		log("[ARDM] Skill list exhausted for %s at Lv%s with %s points, rebuilding", c, A, b:GetAbilityPoints())
		o = f.Utils.CombineTablesUnique(f.Skill.GetTalentList(b), f.Skill.GetAbilityList(b))
	end
end
function a.GetLaneByPosition(b)
	if IsLanMode and IsLanMode() then
		local U = b:GetAssignedLane()
		if U == LANE_TOP or U == LANE_MID or U == LANE_BOT then
			return U
		end
	end
	local V = f.GetPosition(b)
	if GetTeam() == TEAM_RADIANT then
		if V == 1 then
			return LANE_BOT
		elseif V == 2 then
			return LANE_MID
		elseif V == 3 or V == 4 then
			return LANE_TOP
		elseif V == 5 then
			return LANE_BOT
		end
	else
		if V == 1 then
			return LANE_TOP
		elseif V == 2 then
			return LANE_MID
		elseif V == 3 or V == 4 then
			return LANE_BOT
		elseif V == 5 then
			return LANE_TOP
		end
	end
	return b:GetAssignedLane() or LANE_MID
end
function a.GetNumEnemyNearby(W)
	local X = 0
	for D, Y in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(Y) then
			local Z = GetHeroLastSeenInfo(Y)
			if Z ~= nil then
				local _ = Z[1]
				if _ ~= nil and GetUnitToLocationDistance(W, _.location) <= 3000 and _.time_since_seen < 1.0 then
					X = X + 1
				end
			end
		end
	end
	return X
end
local a0 = 0
function a.GetRemainingRespawnTime()
	if a0 == 0 then
		return 0
	else
		return b:GetRespawnTime() - (DotaTime() - a0)
	end
end
local a1 = RandomInt(14, 20)
local a2 = RandomInt(19, 56) / 10
local a3 = -999
local a4 = 9999
local a5 = 999
local a6 = 0
local a7 = 0
local a8 = 0
local a9 = RandomInt(5, 9)
local aa = false
local ab = nil
local ac = nil
local ad = false
function a.SetTalkMessage()
	local ae = b:GetPlayerID()
	local af = b:GetGold()
	local ag = GetHeroKills(ae)
	local ah = GetHeroDeaths(ae)
	local ai = GetGameMode() == GAMEMODE_TURBO and 2.0 or 1.0
	if ae == f.Role.GetReplyMemberID() and a8 <= a9 then
		if not aa and GetGameState() == GAME_STATE_GAME_IN_PROGRESS then
			aa = true
			InstallChatCallback(function(aj)
				a.SetReplyHumanTime(aj)
			end)
		end
		if ac ~= nil and ab ~= nil and DotaTime() > ab + a2 then
			local ak = f.Chat.GetReplyString(ac, ad)
			if ak ~= nil then
				if a8 == a9 then
					ak = f.Chat.GetStopReplyString()
				end
				b:ActionImmediate_Chat(ak, ad)
				a8 = a8 + 1
				a2 = RandomInt(6, 30) / 10
				if a2 > 2.0 then
					a2 = RandomInt(6, 30) / 10
				end
			end
			ac = nil
			ab = nil
		end
	end
	if f.Customize.Allow_Trash_Talk then
		if
			DotaTime() < 600
			and b:IsAlive()
			and ag > a5
			and f.GetNumOfTeamTotalKills(false) == 1
			and f.GetNumOfTeamTotalKills(true) == 0
			and RandomInt(1, 9) > 4
		then
			local al = i.Get("got_first_blood")[RandomInt(1, #i.Get("got_first_blood"))]
			b:ActionImmediate_Chat(al, true)
		end
		if b:IsAlive() and af > a4 + 300 * ai and ag > a5 then
			local al = "?"
			if f.Customize.Trash_Talk_Level and f.Customize.Trash_Talk_Level >= 2 then
				if RandomInt(1, 9) > 7 then
					al = i.Get("got_a_kill")[RandomInt(1, #i.Get("got_a_kill"))]
				end
				if af > a4 + 800 * ai and RandomInt(1, 9) > 4 then
					al = i.Get("got_big_kill")[RandomInt(1, #i.Get("got_big_kill"))]
				end
				if af > a4 + 1000 * ai and RandomInt(1, 9) > 3 then
					al = i.Get("got_big_kill_2")[RandomInt(1, #i.Get("got_big_kill_2"))]
				end
				if af > a4 + 1500 * ai then
					al = i.Get("got_big_kill_3")[RandomInt(1, #i.Get("got_big_kill_3"))]
				end
			end
			if RandomInt(1, 9) > 4 then
				b:ActionImmediate_Chat(al, true)
			end
		end
		if not b:IsAlive() then
			if a7 >= 8 and a3 == -999 then
				a3 = DotaTime()
				a7 = 0
			end
			if a3 ~= -999 and a3 < DotaTime() - a2 then
				b:ActionImmediate_Chat(i.Get("kill_streak_ended")[RandomInt(1, #i.Get("kill_streak_ended"))], true)
				a3 = -999
				a2 = RandomInt(36, 49) / 10
			end
		end
		if ag == 0 and ah >= a1 and f.Role.NotSayJiDi() then
			b:ActionImmediate_Chat(i.Get("say_end")[RandomInt(1, #i.Get("say_end"))], true)
			f.Role["sayJiDi"] = true
		end
	end
	if a6 == ah then
		if ag >= a5 + 1 then
			a7 = a7 + 1
		end
	else
		a7 = 0
	end
	a5 = GetHeroKills(ae)
	a6 = GetHeroDeaths(ae)
	a4 = b:GetGold()
end
function a.SetReplyHumanTime(aj)
	local am = aj.string
	local an = aj.player_id
	if string.find(am, "!sp") or string.find(am, "!speak") then
		local ao, ap = f.Utils.TrimString(am):match("^(%S+)%s+(.*)$")
		log("Set to speak: %s", ap)
		f.Customize.Localization = ap
		return
	end
	local aqCmd = f.Utils.TrimString(am or ""):lower()
	if aqCmd == "!debug" or aqCmd == "!verbose" then
		if not IsPlayerBot(an) and (aj.team_only or f.Role.IsAllyMemberID(an)) then
			f.Utils.DebugMode = not f.Utils.DebugMode
			IsDebug = f.Utils.DebugMode
			f.Utils.GameStates = f.Utils.GameStates or {}
			f.Utils.GameStates.verboseChat = f.Utils.DebugMode
			local ar = f.Utils.DebugMode and i.Get("say_debug_on") or i.Get("say_debug_off")
			if type(ar) == "table" and #ar > 0 then
				ar = ar[RandomInt(1, #ar)]
			end
			b:ActionImmediate_Chat(ar or (f.Utils.DebugMode and "Verbose debug ON." or "Verbose debug OFF."), false)
		end
		return
	end
	if am ~= "-都来守家" or f.Role.IsAllyMemberID(an) then
		f.Role.SetLastChatString(am)
	end
	if not IsPlayerBot(an) and (aj.team_only or f.Role.IsEnemyMemberID(an)) then
		ac = am
		ab = DotaTime()
		ad = not aj.team_only
	end
end
local function aq()
	if f.IsMeepoClone(b) then
		return
	end
	a.SetTalkMessage()
	if b:GetLevel() <= 15 or b:HasModifier("modifier_arc_warden_tempest_double") or not f.Role.ShouldBuyBack() then
		return
	end
	if b:IsAlive() and a0 ~= 0 then
		a0 = 0
	end
	if not b:IsAlive() then
		if a0 == 0 then
			a0 = DotaTime()
		end
	end
	if b:IsAlive() then
		return
	end
	if not b:HasBuyback() then
		return
	end
	local ar = GetAncient(GetTeam())
	local as = b:GetRespawnTime()
	local at = a.GetRemainingRespawnTime()
	if ar ~= nil and ar:GetHealth() < 0.8 then
		local au = f.GetEnemiesAroundLoc(ar:GetLocation(), 1500)
		local av = f.GetAlliesNearLoc(ar:GetLocation(), 1500)
		if au > 1 and av == 0 and at > 20 then
			f.Role["lastbbtime"] = DotaTime()
			b:ActionImmediate_Buyback()
			return
		end
	end
	if as < 45 then
		return
	end
	if b:GetLevel() > 24 and at > 80 then
		local aw = f.GetTeamFightLocation(b)
		if aw ~= nil then
			f.Role["lastbbtime"] = DotaTime()
			b:ActionImmediate_Buyback()
			return
		end
	end
	if at < 40 then
		return
	end
	if ar ~= nil then
		local ax = a.GetNumEnemyNearby(ar)
		local ay = f.GetNumOfAliveHeroes(false)
		if ax > 0 and ax >= ay then
			f.Role["lastbbtime"] = DotaTime()
			b:ActionImmediate_Buyback()
			return
		end
	end
end
local az = -90
local aA = -1
b.SShopUser = false
local aB = -90
local aC = -90
local function aD()
	if DotaTime() < -56 or b:HasModifier("modifier_arc_warden_tempest_double") or aB + 5.0 > DotaTime() then
		return
	end
	if b.theCourier == nil then
		b.theCourier = a.GetBotCourier(b)
		return
	end
	local aE = 10 == 10
	local aF = b.theCourier
	aA = GetCourierState(aF)
	local aG = aF:GetHealth() / aF:GetMaxHealth()
	local aH = DotaTime()
	local aI = b:IsAlive()
	local aJ = b:GetLevel()
	local aK = 2.3
	local aL = 5.0
	if aA == COURIER_STATE_DEAD then
		return
	end
	if a.IsCourierTargetedByUnit(aF) then
		if aH > aB + aL then
			aB = aH
			f.SetReportMotive(aE, "信使可能会被攻击")
			b:ActionImmediate_Courier(aF, COURIER_ACTION_RETURN_STASH_ITEMS)
			local aM = aF:GetAbilityByName("courier_burst")
			if aM and aM:IsFullyCastable() then
				b:ActionImmediate_Courier(aF, COURIER_ACTION_BURST)
			end
			return
		end
	end
	if b.SShopUser and (not aI or b:GetActiveMode() == BOT_MODE_SECRET_SHOP or not b.SecretShop) then
		b.SShopUser = false
		f.SetReportMotive(aE, "让信使返回基地避免被卡住")
		b:ActionImmediate_Courier(aF, COURIER_ACTION_RETURN_STASH_ITEMS)
		return
	end
	if
		(aA == COURIER_STATE_RETURNING_TO_BASE or aA == COURIER_STATE_AT_BASE or aA == COURIER_STATE_IDLE)
		and aH > aB + aL
	then
		if aA == COURIER_STATE_AT_BASE and aG < 0.8 then
			return
		end
		if aA == COURIER_STATE_IDLE and aF:DistanceFromFountain() > 800 then
			f.SetReportMotive(aE, "让空闲的信使返回")
			b:ActionImmediate_Courier(aF, COURIER_ACTION_RETURN_STASH_ITEMS)
			return
		end
		-- Before 0:20 stash items wait, except wards: supports buy them at -60s (after the
		-- human's 30s on fresh stock) wherever they are, and the courier brings them out.
		if aI and aH < 20 and (aA == COURIER_STATE_AT_BASE or aA == COURIER_STATE_IDLE and aF:DistanceFromFountain() < 800) then
			local wardInStash = false
			for slot = 9, 14 do
				local it = b:GetItemInSlot(slot)
				local nm = it ~= nil and it:GetName() or ""
				if nm == "item_ward_observer" or nm == "item_ward_sentry" or nm == "item_ward_dispenser" then
					wardInStash = true
					break
				end
			end
			if wardInStash then
				pcall(a.LogCourier, "take")
				b:ActionImmediate_Courier(aF, COURIER_ACTION_TAKE_STASH_ITEMS)
				az = aH
				return
			end
			if b:GetCourierValue() > 0 and aH > az + aK then
				pcall(a.LogCourier, "deliver")
				b:ActionImmediate_Courier(aF, COURIER_ACTION_TRANSFER_ITEMS)
				az = aH
				return
			end
		end
		if
			aI
			and (not a.IsInvFull(b) or aH <= 5 * 60 or b.currBuyingBasicItemList ~= nil and #b.currBuyingBasicItemList == 0 and b.currBuyingItemInPurchaseList ~= "item_travel_boots")
			and (aA == COURIER_STATE_AT_BASE or aA == COURIER_STATE_IDLE and aF:DistanceFromFountain() < 800)
		then
			local aN = a.GetNumStashItem(b)
			if aN > 0 and aH >= 20 then
				if
					b.currBuyingBasicItemList ~= nil and #b.currBuyingBasicItemList == 0
					or b.currBuyingBasicItem ~= nil
						and (IsItemPurchasedFromSecretShop(b.currBuyingBasicItem) or a.GetNumStashItem(b) == 6 or b:GetGold() + 80 < GetItemCost(
							b.currBuyingBasicItem
						))
				then
					f.SetReportMotive(aE, "信使取出物品并开始运输")
					pcall(a.LogCourier, "take")
				b:ActionImmediate_Courier(aF, COURIER_ACTION_TAKE_STASH_ITEMS)
					az = aH
					if aH > aC + aL then
						aC = aH
						local aM = aF:GetAbilityByName("courier_burst")
						if aM and aM:IsFullyCastable() then
							f.SetReportMotive(aE, "信使加速配送")
							b:ActionImmediate_Courier(aF, COURIER_ACTION_BURST)
						end
					end
				end
			end
		end
		if
			aI
			and b.SecretShop
			and aF:DistanceFromFountain() < 7000
			and f.Item.GetEmptyInventoryAmount(aF) >= 2
			and not a.IsEnemyHeroAroundSecretShop()
			and aH > az + aK
		then
			f.SetReportMotive(aE, "信使前往神秘商店购物")
			b:ActionImmediate_Courier(aF, COURIER_ACTION_SECRET_SHOP)
			b.SShopUser = true
			az = aH
			return
		end
		if
			aI
			and aH >= 20
			and b:GetCourierValue() > 0
			and b:GetStashValue() < 100
			and (not a.IsInvFull(b) or a.GetNumStashItem(b) == 0 and b.currBuyingBasicItemList ~= nil and #b.currBuyingBasicItemList == 0)
			and (aF:DistanceFromFountain() < 4000 + aJ * 200 or GetUnitToUnitDistance(b, aF) < 1800)
			and aH > az + aK
		then
			f.SetReportMotive(aE, "信使运输背包中的东西")
			pcall(a.LogCourier, "deliver")
				b:ActionImmediate_Courier(aF, COURIER_ACTION_TRANSFER_ITEMS)
			az = aH
			return
		end
	end
end
function a.GetBotCourier(b)
	local aO = b:GetPlayerID()
	for aP = 0, 4 do
		local aQ = GetCourier(aP)
		if aQ:GetPlayerID() == aO then
			return aQ
		end
	end
end
function a.GetNumStashItem(aR)
	local aS = 0
	for D = 9, 14 do
		if aR:GetItemInSlot(D) ~= nil then
			aS = aS + 1
		end
	end
	return aS
end
function a.IsThereRecipeInStash(aR)
	local aS = 0
	for D = 9, 14 do
		local aT = aR:GetItemInSlot(D)
		if aT ~= nil then
			if string.find(aT:GetName(), "item_recipe_") then
				aS = aS + 1
			end
		end
	end
	return aS > 0
end
function a.IsCourierTargetedByUnit(aQ)
	if GetGameMode() == GAMEMODE_TURBO then
		return false
	end
	local aJ = b:GetLevel()
	if f.GetHP(aQ) < 0.9 then
		return true
	end
	if aQ:DistanceFromFountain() < 900 then
		return false
	end
	for D = 0, 10 do
		local aU = GetTower(GetOpposingTeam(), D)
		if aU ~= nil and aU:CanBeSeen() then
			local aV = aU:GetAttackTarget()
			if aV == aQ then
				return true
			end
			if aV == nil and GetUnitToUnitDistance(aQ, aU) < 999 then
				return true
			end
		end
	end
	for D, Y in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(Y) then
			local Z = GetHeroLastSeenInfo(Y)
			if Z ~= nil then
				local _ = Z[1]
				if _ ~= nil and GetUnitToLocationDistance(aQ, _.location) <= 800 and _.time_since_seen < 1.8 then
					return true
				end
			end
		end
	end
	local aW = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	for aX, aY in pairs(aW) do
		if GetUnitToUnitDistance(aY, aQ) <= 700 + aJ * 15 then
			local aZ = f.GetAlliesNearLoc(aY:GetLocation(), 600)
			if #aZ == 0 or aY:GetAttackTarget() == aQ then
				return true
			end
		end
		if aY:GetUnitName() == "npc_dota_hero_sniper" and GetUnitToUnitDistance(aY, aQ) <= 1100 + aJ * 30 then
			return true
		end
		if GetUnitToUnitDistance(aY, aQ) <= aY:GetAttackRange() + 88 then
			return true
		end
	end
	local a_ = f.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
	for aX, aY in pairs(a_) do
		if aY ~= nil and f.IsValidHero(aY) and GetUnitToUnitDistance(aY, aQ) <= 700 + aJ * 15 then
			local aZ = f.GetAlliesNearLoc(aY:GetLocation(), 800)
			if #aZ == 0 or aY:GetAttackTarget() == aQ then
				return true
			end
		end
		if aY ~= nil and f.IsValidHero(aY) and GetUnitToUnitDistance(aY, aQ) <= aY:GetAttackRange() + 100 then
			return true
		end
	end
	local b0 = GetUnitList(UNIT_LIST_ENEMY_CREEPS)
	local aZ = f.GetAlliesNearLoc(aQ:GetLocation(), 1500)
	local b1 = #aZ
	for aX, b2 in pairs(b0) do
		if
			GetUnitToUnitDistance(aQ, b2) <= 800
			and (b2:GetAttackTarget() == aQ or aJ > 10)
			and (b1 == 0 or b2:GetAttackTarget() == aQ)
		then
			return true
		end
	end
	return false
end
function a.IsInvFull(b)
	for D = 0, 8 do
		if b:GetItemInSlot(D) == nil then
			return false
		end
	end
	return true
end
function a.IsEnemyHeroAroundSecretShop()
	local b3 = GetShopLocation(d, SHOP_SECRET)
	local b4 = GetShopLocation(d, SHOP_SECRET2)
	local b5 = d == TEAM_DIRE and b4 or b3
	local b6 = (b5 + GetAncient(d):GetLocation()) * 0.5
	if f.IsEnemyHeroAroundLocation(b6, 2000) then
		return true
	end
	return false
end
local b7 = {}
local b8 = 0
local b9 = 0
local ba = false
local bb = -90
local bc = {}
local bd = {}
local be = nil
local bf = -1
-- Doom (or its Scepter aura): spells and healing are blocked, items are not (Valve data:
-- does_mute empty). It pierces BKB and cannot be dispelled. Items still work; only uses that
-- heal or restore mana for the doomed hero, or try to cure the silence, are wasted.
function a.IsDoomed(unit)
	return unit ~= nil
		and (unit:HasModifier("modifier_doom_bringer_doom") or unit:HasModifier("modifier_doom_bringer_doom_aura_enemy"))
end
-- Doom's talent special_bonus_unique_doom_10 "Doom applies Mute" (Valve data): with it, a
-- doomed hero cannot use items either. Checked on the enemy Doom, in addition to IsMuted().
function a.IsDoomMuted(unit)
	if not a.IsDoomed(unit) then
		return false
	end
	if unit:IsMuted() then
		return true
	end
	for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
		if enemy ~= nil and not enemy:IsNull() and enemy:GetUnitName() == "npc_dota_hero_doom_bringer" then
			local ok, trained = pcall(function()
				local talent = enemy:GetAbilityByName("special_bonus_unique_doom_10")
				return talent ~= nil and talent:IsTrained()
			end)
			if ok and trained then
				return true
			end
		end
	end
	return false
end
-- Only healing is blocked; mana still pays for item actives (BKB, Force Staff, Shiva's...).
-- Pure heals are skipped; HP+mana items only when mana is not low; mana items are not touched.
local DOOM_HEAL_ONLY = {
	item_flask = true,
	item_tango = true,
	item_tango_single = true,
	item_faerie_fire = true,
	item_greater_faerie_fire = true,
	item_satanic = true,
}
local DOOM_HEAL_AND_MANA = {
	item_magic_stick = true,
	item_magic_wand = true,
	item_holy_locket = true,
	item_bottle = true,
	item_cheese = true,
}
local function DoomWastes(name)
	if DOOM_HEAL_ONLY[name] then
		return true
	end
	return DOOM_HEAL_AND_MANA[name] == true and b:GetMana() / math.max(1, b:GetMaxMana()) >= 0.3
end
local function bg()
	a.SetStashItemTimeUpdate()
	-- WD: cash Gris-Gris before other item logic (bypasses CanCastAbility).
	if a.TryConsumeGrisGris and a.TryConsumeGrisGris() then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Shadow Amulet during a teleport channel (item use below is off while channelling).
	if b:IsAlive() and b:HasModifier("modifier_teleporting") and a.AmuletDuringTeleport() then
		return BOT_ACTION_DESIRE_NONE
	end
	if
		not b:IsAlive()
		or b:IsMuted()
		or b:IsHexed()
		or b:IsStunned()
		or b:IsChanneling()
		or b:IsInvulnerable()
		or b:IsUsingAbility()
		or b:IsCastingAbility()
		or b:NumQueuedActions() > 0
		or b:HasModifier("modifier_teleporting")
		-- Plain Doom silences and blocks healing but leaves items usable (does_mute empty); its
		-- Mute talent blocks items too.
		or a.IsDoomMuted(b)
		or b:HasModifier("modifier_phantom_lancer_phantom_edge_boost")
		or b:HasModifier("modifier_life_stealer_infest")
		or b:HasModifier("modifier_nyx_assassin_vendetta") and f.IsRealInvisible(b)
		or a.WillBreakInvisible(b)
	then
		return BOT_ACTION_DESIRE_NONE
	end
	bc = f.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
	bd = b:GetNearbyTowers(888, true)
	be = f.GetProperTarget(b)
	bf = b:GetActiveMode()
	if bf ~= BOT_MODE_ATTACK and bf ~= BOT_MODE_RETREAT then
		local bh = false
		local bi = b:GetAttackTarget()
		if bi ~= nil and bi:IsHero() then
			bh = true
		elseif #bc > 0 and (b:WasRecentlyDamagedByAnyHero(2.0) or f.IsAttacking(b)) then
			bh = true
		end
		if bh then
			bf = BOT_MODE_ATTACK
		end
	end
	local bj = f.IsItemAvailable("item_aether_lens")
	if bj ~= nil then
		b8 = 250
	else
		b8 = 0
	end
	pcall(a.BannerFromBackpack)
	-- Smoke of Deceit is castable from the backpack. Other items stay in the main slots.
	-- Forage in the main inventory is eaten immediately. A backpack copy is swapped out and eaten.
	for forageSlot = 0, 5 do
		local forage = b:GetItemInSlot(forageSlot)
		if forage ~= nil and not forage:IsNull() and not f.CanCastAbility(forage) then
			local fn = forage:GetName()
			if
				(fn == "item_foragers_stats" or fn == "item_foragers_health" or fn == "item_foragers_mana")
				and DotaTime() >= (b._forageStuckLogAt or -999)
			then
				b._forageStuckLogAt = DotaTime() + 20
				pcall(print, string.format(
					"[OHA-FORAGE] t=%.0f %s cannot-eat %s slot%d fully=%s cd=%.1f hidden=%s passive=%s mana=%.0f",
					DotaTime(),
					(string.gsub(c, "npc_dota_hero_", "")),
					fn,
					forageSlot,
					tostring(forage:IsFullyCastable()),
					forage:GetCooldownTimeRemaining(),
					tostring(forage:IsHidden()),
					tostring(forage:IsPassive()),
					b:GetMana()
				))
			end
		end
		if forage ~= nil and not forage:IsNull() and f.CanCastAbility(forage) then
			local forageName = forage:GetName()
			if forageName == "item_foragers_stats" or forageName == "item_foragers_mana" then
				b:Action_UseAbility(forage)
				return BOT_ACTION_DESIRE_NONE
			elseif forageName == "item_foragers_health" then
				b:Action_UseAbilityOnEntity(forage, b)
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	local bk = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 15, 16 }
	for aX, bl in pairs(bk) do
		local bm = b:GetItemInSlot(bl)
		local bn = bm ~= nil and bm:GetName() or nil
		local inBackpack = bl >= 6 and bl <= 8
		local smokeFromBag = inBackpack and bn == "item_smoke_of_deceit"
		if inBackpack and not smokeFromBag then
			bn = nil
		end
		local ready = f.CanCastAbility(bm)
		if smokeFromBag and bm ~= nil and not bm:IsNull() then
			local cd = bm:GetCooldownTimeRemaining()
			ready = not (type(cd) == "number" and cd > 0)
		end
		if ready and bn ~= nil and a.IsDoomed(b) and DoomWastes(bn) then
			ready = false
		end
		if ready and bn ~= nil then
			if a.ConsiderItemDesire[bn] ~= nil and not a.IsItemInStash(bn) then
				local bo, bp, bq, brReason = a.ConsiderItemDesire[bn](bm)
				if bo > 0 then
					local brAllies = f.GetAllyList(b, 1200) or {}
					MatchTrace.Item(
						b,
						bn,
						"use",
						string.format(
							"desire=%.2f cast=%s note=%s mode=%s allies=%d",
							bo,
							tostring(bq),
							tostring(brReason or ""),
							tostring(bf),
							#brAllies
						)
					)
					if string.find(bn, "tpscroll", 1, true) or string.find(bn, "travel_boots", 1, true) then
						a.LogTeleport(bn, bp, brReason, bf)
					end
					a.SetUseItem(bm, bp, bq)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- [OHA-TP]: every teleport with its reason, where from and to, and which lane the target is
-- on next to the lane this bot is laning in (by position) and the engine's assignment.
function a.LogTeleport(item, target, reason, mode)
	if target == nil or type(target) ~= "userdata" and type(target) ~= "table" then
		return
	end
	local ok, tx, ty = pcall(function()
		return target.x, target.y
	end)
	if not ok or type(tx) ~= "number" then
		return
	end
	local names = { [LANE_TOP] = "top", [LANE_MID] = "mid", [LANE_BOT] = "bot" }
	local nearestLane, nearestDist = nil, math.huge
	for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
		local along = GetAmountAlongLane(lane, target)
		if along ~= nil and along.distance < nearestDist then
			nearestLane, nearestDist = lane, along.distance
		end
	end
	local here = b:GetLocation()
	pcall(print, string.format(
		"[OHA-TP] t=%.0f %s %s why=%s mode=%s hp=%.2f foes=%d allies=%d posLane=%s engineLane=%s from=%.0f,%.0f to=%.0f,%.0f targetLane=%s",
		DotaTime(),
		(string.gsub(c, "npc_dota_hero_", "")),
		(string.gsub(item, "^item_", "")),
		tostring(reason),
		tostring(mode),
		b:GetHealth() / math.max(1, b:GetMaxHealth()),
		#(b:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}),
		#(b:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}) - 1,
		tostring(names[a.GetLaneByPosition(b)]),
		tostring(names[b:GetAssignedLane()]),
		here.x,
		here.y,
		tx,
		ty,
		tostring(names[nearestLane])
	))
end
function a.SetUseItem(bm, bp, bq)
	if bm == nil or bm:IsNull() then
		return
	end
	-- Never issue orders on hidden abilities (server: invalid order 60).
	if bm.IsHidden and bm:IsHidden() then
		return
	end
	if bq == "none" then
		b:Action_UseAbility(bm)
		return
	elseif bq == "unit" and type(bp) == "table" then
		b:Action_UseAbilityOnEntity(bm, bp)
		if string.find(bm:GetName(), "tango") then
			b._lastTangoUseTime = DotaTime()
		end
		return
	elseif bq == "ground" or bp and type(bp) ~= "number" and type(bp) ~= "table" and bp.x ~= nil then
		b:Action_UseAbilityOnLocation(bm, bp)
		return
	elseif bq == "tree" then
		b:Action_UseAbilityOnTree(bm, bp)
		b._lastTangoUseTime = DotaTime()
		return
	elseif bq == "twice" then
		b:Action_UseAbility(bm)
		b:ActionQueue_UseAbility(bm)
		return
	end
end
function a.IsWithoutSpellShield(br)
	return not br:HasModifier("modifier_item_sphere_target")
		and not br:HasModifier("modifier_antimage_spell_shield")
		and not br:HasModifier("modifier_item_lotus_orb_active")
end
local bs = -90
function a.SetStashItemTimeUpdate()
	local aH = DotaTime()
	for D = 6, 8 do
		local bm = b:GetItemInSlot(D)
		if bm ~= nil then
			b7[bm:GetName()] = aH
		end
	end
	if aH > bs + 7.0 then
		bs = aH
		for bt, bu in pairs(b7) do
			if bu ~= nil and bu < aH - 7.0 then
				b7[bt] = nil
			end
		end
	end
end
function a.IsItemInStash(bn)
	if b7[bn] ~= nil and DotaTime() < b7[bn] + 6.05 then
		return true
	end
	return false
end
function a.WillBreakInvisible(b)
	if not b:IsInvisible() then
		return false
	end
	local c = c
	if c == "npc_dota_hero_riki" or c == "npc_dota_hero_bounty_hunter" or c == "npc_dota_hero_slark" then
		return false
	end
	if b:HasModifier("modifier_phantom_assassin_blur_active") then
		return false
	end
	if b:HasModifier("modifier_item_glimmer_cape_fade") then
		return false
	end
	if b:HasModifier("modifier_item_shadow_amulet_fade") then
		return true
	end
	if
		b:HasModifier("modifier_item_invisibility_edge_windwalk") or b:HasModifier("modifier_item_silver_edge_windwalk")
	then
		return true
	end
	if b:HasModifier("modifier_smoke_of_deceit") then
		return true
	end
	return false
end
a.ConsiderItemDesire = {}
a.ConsiderItemDesire["item_abyssal_blade"] = function(bm)
	-- Overwhelm is melee range (150) and pierces debuff immunity. A short
	-- approach is allowed on top of the real range.
	local bv = 150 + b8 + 100
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local hMenace = f.GetRightclickMenaceLock(b, bv + 200, "pierce")
	if hMenace ~= nil and a.IsWithoutSpellShield(hMenace) then
		return BOT_ACTION_DESIRE_HIGH, hMenace, bq, "stun carry"
	end
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	for aX, br in pairs(bx) do
		if f.IsValid(br) and f.CanCastOnMagicImmune(br) and a.IsWithoutSpellShield(br) then
			if br:IsChanneling() or br:IsCastingAbility() then
				hEffectTarget = br
				bw = "打断:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if bf == BOT_MODE_RETREAT and not f.IsDisabled(br) then
				hEffectTarget = br
				bw = "撤退:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.IsInRange(b, be, bv + 50)
			and f.CanCastOnMagicImmune(be)
			and a.IsWithoutSpellShield(be)
			and not f.IsDisabled(be)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_ancient_janggo"] = function(bm)
	if bm:GetCurrentCharges() <= 0 and bm:GetName() == "item_ancient_janggo" then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 680
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if b:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	if f.IsGoingOnSomeone(b) then
		if f.IsValidHero(be) and f.CanCastOnMagicImmune(be) and f.IsInRange(b, be, bv) then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_arcane_boots"] = function(bm)
	if b:DistanceFromFountain() < 800 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 1200
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local by = f.GetAllyList(b, bv)
	if #by >= 2 and b:GetHealth() <= 120 and b:WasRecentlyDamagedByAnyHero(3.0) then
		bw = "死前为队友用"
		return BOT_ACTION_DESIRE_HIGH, by[2], bq, bw
	end
	local bz = 0
	for aX, bA in pairs(by) do
		if bA ~= nil and bA:IsAlive() and bA:GetMaxMana() - bA:GetMana() > 180 then
			bz = bz + 1
		end
		if bz >= 2 then
			bw = "团队回蓝"
			return BOT_ACTION_DESIRE_HIGH, by[2], bq, bw
		end
	end
	if b:GetMana() / b:GetMaxMana() < 0.65 then
		bw = "自己补蓝"
		return BOT_ACTION_DESIRE_HIGH, b, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Armlet of Mordiggian (Valve data: +35 damage, +25 strength, +4 armor while on, 45 HP/s drain;
-- neither the drain nor switching off can kill; the strength comes in and goes out over 0.6s).
-- Returning HIGH toggles it. On when it pays for the drain, off as soon as it no longer does;
-- the rules below switch it back on when needed.
-- 1. Worth on: an enemy hero within attack range + 300, Roshan, Tormentor, or a building while
--    pushing. Not lane creeps or neutrals (it used to be on through every farm).
-- 2. On early when chasing a hero within attack range + 600, so the strength is in by the hit.
-- 3. Held 3s after the last reason, and while an enemy hero is within 800 in a fight, so it
--    does not flicker off between targets.
-- 4. Not off below 30% HP with an enemy hero within 1200 (switching off takes the strength HP).
-- 5. Toggle trick: on, being hit, HP below what the strength gives (measured when it turns on):
--    off, then straight back on (at most once a second; not under Doom, which blocks the gain).
-- Never toggled under Ancient Apparition's Ice Blast: changing max HP there can drop him under
-- the shatter threshold.
a.ConsiderItemDesire["item_armlet"] = function(bm)
	local on = bm:GetToggleState()
	local now = DotaTime()
	if b:HasModifier("modifier_ice_blast") then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Strength HP: max HP with it on minus off, measured once it has settled (0.6s+).
	if on and b._armletOnAt ~= nil and now - b._armletOnAt > 0.8 and b._armletMaxOff ~= nil then
		b._armletHpGain = math.max(0, b:GetMaxHealth() - b._armletMaxOff)
	elseif not on and (b._armletOffAt == nil or now - b._armletOffAt > 0.8) then
		b._armletMaxOff = b:GetMaxHealth()
	end
	local function TurnOn(why)
		b._armletOnAt = now
		b._armletWhy = why
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	local function TurnOff(why)
		b._armletOffAt = now
		b._armletWhy = why
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	-- 5. Second half of the trick: back on right away.
	if not on and b._armletTrickAt ~= nil and now - b._armletTrickAt < 0.5 then
		b._armletTrickAt = nil
		return TurnOn("trick-on")
	end
	local doomed = a.IsDoomed(b)
	local heroNear = f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE) or {}
	local hit = b:WasRecentlyDamagedByAnyHero(1.5) or f.IsAttackProjectileIncoming(b, 1000)
	if
		on
		and not doomed
		and hit
		and b._armletHpGain ~= nil
		and b._armletHpGain > 0
		and b:GetHealth() < b._armletHpGain * 0.9
		and now - (b._armletTrickLast or -99) >= 1
	then
		b._armletTrickAt = now
		b._armletTrickLast = now
		return TurnOff("trick-off")
	end
	-- 1 and 2: reasons to be on.
	local want = false
	if f.IsValid(be) and f.CanBeAttacked(be) and not b:IsDisarmed() then
		local reach = b:GetAttackRange() + 300
		if be:IsHero() and be:GetTeam() ~= b:GetTeam() then
			if f.IsInRange(b, be, reach) then
				want = true
			elseif f.IsGoingOnSomeone(b) and f.IsInRange(b, be, reach + 300) then
				want = true
			end
		elseif (f.IsRoshan(be) or f.IsTormentor(be)) and f.IsInRange(b, be, reach) then
			want = true
		elseif
			be:IsBuilding()
			and not string.find(be:GetUnitName(), "OutpostName")
			and f.IsPushing(b)
			and f.IsInRange(b, be, reach)
		then
			want = true
		end
	end
	-- Survival: on to gain the strength HP (blocked by Doom, so not then).
	if not doomed then
		if f.IsRetreating(b) and not f.IsRealInvisible(b) and f.GetHP(b) < 0.2 then
			if
				b:WasRecentlyDamagedByAnyHero(2.0)
				or f.IsAttackProjectileIncoming(b, 1200)
				or f.IsStunProjectileIncoming(b, 550)
			then
				want = true
			end
		end
		if
			f.GetAttackProjectileDamageByRange(b, 600) > b:GetHealth() * 2
			or f.IsStunProjectileIncoming(b, 600) and f.GetHP(b) < 0.25
		then
			want = true
		end
	end
	-- 3. Hold.
	if want then
		b._armletHoldUntil = now + 3
	end
	local fightNear = #(f.GetNearbyHeroes(b, 800, true, BOT_MODE_NONE) or {}) > 0
		and (f.IsGoingOnSomeone(b) or f.IsInTeamFight(b, 1200))
	local holding = now < (b._armletHoldUntil or -99) or fightNear
	-- 4. Low with enemies around: keep it on.
	local lowNearEnemy = f.GetHP(b) < 0.3 and #heroNear > 0
	if not on then
		if want then
			return TurnOn("worth")
		end
		return BOT_ACTION_DESIRE_NONE
	end
	if want or holding or lowNearEnemy then
		return BOT_ACTION_DESIRE_NONE
	end
	return TurnOff("not-worth")
end
a.ConsiderItemDesire["item_bfury"] = function(bm)
	return a.ConsiderItemDesire["item_quelling_blade"](bm)
end
a.ConsiderItemDesire["item_black_king_bar"] = function(bm)
	if b:HasModifier("modifier_dazzle_nothl_projection_soul_debuff") then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 1300
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if
		#bx > 0
		and not b:IsMagicImmune()
		and not b:IsInvulnerable()
		and not b:HasModifier("modifier_item_lotus_orb_active")
		and not b:HasModifier("modifier_antimage_spell_shield")
		and (f.IsGoingOnSomeone(b) or f.IsRetreating(b))
	then
		local bC = f.GetEnemyCount(b, 600)
		if b:IsRooted() then
			bw = "解缠绕"
			return BOT_ACTION_DESIRE_HIGH, b, bq, bw
		end
		if
			b:IsSilenced()
			and not a.IsDoomed(b)
			and b:GetMana() > 100
			and not b:HasModifier("modifier_item_mask_of_madness_berserk")
			and bC >= 2
		then
			bw = "解沉默"
			return BOT_ACTION_DESIRE_HIGH, b, bq, bw
		end
		if f.IsNotAttackProjectileIncoming(b, 350) and bC >= 1 then
			bw = "防御弹道"
			return BOT_ACTION_DESIRE_HIGH, b, bq, bw
		end
		if f.IsWillBeCastUnitTargetSpell(b, bv) and bC >= 1 then
			bw = "防御指向技能"
			return BOT_ACTION_DESIRE_HIGH, b, bq, bw
		end
		if f.IsWillBeCastPointSpell(b, bv) and bC >= 1 then
			bw = "防御地点技能"
			return BOT_ACTION_DESIRE_HIGH, b, bq, bw
		end
		if f.GetEnemyCount(b, 800) >= 3 then
			bw = "先开BKB切入"
			return BOT_ACTION_DESIRE_HIGH, b, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_blade_mail"] = function(bm)
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsNotAttackProjectileIncoming(b, 366) and #bx >= 1 then
		hEffectTarget = b
		bw = "反弹弹道"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	for aX, br in pairs(bc) do
		if
			f.IsValidHero(br)
			and f.CanCastOnNonMagicImmune(br)
			and br:GetAttackTarget() == b
			and (b:WasRecentlyDamagedByHero(br, 5.0) or f.IsAttackProjectileIncoming(b, 1000))
		then
			hEffectTarget = br
			bw = "反弹敌人伤害:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_blink"] = function(bm)
	local bv = 1200
	if bm:GetName() == "item_arcane_blink" then
		bv = 1400
	end
	bv = bv + b8
	if f.HasItemInInventory("item_magnifying_monocle") then
		bv = bv + 100
	end
	if f.HasItemInInventory("item_enhancement_keen_eyed") then
		if DotaTime() >= (f.IsModeTurbo() and 7.5 * 60 or 15 * 60) then
			bv = bv + 125
		elseif DotaTime() >= (f.IsModeTurbo() and 12.5 * 60 or 25 * 60) then
			bv = bv + 135
		end
	end
	if f.HasItemInInventory("item_enhancement_mystical") then
		if DotaTime() >= (f.IsModeTurbo() and 17.5 * 60 or 35 * 60) then
			bv = bv + 100
		end
	end
	if f.HasItemInInventory("item_enhancement_boundless") then
		if DotaTime() >= (f.IsModeTurbo() and 30 * 60 or 60 * 60) then
			bv = bv + 350
		end
	end
	local c = b:GetUnitName()
	if b:IsRooted() or b:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	if f.IsStuck(b) then
		local bD = f.GetLocationTowardDistanceLocation(b, GetAncient(GetTeam()):GetLocation(), bv)
		return BOT_ACTION_DESIRE_HIGH, bD, "ground", nil
	end
	local bE = b:GetNearbyHeroes(800, false, BOT_MODE_ATTACK)
	if f.IsRetreating(b) and not f.IsRealInvisible(b) and b:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE then
		local bF = f.GetLocationTowardDistanceLocation(b, GetAncient(GetTeam()):GetLocation(), bv)
		local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), 1200)
		if
			b:DistanceFromFountain() > 900
			and IsLocationPassable(bF)
			and (#bE <= 1 or b:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH * 0.9)
			and nInRangeEnemy ~= nil
			and #nInRangeEnemy >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, bF, "ground", nil
		end
	end
	bE = b:GetNearbyHeroes(1600, false, BOT_MODE_ATTACK)
	if
		#bE <= 1
		and (be == nil or not be:IsHero())
		and f.IsFarming(b)
		and not b:WasRecentlyDamagedByAnyHero(3.1)
		and not f.IsPushing(b)
		and not f.IsDefending(b)
	then
		local bG = b:FindAoELocation(true, false, b:GetLocation(), bv, 500, 0, 0)
		local bH = b:GetNearbyLaneCreeps(1600, true)
		local nInRangeEnemy = f.GetEnemiesNearLoc(bG.targetloc, 1600)
		if bH ~= nil and #bH >= 4 and nInRangeEnemy ~= nil and #nInRangeEnemy == 0 and bG.count >= 4 then
			local bI = f.GetCenterOfUnits(bH)
			local bJ = GetUnitToLocationDistance(b, bI)
			local bF = f.GetLocationTowardDistanceLocation(b, bI, bJ + 550)
			local bK = f.GetLocationTowardDistanceLocation(b, bI, bJ - 300)
			if bJ > bv then
				bK = f.GetLocationTowardDistanceLocation(b, bI, bv)
			end
			if
				IsLocationPassable(bK)
				and GetUnitToLocationDistance(b, bK) > 600
				and IsLocationVisible(bF)
				and not f.IsLocHaveTower(700, true, bK)
			then
				return BOT_ACTION_DESIRE_HIGH, bK, "ground", nil
			end
		end
	end
	if
		f.IsProjectileIncoming(b, 1200) and (
			be == nil
			or not be:IsHero()
			or not f.IsInRange(b, be, b:GetAttackRange() + 100)
		)
	then
		local bD = f.GetLocationTowardDistanceLocation(b, GetAncient(GetTeam()):GetLocation(), 1199)
		return BOT_ACTION_DESIRE_HIGH, bD, "ground", nil
	end
	if f.IsGoingOnSomeone(b) then
		if
			b.shouldBlink ~= nil
			and b.shouldBlink
			and (
				c == "npc_dota_hero_batrider"
				or c == "npc_dota_hero_beastmaster"
				or c == "npc_dota_hero_dark_seer"
				or c == "npc_dota_hero_earthshaker"
				or c == "npc_dota_hero_magnataur"
				or c == "npc_dota_hero_rubick"
				or c == "npc_dota_hero_tiny"
				or c == "npc_dota_hero_treant"
			)
		then
			return BOT_ACTION_DESIRE_NONE
		end
		if c == "npc_dota_hero_nevermore" then
			local bL = b:GetAbilityByName("nevermore_requiem")
			if f.CanCastAbility(bL) then
				return BOT_ACTION_DESIRE_NONE
			end
		end
		if
			f.IsValidTarget(be)
			and f.IsInRange(b, be, bv)
			and f.CanBeAttacked(be)
			and not f.IsInRange(b, be, 500)
			and not be:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not be:HasModifier("modifier_enigma_black_hole_pull")
		then
			local bE = f.GetAlliesNearLoc(be:GetLocation(), 1200)
			local nInRangeEnemy = f.GetEnemiesNearLoc(be:GetLocation(), 1200)
			local bM = f.WeAreStronger(b, 1200)
			local bN = 0
			for aX, Y in pairs(GetTeamPlayers(GetOpposingTeam())) do
				if IsHeroAlive(Y) then
					local Z = GetHeroLastSeenInfo(Y)
					if Z ~= nil then
						local _ = Z[1]
						if
							_ ~= nil
							and _.time_since_seen < 3.0
							and GetUnitToLocationDistance(be, _.location) <= 1200
						then
							bN = bN + 1
						end
					end
				end
			end
			if #bE >= bN and bM then
				local bO = Min(bv, GetUnitToUnitDistance(b, be))
				local bF = f.GetUnitTowardDistanceLocation(b, be, bO) + RandomVector(150)
				if IsLocationPassable(bF) then
					return BOT_ACTION_DESIRE_HIGH, bF, "ground", nil
				end
			end
		end
	end
	if f.IsDoingTormentor(b) and not f.IsRealInvisible(b) then
		local bP = f.GetTormentorLocation(GetTeam())
		if GetUnitToLocationDistance(b, bP) > 2000 then
			local bF = f.VectorTowards(b:GetLocation(), bP, bv)
			local nInRangeEnemy = f.GetEnemiesNearLoc(bF, 1200)
			if IsLocationPassable(bF) and #nInRangeEnemy == 0 then
				return BOT_ACTION_DESIRE_HIGH, bF, "ground", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_overwhelming_blink"] = function(bm)
	return a.ConsiderItemDesire["item_blink"](bm)
end
a.ConsiderItemDesire["item_swift_blink"] = function(bm)
	return a.ConsiderItemDesire["item_blink"](bm)
end
a.ConsiderItemDesire["item_arcane_blink"] = function(bm)
	return a.ConsiderItemDesire["item_blink"](bm)
end
a.ConsiderItemDesire["item_cheese"] = function(bm)
	if b:DistanceFromFountain() < 1200 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local bQ = b:GetMaxHealth() - b:GetHealth()
	local bR = b:GetHealth() / b:GetMaxHealth()
	local bS = b:GetMaxMana() - b:GetMana()
	local bT = b:GetMana() / b:GetMaxMana()
	if bQ > 2500 and bS > 1500 or bQ > 2000 and bQ + bS > 3000 or bR < 0.4 and bT < 0.4 or bR < 0.2 or bT < 0.06 then
		if f.IsGoingOnSomeone(b) then
			if f.IsValidHero(be) and f.IsInRange(b, be, 2000) and f.CanCastOnMagicImmune(be) then
				hEffectTarget = b
				bw = "进攻"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
		if f.IsRetreating(b) and b:WasRecentlyDamagedByAnyHero(4.0) then
			hEffectTarget = b
			bw = "撤退"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Bloodstone's Bloodpact (Valve data: spell lifesteal 20% -> 60% for 5s, no mana, 35s cooldown).
-- Worth it only when he is hurt and about to cast: HP below 60%, an enemy hero within 900, and
-- at least one spell ready with the mana for it (one that costs mana or deals damage; many
-- spells report 0 ability damage), while fighting, chasing or under fire
-- (or at Roshan / Tormentor). It used to go on every engage and team fight at any HP, and was
-- often on cooldown by the time the hero was low.
local function SpellReadyToCast()
	for slot = 0, 5 do
		local ab = b:GetAbilityInSlot(slot)
		if ab ~= nil and not ab:IsNull() and ab:IsTrained() and not ab:IsHidden() then
			local okP, passive = pcall(function()
				return ab:IsPassive()
			end)
			local okT, toggle = pcall(function()
				return ab:IsToggle()
			end)
			if
				not (okP and passive)
				and not (okT and toggle)
				and ab:IsFullyCastable()
				and ab:GetManaCost() <= b:GetMana()
				and (ab:GetManaCost() > 0 or (ab:GetAbilityDamage() or 0) > 0)
			then
				return true
			end
		end
	end
	return false
end
-- A damaging spell ready (mana, castable) with an enemy hero inside its reach. Damage is read
-- from the ability damage or the usual damage values (many spells report 0 ability damage);
-- reach is the cast range, or the radius for a no-target spell.
local DAMAGE_KEYS = { "damage", "aoe_damage", "impale_damage", "damage_per_second", "burn_damage", "tick_damage", "max_damage" }
local function DamagingSpellOnEnemy(foes)
	for slot = 0, 5 do
		local ab = b:GetAbilityInSlot(slot)
		if ab ~= nil and not ab:IsNull() and ab:IsTrained() and not ab:IsHidden() then
			local okP, passive = pcall(function()
				return ab:IsPassive()
			end)
			if not (okP and passive) and ab:IsFullyCastable() and ab:GetManaCost() <= b:GetMana() then
				local dmg = ab:GetAbilityDamage() or 0
				if dmg <= 0 then
					for _, key in ipairs(DAMAGE_KEYS) do
						local okV, v = pcall(function()
							return ab:GetSpecialValueFloat(key)
						end)
						if okV and type(v) == "number" and v > 0 then
							dmg = v
							break
						end
					end
				end
				if dmg > 0 then
					local reach = ab:GetCastRange()
					if reach == nil or reach <= 0 then
						local okR, rad = pcall(function()
							return ab:GetSpecialValueInt("radius")
						end)
						reach = (okR and type(rad) == "number" and rad > 0) and rad or 300
					end
					for _, e0 in pairs(foes) do
						if f.IsValidHero(e0) and GetUnitToUnitDistance(b, e0) <= reach + 50 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end
a.ConsiderItemDesire["item_bloodstone"] = function(bm)
	local bq = "none"
	if b:IsSilenced() or b:HasModifier("modifier_item_bloodstone_active") then
		return BOT_ACTION_DESIRE_NONE
	end
	if f.GetHP(b) >= 0.6 then
		return BOT_ACTION_DESIRE_NONE
	end
	local objective = f.IsDoingRoshan(b) or f.IsDoingTormentor(b)
	local foes = f.GetNearbyHeroes(b, 900, true, BOT_MODE_NONE) or {}
	if #foes == 0 and not objective then
		return BOT_ACTION_DESIRE_NONE
	end
	local fighting = f.IsInTeamFight(b, 1200)
		or f.IsGoingOnSomeone(b)
		or b:WasRecentlyDamagedByAnyHero(2)
		or objective
	-- Running away: only with a damaging spell that can reach an enemy now. Bloodpact heals only
	-- from spell damage, so an escape that hits nothing (Leap, Blink, Sinister Gaze) wastes it.
	local spellOk
	if f.IsRetreating(b) then
		spellOk = DamagingSpellOnEnemy(foes)
	else
		spellOk = SpellReadyToCast()
	end
	if fighting and spellOk then
		pcall(print, string.format(
			"[OHA-ITEM] t=%.0f %s bloodstone hp=%.2f foes=%d",
			DotaTime(),
			(string.gsub(c, "npc_dota_hero_", "")),
			f.GetHP(b),
			#foes
		))
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Bloodstone: spell lifesteal while low"
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_bloodthorn"] = function(bm)
	return a.ConsiderItemDesire["item_orchid"](bm)
end
a.ConsiderItemDesire["item_bottle"] = function(bm)
	if bm:GetCurrentCharges() == 0 or b:HasModifier("modifier_bottle_regeneration") then
		return BOT_ACTION_DESIRE_NONE
	end
	if f.HasDamageOverTimeDebuff(b) then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 400 + b8
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bS = b:GetMaxMana() - b:GetMana()
	local bQ = b:OriginalGetMaxHealth() - b:OriginalGetHealth()
	if b:HasModifier("modifier_fountain_aura") then
		hEffectTarget = b
		bw = "在泉水里喝"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if not b:WasRecentlyDamagedByAnyHero(3.0) then
		if bQ > 150 and bS > 90 then
			hEffectTarget = b
			bw = "补血补篮"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if bQ > 500 and f.GetHP(b) < 0.5 then
			hEffectTarget = b
			bw = "只补血"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if bS > 280 and f.GetMP(b) < 0.4 then
			hEffectTarget = b
			bw = "只补篮"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_clarity"] = function(bm)
	if b:DistanceFromFountain() < 2000 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 800 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if
		f.GetMP(b) < 0.4
		and not b:HasModifier("modifier_clarity_potion")
		and #bx == 0
		and not b:WasRecentlyDamagedByAnyHero(4.0)
	then
		hEffectTarget = b
		bw = "净化自己"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if #bx == 0 then
		local bU = f.GetNearbyHeroes(b, 600, false, BOT_MODE_NONE)
		local bV = nil
		local bW = 99999
		for aX, bA in pairs(bU) do
			if
				f.IsValid(bA)
				and bA ~= b
				and not bA:IsIllusion()
				and not bA:IsChanneling()
				and not bA:HasModifier("modifier_clarity_potion")
				and not bA:WasRecentlyDamagedByAnyHero(4.0)
				and bA:GetMaxMana() - bA:GetMana() > 350
			then
				if bA:GetMana() < bW then
					bV = bA
					bW = bA:GetMana()
				end
			end
		end
		if bV ~= nil then
			hEffectTarget = bV
			bw = "净化队友:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_crimson_guard"] = function(bm)
	if b:DistanceFromFountain() < 400 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 1200
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local by = f.GetAllyList(b, bv)
	for aX, bA in pairs(by) do
		if
			f.IsValid(bA)
			and bA:OriginalGetHealth() / bA:OriginalGetMaxHealth() < 0.8
			and bA:WasRecentlyDamagedByAnyHero(2.0)
			and not bA:HasModifier("modifier_item_crimson_guard_nostack")
			and #bc > 0
		then
			hEffectTarget = bA
			bw = "救救队友:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	local bX = f.GetNearbyHeroes(b, 1000, true, BOT_MODE_NONE)
	local bY = b:GetNearbyTowers(800, true)
	if #by >= 2 and (#bX + #bY >= 2 or #bX >= 2) then
		for aX, bA in pairs(by) do
			if bA:WasRecentlyDamagedByAnyHero(2.0) and not bA:HasModifier("modifier_item_crimson_guard_nostack") then
				hEffectTarget = bA
				bw = "保护队友:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_cyclone"] = function(bm)
	local bv = 650 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if b:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Doomed: a self-cyclone is 2.5s invulnerable (Valve data), so it skips ~2 Doom ticks and
	-- any other damage in that window. Used when hurt or under fire.
	if a.IsDoomed(b) and (f.GetHP(b) < 0.5 or b:WasRecentlyDamagedByAnyHero(1.5)) then
		pcall(print, string.format(
			"[OHA-ITEM] t=%.0f %s cyclone-self why=doom hp=%.2f",
			DotaTime(),
			(string.gsub(c, "npc_dota_hero_", "")),
			f.GetHP(b)
		))
		return BOT_ACTION_DESIRE_HIGH, b, bq, "doom"
	end
	if
		f.IsValid(be)
		and f.CanCastOnNonMagicImmune(be)
		and a.IsWithoutSpellShield(be)
		and f.IsInRange(b, be, bv + 200)
	then
		if c == "npc_dota_hero_invoker" and f.IsGoingOnSomeone(b) then
			if f.IsValidHero(be) and not f.IsSuspiciousIllusion(be) and f.GetMP(b) > 0.5 then
				hEffectTarget = be
				bw = "预设连招:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
		if
			be:HasModifier("modifier_invoker_cold_snap_freeze")
			or be:HasModifier("modifier_invoker_cold_snap")
			or be:HasModifier("modifier_invoker_chaos_meteor_burn")
		then
			return BOT_ACTION_DESIRE_NONE
		end
		if
			be:HasModifier("modifier_teleporting")
			or be:HasModifier("modifier_abaddon_borrowed_time")
			or be:HasModifier("modifier_ursa_enrage")
			or be:HasModifier("modifier_item_satanic_unholy")
			or be:IsChanneling()
		then
			hEffectTarget = be
			bw = "驱散Buff:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if f.GetHP(be) > 0.49 and f.IsCastingUltimateAbility(be) then
			hEffectTarget = be
			bw = "打断大招:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if f.IsRunning(be) and be:GetCurrentMovementSpeed() > 440 then
			hEffectTarget = be
			bw = "阻止逃跑:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if f.CanCastOnNonMagicImmune(b) and #bc > 0 then
		if f.GetHP(b) < 0.2 and b:WasRecentlyDamagedByAnyHero(3.0) then
			hEffectTarget = b
			bw = "撤退:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if b:IsRooted() or b:GetPrimaryAttribute() == ATTRIBUTE_INTELLECT and b:IsSilenced() and not a.IsDoomed(b) then
			hEffectTarget = b
			bw = "解缠绕:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if f.IsUnitTargetProjectileIncoming(b, 800) then
			hEffectTarget = b
			bw = "防御弹道:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_wind_waker"] = function(bm)
	return a.ConsiderItemDesire["item_cyclone"](bm)
end
a.ConsiderItemDesire["item_dagon"] = function(bm)
	local bv = bm:GetCastRange() + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv + 100, true, BOT_MODE_NONE)
	local bZ = bm:GetSpecialValueInt("damage")
	if b:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	for aX, br in pairs(bx) do
		if
			f.IsValidHero(br)
			and f.CanCastOnNonMagicImmune(br)
			and a.IsWithoutSpellShield(br)
			and f.CanKillTarget(br, bZ, DAMAGE_TYPE_MAGICAL)
		then
			hEffectTarget = br
			bw = "击杀:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.CanCastOnNonMagicImmune(be)
			and a.IsWithoutSpellShield(be)
			and f.IsInRange(b, be, bv)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_dagon_2"] = function(bm)
	return a.ConsiderItemDesire["item_dagon"](bm)
end
a.ConsiderItemDesire["item_dagon_3"] = function(bm)
	return a.ConsiderItemDesire["item_dagon"](bm)
end
a.ConsiderItemDesire["item_dagon_4"] = function(bm)
	return a.ConsiderItemDesire["item_dagon"](bm)
end
a.ConsiderItemDesire["item_dagon_5"] = function(bm)
	return a.ConsiderItemDesire["item_dagon"](bm)
end
a.ConsiderItemDesire["item_diffusal_blade"] = function(bm)
	local bv = 630 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if bf == BOT_MODE_RETREAT then
		for aX, br in pairs(bc) do
			if
				f.IsValid(br)
				and f.IsMoving(br)
				and f.IsInRange(br, b, bv)
				and b:WasRecentlyDamagedByHero(br, 4.0)
				and br:GetCurrentMovementSpeed() > 200
				and f.CanCastOnNonMagicImmune(br)
				and a.IsWithoutSpellShield(br)
				and not f.IsDisabled(br)
			then
				hEffectTarget = br
				bw = "撤退:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.IsMoving(be)
			and be:GetCurrentMovementSpeed() > 200
			and f.IsInRange(be, b, bv)
			and f.CanCastOnNonMagicImmune(be)
			and a.IsWithoutSpellShield(be)
			and not f.IsDisabled(be)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if
		f.IsValidHero(be)
		and f.IsInRange(be, b, bv)
		and f.CanCastOnNonMagicImmune(be)
		and a.IsWithoutSpellShield(be)
		and not f.IsDisabled(be)
		and b:GetAttackTarget() == be
	then
		hEffectTarget = be
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, "diffusal: in combat"
	end
	local br = bc[1]
	if
		f.IsValidHero(br)
		and f.IsInRange(b, br, bv - 100)
		and f.CanCastOnNonMagicImmune(br)
		and a.IsWithoutSpellShield(br)
		and not f.IsDisabled(br)
		and f.IsMoving(br)
		and f.IsRunning(br)
		and br:GetCurrentMovementSpeed() > b:GetCurrentMovementSpeed() * 0.8
	then
		hEffectTarget = br
		bw = "减速:" .. f.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_enchanted_mango"] = function(bm)
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	if b:GetMana() < 150 then
		hEffectTarget = b
		bw = "自己吃"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_ethereal_blade"] = function(bm)
	local bv = 800 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.CanCastOnNonMagicImmune(be)
			and f.CanCastOnTargetAdvanced(be)
			and f.IsInRange(b, be, bv)
		then
			hEffectTarget = be
			bw = "进攻" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_faerie_fire"] = function(bm)
	if b:DistanceFromFountain() < 1800 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 300 + b8
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if
		bf == BOT_MODE_RETREAT
		and b:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
		and b:WasRecentlyDamagedByAnyHero(3.0)
		and b:OriginalGetHealth() < 90
	then
		hEffectTarget = b
		bw = "撤退"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if f.IsGoingOnSomeone(b) and f.GetHP(b) < 0.3 and f.IsValidHero(be) and b:WasRecentlyDamagedByAnyHero(3.0) then
		hEffectTarget = b
		bw = "进攻"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if
		DotaTime() > 10 * 60
		and bm:GetName() == "item_faerie_fire"
		and b:GetItemInSlot(6) ~= nil
		and b:GetMaxHealth() - b:OriginalGetHealth() > 200
	then
		hEffectTarget = b
		bw = "自己吃"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_flask"] = function(bm)
	if b:DistanceFromFountain() < 3000 then
		return BOT_ACTION_DESIRE_NONE
	end
	if f.HasDamageOverTimeDebuff(b) then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 900
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local b_ = f.GetHP(b)
	if
		b_ < 0.65
		and #bx == 0
		and not b:WasRecentlyDamagedByAnyHero(2.2)
		and not b:HasModifier("modifier_filler_heal")
		and not b:HasModifier("modifier_elixer_healing")
		and not b:HasModifier("modifier_flask_healing")
		and not b:HasModifier("modifier_juggernaut_healing_ward_heal")
	then
		hEffectTarget = b
		bw = "自己吃"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	local bU = f.GetAlliesNearLoc(b:GetLocation(), 700)
	local c0 = nil
	local c1 = 99999
	for aX, bA in pairs(bU) do
		if
			f.IsValid(bA)
			and bA ~= b
			and not bA:HasModifier("modifier_filler_heal")
			and not bA:HasModifier("modifier_elixer_healing")
			and not bA:HasModifier("modifier_flask_healing")
			and not bA:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not bA:WasRecentlyDamagedByAnyHero(3.0)
			and not bA:IsIllusion()
			and not bA:IsChanneling()
			and f.GetHP(bA) < 0.6
		then
			if bA:OriginalGetHealth() < c1 then
				c0 = bA
				c1 = bA:OriginalGetHealth()
			end
		end
	end
	if c0 ~= nil and #bx == 0 then
		hEffectTarget = c0
		bw = "给队友贴:" .. f.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Healing Lotus (item_famango*) — not Lotus Orb. Cannot be sold; use on self or ally (ctrl-click, ~400 range).
-- Pool pickup: supports first, cores low priority. Use: prefer ally if their HP/mana dropped, else self.
-- Late game + full bag: consume (or leave for purchase drop) to free a slot even at high HP/MP.
local function ConsiderHealingLotus(item, label, selfHp, selfMp, allyNeed, fountainDist)
	if b:DistanceFromFountain() < fountainDist then
		return BOT_ACTION_DESIRE_NONE
	end
	local bq = "unit"
	local enemies = f.GetNearbyHeroes(b, 900, true, BOT_MODE_NONE) or {}
	local hp = f.GetHP(b)
	local mp = b:GetMaxMana() > 0 and b:GetMana() / b:GetMaxMana() or 1
	local isSupport = f.GetPosition(b) >= 4
	-- Only supports (or anyone in real emergency) share/use these liberally.
	local hpGate = isSupport and selfHp or math.max(0.32, selfHp - 0.2)
	local mpGate = isSupport and selfMp or math.max(0.22, selfMp - 0.2)
	local lateGame = (GetGameMode() == GAMEMODE_TURBO or GetGameMode() == 23) and (15 * 60) or (25 * 60)
	local bagFull = f.Item.GetEmptyNonBackpackInventoryAmount(b) <= 0

	-- Ally first when their HP/mana dropped (ctrl+click, range 400).
	local allies = f.GetAlliesNearLoc(b:GetLocation(), 400) or {}
	local bestAlly = nil
	local bestScore = -1
	for _, ally in pairs(allies) do
		if
			f.IsValid(ally)
			and ally ~= b
			and not ally:IsIllusion()
			and not ally:HasModifier("modifier_flask_healing")
			and not ally:HasModifier("modifier_filler_heal")
		then
			local aHp = ally:GetHealth() / math.max(1, ally:GetMaxHealth())
			local aMp = ally:GetMaxMana() > 0 and ally:GetMana() / ally:GetMaxMana() or 1
			local need = aHp < allyNeed or aMp < allyNeed
			local urgent = aHp < 0.4 or (aHp < 0.55 and aMp < 0.35)
			if need or urgent then
				-- Prefer helping even with enemies around if urgent; otherwise wait for calm.
				if urgent or #enemies == 0 then
					local score = (1 - aHp) * 1.2 + (1 - aMp) * 0.7
					if urgent then
						score = score + 0.5
					end
					-- Prefer the neediest ally (cores in a fight are fine targets).
					if f.IsCore(ally) then
						score = score + 0.15
					end
					if score > bestScore then
						bestScore = score
						bestAlly = ally
					end
				end
			end
		end
	end
	-- Ally in need beats self top-up (unless we're about to die).
	if bestAlly ~= nil and hp >= 0.28 then
		return BOT_ACTION_DESIRE_HIGH, bestAlly, bq, "Heal ally (" .. label .. "): " .. f.Chat.GetNormName(bestAlly)
	end

	-- Emergency self.
	if hp < 0.28 or (hp < 0.4 and mp < 0.25) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Emergency self (" .. label .. ")"
	end
	-- Self when low and no needy ally.
	if
		(hp < hpGate or mp < mpGate)
		and #enemies == 0
		and not b:WasRecentlyDamagedByAnyHero(2.0)
		and not b:HasModifier("modifier_flask_healing")
		and not b:HasModifier("modifier_filler_heal")
	then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Self heal (" .. label .. ")"
	end
	-- Late game, main inventory full: consume to free a slot (cannot sell).
	-- Step 0: if greater famango can still stack (2+ piles), skip consume — purchase path merges.
	if
		DotaTime() >= lateGame
		and bagFull
		and #enemies == 0
		and not b:WasRecentlyDamagedByAnyHero(2.0)
		and not b:HasModifier("modifier_flask_healing")
	then
		-- Step 0: leave incomplete greater stacks alone if they can still merge (purchase merges).
		if f.Item.CanStackGreaterFamango(b) then
			return BOT_ACTION_DESIRE_NONE
		end
		if item ~= nil and item:GetName() == "item_greater_famango" then
			local charges = f.Item.GetLotusCharges(item)
			local freeName = f.Item.FindLotusToFreeSlot(b)
			-- Prefer consuming a lower-tier / full stack over an incomplete greater pile.
			if charges < f.Item.GREATER_FAMANGO_MAX_STACK and freeName ~= nil and freeName ~= "item_greater_famango" then
				return BOT_ACTION_DESIRE_NONE
			end
		end
		if hp >= 0.9 and mp >= 0.85 then
			return BOT_ACTION_DESIRE_HIGH, b, bq, "Free slot (" .. label .. ", full)"
		end
		-- Still packed but not full resources — use it, then the slot opens.
		if hp < 0.95 or mp < 0.9 then
			return BOT_ACTION_DESIRE_MODERATE, b, bq, "Free slot (" .. label .. ")"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_famango"] = function(cg)
	return ConsiderHealingLotus(cg, "lotus", 0.72, 0.55, 0.65, 2800)
end
a.ConsiderItemDesire["item_great_famango"] = function(cg)
	return ConsiderHealingLotus(cg, "great lotus", 0.65, 0.45, 0.58, 2800)
end
a.ConsiderItemDesire["item_greater_famango"] = function(cg)
	return ConsiderHealingLotus(cg, "greater lotus", 0.55, 0.35, 0.5, 1000)
end
a.ConsiderItemDesire["item_force_staff"] = function(bm)
	local bv = 550 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if b:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	if b:HasModifier("modifier_furion_sprout_damage") then
		hEffectTarget = b
		bw = "解开先知的树框" .. f.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	local bU = f.GetAlliesNearLoc(b:GetLocation(), 600)
	for aX, bA in pairs(bU) do
		if bA ~= nil and bA:IsAlive() and f.CanCastOnNonMagicImmune(bA) then
			local ch = f.GetNearbyHeroes(bA, 1200, true, BOT_MODE_NONE)
			if
				#ch >= 1
				and not bA:IsInvisible()
				and bA:GetActiveMode() == BOT_MODE_RETREAT
				and bA:IsFacingLocation(GetAncient(d):GetLocation(), 30)
				and bA:DistanceFromFountain() > 600
				and bA:WasRecentlyDamagedByAnyHero(4.0)
			then
				hEffectTarget = bA
				bw = "帮队友撤退" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if f.IsGoingOnSomeone(bA) then
				local ci = f.GetProperTarget(bA)
				if
					f.IsValidHero(ci)
					and bA:IsFacingLocation(ci:GetLocation(), 15)
					and f.CanCastOnNonMagicImmune(ci)
					and GetUnitToUnitDistance(ci, bA) > bA:GetAttackRange() + 50
					and GetUnitToUnitDistance(ci, bA) < bA:GetAttackRange() + 700
					and not ci:IsFacingLocation(bA:GetLocation(), 40)
					and f.GetEnemyCount(bA, 1600) <= 3
				then
					hEffectTarget = bA
					bw = "帮队友进攻" .. f.Chat.GetNormName(hEffectTarget)
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
				end
			end
			if f.IsStuck(bA) or bA:HasModifier("modifier_furion_sprout_damage") then
				hEffectTarget = bA
				bw = "队友卡地形了" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	for aX, bA in pairs(bU) do
		if
			bA ~= nil
			and bA:IsAlive()
			and bA:GetUnitName() == "npc_dota_hero_crystal_maiden"
			and f.CanCastOnNonMagicImmune(bA)
			and (bA:IsInvisible() or bA:GetHealth() / bA:GetMaxHealth() > 0.8)
			and (bA:IsChanneling() and not bA:HasModifier("modifier_teleporting"))
		then
			local cj = f.GetNearbyHeroes(bA, 1200, true, BOT_MODE_NONE)
			for aX, br in pairs(cj) do
				if
					br ~= nil
					and br:IsAlive()
					and f.CanCastOnNonMagicImmune(br)
					and GetUnitToUnitDistance(br, bA) > 835
					and bA:IsFacingLocation(br:GetLocation(), 30)
				then
					hEffectTarget = bA
					bw = "推冰女"
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
				end
			end
		end
	end
	if b:DistanceFromFountain() < 2600 then
		for aX, br in pairs(bc) do
			if
				f.IsValidHero(br)
				and f.CanCastOnMagicImmune(br)
				and br:IsFacingLocation(GetAncient(d):GetLocation(), 40)
				and GetUnitToLocationDistance(br, GetAncient(d):GetLocation()) < 1200
			then
				hEffectTarget = br
				bw = "推人入泉" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if f.IsGoingOnSomeone(b) and #bU >= 2 then
		if
			f.IsValidHero(be)
			and f.IsInRange(b, be, bv)
			and f.CanCastOnNonMagicImmune(be)
			and a.IsWithoutSpellShield(be)
		then
			local ck = f.GetCenterOfUnits(bU)
			if be:IsFacingLocation(ck, 28) and GetUnitToLocationDistance(b, ck) >= 500 then
				hEffectTarget = be
				bw = "推敌人靠近自己" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_ghost"] = function(bm)
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	-- A right-click carry is on me. Ghost now, before the 500 HP line below.
	for aX, br in pairs(bc) do
		if
			f.IsValidHero(br)
			and f.tRightclickMenace[br:GetUnitName()]
			and not f.IsSuspiciousIllusion(br)
			and br:GetAttackTarget() == b
			and f.GetHP(b) < 0.75
		then
			return BOT_ACTION_DESIRE_HIGH, br, bq, "ghost vs carry"
		end
	end
	if b:GetAttackTarget() == nil or b:GetHealth() < 500 then
		for aX, br in pairs(bc) do
			if
				f.IsValidHero(br)
				and f.CanCastOnMagicImmune(br)
				and f.IsInRange(b, br, br:GetAttackRange() + 100)
				and br:GetAttackTarget() == b
				and b:WasRecentlyDamagedByHero(br, 2.0)
				and br:GetAttackDamage() > b:GetAttackDamage()
			then
				hEffectTarget = br
				bw = "撤退" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_crellas_crozier"] = function(bm)
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	if b:GetAttackTarget() == nil or b:GetHealth() < 500 then
		for aX, br in pairs(bc) do
			if
				f.IsValidHero(br)
				and f.CanCastOnMagicImmune(br)
				and f.IsInRange(b, br, br:GetAttackRange() + 100)
				and br:GetAttackTarget() == b
				and b:WasRecentlyDamagedByHero(br, 2.0)
				and br:GetAttackDamage() > b:GetAttackDamage()
			then
				hEffectTarget = br
				bw = "撤退" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Witch Doctor innate: cash out Gris-Gris when packed and needing space/gold.
-- item_grisgris is often IsPassive/IsHidden so CanCastAbility never lets ConsiderItemDesire fire.
a.ConsiderItemDesire["item_grisgris"] = function(bm)
	return BOT_ACTION_DESIRE_NONE
end

local GRISGRIS_KEEP = {
	item_grisgris = true,
	item_aegis = true,
	item_rapier = true,
	item_gem = true,
	item_cheese = true,
	item_refresher_shard = true,
	item_tpscroll = true,
	item_ward_observer = true,
	item_ward_sentry = true,
	item_ward_dispenser = true,
	item_smoke_of_deceit = true,
}

local function FindGrisGrisSlot()
	for slot = 0, 16 do
		local it = b:GetItemInSlot(slot)
		if it ~= nil and not it:IsNull() and it:GetName() == "item_grisgris" then
			return slot, it
		end
	end
	return -1, nil
end

local function PendingBuyName()
	local cV = b.currBuyingBasicItem
	if cV == nil and type(b.currBuyingBasicItemList) == "table" and #b.currBuyingBasicItemList > 0 then
		cV = b.currBuyingBasicItemList[#b.currBuyingBasicItemList]
	end
	if cV == nil then
		cV = b.currBuyingItemInPurchaseList
	end
	if cV == "item_aghanims_shard" then
		return nil
	end
	return cV
end

local function InventoryIsPacked()
	return f.Item.GetEmptyNonBackpackInventoryAmount(b) <= 0
end

local function BackpackIsPacked()
	return f.Item.GetEmptyBackpackSlot(b) < 0
end

-- Sell cheapest non-critical item in slots 0-8 so we can shuffle Gris-Gris into a main slot.
local function SellCheapestJunkForGrisGris()
	local bestItem = nil
	local bestCost = 999999
	for slot = 0, 8 do
		local it = b:GetItemInSlot(slot)
		if it ~= nil and not it:IsNull() then
			local name = it:GetName()
			if not GRISGRIS_KEEP[name] and not string.find(name, "token") then
				local cost = GetItemCost(name) or 0
				if cost < bestCost then
					bestCost = cost
					bestItem = it
				end
			end
		end
	end
	if bestItem == nil then
		return false
	end
	b:ActionImmediate_SellItem(bestItem)
	return true
end

local function FreeMainSlotForGrisGris()
	local pack = f.Item.GetEmptyBackpackSlot(b)
	if pack < 0 then
		if not SellCheapestJunkForGrisGris() then
			return -1
		end
		pack = f.Item.GetEmptyBackpackSlot(b)
		if pack < 0 then
			-- Sold a main-slot item; find the empty main slot.
			for main = 0, 5 do
				if b:GetItemInSlot(main) == nil then
					return main
				end
			end
			return -1
		end
	end
	for main = 0, 5 do
		local it = b:GetItemInSlot(main)
		if it ~= nil and it:GetName() ~= "item_grisgris" then
			b:ActionImmediate_SwapItems(main, pack)
			return main
		end
	end
	return -1
end

local function TeamUnderPush()
	local ancient = GetAncient(GetTeam())
	if ancient ~= nil and f.Utils.CountEnemyHeroesNear(ancient:GetLocation(), 3200) >= 1 then
		return true
	end
	if f.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 1 then
		return true
	end
	-- High defend desire = lanes/base getting shoved.
	if f.IsDefending(b) and (b:GetActiveModeDesire() or 0) >= BOT_MODE_DESIRE_HIGH then
		return true
	end
	local maxDefend = math.max(
		GetDefendLaneDesire(LANE_TOP) or 0,
		GetDefendLaneDesire(LANE_MID) or 0,
		GetDefendLaneDesire(LANE_BOT) or 0
	)
	return maxDefend >= 0.55
end

local function AnnounceGrisGrisAllChat(reason)
	local key = "say_consume_grisgris"
	if reason and string.find(reason, "push") then
		key = "say_consume_grisgris_push"
	end
	local cU = i.Get(key)
	if (cU == nil or (type(cU) == "table" and #cU == 0)) and key ~= "say_consume_grisgris" then
		cU = i.Get("say_consume_grisgris")
	end
	local msg = nil
	if type(cU) == "table" and #cU > 0 then
		msg = cU[RandomInt(1, #cU)]
	elseif type(cU) == "string" then
		msg = cU
	else
		msg = "Consuming Gris-Gris!"
	end
	-- true = all-chat
	b:ActionImmediate_Chat(msg, true)
	MatchTrace.Item(b, "item_grisgris", "announce", reason or "")
end

-- Right-click → Consume equivalent for bots is Action_UseAbility on the item handle.
-- Gris-Gris is NOT sellable (ItemSellable=0); SellItem will not cash it out.
local function DoConsumeGrisGris(gris, slot, reason)
	b._grisGrisConsumeAt = DotaTime()
	AnnounceGrisGrisAllChat(reason)
	-- Move into a main slot when possible; consume orders from slot 16 are unreliable.
	if slot == 16 or slot >= 6 then
		local freed = FreeMainSlotForGrisGris()
		if freed >= 0 then
			local cur = FindGrisGrisSlot()
			if cur == 16 or cur >= 6 then
				b:ActionImmediate_SwapItems(cur, freed)
			end
			slot, gris = FindGrisGrisSlot()
		end
	end
	if gris == nil then
		return false
	end
	b:Action_ClearActions(false)
	b:Action_UseAbility(gris)
	MatchTrace.Item(b, "item_grisgris", "consume", string.format("%s slot=%d", reason or "", slot or -1))
	return true
end

-- Early packed bags are starting consumables, not a reason to cash Gris-Gris.
local function GrisGrisMinGameTime()
	-- ~15m normal; turbo compresses the clock (~9m).
	if GetGameMode() == GAMEMODE_TURBO or GetGameMode() == 23 then
		return 9 * 60
	end
	return 15 * 60
end

function a.TryConsumeGrisGris()
	if c ~= "npc_dota_hero_witch_doctor" then
		return false
	end
	if not b:IsAlive() or b:IsMuted() or b:IsHexed() or b:IsStunned() or b:IsChanneling() then
		return false
	end
	if DotaTime() < GrisGrisMinGameTime() then
		return false
	end
	if b._grisGrisConsumeAt ~= nil and DotaTime() - b._grisGrisConsumeAt < 6.0 then
		return false
	end
	local slot, gris = FindGrisGrisSlot()
	if gris == nil then
		return false
	end
	local buyName = PendingBuyName()
	local bagFull = BackpackIsPacked()
	local underPush = TeamUnderPush()
	local packed = InventoryIsPacked()
	-- 1) Team getting pushed → cash gold for buyback/items (even if inv not full).
	-- 2) Packed + pending buy / bag full → free value when stuck.
	if underPush then
		return DoConsumeGrisGris(gris, slot, "push")
	end
	if not packed then
		return false
	end
	if buyName == nil and not bagFull then
		return false
	end
	return DoConsumeGrisGris(
		gris,
		slot,
		string.format("packed buy=%s bagFull=%s", tostring(buyName), tostring(bagFull))
	)
end
a.ConsiderItemDesire["item_glimmer_cape"] = function(bm)
	local bv = 800 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	if
		b:DistanceFromFountain() > 600
		and #bd == 0
		and not b:HasModifier("modifier_item_dustofappearance")
		and not b:HasModifier("modifier_slardar_amplify_damage")
		and not b:HasModifier("modifier_item_glimmer_cape")
		and not b:IsInvulnerable()
		and not b:IsMagicImmune()
	then
		if b:IsSilenced() or b:IsRooted() or f.IsStunProjectileIncoming(b, 1000) then
			hEffectTarget = b
			bw = "自己被缠绕或沉默了"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if
			f.IsRetreating(b)
				and b:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
				and not b:HasModifier("modifier_fountain_aura")
			or be == nil and #bc > 0 and f.GetHP(b) < 0.36 + 0.09 * #bc
		then
			hEffectTarget = b
			bw = "自己撤退"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		local bU = f.GetNearbyHeroes(b, bv, false, BOT_MODE_NONE)
		for aX, bA in pairs(bU) do
			if
				f.IsValid(bA)
				and not bA:IsIllusion()
				and not bA:IsMagicImmune()
				and not bA:IsInvulnerable()
				and not bA:IsInvisible()
				and bA:DistanceFromFountain() > 600
				and not bA:HasModifier("modifier_item_glimmer_cape")
				and not bA:HasModifier("modifier_item_dustofappearance")
				and not bA:HasModifier("modifier_slardar_amplify_damage")
				and not bA:HasModifier("modifier_arc_warden_tempest_double")
			then
				local cl = bA:GetNearbyTowers(888, true)
				if #cl == 0 then
					if
						f.GetHP(bA) < 0.35 + 0.05 * #bc
						and f.IsRetreating(bA)
						and bA:WasRecentlyDamagedByAnyHero(4.0)
					then
						hEffectTarget = bA
						bw = "保护队友撤退:" .. f.Chat.GetNormName(hEffectTarget)
						return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
					end
					if f.IsDisabled(bA) or f.IsStunProjectileIncoming(bA, 1000) then
						hEffectTarget = bA
						bw = "保护被控队友:" .. f.Chat.GetNormName(hEffectTarget)
						return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_mekansm"] = function(bm)
	local bv = 1200
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bU = f.GetAllyList(b, bv)
	for aX, bA in pairs(bU) do
		if bA ~= nil and bA:IsAlive() and f.GetHP(bA) < 0.45 and #bc > 0 then
			hEffectTarget = bA
			bw = "治疗队友" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	local cm = 0
	for aX, bA in pairs(bU) do
		if bA ~= nil and bA:GetMaxHealth() - bA:GetHealth() > 400 then
			cm = cm + 1
			if cm >= 2 and bA:GetHealth() / bA:GetMaxHealth() < 0.55 then
				hEffectTarget = bA
				bw = "治疗二队友:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if cm >= 3 then
				hEffectTarget = bA
				bw = "治疗多个队友:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if
		not a.IsDoomed(b)
		and (
			b:GetHealth() / b:GetMaxHealth() < 0.5
			or b:IsSilenced()
			or b:IsRooted()
			or b:HasModifier("modifier_item_urn_damage")
			or b:HasModifier("modifier_item_spirit_vessel_damage")
		)
	then
		hEffectTarget = b
		bw = "治疗自己:" .. f.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_guardian_greaves"] = function(bm)
	local bv = 1200
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bU = f.GetAllyList(b, bv)
	for aX, bA in pairs(bU) do
		if bA ~= nil and bA:IsAlive() and f.GetHP(bA) < 0.45 and #bc > 0 then
			hEffectTarget = bA
			bw = "治疗队友" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	local cm = 0
	for aX, bA in pairs(bU) do
		if bA ~= nil and bA:GetMaxHealth() - bA:GetHealth() > 400 then
			cm = cm + 1
			if cm >= 2 and bA:GetHealth() / bA:GetMaxHealth() < 0.55 then
				hEffectTarget = bA
				bw = "治疗二队友:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if cm >= 3 then
				hEffectTarget = bA
				bw = "治疗多个队友:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if
		not a.IsDoomed(b)
		and (
			b:GetHealth() / b:GetMaxHealth() < 0.5
			or b:IsSilenced()
			or b:IsRooted()
			or b:HasModifier("modifier_item_urn_damage")
			or b:HasModifier("modifier_item_spirit_vessel_damage")
		)
	then
		hEffectTarget = b
		bw = "治疗自己:" .. f.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	local bz = 0
	for aX, bA in pairs(bU) do
		if bA ~= nil and bA:GetMaxMana() - bA:GetMana() > 400 then
			bz = bz + 1
		end
		if bz >= 2 and b:GetMana() / b:GetMaxMana() < 0.2 then
			hEffectTarget = bA
			bw = "回蓝二队友:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if bz >= 3 then
			hEffectTarget = bA
			bw = "回蓝多个队友:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	local cn = b:GetNearbyLaneCreeps(1200, false)
	if #cn >= 9 then
		local bG = b:FindAoELocation(false, false, b:GetLocation(), 100, 1100, 0, 200)
		if bG.count >= 6 and GetUnitToLocationDistance(b, bG.targetloc) <= 200 then
			hEffectTarget = b
			bw = "治疗小兵们:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_hand_of_midas"] = function(bm)
	local bv = 990 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	if #bc >= 1 then
		bv = 628
	end
	local co = b:GetNearbyCreeps(bv, true)
	local cp = nil
	local cq = 0
	for aX, b2 in pairs(co) do
		if f.IsValid(b2) and not b2:IsMagicImmune() and not b2:IsAncientCreep() then
			if b2:GetLevel() > cq then
				cq = b2:GetLevel()
				cp = b2
			end
		end
	end
	if cp ~= nil then
		hEffectTarget = cp
		bw = "点金小兵:" .. hEffectTarget:GetUnitName()
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_heavens_halberd"] = function(bm)
	local bv = 750 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local hMenace = f.GetRightclickMenaceLock(b, bv, "disarm")
	if hMenace ~= nil and a.IsWithoutSpellShield(hMenace) then
		return BOT_ACTION_DESIRE_HIGH, hMenace, bq, "disarm carry"
	end
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local cr = nil
	local cs = 0
	for aX, br in pairs(bx) do
		if
			f.IsValidHero(br)
			and not br:IsDisarmed()
			and not f.IsDisabled(br)
			and f.CanCastOnNonMagicImmune(br)
			and a.IsWithoutSpellShield(br)
			and br:GetAttackTarget() ~= nil
			and (br:GetPrimaryAttribute() ~= ATTRIBUTE_INTELLECT or br:GetAttackDamage() > 180)
		then
			local ct = br:GetEstimatedDamageToTarget(false, b, 3.0, DAMAGE_TYPE_PHYSICAL)
			if ct > cs then
				cs = ct
				cr = br
			end
		end
	end
	if cr ~= nil then
		hEffectTarget = cr
		bw = "缴械敌人:" .. f.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if b:GetActiveMode() == BOT_MODE_ROSHAN then
		local be = b:GetAttackTarget()
		if f.IsRoshan(be) and not f.IsDisabled(be) and not be:IsDisarmed() then
			hEffectTarget = be
			bw = "缴械肉山"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_helm_of_the_dominator"] = function(bm)
	local bv = 1000 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	for aX, aR in pairs(GetUnitList(UNIT_LIST_ALLIED_CREEPS)) do
		if f.IsValid(aR) and aR:HasModifier("modifier_dominated") and aR:IsAncientCreep() then
			return BOT_ACTION_DESIRE_NONE, hEffectTarget, "sCastType", bw
		end
	end
	local cu = 0
	local cv = nil
	local co = b:GetNearbyCreeps(bv, true)
	if #co >= 2 then
		for aX, b2 in pairs(co) do
			if f.IsValid(b2) then
				local cw = b2:GetHealth()
				if
					cw > cu
					and b2:GetHealth() / b2:GetMaxHealth() > 0.75
					and (not b2:IsAncientCreep() or bm:GetName() == "item_helm_of_the_overlord")
					and not f.IsKeyWordUnit("siege", b2)
				then
					cv = b2
					cu = cw
				end
			end
		end
	end
	if cv ~= nil then
		hEffectTarget = cv
		bw = "支配:" .. hEffectTarget:GetUnitName()
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_helm_of_the_overlord"] = function(bm)
	return a.ConsiderItemDesire["item_helm_of_the_dominator"](bm)
end
a.ConsiderItemDesire["item_hood_of_defiance"] = function(bm)
	if b:HasModifier("modifier_item_pipe_barrier") or f.GetHP(b) > 0.88 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 1000
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if #bx > 0 then
		hEffectTarget = b
		bw = "套盾"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_holy_locket"] = function(bm)
	return a.ConsiderItemDesire["item_magic_wand"](bm)
end
a.ConsiderItemDesire["item_hurricane_pike"] = function(bm)
	local bv = 800 + b8
	local cx = 450 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, cx, true, BOT_MODE_NONE)
	if bf == BOT_MODE_RETREAT and b:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH then
		for aX, br in pairs(bc) do
			if f.IsInRange(b, br, cx) and f.CanCastOnNonMagicImmune(br) then
				hEffectTarget = br
				bw = "撤退了推敌人"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
		if b:IsFacingLocation(GetAncient(d):GetLocation(), 20) and b:DistanceFromFountain() > 600 and #bc >= 1 then
			hEffectTarget = b
			bw = "撤退了推自己"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.CanCastOnNonMagicImmune(be)
			and GetUnitToUnitDistance(be, b) > b:GetAttackRange() + 100
			and GetUnitToUnitDistance(be, b) < b:GetAttackRange() + 700
			and GetUnitToUnitDistance(be, b) < GetUnitToLocationDistance(b, f.GetCorrectLoc(be, 1.0)) - 100
			and b:IsFacingLocation(be:GetLocation(), 20)
			and not be:IsFacingLocation(b:GetLocation(), 120)
			and f.GetEnemyCount(b, 1600) <= 2
		then
			hEffectTarget = b
			bw = "进攻" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if f.HasItem(b, "item_hurricane_pike") then
		for aX, br in pairs(bc) do
			if
				br ~= nil
				and f.CanCastOnNonMagicImmune(br)
				and GetUnitToUnitDistance(br, b) <= cx
				and f.CanCastOnNonMagicImmune(br)
			then
				b:SetTarget(br)
				hEffectTarget = br
				bw = "推开" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	local bU = f.GetNearbyHeroes(b, bv, false, BOT_MODE_NONE)
	for aX, bA in pairs(bU) do
		if
			bA ~= nil
			and bA:IsAlive()
			and bA:GetUnitName() == "npc_dota_hero_crystal_maiden"
			and f.CanCastOnNonMagicImmune(bA)
			and a.IsWithoutSpellShield(bA)
			and (bA:IsInvisible() or bA:GetHealth() / bA:GetMaxHealth() > 0.8)
			and (bA:IsChanneling() and not bA:HasModifier("modifier_teleporting"))
		then
			local cj = f.GetNearbyHeroes(bA, 1200, true, BOT_MODE_NONE)
			for aX, br in pairs(cj) do
				if
					br ~= nil
					and br:IsAlive()
					and f.CanCastOnNonMagicImmune(br)
					and GetUnitToUnitDistance(br, bA) > 835
					and bA:IsFacingLocation(br:GetLocation(), 30)
				then
					hEffectTarget = bA
					bw = "推CM"
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_invis_sword"] = function(bm)
	if
		b:IsInvisible()
		or #bd > 0
		or b:HasModifier("modifier_item_dustofappearance")
		or b:HasModifier("modifier_slardar_amplify_damage")
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsRetreating(b) and b:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE and #bc > 0 then
		hEffectTarget = b
		bw = "撤退了"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if f.GetHP(b) < 0.166 and (#bc > 0 or b:WasRecentlyDamagedByAnyHero(5.0)) then
		hEffectTarget = b
		bw = "残血了"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.CanCastOnMagicImmune(be)
			and not f.IsInRange(b, be, be:GetCurrentVisionRange())
			and f.IsInRange(b, be, 2600)
		then
			local cy = b:GetNearbyLaneCreeps(800, true)
			if #cy == 0 and #bc == 0 then
				hEffectTarget = be
				bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_lotus_orb"] = function(bm)
	local bv = 1000 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local cz = f.GetNearbyHeroes(b, bv, false, BOT_MODE_NONE)
	for aX, bA in pairs(cz) do
		if
			f.IsValid(bA)
			and not bA:IsIllusion()
			and not bA:IsMagicImmune()
			and not bA:IsInvulnerable()
			and not bA:HasModifier("modifier_item_lotus_orb_active")
			and not bA:HasModifier("modifier_antimage_spell_shield")
		then
			if f.IsUnitTargetProjectileIncoming(bA, 800) then
				hEffectTarget = bA
				bw = "反弹弹道"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if
				bA:IsRooted()
				or bA:IsSilenced() and not bA:HasModifier("modifier_item_mask_of_madness_berserk")
				or bA:IsDisarmed() and not bA:HasModifier("modifier_oracle_fates_edict")
			then
				hEffectTarget = bA
				bw = "驱散队友:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if f.IsWillBeCastUnitTargetSpell(bA, 1200) then
				hEffectTarget = bA
				bw = "给队友反弹技能:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_magic_stick"] = function(bm)
	if bm:GetCurrentCharges() <= 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bq = "none"
	local bx = f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
	local ax = #bx
	local cA = f.GetHP(b)
	local cB = f.GetMP(b)
	local cC = bm:GetCurrentCharges()
	if cA < 0.25 and cC >= 1 then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Stick: emergency"
	end
	if f.IsRetreating(b) and cA < 0.6 and cC >= 2 then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Stick: retreat"
	end
	if ax >= 1 and cC >= 1 and (cA < 0.6 or cB < 0.35) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Stick: fight"
	end
	if cC >= 5 and ax == 0 and (cA < 0.7 or cB < 0.5) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Stick: proactive heal"
	end
	if cC >= 10 and (cA < 0.85 or cB < 0.75) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Stick: max charges"
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_magic_wand"] = function(bm)
	if bm:GetCurrentCharges() <= 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bq = "none"
	if bm:GetName() == "item_holy_locket" then
		bq = "unit"
	end
	local bx = f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
	local ax = #bx
	local cA = f.GetHP(b)
	local cB = f.GetMP(b)
	local cC = bm:GetCurrentCharges()
	local cD = f.IsRetreating(b)
	if cA < 0.25 and cC >= 1 then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Wand: emergency"
	end
	if cD and cA < 0.6 and cC >= 2 then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Wand: retreat"
	end
	if ax >= 1 and cC >= 1 and (cA < 0.6 or cB < 0.3) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Wand: fight"
	end
	if cC >= 5 and ax == 0 and (cA < 0.75 or cB < 0.5) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Wand: proactive heal"
	end
	if cC >= 10 and (cA < 0.8 or cB < 0.6) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Wand: high charges"
	end
	if cC >= 20 and (cA < 0.9 or cB < 0.75) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "Wand: max charges"
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_manta"] = function(bm)
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local cE = f.GetNearbyHeroes(b, 1000, false, BOT_MODE_ATTACK)
	local bX = f.GetNearbyHeroes(b, 1000, true, BOT_MODE_NONE)
	local bY = b:GetNearbyTowers(800, true)
	local cF = b:GetNearbyBarracks(600, true)
	local cG = b:GetNearbyLaneCreeps(1000, false)
	local cH = b:GetNearbyLaneCreeps(800, true)
	if f.IsPushing(b) then
		if (#bY >= 1 or #cF >= 1) and #cG >= 1 then
			hEffectTarget = b
			bw = "推进"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if
		f.IsGoingOnSomeone(b)
		and f.IsValidHero(be)
		and f.CanCastOnMagicImmune(be)
		and f.IsInRange(b, be, b:GetAttackRange() + 80)
	then
		hEffectTarget = be
		bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if
		b:IsRooted()
		or b:IsSilenced() and not b:HasModifier("modifier_item_mask_of_madness_berserk")
		or b:HasModifier("modifier_item_solar_crest_armor_reduction")
		or b:HasModifier("modifier_item_medallion_of_courage_armor_reduction")
		or b:HasModifier("modifier_item_spirit_vessel_damage")
		or b:HasModifier("modifier_dragonknight_breathefire_reduction")
		or b:HasModifier("modifier_slardar_amplify_damage")
		or b:HasModifier("modifier_item_dustofappearance")
	then
		hEffectTarget = b
		bw = "解Buff"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if
		not b:IsMagicImmune()
		and not b:HasModifier("modifier_antimage_spell_shield")
		and not b:HasModifier("modifier_item_sphere_target")
		and not b:HasModifier("modifier_item_lotus_orb_active")
		and f.IsNotAttackProjectileIncoming(b, 70)
	then
		hEffectTarget = b
		bw = "躲弹道"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if f.IsRetreating(b) and bX[1] ~= nil and b:DistanceFromFountain() > 600 then
		hEffectTarget = b
		bw = "撤退了"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if #cH >= 8 then
		hEffectTarget = b
		bw = "刷小兵"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if
		b:WasRecentlyDamagedByAnyHero(5.0)
		and b:GetHealth() / b:GetMaxHealth() < 0.18
		and b:DistanceFromFountain() > 800
	then
		hEffectTarget = b
		bw = "残血了"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_mjollnir"] = function(bm)
	local bv = 800 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local cI = f.GetNearbyHeroes(b, bv + 100, false, BOT_MODE_NONE)
	if f.IsInTeamFight(b, 900) then
		local cJ = nil
		local cK = 1
		for aX, bA in pairs(cI) do
			if f.IsValid(bA) and not bA:IsIllusion() and not bA:HasModifier("modifier_item_mjollnir_static") then
				local ay = 0
				local nEnemyHeroes = f.GetNearbyHeroes(bA, 1400, true, BOT_MODE_NONE)
				local cL = bA:GetNearbyCreeps(1000, true)
				for aX, aR in pairs(nEnemyHeroes) do
					if aR ~= nil and aR:IsAlive() and aR:GetAttackTarget() == bA then
						ay = ay + 1
					end
				end
				for aX, aR in pairs(cL) do
					if aR ~= nil and aR:IsAlive() and aR:GetAttackTarget() == bA then
						ay = ay + 1
					end
				end
				if ay > cK then
					cK = ay
					cJ = bA
				end
			end
		end
		if cJ ~= nil then
			hEffectTarget = cJ
			bw = "团战中套电锤给队友:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if f.IsValidHero(be) then
		local cM = f.GetAlliesNearLoc(be:GetLocation(), 1400)
		if f.IsValid(cM[1]) then
			local cJ = nil
			local cN = 9999
			for aX, bA in pairs(cM) do
				if
					f.IsValid(bA)
					and GetUnitToUnitDistance(b, bA) < bv + 200
					and GetUnitToUnitDistance(be, bA) < cN
					and not bA:HasModifier("modifier_item_mjollnir_static")
				then
					cJ = bA
					cN = GetUnitToUnitDistance(be, bA)
				end
			end
			if cJ ~= nil then
				hEffectTarget = cJ
				bw = "攻击前套电锤给队友:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if bc[1] == nil then
		local cO = b:GetNearbyLaneCreeps(1000, false)
		local cL = b:GetNearbyLaneCreeps(1000, true)
		if #cO >= 1 and #cL == 0 then
			local cp = nil
			local cN = 0
			for aX, b2 in pairs(cO) do
				if f.IsValid(b2) and f.GetHP(b2) > 0.6 and b2:DistanceFromFountain() > cN then
					cp = b2
					cN = b2:DistanceFromFountain()
				end
			end
			if cp ~= nil then
				hEffectTarget = cp
				bw = "给前排小兵套上"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if f.IsValidHero(bc[1]) and bc[1]:GetAttackTarget() == b then
		if not b:HasModifier("modifier_item_mjollnir_static") then
			hEffectTarget = b
			bw = "给自己套上"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_mask_of_madness"] = function(bm)
	if c == "npc_dota_hero_drow_ranger" then
		return BOT_ACTION_DESIRE_NONE
	end
	local cP = b:GetAttackTarget()
	local bv = b:GetAttackRange() + 100
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	if
		(f.IsValid(cP) or f.IsValidBuilding(cP))
		and f.CanBeAttacked(cP)
		and f.IsInRange(b, cP, bv)
		and (
			not f.CanKillTarget(cP, b:GetAttackDamage() * 2, DAMAGE_TYPE_PHYSICAL)
			or f.GetAroundTargetEnemyUnitCount(b, bv) >= 2
		)
	then
		local cQ = f.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
		if cP:IsHero() or #cQ == 0 and not b:WasRecentlyDamagedByAnyHero(2.0) then
			if
				#cQ == 0
				or (
					c ~= "npc_dota_hero_sniper"
					or c ~= "npc_dota_hero_medusa"
					or c ~= "npc_dota_hero_faceless_void" and f.GetUltimateAbility(b):GetCooldown() > 0
				)
			then
				b:SetTarget(cP)
				hEffectTarget = cP
				bw = "启动"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_medallion_of_courage"] = function(bm)
	local bv = 900 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and not be:HasModifier("modifier_item_solar_crest_armor_reduction")
			and not be:HasModifier("modifier_item_medallion_of_courage_armor_reduction")
			and f.CanCastOnNonMagicImmune(be)
			and not be:IsAncientCreep()
			and (
				f.IsInRange(b, be, b:GetAttackRange() + 150)
				or f.IsInRange(b, be, 1000) and f.GetAroundTargetOtherAllyHeroCount(b, be, 600) >= 1
			)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if #bc == 0 then
		if
			f.IsValid(be)
			and not be:HasModifier("modifier_item_solar_crest_armor_reduction")
			and not be:HasModifier("modifier_item_medallion_of_courage_armor_reduction")
			and not be:HasModifier("modifier_fountain_glyph")
			and not f.CanKillTarget(be, b:GetAttackDamage() * 2.38, DAMAGE_TYPE_PHYSICAL)
			and f.IsInRange(b, be, b:GetAttackRange() + 150)
		then
			hEffectTarget = be
			bw = "刷小兵:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	local bU = f.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
	for aX, bA in pairs(bU) do
		if
			bA ~= b
			and f.IsValidHero(bA)
			and not bA:IsIllusion()
			and f.CanCastOnNonMagicImmune(bA)
			and not bA:HasModifier("modifier_item_solar_crest_armor_addition")
			and not bA:HasModifier("modifier_item_medallion_of_courage_armor_addition")
			and not bA:HasModifier("modifier_arc_warden_tempest_double")
			and (
				f.IsDisabled(bA)
				or f.GetHP(bA) < 0.35 and #bc > 0 and bA:WasRecentlyDamagedByAnyHero(2.0)
				or f.IsValidHero(bA:GetAttackTarget())
					and GetUnitToUnitDistance(bA, bA:GetAttackTarget()) <= bA:GetAttackRange()
					and #bc == 0
			)
		then
			hEffectTarget = bA
			bw = "救队友:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_moon_shard"] = function(bm)
	if b:GetNetWorth() < 18000 or g.CountBackpackEmptySpace(b) >= 3 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 2000
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	if not b:HasModifier("modifier_item_moon_shard_consumed") then
		if b.moonSharedTime == nil then
			b.moonSharedTime = DotaTime()
		elseif b.moonSharedTime < DotaTime() - 2.0 then
			b.moonSharedTime = nil
			hEffectTarget = b
			bw = "自己吃"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	local cR = nil
	local cS = 0
	for D = 1, #GetTeamPlayers(GetTeam()) do
		local cT = GetTeamMember(D)
		if
			cT ~= nil
			and cT:IsAlive()
			and cT:GetAttackDamage() > cS
			and not cT:HasModifier("modifier_item_moon_shard_consumed")
		then
			cR = cT
			cS = cT:GetAttackDamage()
		end
	end
	if cR ~= nil then
		if b.moonSharedTime == nil then
			b.moonSharedTime = DotaTime()
		elseif b.moonSharedTime < DotaTime() - 3.0 then
			b.moonSharedTime = nil
			hEffectTarget = cR
			bw = "给队友"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_necronomicon"] = function(bm)
	local bv = 750
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if be ~= nil and be:IsAlive() and f.IsInRange(b, be, 1000) then
		hEffectTarget = be
		bw = "进攻"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_necronomicon_2"] = function(bm)
	return a.ConsiderItemDesire["item_necronomicon"](bm)
end
a.ConsiderItemDesire["item_necronomicon_3"] = function(bm)
	return a.ConsiderItemDesire["item_necronomicon"](bm)
end
a.ConsiderItemDesire["item_nullifier"] = function(bm)
	local bv = 800 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.CanCastOnNonMagicImmune(be)
			and f.CanCastOnTargetAdvanced(be)
			and f.IsInRange(be, b, bv)
			and not be:HasModifier("modifier_item_nullifier_mute")
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_orchid"] = function(bm)
	local bv = 900 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local hMenace = f.GetRightclickMenaceLock(b, bv, "silence")
	if hMenace ~= nil and a.IsWithoutSpellShield(hMenace) then
		return BOT_ACTION_DESIRE_HIGH, hMenace, bq, "silence carry"
	end
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	for aX, br in pairs(bx) do
		if f.IsValid(br) and f.CanCastOnNonMagicImmune(br) and a.IsWithoutSpellShield(br) then
			if br:IsChanneling() or br:IsCastingAbility() then
				hEffectTarget = br
				bw = "打断:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if f.IsRetreating(b) then
				if not f.IsDisabled(br) then
					hEffectTarget = br
					bw = "撤退:" .. f.Chat.GetNormName(hEffectTarget)
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
				end
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.IsInRange(b, be, bv)
			and not f.IsDisabled(be)
			and f.CanCastOnNonMagicImmune(be)
			and a.IsWithoutSpellShield(be)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_phase_boots"] = function(bm)
	local bq = "none"
	local bx = f.GetNearbyHeroes(b, 800, true, BOT_MODE_NONE)
	local cU = b:GetCurrentActionType()
	if
		cU == BOT_ACTION_TYPE_MOVE_TO
		or cU == BOT_ACTION_TYPE_MOVE_TO_DIRECTLY
		or cU == BOT_ACTION_TYPE_ATTACK_MOVE
		or f.IsRunning(b)
	then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "phase: moving"
	end
	if f.IsGoingOnSomeone(b) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "phase: chasing"
	end
	if f.IsRetreating(b) then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "phase: retreat"
	end
	if #bx > 0 then
		return BOT_ACTION_DESIRE_HIGH, b, bq, "phase: near enemy"
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_pipe"] = function(bm)
	local bv = 1000
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local by = f.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
	for aX, bA in pairs(by) do
		if f.IsValid(bA) and not bA:IsIllusion() and bA:GetHealth() / bA:GetMaxHealth() < 0.4 and #bc > 0 then
			hEffectTarget = bA
			bw = "保护队友:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	local cV = f.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
	local bX = f.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
	local cW = b:GetNearbyTowers(1200, true)
	if #cV >= 2 and #bX >= 2 or #bX >= 2 and #cV + #cW >= 2 then
		hEffectTarget = b
		bw = "保护团队"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_power_treads"] = function(bm)
	if n then
		return 0
	end
	local cX = bm:GetPowerTreadsStat()
	if cX == ATTRIBUTE_INTELLECT then
		cX = ATTRIBUTE_AGILITY
	elseif cX == ATTRIBUTE_AGILITY then
		cX = ATTRIBUTE_INTELLECT
	end
	if
		(
			b:HasModifier("modifier_flask_healing")
			or b:HasModifier("modifier_clarity_potion")
			or b:HasModifier("modifier_item_urn_heal")
			or b:HasModifier("modifier_item_spirit_vessel_heal")
			or b:HasModifier("modifier_bottle_regeneration")
		)
		and not f.IsGoingOnSomeone(b)
		and not f.IsRetreating(b)
		and not b:WasRecentlyDamagedByAnyHero(5.0)
	then
		if cX ~= ATTRIBUTE_AGILITY then
			bb = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	elseif
		f.IsRetreating(b) and not f.IsRealInvisible(b) and b:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
		or f.IsNotAttackProjectileIncoming(b, 1200)
		or bf == BOT_MODE_EVASIVE_MANEUVERS
		or b:HasModifier("modifier_sniper_assassinate")
		or f.GetHP(b) < 0.2
		or cX == ATTRIBUTE_STRENGTH and f.GetHP(b) < 0.3
	then
		if cX ~= ATTRIBUTE_STRENGTH then
			bb = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	elseif DotaTime() - (b._ptSpellSwitchAt or -999) < 3 then
		-- Switched to Intelligence for a spell: leave it for 3s instead of switching straight back.
		return BOT_ACTION_DESIRE_NONE
	elseif f.IsGoingOnSomeone(b) then
		if f.ShouldSwitchPTStat(b, bm) and bb < DotaTime() - 0.2 then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	elseif f.ShouldSwitchPTStat(b, bm) and bb < DotaTime() - 0.2 then
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	return BOT_ACTION_DESIRE_NONE
end
local cY = 0
a.ConsiderItemDesire["item_quelling_blade"] = function(bm)
	local bv = 450 + b8
	local bq = "tree"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if b:HasModifier("modifier_furion_sprout_damage") then
		local cZ = b:GetNearbyTrees(280)
		if
			cZ ~= nil
			and #cZ >= 8
			and IsLocationVisible(GetTreeLocation(cZ[1]))
			and IsLocationPassable(GetTreeLocation(cZ[1]))
		then
			hEffectTarget = cZ[1]
			bw = "吃先知的树"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if DotaTime() < 0 and not ba then
		for D, Y in pairs(GetTeamPlayers(GetOpposingTeam())) do
			if GetSelectedHeroName(Y) == "npc_dota_hero_monkey_king" then
				ba = true
			end
		end
	end
	if ba then
		local c_ = nil
		for aX, aY in pairs(bc) do
			if aY:IsAlive() and aY:GetUnitName() == "npc_dota_hero_monkey_king" then
				c_ = aY
				break
			end
		end
		if c_ ~= nil and f.IsInRange(b, c_, bv) then
			local d0 = b:GetNearbyTrees(bv)
			for aX, d1 in pairs(d0) do
				local d2 = GetTreeLocation(d1)
				if GetUnitToLocationDistance(c_, d2) < 30 then
					bw = "砍大圣的树"
					return BOT_ACTION_DESIRE_HIGH, d1, bq, bw
				end
			end
		end
	end
	if DotaTime() > cY + 0.8 and (f.IsGoingOnSomeone(b) or f.IsFarming(b) or f.IsRetreating(b)) then
		cY = DotaTime()
		local d3 = 350
		local d0 = b:GetNearbyTrees(d3)
		local d4 = #d0
		if d4 >= 1 then
			for d5 = 1, d4 do
				local d1 = d0[d5]
				if b:IsFacingLocation(GetTreeLocation(d1), 7) then
					bw = "开视野"
					return BOT_ACTION_DESIRE_HIGH, d1, bq, bw
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_refresher"] = function(bm)
	local bv = 1000
	local bq = "none"
	local hEffectTarget = nil
	local bw = "刷新技能"
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if h ~= nil and h.CanUseRefresherShard ~= nil and h.CanUseRefresherShard() then
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if #bx > 0 and (f.IsGoingOnSomeone(b) or f.IsInTeamFight(b)) and f.CanUseRefresherShard(b) then
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_refresher_shard"] = function(bm)
	return a.ConsiderItemDesire["item_refresher"](bm)
end
a.ConsiderItemDesire["item_ultimate_scepter_roshan"] = function(bm)
	local bv = 300
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if bm:IsFullyCastable() then
		hEffectTarget = b
		bw = "吃A杖"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_aghanims_shard_roshan"] = function(bm)
	local bv = 300
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if bm:IsFullyCastable() then
		hEffectTarget = b
		bw = "吃魔晶"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_rod_of_atos"] = function(bm)
	local bv = 1100 + b8
	local bq = "unit"
	if bm:GetName() == "item_gungir" then
		bq = "ground"
	end
	local hEffectTarget = nil
	local bw = nil
	local d6 = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	for aX, br in pairs(d6) do
		if
			f.IsValid(br)
			and br:IsChanneling()
			and br:HasModifier("modifier_teleporting")
			and f.CanCastOnNonMagicImmune(br)
			and f.CanCastOnTargetAdvanced(br)
		then
			hEffectTarget = br
			bw = "打断:" .. f.Chat.GetNormName(hEffectTarget)
			if bm:GetName() == "item_gungir" then
				hEffectTarget = hEffectTarget:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if
		bf == BOT_MODE_RETREAT
		and b:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
		and f.IsValid(d6[1])
		and f.CanCastOnNonMagicImmune(d6[1])
		and f.CanCastOnTargetAdvanced(d6[1])
		and not f.IsDisabled(d6[1])
	then
		hEffectTarget = d6[1]
		bw = "撤退了"
		if bm:GetName() == "item_gungir" then
			hEffectTarget = hEffectTarget:GetLocation()
		end
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and not f.IsDisabled(be)
			and f.CanCastOnNonMagicImmune(be)
			and f.CanCastOnTargetAdvanced(be)
			and GetUnitToUnitDistance(be, b) <= bv
			and f.IsMoving(be)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			if bm:GetName() == "item_gungir" then
				hEffectTarget = hEffectTarget:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_satanic"] = function(bm)
	local bv = b:GetAttackRange() + 250
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if
		b:OriginalGetHealth() / b:OriginalGetMaxHealth() < 0.62
		and #bx > 0
		and (f.IsValidHero(be) and f.IsInRange(b, be, bv) or f.IsValidHero(bx[1]) and f.IsInRange(b, bx[1], bv))
	then
		hEffectTarget = be
		bw = "进攻"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Shadow Amulet (game files: allied hero target, range 600, cooldown 18s, fade 1.25s).
-- Self: while running away from an enemy hero, or when a stun projectile is coming (invisible
-- while stunned, nothing can target it). Ally in range: stunned, about to be stunned, or running
-- away hurt. Never on a rooted hero or one already revealed (Dust, Amplify Damage), never near an
-- enemy tower. During a teleport it is cast from the top of the item think (AmuletDuringTeleport),
-- since item use is off while channelling.
local function AmuletHidden(u)
	return u:IsInvisible()
		or u:HasModifier("modifier_invisible")
		or u:HasModifier("modifier_item_glimmer_cape")
		or u:HasModifier("modifier_item_shadow_amulet_fade")
end
local function AmuletRevealed(u)
	return u:IsRooted() or u:HasModifier("modifier_slardar_amplify_damage") or u:HasModifier("modifier_item_dustofappearance")
end
local function AmuletLog(target, why)
	if DotaTime() < (b._amuletLogAt or -999) then
		return
	end
	b._amuletLogAt = DotaTime() + 2
	pcall(print, string.format(
		"[OHA-ITEM] t=%.0f %s shadow-amulet target=%s why=%s",
		DotaTime(),
		(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
		(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
		why
	))
end
a.ConsiderItemDesire["item_shadow_amulet"] = function(bm)
	local bq = "unit"
	local range = 600 + b8
	if not AmuletHidden(b) and not AmuletRevealed(b) and #(b:GetNearbyTowers(888, true) or {}) == 0 then
		local foes = f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE) or {}
		if f.IsStunProjectileIncoming(b, 1000) then
			AmuletLog(b, "stun-incoming")
			return BOT_ACTION_DESIRE_HIGH, b, bq, "stun-incoming"
		end
		if #foes > 0 and (bf == BOT_MODE_RETREAT or f.IsRetreating(b)) and not f.IsGoingOnSomeone(b) then
			AmuletLog(b, "running-away")
			return BOT_ACTION_DESIRE_HIGH, b, bq, "running-away"
		end
	end
	for _, ally in pairs(f.GetNearbyHeroes(b, range, false, BOT_MODE_NONE) or {}) do
		if
			f.IsValid(ally)
			and ally ~= b
			and not ally:IsIllusion()
			and not ally:IsMagicImmune()
			and not AmuletHidden(ally)
			and not AmuletRevealed(ally)
			and #(ally:GetNearbyTowers(888, true) or {}) == 0
		then
			local why = nil
			if ally:IsStunned() then
				why = "ally-stunned"
			elseif f.IsStunProjectileIncoming(ally, 1000) then
				why = "ally-stun-incoming"
			elseif
				f.IsRetreating(ally)
				and ally:GetHealth() / math.max(1, ally:GetMaxHealth()) < 0.5
				and #(ally:GetNearbyHeroes(900, true, BOT_MODE_NONE) or {}) > 0
			then
				why = "ally-running-away"
			end
			if why ~= nil then
				AmuletLog(ally, why)
				return BOT_ACTION_DESIRE_HIGH, ally, bq, why
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Teleporting with an enemy hero near: cast it on self during the channel. The amulet does not
-- cancel channels (DOTA_ABILITY_BEHAVIOR_IGNORE_CHANNEL in the game files), so the 1.25s fade
-- runs inside the TP. Casting it before the TP would not work: the TP is an item cast, which
-- breaks the invisibility, and item use is held while the amulet fade is on. True when cast.
function a.AmuletDuringTeleport()
	local slot = b:FindItemSlot("item_shadow_amulet")
	if slot < 0 or slot > 5 then
		return false
	end
	local amulet = b:GetItemInSlot(slot)
	if amulet == nil or not f.CanCastAbility(amulet) or AmuletHidden(b) or AmuletRevealed(b) then
		return false
	end
	if #(f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE) or {}) == 0 then
		return false
	end
	AmuletLog(b, "during-teleport")
	b:Action_UseAbilityOnEntity(amulet, b)
	return true
end
a.ConsiderItemDesire["item_sheepstick"] = function(bm)
	local bv = 800 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local hMenace = f.GetRightclickMenaceLock(b, bv, "hex")
	if hMenace ~= nil and a.IsWithoutSpellShield(hMenace) then
		return BOT_ACTION_DESIRE_HIGH, hMenace, bq, "hex carry"
	end
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	for aX, br in pairs(bx) do
		if f.IsValid(br) and f.CanCastOnNonMagicImmune(br) and a.IsWithoutSpellShield(br) then
			if br:IsChanneling() or br:IsCastingAbility() then
				hEffectTarget = br
				bw = "打断:" .. f.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if f.IsRetreating(b) then
				if not f.IsDisabled(br) and not br:IsDisarmed() then
					hEffectTarget = br
					bw = "撤退:" .. f.Chat.GetNormName(hEffectTarget)
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
				end
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.IsInRange(b, be, bv)
			and not f.IsDisabled(be)
			and f.CanCastOnNonMagicImmune(be)
			and a.IsWithoutSpellShield(be)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_shivas_guard"] = function(bm)
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv + 50, true, BOT_MODE_NONE)
	local co = b:GetNearbyCreeps(bv, true)
	if #co >= 6 or #bx >= 1 then
		hEffectTarget = b
		bw = "启动希瓦"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_silver_edge"] = function(bm)
	local bv = 1600
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if
		f.IsGoingOnSomeone(b)
		and not b:HasModifier("modifier_slardar_amplify_damage")
		and not b:HasModifier("modifier_item_dustofappearance")
		and #bd == 0
	then
		if f.IsValidHero(be) and f.IsInRange(b, be, 2400) and f.CanCastOnMagicImmune(be) then
			local d8 = be:GetNearbyTowers(888, false)
			if #d8 == 0 then
				hEffectTarget = be
				bw = "破坏被动:" .. f.Chat.GetNormName(be)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return a.ConsiderItemDesire["item_invis_sword"](bm)
end
a.ConsiderItemDesire["item_solar_crest"] = function(bm)
	local bv = 1000
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bU = f.GetAlliesNearLoc(b:GetLocation(), 1000)
	for aX, bA in pairs(bU) do
		if
			f.IsValidHero(bA)
			and f.IsInRange(b, bA, bv)
			and not bA:HasModifier("modifier_legion_commander_press_the_attack")
			and not bA:IsMagicImmune()
			and not bA:IsInvulnerable()
			and bA:CanBeSeen()
		then
			if not bA:IsBot() and bA:GetAttackTarget() ~= nil and bA:GetMaxHealth() - bA:GetHealth() >= 120 then
				hEffectTarget = bA
				bw = "Solar Crest"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if f.IsGoingOnSomeone(bA) then
				local d9 = f.GetProperTarget(bA)
				if
					f.IsValidHero(d9)
					and bA:IsFacingLocation(d9:GetLocation(), 20)
					and f.IsInRange(bA, d9, bA:GetAttackRange() + 100)
				then
					hEffectTarget = bA
					bw = "Solar Crest"
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_sphere"] = function(bm)
	local bv = 700 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local cz = f.GetNearbyHeroes(b, bv, false, BOT_MODE_NONE)
	for aX, bA in pairs(cz) do
		if
			f.IsValidHero(bA)
			and bA ~= b
			and not bA:IsMagicImmune()
			and not bA:IsInvulnerable()
			and not bA:IsIllusion()
			and not bA:HasModifier("modifier_item_sphere_target")
			and not bA:HasModifier("modifier_antimage_spell_shield")
			and (
				f.IsUnitTargetProjectileIncoming(bA, 800)
				or f.IsWillBeCastUnitTargetSpell(bA, 1200)
				or b:GetHealth() < 150
			)
		then
			hEffectTarget = bA
			bw = "帮助队友"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if f.IsValidHero(be) and f.IsInRange(b, be, 2400) and not f.IsInRange(b, be, 800) then
		if #cz >= 2 then
			local cJ = nil
			local da = 9999
			for aX, bA in pairs(cz) do
				if
					bA ~= b
					and not bA:IsIllusion()
					and f.IsInRange(bA, be, da)
					and not bA:HasModifier("modifier_item_sphere_target")
					and not bA:HasModifier("modifier_antimage_spell_shield")
				then
					cJ = bA
					da = GetUnitToUnitDistance(be, bA)
					if f.IsHumanPlayer(bA) then
						break
					end
				end
			end
			if cJ ~= nil then
				hEffectTarget = cJ
				bw = "先给前排套上"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_spirit_vessel"] = function(bm)
	return a.ConsiderItemDesire["item_urn_of_shadows"](bm)
end
-- Essence Distiller on the ground (datafeed: placed on the ground it stays dormant 15s, latches onto
-- the first enemy within 450 and gives True Sight and shared vision on it; cast range 1000). Used
-- on an enemy hero seen turning invisible in the last 4s whose last spot is within cast range and
-- still in our vision, when the bot has no Dust ready to do it. [OHA-ITEM] distiller-ground.
local function DistillerGroundSpot()
	local now = DotaTime()
	b._distillerFaders = b._distillerFaders or {}
	for _, eq in pairs(f.GetEnemiesNearLoc(b:GetLocation(), 1600) or {}) do
		if f.IsValidHero(eq) and f.IsUnitWillGoInvisible(eq) and not f.HasInvisCounterBuff(eq) and not f.IsSuspiciousIllusion(eq) then
			b._distillerFaders[eq:GetPlayerID()] = { t = now, loc = eq:GetLocation(), name = eq:GetUnitName() }
		end
	end
	local dustSlot = b:FindItemSlot("item_dust")
	local dust = dustSlot >= 0 and dustSlot <= 5 and b:GetItemInSlot(dustSlot) or nil
	local dustReady = dust ~= nil and f.CanCastAbility(dust)
	for pid, v in pairs(b._distillerFaders) do
		if now - v.t > 4 or not IsHeroAlive(pid) then
			b._distillerFaders[pid] = nil
		elseif not dustReady then
			local info = GetHeroLastSeenInfo(pid)
			local ls = info ~= nil and info[1] or nil
			local loc = ls ~= nil and ls.location or v.loc
			local gone = ls == nil or ls.time_since_seen > 0.1
			if gone and GetUnitToLocationDistance(b, loc) <= 1000 + b8 and IsLocationVisible(loc) then
				b._distillerFaders[pid] = nil
				return loc, v.name
			end
		end
	end
	return nil
end
a.ConsiderItemDesire["item_essence_distiller"] = function(bm)
	if bm:GetCurrentCharges() == 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	do
		local spot, who = DistillerGroundSpot()
		if spot ~= nil then
			pcall(print, string.format(
				"[OHA-ITEM] t=%.0f %s distiller-ground on %s dist=%d",
				DotaTime(),
				(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
				(string.gsub(tostring(who), "npc_dota_hero_", "")),
				math.floor(GetUnitToLocationDistance(b, spot))
			))
			return BOT_ACTION_DESIRE_HIGH, spot, "ground", "distiller-reveal"
		end
	end
	local bv = 950 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and (
				f.CanCastOnNonMagicImmune(be)
					and f.IsInRange(b, be, bv)
					and not be:HasModifier("modifier_item_urn_damage")
					and not be:HasModifier("modifier_item_spirit_vessel_damage")
					and not be:HasModifier("modifier_item_essence_distiller_damage")
					and not be:HasModifier("modifier_arc_warden_tempest_double")
					and (f.GetHP(be) < 0.95 or f.IsInRange(b, be, 700))
				or be:HasModifier("modifier_invoker_cold_snap_freeze")
			)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if b:GetActiveMode() ~= BOT_MODE_ROSHAN then
		local bU = f.GetNearbyHeroes(b, bv + 80, false, BOT_MODE_NONE)
		local c0 = nil
		local c1 = 99999
		for aX, bA in pairs(bU) do
			if
				f.IsValid(bA)
				and not bA:IsIllusion()
				and bA:DistanceFromFountain() > 800
				and f.CanCastOnNonMagicImmune(bA)
				and not bA:WasRecentlyDamagedByAnyHero(3.1)
				and not bA:HasModifier("modifier_item_spirit_vessel_heal")
				and not bA:HasModifier("modifier_item_urn_heal")
				and not bA:HasModifier("modifier_item_essence_distiller_heal")
				and not bA:HasModifier("modifier_fountain_aura")
				and not bA:HasModifier("modifier_arc_warden_tempest_double")
				and bA:OriginalGetMaxHealth() - bA:OriginalGetHealth() > 450
				and #bc == 0
			then
				if bA:OriginalGetHealth() < c1 then
					c0 = bA
					c1 = bA:OriginalGetHealth()
				end
			end
		end
		if c0 ~= nil then
			hEffectTarget = c0
			bw = "治疗:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_tango"] = function(bm)
	if b:DistanceFromFountain() < 3300 or b:HasModifier("modifier_tango_heal") then
		return BOT_ACTION_DESIRE_NONE
	end
	if b._lastTangoUseTime and DotaTime() - b._lastTangoUseTime < 16 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 300 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local db = bm:GetCurrentCharges()
	if
		b:GetLevel() <= 12
		and (#bc == 0 or bf == BOT_MODE_LANING)
		and db >= 1
		and DotaTime() > 10
		and DotaTime() > f.Role["fLastGiveTangoTime"] + 40.0
	then
		local bU = f.GetNearbyHeroes(b, 800, false, BOT_MODE_NONE)
		for aX, bA in pairs(bU) do
			if bA ~= b then
				local dc = bA:FindItemSlot("item_tango")
				if
					dc == -1
					and not bA:IsIllusion()
					and bA:OriginalGetMaxHealth() - bA:OriginalGetHealth() > 200
					and not bA:HasModifier("modifier_tango_heal")
					and not bA:HasModifier("modifier_arc_warden_tempest_double")
					and not f.IsMeepoClone(b)
					and not f.IsMeepoClone(bA)
					and f.Item.GetItemCount(bA, "item_tango_single") == 0
					and f.Item.GetEmptyInventoryAmount(bA) >= 4
				then
					f.Role["fLastGiveTangoTime"] = DotaTime()
					hEffectTarget = bA
					bw = "分享队友吃树"
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
				end
			end
		end
	end
	local dd = f.IsItemAvailable("item_tango_single")
	if dd ~= nil and dd:IsFullyCastable() then
		return 0
	end
	return a.ConsiderItemDesire["item_tango_single"](bm)
end
a.ConsiderItemDesire["item_tango_single"] = function(bm)
	if b:DistanceFromFountain() < 3300 or b:HasModifier("modifier_tango_heal") then
		return 0
	end
	if b._lastTangoUseTime and DotaTime() - b._lastTangoUseTime < 16 then
		return 0
	end
	local bv = 300 + b8
	local bq = "tree"
	local hEffectTarget = nil
	local bw = nil
	local de = bm:GetName() == "item_tango" and 200 or 160
	local bQ = b:OriginalGetMaxHealth() - b:OriginalGetHealth()
	if b:HasModifier("modifier_furion_sprout_damage") then
		local cZ = b:GetNearbyTrees(280)
		if
			cZ ~= nil
			and #cZ >= 8
			and IsLocationVisible(GetTreeLocation(cZ[1]))
			and IsLocationPassable(GetTreeLocation(cZ[1]))
		then
			hEffectTarget = cZ[1]
			bw = "吃先知的树"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if not b:HasModifier("modifier_flask_healing") and not b:HasModifier("modifier_juggernaut_healing_ward_heal") then
		local df = b:GetNearbyTrees(800)
		local dg = df[1]
		local dh = f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		local di = dh[1]
		local dj = b:GetNearbyTowers(1400, true)
		local dk = dj[1]
		local cA = f.GetHP(b)
		if b:GetActiveMode() == BOT_MODE_RETREAT and cA > 0.35 and cA < 0.95 and dg ~= nil then
			local dm = GetTreeLocation(dg)
			if
				IsLocationVisible(dm)
				and IsLocationPassable(dm)
				and (#dj == 0 or GetUnitToLocationDistance(dk, dm) > 920)
			then
				hEffectTarget = dg
				bw = "retreat tango"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
		local dl = #dh == 0 or di ~= nil and not f.IsInRange(b, di, 400)
		if dg ~= nil and bQ >= 350 and dl then
			local dm = GetTreeLocation(dg)
			if
				IsLocationVisible(dm)
				and IsLocationPassable(dm)
				and (#dj == 0 or GetUnitToLocationDistance(dk, dm) > 920)
			then
				hEffectTarget = dg
				bw = "proactive heal"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
		if dg ~= nil then
			local dm = GetTreeLocation(dg)
			if
				bQ > de
				and IsLocationVisible(dm)
				and IsLocationPassable(dm)
				and (#dh == 0 or not f.IsInRange(b, di, 800))
				and (#dh == 0 or GetUnitToLocationDistance(b, dm) * 1.6 < GetUnitToUnitDistance(b, di))
				and (#dj == 0 or GetUnitToLocationDistance(dk, dm) > 920)
			then
				hEffectTarget = dg
				bw = "800码内的树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
		local dn = b:GetNearbyTowers(1100, false)
		if #dn >= 1 and bQ > de + 20 then
			local dp = dn[1]
			if dp ~= nil then
				local dq = 1100 - GetUnitToUnitDistance(b, dp)
				local dr = b:GetNearbyTrees(dq)
				local dg = dr[1]
				if dg ~= nil then
					local dm = GetTreeLocation(dg)
					if IsLocationVisible(dm) and IsLocationPassable(dm) then
						hEffectTarget = dg
						bw = "吃塔下的树"
						return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
					end
				end
			end
		end
		local cZ = b:GetNearbyTrees(280)
		if
			cZ[1] ~= nil
			and IsLocationVisible(GetTreeLocation(cZ[1]))
			and IsLocationPassable(GetTreeLocation(cZ[1]))
		then
			if bQ > de then
				hEffectTarget = cZ[1]
				bw = "近处的树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if bQ > de * 0.38 and b:WasRecentlyDamagedByAnyHero(2.0) then
				hEffectTarget = cZ[1]
				bw = "提前吃树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if
		DotaTime() > 4 * 60 + 30
		and be == nil
		and bm:GetName() == "item_tango_single"
		and b:DistanceFromFountain() > 3000
		and bf ~= BOT_MODE_RUNE
	then
		local ds = f.Item.GetItemCount(b, "item_tango_single")
		local bc = f.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
		if ds >= 2 then
			local df = b:GetNearbyTrees(1200)
			if
				df[1] ~= nil
				and IsLocationVisible(GetTreeLocation(df[1]))
				and IsLocationPassable(GetTreeLocation(df[1]))
				and #bc == 0
			then
				hEffectTarget = df[1]
				bw = "消耗共享吃树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
		if DotaTime() > 7 * 60 + 30 then
			local df = b:GetNearbyTrees(1200)
			if
				df[1] ~= nil
				and IsLocationVisible(GetTreeLocation(df[1]))
				and IsLocationPassable(GetTreeLocation(df[1]))
				and bQ > 60
				and #bc == 0
			then
				hEffectTarget = df[1]
				bw = "用掉共享吃树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_tome_of_knowledge"] = function(bm)
	local bv = 300
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if bm:IsFullyCastable() then
		hEffectTarget = b
		bw = "读书"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.GetLaningTPLocation(b, dt, botLocation)
	if GetGameMode() == GAMEMODE_1V1MID or GetGameMode() == GAMEMODE_MO then
		return nil, false
	end
	local du
	local dv = false
	if IsLanMode and IsLanMode() then
		local U = b:GetAssignedLane()
		if U == LANE_TOP or U == LANE_MID or U == LANE_BOT then
			du = U
		end
	end
	if du == nil then
		local V = f.GetPosition(b)
		if d == TEAM_RADIANT then
			if V == 1 then
				du = LANE_BOT
			elseif V == 2 then
				du = LANE_MID
			elseif V == 3 or V == 4 then
				du = LANE_TOP
			elseif V == 5 then
				du = LANE_BOT
			end
		elseif d == TEAM_DIRE then
			if V == 1 then
				du = LANE_TOP
			elseif V == 2 then
				du = LANE_MID
			elseif V == 3 or V == 4 then
				du = LANE_BOT
			elseif V == 5 then
				du = LANE_TOP
			end
		end
	end
	local dw = GetAmountAlongLane(du, botLocation)
	local dx = GetLaneFrontAmount(d, du, false)
	if dw.distance > dt or dw.amount < dx / 5 then
		dv = true
	end
	local dy = { [LANE_TOP] = "top", [LANE_MID] = "mid", [LANE_BOT] = "bot" }
	if dv then
		pcall(NoLog, string.format(
			"[OHA-TP] diag-laning %s pos=%s assigned=%s chose=%s lan=%s",
			b:GetUnitName(),
			tostring(f.GetPosition(b)),
			tostring(dy[b:GetAssignedLane()] or b:GetAssignedLane()),
			tostring(dy[du] or du),
			tostring(IsLanMode and IsLanMode())
		))
	end
	return GetLaneFrontLocation(d, du, 100), dv
end
function a.GetDefendTPLocation(dz)
	return GetLaneFrontLocation(d, dz, -950)
end
function a.GetPushTPLocation(dz)
	local dx = GetLaneFrontLocation(d, dz, 0)
	local dA = f.GetNearbyLocationToTp(dx)
	if f.GetLocationToLocationDistance(dx, dA) < 2000 then
		return dA
	end
end
function a.CanJuke()
	local dB = b:GetNearbyTowers(350, false)
	if
		dB[1] ~= nil
		and dB[1]:DistanceFromFountain() > b:DistanceFromFountain() + 100
		and f.GetEnemyCount(b, 700) == 0
	then
		return true
	end
	if
		f.GetModifierTime(b, "modifier_dazzle_shallow_grave") > 3.0
		or f.GetModifierTime(b, "modifier_oracle_false_promise_timer") > 3.0
	then
		return true
	end
	local dC = GetTeamPlayers(GetOpposingTeam())
	local dD = GetHeightLevel(b:GetLocation())
	for D = 1, #dC do
		local Z = GetHeroLastSeenInfo(dC[D])
		if Z ~= nil then
			local _ = Z[1]
			if _ ~= nil and _.time_since_seen < 2.0 then
				if GetUnitToLocationDistance(b, _.location) < 1300 and GetHeightLevel(_.location) < dD then
					return false
				end
				if GetUnitToLocationDistance(b, _.location) < 600 then
					local bc = f.GetNearbyHeroes(b, 600, true, BOT_MODE_NONE)
					if #bc == 0 then
						return false
					end
				end
			end
		end
	end
	local dE = 0
	local dF = f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
	for aX, aY in pairs(dF) do
		local dG = aY:GetEstimatedDamageToTarget(true, b, 4.0, DAMAGE_TYPE_ALL)
		dE = dE + dG
		if b:OriginalGetHealth() <= dE then
			return false
		end
	end
	return true
end
function a.GetNumHeroWithinRange(dH)
	local dC = GetTeamPlayers(GetOpposingTeam())
	local dI = 0
	for D = 1, #dC do
		local Z = GetHeroLastSeenInfo(dC[D])
		if Z ~= nil then
			local _ = Z[1]
			if _ ~= nil and _.time_since_seen < 2.0 and GetUnitToLocationDistance(b, _.location) < dH then
				dI = dI + 1
			end
		end
	end
	return dI
end
function a.IsFarmingAlways(b)
	local dJ = b:GetAttackTarget()
	if
		f.IsValid(dJ)
		and dJ:GetTeam() == TEAM_NEUTRAL
		and not f.IsRoshan(dJ)
		and not f.IsKeyWordUnit("warlock", dJ)
		and a.GetNumEnemyNearby(GetAncient(d)) >= 2
	then
		return true
	end
	local cz = f.GetNearbyHeroes(b, 800, false, BOT_MODE_NONE)
	-- Removed: an Intelligence hero hitting an ancient creep with fewer than 2 allies around was
	-- TP'd to its own Ancient, with no danger at all (game 019, 27:52: Lina from an ancient camp
	-- by the Radiant outpost to the Dire top T3). Only enemies at the base send a farmer home now.
	if a.GetNumEnemyNearby(GetAncient(d)) >= 4 and b:DistanceFromFountain() >= 4800 and #cz < 2 then
		return true
	end
	return false
end
function a.IsBaseTowerDestroyed()
	for D = 9, 10, 1 do
		local aU = GetTower(d, D)
		if aU == nil or aU:GetHealth() / aU:GetMaxHealth() < 0.99 then
			return true
		end
	end
	return false
end
if b.useProphetTP == nil then
	b.useProphetTP = false
end
if b.ProphetTPLocation == nil then
	b.ProphetTPLocation = b:GetLocation()
end
a.ConsiderItemDesire["item_tpscroll"] = function(bm)
	if
		bf == BOT_MODE_RUNE
		or b:IsRooted()
		or b:HasModifier("modifier_item_armlet_unholy_strength")
		or b:HasModifier("modifier_kunkka_x_marks_the_spot")
		or b:HasModifier("modifier_teleporting")
		or b:HasModifier("modifier_sniper_assassinate")
		or b:HasModifier("modifier_viper_nethertoxin")
		or b:HasModifier("modifier_oracle_false_promise_timer") and f.GetModifierTime(
			b,
			"modifier_oracle_false_promise_timer"
		) <= 3.2
		or b:HasModifier("modifier_jakiro_macropyre_burn") and f.GetModifierTime(b, "modifier_jakiro_macropyre_burn") >= 1.4
		or b:HasModifier("modifier_arc_warden_tempest_double") and b:GetRemainingLifespan() < 3.3
		or f.IsDoingRoshan(b) and GetUnitToLocationDistance(b, f.GetCurrentRoshanLocation()) <= 2800
		or b._roshDipActive and b:IsAlive() and GetUnitToLocationDistance(b, f.GetCurrentRoshanLocation()) <= 3000
		or f.IsDoingTormentor(b) and GetUnitToLocationDistance(b, f.GetTormentorLocation(GetTeam())) <= 2800
	then
		return BOT_ACTION_DESIRE_NONE
	end
	if b:GetHealth() < 240 then
		local dK = f.GetAttackProjectileDamageByRange(b, 1600) * 2
		if b:GetHealth() < b:GetActualIncomingDamage(dK, DAMAGE_TYPE_PHYSICAL) then
			return BOT_ACTION_DESIRE_NONE
		end
	end
	if b:HasModifier("modifier_spirit_breaker_charge_of_darkness") or b.healInBase then
		return BOT_ACTION_DESIRE_NONE
	end
	local bY = b:GetNearbyTowers(888, true)
	if #bY > 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	local dL = nil
	local bq = "ground"
	local hEffectTarget = nil
	local bw = nil
	local dt = 5500
	local bf = b:GetActiveMode()
	local dM = b:GetActiveModeDesire()
	local botLocation = b:GetLocation()
	local bR = f.GetHP(b)
	local bT = f.GetMP(b)
	local ax = a.GetNumHeroWithinRange(1600)
	local ay = f.GetAllyCount(b, 1600)
	local dN = f.IsItemAvailable("item_flask")
	if b:GetLevel() > 12 and b:DistanceFromFountain() < 600 then
		dt = dt + 600
	end
	-- No TP out of the fountain while creeps are hitting our base: at 37:27 Tusk teleported
	-- out to farm with 3 enemy creeps at our Ancient. Walk out and defend instead.
	local baseCreeps = 0
	local ourAncient = GetAncient(GetTeam())
	if ourAncient ~= nil then
		for _, cr in pairs(GetUnitList(UNIT_LIST_ENEMY_CREEPS) or {}) do
			if cr ~= nil and cr:IsAlive() and GetUnitToUnitDistance(cr, ourAncient) <= 1600 then
				baseCreeps = baseCreeps + 1
			end
		end
	end
	local baseUnderCreeps = baseCreeps >= 2
		or f.Utils.HighGroundCreepWaveNear ~= nil and f.Utils.HighGroundCreepWaveNear(b, 30000) ~= nil
	if
		b:DistanceFromFountain() < 1500
		and bR > 0.75
		and ax == 0
		and not b:HasModifier("modifier_teleporting")
		and DotaTime() > 15
		and not baseUnderCreeps
		-- An item waits to be sold (item_purchase_generic SellMarkedItems): reach the fountain first.
		and not (b._sellPending and b:DistanceFromFountain() > 500)
	then
		local dO = a.GetLaneByPosition(b)
		if not f.IsInLaningPhase() and DotaTime() > 10 * 60 then
			if bf == BOT_MODE_DEFEND_TOWER_TOP then
				dO = LANE_TOP
			elseif bf == BOT_MODE_DEFEND_TOWER_MID then
				dO = LANE_MID
			elseif bf == BOT_MODE_DEFEND_TOWER_BOT then
				dO = LANE_BOT
			elseif bf == BOT_MODE_PUSH_TOWER_TOP then
				dO = LANE_TOP
			elseif bf == BOT_MODE_PUSH_TOWER_MID then
				dO = LANE_MID
			elseif bf == BOT_MODE_PUSH_TOWER_BOT then
				dO = LANE_BOT
			elseif b.laneToDefend ~= nil then
				dO = b.laneToDefend
			else
				local dP = 0
				for aX, dQ in pairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
					local dx = GetLaneFrontLocation(GetOpposingTeam(), dQ, 0)
					local dR = f.GetLastSeenEnemiesNearLoc(dx, 800)
					if #dR > dP then
						dP = #dR
						dO = dQ
					end
				end
			end
		end
		local dS = GetLaneFrontLocation(GetTeam(), dO, -500)
		local dT = { [LANE_TOP] = "top", [LANE_MID] = "mid", [LANE_BOT] = "bot" }
		-- Printed every think while at the fountain (6,541 lines in one game); once per 10s now.
		if DotaTime() >= (b._diagFountainLogAt or -999) then
			b._diagFountainLogAt = DotaTime() + 10
			pcall(NoLog, string.format(
				"[OHA-TP] diag-fountain %s pos=%s assigned=%s chose=%s mode=%s lan=%s",
				c,
				tostring(f.GetPosition(b)),
				tostring(dT[b:GetAssignedLane()] or b:GetAssignedLane()),
				tostring(dT[dO] or dO),
				tostring(bf),
				tostring(IsLanMode and IsLanMode())
			))
		end
		if dS ~= nil and GetUnitToLocationDistance(b, dS) > 3500 then
			local dU = { [LANE_TOP] = "top", [LANE_MID] = "mid", [LANE_BOT] = "bot" }
			local dV = f.GetLastSeenEnemiesNearLoc(dS, 1600)
			local dW = f.GetAlliesNearLoc(dS, 1600)
			if #dV <= 1 or #dW >= #dV then
				return BOT_ACTION_DESIRE_HIGH, dS, bq, "fountain TP out"
			end
			local dX = GetLaneFrontLocation(GetTeam(), dO, -1500)
			if GetUnitToLocationDistance(b, dX) > 3500 then
				return BOT_ACTION_DESIRE_HIGH, dX, bq, "fountain TP safe"
			end
		end
	end
	if bf == BOT_MODE_LANING and not a.JustTeleported() then
		hEffectTarget, shouldTp = a.GetLaningTPLocation(b, dt, botLocation)
		bw = "出去发育"
		if shouldTp then
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if
		a.IsInvFull(b)
		and a.GetNumStashItem(b) >= 1
		and (b:GetStashValue() >= 1200 and a.IsThereRecipeInStash(b) or b:GetStashValue() >= 2000 and b:GetGold() > 1100)
		and not f.IsPushing(b)
		and b:GetActiveMode() ~= BOT_MODE_ATTACK
		and not f.IsInTeamFight(b, 1200)
		and not f.Utils.IsTeamPushingSecondTierOrHighGround(b)
		and ax == 0
	then
		hEffectTarget = f.GetTeamFountain()
		bw = "撤退:1"
		if c == "npc_dota_hero_furion" then
			local dY = b:GetAbilityByName("furion_teleportation")
			if dY:IsTrained() and dY:IsFullyCastable() then
				b.useProphetTP = true
				b.ProphetTPLocation = hEffectTarget
				return BOT_ACTION_DESIRE_NONE
			end
		end
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	if f.IsDoingRoshan(b) and ax == 0 and not f.IsRoshanCloseToChangingSides() then
		local dZ = f.GetCurrentRoshanLocation()
		local d_ = f.GetNearbyLocationToTp(dZ)
		local e0 = GetUnitToLocationDistance(b, d_)
		local e1 = GetUnitToLocationDistance(b, dZ)
		if e0 > 8000 and e1 > 8000 and e1 > e0 then
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = d_
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, d_, "ground", "tp_roshan"
		end
	end
	-- Side shop / watcher mode only means Tormentor once our Tormentor mode can run (20:00,
	-- 10:00 in Turbo). Before that it is the engine's own watcher trip: at 0:10 Snapfire and
	-- earlier Phoenix TP'd to the tower nearest the Tormentor and walked back to their lane.
	if
		(b:GetActiveMode() == BOT_MODE_SIDE_SHOP or b:GetActiveMode() == BOT_MODE_WATCHER)
		and DotaTime() >= (f.IsModeTurbo() and 10 or 20) * 60
		and ax == 0
		and (not f.IsInTeamFight(b, 1200) or not f.IsGoingOnSomeone(b) or not f.IsDefending(b))
	then
		local e2 = f.GetTormentorLocation(d)
		if GetUnitToLocationDistance(b, e2) > 8000 then
			hEffectTarget = f.GetNearbyLocationToTp(e2)
			bw = "tormentor"
			if f.GetLocationToLocationDistance(b:GetLocation(), hEffectTarget) > 4400 then
				if c == "npc_dota_hero_furion" then
					local dY = b:GetAbilityByName("furion_teleportation")
					if dY:IsTrained() and dY:IsFullyCastable() then
						b.useProphetTP = true
						b.ProphetTPLocation = hEffectTarget
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if f.IsDefending(b) and dM > BOT_MODE_DESIRE_LOW and ax == 0 then
		local e3, e4 = LANE_MID, "tower_mid"
		if bf == BOT_MODE_DEFEND_TOWER_TOP then
			e3, e4 = LANE_TOP, "tower_top"
		end
		if bf == BOT_MODE_DEFEND_TOWER_BOT then
			e3, e4 = LANE_BOT, "tower_bot"
		end
		local dw = GetAmountAlongLane(e3, botLocation)
		local dx = GetLaneFrontAmount(d, e3, false)
		if dw.distance > dt or dw.amount < dx / 5 then
			dL = a.GetDefendTPLocation(e3)
		end
		if dL ~= nil and GetUnitToLocationDistance(b, dL) > dt - 500 then
			hEffectTarget = dL
			bw = "前往守塔:" .. e4
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_ABSOLUTE, hEffectTarget, bq, bw
		end
	end
	if f.IsPushing(b) and dM >= BOT_MODE_DESIRE_LOW and ax == 0 then
		local e5, e4 = LANE_MID, "tower_mid"
		if bf == BOT_MODE_PUSH_TOWER_TOP then
			e5, e4 = LANE_TOP, "tower_top"
		end
		if bf == BOT_MODE_PUSH_TOWER_BOT then
			e5, e4 = LANE_BOT, "tower_bot"
		end
		local dw = GetAmountAlongLane(e5, botLocation)
		local dx = GetLaneFrontAmount(d, e5, false)
		if dw.amount < dx - 0.05 and (dw.distance > dt or dw.amount < dx / 5) then
			dL = a.GetPushTPLocation(e5)
		end
		if
			dL ~= nil
			and GetUnitToLocationDistance(b, dL) > dt - 600
			and GetAmountAlongLane(e5, dL).amount > dw.amount
		then
			hEffectTarget = dL
			bw = "前往推塔:" .. e4
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if bf == BOT_MODE_DEFEND_ALLY and dM >= BOT_MODE_DESIRE_LOW and f.Role.CanBeSupport(c) and ax == 0 then
		local ap = b:GetTarget()
		if ap ~= nil and ap:IsHero() and GetUnitToUnitDistance(b, ap) > dt then
			local dA = f.GetNearbyLocationToTp(ap:GetLocation())
			if dA ~= nil and GetUnitToLocationDistance(b, dA) > dt - 800 then
				dL = dA
			end
		end
		if dL ~= nil then
			hEffectTarget = dL
			bw = "支援队友:" .. f.Chat.GetNormName(ap)
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if
		bf == BOT_MODE_RETREAT
		and dM >= BOT_MODE_DESIRE_LOW
		and b:GetLevel() >= 3
		and not b:HasModifier("modifier_arc_warden_tempest_double")
	then
		local function HasTangoToEat()
			if b:HasModifier("modifier_tango_heal") then
				return true
			end
			for _, name in pairs({ "item_tango", "item_tango_single" }) do
				local slot = b:FindItemSlot(name)
				if slot >= 0 and slot <= 8 then
					local it = b:GetItemInSlot(slot)
					if it ~= nil then
						local charges = it:GetCurrentCharges()
						if charges == nil or charges > 0 then
							return true
						end
					end
				end
			end
			return false
		end
		-- Above half health, a tango refills him. A fountain TP spends the scroll for nothing.
		local tangoInstead = bR > 0.5 and HasTangoToEat()
		if
			bR < 0.19
			and (b:WasRecentlyDamagedByAnyHero(8.0) or bR < 0.12)
			and c ~= "npc_dota_hero_huskar"
			and (c ~= "npc_dota_hero_slark" or b:GetLevel() <= 5)
			and ax == 0
			and dN == nil
			and not b:HasModifier("modifier_tango_heal")
			and not b:HasModifier("modifier_flask_healing")
			and not b:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not b:HasModifier("modifier_item_urn_heal")
			and not b:HasModifier("modifier_item_spirit_vessel_heal")
			and b:DistanceFromFountain() > dt
		then
			dL = f.GetTeamFountain()
			bw = "撤退:1"
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, dL, bq, bw
		end
		local e6 = f.GetNearbyHeroes(b, 1500, false, BOT_MODE_ATTACK)
		-- Retreat TP home: HP under 15% + 24% per enemy hero within 1600 (two enemies: 63%). In
		-- the laning phase that sent Doom home at 3:57 (game 018) and cost the lane; there it
		-- needs HP under 35% (40% with 3+ enemies), walking back or regen covers the rest.
		local tpHpLine = 0.15 + 0.24 * ax
		if f.IsInLaningPhase() then
			tpHpLine = math.min(tpHpLine, ax >= 3 and 0.4 or 0.35)
		end
		if
			bR < tpHpLine
			and #e6 == 0
			and b:WasRecentlyDamagedByAnyHero(6.0)
			and a.CanJuke()
			and ax <= (bR < 0.4 and 2 or 3)
			and ay <= 2
			and dN == nil
			and not tangoInstead
			and not b:HasModifier("modifier_tango_heal")
			and not b:HasModifier("modifier_flask_healing")
			and not b:HasModifier("modifier_item_urn_heal")
			and not b:HasModifier("modifier_item_spirit_vessel_heal")
			and not b:HasModifier("modifier_juggernaut_healing_ward_heal")
			and b:DistanceFromFountain() > dt - 600
		then
			dL = f.GetTeamFountain()
			bw = "撤退:2"
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, dL, bq, bw
		end
		if
			(bR < 0.34 or bR + bT < 0.43)
			and #e6 == 0
			and b:GetLevel() >= 9
			and a.CanJuke()
			and ax <= 1
			and ay <= 2
			and dN == nil
			and b:GetAttackTarget() == nil
			and c ~= "npc_dota_hero_huskar"
			and c ~= "npc_dota_hero_slark"
			and not b:HasModifier("modifier_flask_healing")
			and not b:HasModifier("modifier_clarity_potion")
			and not b:HasModifier("modifier_filler_heal")
			and not b:HasModifier("modifier_item_urn_heal")
			and not b:HasModifier("modifier_item_spirit_vessel_heal")
			and not b:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not b:HasModifier("modifier_bottle_regeneration")
			and not b:HasModifier("modifier_tango_heal")
			and not tangoInstead
			and b:DistanceFromFountain() > dt - 600
		then
			dL = f.GetTeamFountain()
			bw = "撤退:3"
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, dL, bq, bw
		end
	end
	if
		bf == BOT_MODE_FARM
		and b:DistanceFromFountain() < 800
		and not a.IsBaseTowerDestroyed()
		and bR > 0.9
		and bT > 0.8
	then
		local e7, e8 = f.GetMostFarmLaneDesire(b)
		if e8 > 0.1 then
			farmTpLoc = GetLaneFrontLocation(d, e7, 0)
			local dA = f.GetNearbyLocationToTp(farmTpLoc)
			if
				dA ~= nil
				and farmTpLoc ~= nil
				and f.IsLocHaveTower(2000, false, farmTpLoc)
				and GetUnitToLocationDistance(b, dA) > dt
			then
				dL = farmTpLoc
			end
		end
		if dL ~= nil and a.JustTeleported() then
			dL = nil
		end
		if dL ~= nil then
			hEffectTarget = dL
			bw = "出去发育"
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_ABSOLUTE, hEffectTarget, bq, bw
		end
	end
	if
		b:GetLevel() >= 10
		and bf ~= BOT_MODE_ROSHAN
		and not a.IsBaseTowerDestroyed()
		and f.GetAllyCount(b, 1600) <= 2
		and f.Role.ShouldTpToFarm()
		and not f.Role.IsAllyHaveAegis()
		and not f.Role.CanBeSupport(c)
		and not f.IsEnemyHeroAroundLocation(GetAncient(d):GetLocation(), 3300)
		and f.Utils.CountEnemyHeroesOnHighGround(GetTeam()) < 1
	then
		local e6 = f.GetNearbyHeroes(b, 1600, false, BOT_MODE_ATTACK)
		local e9 = f.GetNearbyHeroes(b, 1400, true, BOT_MODE_NONE)
		local ea = b:GetNearbyCreeps(1600, true)
		local e7, e8 = f.GetMostFarmLaneDesire(b)
		local eb = false
		if f.IsItemAvailable("item_travel_boots") or f.IsItemAvailable("item_travel_boots_2") then
			eb = true
		end
		if e8 > (eb and 0.7 or 0.8) and #e9 == 0 and #ea == 0 and #e6 == 0 then
			if eb then
				dL = GetLaneFrontLocation(d, e7, -600)
				local cz = f.GetAlliesNearLoc(dL, 1600)
				if GetUnitToLocationDistance(b, dL) > dt - 1500 and #cz == 0 then
					f.Role["lastFarmTpTime"] = DotaTime()
					bw = "飞鞋带线"
					if c == "npc_dota_hero_furion" then
						local dY = b:GetAbilityByName("furion_teleportation")
						if dY:IsTrained() and dY:IsFullyCastable() then
							b.useProphetTP = true
							b.ProphetTPLocation = dL
							return BOT_ACTION_DESIRE_NONE
						end
					end
					return BOT_ACTION_DESIRE_HIGH, dL, bq, bw
				end
			end
			dL = GetLaneFrontLocation(d, e7, 0)
			local dA = f.GetNearbyLocationToTp(dL)
			local cz = f.GetAlliesNearLoc(dL, 1600)
			if
				dA ~= nil
				and f.IsLocHaveTower(1850, false, dL)
				and GetUnitToLocationDistance(b, dA) > dt - 800
				and #cz == 0
			then
				f.Role["lastFarmTpTime"] = DotaTime()
				bw = "线上打钱"
				if c == "npc_dota_hero_furion" then
					local dY = b:GetAbilityByName("furion_teleportation")
					if dY:IsTrained() and dY:IsFullyCastable() then
						b.useProphetTP = true
						b.ProphetTPLocation = dA
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, dA, bq, bw
			end
		end
	end
	if
		b:GetLevel() > 10
		and bf ~= BOT_MODE_SECRET_SHOP
		and bf ~= BOT_MODE_ROSHAN
		and bf ~= BOT_MODE_ATTACK
		and (be == nil or not be:IsHero())
	then
		local e9 = f.GetNearbyHeroes(b, 1400, true, BOT_MODE_NONE)
		local aw = f.GetTeamFightLocation(b)
		local eb = false
		if f.IsItemAvailable("item_travel_boots") or f.IsItemAvailable("item_travel_boots_2") then
			eb = true
		end
		if c == "npc_dota_hero_spectre" then
			local ec = b:GetAbilityByName("spectre_shadow_step")
			local ed = b:GetAbilityByName("spectre_haunt")
			if ec:IsFullyCastable() or ed:IsTrained() and ed:IsFullyCastable() then
				return BOT_ACTION_DESIRE_NONE
			end
		end
		if #e9 == 0 and aw ~= nil and GetUnitToLocationDistance(b, aw) > dt - 1200 then
			if eb then
				bw = "飞鞋支援团战距离:" .. GetUnitToLocationDistance(b, aw)
				if c == "npc_dota_hero_furion" then
					local dY = b:GetAbilityByName("furion_teleportation")
					if dY:IsTrained() and dY:IsFullyCastable() then
						b.useProphetTP = true
						b.ProphetTPLocation = aw
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, aw, bq, bw
			end
			local dA = f.GetNearbyLocationToTp(aw)
			if
				dA ~= nil
				and f.GetLocationToLocationDistance(dA, aw) < 1800
				and GetUnitToLocationDistance(b, dA) > dt - 1200
			then
				bw = "支援团战:" .. GetUnitToLocationDistance(b, aw)
				if c == "npc_dota_hero_furion" then
					local dY = b:GetAbilityByName("furion_teleportation")
					if dY:IsTrained() and dY:IsFullyCastable() then
						b.useProphetTP = true
						b.ProphetTPLocation = dA
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, dA, bq, bw
			end
		end
		local ee = GetAncient(d)
		if
			b:GetLevel() >= 15
			and #e9 == 0
			and f.Role.ShouldTpToFarm()
			and b:DistanceFromFountain() > 2000
			and GetUnitToUnitDistance(b, ee) > dt - 200
			and f.GetAroundTargetAllyHeroCount(ee, 1400) == 0
		then
			local ef = f.GetNearestLaneFrontLocation(ee:GetLocation(), true, 400)
			if ef ~= nil and GetUnitToLocationDistance(ee, ef) <= 1600 then
				f.Role["lastFarmTpTime"] = DotaTime()
				bw = "守护遗迹"
				if c == "npc_dota_hero_furion" then
					local dY = b:GetAbilityByName("furion_teleportation")
					if dY:IsTrained() and dY:IsFullyCastable() then
						b.useProphetTP = true
						b.ProphetTPLocation = ee:GetLocation()
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, ee:GetLocation(), bq, bw
			end
			local eg = GetTower(d, 9)
			local eh = GetTower(d, 10)
			if eg == nil and eh == nil then
				local b0 = GetUnitList(UNIT_LIST_ENEMY_CREEPS)
				for aX, b2 in pairs(b0) do
					if
						f.IsValid(b2)
						and GetUnitToUnitDistance(ee, b2) <= 800
						and (b2:GetAttackTarget() == ee or b:GetLevel() >= 15)
					then
						f.Role["lastFarmTpTime"] = DotaTime()
						bw = "保护遗迹"
						if c == "npc_dota_hero_furion" then
							local dY = b:GetAbilityByName("furion_teleportation")
							if dY:IsTrained() and dY:IsFullyCastable() then
								b.useProphetTP = true
								b.ProphetTPLocation = ee:GetLocation()
								return BOT_ACTION_DESIRE_NONE
							end
						end
						return BOT_ACTION_DESIRE_HIGH, ee:GetLocation(), bq, bw
					end
				end
			end
		end
	end
	if
		(bR + bT < 0.3 or bR < 0.2)
		and b:GetLevel() >= 6
		and c ~= "npc_dota_hero_huskar"
		and c ~= "npc_dota_hero_slark"
		and not b:HasModifier("modifier_arc_warden_tempest_double")
	then
		if
			a.CanJuke()
			and b:DistanceFromFountain() > dt + 200
			and ax <= 1
			and ay <= 1
			and f.GetProperTarget(b) == nil
			and dN == nil
			and b:GetAttackTarget() == nil
			and not b:HasModifier("modifier_flask_healing")
			and not b:HasModifier("modifier_clarity_potion")
			and not b:HasModifier("modifier_filler_heal")
			and not b:HasModifier("modifier_item_urn_heal")
			and not b:HasModifier("modifier_item_spirit_vessel_heal")
			and not b:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not b:HasModifier("modifier_bottle_regeneration")
			and not b:HasModifier("modifier_tango_heal")
		then
			dL = f.GetTeamFountain()
		end
		if dL ~= nil then
			hEffectTarget = dL
			bw = "回复状态"
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if
		b:HasModifier("modifier_bloodseeker_rupture")
		and ax <= 1
		and f.GetModifierTime(b, "modifier_bloodseeker_rupture") >= 3.1
	then
		local ay = f.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
		if #ay <= 1 and a.CanJuke() then
			dL = f.GetTeamFountain()
		end
		if dL ~= nil then
			hEffectTarget = dL
			bw = "躲血魔大"
			if c == "npc_dota_hero_furion" then
				local dY = b:GetAbilityByName("furion_teleportation")
				if dY:IsTrained() and dY:IsFullyCastable() then
					b.useProphetTP = true
					b.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if a.IsFarmingAlways(b) then
		dL = GetAncient(d):GetLocation()
		bw = "处理特殊情况一"
		if c == "npc_dota_hero_furion" then
			local dY = b:GetAbilityByName("furion_teleportation")
			if dY:IsTrained() and dY:IsFullyCastable() then
				b.useProphetTP = true
				b.ProphetTPLocation = dL
				return BOT_ACTION_DESIRE_NONE
			end
		end
		return BOT_ACTION_DESIRE_HIGH, dL, bq, bw
	end
	if f.IsStuck(b) then
		dL = GetAncient(d):GetLocation()
		bw = "处理特殊情况二"
		if c == "npc_dota_hero_furion" then
			local dY = b:GetAbilityByName("furion_teleportation")
			if dY:IsTrained() and dY:IsFullyCastable() then
				b.useProphetTP = true
				b.ProphetTPLocation = dL
				return BOT_ACTION_DESIRE_NONE
			end
		end
		return BOT_ACTION_DESIRE_HIGH, dL, bq, bw
	end
	if f.Role.ShouldTpToDefend() and b:DistanceFromFountain() > 3800 then
		dL = GetAncient(d):GetLocation()
		bw = "立即TP守家"
		return BOT_ACTION_DESIRE_HIGH, dL, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_urn_of_shadows"] = function(bm)
	if bm:GetCurrentCharges() == 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 950 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and (
				f.CanCastOnNonMagicImmune(be)
					and f.IsInRange(b, be, bv)
					and not be:HasModifier("modifier_item_urn_damage")
					and not be:HasModifier("modifier_item_spirit_vessel_damage")
					and not be:HasModifier("modifier_arc_warden_tempest_double")
					and (f.GetHP(be) < 0.95 or f.IsInRange(b, be, 700))
				or be:HasModifier("modifier_invoker_cold_snap_freeze")
			)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if b:GetActiveMode() ~= BOT_MODE_ROSHAN then
		local bU = f.GetNearbyHeroes(b, bv + 80, false, BOT_MODE_NONE)
		local c0 = nil
		local c1 = 99999
		for aX, bA in pairs(bU) do
			if
				f.IsValid(bA)
				and not bA:IsIllusion()
				and bA:DistanceFromFountain() > 800
				and f.CanCastOnNonMagicImmune(bA)
				and not bA:WasRecentlyDamagedByAnyHero(3.1)
				and not bA:HasModifier("modifier_item_spirit_vessel_heal")
				and not bA:HasModifier("modifier_item_urn_heal")
				and not bA:HasModifier("modifier_fountain_aura")
				and not bA:HasModifier("modifier_arc_warden_tempest_double")
				and bA:OriginalGetMaxHealth() - bA:OriginalGetHealth() > 450
				and #bc == 0
			then
				if bA:OriginalGetHealth() < c1 then
					c0 = bA
					c1 = bA:OriginalGetHealth()
				end
			end
		end
		if c0 ~= nil then
			hEffectTarget = c0
			bw = "治疗:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_veil_of_discord"] = function(bm)
	-- Techies casts it himself when Blast Off lands; keep it while Blast Off is ready.
	if c == "npc_dota_hero_techies" then
		local blast = b:GetAbilityByName("techies_suicide")
		if blast ~= nil and blast:IsTrained() and blast:IsFullyCastable() then
			return BOT_ACTION_DESIRE_NONE
		end
	end
	local bv = 900
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv + 50, true, BOT_MODE_NONE)
	local co = b:GetNearbyCreeps(bv, true)
	if #co >= 6 or #bx >= 1 then
		hEffectTarget = b
		bw = "启动希瓦"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
local ei = 0
a.ConsiderItemDesire["item_ward_sentry"] = function(bm)
	local bv = 500 + b8
	local bq = "ground"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
	local dn = b:GetNearbyTowers(1200, false)
	if f.IsGoingOnSomeone(b) and #bx >= 1 then
		local cr = nil
		for aX, br in pairs(bx) do
			if
				f.IsValidHero(br)
				and f.IsInRange(b, br, 900)
				and f.CanCastOnMagicImmune(br)
				and f.HasInvisibilityOrItem(br)
				and not br:HasModifier("modifier_slardar_amplify_damage")
				and not br:HasModifier("modifier_item_dustofappearance")
				and not f.Site.IsLocationHaveTrueSight(br:GetLocation())
			then
				hEffectTarget = f.GetUnitTowardDistanceLocation(b, br, bv)
				bw = "插真眼针对:" .. f.Chat.GetNormName(br)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
local ej = -1
a.ConsiderItemDesire["item_ironwood_tree"] = function(bm)
	local bv = 600
	local bq = "ground"
	local hEffectTarget = nil
	local bw = nil
	if ej == -1 then
		ej = GetHeroKills(b:GetPlayerID()) + GetHeroAssists(b:GetPlayerID())
	end
	if ej < GetHeroKills(b:GetPlayerID()) + GetHeroAssists(b:GetPlayerID()) then
		ej = -1
		hEffectTarget = f.GetFaceTowardDistanceLocation(b, bv)
		bw = "GG"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_essence_ring"] = function(bm)
	if b:DistanceFromFountain() < 1000 then
		return 0
	end
	local bv = 600
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, 1400, true, BOT_MODE_NONE)
	if b:GetMaxHealth() - b:GetHealth() > 600 and f.IsAllowedToSpam(b, 200) then
		hEffectTarget = b
		bw = "治疗自己"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return a.ConsiderItemDesire["item_faerie_fire"](bm)
end
a.ConsiderItemDesire["item_ash_legion_shield"] = function(bm)
	local ek = bm:GetSpecialValueInt("block_radius")
	local el = GetUnitList(UNIT_LIST_ALLIES)
	local em = 0
	local en = 0
	for aX, aR in pairs(el) do
		if f.IsValid(aR) and f.IsInRange(b, aR, ek) then
			local eo = aR:GetUnitName()
			if aR:IsHero() and (aR:IsIllusion() or string.find(eo, "bear")) then
				en = en + 1
			end
			if string.find(eo, "golem") then
				return BOT_ACTION_DESIRE_HIGH, b, "none", nil
			end
			if
				-- Unit names are singular: npc_dota_broodmother_spiderling, npc_dota_invoker_forged_spirit,
				-- npc_dota_visage_familiar. The plural / "forge_spirit" spellings never matched.
				string.find(eo, "broodmother_spider")
				or string.find(eo, "forged_spirit")
				or string.find(eo, "golem")
				or string.find(eo, "boar")
				or string.find(eo, "furion_treant")
				or string.find(eo, "familiar")
				or aR:IsDominated()
				or aR:HasModifier("modifier_chen_holy_persuasion")
			then
				em = em + 1
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		if b:WasRecentlyDamagedByAnyHero(2.0) and (em >= 2 or en >= 2) then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_flayers_bota"] = function(bm)
	if f.IsGoingOnSomeone(b) then
		if f.IsValidHero(be) and f.CanBeAttacked(be) and not f.IsSuspiciousIllusion(be) and bAttacking then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	if f.IsDoingRoshan(b) then
		if
			f.IsRoshan(be)
			and f.CanBeAttacked(be)
			and f.IsInRange(b, be, botAttackRange + 150)
			and #nEnemyHeroes == 0
			and bAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	if f.IsDoingTormentor(b) then
		if f.IsTormentor(be) and f.IsInRange(b, be, botAttackRange + 150) and #nEnemyHeroes == 0 and bAttacking then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_idol_of_screeauk"] = function(bm)
	if f.IsGoingOnSomeone(b) then
		if b:WasRecentlyDamagedByAnyHero(2.0) and f.IsRunning(b) then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_jidi_pollen_bag"] = function(bm)
	local ek = bm:GetSpecialValueInt("debuff_radius")
	local nInRangeEnemy = f.GetEnemiesNearLoc(botLocation, ek)
	if f.IsInTeamFight(b, 1200) then
		if #nInRangeEnemy >= 2 then
			local ep = 0
			for aX, eq in pairs(nInRangeEnemy) do
				if
					f.IsValidHero(eq)
					and f.CanBeAttacked(eq)
					and f.CanCastOnNonMagicImmune(eq)
					and not eq:HasModifier("modifier_doom_bringer_doom_aura_enemy")
					and not eq:HasModifier("modifier_necrolyte_reapers_scythe")
					and not eq:HasModifier("modifier_ice_blast")
					and not eq:HasModifier("modifier_item_spirit_vessel_damage")
				then
					ep = ep + 1
				end
			end
			if ep >= 2 then
				return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.CanBeAttacked(be)
			and f.IsInRange(b, be, ek)
			and f.CanCastOnNonMagicImmune(be)
			and not be:HasModifier("modifier_doom_bringer_doom_aura_enemy")
			and not be:HasModifier("modifier_necrolyte_reapers_scythe")
			and not be:HasModifier("modifier_ice_blast")
			and not be:HasModifier("modifier_item_spirit_vessel_damage")
		then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_metamorphic_mandible"] = function(bm)
	local er = bm:GetSpecialValueInt("duration")
	if f.IsGoingOnSomeone(b) then
		if b:WasRecentlyDamagedByAnyHero(2.0) then
			local dG = 0
			-- nEnemyHeroes was never defined here ("bad argument to pairs", game 020, Pudge).
			for aX, eq in pairs(f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE) or {}) do
				if
					f.IsValidHero(eq)
					and not f.IsSuspiciousIllusion(eq)
					and not eq:HasModifier("modifier_necrolyte_reapers_scythe")
					and not eq:IsChanneling()
				then
					if
						eq:GetAttackTarget() == b
						or f.IsChasingTarget(eq, b)
						or eq:IsFacingLocation(b:GetLocation(), 15)
						or b:WasRecentlyDamagedByHero(eq, 3.0)
					then
						dG = dG + eq:GetAttackDamage() * eq:GetAttackSpeed() * er
					end
				end
			end
			if b:GetActualIncomingDamage(dG * 1.5, DAMAGE_TYPE_PHYSICAL) < b:GetHealth() then
				return BOT_ACTION_DESIRE_HIGH, b, "none", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_riftshadow_prism"] = function(bm)
	local es = bm:GetSpecialValueInt("health_cost")
	if f.IsGoingOnSomeone(b) then
		if b:WasRecentlyDamagedByAnyHero(2.0) and f.GetHealthAfter(b:GetHealth() * es) > 0.2 then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_spider_legs"] = function(bm)
	return a.ConsiderItemDesire["item_phase_boots"](bm)
end
a.ConsiderItemDesire["item_flicker"] = function(bm)
	if b:DistanceFromFountain() < 600 or b:IsRooted() then
		return BOT_ACTION_DESIRE_NONE
	end
	local bv = 600
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, 800, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if f.IsValidHero(be) and (b:IsSilenced() or b:IsRooted()) then
			hEffectTarget = b
			bw = "驱散沉默或缠绕"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if f.IsRetreating(b) and b:WasRecentlyDamagedByAnyHero(3.0) and #bx >= 1 then
		hEffectTarget = b
		bw = "撤退"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_illusionsts_cape"] = function(bm)
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	if f.IsValid(be) and f.IsInRange(b, be, bv) then
		hEffectTarget = be
		bw = "辅助攻击"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return a.ConsiderItemDesire["item_manta"](bm)
end
a.ConsiderItemDesire["item_woodland_striders"] = function(bm)
	if b:DistanceFromFountain() < 600 then
		return 0
	end
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	if f.IsRetreating(b) and b:WasRecentlyDamagedByAnyHero(4.0) then
		hEffectTarget = b
		bw = "撤退"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_fallen_sky"] = function(bm)
	local bv = 1600
	local bq = "ground"
	local ek = 315
	local et = 0.5
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		local eu = f.GetAoeEnemyHeroLocation(b, bv, ek, 2)
		if eu ~= nil then
			hEffectTarget = eu
			bw = "Aoe"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if f.IsValidHero(be) and f.CanCastOnNonMagicImmune(be) and f.IsInRange(b, be, bv) then
			local ev = f.GetDelayCastLocation(b, be, bv, ek, et)
			if ev ~= nil then
				hEffectTarget = ev
				bw = "进攻"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if f.IsRetreating(b) and b:WasRecentlyDamagedByAnyHero(3.0) then
		local bK = f.GetLocationTowardDistanceLocation(b, GetAncient(d):GetLocation(), 1600)
		local e6 = f.GetNearbyHeroes(b, 800, false, BOT_MODE_ATTACK)
		if
			b:DistanceFromFountain() > 800
			and IsLocationPassable(bK)
			and (#e6 == 0 or b:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH * 0.9)
			and #bx >= 1
		then
			hEffectTarget = bK
			bw = "撤退"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_ex_machina"] = function(bm)
	local bv = 800
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if f.IsValidHero(be) then
			local ew = { 0, 1, 2, 3, 4, 5 }
			local ex = 0
			for aX, bl in pairs(ew) do
				local bm = b:GetItemInSlot(bl)
				if bm ~= nil and bm:GetName() ~= "item_refresher" then
					local ey = bm:GetCooldownTimeRemaining()
					ex = ex + ey
				end
			end
			if ex >= 30 then
				hEffectTarget = be
				bw = "刷新CD"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_stormcrafter"] = function(bm)
	local bv = 300 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
	if f.CanCastOnNonMagicImmune(b) and #bx > 0 then
		if b:IsRooted() or b:GetPrimaryAttribute() == ATTRIBUTE_INTELLECT and b:IsSilenced() and not a.IsDoomed(b) then
			hEffectTarget = b
			bw = "解缠绕:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		if f.IsUnitTargetProjectileIncoming(b, 400) then
			hEffectTarget = b
			bw = "防御弹道:" .. f.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_gungir"] = function(bm)
	local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), 1000)
	for aX, eq in pairs(nInRangeEnemy) do
		if
			f.IsValidTarget(eq)
			and f.IsUnitWillGoInvisible(eq)
			and f.IsClosestToDustLocation(b, eq:GetLocation())
			and not f.HasInvisCounterBuff(eq)
			and not f.IsSuspiciousIllusion(eq)
		then
			if bm:GetName() == "item_gungir" then
				hEffectTarget = eq:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, "unit", "Stop invis"
		end
	end
	return a.ConsiderItemDesire["item_rod_of_atos"](bm)
end
-- Meteor Hammer (Valve data: 2s channel, 600 range, 400 radius, 0.75s stun, burn hits buildings).
-- It had no rule, so it was bought and never cast. A tower or barracks while pushing with no
-- enemy hero near, or a disabled enemy hero in range (the stun lands after the 2s channel).
a.ConsiderItemDesire["item_meteor_hammer"] = function(bm)
	local range = 600 + b8
	if f.IsPushing(b) and #(f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE) or {}) == 0 then
		local buildings = {}
		for _, t in pairs(b:GetNearbyTowers(range, true) or {}) do
			buildings[#buildings + 1] = t
		end
		for _, r in pairs(b:GetNearbyBarracks(range, true) or {}) do
			buildings[#buildings + 1] = r
		end
		for _, bld in ipairs(buildings) do
			if f.IsValidBuilding(bld) and f.CanBeAttacked(bld) then
				return BOT_ACTION_DESIRE_HIGH, bld:GetLocation(), "ground", "meteor-building"
			end
		end
	end
	-- Not during OD's timed prison hammer (it lands as the prison ends), and never on an
	-- invulnerable target: game 021, 22:07, OD imprisoned an enemy and this rule cast the hammer
	-- at once on the "disabled" prisoner, which it cannot hit.
	if b._prison ~= nil then
		return BOT_ACTION_DESIRE_NONE
	end
	for _, e in pairs(f.GetNearbyHeroes(b, range, true, BOT_MODE_NONE) or {}) do
		if
			f.IsValidHero(e)
			and f.IsDisabled(e)
			and not e:IsInvulnerable()
			and f.CanCastOnNonMagicImmune(e)
			and not f.IsSuspiciousIllusion(e)
		then
			return BOT_ACTION_DESIRE_HIGH, e:GetLocation(), "ground", "meteor-disabled"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_pogo_stick"] = function(bm)
	local bv = 1000
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.IsInRange(b, be, b:GetAttackRange() + 400)
			and f.CanCastOnMagicImmune(be)
			and f.IsChasingTarget(b, be)
		then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(be)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if bf == BOT_MODE_RETREAT and b:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH then
		if b:IsFacingLocation(GetAncient(d):GetLocation(), 20) and b:DistanceFromFountain() > 600 and #bx >= 1 then
			hEffectTarget = b
			bw = "撤退了推自己"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_paintball"] = function(bm)
	local bv = 900 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if
		f.IsValidHero(be)
		and f.CanCastOnNonMagicImmune(be)
		and f.CanCastOnTargetAdvanced(be)
		and f.IsInRange(be, b, bv)
	then
		hEffectTarget = be
		bw = "仙灵榴弹:" .. f.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_heavy_blade"] = function(bm)
	local bv = bm:GetCastRange() + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	for D = 1, #GetTeamPlayers(GetTeam()) do
		local bA = GetTeamMember(D)
		if f.IsValidHero(bA) and f.IsInRange(b, bA, bv + 100) then
			if
				(f.IsGoingOnSomeone(bA) or f.IsRetreating(bA))
				and bA:WasRecentlyDamagedByAnyHero(2.0)
				and f.GetHP(bA) < 0.85
			then
				local d7 = f.GetNearbyHeroes(bA, 300, true, BOT_MODE_NONE)
				local br = d7[1]
				if f.IsValidHero(br) and f.CanCastOnMagicImmune(br) then
					hEffectTarget = bA
					bw = "行巫之祸驱散友军:" .. f.Chat.GetNormName(bA)
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
				end
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		if f.IsValidHero(be) and f.IsInRange(b, be, bv) and f.CanCastOnNonMagicImmune(be) then
			if be:WasRecentlyDamagedByAnyHero(3.0) and f.GetHP(be) < 0.7 then
				hEffectTarget = be
				bw = "行巫之祸驱散敌军:" .. f.Chat.GetNormName(be)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_revenants_brooch"] = function(bm)
	local bv = b:GetAttackRange() + 100
	local bq = "none"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if f.IsValidHero(be) and f.IsInRange(b, be, bv) then
			hEffectTarget = b
			bw = "亡魂胸针进攻:" .. f.Chat.GetNormName(be)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_wraith_pact"] = function(bm)
	local bv = 200 + b8
	local bq = "ground"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and be:GetAttackTarget() ~= nil
			and f.IsInRange(b, be, 900)
			and f.CanCastOnNonMagicImmune(be)
		then
			hEffectTarget = f.GetFaceTowardDistanceLocation(b, 200)
			bw = "怨灵之契进攻:" .. f.Chat.GetNormName(be)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_boots_of_bearing"] = function(bm)
	return a.ConsiderItemDesire["item_ancient_janggo"](bm)
end
a.ConsiderItemDesire["item_new"] = function(bm)
	local bv = 300 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsGoingOnSomeone(b) then
		if f.IsValidHero(be) then
			hEffectTarget = be
			bw = "进攻:" .. f.Chat.GetNormName(be)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_soul_ring"] = function(aT)
	local bq = "none"
	local hEffectTarget = b
	local bw = nil
	local ez = b:GetActiveMode()
	local eA = b:GetMana() / b:GetMaxMana()
	local eB = b:OriginalGetHealth() / b:OriginalGetMaxHealth()
	-- Techies uses it in his own script, only right before a Blast Off he cannot afford.
	if c == "npc_dota_hero_techies" then
		return BOT_ACTION_DESIRE_NONE
	end
	if (ez == BOT_MODE_FARM or ez == BOT_MODE_LANING) and eB > 0.5 and eA < 0.5 then
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_pavise"] = function(aT)
	local bv = 1000 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local cz = f.GetNearbyHeroes(b, bv, false, BOT_MODE_NONE)
	local eC = b:OriginalGetHealth() / b:OriginalGetMaxHealth()
	for aX, bA in pairs(cz) do
		if
			f.IsValidHero(bA)
			and bA ~= b
			and not bA:IsMagicImmune()
			and not bA:IsInvulnerable()
			and not bA:IsIllusion()
			and not bA:HasModifier("modifier_item_pavise_shield")
			and not bA:HasModifier("modifier_antimage_spell_shield")
			and (f.IsUnitTargetProjectileIncoming(bA, 800) or f.IsWillBeCastUnitTargetSpell(bA, 1200) or eC < 0.2)
		then
			hEffectTarget = bA
			bw = "帮助队友"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if f.IsValidHero(be) and f.IsInRange(b, be, 2400) and not f.IsInRange(b, be, 800) then
		if #cz >= 2 then
			local cJ = nil
			local da = 9999
			for aX, bA in pairs(cz) do
				if
					bA ~= b
					and not bA:IsIllusion()
					and f.IsInRange(bA, be, da)
					and not bA:HasModifier("modifier_item_pavise_shield")
					and not bA:HasModifier("modifier_antimage_spell_shield")
				then
					cJ = bA
					da = GetUnitToUnitDistance(be, bA)
					if f.IsHumanPlayer(bA) then
						break
					end
				end
			end
			if cJ ~= nil then
				hEffectTarget = cJ
				bw = "先给前排套上"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_harpoon"] = function(aT)
	local bv = 700 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local eD = b:GetAttackRange()
	local be = f.GetProperTarget(b)
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidTarget(be)
			and f.IsInRange(b, be, bv + eD)
			and not f.IsInRange(b, be, bv / 2)
			and not f.IsSuspiciousIllusion(be)
		then
			hEffectTarget = be
			bw = "Harpoon"
			if f.WeAreStronger(b, bv + eD) then
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			else
				return BOT_ACTION_DESIRE_MODERATE, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_disperser"] = function(aT)
	local bv = 600 + b8
	local bq = "unit"
	local hEffectTarget = nil
	local bw = nil
	local eD = b:GetAttackRange()
	local be = f.GetProperTarget(b)
	local nAllyHeroes = f.GetNearbyHeroes(b, bv, false, BOT_MODE_NONE)
	local nEnemyHeroes = f.GetNearbyHeroes(b, bv + eD, true, BOT_MODE_NONE)
	if f.IsDisabled(b) then
		if nEnemyHeroes ~= nil and #nEnemyHeroes >= 1 then
			hEffectTarget = b
			bw = "Disperser"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	for aX, eE in pairs(nAllyHeroes) do
		if
			nEnemyHeroes ~= nil
			and #nEnemyHeroes >= 1
			and eE:WasRecentlyDamagedByAnyHero(2)
			and not f.IsSuspiciousIllusion(eE)
		then
			hEffectTarget = eE
			bw = "Disperser"
			if f.IsDisabled(eE) then
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if eE:GetActiveMode() == BOT_MODE_RETREAT and f.GetHP(eE) < 0.42 then
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidTarget(be)
			and f.CanCastOnNonMagicImmune(be)
			and f.IsInRange(b, be, bv)
			and not f.IsSuspiciousIllusion(be)
			and not f.IsDisabled(be)
		then
			if
				be:GetCurrentMovementSpeed() > b:GetCurrentMovementSpeed()
				and b:IsFacingLocation(be:GetLocation(), 30)
				and not be:IsFacingLocation(b:GetLocation(), 30)
			then
				hEffectTarget = RandomInt(1, 100) > 20 and be or b
				bw = "Disperser"
				if f.WeAreStronger(b, bv + eD) then
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
				else
					return BOT_ACTION_DESIRE_MODERATE, hEffectTarget, bq, bw
				end
			end
		end
	end
	if f.IsInTeamFight(b, bv + eD) then
		local eF = f.GetAlliesNearLoc(b:GetLocation(), bv)
		if eF ~= nil and #eF >= 1 and nEnemyHeroes ~= nil and #nEnemyHeroes >= 2 then
			hEffectTarget = b
			bw = "Disperser"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
	end
	if f.IsRetreating(b) then
		if nEnemyHeroes ~= nil and #nEnemyHeroes >= 1 then
			if not f.WeAreStronger(b, bv + eD) or f.GetHP(b) < 0.33 then
				hEffectTarget = RandomInt(1, 100) > 10 and b or be
				bw = "Disperser"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_blood_grenade"] = function(aT)
	local bv = 900
	local ek = 300
	local eG = b:GetHealth()
	local eH = 75
	local eI = 50
	local eJ = 15
	local er = 5
	local nEnemyHeroes = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	local eK = eI + eJ * er
	for aX, eq in pairs(nEnemyHeroes) do
		local eL = f.CanKillTarget(eq, eK, DAMAGE_TYPE_MAGICAL)
		if f.IsInRange(b, eq, b:GetAttackRange()) and b:IsFacingLocation(eq:GetLocation(), 15) then
			eL = eL or f.CanKillTarget(eq, eK + 150, DAMAGE_TYPE_MAGICAL)
		end
		if
			f.IsValidHero(eq)
			and f.CanCastOnNonMagicImmune(eq)
			and eL
			and not f.IsSuspiciousIllusion(eq)
			and eG > eH * 2
		then
			local nInRangeEnemy = f.GetEnemiesNearLoc(eq:GetLocation(), ek)
			if nInRangeEnemy ~= nil and #nInRangeEnemy >= 1 then
				return BOT_ACTION_DESIRE_HIGH, f.GetCenterOfUnits(nInRangeEnemy), "ground", "Blood Grenade"
			end
			return BOT_ACTION_DESIRE_HIGH, eq:GetLocation(), "ground", "Blood Grenade"
		end
	end
	if f.IsGoingOnSomeone(b) then
		for aX, eq in pairs(nEnemyHeroes) do
			if
				f.IsValidHero(eq)
				and f.CanCastOnNonMagicImmune(eq)
				and f.IsChasingTarget(b, eq)
				and not f.IsSuspiciousIllusion(eq)
				and eG > eH * 2
			then
				local bE = f.GetNearbyHeroes(eq, 1200, true, BOT_MODE_NONE)
				local nInRangeEnemy = f.GetNearbyHeroes(eq, 1200, false, BOT_MODE_NONE)
				if
					bE ~= nil
					and nInRangeEnemy ~= nil
					and #bE >= #nInRangeEnemy
					and #bE >= 1
					and f.IsGoingOnSomeone(bE[1])
					and bE[1]:GetAttackTarget() == eq
					and f.IsChasingTarget(bE[1], eq)
					and not bE[1]:IsIllusion()
					and f.GetTotalEstimatedDamageToTarget(bE, eq) >= eq:GetHealth()
				then
					local eM = f.GetEnemiesNearLoc(eq:GetLocation(), ek)
					if eM ~= nil and #eM >= 1 then
						return BOT_ACTION_DESIRE_HIGH, f.GetCenterOfUnits(eM), "ground", "Blood Grenade"
					end
					return BOT_ACTION_DESIRE_HIGH, eq:GetLocation(), "ground", "Blood Grenade"
				end
			end
		end
	end
	-- An early fight item. In any fight, or from 8:00 on anywhere, throw it at an enemy hero in
	-- range instead of waiting for a kill. It otherwise sat in a slot until the game pushed it
	-- into the backpack (bot swaps do not take effect) and it was never thrown.
	local fighting = f.IsGoingOnSomeone(b) or f.IsInTeamFight(b, 1200)
	if (fighting or DotaTime() >= 8 * 60) and eG > eH * 2 then
		local best, bestCount = nil, 0
		for aX, eq in pairs(nEnemyHeroes) do
			if f.IsValidHero(eq) and f.CanCastOnNonMagicImmune(eq) and not f.IsSuspiciousIllusion(eq) then
				local group = f.GetEnemiesNearLoc(eq:GetLocation(), ek) or {}
				if best == nil or #group > bestCount then
					best, bestCount = eq, #group
				end
			end
		end
		if best ~= nil then
			local group = f.GetEnemiesNearLoc(best:GetLocation(), ek)
			local spot = (group ~= nil and #group >= 2) and f.GetCenterOfUnits(group) or best:GetLocation()
			pcall(print, string.format(
				"[OHA-ITEM] t=%.0f %s grenade-throw why=%s target=%s group=%d",
				DotaTime(),
				(string.gsub(c, "npc_dota_hero_", "")),
				fighting and "fight" or "late",
				(string.gsub(best:GetUnitName(), "npc_dota_hero_", "")),
				bestCount
			))
			return BOT_ACTION_DESIRE_HIGH, spot, "ground", "Blood Grenade"
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
local eN = 0
-- [OHA-ITEM] smoke: every Smoke of Deceit use with its reason.
local function SmokeLog(why, allies)
	if DotaTime() < (b._smokeLogAt or -999) then
		return
	end
	b._smokeLogAt = DotaTime() + 3
	pcall(print, string.format(
		"[OHA-ITEM] t=%.0f %s smoke why=%s allies=%d",
		DotaTime(),
		(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
		why,
		allies or 0
	))
end
-- The first enemy tower still standing in a lane, outer to inner.
local function SmokeNextEnemyTower(lane)
	local ids = lane == LANE_TOP and { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3 }
		or lane == LANE_MID and { TOWER_MID_1, TOWER_MID_2, TOWER_MID_3 }
		or { TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3 }
	for _, id in ipairs(ids) do
		local t = GetTower(GetOpposingTeam(), id)
		if t ~= nil and t:IsAlive() then
			return t
		end
	end
	return nil
end
a.ConsiderItemDesire["item_smoke_of_deceit"] = function(aT)
	local ek = 1200
	local bq = "none"
	local hEffectTarget = nil
	local bw = "Smoke Of Deceit"
	local eO = false
	local bE = f.GetAllyList(b, ek)
	local nInRangeEnemy = f.GetNearbyHeroes(b, ek, true, BOT_MODE_NONE)
	local eP = b:GetNearbyTowers(ek, true)
	-- Not before 10:00 (no build buys Smoke before the horn since 29becd3; pos 5 buys one from
	-- 12:00), and never in a lane fight or under our own tower: at 7:00 Techies popped one in
	-- team roam beside Medusa at our T1, in a creep wave.
	if DotaTime() < 10 * 60 then
		return BOT_ACTION_DESIRE_NONE
	end
	if #(b:GetNearbyLaneCreeps(1000, true) or {}) >= 3 or #(b:GetNearbyTowers(1000, false) or {}) >= 1 then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Never smoke alone after horn.
	if bE == nil or #bE < 2 then
		MatchTrace.Decide(
			b,
			"smoke_skip",
			"alone",
			string.format("allies=%d mode=%s", bE and #bE or 0, tostring(b:GetActiveMode())),
			8
		)
		return BOT_ACTION_DESIRE_NONE
	end
	if (nInRangeEnemy ~= nil and #nInRangeEnemy == 0) or (eP ~= nil and #eP == 0) then
		for aX, eE in pairs(bE) do
			if f.IsValidHero(eE) then
				local eQ = f.GetNearbyHeroes(eE, ek, true, BOT_MODE_NONE)
				local eR = eE:GetNearbyTowers(ek, true)
				if (eQ ~= nil and #eQ >= 1) or (eR ~= nil and #eR >= 1) then
					eO = true
					break
				end
			end
		end
	end
	if not eO then
		local bf = b:GetActiveMode()
		local eS = f.CheckTimeOfDay()
		hEffectTarget = b
		if bf == BOT_MODE_ROAM or bf == BOT_MODE_GANK or bf == BOT_MODE_TEAM_ROAM then
			SmokeLog("team-roam", #bE)
			MatchTrace.Item(b, "item_smoke_of_deceit", "team_roam", string.format("allies=%d", #bE))
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
		end
		-- A group walking to push a lane, still far from the tower (game 034, 16:30-17:15: four Dire
		-- heroes walked together from Radiant's mid tower to its top tower and killed Grimstroke
		-- and Riki on the way). Smoke hides the group until it reaches the wave.
		local pushLane = bf == BOT_MODE_PUSH_TOWER_TOP and LANE_TOP
			or bf == BOT_MODE_PUSH_TOWER_MID and LANE_MID
			or bf == BOT_MODE_PUSH_TOWER_BOT and LANE_BOT
			or nil
		if pushLane ~= nil and #bE >= 3 then
			local tower = SmokeNextEnemyTower(pushLane)
			local dist = tower ~= nil and GetUnitToUnitDistance(b, tower) or 0
			if dist > 2500 then
				SmokeLog(string.format("push-group lane=%d tower-dist=%d", pushLane, math.floor(dist)), #bE)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
		if
			eS == "day" and GetUnitToLocationDistance(b, f.Utils.RadiantRoshanLoc) < 600
			or eS == "night" and GetUnitToLocationDistance(b, f.Utils.DireRoshanLoc) < 600
		then
			if GetRoshanKillTime() > eN then
				eN = GetRoshanKillTime()
				SmokeLog("post-roshan", #bE)
				MatchTrace.Item(b, "item_smoke_of_deceit", "post_roshan", string.format("allies=%d", #bE))
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
		if bf == BOT_MODE_ROSHAN then
			if eS == "day" and GetUnitToLocationDistance(b, f.Utils.RadiantRoshanLoc) > 3000 then
				SmokeLog("to-roshan", #bE)
				MatchTrace.Item(b, "item_smoke_of_deceit", "to_roshan", string.format("allies=%d", #bE))
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
			if eS == "night" and GetUnitToLocationDistance(b, f.Utils.DireRoshanLoc) > 3000 then
				SmokeLog("to-roshan", #bE)
				MatchTrace.Item(b, "item_smoke_of_deceit", "to_roshan", string.format("allies=%d", #bE))
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, bq, bw
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
local eT = nil
a.ConsiderItemDesire["item_dust"] = function(aT)
	local ek = 1050
	-- Game 031, 28:40: Dazzle used Glimmer Cape (datafeed: 0.5s fade, 5s invisible) and no Dust
	-- came; the rules below only catch the half-second fade, or 0.2-0.5s after he vanished within
	-- 600. An enemy hero seen fading is remembered for 4s; while he is out of sight within 900 of
	-- where he was last seen (Dust: 1050 around the caster), the closest Dust holder reveals.
	do
		local now = DotaTime()
		b._invisSeen = b._invisSeen or {}
		for _, eq in pairs(f.GetEnemiesNearLoc(b:GetLocation(), 1600) or {}) do
			if
				f.IsValidHero(eq)
				and f.IsUnitWillGoInvisible(eq)
				and not f.HasInvisCounterBuff(eq)
				and not f.IsSuspiciousIllusion(eq)
			then
				local pid = eq:GetPlayerID()
				if b._invisSeen[pid] == nil then
					b._invisSeen[pid] = { t = now, loc = eq:GetLocation(), name = eq:GetUnitName(), logged = false }
				else
					b._invisSeen[pid].loc = eq:GetLocation()
				end
			end
		end
		for pid, v in pairs(b._invisSeen) do
			if now - v.t > 4 or not IsHeroAlive(pid) then
				-- Game 029: 15 fades seen, Grimstroke the closest holder 553-999 away, no Dust at all.
				-- Say which condition held it back the last time it was checked.
				if v.wasClosest and v.why ~= nil then
					pcall(print, string.format(
						"[OHA-DUST] t=%.0f %s no-dust on %s why=%s",
						now,
						(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
						(string.gsub(v.name, "npc_dota_hero_", "")),
						v.why
					))
				end
				b._invisSeen[pid] = nil
			else
				local info = GetHeroLastSeenInfo(pid)
				local ls = info ~= nil and info[1] or nil
				local loc = ls ~= nil and ls.location or v.loc
				local gone = ls == nil or ls.time_since_seen > 0.1
				local dist = GetUnitToLocationDistance(b, loc)
				local closest = f.IsClosestToDustLocation(b, loc)
				if closest then
					v.wasClosest = true
				end
				if not gone then
					v.why = "still-visible"
				elseif dist > 900 then
					v.why = string.format("far(%.0f)", dist)
				elseif not closest then
					v.why = "not-closest"
				elseif not IsLocationVisible(loc) then
					v.why = "spot-in-fog"
				else
					v.why = "cast-blocked"
				end
				if not v.logged and b:FindItemSlot("item_dust") >= 0 then
					v.logged = true
					pcall(print, string.format(
						"[OHA-DUST] t=%.0f %s saw %s fade dist=%.0f slot=%d closest=%s",
						now,
						(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
						(string.gsub(v.name, "npc_dota_hero_", "")),
						dist,
						b:FindItemSlot("item_dust"),
						tostring(closest)
					))
				end
				-- Only with his last spot still in our vision: a fader who walked into fog, blinked or
				-- teleported is not worth a Dust (user call).
				if gone and dist <= 900 and closest and IsLocationVisible(loc) then
					b._invisSeen[pid] = nil
					pcall(print, string.format(
						"[OHA-DUST] t=%.0f %s dust on %s dist=%.0f",
						now,
						(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
						(string.gsub(v.name, "npc_dota_hero_", "")),
						dist
					))
					return BOT_ACTION_DESIRE_HIGH, b, "none", nil
				end
			end
		end
	end
	if eT == nil then
		eT = GetTeamPlayers(GetOpposingTeam())
	end
	local df = b:GetNearbyTrees(500)
	if #df < 5 then
		for aX, Y in pairs(eT) do
			local Z = GetHeroLastSeenInfo(Y)
			if IsHeroAlive(Y) and Z ~= nil then
				local _ = Z[1]
				if
					_ ~= nil
					and _.time_since_seen > 0.2
					and _.time_since_seen < 0.5
					and GetUnitToLocationDistance(b, _.location) < ek - 450
					and f.IsClosestToDustLocation(b, _.location)
				then
					local bD = f.GetXUnitsTowardsLocation2(_.location, q, 200)
					if d == TEAM_DIRE then
						bD = f.GetXUnitsTowardsLocation2(_.location, p, 200)
					end
					if IsLocationVisible(bD) and IsLocationPassable(bD) then
						return BOT_ACTION_DESIRE_HIGH, b, "none", nil
					end
				end
			end
		end
	end
	if
		b:HasModifier("modifier_sandking_sand_storm_slow")
		or b:HasModifier("modifier_sandking_sand_storm_slow_aura_thinker")
	then
		return BOT_ACTION_DESIRE_HIGH, b, "none", nil
	end
	local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), ek)
	if nInRangeEnemy ~= nil and #nInRangeEnemy == 0 then
		if b:HasModifier("modifier_item_radiance_debuff") then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
		for aX, Y in pairs(eT) do
			if IsHeroAlive(Y) and b:WasRecentlyDamagedByPlayer(Y, 0.5) then
				local Z = GetHeroLastSeenInfo(Y)
				if Z ~= nil then
					local _ = Z[1]
					if _ ~= nil and GetUnitToLocationDistance(b, _.location) < ek then
						return BOT_ACTION_DESIRE_HIGH, b, "none", nil
					end
				end
			end
		end
	else
		for aX, eq in pairs(nInRangeEnemy) do
			if
				f.IsValidTarget(eq)
				and f.IsUnitWillGoInvisible(eq)
				and f.IsClosestToDustLocation(b, eq:GetLocation())
				and not f.HasInvisCounterBuff(eq)
				and not f.IsSuspiciousIllusion(eq)
			then
				local eU = eq:GetNearbyTowers(700, true)
				if eU == nil or #eU == 0 then
					return BOT_ACTION_DESIRE_HIGH, b, "none", nil
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Roshan's Banner (datafeed: placed within 1200, 120s, buffs our lane creeps in a 600/900/1200
-- radius by level; can be destroyed, melee heroes hit it twice as hard). Bots had no rule for it.
-- Bots carry it in the backpack: a.BannerFromBackpack swaps it into a main slot first.
-- Pushing (user call): planted behind our wave once the wave is at an enemy tower, barracks or
-- the ancient, so the creeps fighting the building get the buff. One banner per push.
-- Pushing, with an enemy tower, barracks or the ancient within 2500: a banner in the backpack goes
-- into a main slot (an empty one, else the cheapest), early enough for any backpack cooldown to run
-- out before the wave reaches the building. Once per 5s.
function a.BannerFromBackpack()
	local slot = b:FindItemSlot("item_roshans_banner")
	if slot < 6 or slot > 8 or not f.IsPushing(b) or DotaTime() < (b._bannerSwapAt or -999) then
		return
	end
	local near = nil
	for _, t in pairs(b:GetNearbyTowers(2500, true) or {}) do
		if f.IsValidBuilding(t) then
			near = t
			break
		end
	end
	if near == nil then
		for _, r in pairs(b:GetNearbyBarracks(2500, true) or {}) do
			if f.IsValidBuilding(r) then
				near = r
				break
			end
		end
	end
	local anc = GetAncient(GetOpposingTeam())
	if near == nil and anc ~= nil and GetUnitToUnitDistance(b, anc) <= 2500 then
		near = anc
	end
	if near == nil then
		return
	end
	local dest = require(GetScriptDirectory() .. "/FuncLib/systems/item").GetMainInvLessValItemSlot(b)
	if dest == nil or dest < 0 then
		return
	end
	b._bannerSwapAt = DotaTime() + 5
	local out = b:GetItemInSlot(dest)
	-- Forced: the swap wrapper (global_overrides) refuses a swap with an enemy hero within 1000,
	-- and an enemy base always has one (game 029, 52:33-53:24: 9 tries, the banner never moved).
	b._swapDespiteEnemies = true
	b._swapDespiteCooldown = true
	pcall(print, string.format(
		"[OHA-BANNER] t=%.0f %s swap slot%d->%d out=%s building=%s dist=%.0f",
		DotaTime(),
		(string.gsub(c, "npc_dota_hero_", "")),
		slot,
		dest,
		out ~= nil and out:GetName() or "-",
		(string.gsub(near:GetUnitName(), "npc_dota_", "")),
		GetUnitToUnitDistance(b, near)
	))
	b:ActionImmediate_SwapItems(slot, dest)
end
a.ConsiderItemDesire["item_roshans_banner"] = function(bm)
	if not f.IsPushing(b) or b:WasRecentlyDamagedByAnyHero(1.5) and f.GetHP(b) < 0.4 then
		return BOT_ACTION_DESIRE_NONE
	end
	local building = nil
	local bd = 99999
	local cands = {}
	for _, t in pairs(b:GetNearbyTowers(1600, true) or {}) do
		table.insert(cands, t)
	end
	for _, r in pairs(b:GetNearbyBarracks(1600, true) or {}) do
		table.insert(cands, r)
	end
	local anc = GetAncient(GetOpposingTeam())
	if anc ~= nil and GetUnitToUnitDistance(b, anc) <= 1600 then
		table.insert(cands, anc)
	end
	for _, u in ipairs(cands) do
		if f.IsValidBuilding(u) and not u:IsInvulnerable() then
			local d0 = GetUnitToUnitDistance(b, u)
			if d0 < bd then
				building, bd = u, d0
			end
		end
	end
	if building == nil then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Our creeps at the building (within 900 of it).
	local wave = {}
	for _, cr in pairs(b:GetNearbyLaneCreeps(1600, false) or {}) do
		if f.IsValid(cr) and GetUnitToUnitDistance(cr, building) <= 900 then
			table.insert(wave, cr)
		end
	end
	-- 5+ creeps (user call: 3 is too few to be worth it).
	if #wave < 5 then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Not on top of another of our banners.
	for _, u in pairs(GetUnitList(UNIT_LIST_ALLIES) or {}) do
		if
			u ~= nil
			and not u:IsNull()
			and u:IsAlive()
			and string.find(u:GetUnitName(), "roshans_banner")
			and GetUnitToUnitDistance(u, building) <= 1500
		then
			return BOT_ACTION_DESIRE_NONE
		end
	end
	-- Behind the wave, 250 toward our fountain from its center: the creeps stay in the radius,
	-- and the banner is not the first thing the building shoots.
	local loc = f.GetXUnitsTowardsLocation2(f.GetCenterOfUnits(wave), f.GetTeamFountain(), 250)
	if GetUnitToLocationDistance(b, loc) > 1150 or not IsLocationPassable(loc) then
		return BOT_ACTION_DESIRE_NONE
	end
	pcall(print, string.format(
		"[OHA-BANNER] t=%.0f %s plant at=%.0f,%.0f building=%s dist=%.0f creeps=%d",
		DotaTime(),
		(string.gsub(c, "npc_dota_hero_", "")),
		loc.x,
		loc.y,
		(string.gsub(building:GetUnitName(), "npc_dota_", "")),
		bd,
		#wave
	))
	return BOT_ACTION_DESIRE_HIGH, loc, "ground", nil
end
a.ConsiderItemDesire["item_trusty_shovel"] = function(bm)
	if GetTeamMember(1):IsBot() then
		return BOT_ACTION_DESIRE_NONE
	end
	local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), 1000)
	if nInRangeEnemy ~= nil and #nInRangeEnemy == 0 then
		return BOT_ACTION_DESIRE_HIGH, b:GetLocation(), "ground", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_arcane_ring"] = function(bm)
	return a.ConsiderItemDesire["item_arcane_boots"](bm)
end
a.ConsiderItemDesire["item_unstable_wand"] = function(bm)
	local bv = 1600
	local nInRangeEnemy = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if
		nInRangeEnemy ~= nil
		and #nInRangeEnemy == 0
		and f.GetMP(b) > 0.5
		and (f.IsRetreating(b) or f.IsGoingOnSomeone(b))
	then
		return BOT_ACTION_DESIRE_HIGH, b, "none", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_seeds_of_serenity"] = function(bm)
	local ek = 400
	local nInRangeEnemy = f.GetNearbyHeroes(b, ek, true, BOT_MODE_NONE)
	local eP = b:GetNearbyTowers(700, true)
	if f.IsFarming(b) then
		if f.IsAttacking(b) then
			local eV = b:GetNearbyNeutralCreeps(ek)
			if eV ~= nil and (#eV >= 3 or #eV >= 2 and eV[1]:IsAncientCreep()) then
				return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
			end
			local bH = b:GetNearbyLaneCreeps(ek, true)
			if bH ~= nil and #bH >= 3 then
				return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
			end
		end
	end
	if f.IsPushing(b) then
		if
			eP ~= nil
			and #eP >= 1
			and f.IsValidBuilding(be)
			and f.IsValidBuilding(eP[1])
			and f.IsAttacking(b)
			and be == eP[1]
		then
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation(), "ground", nil
		end
	end
	if f.IsDoingRoshan(b) then
		if f.IsRoshan(be) and f.IsInRange(b, be, ek) and f.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation(), "ground", nil
		end
	end
	if f.IsDoingTormentor(b) then
		if f.IsTormentor(be) and f.IsInRange(b, be, ek) and f.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation(), "ground", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_dagger_of_ristul"] = function(bm)
	local bq = "none"
	if f.GetHP(b) < 0.4 then
		return BOT_ACTION_DESIRE_NONE
	end
	if f.IsGoingOnSomeone(b) then
		if f.IsValidTarget(be) and f.IsInRange(b, be, 800) and f.GetHP(b) > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, b, bq, nil
		end
	end
	if f.IsFarming(b) and f.IsAttacking(b) and f.GetHP(b) > 0.7 then
		local eV = b:GetNearbyNeutralCreeps(600)
		if eV ~= nil and #eV >= 2 then
			return BOT_ACTION_DESIRE_HIGH, b, bq, nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_stonefeather_satchel"] = function(bm)
	local bq = "none"
	local nEnemyHeroes = f.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
	if
		#nEnemyHeroes >= 1
		and (f.IsRetreating(b) or f.GetHP(b) < 0.5)
		and not b:HasModifier("modifier_item_stonefeather_satchel_rocks")
	then
		return BOT_ACTION_DESIRE_HIGH, b, bq, nil
	end
	if #nEnemyHeroes == 0 and not b:HasModifier("modifier_item_stonefeather_satchel_feathers") then
		return BOT_ACTION_DESIRE_MODERATE, b, bq, nil
	end
	return BOT_ACTION_DESIRE_NONE
end
local eW = nil
a.ConsiderItemDesire["item_royal_jelly"] = function(bm)
	if eW == nil then
		eW = DotaTime()
	else
		if eW < DotaTime() - 2.0 then
			local cJ = nil
			for D = 1, #GetTeamPlayers(GetTeam()) do
				local eE = GetTeamMember(D)
				if
					f.IsValidHero(eE)
					and f.IsCore(eE)
					and not eE:IsIllusion()
					and not eE:HasModifier("modifier_royal_jelly")
				then
					cJ = eE
				end
			end
			if cJ ~= nil then
				eW = nil
				return BOT_ACTION_DESIRE_HIGH, cJ, "unit", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_bullwhip"] = function(bm)
	local bv = 850 + b8
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.CanCastOnNonMagicImmune(be)
			and f.IsChasingTarget(b, be)
			and not f.IsDisabled(be)
		then
			return BOT_ACTION_DESIRE_HIGH, be, "unit", nil
		end
	end
	local bE = f.GetAlliesNearLoc(b:GetLocation(), bv)
	for aX, eE in pairs(bE) do
		if f.IsValidHero(eE) and f.CanCastOnNonMagicImmune(eE) then
			local eQ = f.GetNearbyHeroes(eE, 1200, true, BOT_MODE_NONE)
			if
				eQ ~= nil
				and #eQ >= 1
				and f.IsRetreating(eE)
				and eE:DistanceFromFountain() > 1200
				and not f.IsRealInvisible(eE)
				and not f.IsDisabled(eE)
			then
				return BOT_ACTION_DESIRE_HIGH, eE, "unit", nil
			end
		end
	end
	if bm:IsFullyCastable() then
		return BOT_ACTION_DESIRE_HIGH, b, "unit", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_light_collector"] = function(bm)
	local ek = 325
	local eX = b:GetNearbyTrees(ek)
	if f.IsGoingOnSomeone(b) then
		if eX ~= nil and #eX >= 3 then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_iron_talon"] = function(bm)
	local bv = 350
	if f.IsFarming(b) then
		local eY = b:GetNearbyNeutralCreeps(bv)
		if #eY <= 0 then
			return 0
		end
		local eZ = f.GetMostHpUnit(eY)
		if f.CanBeAttacked(eZ) and f.GetHP(eZ) > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, eZ, "unit", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_craggy_coat"] = function(bm)
	local ek = 1200
	if f.IsInTeamFight(b) then
		local e_ = f.GetEnemiesNearLoc(b:GetLocation(), ek)
		if e_ ~= nil and #e_ >= 2 and b:WasRecentlyDamagedByAnyHero(1.5) then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsGoingOnSomeone(b) then
		local bE = f.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
		if
			f.IsValidTarget(be)
			and f.IsAttacking(be)
			and b:WasRecentlyDamagedByAnyHero(1.3)
			and f.IsInRange(b, be, 600)
			and not f.IsSuspiciousIllusion(be)
		then
			local eM = f.GetNearbyHeroes(be, 1200, false, BOT_MODE_NONE)
			if bE ~= nil and eM ~= nil and #bE >= #eM then
				return BOT_ACTION_DESIRE_HIGH, b, "none", nil
			end
		end
	end
	if f.IsDoingRoshan(b) then
		if f.IsRoshan(be) and f.IsInRange(b, be, 500) and f.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsDoingTormentor(b) then
		if f.IsTormentor(be) and f.IsInRange(b, be, 500) and f.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_psychic_headband"] = function(bm)
	local bv = 600 + b8
	local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), bv)
	if f.IsRetreating(b) then
		if
			f.IsValidHero(nInRangeEnemy[1])
			and f.CanCastOnNonMagicImmune(nInRangeEnemy[1])
			and f.IsRunning(nInRangeEnemy[1])
			and nInRangeEnemy[1]:IsFacingLocation(b:GetLocation(), 30)
			and not f.IsSuspiciousIllusion(nInRangeEnemy[1])
			and not f.IsDisabled(nInRangeEnemy[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nInRangeEnemy[1], "unit", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_ogre_seal_totem"] = function(bm)
	local f0 = 275
	local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), f0 * 2)
	if f.IsGoingOnSomeone(b) then
		local bE = f.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
		if
			f.IsValidTarget(be)
			and f.CanCastOnNonMagicImmune(be)
			and b:IsFacingLocation(be:GetLocation(), 5)
			and f.IsInRange(b, be, f0 * 2)
			and not f.IsInRange(b, be, f0 - 75)
			and not f.IsSuspiciousIllusion(be)
			and not b:HasModifier("modifier_abaddon_borrowed_time")
			and not b:HasModifier("modifier_necrolyte_reapers_scythe")
			and not f.IsLocationInChrono(be:GetLocation())
			and not f.IsLocationInBlackHole(be:GetLocation())
		then
			local eM = f.GetNearbyHeroes(be, 1000, false, BOT_MODE_NONE)
			if bE ~= nil and eM ~= nil and #bE >= #eM then
				return BOT_ACTION_DESIRE_HIGH, b, "unit", nil
			end
		end
	end
	if f.IsRetreating(b) then
		if
			f.IsValidHero(nInRangeEnemy[1])
			and f.IsRunning(nInRangeEnemy[1])
			and b:IsFacingLocation(f.GetEscapeLoc(), 15)
			and nInRangeEnemy[1]:IsFacingLocation(b:GetLocation(), 30)
		then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
local f1 = "health"
a.ConsiderItemDesire["item_doubloon"] = function(bm)
	local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), 1000)
	if f.IsGoingOnSomeone(b) then
		local bE = f.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
		if
			f.IsValidTarget(be)
			and f.IsInRange(b, be, 1000)
			and f.GetHP(b) > 0.8
			and f.GetMP(b) < 0.5
			and f1 == "mana"
			and not f.IsSuspiciousIllusion(be)
		then
			f1 = "health"
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsRetreating(b) then
		if
			f.IsValidHero(nInRangeEnemy[1])
			and f.IsRunning(nInRangeEnemy[1])
			and nInRangeEnemy[1]:IsFacingLocation(b:GetLocation(), 30)
			and b:WasRecentlyDamagedByAnyHero(1.5)
			and f.GetHP(b) < 0.5
			and f.GetMP(b) > 0.75
			and f1 == "health"
		then
			f1 = "mana"
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_ninja_gear"] = function(bm)
	local bv = 1600
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidTarget(be)
			and f.CanCastOnMagicImmune(be)
			and f.IsInRange(b, be, 2800)
			and not f.IsInRange(b, be, be:GetCurrentVisionRange() + 200)
			and not f.IsSuspiciousIllusion(be)
		then
			local bH = b:GetNearbyLaneCreeps(800, true)
			local eU = b:GetNearbyTowers(700, true)
			if bH ~= nil and #bH == 0 and eU ~= nil and #eU == 0 then
				return BOT_ACTION_DESIRE_HIGH, b, "none", nil
			end
		end
	end
	if f.IsDefending(b) then
		local bf = b:GetActiveMode()
		local dz = LANE_MID
		if bf == BOT_MODE_PUSH_TOWER_TOP then
			dz = LANE_TOP
		end
		if bf == BOT_MODE_PUSH_TOWER_BOT then
			dz = LANE_BOT
		end
		local f2 = GetLaneFrontLocation(d, dz, 0)
		if GetUnitToLocationDistance(b, f2) > 3200 then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsDoingRoshan(b) then
		if f.CheckTimeOfDay() == "day" and GetUnitToLocationDistance(b, f.Utils.RadiantRoshanLoc) > 3200 then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
		if f.CheckTimeOfDay() == "night" and GetUnitToLocationDistance(b, f.Utils.DireRoshanLoc) > 3200 then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsDoingTormentor(b) and GetUnitToLocationDistance(b, f.GetTormentorLocation(GetTeam())) > 3200 then
		return BOT_ACTION_DESIRE_HIGH, b, "none", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_trickster_cloak"] = function(bm)
	return a.ConsiderItemDesire["item_invis_sword"](bm)
end
a.ConsiderItemDesire["item_havoc_hammer"] = function(bm)
	local ek = 400
	local bZ = 175 + b:GetAttributeValue(ATTRIBUTE_STRENGTH) * 1.5
	local nEnemyHeroes = f.GetNearbyHeroes(b, ek, true, BOT_MODE_NONE)
	for aX, eq in pairs(nEnemyHeroes) do
		if
			f.IsValidHero(eq)
			and f.CanCastOnNonMagicImmune(eq)
			and f.CanKillTarget(eq, bZ, DAMAGE_TYPE_MAGICAL)
			and not f.IsSuspiciousIllusion(eq)
			and not eq:HasModifier("modifier_abaddon_borrowed_time")
			and not eq:HasModifier("modifier_dazzle_shallow_grave")
			and not eq:HasModifier("modifier_oracle_false_promise_timer")
			and not eq:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsInTeamFight(b, 1200) then
		local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), 1000)
		if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2 then
			local e_ = f.GetEnemiesNearLoc(b:GetLocation(), ek)
			if
				e_ ~= nil
				and #e_ >= 2
				and not f.IsLocationInChrono(nInRangeEnemy[1]:GetLocation())
				and not f.IsLocationInBlackHole(nInRangeEnemy[1]:GetLocation())
			then
				return BOT_ACTION_DESIRE_HIGH, b, "none", nil
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		local bE = f.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
		if
			f.IsValidTarget(be)
			and f.CanCastOnNonMagicImmune(be)
			and f.IsInRange(b, be, ek)
			and f.IsRunning(be)
			and b:IsFacingLocation(be:GetLocation(), 30)
			and not be:IsFacingLocation(b:GetLocation(), 90)
			and not f.IsSuspiciousIllusion(be)
			and not f.IsDisabled(be)
		then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsDoingRoshan(b) then
		if f.IsRoshan(be) and f.IsInRange(b, be, ek) and f.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsDoingTormentor(b) then
		if f.IsTormentor(be) and f.IsInRange(b, be, ek) and f.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_martyrs_plate"] = function(bm)
	local ek = 900
	if f.IsInTeamFight(b) then
		local bE = f.GetAlliesNearLoc(b:GetLocation(), ek)
		local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), ek)
		if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2 then
			if
				f.IsValidHero(nInRangeEnemy[1])
				and f.IsValidHero(nInRangeEnemy[2])
				and f.IsAttacking(nInRangeEnemy[1])
				and f.IsAttacking(nInRangeEnemy[2])
				and f.GetHP(b) > 0.88
				and b:GetHealth() >= 3800
				and not b:WasRecentlyDamagedByAnyHero(0.8)
			then
				return BOT_ACTION_DESIRE_HIGH, b, "none", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_force_boots"] = function(bm)
	local bv = 700 + b8
	local nInRangeEnemy = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsStuck(b) then
		return BOT_ACTION_DESIRE_HIGH, b, "unit", nil
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidTarget(be)
			and f.IsInRange(b, be, 900)
			and a.IsWithoutSpellShield(be)
			and not f.IsSuspiciousIllusion(be)
			and not f.IsLocationInChrono(be:GetLocation())
			and not f.IsLocationInBlackHole(be:GetLocation())
			and not be:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local bE = f.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
			local eM = f.GetNearbyHeroes(be, 1200, false, BOT_MODE_NONE)
			if bE ~= nil and eM ~= nil and #bE >= #eM then
				if b:IsFacingLocation(be:GetLocation(), 15) and #bE >= #eM + 1 then
					return BOT_ACTION_DESIRE_HIGH, b, "unit", nil
				end
				local ck = f.GetCenterOfUnits(bE)
				if be:IsFacingLocation(ck, 15) and GetUnitToLocationDistance(b, ck) >= 750 then
					return BOT_ACTION_DESIRE_HIGH, be, "unit", nil
				end
			end
		end
	end
	if f.IsRetreating(b) then
		if
			nInRangeEnemy ~= nil
			and #nInRangeEnemy >= 1
			and b:IsFacingLocation(f.GetEscapeLoc(), 30)
			and b:DistanceFromFountain() > 600
			and not f.IsRealInvisible(b)
		then
			return BOT_ACTION_DESIRE_HIGH, b, "unit", nil
		end
	end
	local bE = f.GetAlliesNearLoc(b:GetLocation(), bv)
	for aX, eE in pairs(bE) do
		if f.IsValidHero(eE) and f.CanCastOnNonMagicImmune(eE) then
			local eQ = f.GetNearbyHeroes(eE, 1200, true, BOT_MODE_NONE)
			if
				eQ ~= nil
				and #eQ >= 1
				and f.IsRetreating(eE)
				and eE:IsFacingLocation(f.GetEscapeLoc(), 30)
				and eE:DistanceFromFountain() > 600
				and eE:WasRecentlyDamagedByAnyHero(2.2)
				and not f.IsRealInvisible(eE)
			then
				return BOT_ACTION_DESIRE_HIGH, eE, "unit", nil
			end
			if f.IsGoingOnSomeone(eE) then
				local d9 = f.GetProperTarget(eE)
				if
					f.IsValidHero(d9)
					and f.CanCastOnNonMagicImmune(d9)
					and eE:IsFacingLocation(d9:GetLocation(), 15)
					and GetUnitToUnitDistance(eE, d9) > eE:GetAttackRange() + 50
					and GetUnitToUnitDistance(eE, d9) < eE:GetAttackRange() + 700
					and f.IsRunning(d9)
					and f.GetEnemyCount(eE, 1600) <= 3
					and not d9:IsFacingLocation(eE:GetLocation(), 40)
					and not f.IsSuspiciousIllusion(d9)
				then
					return BOT_ACTION_DESIRE_HIGH, eE, "unit", nil
				end
			end
			if f.IsStuck(eE) then
				return BOT_ACTION_DESIRE_HIGH, eE, "unit", nil
			end
		end
	end
	if b:DistanceFromFountain() < 2800 then
		for aX, eq in pairs(nInRangeEnemy) do
			if
				f.IsValidHero(eq)
				and f.CanCastOnMagicImmune(eq)
				and eq:IsFacingLocation(GetAncient(d):GetLocation(), 30)
				and GetUnitToLocationDistance(eq, GetAncient(d):GetLocation()) < 1600
				and not f.IsSuspiciousIllusion(eq)
			then
				local bE = f.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
				local eM = f.GetNearbyHeroes(eq, 1000, false, BOT_MODE_NONE)
				if bE ~= nil and eM ~= nil and #bE >= #eM then
					return BOT_ACTION_DESIRE_HIGH, eq, "unit", nil
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_seer_stone"] = function(bm)
	local ek = 800
	if f.IsGoingOnSomeone(b) then
		local f3 = b:FindAoELocation(true, true, b:GetLocation(), 1600, ek, 0, 0)
		local nInRangeEnemy = f.GetEnemiesNearLoc(f3.targetloc, ek)
		local cr = nil
		for aX, eq in pairs(nInRangeEnemy) do
			if
				f.IsValidHero(eq)
				and f.IsInRange(b, eq, ek)
				and f.CanCastOnMagicImmune(eq)
				and f.HasInvisibilityOrItem(eq)
				and not eq:HasModifier("modifier_slardar_amplify_damage")
				and not eq:HasModifier("modifier_item_dustofappearance")
				and not f.Site.IsLocationHaveTrueSight(eq:GetLocation())
			then
				return BOT_ACTION_DESIRE_HIGH, f3.targetloc, "ground", nil
			end
		end
	end
	local f4 = 0
	for aX, eq in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if f.IsValidHero(eq) and not f.IsSuspiciousIllusion(eq) then
			f4 = f4 + 1
		end
	end
	if f.IsRoshanAlive() and f4 == 0 then
		if f.CheckTimeOfDay() == "day" and GetUnitToLocationDistance(b, f.Utils.RadiantRoshanLoc) > 1600 then
			return BOT_ACTION_DESIRE_HIGH, f.Utils.RadiantRoshanLoc, "ground", nil
		end
		if f.CheckTimeOfDay() == "night" and GetUnitToLocationDistance(b, f.Utils.DireRoshanLoc) > 1600 then
			return BOT_ACTION_DESIRE_HIGH, f.Utils.DireRoshanLoc, "ground", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_demonicon"] = function(bm)
	local bv = 750
	local bx = f.GetNearbyHeroes(b, bv, true, BOT_MODE_NONE)
	if f.IsPushing(b) then
		local eU = b:GetNearbyTowers(900, true)
		local f5 = b:GetNearbyLaneCreeps(900, false)
		if eU ~= nil and #eU >= 1 and f5 ~= nil and #f5 >= 3 then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsValidTarget(be) and f.IsInRange(b, be, 1000) and not be:HasModifier("modifier_abaddon_borrowed_time") then
		local eM = f.GetNearbyHeroes(be, 1000, false, BOT_MODE_NONE)
		if eM ~= nil then
			if #eM == 0 then
				return BOT_ACTION_DESIRE_HIGH, b, "none", nil
			end
			if #eM >= 1 then
				return BOT_ACTION_DESIRE_HIGH, b, "none", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_force_field"] = function(bm)
	local ek = 1200
	local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), ek)
	for aX, eq in pairs(nInRangeEnemy) do
		if
			f.IsValidHero(eq)
			and eq:GetAttackTarget() == b
			and (b:WasRecentlyDamagedByHero(eq, 5) or f.IsAttackProjectileIncoming(b, 500))
			and not f.IsSuspiciousIllusion(eq)
		then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_pirate_hat"] = function(bm)
	return a.ConsiderItemDesire["item_trusty_shovel"](bm)
end
a.ConsiderItemDesire["item_mana_draught"] = function(bm)
	local nEnemyHeroes = b:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if
		#nEnemyHeroes == 0
		or f.IsValidHero(nEnemyHeroes[1])
			and not f.IsInRange(b, nEnemyHeroes[1], 800)
			and not b:WasRecentlyDamagedByAnyHero(5.0)
	then
		if f.GetMP(b) < 0.5 then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_polliwog_charm"] = function(bm)
	local bv = 1000
	if b:GetMana() < 75 + 40 then
		return BOT_ACTION_DESIRE_NONE
	end
	local nAllyHeroes = f.GetAlliesNearLoc(b:GetLocation(), bv)
	local c0 = nil
	local c1 = 99999
	for aX, eE in pairs(nAllyHeroes) do
		if
			f.IsValidHero(eE)
			and not eE:IsIllusion()
			and not eE:HasModifier("modifier_abaddon_borrowed_time")
			and not eE:HasModifier("modifier_necrolyte_reapers_scythe")
			and not eE:HasModifier("modifier_filler_heal")
			and not eE:HasModifier("modifier_elixer_healing")
			and not eE:HasModifier("modifier_flask_healing")
			and not eE:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not eE:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not eE:IsChanneling()
			and eE:GetMaxHealth() - eE:GetHealth() > 100
		then
			if eE:GetHealth() < c1 then
				c0 = eE
				c1 = eE:GetHealth()
			end
		end
	end
	if c0 ~= nil then
		return BOT_ACTION_DESIRE_HIGH, c0, "unit", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_rippers_lash"] = function(bm)
	local bv = 700
	local ek = 200
	local nAllyHeroes = f.GetAlliesNearLoc(b:GetLocation(), bv)
	for aX, eE in pairs(nAllyHeroes) do
		if f.IsValidHero(eE) and not eE:IsIllusion() then
			local ci = eE:GetAttackTarget()
			if f.IsGoingOnSomeone(eE) and f.IsAttacking(eE) then
				if
					f.IsValidHero(ci)
					and f.CanBeAttacked(ci)
					and f.IsInRange(eE, ci, eE:GetAttackRange() + 50)
					and f.IsInRange(b, ci, bv)
					and not f.IsSuspiciousIllusion(ci)
					and not ci:HasModifier("modifier_abaddon_borrowed_time")
					and not ci:HasModifier("modifier_necrolyte_reapers_scythe")
					and not ci:HasModifier("modifier_dazzle_shallow_grave")
				then
					local f3 = b:FindAoELocation(true, true, ci:GetLocation(), 0, ek, 0, 0)
					if f3.count >= 2 then
						return BOT_ACTION_DESIRE_HIGH, f3.targetloc, "point", nil
					else
						return BOT_ACTION_DESIRE_HIGH, ci:GetLocation(), "point", nil
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_gale_guard"] = function(bm)
	local nAllyHeroes = b:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nEnemyHeroes = b:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if b:HasModifier("modifier_abaddon_aphotic_shield") or not f.CanBeAttacked(b) then
		return BOT_ACTION_DESIRE_NONE
	end
	if b:IsRooted() and #nEnemyHeroes > 0 then
		return BOT_ACTION_DESIRE_HIGH, b, "none", nil
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.IsInRange(b, be, b:GetAttackRange() + 300)
			and (f.GetHP(b) < 0.65 and b:WasRecentlyDamagedByAnyHero(3.0))
			and not f.IsSuspiciousIllusion(be)
		then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsRetreating(b) and not f.IsRealInvisible(b) then
		for aX, eq in pairs(nEnemyHeroes) do
			if
				f.IsValidHero(eq)
				and f.IsInRange(b, eq, 800)
				and f.IsChasingTarget(eq, b)
				and not f.IsSuspiciousIllusion(eq)
			then
				if #nEnemyHeroes > #nAllyHeroes or f.GetHP(b) < 0.55 and b:WasRecentlyDamagedByAnyHero(3.0) then
					return BOT_ACTION_DESIRE_HIGH, b, "none", nil
				end
			end
		end
	end
	if f.IsFarming(b) then
		local cL = b:GetNearbyCreeps(1600, true)
		if cL then
			if f.IsValid(cL[1]) and f.CanBeAttacked(cL[1]) and f.GetHP(b) < 0.25 and f.IsAttacking(b) then
				return BOT_ACTION_DESIRE_HIGH, b, "none", nil
			end
		end
	end
	if f.IsDoingRoshan(b) then
		if
			f.IsRoshan(be)
			and f.CanBeAttacked(be)
			and f.IsInRange(b, be, 500)
			and f.IsAttacking(b)
			and f.GetHP(b) < 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if f.IsDoingTormentor(b) then
		if f.IsTormentor(be) and f.IsInRange(b, be, 400) and f.IsAttacking(b) and f.GetHP(b) < 0.5 then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_crippling_crossbow"] = function(bm)
	local bv = f.GetProperCastRange(false, b, bm:GetCastRange())
	local bZ = bm:GetSpecialValueInt("damage")
	local nAllyHeroes = b:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nEnemyHeroes = b:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for aX, eq in pairs(nEnemyHeroes) do
		if
			f.IsValidHero(eq)
			and f.IsInRange(b, eq, bv)
			and not f.IsInRange(b, eq, bv / 2)
			and f.CanCastOnNonMagicImmune(eq)
			and f.CanCastOnTargetAdvanced(eq)
		then
			if
				f.CanKillTarget(eq, bZ, DAMAGE_TYPE_MAGICAL)
				and not eq:HasModifier("modifier_abaddon_borrowed_time")
				and not eq:HasModifier("modifier_dazzle_shallow_grave")
				and not eq:HasModifier("modifier_necrolyte_reapers_scythe")
				and not eq:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH, eq, "unit", nil
			end
		end
	end
	if f.IsGoingOnSomeone(b) then
		if
			f.IsValidHero(be)
			and f.CanBeAttacked(be)
			and f.CanCastOnNonMagicImmune(be)
			and f.CanCastOnTargetAdvanced(be)
			and f.IsInRange(b, be, bv)
			and not f.IsInRange(b, be, bv / 2)
			and f.IsChasingTarget(b, be)
		then
			return BOT_ACTION_DESIRE_HIGH, be, "unit", nil
		end
	end
	if f.IsRetreating(b) and not f.IsRealInvisible(b) then
		for aX, eq in pairs(nEnemyHeroes) do
			if
				f.IsValidHero(eq)
				and f.IsInRange(b, eq, bv)
				and f.CanCastOnNonMagicImmune(eq)
				and f.CanCastOnTargetAdvanced(eq)
				and f.IsChasingTarget(eq, b)
				and not f.IsDisabled(eq)
			then
				if #nEnemyHeroes > #nAllyHeroes or f.GetHP(b) < 0.55 and b:WasRecentlyDamagedByAnyHero(3.0) then
					return BOT_ACTION_DESIRE_HIGH, eq, "unit", nil
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_pyrrhic_cloak"] = function(bm)
	local bv = f.GetProperCastRange(false, b, bm:GetCastRange())
	local nEnemyHeroes = b:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if
		f.IsNotAttackProjectileIncoming(b, 400)
		and f.IsValidHero(nEnemyHeroes[1])
		and f.IsInRange(b, nEnemyHeroes[1], bv)
		and f.CanCastOnNonMagicImmune(nEnemyHeroes[1])
		and f.CanCastOnTargetAdvanced(nEnemyHeroes[1])
	then
		return BOT_ACTION_DESIRE_HIGH, nEnemyHeroes[1], "unit", nil
	end
	for aX, eq in pairs(nEnemyHeroes) do
		if
			f.IsValidHero(eq)
			and f.IsInRange(b, eq, bv)
			and f.CanCastOnNonMagicImmune(eq)
			and f.CanCastOnTargetAdvanced(eq)
			and eq:GetAttackTarget() == b
			and (b:WasRecentlyDamagedByHero(eq, 3.0) or f.IsAttackProjectileIncoming(b, 1000))
		then
			return BOT_ACTION_DESIRE_HIGH, eq, "unit", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_minotaur_horn"] = function(bm)
	if
		b:IsMagicImmune()
		or not f.CanBeAttacked(b)
		or not b:HasModifier("modifier_item_lotus_orb_active")
		or not b:HasModifier("modifier_antimage_spell_shield")
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local nEnemyHeroes = f.GetEnemiesNearLoc(b:GetLocation(), 1200)
	if (f.IsGoingOnSomeone(b) or f.IsRetreating(b) and not f.IsRealInvisible(b)) and #nEnemyHeroes > 0 then
		if b:IsRooted() then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
		nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), 600)
		if b:IsSilenced() and #nInRangeEnemy >= 2 and not b:HasModifier("modifier_item_mask_of_madness_berserk") then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
		if
			f.IsNotAttackProjectileIncoming(b, 300)
			or f.IsWillBeCastUnitTargetSpell(b, 300)
			or f.IsWillBeCastPointSpell(b, 300)
		then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
		nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), 1200)
		if
			#nInRangeEnemy > #nAllyHeroes
			and f.GetHP(b) < 0.6
			and f.IsValidHero(nInRangeEnemy[1])
			and (f.IsChasingTarget(nInRangeEnemy[1], b) or nInRangeEnemy[1]:GetAttackTarget() == b)
		then
			return BOT_ACTION_DESIRE_HIGH, b, "none", nil
		end
	end
	if
		b:HasModifier("modifier_jakiro_macropyre_burn")
		or b:HasModifier("modifier_lich_chainfrost_slow")
		or b:HasModifier("modifier_crystal_maiden_freezing_field_slow")
		or b:HasModifier("modifier_puck_coiled")
		or b:HasModifier("modifier_skywrath_mystic_flare_aura_effect")
		or b:HasModifier("modifier_snapfire_magma_burn_slow")
		or b:HasModifier("modifier_sand_king_epicenter_slow")
	then
		return BOT_ACTION_DESIRE_HIGH, b, "none", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
a.ConsiderItemDesire["item_book_of_shadows"] = function(bm)
	local bv = 700 + b8
	local bE = f.GetAlliesNearLoc(b:GetLocation(), bv)
	local nInRangeEnemy = f.GetEnemiesNearLoc(b:GetLocation(), 1200)
	for aX, eE in pairs(bE) do
		if f.IsValidHero(eE) and f.CanCastOnNonMagicImmune(eE) and eE:WasRecentlyDamagedByAnyHero(3) then
			local eQ = f.GetNearbyHeroes(eE, 1200, true, BOT_MODE_NONE)
			if
				eQ ~= nil
				and #eQ >= 1
				and f.IsRetreating(eE)
				and not f.IsRealInvisible(eE)
				and not f.IsDisabled(eE)
				and eE:DistanceFromFountain() > 1200
			then
				return BOT_ACTION_DESIRE_HIGH, eE, "unit", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.IsTargetedByEnemy(W)
	local f6 = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	for aX, f7 in pairs(f6) do
		if f.IsValidHero(f7) then
			if GetUnitToUnitDistance(W, f7) <= f7:GetAttackRange() + 200 and f7:GetAttackTarget() == W then
				return true
			end
		end
	end
	return false
end
local function f8()
	if
		GetGlyphCooldown() > 0
		or DotaTime() < 60
		or b ~= GetTeamMember(1)
		or not GetTeamMember(2):IsBot()
		or not GetTeamMember(3):IsBot()
		or not GetTeamMember(4):IsBot()
		or not GetTeamMember(5):IsBot()
	then
		return
	end
	local f9 = {
		TOWER_TOP_1,
		TOWER_MID_1,
		TOWER_BOT_1,
		TOWER_TOP_2,
		TOWER_MID_2,
		TOWER_BOT_2,
		TOWER_TOP_3,
		TOWER_MID_3,
		TOWER_BOT_3,
		TOWER_BASE_1,
		TOWER_BASE_2,
	}
	for aX, fa in pairs(f9) do
		local aU = GetTower(d, fa)
		if
			aU ~= nil
			and aU:GetHealth() > 0
			and aU:GetHealth() / aU:GetMaxHealth() < 0.36
			and aU:CanBeSeen()
			and a.IsTargetedByEnemy(aU)
		then
			b:ActionImmediate_Glyph()
			return
		end
	end
	local fb = { BARRACKS_TOP_MELEE, BARRACKS_MID_MELEE, BARRACKS_BOT_MELEE }
	for aX, fc in pairs(fb) do
		local fd = GetBarracks(d, fc)
		if
			fd ~= nil
			and fd:GetHealth() > 0
			and fd:GetHealth() / fd:GetMaxHealth() < 0.5
			and a.IsTargetedByEnemy(fd)
		then
			b:ActionImmediate_Glyph()
			return
		end
	end
	local fe = GetAncient(d)
	if fe ~= nil and fe:GetHealth() > 0 and fe:GetHealth() / fe:GetMaxHealth() < 0.5 and a.IsTargetedByEnemy(fe) then
		b:ActionImmediate_Glyph()
		return
	end
end
-- [OHA-STUCK]: a live hero away from the fountain that has moved less than 300 in 8s while not
-- attacking, casting or channeling. Catches back-and-forth between two orders too, which the
-- idle nudge in global_overrides misses (the hero is never "idle"). At most every 10s per bot.
local STUCK_MODE_NAMES = nil
local function StuckModeName(mode)
	if STUCK_MODE_NAMES == nil then
		STUCK_MODE_NAMES = {}
		for name, id in pairs(_G) do
			if type(name) == "string" and type(id) == "number" and string.sub(name, 1, 9) == "BOT_MODE_" then
				STUCK_MODE_NAMES[id] = string.lower(string.sub(name, 10))
			end
		end
	end
	return STUCK_MODE_NAMES[mode] or tostring(mode)
end
-- [OHA-FLIP] a bot flipping between modes without getting anywhere: 6+ mode changes in 20s with
-- under 800 net movement. Game 019, 40:40-41:20: Gyrocopter by his mid T2 went roam 0.89, retreat
-- 0.29, roam 0.34, push 0.61 while walking back and forth (35 moved over a 2229 path). Lists
-- each mode with its desire at the switch. Once every 30s per bot at most.
function a.LogModeFlip()
	if not b:IsAlive() then
		b._modeHist = nil
		return
	end
	local now = DotaTime()
	local mode = b:GetActiveMode()
	local hist = b._modeHist or {}
	b._modeHist = hist
	local last = hist[#hist]
	if last == nil or last.mode ~= mode then
		hist[#hist + 1] = { t = now, mode = mode, des = b:GetActiveModeDesire(), loc = b:GetLocation() }
	end
	while #hist > 0 and hist[1].t < now - 20 do
		table.remove(hist, 1)
	end
	if #hist < 7 or now < (b._modeFlipLogAt or -999) then
		return
	end
	local moved = f.GetLocationToLocationDistance(hist[1].loc, b:GetLocation())
	if moved >= 800 then
		return
	end
	b._modeFlipLogAt = now + 30
	local parts = {}
	for _, h0 in ipairs(hist) do
		parts[#parts + 1] = string.format("%s:%.2f@%.0f", StuckModeName(h0.mode), h0.des or 0, h0.t)
	end
	local loc = b:GetLocation()
	pcall(print, string.format(
		"[OHA-FLIP] t=%.0f %s changes=%d moved=%d at=%.0f,%.0f hp=%.2f enemies=%d modes=%s",
		now,
		(string.gsub(c, "npc_dota_hero_", "")),
		#hist - 1,
		math.floor(moved),
		loc.x,
		loc.y,
		f.GetHP(b),
		#(f.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE) or {}),
		table.concat(parts, ">")
	))
end
function a.LogStuck()
	-- Laning holds position between last hits by design (239 of 855 lines in one game).
	if
		not b:IsAlive()
		or b:IsChanneling()
		or b:IsCastingAbility()
		or b:DistanceFromFountain() < 1200
		or b:GetActiveMode() == BOT_MODE_LANING
	then
		b._stuckTrail = nil
		return
	end
	local now = DotaTime()
	if now < (b._stuckSampleAt or -999) then
		return
	end
	b._stuckSampleAt = now + 1
	local trail = b._stuckTrail or {}
	b._stuckTrail = trail
	trail[#trail + 1] = { t = now, loc = b:GetLocation() }
	while #trail > 0 and trail[1].t < now - 8.5 do
		table.remove(trail, 1)
	end
	if #trail < 8 or now < (b._stuckLogAt or -999) then
		return
	end
	local attacking = b:GetAttackTarget() ~= nil
	local moved = f.GetLocationToLocationDistance(trail[1].loc, b:GetLocation())
	local path = 0
	for k = 2, #trail do
		path = path + f.GetLocationToLocationDistance(trail[k - 1].loc, trail[k].loc)
	end
	if moved < 300 and not attacking then
		b._stuckLogAt = now + 10
		local loc = b:GetLocation()
		pcall(print, string.format(
			"[OHA-STUCK] t=%.0f %s mode=%s/%.2f action=%s moved=%d path=%d at=%.0f,%.0f hp=%.2f enemies=%d",
			now,
			(string.gsub(c, "npc_dota_hero_", "")),
			StuckModeName(b:GetActiveMode()),
			b:GetActiveModeDesire(),
			tostring(b:GetCurrentActionType()),
			math.floor(moved),
			math.floor(path),
			loc.x,
			loc.y,
			f.GetHP(b),
			#(f.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE) or {})
		))
	end
end
-- An enemy tower shooting at the bot: an attack order on an allied lane creep that stands inside
-- the tower range makes the tower switch to it. Only a creep already within the bot's attack
-- range (+50) is used, so there is no walk: walking to a creep would keep the hero under the
-- tower longer and break a chase or a run. One order, then 2s before another; the mode's own
-- next order carries on (move, chase). Any HP: the order alone moves the tower's aggro, even on a
-- full-HP creep the hero cannot actually hit.
-- Logs [OHA-AGGRO] tower-deflect, and 0.8s later whether the tower switched target.
function a.DeflectTowerAggro()
	local now = DotaTime()
	if b._deaggroTower ~= nil and now - (b._deaggroAt or -99) >= 0.8 and not b._deaggroChecked then
		b._deaggroChecked = true
		local tw = b._deaggroTower
		local switched = f.IsValidBuilding(tw) and tw:GetAttackTarget() ~= b
		if not switched then
			b._deaggroFailedAt = now
		end
		pcall(print, string.format(
			"[OHA-AGGRO] t=%.0f %s tower-deflect result=%s",
			now,
			(string.gsub(c, "npc_dota_hero_", "")),
			switched and "switched" or "still-on-me"
		))
	end
	if not b:IsAlive() or b:IsInvulnerable() or now < (b._deaggroAt or -99) + 2 then
		return false
	end
	-- Walk out instead (game 034, 26:47-26:59: Phoenix kept getting a deflect order every 2s after
	-- it failed, each one cancelling the push mode's step out of range; he went from 85% to 9% HP
	-- under the tower, logged idle). No deflect below 60% HP or while retreating (the modes walk
	-- the bot out from there), and none for 6s after one that did not move the tower's aggro.
	if f.GetHP(b) < 0.6 or b:GetActiveMode() == BOT_MODE_RETREAT or now < (b._deaggroFailedAt or -99) + 6 then
		return false
	end
	for _, tw in pairs(b:GetNearbyTowers(1000, true) or {}) do
		if f.IsValidBuilding(tw) and tw:GetAttackTarget() == b then
			local reach = b:GetAttackRange() + 50
			local towerReach = tw:GetAttackRange() or 700
			local best, bestScore = nil, math.huge
			for _, cr in pairs(b:GetNearbyLaneCreeps(reach + 200, false) or {}) do
				if
					f.IsValid(cr)
					and GetUnitToUnitDistance(b, cr) <= reach
					and GetUnitToUnitDistance(tw, cr) <= towerReach
				then
					local score = GetUnitToUnitDistance(b, cr)
					if score < bestScore then
						best, bestScore = cr, score
					end
				end
			end
			if best ~= nil then
				b._deaggroAt = now
				b._deaggroTower = tw
				b._deaggroChecked = false
				pcall(print, string.format(
					"[OHA-AGGRO] t=%.0f %s tower-deflect creepHp=%.2f dist=%d mode=%s",
					now,
					(string.gsub(c, "npc_dota_hero_", "")),
					f.GetHP(best),
					GetUnitToUnitDistance(b, best),
					StuckModeName(b:GetActiveMode())
				))
				b:Action_AttackUnit(best, true)
				return true
			end
			return false
		end
	end
	return false
end
-- [OHA-HOMEWALK]: a healthy bot (HP 80%+, mana 40%+) closing on its fountain for 4s+ while
-- outside it, after 10:00. Shows the mode and action behind walks home nobody asked for (game
-- 015, 52:20: Medusa walked back to the fountain at full HP after defending the high ground).
-- At most every 15s per bot.
function a.LogHomeWalk()
	if DotaTime() < 600 or not b:IsAlive() then
		b._homeWalkSince = nil
		return
	end
	local d = b:DistanceFromFountain()
	local healthy = f.GetHP(b) >= 0.8 and (b:GetMaxMana() <= 0 or f.GetMP(b) >= 0.4)
	local closing = b._homeWalkLast ~= nil and d < b._homeWalkLast - 5
	b._homeWalkLast = d
	if not healthy or d < 1200 or d > 9000 or not closing or f.IsRetreating(b) then
		if not closing then
			b._homeWalkSince = nil
		end
		return
	end
	b._homeWalkSince = b._homeWalkSince or DotaTime()
	if DotaTime() - b._homeWalkSince < 4 or DotaTime() < (b._homeWalkLogAt or -999) then
		return
	end
	b._homeWalkLogAt = DotaTime() + 15
	local loc = b:GetLocation()
	pcall(print, string.format(
		"[OHA-HOMEWALK] t=%.0f %s mode=%s/%.2f action=%s fountainDist=%d at=%.0f,%.0f hp=%.2f stash=%d courier=%d",
		DotaTime(),
		(string.gsub(c, "npc_dota_hero_", "")),
		StuckModeName(b:GetActiveMode()),
		b:GetActiveModeDesire(),
		tostring(b:GetCurrentActionType()),
		math.floor(d),
		loc.x,
		loc.y,
		f.GetHP(b),
		b:GetStashValue(),
		b:GetCourierValue()
	))
end
-- A teleport just landed (TP scroll, Teleportation, Boots of Travel...): 1500+ moved in under
-- 1.5s. The "go farm" TPs wait 20s after it: game 020, 6:02-6:08, Nature's Prophet used
-- Teleportation to help top (team roam 1.50), landed, and laning mode TP'd him back to his
-- bottom lane 6s later ("出去发育").
function a.TrackTeleportJump()
	-- A respawn moves him to the fountain too: not a teleport.
	if not b:IsAlive() then
		b._jumpTrack = nil
		return
	end
	local now = DotaTime()
	local here = b:GetLocation()
	local last = b._jumpTrack
	if last ~= nil and now - last.t <= 1.5 and f.GetLocationToLocationDistance(last.loc, here) >= 1500 then
		b._jumpAt = now
	end
	if last == nil or now - last.t >= 0.5 then
		b._jumpTrack = { t = now, loc = here }
	end
end
function a.JustTeleported()
	return DotaTime() - (b._jumpAt or -999) < 20
end
-- Stuck order queue: queued orders, not channelling or in a cast, and under 50 moved for 4s.
-- Game 021, 36:51-37:25: Doom stood still 12,500 from his base in defend mode with enemies at
-- his Ancient (current action idle / use-ability); the item think skips everything while
-- orders are queued, so a Forager mushroom in his bag was never eaten either. The orders are
-- cleared so modes and items work again.
function a.WatchStuckQueue()
	if not b:IsAlive() or b:NumQueuedActions() <= 0 or b:IsChanneling() or b:IsCastingAbility() then
		b._qWatch = nil
		return false
	end
	local now = DotaTime()
	local here = b:GetLocation()
	local w = b._qWatch
	if w == nil or f.GetLocationToLocationDistance(w.loc, here) >= 50 then
		b._qWatch = { since = now, loc = here }
		return false
	end
	if now - w.since < 4 then
		return false
	end
	b._qWatch = nil
	pcall(print, string.format(
		"[OHA-STUCK] t=%.0f %s queue-cleared queued=%d action=%s mode=%d",
		now,
		(string.gsub(c, "npc_dota_hero_", "")),
		b:NumQueuedActions(),
		tostring(b:GetCurrentActionType()),
		b:GetActiveMode()
	))
	b:Action_ClearActions(true)
	return true
end
-- Game 031, 29:42-29:50: Doom teleported to the bottom lane and stood still while 3 enemies hit
-- him, with nothing in the log. Standing (moved under 40 in 2s) while a hero hit him in the last
-- second, not disabled, not casting: log the mode, desire, action and his debuffs, once per 8s.
function a.WatchStillUnderHit()
	if not b:IsAlive() or not b:WasRecentlyDamagedByAnyHero(1.0) then
		b._stillWatch = nil
		return
	end
	local now = DotaTime()
	local here = b:GetLocation()
	local w = b._stillWatch
	if w == nil or f.GetLocationToLocationDistance(w.loc, here) >= 40 then
		b._stillWatch = { since = now, loc = here }
		return
	end
	if now - w.since < 2 or now < (b._stillLogAt or -999) then
		return
	end
	if b:IsStunned() or b:IsRooted() or b:IsHexed() or b:IsNightmared() or b:IsChanneling() or b:IsCastingAbility() then
		return
	end
	-- Attacking in place is fine (game 029, 52:22 and 52:30: Medusa and Pudge hitting a hero).
	local tgt0 = b:GetAttackTarget()
	if tgt0 ~= nil and not tgt0:IsNull() and tgt0:IsAlive() and GetUnitToUnitDistance(b, tgt0) <= b:GetAttackRange() + 150 then
		return
	end
	b._stillLogAt = now + 8
	local mods = {}
	for i = 0, math.min(b:NumModifiers(), 24) - 1 do
		local name = b:GetModifierName(i)
		if name ~= nil then
			table.insert(mods, (string.gsub(name, "^modifier_", "")))
		end
	end
	local target = b:GetAttackTarget()
	pcall(print, string.format(
		"[OHA-STILL] t=%.0f %s still=%.1fs mode=%d desire=%.2f action=%s queued=%d target=%s hp=%.2f foes=%d mods=%s",
		now,
		(string.gsub(c, "npc_dota_hero_", "")),
		now - w.since,
		b:GetActiveMode(),
		b:GetActiveModeDesire(),
		tostring(b:GetCurrentActionType()),
		b:NumQueuedActions(),
		target ~= nil and not target:IsNull() and (string.gsub(target:GetUnitName(), "npc_dota_", "")) or "-",
		f.GetHP(b),
		#(f.GetEnemiesNearLoc(here, 1200) or {}),
		#mods > 0 and table.concat(mods, ",") or "-"
	))
end
-- Forager mushrooms in a main slot, eaten ahead of the item think's busy gate (queued orders,
-- casting ...). Game 032, 13:14-19:07: Medusa swapped a Vital Toadstool into a main slot every
-- 16s and never ate it; it went back to the backpack each time. Targeting from the datafeed:
-- Vital Toadstool is unit-target (cast on self), Ironwood Nut and Tomo'kan Ringcap are no-target
-- (the Ringcap was being cast on a unit). Once per 0.5s.
local FORAGE_NO_TARGET = { item_foragers_stats = true, item_foragers_mana = true }
function a.EatForage()
	if not b:IsAlive() or DotaTime() < (b._forageEatAt or -999) then
		return false
	end
	if b:IsStunned() or b:IsHexed() or b:IsChanneling() or b:IsCastingAbility() or b:IsInvulnerable() then
		return false
	end
	local okM, muted = pcall(function()
		return b:IsMuted()
	end)
	if okM and muted then
		return false
	end
	for slot = 0, 5 do
		local it = b:GetItemInSlot(slot)
		if it ~= nil and not it:IsNull() then
			local name = it:GetName()
			if (FORAGE_NO_TARGET[name] or name == "item_foragers_health") and f.CanCastAbility(it) then
				b._forageEatAt = DotaTime() + 0.5
				pcall(print, string.format("[OHA-FORAGE] t=%.0f %s eat %s slot%d", DotaTime(), (string.gsub(c, "npc_dota_hero_", "")), name, slot))
				if FORAGE_NO_TARGET[name] then
					b:Action_UseAbility(it)
				else
					b:Action_UseAbilityOnEntity(it, b)
				end
				return true
			end
		end
	end
	return false
end
-- Dust ahead of the item think's busy gate (queued orders and the like), as for the mushrooms:
-- the Dust rule decides, this only makes sure it can act. Dust is no-target (datafeed).
function a.UseDustNow()
	if not b:IsAlive() or b:IsStunned() or b:IsHexed() or b:IsChanneling() or b:IsCastingAbility() then
		return false
	end
	local okM, muted = pcall(function()
		return b:IsMuted()
	end)
	if okM and muted then
		return false
	end
	local slot = b:FindItemSlot("item_dust")
	if slot < 0 or slot > 5 then
		return false
	end
	local dust = b:GetItemInSlot(slot)
	local rule = a.ConsiderItemDesire["item_dust"]
	if dust == nil or rule == nil or not f.CanCastAbility(dust) then
		return false
	end
	local desire = rule(dust)
	if type(desire) == "number" and desire > 0 then
		b:Action_UseAbility(dust)
		return true
	end
	return false
end
-- [OHA-COURIER] what the courier takes and delivers, and what shows up in the inventory (user ask,
-- game 031: Earthshaker's sentry was in the stash / on the courier while he kept switching a
-- dispenser with 1 observer). take: the stash items when the courier is sent for them; deliver:
-- the order with the courier's value; arrived: an item that appears in the inventory away from
-- the shop (or a dispenser whose charges change), checked once a second.
-- [OHA-API] one-time dump of the bot API this game build actually exposes (user ask: the online
-- docs are old and list no vector-target action). Radiant's first bot, once, at the first item
-- think: every global callable by name, every global table with callables (classes such as
-- CDOTA_Bot_Script) with its own and its metatable's callables, 25 names a line, sorted.
local function ApiNames(t)
	local names = {}
	local seen = {}
	local function add(tbl)
		if type(tbl) ~= "table" then
			return
		end
		for k, v in pairs(tbl) do
			if type(k) == "string" and type(v) == "function" and not seen[k] then
				seen[k] = true
				names[#names + 1] = k
			end
		end
	end
	add(t)
	local okM, mt = pcall(getmetatable, t)
	if okM and type(mt) == "table" then
		add(mt)
		if type(mt.__index) == "table" then
			add(mt.__index)
		end
	end
	table.sort(names)
	return names
end
local function ApiPrint(label, names)
	for i = 1, #names, 25 do
		local part = {}
		for j = i, math.min(i + 24, #names) do
			part[#part + 1] = names[j]
		end
		pcall(print, string.format("[OHA-API] %s n=%d %d-%d: %s", label, #names, i, i + #part - 1, table.concat(part, ",")))
	end
end
function a.DumpBotApi()
	if _G.OHA_API_DUMPED or GetTeam() ~= TEAM_RADIANT then
		return
	end
	local first = GetTeamMember(1)
	if first == nil or first:GetPlayerID() ~= b:GetPlayerID() then
		return
	end
	_G.OHA_API_DUMPED = true
	local globals, classes = {}, {}
	for k, v in pairs(_G) do
		if type(k) == "string" then
			if type(v) == "function" then
				globals[#globals + 1] = k
			elseif type(v) == "table" and k ~= "_G" and string.sub(k, 1, 1) == "C" then
				classes[#classes + 1] = k
			end
		end
	end
	table.sort(globals)
	table.sort(classes)
	ApiPrint("globals", globals)
	for _, cls in ipairs(classes) do
		local names = ApiNames(_G[cls])
		if #names > 0 then
			ApiPrint(cls, names)
		end
	end
	-- The bot's own handle, in case its class table is not a global.
	ApiPrint("bot-handle", ApiNames(b))
	-- Numeric constants for shrines and ability behaviors (is ABILITY_BEHAVIOR_VECTOR_TARGETING
	-- defined for bots?), and what the old healing-shrine API returns now that 7.33 replaced those
	-- shrines with lotus pools and watchers: GetShrine for every SHRINE_* id on both teams.
	local consts = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "number" and (string.find(k, "^SHRINE_") or string.find(k, "^ABILITY_BEHAVIOR_")) then
			consts[#consts + 1] = k .. "=" .. tostring(v)
		end
	end
	table.sort(consts)
	ApiPrint("constants", consts)
	local shrineIds = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "number" and string.find(k, "^SHRINE_") then
			shrineIds[#shrineIds + 1] = { name = k, id = v }
		end
	end
	table.sort(shrineIds, function(x, y)
		return x.id < y.id
	end)
	if #shrineIds == 0 then
		pcall(print, "[OHA-API] shrine no SHRINE_* constants defined")
	end
	for _, team in ipairs({ TEAM_RADIANT, TEAM_DIRE }) do
		for _, s in ipairs(shrineIds) do
			local ok, shrine = pcall(GetShrine, team, s.id)
			local detail
			if not ok then
				detail = "error=" .. tostring(shrine)
			elseif shrine == nil then
				detail = "nil"
			else
				local okL, loc = pcall(function()
					return shrine:GetLocation()
				end)
				local okN, name = pcall(function()
					return shrine:GetUnitName()
				end)
				local okC, cd = pcall(GetShrineCooldown, shrine)
				local okH, healing = pcall(IsShrineHealing, shrine)
				detail = string.format(
					"unit=%s xy=%s cooldown=%s healing=%s",
					okN and tostring(name) or "?",
					okL and loc ~= nil and string.format("%d,%d", math.floor(loc.x), math.floor(loc.y)) or "?",
					okC and tostring(cd) or "error",
					okH and tostring(healing) or "error"
				)
			end
			pcall(print, string.format(
				"[OHA-API] shrine team=%s %s(%d): %s",
				team == TEAM_RADIANT and "radiant" or "dire",
				s.name,
				s.id,
				detail
			))
		end
	end
end
function a.LogCourier(kind)
	local now = DotaTime()
	b._courierLogAt = b._courierLogAt or {}
	if now < (b._courierLogAt[kind] or -999) then
		return
	end
	b._courierLogAt[kind] = now + 3
	local names = {}
	for slot = 9, 14 do
		local it = b:GetItemInSlot(slot)
		if it ~= nil and not it:IsNull() then
			names[#names + 1] = (string.gsub(it:GetName(), "^item_", ""))
		end
	end
	pcall(print, string.format(
		"[OHA-COURIER] t=%.0f %s %s stash=%s stashValue=%d courierValue=%d",
		now,
		(string.gsub(c, "npc_dota_hero_", "")),
		kind,
		#names > 0 and table.concat(names, ",") or "-",
		b:GetStashValue(),
		b:GetCourierValue()
	))
end
local function DispenserCounts(it)
	local obs = it:GetCurrentCharges() or 0
	local okS, sen = pcall(function()
		return it:GetSecondaryCharges()
	end)
	return obs, okS and type(sen) == "number" and sen or -1
end
function a.WatchArrivals()
	local now = DotaTime()
	if now < (b._arrivalAt or -999) or not b:IsAlive() then
		return
	end
	b._arrivalAt = now + 1
	local count, disp = {}, nil
	for slot = 0, 8 do
		local it = b:GetItemInSlot(slot)
		if it ~= nil and not it:IsNull() then
			local nm = it:GetName()
			count[nm] = (count[nm] or 0) + 1
			if nm == "item_ward_dispenser" then
				local o, s0 = DispenserCounts(it)
				disp = { obs = o, sen = s0, slot = slot }
			end
		end
	end
	local prev = b._arrivalPrev
	b._arrivalPrev = { count = count, disp = disp }
	if prev == nil then
		return
	end
	local atShop = b:DistanceFromFountain() <= 1000
	for nm, n in pairs(count) do
		if n > (prev.count[nm] or 0) and not atShop then
			pcall(print, string.format(
				"[OHA-COURIER] t=%.0f %s arrived %s slot=%d",
				now,
				(string.gsub(c, "npc_dota_hero_", "")),
				(string.gsub(nm, "^item_", "")),
				b:FindItemSlot(nm)
			))
		end
	end
	local pd = prev.disp
	if disp ~= nil and (pd == nil or pd.obs ~= disp.obs or pd.sen ~= disp.sen) then
		pcall(print, string.format(
			"[OHA-COURIER] t=%.0f %s dispenser obs=%s->%d sen=%s->%d slot=%d",
			now,
			(string.gsub(c, "npc_dota_hero_", "")),
			pd ~= nil and tostring(pd.obs) or "-",
			disp.obs,
			pd ~= nil and tostring(pd.sen) or "-",
			disp.sen,
			disp.slot
		))
	end
end
-- Walk out of a Serpent Ward ring through the gap (see GetSerpentWardEscapeDesire in
-- FuncLib/hero/special_units.lua): once the snake on our way out is dead, move 250 past where it
-- stood for 1.5s. Runs from the item think, which acts after the mode thinks, so no mode turns the
-- bot back into the ring. Logged once per escape.
function a.WalkOutOfSnakes()
	local now = DotaTime()
	if not b:IsAlive() then
		b._snakeExit = nil
		b._snakeExitWard = nil
		return false
	end
	local w = b._snakeExitWard
	if w ~= nil and now - (b._snakeExitWardAt or -999) < 6 then
		local dead = w:IsNull() or not w:IsAlive()
		if dead and b._snakeExitWardLoc ~= nil then
			local from = b:GetLocation()
			local dir = b._snakeExitWardLoc - from
			if dir:Length2D() < 1 then
				dir = f.GetTeamFountain() - from
			end
			b._snakeExit = { loc = b._snakeExitWardLoc + dir:Normalized() * 250, untilAt = now + 1.5 }
			b._snakeExitWard = nil
			pcall(print, string.format("[OHA-SNAKE] t=%.0f %s walk-out hp=%.2f", now, (string.gsub(c, "npc_dota_hero_", "")), f.GetHP(b)))
		end
	elseif w ~= nil then
		b._snakeExitWard = nil
	end
	local e = b._snakeExit
	if e == nil then
		return false
	end
	if now > e.untilAt or GetUnitToLocationDistance(b, e.loc) < 60 then
		b._snakeExit = nil
		return false
	end
	if b:IsStunned() or b:IsRooted() or b:IsHexed() or b:IsChanneling() then
		return false
	end
	b:Action_MoveToLocation(e.loc)
	return true
end
function a.RunePickupLock()
	return b:IsAlive()
		and b:GetActiveMode() == BOT_MODE_RUNE
		and DotaTime() - (b._runePickupAt or -999) < 0.5
end
function ItemUsageThink()
	local _perfT0 = nil
	if MatchTrace.PerfEnabled and MatchTrace.PerfEnabled() and RealTime then
		_perfT0 = RealTime()
	end
	local function _perfDone()
		if _perfT0 then
			MatchTrace.PerfSample("ItemUsageThink", RealTime() - _perfT0)
		end
	end
	MatchTrace.Tick(b)
	-- Ability charges for every bot (the API has no ability-charge read); before any gate below.
	pcall(ChargeTracker.Tick, b)
	pcall(a.TrackTeleportJump)
	pcall(a.WatchStillUnderHit)
	pcall(a.WatchArrivals)
	pcall(a.DumpBotApi)
	pcall(a.LogHomeWalk)
	local okQ, cleared = pcall(a.WatchStuckQueue)
	if okQ and cleared then
		return
	end
	-- Rune mode just ordered a rune pick-up: no item or spell order this frame, it would replace
	-- the pick-up. The river horn gold stopped being taken from build 043 on, the build that fixed
	-- a crash in this think (before it, this think issued no orders at all for most bots); the
	-- same Dota build (6975) and no rune-mode change in between.
	if a.RunePickupLock() then
		return
	end
	do
		local okF, ate = pcall(a.EatForage)
		if okF and ate then
			_perfDone()
			return
		end
		local okD, dusted = pcall(a.UseDustNow)
		if okD and dusted then
			_perfDone()
			return
		end
		local okS, walking = pcall(a.WalkOutOfSnakes)
		if okS and walking then
			_perfDone()
			return
		end
	end
	-- A hero script holding for a cast it just ordered (Techies' M.A.D. plant): no item order
	-- that would replace it.
	if h ~= nil and h.MadHoldActive ~= nil then
		local okH, held = pcall(h.MadHoldActive)
		if okH and held then
			return
		end
	end
	-- Tower aggro: one attack order on an allied lane creep under the tower, never a walk.
	local okDeaggro, deaggroed = pcall(a.DeflectTowerAggro)
	if okDeaggro and deaggroed then
		return
	end
	LogHumanPing()
	pcall(a.LogStuck)
	pcall(a.LogModeFlip)
	-- A hero script can ask to keep thinking while invulnerable (Tusk inside his snowball has
	-- to launch it). Spells only, no items. The return below used to skip it entirely, so the
	-- snowball always rolled its full duration.
	if b:IsInvulnerable() and b:IsAlive() and h ~= nil and h.bThinkWhileInvulnerable then
		local x, ff = pcall(h.SkillsComplement)
		if not x then
			MatchTrace.Event(b, "error", "SkillsComplement: " .. tostring(ff))
			-- Hero spell-script errors were only in the match trace, never on the console (a
			-- Techies M.A.D. rule that never ran left no trace). First 3 distinct ones per bot.
			b._skillErrs = b._skillErrs or {}
			local key = tostring(ff)
			if not b._skillErrs[key] and (b._skillErrCount or 0) < 3 then
				b._skillErrs[key] = true
				b._skillErrCount = (b._skillErrCount or 0) + 1
				pcall(print, string.format("[OHA-ERROR] t=%.1f %s SkillsComplement: %s", DotaTime(), c, key))
			end
		end
		_perfDone()
		return
	end
	if b:IsInvulnerable() or not b:IsHero() or not b:IsAlive() or not string.find(c, "hero") or b:IsIllusion() then
		_perfDone()
		return
	end
	-- A spell or attack cancels an outpost capture. Wisdom and lotus do not care.
	-- Only while the capture is running, so a bot that gave up can still use items.
	if b:HasModifier("modifier_watch_tower_capturing") then
		_perfDone()
		return
	end
	-- Keep attack orders; only throttle expensive item/ability rescans when target is locked.
	if ShouldThrottleHeavyThink() then
		_perfDone()
		return
	end
	if not f.IsNoItemIllution(b) then
		local tItem = _perfT0 and RealTime() or nil
		bg()
		if tItem then
			MatchTrace.PerfSample("ItemUsage.bg", RealTime() - tItem)
		end
	end
	-- Last stand: a cornered hero casts the big spells its script lists in LastStandSpells
	-- ({ name, kind = "none" | "unit" | "point" }) before anything else. Running stops working
	-- under heavy slows in a crowd; the spell is worth more than one more step.
	if h ~= nil and h.LastStandSpells ~= nil and not f.IsNoAbilityIllution(b) and not f.CanNotUseAbility(b) then
		local cornered, nearest, foes = AbilityContext.IsCornered(b)
		if cornered then
			for _, spec in ipairs(h.LastStandSpells) do
				local ab = b:GetAbilityByName(spec.name)
				if ab ~= nil and not ab:IsNull() and ab:IsTrained() and not ab:IsHidden() and ab:IsFullyCastable() then
					pcall(print, string.format(
						"[OHA-CORNERED] t=%.0f %s last-stand %s",
						DotaTime(),
						(string.gsub(c, "npc_dota_hero_", "")),
						spec.name
					))
					if spec.kind == "unit" and f.IsValidHero(nearest) then
						b:Action_UseAbilityOnEntity(ab, nearest)
					elseif spec.kind == "point" and foes ~= nil and #foes > 0 then
						b:Action_UseAbilityOnLocation(ab, f.GetCenterOfUnits(foes))
					else
						b:Action_UseAbility(ab)
					end
					_perfDone()
					return
				end
			end
		end
	end
	if h ~= nil and not f.IsNoAbilityIllution(b) then
		local tSkill = _perfT0 and RealTime() or nil
		local x, ff = pcall(h.SkillsComplement)
		if tSkill then
			MatchTrace.PerfSample("SkillsComplement", RealTime() - tSkill)
		end
		if not x then
			MatchTrace.Event(b, "error", "SkillsComplement: " .. tostring(ff))
			-- Hero spell-script errors were only in the match trace, never on the console (a
			-- Techies M.A.D. rule that never ran left no trace). First 3 distinct ones per bot.
			b._skillErrs = b._skillErrs or {}
			local key = tostring(ff)
			if not b._skillErrs[key] and (b._skillErrCount or 0) < 3 then
				b._skillErrs[key] = true
				b._skillErrCount = (b._skillErrCount or 0) + 1
				pcall(print, string.format("[OHA-ERROR] t=%.1f %s SkillsComplement: %s", DotaTime(), c, key))
			end
		end
	end
	if l and not b:IsChanneling() then
		local fg = l.ShouldMantaDodge(b)
		if fg >= 0 then
			local bm = b:GetItemInSlot(fg)
			if bm then
				b:Action_UseAbility(bm)
				_perfDone()
				return
			end
		end
		local fh = l.ShouldUseSelfDispelItem(b)
		if fh >= 0 then
			local bm = b:GetItemInSlot(fh)
			if bm then
				b:Action_UseAbility(bm)
				_perfDone()
				return
			end
		end
		local fi, d9 = l.ShouldUseAllyDispelItem(b)
		if fi >= 0 and d9 then
			local bm = b:GetItemInSlot(fi)
			if bm then
				b:Action_UseAbilityOnEntity(bm, d9)
				_perfDone()
				return
			end
		end
	end
	for fj = 6, 8 do
		local fk = b:GetItemInSlot(fj)
		if fk ~= nil then
			local fl = fk:GetName()
			if fl == "item_famango" or fl == "item_great_famango" or fl == "item_greater_famango" then
				for fm = 0, 5 do
					if b:GetItemInSlot(fm) == nil then
						b:ActionImmediate_SwapItems(fj, fm)
						break
					end
				end
				break
			end
		end
	end
	_perfDone()
end
function AbilityUsageThink()
	if a.RunePickupLock() then
		return
	end
	HandleIdleBotState(b)
end
local fn = false
local fo = nil
local fp = 0
local fq = false
local fr = nil
local fs = 0
local ft = nil
local function fu(fv)
	if ft == nil then
		local x, bD = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/localization")
		ft = x and bD or false
	end
	if ft and ft.Get then
		local fw = ft.Get(fv)
		if fw and type(fw) == "table" and #fw > 0 then
			return fw[RandomInt(1, #fw)]
		end
		if fw and type(fw) == "string" then
			return fw
		end
	end
	if fv == "say_gg_lose" then
		local fx = { "gg", "ggwp", "GG" }
		return fx[RandomInt(1, #fx)]
	end
	local fx = { "ez", "gg ez", "EZ" }
	return fx[RandomInt(1, #fx)]
end
function BuybackUsageThink()
	if E() then
		return
	end
	if b.lastBuybackFrameProcessTime == nil then
		b.lastBuybackFrameProcessTime = DotaTime()
	end
	if DotaTime() > 30 and DotaTime() - b.lastBuybackFrameProcessTime < 2 then
		return
	end
	b.lastBuybackFrameProcessTime = DotaTime()
	if not b:IsIllusion() then
		aq()
	end
	if not b:IsIllusion() then
		f8()
	end
	if not fn and not b:IsIllusion() and DotaTime() > 10 * 60 then
		local ar = GetAncient(GetTeam())
		if ar ~= nil and f.GetHP(ar) < 0.2 and f.CanBeAttacked(ar) then
			local fy = f.GetNumOfAliveHeroes(false)
			if fy <= 2 then
				if fo == nil then
					fo = RandomInt(1, 5) <= 3
					fp = DotaTime() + RandomFloat(1, 5)
				end
				if fo and DotaTime() >= fp then
					b:ActionImmediate_Chat(fu("say_gg_lose"), true)
					fn = true
				end
			end
		end
	end
	if not fq and not b:IsIllusion() and DotaTime() > 10 * 60 then
		local fz = GetAncient(GetOpposingTeam())
		if fz ~= nil and f.GetHP(fz) < 0.2 and f.CanBeAttacked(fz) then
			local fy = f.GetNumOfAliveHeroes(false)
			if fy >= 3 then
				if fr == nil then
					fr = RandomInt(1, 5) <= 3
					fs = DotaTime() + RandomFloat(1, 5)
				end
				if fr and DotaTime() >= fs then
					b:ActionImmediate_Chat(fu("say_gg_win"), true)
					fq = true
				end
			end
		end
	end
end
function CourierUsageThink()
	if E() then
		return
	end
	if b.lastCourierFrameProcessTime == nil then
		b.lastCourierFrameProcessTime = DotaTime()
	end
	if DotaTime() > 30 and DotaTime() - b.lastCourierFrameProcessTime < 0.5 then
		return
	end
	b.lastCourierFrameProcessTime = DotaTime()
	if not b:IsIllusion() then
		aD()
	end
end
function AbilityLevelUpThink()
	if E() then
		return
	end
	if b.lastLevelUpFrameProcessTime == nil then
		b.lastLevelUpFrameProcessTime = DotaTime()
	end
	if DotaTime() > 30 and DotaTime() - b.lastLevelUpFrameProcessTime < 1 then
		return
	end
	b.lastLevelUpFrameProcessTime = DotaTime()
	if not b:IsIllusion() then
		K()
	end
end
function a.SetAbilityItemList(fA, fB, fC)
	m = fA
	n = fB
	o = fC
end
a.AbilityLevelUpThink = AbilityLevelUpThink
a.BuybackUsageThink = BuybackUsageThink
-- Engine entry points report their own errors. Unwrapped, an error here showed only as
-- "Script Runtime Error: error in error handling" (every bot at -89s), with no message.
-- Up to 3 per function per bot, as [OHA-ERROR].
local OHA_ERR_COUNT = {}
local function OHA_Guard(name, fn)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			local n = (OHA_ERR_COUNT[name] or 0) + 1
			OHA_ERR_COUNT[name] = n
			if n <= 3 then
				local hero = "?"
				pcall(function()
					hero = GetBot():GetUnitName()
				end)
				pcall(print, string.format("[OHA-ERROR] t=%.1f %s %s: %s", DotaTime(), hero, name, tostring(err)))
			end
		end
	end
end
ItemUsageThink = OHA_Guard("ItemUsageThink", ItemUsageThink)
AbilityUsageThink = OHA_Guard("AbilityUsageThink", AbilityUsageThink)
BuybackUsageThink = OHA_Guard("BuybackUsageThink", BuybackUsageThink)
CourierUsageThink = OHA_Guard("CourierUsageThink", CourierUsageThink)
AbilityLevelUpThink = OHA_Guard("AbilityLevelUpThink", AbilityLevelUpThink)
a.AbilityUsageThink = AbilityUsageThink
a.ItemUsageThink = ItemUsageThink
return a
