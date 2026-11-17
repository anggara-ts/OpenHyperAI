-- Thinking for summoned units: jugg.
local X = {}
local ancient = GetAncient(GetTeam())
local ancientLocation = nil
if ancient ~= nil then
	ancientLocation = ancient:GetLocation()
end
function X.HealingWardThink(healingWard)
	local nearbyEnemies = healingWard:GetNearbyHeroes(1200, true, BOT_MODE_DESIRE_NONE)
	local moveLocation = nil
	local weakestAlly = nil
	local lowestHpRatio = 0.99
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local teamMember = GetTeamMember(i)
		if teamMember ~= nil and teamMember:IsAlive() and GetUnitToUnitDistance(teamMember, healingWard) <= 1200 then
			local memberHpRatio = teamMember:GetHealth() / teamMember:GetMaxHealth()
			if memberHpRatio < lowestHpRatio then
				lowestHpRatio = memberHpRatio
				weakestAlly = teamMember
			end
		end
	end
	if #nearbyEnemies == 0 then
		local allyHeroAoe = healingWard:FindAoELocation(false, true, healingWard:GetLocation(), 1000, 400, 0, 0)
		if allyHeroAoe.count >= 2 then
			moveLocation = allyHeroAoe.targetloc
		end
		if moveLocation == nil then
			if weakestAlly ~= nil then
				moveLocation = weakestAlly:GetLocation()
			end
		end
		if moveLocation == nil then
			local allyCreepAoe = healingWard:FindAoELocation(false, false, healingWard:GetLocation(), 800, 400, 0, 0)
			if allyCreepAoe.count >= 1 then
				moveLocation = allyCreepAoe.targetloc
			end
		end
	else
		if weakestAlly ~= nil then
			moveLocation = weakestAlly:GetLocation()
		end
	end
	if moveLocation ~= nil then
		if moveLocation == GetBot():GetLocation() then
			return
		else
			healingWard:Action_MoveToLocation(moveLocation)
		end
	else
		healingWard:Action_MoveToLocation(ancientLocation)
	end
end
return X
