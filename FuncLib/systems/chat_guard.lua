-- Repeated bot chat (issue #56). Every chat line a bot sends also prints one console line
-- "CLocalize::FindSafe failed to localize: '<text>'" (the client tries the text as a token first).
-- Game 062: 212 such lines, "Please come defending" alone 32 times, often 3-4s apart (the defend
-- ping repeats every 6s per team). A team now says the same text at most once per REPEAT_WINDOW.
-- The ~590 "failed to localize: 'invalid index'" lines are not chat: they come from the spectator
-- UI and keep printing after the bot scripts stop (issue #56 comments).
local ChatGuard = {}

ChatGuard.REPEAT_WINDOW = 30 -- seconds before a team may repeat the same chat text

-- Pure rule: may `key` (team .. text) be said at `now`? Records the time when it may.
-- `state` maps key -> last time said.
function ChatGuard.Allow(state, key, now, window)
	window = window or ChatGuard.REPEAT_WINDOW
	local last = state[key]
	if last ~= nil and now - last < window and now >= last then
		return false, now - last
	end
	state[key] = now
	return true, nil
end

return ChatGuard
