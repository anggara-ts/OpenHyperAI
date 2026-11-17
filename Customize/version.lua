-- Custom build version.
-- A git clone has Customize/build_info.lua (git-ignored, written by Util/build-info.js from the git hooks):
-- the number is then "<commit date YYYY.MM.DD>-<short sha>", plus "+dirty" when tracked files other than
-- Customize/general.lua had local changes. Without it (Workshop copies) the static release number below is used.
-- Release format: YYYY.MM.DD-NNN.
local Version = {
	number = "2026.11.17-148",
}

local infoOk, info = pcall(require, GetScriptDirectory() .. "/Customize/build_info")
if infoOk and type(info) == "table" and type(info.version) == "string" then
	Version.number = info.version .. (info.dirty and "+dirty" or "")
	Version.commit = info.commit
	Version.branch = info.branch
	Version.dirty = info.dirty == true
end

return Version
