-- Support library: http_req.
local function createClass(self)
	local class = { prototype = {} }
	class.prototype.__index = class.prototype
	class.prototype.constructor = class
	return class
end
local Module = {}
local Json = require(GetScriptDirectory() .. "/FuncLib/lib/json")
Module.Request = createClass()
local Request = Module.Request
Request.name = "Request"
function Request.prototype.____constructor(self) end
function Request.HttpPost(self, body, endpoint, callback)
	if self.UUID ~= nil then
		return Module.Request:RawPostRequest((Module.Request.BASE_URL .. "/") .. endpoint, callback, body)
	else
		return self:GetUUID(callback)
	end
end
function Request.GetUUID(self, callback)
	return Module.Request:RawPostRequest(Module.Request.BASE_URL .. "/uuid", callback)
end
function Request.RawPostRequest(self, url, callback, body)
	local encodedBody = Json.encode(body)
	local request = CreateRemoteHTTPRequest(url)
	request:SetHTTPRequestRawPostBody("application/json", encodedBody)
	request:Send(function(response)
		log("Raw %s Result: %s", url, response)
		local decoded = Json.decode(response)
		log("Jsonified result: %s", decoded)
		if callback then
			callback(response)
		end
	end)
	return request
end
function Request.RawGetRequest(self, url, callback)
	local request = CreateRemoteHTTPRequest(url)
	request:Send(function(response)
		log("Raw %s Result: %s", url, response)
		if callback then
			callback(response)
		end
	end)
	return request
end
Request.UUID = nil
Request.BASE_URL = "http://127.0.0.1:5000/"
return Module
