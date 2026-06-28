-------------------------------------------------------------------------------
-- DorqUtilities namespace and shared helpers.
-------------------------------------------------------------------------------

local mod = {}
local modName = "DorqUtilities"
_G[modName] = mod

local string_find = string.find
local string_gsub = string.gsub

local tocVersion = string_gsub(C_AddOns.GetAddOnMetadata(modName, "Version") or "1.0.0", "wowi:revision", 0)
mod.VERSION = tonumber(select(3, string_find(tocVersion, "(%d+%.%d+)")))
mod.VERSION_STRING = "v" .. tocVersion
mod.CLIENT_VERSION = tonumber((select(4, GetBuildInfo())))
mod.COMMAND = "/dorq"

local function CopyTable(srcTable)
	local newTable = {}
	for key, value in pairs(srcTable or {}) do
		if type(value) == "table" then
			value = CopyTable(value)
		end
		newTable[key] = value
	end
	return newTable
end

local function Print(msg, r, g, b)
	DEFAULT_CHAT_FRAME:AddMessage("DorqUtilities: " .. tostring(msg), r, g, b)
end

mod.CopyTable = CopyTable
mod.Print = Print
