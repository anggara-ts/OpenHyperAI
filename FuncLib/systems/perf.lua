-- Shared bot system: [OHA-PERF] timing of our engine entry points (#52).
-- Game 040, 29:33-30:30: the server tick took 115-145ms (~8 FPS) for 30s during and after a big fight, but the
-- engine only prints "Script function ... took Nms" above its own threshold, so small calls that add up were
-- invisible. Perf.Wrap times a function with RealTime(); every 10s, a bot whose total is over the budget prints
-- its total and top 3 functions. Quiet in normal play.
local Perf = {}
local WINDOW = 10 -- seconds of game time per report
local BUDGET = 0.020 -- seconds of our code per second of game time, per bot, before it prints

local function Record(name, seconds)
	local bot = GetBot()
	if bot == nil then
		return
	end
	local perf = bot._perf
	local now = DotaTime()
	if perf == nil then
		perf = { since = now, total = 0, sum = {}, calls = 0 }
		bot._perf = perf
	end
	perf.total = perf.total + seconds
	perf.calls = perf.calls + 1
	perf.sum[name] = (perf.sum[name] or 0) + seconds
	local span = now - perf.since
	if span < WINDOW then
		return
	end
	if perf.total / span > BUDGET then
		local names = {}
		for key, value in pairs(perf.sum) do
			names[#names + 1] = { key, value }
		end
		table.sort(names, function(a, b)
			return a[2] > b[2]
		end)
		local top = {}
		for i = 1, math.min(3, #names) do
			top[#top + 1] = string.format("%s=%.0fms", names[i][1], names[i][2] * 1000)
		end
		pcall(
			print,
			string.format(
				"[OHA-PERF] t=%.0f %s ms/s=%.1f calls=%d window=%.0fs top=%s",
				now,
				(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
				perf.total / span * 1000,
				perf.calls,
				span,
				table.concat(top, ",")
			)
		)
	end
	bot._perf = { since = now, total = 0, sum = {}, calls = 0 }
end

local function Finish(name, startedAt, ...)
	Record(name, RealTime() - startedAt)
	return ...
end

-- Returns fn wrapped with timing (fn unchanged when nil or when RealTime is missing).
function Perf.Wrap(name, fn)
	if type(fn) ~= "function" or RealTime == nil then
		return fn
	end
	return function(...)
		return Finish(name, RealTime(), fn(...))
	end
end

return Perf
