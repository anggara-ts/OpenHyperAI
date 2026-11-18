-- Shared bot system: small notes the whole team shares (e.g. when it last used a Smoke).
-- Every bot runs in one Lua state and `require` caches this module once, so all bots see the same table. Bots
-- of both teams can share it too, so every value is kept per team.
local TeamMemory = { byTeam = {} }

function TeamMemory.Get(team, key)
	local notes = TeamMemory.byTeam[team]
	return notes and notes[key]
end

function TeamMemory.Set(team, key, value)
	TeamMemory.byTeam[team] = TeamMemory.byTeam[team] or {}
	TeamMemory.byTeam[team][key] = value
end

return TeamMemory
