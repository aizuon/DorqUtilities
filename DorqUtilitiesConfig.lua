-------------------------------------------------------------------------------
-- Title: DorqUtilities Config
-------------------------------------------------------------------------------

local module = {}
local moduleName = "Profiles"
DorqUtilities[moduleName] = module

local CopyTable = DorqUtilities.CopyTable
local L = DorqUtilities.translations

local disabled

local masterProfile = {
	scrollAreas = {
		Notification = {
			name = L.MSG_NOTIFICATION,
			offsetX = -175,
			offsetY = 120,
			scrollHeight = 200,
			scrollWidth = 350,
		},
		Static = {
			name = L.MSG_STATIC,
			offsetX = -20,
			offsetY = -300,
			scrollHeight = 125,
			animationStyle = "Static",
			direction = "Down",
		},
	},

	events = {},

	settings = {
		warcraftLogsContextMenu = true,
	},

	alerts = {
		LOW_HEALTH = {
			colorG = 0.5,
			colorB = 0.5,
			message = L.MSG_TRIGGER_LOW_HEALTH .. "! (%p%%)",
			alwaysSticky = true,
			fontSize = 26,
			soundFile = "MSBT Low Health",
			threshold = 35,
			repeatDelay = 5,
		},
		LOW_MANA = {
			colorR = 0.5,
			colorG = 0.5,
			message = L.MSG_TRIGGER_LOW_MANA .. "! (%p%%)",
			alwaysSticky = true,
			fontSize = 26,
			soundFile = "MSBT Low Mana",
			threshold = 35,
			repeatDelay = 5,
		},
		BLOODLUST_READY = {
			message = "BL READY",
		},
		POTION_READY = {
			message = "POT READY",
		},
		LOADOUT_MISMATCH = {
			message = "CHECK %c LOADOUT: %m",
			fontSize = 24,
		},
	},

	normalFontName = L.DEFAULT_FONT_NAME,
	normalOutlineIndex = 1,
	normalFontSize = 18,
	normalFontAlpha = 100,
	critFontName = L.DEFAULT_FONT_NAME,
	critOutlineIndex = 1,
	critFontSize = 26,
	critFontAlpha = 100,
	animationSpeed = 100,
}

local currentProfile = CopyTable(masterProfile)
local savedMedia = { fonts = {}, sounds = {} }
local emptyTable = {}
local variablesLoaded
local savedVarsName = "DorqUtilities_SavedVars"
local legacySavedVarsName = "MSBTLite_SavedVars"

local featureGroups = {
	{
		title = "Alerts",
		description = "Control low-resource warnings and the Bloodlust ready alert.",
		features = {
			{
				label = "Low health warning",
				tooltip = "Shows the low health warning message and sound.",
				displayNote = "Notification area - left of center and slightly above the middle of the screen.",
				alerts = { "LOW_HEALTH" },
			},
			{
				label = "Low mana warning",
				tooltip = "Shows the low mana warning message and sound.",
				displayNote = "Notification area - left of center and slightly above the middle of the screen.",
				alerts = { "LOW_MANA" },
			},
			{
				label = "Bloodlust ready alert",
				tooltip = "Shows a static BL READY message in dungeon instances when your current class or pet has a usable Bloodlust-style spell and you are not Sated.",
				displayNote = "Static middle-screen alert.",
				alerts = { "BLOODLUST_READY" },
			},
			{
				label = "Combat potion ready alert",
				tooltip = "Shows a static POT READY message in dungeon instances for DPS players when a tracked combat potion in your bags is ready.",
				displayNote = "Static middle-screen alert.",
				alerts = { "POTION_READY" },
			},
			{
				label = "M+ / raid loadout warning",
				tooltip = "Shows a static warning near the top of the screen when your active equipment set or talent loadout does not match available presets containing mp or raid.",
				displayNote = "Static top-screen alert.",
				alerts = { "LOADOUT_MISMATCH" },
			},
			{
				label = "Warcraft Logs context menu",
				tooltip = "Adds a Copy Warcraft Logs Profile option to player context menus.",
				displayNote = "Player right-click context menus.",
				settings = { "warcraftLogsContextMenu" },
			},
		},
	},
}

local function MergeTable(destinationTable, sourceTable)
	if type(sourceTable) ~= "table" then
		return destinationTable
	end

	for key, value in pairs(sourceTable) do
		if type(value) == "table" then
			if type(destinationTable[key]) == "table" then
				MergeTable(destinationTable[key], value)
			else
				destinationTable[key] = CopyTable(value)
			end
		else
			destinationTable[key] = value
		end
	end

	return destinationTable
end

local function CopyNestedTable(value)
	if type(value) ~= "table" then
		return {}
	end

	return CopyTable(value)
end

local function PersistSavedVariables()
	_G[savedVarsName] = _G[savedVarsName] or {}
	_G[savedVarsName].disabled = disabled or false
	_G[savedVarsName].profile = CopyTable(currentProfile)
	_G[savedVarsName].savedMedia = {
		fonts = CopyNestedTable(savedMedia.fonts),
		sounds = CopyNestedTable(savedMedia.sounds),
	}
end

local function LoadSavedVariables()
	if type(_G[savedVarsName]) ~= "table" then
		if type(_G[legacySavedVarsName]) == "table" then
			_G[savedVarsName] = CopyTable(_G[legacySavedVarsName])
		else
			_G[savedVarsName] = {}
		end
	end

	disabled = not not _G[savedVarsName].disabled
	currentProfile = CopyTable(masterProfile)
	MergeTable(currentProfile, _G[savedVarsName].profile)
	currentProfile.events = {}
	currentProfile.settings = currentProfile.settings or {}
	for settingKey in pairs(currentProfile.settings) do
		if masterProfile.settings[settingKey] == nil then
			currentProfile.settings[settingKey] = nil
		end
	end
	for alertKey in pairs(currentProfile.alerts or {}) do
		if not masterProfile.alerts[alertKey] then
			currentProfile.alerts[alertKey] = nil
		end
	end
	module.currentProfile = currentProfile

	local storedMedia = _G[savedVarsName].savedMedia
	savedMedia.fonts = CopyNestedTable(storedMedia and storedMedia.fonts)
	savedMedia.sounds = CopyNestedTable(storedMedia and storedMedia.sounds)
end

local function InitializeSavedVariables()
	if variablesLoaded then
		return
	end

	LoadSavedVariables()
	PersistSavedVariables()

	if DorqUtilities.Media and DorqUtilities.Media.OnVariablesInitialized then
		DorqUtilities.Media.OnVariablesInitialized()
	end

	variablesLoaded = true
end

local function IsModDisabled()
	return disabled
end

local function SetModDisabled(value)
	disabled = not not value
	PersistSavedVariables()
end

local function SetEntryDisabled(container, entryKeys, shouldDisable)
	if type(container) ~= "table" then
		return
	end

	for _, entryKey in ipairs(entryKeys or emptyTable) do
		if container[entryKey] then
			container[entryKey].disabled = shouldDisable or nil
		end
	end
end

local function ApplyDefaultDisabledState(container, defaults, entryKeys)
	if type(container) ~= "table" or type(defaults) ~= "table" then
		return
	end

	for _, entryKey in ipairs(entryKeys or emptyTable) do
		if container[entryKey] then
			container[entryKey].disabled = defaults[entryKey] and defaults[entryKey].disabled or nil
		end
	end
end

local function SetSettingsEnabled(entryKeys, isEnabled)
	if type(currentProfile.settings) ~= "table" then
		currentProfile.settings = {}
	end

	for _, entryKey in ipairs(entryKeys or emptyTable) do
		if masterProfile.settings[entryKey] ~= nil then
			currentProfile.settings[entryKey] = isEnabled and true or false
		end
	end
end

local function ResetSettings(entryKeys)
	if type(currentProfile.settings) ~= "table" then
		currentProfile.settings = {}
	end

	for _, entryKey in ipairs(entryKeys or emptyTable) do
		if masterProfile.settings[entryKey] ~= nil then
			currentProfile.settings[entryKey] = masterProfile.settings[entryKey]
		end
	end
end

local function IsFeatureEnabled(feature)
	for _, eventKey in ipairs(feature.events or emptyTable) do
		local eventSettings = currentProfile.events and currentProfile.events[eventKey]
		if not eventSettings or eventSettings.disabled then
			return false
		end
	end

	for _, alertKey in ipairs(feature.alerts or emptyTable) do
		local alertSettings = currentProfile.alerts and currentProfile.alerts[alertKey]
		if not alertSettings or alertSettings.disabled then
			return false
		end
	end

	for _, settingKey in ipairs(feature.settings or emptyTable) do
		if type(currentProfile.settings) ~= "table" or currentProfile.settings[settingKey] == false then
			return false
		end
	end

	return true
end

local function SetFeatureEnabled(feature, isEnabled)
	SetEntryDisabled(currentProfile.events, feature.events, not isEnabled)
	SetEntryDisabled(currentProfile.alerts, feature.alerts, not isEnabled)
	SetSettingsEnabled(feature.settings, isEnabled)
	PersistSavedVariables()
end

local function ResetFeatureToggles()
	for _, group in ipairs(featureGroups) do
		for _, feature in ipairs(group.features) do
			ApplyDefaultDisabledState(currentProfile.events, masterProfile.events, feature.events)
			ApplyDefaultDisabledState(currentProfile.alerts, masterProfile.alerts, feature.alerts)
			ResetSettings(feature.settings)
		end
	end

	PersistSavedVariables()
end

module.masterProfile = masterProfile
module.currentProfile = currentProfile
module.savedMedia = savedMedia
module.IsModDisabled = IsModDisabled
module.SetModDisabled = SetModDisabled
module.featureGroups = featureGroups
module.IsFeatureEnabled = IsFeatureEnabled
module.SetFeatureEnabled = SetFeatureEnabled
module.ResetFeatureToggles = ResetFeatureToggles
module.SaveProfile = PersistSavedVariables

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
	if addonName ~= "DorqUtilities" then
		return
	end

	InitializeSavedVariables()
	self:UnregisterEvent("ADDON_LOADED")
end)
