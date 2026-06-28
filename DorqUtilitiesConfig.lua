-------------------------------------------------------------------------------
-- DorqUtilities Config
-------------------------------------------------------------------------------

local module = {}
local moduleName = "Profiles"
DorqUtilities[moduleName] = module

local CopyTable = DorqUtilities.CopyTable

local disabled

local masterProfile = {
	settings = {
		ebonMightTracker = true,
		soundChannelCap = true,
		warcraftLogsContextMenu = true,
	},

	alerts = {
		LOW_HEALTH = {
			colorG = 0.5,
			colorB = 0.5,
			message = "Low Health! (%p%%)",
			fontSize = 26,
			soundFile = "Interface\\AddOns\\DorqUtilities\\Sounds\\LowHealth.ogg",
			threshold = 35,
			repeatDelay = 5,
		},
		LOW_MANA = {
			colorR = 0.5,
			colorG = 0.5,
			message = "Low Mana! (%p%%)",
			fontSize = 26,
			soundFile = "Interface\\AddOns\\DorqUtilities\\Sounds\\LowMana.ogg",
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
		BLACK_ATTUNEMENT_MISSING = {
			message = "BLACK ATTUNEMENT MISSING",
			fontSize = 24,
		},
	},
}

local currentProfile = CopyTable(masterProfile)
local emptyTable = {}
local variablesLoaded
local savedVarsName = "DorqUtilities_SavedVars"

local featureGroups = {
	{
		title = "Alerts",
		description = "Control the DorqUtilities features that are currently implemented.",
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
				label = "Black Attunement warning",
				tooltip = "Shows a static warning for Augmentation Evokers with Draconic Attunements talented when Black Attunement is not active.",
				displayNote = "Static top-screen alert.",
				alerts = { "BLACK_ATTUNEMENT_MISSING" },
			},
			{
				label = "Ebon Might tracker",
				tooltip = "Shows a cursor reminder for Augmentation Evokers when Ebon Might is missing in combat or inside its 4 second refresh window.",
				displayNote = "Cursor-following icon reminder.",
				settings = { "ebonMightTracker" },
			},
			{
				label = "Warcraft Logs context menu",
				tooltip = "Adds a Copy Warcraft Logs Profile option to player context menus.",
				displayNote = "Player right-click context menus.",
				settings = { "warcraftLogsContextMenu" },
			},
			{
				label = "Sound channel override",
				tooltip = "Keeps Sound_NumChannels set to 96, overriding addons that raise or lower it.",
				displayNote = "Sound CVar guard.",
				settings = { "soundChannelCap" },
			},
		},
	},
}

local function MergeKnownEntries(destinationTable, sourceTable, defaults)
	if type(sourceTable) ~= "table" then
		return
	end

	for key, defaultValue in pairs(defaults) do
		local value = sourceTable[key]
		if type(defaultValue) == "table" and type(value) == "table" then
			MergeKnownEntries(destinationTable[key], value, defaultValue)
			if value.disabled ~= nil then
				destinationTable[key].disabled = value.disabled
			end
		elseif value ~= nil then
			destinationTable[key] = value
		end
	end
end

local function PersistSavedVariables()
	_G[savedVarsName] = _G[savedVarsName] or {}
	_G[savedVarsName].disabled = disabled or false
	_G[savedVarsName].profile = CopyTable(currentProfile)
end

local function LoadSavedVariables()
	_G[savedVarsName] = type(_G[savedVarsName]) == "table" and _G[savedVarsName] or {}
	disabled = not not _G[savedVarsName].disabled
	currentProfile = CopyTable(masterProfile)
	MergeKnownEntries(currentProfile, _G[savedVarsName].profile, masterProfile)
	module.currentProfile = currentProfile
end

local function InitializeSavedVariables()
	if variablesLoaded then
		return
	end

	LoadSavedVariables()
	PersistSavedVariables()
	variablesLoaded = true
end

local function IsModDisabled()
	return disabled
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
	currentProfile.settings = currentProfile.settings or {}
	for _, entryKey in ipairs(entryKeys or emptyTable) do
		if masterProfile.settings[entryKey] ~= nil then
			currentProfile.settings[entryKey] = isEnabled and true or false
		end
	end
end

local function ResetSettings(entryKeys)
	currentProfile.settings = currentProfile.settings or {}
	for _, entryKey in ipairs(entryKeys or emptyTable) do
		if masterProfile.settings[entryKey] ~= nil then
			currentProfile.settings[entryKey] = masterProfile.settings[entryKey]
		end
	end
end

local function IsFeatureEnabled(feature)
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
	SetEntryDisabled(currentProfile.alerts, feature.alerts, not isEnabled)
	SetSettingsEnabled(feature.settings, isEnabled)
	PersistSavedVariables()
end

local function ResetFeatureToggles()
	for _, group in ipairs(featureGroups) do
		for _, feature in ipairs(group.features) do
			ApplyDefaultDisabledState(currentProfile.alerts, masterProfile.alerts, feature.alerts)
			ResetSettings(feature.settings)
		end
	end

	PersistSavedVariables()
end

module.masterProfile = masterProfile
module.currentProfile = currentProfile
module.IsModDisabled = IsModDisabled
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
