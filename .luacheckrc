-- luacheck settings for the Dota 2 bot scripts (run by .github/workflows/lua-check.yml).
-- The game runs LuaJIT, and the bot API puts hundreds of functions and constants in the
-- global scope (GetBot, DotaTime, BOT_MODE_*, ...), so global checks are off.
std = "luajit"
allow_defined = true
allow_defined_top = true
global = false
unused_args = false
max_line_length = false
-- 1xx globals (API), 211/212/213 unused locals/args/loop vars, 311/411/412/421/431/432
-- shadowing and overwritten values are noise in this code base. What stays: syntax errors,
-- unreachable code, empty blocks, unused values, wrong goto, etc.
ignore = { "1..", "211", "212", "213", "311", "411", "412", "421", "422", "423", "431", "432", "542" }
exclude_files = { ".git/**", "Util/**" }
