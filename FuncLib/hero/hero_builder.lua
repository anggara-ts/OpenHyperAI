-- Hero-specific helper: hero builder.
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local defaultTalentTree = { t25 = { 0, 10 }, t20 = { 10, 0 }, t15 = { 0, 10 }, t10 = { 10, 0 } }
function X.buildHeroConfig(bot, heroConfig)
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	local sRole = Item.GetRoleItemsBuyList(bot)
	local sAbilityList = Fu.Skill.GetAbilityList(bot)
	local sTalentList = Fu.Skill.GetTalentList(bot)
	local defaultSkillBuild = {}
	local skillBuilds = heroConfig.skills or {}
	if skillBuilds.default then
		defaultSkillBuild = skillBuilds.default
	else
		for roleKey in pairs(skillBuilds) do
			if roleKey ~= "default" then
				defaultSkillBuild = skillBuilds[roleKey]
				break
			end
		end
	end
	local nAbilityBuildList = skillBuilds[sRole] or defaultSkillBuild
	local talentTrees = heroConfig.talents or {}
	local tTalentTreeList = talentTrees[sRole] or talentTrees.default or defaultTalentTree
	local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
	local defaultItemBuild = {}
	local itemBuilds = heroConfig.items or {}
	if itemBuilds.default then
		defaultItemBuild = itemBuilds.default
	else
		for roleKey in pairs(itemBuilds) do
			if roleKey ~= "default" then
				defaultItemBuild = itemBuilds[roleKey]
				break
			end
		end
	end
	local sRoleItemsBuyList = itemBuilds[sRole] or defaultItemBuild
	local sSkillList = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
	return { role = sRole, skillBuild = sSkillList, itemBuild = sRoleItemsBuyList, sellList = heroConfig.sell or {} }
end
function X.buildHeroExport(heroConfig, skillsComplement, minionThink)
	return { sSkillList = heroConfig.skillBuild, sBuyList = heroConfig.itemBuild, sSellList = heroConfig.sellList, SkillsComplement = skillsComplement, MinionThink = minionThink }
end
return X
