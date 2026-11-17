-- Fretbots plugin settings (moved out of Customize/general.lua when Fretbots became a plugin).
-- The installer copies this file to <dota>/game/dota/scripts/vscripts/game/Customize/fretbots.lua;
-- edit that copy, it wins over the one in the bots folder.
-- For more about Fretbots mode: https://github.com/forest0xia/dota2bot-OpenHyperAI/discussions/68
local Fretbots = {
	-- Default difficulty, a number between: [0, 10]. Used when nobody votes.
	-- 0 is the lightest: almost no extra gold or XP, and no bonuses when a bot dies.
	-- 1 is a small edge. 2 pushes a carry toward roughly 300 GPM and feels heavy.
	-- 5 is about 1.2x the bonus and 10 is 2x. A chat vote still overrides this.
	Default_Difficulty = 1,

	-- Default ally bots bonus scale comparing to enemy bots, a number between: [0, 1]
	Default_Ally_Scale = 0.5,

	-- Set whether or not allowing the team to vote for difficulty. If false, will directly apply the default difficulty.
	Allow_To_Vote = true,

	-- Set to false disables all sounds from Fretbots mode
	Play_Sounds = true,

	-- Set to play chatwheel taunt sounds when human player died
	Player_Death_Sound = true,
}

return Fretbots
