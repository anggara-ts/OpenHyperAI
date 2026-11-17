-- Bot name lists. defaultPostfix is the OHA-DEV tag on bot names.
if GetScriptDirectory == nil then
	GetScriptDirectory = function()
		return "bots"
	end
end
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local TeamNames = {}
TeamNames.defaultPostfix = "OHA-DEV"
TeamNames.maxTeamSize = 12
local teamList = {
	{ name = "XG", players = { "Ame", "Xm", "Xxs", "XinQ", "xNova" } },
	{ name = "PARI", players = { "Satanic", "No[o]ne-", "DM", "9Class", "Dukalis" } },
	{ name = "FLCN", players = { "ATF", "Malr1ne", "skiter", "Sneyking", "Cr1t-" } },
	{ name = "LQD", players = { "miCKe", "Nisha", "zai", "Boxi", "Insania" } },
	{ name = "GG", players = { "dyrachyo", "Quinn", "Ace", "tOfu", "Seleri" } },
	{ name = "TUND", players = { "Skiter", "Nine", "33", "Sneyking", "Aui_2000" } },
	{ name = "EG", players = { "Pakazs", "Chris Luck", "Wisper", "Matthew", "Panda" } },
	{ name = "LGD", players = { "shiro", "NTS", "niu", "planet", "y`" } },
	{ name = "SR", players = { "Arteezy", "Abed", "SaberL", "Cr1t-", "Fly" } },
	{ name = "TLN", players = { "23savage", "Mikoto", "Jabz", "Q", "Oli" } },
	{ name = "BC", players = { "K1", "C.Luck", "Wisper", "Stinger", "Scofield" } },
	{ name = "TS", players = { "Yatoro", "Larl", "Collapse", "Mira", "Miposhka" } },
	{ name = "TSM", players = { "Timado", "Bryle", "Kasane", "Ari", "Whitemon" } },
	{ name = "BB", players = { "Nightfall", "gpk", "Pure", "Save-", "TTT" } },
	{ name = "EXE", players = { "Palos", "Bob", "Tino", "Shanks", "Carlo" } },
	{ name = "QUEST", players = { "TA2000", "No!ob", "Tobi", "OmaR", "kaori" } },
	{ name = "NOUNS", players = { "Gunnar", "Costabile", "Moo", "ZFreek", "Husky" } },
	{ name = "BLEED", players = { "JaCkky", "Kordan", "ice3", "DJ", "DuBu" } },
	{ name = "AST", players = { "Monet", "Xxs", "Ori", "BoBoKa", "LaNm" } },
	{ name = "IG", players = { "flyfly", "Emo", "JT-", "Kaka", "Oli" } },
	{ name = "AR", players = { "Eurus", "Somnus", "Yang", "Fy", "xNova" } },
	{ name = "BLK", players = { "Raven", "Karl", "Kuku", "TIMS", "Eyyou" } },
	{ name = "9P", players = { "RAMZES", "kiyotaka", "MieRo", "Antares", "Solo" } },
	{ name = "SMG", players = { "MidOne", "Moon", "Masaros", "Ahfu", "RPotato" } },
	{ name = "KEYD", players = { "4dr", "Tavo", "hFn", "KJ", "mini" } },
	{ name = "TG", players = { "watson", "Quinn", "Ace", "tOfu", "Malady" } },
	{ name = "TA", players = { "shiro", "NothingToSay", "Bach", "planet", "y`" } },
	{
		name = "ADD",
		players = {
			"Azazel",
			"Lucifer",
			"Belial",
			"Lilith",
			"Diablo",
			"Mephisto",
			"Samael",
			"Abaddon",
			"Mammon",
			"Astaroth",
			"Moloch",
			"Apollyon",
			"Zagan",
			"Nyx",
			"Malphas",
			"Inferno",
			"Darkfire",
			"Shadow",
			"Nightmare",
			"Doom",
			"Soul",
			"Death",
			"Light",
			"Seraph",
			"Radiant",
			"Divine",
			"Angel",
		},
	},
}
local chineseTeamList = {
	{
		name = "阴司",
		players = { "钟馗", "阎罗", "孟婆", "判官", "黑无常", "白无常", "牛头", "马面" },
	},
	{ name = "天宫", players = { "哪吒", "杨戬", "雷震", "李靖", "巨灵", "托塔", "哮天", "哪父" } },
	{
		name = "妖魔",
		players = { "饕餮", "穷奇", "梼杌", "混沌", "九婴", "无支祁", "相柳", "猰貐" },
	},
	{ name = "水神", players = { "河伯", "海若", "风伯", "雨师", "水德", "洛神", "共工", "玄冥" } },
	{ name = "火雷", players = { "祝融", "火神", "雷公", "电母", "赤焰", "炎帝", "火德", "金乌" } },
	{ name = "英魂", players = { "刑天", "后羿", "夸父", "精卫", "黄帝", "炎帝", "神农", "蚩尤" } },
	{ name = "灵兽", players = { "青龙", "白虎", "朱雀", "玄武", "腾蛇" } },
	{ name = "封神", players = { "姜子牙", "哪吒", "杨戬", "雷震子", "托塔天王" } },
	{ name = "天罡", players = { "天勇", "天雄", "天猛", "天伤", "天英" } },
	{ name = "地煞", players = { "地勇", "地煞", "地俊", "地雄", "地恶" } },
	{ name = "山海", players = { "夸父", "共工", "精卫", "女娲", "伏羲" } },
	{ name = "异兽", players = { "饕餮", "烛龙", "穷奇", "梼杌", "狻猊" } },
	{ name = "天象", players = { "雷公", "电母", "风伯", "雨师", "云华" } },
	{
		name = "上古",
		players = {
			"蚩尤",
			"黄帝",
			"炎帝",
			"盘古",
			"女娲",
			"伏羲",
			"神农",
			"祝融",
			"共工",
			"刑天",
			"夸父",
			"后羿",
			"嫦娥",
			"西王母",
			"东皇太一",
			"玄冥",
			"羲和",
			"强良",
			"句芒",
			"应龙",
		},
	},
}
teamList = RandomInt(1, 2) >= 2 and chineseTeamList or teamList
local function buildTeamNames(customNames, customTeamName)
	local names = {}
	local customPlayerNames = {}
	local teamIndex = 0
	repeat
		teamIndex = RandomInt(1, #teamList)
	until teamIndex % 2 == GetTeam() - 2 and (teamList[teamIndex].name ~= "ADD" or teamList[teamIndex].name ~= "上古")
	names = Utils.MergeLists(teamList[teamIndex].players, teamList[#teamList].players)
	if customNames and #customNames > 0 then
		for slot = 1, #customNames do
			if customNames[slot] and customNames[slot] ~= "Random" then
				names[slot] = customNames[slot]
				table.insert(customPlayerNames, customNames[slot])
			end
		end
	end
	local showTeamNames = CustomLoader.Enable and CustomLoader.Show_Team_Names
	local teamName = customTeamName and customTeamName ~= "" and customTeamName or teamList[teamIndex].name
	local botNames = {}
	for _ = 1, TeamNames.maxTeamSize do
		local playerName = table.remove(names, 1)
		if Utils.HasValue(customPlayerNames, playerName) then
			table.insert(botNames, playerName)
		elseif showTeamNames then
			table.insert(botNames, teamName .. "." .. playerName .. "." .. TeamNames.defaultPostfix)
		else
			table.insert(botNames, playerName .. "." .. TeamNames.defaultPostfix)
		end
	end
	return botNames
end
function TeamNames.generateTeams(customNames)
	local radiantNames = customNames and customNames.Radiant or {}
	local direNames = customNames and customNames.Dire or {}
	local radiantTeamName = CustomLoader.Enable and CustomLoader.Radiant_Team_Name or nil
	local direTeamName = CustomLoader.Enable and CustomLoader.Dire_Team_Name or nil
	local radiantBotNames = buildTeamNames(radiantNames, radiantTeamName)
	local direBotNames = buildTeamNames(direNames, direTeamName)
	return { Radiant = radiantBotNames, Dire = direBotNames }
end
return TeamNames
