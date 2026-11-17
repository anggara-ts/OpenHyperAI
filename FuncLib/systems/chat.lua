-- Shared bot system: chat.
local Chat = {}
local sNameField = "sRawName"
local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
Chat["tItemNameList"] = require(GetScriptDirectory() .. "/FuncLib/data/item_names")
Chat["tHeroNameList"] = require(GetScriptDirectory() .. "/FuncLib/data/hero_names")
local itemCnNames = {}
for _, itemInfo in pairs(Chat["tItemNameList"]) do
	itemCnNames[itemInfo["sRawName"]] = itemInfo["sCnName"]
end
function Chat.GetItemCnName(itemName)
	return itemCnNames[itemName] or "未定义:" .. itemName
end
function Chat.GetLocalName(hero)
	local heroInfo = Chat["tHeroNameList"][hero:GetUnitName()]
	if heroInfo ~= nil then
		return heroInfo[sNameField]
	end
end
function Chat.GetNormName(hero)
	local heroInfo = Chat["tHeroNameList"][hero:GetUnitName()]
	return heroInfo ~= nil and heroInfo["sNormName"] or string.sub(hero:GetUnitName(), 10)
end
local chatTable = require(GetScriptDirectory() .. "/FuncLib/data/chat_table")
local keywordToIndex = {}
for index = 1, #chatTable do
	local keywords = chatTable[index][1]
	for _, keyword in pairs(keywords) do
		local existingIndex = keywordToIndex[keyword]
		if existingIndex == nil then
			keywordToIndex[keyword] = index
		else
			for _, line in pairs(chatTable[index][2]) do
				table.insert(chatTable[existingIndex][2], line)
			end
			for _, line in pairs(chatTable[index][3]) do
				table.insert(chatTable[existingIndex][3], line)
			end
		end
	end
end
function Chat.GetChatStringTableIndex(message)
	return keywordToIndex[message] or -1
end
function Chat.GetChatTableString(index, isAllChat)
	local replies = chatTable[index][isAllChat and 3 or 2]
	return replies[RandomInt(1, #replies)]
end
function Chat.GetReplyString(message, isAllChat)
	if not Chat.AllowTrashTalk(isAllChat) then
		return nil
	end
	local reply = nil
	if CustomLoader.Localization == "zh" then
		local index = Chat.GetChatStringTableIndex(message)
		if index ~= -1 then
			reply = Chat.GetChatTableString(index, isAllChat)
		else
			reply = Chat.GetCheaterReplyString(message)
			if reply == nil then
				reply = Chat.GetRepeatString(message)
			end
		end
	end
	if reply == nil or RandomInt(1, 100) > 90 then
		local randomResponses = Localization.Get("random_responses")
		reply = randomResponses[RandomInt(1, #randomResponses)]
	end
	return reply
end
function Chat.AllowTrashTalk(isAllChat)
	local trashTalkLevel = CustomLoader.Trash_Talk_Level
	return CustomLoader.Allow_Trash_Talk and (not isAllChat and (trashTalkLevel == nil or trashTalkLevel >= 2) or isAllChat and (trashTalkLevel == nil or trashTalkLevel >= 1))
end
function Chat.GetCheaterReplyString(message)
	return string.byte(message, 1) == string.byte("-", 1) and "cheater" or nil
end
function Chat.GetRepeatString(message)
	local skipWords = { "你们", "你", "我", "吗？", "吗", "吧", "？" }
	for _, word in ipairs(skipWords) do
		if message == word then
			return nil
		end
	end
	local originalMessage = message
	if message:find("我是你") then
		return message:gsub("我是你", "我才是你")
	end
	local insultWords = { "sb", "SB", "智障", "弱智", "脑残", "脑瘫", "猪", "傻", "菜", "笨", "蠢" }
	for _, word in ipairs(insultWords) do
		if message:find(word) then
			return Chat.GetReplyTauntString()
		end
	end
	local endings = { "呀", "哦", "呀！", "哦！", "！", "" }
	local ending = endings[RandomInt(1, #endings)]
	message = string.gsub(message, "你们", "")
	message = string.gsub(message, "你", "")
	message = string.gsub(message, "吗？", ending)
	message = string.gsub(message, "吗", ending)
	message = string.gsub(message, "吧", "啊")
	message = string.gsub(message, "？", "！")
	message = string.gsub(message, "?", "!")
	message = string.gsub(message, "我", "你")
	return message ~= originalMessage and message or nil
end
local tauntReplies = {
	"你是在说你自己吗?",
	"你就只会说这个而已吗?",
	"我不允许你这么说你自己!",
	"别这么说你自己, 小伙汁.",
	"其实你不用这么来说你自己的.",
	"原来你自己就是酱紫的呀.",
	"自信点, 别这么说你自己.",
	"放松点, 就你这样没事的.",
	"反弹biubiubiu.",
	"给爷爬~~~",
}
function Chat.GetReplyTauntString()
	return tauntReplies[RandomInt(1, #tauntReplies)]
end
function Chat.GetStopReplyString()
	local noMoreTalking = Localization.Get("no_more_talking")
	return noMoreTalking[RandomInt(1, #noMoreTalking)]
end
return Chat
