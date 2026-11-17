-- Support library: json.
local alwaysTryUsingLpeg = false
local registerGlobalModuleTable = false
local globalModuleName = "json"
local pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset =
	pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset
local error, require, pcall, select = error, require, pcall, select
local floor, huge = math.floor, math.huge
local strrep, gsub, strsub, strbyte, strchar, strfind, strlen, strformat =
	string.rep, string.gsub, string.sub, string.byte, string.char, string.find, string.len, string.format
local strmatch = string.match
local concat = table.concat
local json = { version = "dkjson 2.5.1 - removed lpeg" }
if registerGlobalModuleTable then
	_G[globalModuleName] = json
end
local envBlocker = nil
pcall(function()
	local debugGetmetatable = require("debug").getmetatable
	if debugGetmetatable then
		getmetatable = debugGetmetatable
	end
end)
json.null = setmetatable({}, {
	__tojson = function()
		return "null"
	end,
})
local function isArray(tbl)
	local maxIndex, count, arrayLength = 0, 0, 0
	for key, value in pairs(tbl) do
		if key == "n" and type(value) == "number" then
			arrayLength = value
			if value > maxIndex then
				maxIndex = value
			end
		else
			if type(key) ~= "number" or key < 1 or floor(key) ~= key then
				return false
			end
			if key > maxIndex then
				maxIndex = key
			end
			count = count + 1
		end
	end
	if maxIndex > 10 and maxIndex > arrayLength and maxIndex > count * 2 then
		return false
	end
	return true, maxIndex
end
local escapeCodes =
	{ ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function escapeUtf8(char)
	local codePoint = escapeCodes[char]
	if codePoint then
		return codePoint
	end
	local byte1, byte2, byte3, byte4 = strbyte(char, 1, 4)
	byte1, byte2, byte3, byte4 = byte1 or 0, byte2 or 0, byte3 or 0, byte4 or 0
	if byte1 <= 0x7f then
		codePoint = byte1
	elseif 0xc0 <= byte1 and byte1 <= 0xdf and byte2 >= 0x80 then
		codePoint = (byte1 - 0xc0) * 0x40 + byte2 - 0x80
	elseif 0xe0 <= byte1 and byte1 <= 0xef and byte2 >= 0x80 and byte3 >= 0x80 then
		codePoint = ((byte1 - 0xe0) * 0x40 + byte2 - 0x80) * 0x40 + byte3 - 0x80
	elseif 0xf0 <= byte1 and byte1 <= 0xf7 and byte2 >= 0x80 and byte3 >= 0x80 and byte4 >= 0x80 then
		codePoint = (((byte1 - 0xf0) * 0x40 + byte2 - 0x80) * 0x40 + byte3 - 0x80) * 0x40 + byte4 - 0x80
	else
		return ""
	end
	if codePoint <= 0xffff then
		return strformat("\\u%.4x", codePoint)
	elseif codePoint <= 0x10ffff then
		codePoint = codePoint - 0x10000
		local highSurrogate, lowSurrogate = 0xD800 + floor(codePoint / 0x400), 0xDC00 + codePoint % 0x400
		return strformat("\\u%.4x\\u%.4x", highSurrogate, lowSurrogate)
	else
		return ""
	end
end
local function fsub(str, pattern, replacement)
	if strfind(str, pattern) then
		return gsub(str, pattern, replacement)
	else
		return str
	end
end
local function quoteString(value)
	value = fsub(value, '[%z\1-\31"\\\127]', escapeUtf8)
	if strfind(value, "[\194\216\220\225\226\239]") then
		value = fsub(value, "\194[\128-\159\173]", escapeUtf8)
		value = fsub(value, "\216[\128-\132]", escapeUtf8)
		value = fsub(value, "\220\143", escapeUtf8)
		value = fsub(value, "\225\158[\180\181]", escapeUtf8)
		value = fsub(value, "\226\128[\140-\143\168-\175]", escapeUtf8)
		value = fsub(value, "\226\129[\160-\175]", escapeUtf8)
		value = fsub(value, "\239\187\191", escapeUtf8)
		value = fsub(value, "\239\191[\176-\191]", escapeUtf8)
	end
	return '"' .. value .. '"'
end
json.quotestring = quoteString
local function replace(str, search, replacement)
	local startPos, endPos = strfind(str, search, 1, true)
	if startPos then
		return strsub(str, 1, startPos - 1) .. replacement .. strsub(str, endPos + 1, -1)
	else
		return str
	end
end
local decimalPoint, numberFilter
local function updateDecimalPoint()
	decimalPoint = strmatch(tostring(0.5), "([^05+])")
	numberFilter = "[^0-9%-%+eE" .. gsub(decimalPoint, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "]+"
end
updateDecimalPoint()
local function numberToString(number)
	return replace(fsub(tostring(number), numberFilter, ""), decimalPoint, ".")
end
local function stringToNumber(str)
	local number = tonumber(replace(str, ".", decimalPoint))
	if not number then
		updateDecimalPoint()
		number = tonumber(replace(str, ".", decimalPoint))
	end
	return number
end
local function addNewline2(level, buffer, bufferLength)
	buffer[bufferLength + 1] = "\n"
	buffer[bufferLength + 2] = strrep("  ", level)
	bufferLength = bufferLength + 2
	return bufferLength
end
function json.addnewline(state)
	if state.indent then
		state.bufferlen = addNewline2(state.level or 0, state.buffer, state.bufferlen or #state.buffer)
	end
end
local encode2
local function addPair(key, value, prev, indent, level, buffer, bufferLength, tables, globalOrder, state)
	local keyType = type(key)
	if keyType ~= "string" and keyType ~= "number" then
		return nil, "type '" .. keyType .. "' is not supported as a key by JSON."
	end
	if prev then
		bufferLength = bufferLength + 1
		buffer[bufferLength] = ","
	end
	if indent then
		bufferLength = addNewline2(level, buffer, bufferLength)
	end
	buffer[bufferLength + 1] = quoteString(key)
	buffer[bufferLength + 2] = ":"
	return encode2(value, indent, level, buffer, bufferLength + 2, tables, globalOrder, state)
end
local function appendCustom(result, buffer, state)
	local bufferLength = state.bufferlen
	if type(result) == "string" then
		bufferLength = bufferLength + 1
		buffer[bufferLength] = result
	end
	return bufferLength
end
local function exception(reason, value, state, buffer, bufferLength, defaultMessage)
	defaultMessage = defaultMessage or reason
	local handler = state.exception
	if not handler then
		return nil, defaultMessage
	else
		state.bufferlen = bufferLength
		local result, message = handler(reason, value, state, defaultMessage)
		if not result then
			return nil, message or defaultMessage
		end
		return appendCustom(result, buffer, state)
	end
end
function json.encodeexception(reason, value, state, defaultMessage)
	return quoteString("<" .. defaultMessage .. ">")
end
encode2 = function(value, indent, level, buffer, bufferLength, tables, globalOrder, state)
	local valueType = type(value)
	local valueMeta = getmetatable(value)
	valueMeta = type(valueMeta) == "table" and valueMeta
	local valueToJson = valueMeta and valueMeta.__tojson
	if valueToJson then
		if tables[value] then
			return exception("reference cycle", value, state, buffer, bufferLength)
		end
		tables[value] = true
		state.bufferlen = bufferLength
		local result, message = valueToJson(value, state)
		if not result then
			return exception("custom encoder failed", value, state, buffer, bufferLength, message)
		end
		tables[value] = nil
		bufferLength = appendCustom(result, buffer, state)
	elseif value == nil then
		bufferLength = bufferLength + 1
		buffer[bufferLength] = "null"
	elseif valueType == "number" then
		local numberText
		if value ~= value or value >= huge or -value >= huge then
			numberText = "null"
		else
			numberText = numberToString(value)
		end
		bufferLength = bufferLength + 1
		buffer[bufferLength] = numberText
	elseif valueType == "boolean" then
		bufferLength = bufferLength + 1
		buffer[bufferLength] = value and "true" or "false"
	elseif valueType == "string" then
		bufferLength = bufferLength + 1
		buffer[bufferLength] = quoteString(value)
	elseif valueType == "table" then
		if tables[value] then
			return exception("reference cycle", value, state, buffer, bufferLength)
		end
		tables[value] = true
		level = level + 1
		local isArrayTable, count = isArray(value)
		if count == 0 and valueMeta and valueMeta.__jsontype == "object" then
			isArrayTable = false
		end
		local message
		if isArrayTable then
			bufferLength = bufferLength + 1
			buffer[bufferLength] = "["
			for i = 1, count do
				bufferLength, message =
					encode2(value[i], indent, level, buffer, bufferLength, tables, globalOrder, state)
				if not bufferLength then
					return nil, message
				end
				if i < count then
					bufferLength = bufferLength + 1
					buffer[bufferLength] = ","
				end
			end
			bufferLength = bufferLength + 1
			buffer[bufferLength] = "]"
		else
			local prev = false
			bufferLength = bufferLength + 1
			buffer[bufferLength] = "{"
			local order = valueMeta and valueMeta.__jsonorder or globalOrder
			if order then
				local used = {}
				count = #order
				for i = 1, count do
					local key = order[i]
					local entryValue = value[key]
					if entryValue then
						used[key] = true
						bufferLength, message = addPair(
							key,
							entryValue,
							prev,
							indent,
							level,
							buffer,
							bufferLength,
							tables,
							globalOrder,
							state
						)
						prev = true
					end
				end
				for key, entryValue in pairs(value) do
					if not used[key] then
						bufferLength, message = addPair(
							key,
							entryValue,
							prev,
							indent,
							level,
							buffer,
							bufferLength,
							tables,
							globalOrder,
							state
						)
						if not bufferLength then
							return nil, message
						end
						prev = true
					end
				end
			else
				for key, entryValue in pairs(value) do
					bufferLength, message =
						addPair(key, entryValue, prev, indent, level, buffer, bufferLength, tables, globalOrder, state)
					if not bufferLength then
						return nil, message
					end
					prev = true
				end
			end
			if indent then
				bufferLength = addNewline2(level - 1, buffer, bufferLength)
			end
			bufferLength = bufferLength + 1
			buffer[bufferLength] = "}"
		end
		tables[value] = nil
	else
		return exception(
			"unsupported type",
			value,
			state,
			buffer,
			bufferLength,
			"type '" .. valueType .. "' is not supported by JSON."
		)
	end
	return bufferLength
end
function json.encode(value, state)
	state = state or {}
	local oldBuffer = state.buffer
	local buffer = oldBuffer or {}
	state.buffer = buffer
	updateDecimalPoint()
	local result, message = encode2(
		value,
		state.indent,
		state.level or 0,
		buffer,
		state.bufferlen or 0,
		state.tables or {},
		state.keyorder,
		state
	)
	if not result then
		error(message, 2)
	elseif oldBuffer == buffer then
		state.bufferlen = result
		return true
	else
		state.bufferlen = nil
		state.buffer = nil
		return concat(buffer)
	end
end
local function describePosition(str, where)
	local line, pos, linePos = 1, 1, 0
	while true do
		pos = strfind(str, "\n", pos, true)
		if pos and pos < where then
			line = line + 1
			linePos = pos
			pos = pos + 1
		else
			break
		end
	end
	return "line " .. line .. ", column " .. where - linePos
end
local function unterminated(str, what, where)
	return nil, strlen(str) + 1, "unterminated " .. what .. " at " .. describePosition(str, where)
end
local function scanWhite(str, pos)
	while true do
		pos = strfind(str, "%S", pos)
		if not pos then
			return nil
		end
		local twoChars = strsub(str, pos, pos + 1)
		if twoChars == "\239\187" and strsub(str, pos + 2, pos + 2) == "\191" then
			pos = pos + 3
		elseif twoChars == "//" then
			pos = strfind(str, "[\n\r]", pos + 2)
			if not pos then
				return nil
			end
		elseif twoChars == "/*" then
			pos = strfind(str, "*/", pos + 2)
			if not pos then
				return nil
			end
			pos = pos + 2
		else
			return pos
		end
	end
end
local escapeChars =
	{ ['"'] = '"', ["\\"] = "\\", ["/"] = "/", ["b"] = "\b", ["f"] = "\f", ["n"] = "\n", ["r"] = "\r", ["t"] = "\t" }
local function unicodeChar(codePoint)
	if codePoint < 0 then
		return nil
	elseif codePoint <= 0x007f then
		return strchar(codePoint)
	elseif codePoint <= 0x07ff then
		return strchar(0xc0 + floor(codePoint / 0x40), 0x80 + floor(codePoint) % 0x40)
	elseif codePoint <= 0xffff then
		return strchar(
			0xe0 + floor(codePoint / 0x1000),
			0x80 + floor(codePoint / 0x40) % 0x40,
			0x80 + floor(codePoint) % 0x40
		)
	elseif codePoint <= 0x10ffff then
		return strchar(
			0xf0 + floor(codePoint / 0x40000),
			0x80 + floor(codePoint / 0x1000) % 0x40,
			0x80 + floor(codePoint / 0x40) % 0x40,
			0x80 + floor(codePoint) % 0x40
		)
	else
		return nil
	end
end
local function scanString(str, pos)
	local lastPos = pos + 1
	local buffer, count = {}, 0
	while true do
		local nextPos = strfind(str, '["\\]', lastPos)
		if not nextPos then
			return unterminated(str, "string", pos)
		end
		if nextPos > lastPos then
			count = count + 1
			buffer[count] = strsub(str, lastPos, nextPos - 1)
		end
		if strsub(str, nextPos, nextPos) == '"' then
			lastPos = nextPos + 1
			break
		else
			local escapeChar = strsub(str, nextPos + 1, nextPos + 1)
			local value
			if escapeChar == "u" then
				value = tonumber(strsub(str, nextPos + 2, nextPos + 5), 16)
				if value then
					local lowSurrogate
					if 0xD800 <= value and value <= 0xDBff then
						if strsub(str, nextPos + 6, nextPos + 7) == "\\u" then
							lowSurrogate = tonumber(strsub(str, nextPos + 8, nextPos + 11), 16)
							if lowSurrogate and 0xDC00 <= lowSurrogate and lowSurrogate <= 0xDFFF then
								value = (value - 0xD800) * 0x400 + lowSurrogate - 0xDC00 + 0x10000
							else
								lowSurrogate = nil
							end
						end
					end
					value = value and unicodeChar(value)
					if value then
						if lowSurrogate then
							lastPos = nextPos + 12
						else
							lastPos = nextPos + 6
						end
					end
				end
			end
			if not value then
				value = escapeChars[escapeChar] or escapeChar
				lastPos = nextPos + 2
			end
			count = count + 1
			buffer[count] = value
		end
	end
	if count == 1 then
		return buffer[1], lastPos
	elseif count > 1 then
		return concat(buffer), lastPos
	else
		return "", lastPos
	end
end
local scanValue
local function scanTable(what, closeChar, str, startPos, nullValue, objectMeta, arrayMeta)
	local length = strlen(str)
	local tbl, count = {}, 0
	local pos = startPos + 1
	if what == "object" then
		setmetatable(tbl, objectMeta)
	else
		setmetatable(tbl, arrayMeta)
	end
	while true do
		pos = scanWhite(str, pos)
		if not pos then
			return unterminated(str, what, startPos)
		end
		local char = strsub(str, pos, pos)
		if char == closeChar then
			return tbl, pos + 1
		end
		local firstValue, err
		firstValue, pos, err = scanValue(str, pos, nullValue, objectMeta, arrayMeta)
		if err then
			return nil, pos, err
		end
		pos = scanWhite(str, pos)
		if not pos then
			return unterminated(str, what, startPos)
		end
		char = strsub(str, pos, pos)
		if char == ":" then
			if firstValue == nil then
				return nil, pos, "cannot use nil as table index (at " .. describePosition(str, pos) .. ")"
			end
			pos = scanWhite(str, pos + 1)
			if not pos then
				return unterminated(str, what, startPos)
			end
			local secondValue
			secondValue, pos, err = scanValue(str, pos, nullValue, objectMeta, arrayMeta)
			if err then
				return nil, pos, err
			end
			tbl[firstValue] = secondValue
			pos = scanWhite(str, pos)
			if not pos then
				return unterminated(str, what, startPos)
			end
			char = strsub(str, pos, pos)
		else
			count = count + 1
			tbl[count] = firstValue
		end
		if char == "," then
			pos = pos + 1
		end
	end
end
scanValue = function(str, pos, nullValue, objectMeta, arrayMeta)
	pos = pos or 1
	pos = scanWhite(str, pos)
	if not pos then
		return nil, strlen(str) + 1, "no valid JSON value (reached the end)"
	end
	local char = strsub(str, pos, pos)
	if char == "{" then
		return scanTable("object", "}", str, pos, nullValue, objectMeta, arrayMeta)
	elseif char == "[" then
		return scanTable("array", "]", str, pos, nullValue, objectMeta, arrayMeta)
	elseif char == '"' then
		return scanString(str, pos)
	else
		local matchStart, matchEnd = strfind(str, "^%-?[%d%.]+[eE]?[%+%-]?%d*", pos)
		if matchStart then
			local number = stringToNumber(strsub(str, matchStart, matchEnd))
			if number then
				return number, matchEnd + 1
			end
		end
		matchStart, matchEnd = strfind(str, "^%a%w*", pos)
		if matchStart then
			local word = strsub(str, matchStart, matchEnd)
			if word == "true" then
				return true, matchEnd + 1
			elseif word == "false" then
				return false, matchEnd + 1
			elseif word == "null" then
				return nullValue, matchEnd + 1
			end
		end
		return nil, pos, "no valid JSON value at " .. describePosition(str, pos)
	end
end
local function optionalMetatables(...)
	if select("#", ...) > 0 then
		return ...
	else
		return { __jsontype = "object" }, { __jsontype = "array" }
	end
end
function json.decode(str, pos, nullValue, ...)
	local objectMeta, arrayMeta = optionalMetatables(...)
	return scanValue(str, pos, nullValue, objectMeta, arrayMeta)
end
if alwaysTryUsingLpeg then
	pcall(json.use_lpeg)
end
return json
