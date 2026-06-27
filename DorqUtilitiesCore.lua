-------------------------------------------------------------------------------
-- Title: DorqUtilities Core
-------------------------------------------------------------------------------

local module = {}
local moduleName = "Core"
DorqUtilities[moduleName] = module

local MSBTAnimations = DorqUtilities.Animations
local MSBTProfiles = DorqUtilities.Profiles

local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_lower = string.lower
local math_max = math.max
local table_concat = table.concat
local C_ChallengeMode = C_ChallengeMode
local C_ClassTalents = C_ClassTalents
local C_CVar = C_CVar
local C_EquipmentSet = C_EquipmentSet
local C_Item = C_Item
local C_SpecializationInfo = C_SpecializationInfo
local C_SpellBook = C_SpellBook
local C_Timer = C_Timer
local C_Traits = C_Traits
local C_UnitAuras = C_UnitAuras
local GetInstanceInfo = GetInstanceInfo
local GetItemCooldown = GetItemCooldown
local GetItemCount = GetItemCount
local GetCVar = GetCVar
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetSpecializationRole = GetSpecializationRole
local GetTime = GetTime
local IsInInstance = IsInInstance
local IsPlayerSpell = IsPlayerSpell
local issecretvalue = issecretvalue
local SetCVar = SetCVar
local UnitClass = UnitClass
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitHealthPercent = UnitHealthPercent
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerPercent = UnitPowerPercent

local Print = DorqUtilities.Print
local sounds = DorqUtilities.Media.sounds

local MANA_POWER_TYPE = Enum.PowerType.Mana
local DEFAULT_ALERT_SCROLL_AREA = "Notification"
local DEFAULT_SOUND_PATH = "Interface\\AddOns\\DorqUtilities\\Sounds\\"
local BLOODLUST_READY_MESSAGE = "BL READY"
local POTION_READY_MESSAGE = "POT READY"
local LOADOUT_CONTEXT_MP = "mp"
local LOADOUT_CONTEXT_RAID = "raid"
local LOADOUT_CONTEXT_LABELS = {
	mp = "M+",
	raid = "Raid",
}
local LOADOUT_REFRESH_DELAYS = { 0.1, 0.35, 0.8, 1.5 }
local SOUND_NUM_CHANNELS_CVAR = "Sound_NumChannels"
local SOUND_NUM_CHANNELS_TARGET = 96
local SOUND_CHANNEL_REPAIR_DELAYS = { 0.05, 0.25, 0.75, 1.25, 2.5 }
local GCD_THRESHOLD = 1.5
local MAX_AURA_SCAN_COUNT = 80

local manaClasses = {
	DRUID = true,
	MAGE = true,
	PALADIN = true,
	PRIEST = true,
	SHAMAN = true,
	WARLOCK = true,
}

local bloodlustSpellsByClass = {
	EVOKER = { 390386 }, -- Fury of the Aspects
	HUNTER = { 264667 }, -- Primal Rage
	MAGE = { 80353 }, -- Time Warp
	SHAMAN = { 2825, 32182 }, -- Bloodlust, Heroism
}

local combatPotionItemIDs = {
	245898, -- Fleeting Light's Potential
	245897, -- Fleeting Light's Potential
	241308, -- Light's Potential
	241309, -- Light's Potential
	245903, -- Fleeting Potion of Recklessness
	245902, -- Fleeting Potion of Recklessness
	241289, -- Potion of Recklessness
	241288, -- Potion of Recklessness
	245901, -- Fleeting Potion of Zealotry
	245900, -- Fleeting Potion of Zealotry
	241297, -- Potion of Zealotry
	241296, -- Potion of Zealotry
	245911, -- Fleeting Draught of Rampant Abandon
	245910, -- Fleeting Draught of Rampant Abandon
	241293, -- Draught of Rampant Abandon
	241292, -- Draught of Rampant Abandon
}

local bloodlustLockoutDebuffs = {
	57723, -- Exhaustion
	57724, -- Sated
	80354, -- Temporal Displacement
	95809, -- Insanity
	160455, -- Fatigued
	264689, -- Fatigued
	390435, -- Exhaustion
}

local bloodlustLockoutDebuffIDs = {}
for _, spellID in ipairs(bloodlustLockoutDebuffs) do
	bloodlustLockoutDebuffIDs[spellID] = true
end

local BLOODLUST_LOCKOUT_SCAN_FILTERS = {
	"HARMFUL",
	"HARMFUL|IMPORTANT",
	"HARMFUL|RAID",
	"HARMFUL|RAID_IN_COMBAT",
}

local eventFrame = CreateFrame("Frame", "DorqUtilitiesEventFrame", UIParent)
eventFrame:SetPoint("BOTTOM")
eventFrame:SetWidth(0.0001)
eventFrame:SetHeight(0.0001)
eventFrame:Show()

local playerClass
local lowHealthActive = false
local lowManaActive = false
local lastLowHealthTime = 0
local lastLowManaTime = 0
local warningsShown = {}
local bloodlustAlertFrame
local bloodlustAlertShown
local potionAlertFrame
local potionAlertShown
local loadoutMismatchAlertFrame
local loadoutMismatchAlertShown
local loadoutRefreshSequence = 0
local soundChannelRepairSequence = 0
local potionCooldownCheckReadyAt
local currentBloodlustSpellID
local hasBloodlustLockoutDebuff = false
local isBloodlustDungeon = false
local isBloodlustChallengeMode = false
local isPlayerDamageRole = false

local function WarnOnce(key, message)
	if warningsShown[key] then
		return
	end

	warningsShown[key] = true
	Print(message, 1, 0.25, 0.25)
end

local function IsSecretValue(value)
	if not issecretvalue or value == nil then
		return false
	end

	local ok, isSecret = pcall(issecretvalue, value)
	return ok and isSecret == true
end

local function EnsureBloodlustAlertFrame()
	if bloodlustAlertFrame then
		return bloodlustAlertFrame
	end

	local frame = CreateFrame("Frame", "DorqUtilitiesBloodlustAlertFrame", UIParent)
	frame:SetFrameStrata("HIGH")
	frame:SetSize(360, 48)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	frame:Hide()

	local fontString = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	fontString:SetAllPoints(frame)
	fontString:SetJustifyH("CENTER")
	fontString:SetJustifyV("MIDDLE")
	fontString:SetText(BLOODLUST_READY_MESSAGE)
	fontString:SetTextColor(1, 0.1, 0.1, 1)
	fontString:SetShadowColor(0, 0, 0, 1)
	fontString:SetShadowOffset(2, -2)
	frame.text = fontString

	bloodlustAlertFrame = frame
	return frame
end

local function SetBloodlustAlertShown(shouldShow)
	shouldShow = not not shouldShow
	if bloodlustAlertShown == shouldShow then
		return
	end

	bloodlustAlertShown = shouldShow
	if not shouldShow and not bloodlustAlertFrame then
		return
	end

	local frame = EnsureBloodlustAlertFrame()
	if shouldShow then
		frame:Show()
	else
		frame:Hide()
	end
end

local function EnsurePotionAlertFrame()
	if potionAlertFrame then
		return potionAlertFrame
	end

	local frame = CreateFrame("Frame", "DorqUtilitiesPotionAlertFrame", UIParent)
	frame:SetFrameStrata("HIGH")
	frame:SetSize(360, 42)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 76)
	frame:Hide()

	local fontString = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	fontString:SetAllPoints(frame)
	fontString:SetJustifyH("CENTER")
	fontString:SetJustifyV("MIDDLE")
	fontString:SetText(POTION_READY_MESSAGE)
	fontString:SetTextColor(1, 0.72, 0.16, 1)
	fontString:SetShadowColor(0, 0, 0, 1)
	fontString:SetShadowOffset(2, -2)
	frame.text = fontString

	potionAlertFrame = frame
	return frame
end

local function SetPotionAlertShown(shouldShow)
	shouldShow = not not shouldShow
	if potionAlertShown == shouldShow then
		return
	end

	potionAlertShown = shouldShow
	if not shouldShow and not potionAlertFrame then
		return
	end

	local frame = EnsurePotionAlertFrame()
	if shouldShow then
		frame:Show()
	else
		frame:Hide()
	end
end

local function EnsureLoadoutMismatchAlertFrame()
	if loadoutMismatchAlertFrame then
		return loadoutMismatchAlertFrame
	end

	local frame = CreateFrame("Frame", "DorqUtilitiesLoadoutMismatchAlertFrame", UIParent)
	frame:SetFrameStrata("HIGH")
	frame:SetSize(760, 44)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
	frame:Hide()

	local fontString = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	fontString:SetAllPoints(frame)
	fontString:SetJustifyH("CENTER")
	fontString:SetJustifyV("MIDDLE")
	fontString:SetTextColor(1, 0.28, 0.16, 1)
	fontString:SetShadowColor(0, 0, 0, 1)
	fontString:SetShadowOffset(2, -2)
	frame.text = fontString

	loadoutMismatchAlertFrame = frame
	return frame
end

local function SetLoadoutMismatchAlertShown(shouldShow, message)
	shouldShow = not not shouldShow
	if loadoutMismatchAlertShown == shouldShow and (not shouldShow or not loadoutMismatchAlertFrame or loadoutMismatchAlertFrame.text:GetText() == message) then
		return
	end

	loadoutMismatchAlertShown = shouldShow
	if not shouldShow and not loadoutMismatchAlertFrame then
		return
	end

	local frame = EnsureLoadoutMismatchAlertFrame()
	if shouldShow then
		frame.text:SetText(message)
		frame:Show()
	else
		frame:Hide()
	end
end

local function FormatMessage(template, tokens)
	local message = template or ""
	if tokens and tokens.power ~= nil then
		message = string_gsub(message, "%%p", tostring(tokens.power))
	end
	if tokens and tokens.context ~= nil then
		message = string_gsub(message, "%%c", tostring(tokens.context))
	end
	if tokens and tokens.mismatch ~= nil then
		message = string_gsub(message, "%%m", tostring(tokens.mismatch))
	end
	return message
end

local function PlayConfiguredAlertSound(soundFile)
	if not soundFile or MSBTProfiles.currentProfile.soundsDisabled then
		return
	end

	local resolvedPath = sounds[soundFile] or soundFile
	if type(resolvedPath) == "string" then
		if resolvedPath == "" then
			return
		end

		if not string_find(resolvedPath, "\\", nil, true) and not string_find(resolvedPath, "/", nil, true) then
			resolvedPath = DEFAULT_SOUND_PATH .. resolvedPath
		end

		local soundPathLower = string_lower(resolvedPath)
		if (string_find(soundPathLower, "interface", nil, true) or 0) ~= 1 then
			return
		end
	end

	local ok = pcall(PlaySoundFile, resolvedPath, "Master")
	if not ok then
		WarnOnce("alert-sound-failed", "DorqUtilities could not play one of its alert sounds on this client.")
	end
end

local function DisplayAlert(alertSettings, message)
	if not alertSettings or alertSettings.disabled then
		return
	end

	MSBTAnimations.DisplayMessage(
		message,
		alertSettings.scrollArea or DEFAULT_ALERT_SCROLL_AREA,
		alertSettings.alwaysSticky,
		(alertSettings.colorR or 1) * 255,
		(alertSettings.colorG or 1) * 255,
		(alertSettings.colorB or 1) * 255,
		alertSettings.fontSize,
		alertSettings.fontName,
		alertSettings.outlineIndex
	)
	PlayConfiguredAlertSound(alertSettings.soundFile)
end

local function GetHealthPercent()
	if UnitHealthPercent then
		local ok, percent = pcall(UnitHealthPercent, "player", true)
		if ok and type(percent) == "number" and not IsSecretValue(percent) then
			return percent * 100
		end
	end

	local ok, current, maximum = pcall(function()
		return UnitHealth("player"), UnitHealthMax("player")
	end)
	if not ok or IsSecretValue(current) or IsSecretValue(maximum) or not maximum or maximum <= 0 then
		return
	end

	return (current / maximum) * 100
end

local function GetManaPercent()
	if UnitPowerPercent then
		local ok, percent = pcall(UnitPowerPercent, "player", MANA_POWER_TYPE)
		if ok and type(percent) == "number" and not IsSecretValue(percent) then
			return percent * 100
		end
	end

	local ok, current, maximum = pcall(function()
		return UnitPower("player", MANA_POWER_TYPE), UnitPowerMax("player", MANA_POWER_TYPE)
	end)
	if not ok or IsSecretValue(current) or IsSecretValue(maximum) or not maximum or maximum <= 0 then
		return
	end

	return (current / maximum) * 100
end

local function ShowLowHealth()
	local alert = MSBTProfiles.currentProfile.alerts and MSBTProfiles.currentProfile.alerts.LOW_HEALTH
	if not alert or alert.disabled then
		lowHealthActive = false
		return
	end

	local percent = GetHealthPercent()
	if not percent or percent > (alert.threshold or 0) then
		lowHealthActive = false
		return
	end

	local now = GetTime()
	if lowHealthActive or (lastLowHealthTime > 0 and now - lastLowHealthTime < (alert.repeatDelay or 0)) then
		lowHealthActive = true
		return
	end

	lowHealthActive = true
	lastLowHealthTime = now
	DisplayAlert(alert, FormatMessage(alert.message, { power = alert.threshold }))
end

local function ShowLowMana()
	if not manaClasses[playerClass] then
		lowManaActive = false
		return
	end

	local alert = MSBTProfiles.currentProfile.alerts and MSBTProfiles.currentProfile.alerts.LOW_MANA
	if not alert or alert.disabled then
		lowManaActive = false
		return
	end

	local percent = GetManaPercent()
	if not percent or percent > (alert.threshold or 0) then
		lowManaActive = false
		return
	end

	local now = GetTime()
	if lowManaActive or (lastLowManaTime > 0 and now - lastLowManaTime < (alert.repeatDelay or 0)) then
		lowManaActive = true
		return
	end

	lowManaActive = true
	lastLowManaTime = now
	DisplayAlert(alert, FormatMessage(alert.message, { power = alert.threshold }))
end

local function RefreshPlayerDamageRole()
	isPlayerDamageRole = false

	if GetSpecialization and GetSpecializationRole then
		local specializationIndex = GetSpecialization()
		if specializationIndex then
			local ok, role = pcall(GetSpecializationRole, specializationIndex)
			if ok and role == "DAMAGER" then
				isPlayerDamageRole = true
				return true
			end
		end
	end

	if UnitGroupRolesAssigned then
		local ok, role = pcall(UnitGroupRolesAssigned, "player")
		if ok and role == "DAMAGER" then
			isPlayerDamageRole = true
			return true
		end
	end

	return false
end

local function IsPotionAlertEnabled()
	local alertSettings = MSBTProfiles.currentProfile.alerts and MSBTProfiles.currentProfile.alerts.POTION_READY
	return alertSettings and not alertSettings.disabled
end

local function GetCombatPotionCount(itemID)
	if C_Item and C_Item.GetItemCount then
		local ok, count = pcall(C_Item.GetItemCount, itemID, false, false, false, false)
		if ok and type(count) == "number" then
			return count
		end
	end

	if GetItemCount then
		local ok, count = pcall(GetItemCount, itemID, false, false, false, false)
		if ok and type(count) == "number" then
			return count
		end
	end

	return 0
end

local function TryGetCombatPotionCooldown(itemID)
	if C_Item and C_Item.GetItemCooldown then
		local ok, startTime, duration, enabled = pcall(C_Item.GetItemCooldown, itemID)
		if ok then
			if type(startTime) == "table" then
				local info = startTime
				return info.startTime, info.duration, info.isEnabled
			end
			return startTime, duration, enabled
		end
	end

	if GetItemCooldown then
		local ok, startTime, duration, enabled = pcall(GetItemCooldown, itemID)
		if ok then
			return startTime, duration, enabled
		end
	end
end

local function IsKnownBloodlustSpell(spellID)
	if IsPlayerSpell then
		local ok, isKnown = pcall(IsPlayerSpell, spellID)
		if ok and isKnown then
			return true
		end
	end

	if C_SpellBook and C_SpellBook.IsSpellKnown then
		local ok, isKnown = pcall(C_SpellBook.IsSpellKnown, spellID)
		if ok and isKnown then
			return true
		end
	end

	return false
end

local function IsChallengeModeActive()
	if not C_ChallengeMode or not C_ChallengeMode.IsChallengeModeActive then
		return false
	end

	local ok, isActive = pcall(C_ChallengeMode.IsChallengeModeActive)
	return ok and isActive == true
end

local function IsBloodlustAlertEnabled()
	local alertSettings = MSBTProfiles.currentProfile.alerts and MSBTProfiles.currentProfile.alerts.BLOODLUST_READY
	return alertSettings and not alertSettings.disabled
end

local function IsSoundChannelCapEnabled()
	return type(MSBTProfiles.currentProfile.settings) == "table" and MSBTProfiles.currentProfile.settings.soundChannelCap ~= false
end

local function IsLoadoutMismatchAlertEnabled()
	local alertSettings = MSBTProfiles.currentProfile.alerts and MSBTProfiles.currentProfile.alerts.LOADOUT_MISMATCH
	return alertSettings and not alertSettings.disabled
end

local function ReadSoundNumChannels()
	local value
	if C_CVar and C_CVar.GetCVar then
		local ok, cvarValue = pcall(C_CVar.GetCVar, SOUND_NUM_CHANNELS_CVAR)
		if ok then
			value = cvarValue
		end
	end

	if value == nil and GetCVar then
		local ok, cvarValue = pcall(GetCVar, SOUND_NUM_CHANNELS_CVAR)
		if ok then
			value = cvarValue
		end
	end

	return tonumber(value), value
end

local function WriteSoundNumChannels(value)
	local cvarValue = tostring(value)
	if C_CVar and C_CVar.SetCVar then
		local ok = pcall(C_CVar.SetCVar, SOUND_NUM_CHANNELS_CVAR, cvarValue)
		if ok then
			return true
		end
	end

	if SetCVar then
		local ok = pcall(SetCVar, SOUND_NUM_CHANNELS_CVAR, cvarValue)
		if ok then
			return true
		end
	end

	return false
end

local function EnforceSoundChannelCap()
	if MSBTProfiles.IsModDisabled and MSBTProfiles.IsModDisabled() then
		return false
	end

	if not IsSoundChannelCapEnabled() then
		return false
	end

	local current = ReadSoundNumChannels()
	if current == SOUND_NUM_CHANNELS_TARGET then
		return false
	end

	return WriteSoundNumChannels(SOUND_NUM_CHANNELS_TARGET)
end

local function EnforceSoundChannelCapSoon()
	EnforceSoundChannelCap()
	if not C_Timer or not C_Timer.After then
		return
	end

	soundChannelRepairSequence = soundChannelRepairSequence + 1
	local sequence = soundChannelRepairSequence
	for _, delay in ipairs(SOUND_CHANNEL_REPAIR_DELAYS) do
		C_Timer.After(delay, function()
			if sequence ~= soundChannelRepairSequence then
				return
			end

			EnforceSoundChannelCap()
		end)
	end
end

module.RefreshSoundChannelCap = EnforceSoundChannelCapSoon

local function CanPlayerClassProvideBloodlust()
	return bloodlustSpellsByClass[playerClass] ~= nil
end

local function ResolveBloodlustSpell(keepCurrentSpell)
	if keepCurrentSpell and currentBloodlustSpellID then
		return currentBloodlustSpellID
	end

	currentBloodlustSpellID = nil
	local spellIDs = bloodlustSpellsByClass[playerClass]
	if not spellIDs then
		return
	end

	for _, spellID in ipairs(spellIDs) do
		if IsKnownBloodlustSpell(spellID) then
			currentBloodlustSpellID = spellID
			return spellID
		end
	end

	if keepCurrentSpell and isBloodlustDungeon then
		currentBloodlustSpellID = spellIDs[1]
		return currentBloodlustSpellID
	end
end

local function HasBloodlustLockoutDebuffBySpellID(spellID)
	if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
		local ok, auraInfo = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
		if ok and auraInfo then
			return true
		elseif not ok then
			WarnOnce("bloodlust-aura-read-failed", "DorqUtilities could not safely read some player aura data on this client.")
		end
	end

	return false
end

local function ScanBloodlustLockoutDebuffsByFilter(filter)
	if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
		return false
	end

	for index = 1, MAX_AURA_SCAN_COUNT do
		local ok, auraInfo = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, filter)
		if not ok or not auraInfo then
			return false
		end

		local matchOk, isLockoutDebuff = pcall(function()
			local spellID = auraInfo.spellId
			if IsSecretValue(spellID) then
				return false
			end

			return type(spellID) == "number" and bloodlustLockoutDebuffIDs[spellID] == true
		end)
		if matchOk and isLockoutDebuff then
			return true
		end
	end

	return false
end

local function RefreshBloodlustLockoutDebuff()
	hasBloodlustLockoutDebuff = false

	if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
		for _, spellID in ipairs(bloodlustLockoutDebuffs) do
			if HasBloodlustLockoutDebuffBySpellID(spellID) then
				hasBloodlustLockoutDebuff = true
				return true
			end
		end
	end

	for _, filter in ipairs(BLOODLUST_LOCKOUT_SCAN_FILTERS) do
		if ScanBloodlustLockoutDebuffsByFilter(filter) then
			hasBloodlustLockoutDebuff = true
			return true
		end
	end

	return false
end

local function IsBloodlustLockoutAuraInfo(auraInfo)
	if not auraInfo then
		return false
	end

	local ok, isLockoutDebuff = pcall(function()
		local spellID = auraInfo.spellID or auraInfo.spellId
		if not spellID then
			return false
		end

		if IsSecretValue(spellID) then
			return true
		end

		return type(spellID) == "number" and bloodlustLockoutDebuffIDs[spellID] == true
	end)

	return ok and isLockoutDebuff == true
end

local function GetReadyAlertDungeonContext()
	if IsChallengeModeActive() then
		return true, true
	end

	if not IsInInstance then
		return false, false
	end

	local ok, inInstance, instanceType = pcall(IsInInstance)
	if not ok then
		return false, false
	end

	local difficultyID
	if GetInstanceInfo then
		local infoOk
		infoOk, _, _, difficultyID = pcall(GetInstanceInfo)
		if not infoOk then
			difficultyID = nil
		end
	end

	return inInstance == true and (instanceType == "party" or difficultyID == 8), false
end

local function GetLoadoutContext()
	if IsChallengeModeActive() then
		return LOADOUT_CONTEXT_MP
	end

	if not IsInInstance then
		return
	end

	local ok, inInstance, instanceType = pcall(IsInInstance)
	if ok and inInstance == true and instanceType == "raid" then
		return LOADOUT_CONTEXT_RAID
	end
end

local function RefreshBloodlustInstanceState()
	isBloodlustDungeon, isBloodlustChallengeMode = GetReadyAlertDungeonContext()
	return isBloodlustDungeon
end

local function ShouldShowBloodlustAlert()
	if MSBTProfiles.IsModDisabled and MSBTProfiles.IsModDisabled() then
		return false
	end

	if not IsBloodlustAlertEnabled() or not CanPlayerClassProvideBloodlust() then
		return false
	end

	if not isBloodlustDungeon then
		return false
	end

	local spellID = currentBloodlustSpellID or ResolveBloodlustSpell(true)
	if not spellID then
		return false
	end

	if hasBloodlustLockoutDebuff then
		return false
	end

	return true
end

local function UpdateBloodlustAlert()
	SetBloodlustAlertShown(ShouldShowBloodlustAlert())
end

local RefreshPotionState

local function SchedulePotionCooldownCheck(readyAt)
	if not readyAt or not C_Timer or not C_Timer.After then
		return
	end

	if potionCooldownCheckReadyAt and potionCooldownCheckReadyAt <= readyAt then
		return
	end

	potionCooldownCheckReadyAt = readyAt
	C_Timer.After(math_max((readyAt - GetTime()) + 0.05, 0.05), function()
		if potionCooldownCheckReadyAt ~= readyAt then
			return
		end

		potionCooldownCheckReadyAt = nil
		RefreshPotionState()
	end)
end

local function IsCombatPotionReady(itemID)
	if GetCombatPotionCount(itemID) <= 0 then
		return false
	end

	local startTime, duration, enabled = TryGetCombatPotionCooldown(itemID)
	if duration == nil then
		return false
	end

	if enabled == false or enabled == 0 then
		return false
	end

	local readyAt = (startTime or 0) + (duration or 0)
	if duration > GCD_THRESHOLD and readyAt > GetTime() then
		SchedulePotionCooldownCheck(readyAt)
		return false
	end

	return true
end

local function HasReadyCombatPotion()
	for _, itemID in ipairs(combatPotionItemIDs) do
		if IsCombatPotionReady(itemID) then
			return true
		end
	end

	return false
end

RefreshPotionState = function()
	if MSBTProfiles.IsModDisabled and MSBTProfiles.IsModDisabled() then
		SetPotionAlertShown(false)
		return
	end

	if not IsPotionAlertEnabled() then
		SetPotionAlertShown(false)
		return
	end

	RefreshBloodlustInstanceState()
	if not isBloodlustDungeon then
		SetPotionAlertShown(false)
		return
	end

	RefreshPlayerDamageRole()
	if not isPlayerDamageRole then
		SetPotionAlertShown(false)
		return
	end

	SetPotionAlertShown(HasReadyCombatPotion())
end

module.RefreshPotionState = RefreshPotionState

local function NameContainsContext(name, context)
	return type(name) == "string" and string_find(string_lower(name), context, nil, true) ~= nil
end

local function GetEquipmentLoadoutState(context)
	if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs or not C_EquipmentSet.GetEquipmentSetInfo then
		return false, true
	end

	local ok, setIDs = pcall(C_EquipmentSet.GetEquipmentSetIDs)
	if not ok or type(setIDs) ~= "table" then
		return false, true
	end

	local hasContextPreset = false
	for _, setID in ipairs(setIDs) do
		local infoOk, name, _, _, isEquipped = pcall(C_EquipmentSet.GetEquipmentSetInfo, setID)
		if infoOk and NameContainsContext(name, context) then
			hasContextPreset = true
			if C_EquipmentSet.IsEquipmentSetEquipped then
				local equippedOk, setEquipped = pcall(C_EquipmentSet.IsEquipmentSetEquipped, setID)
				if equippedOk then
					isEquipped = setEquipped
				end
			end
			if isEquipped then
				return true, true
			end
		end
	end

	return hasContextPreset, not hasContextPreset
end

local function GetActiveTalentConfigID()
	if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
		local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
		if ok and configID then
			return configID
		end
	end

	if C_Traits and C_Traits.GetActiveConfigID then
		local ok, configID = pcall(C_Traits.GetActiveConfigID)
		if ok and configID then
			return configID
		end
	end
end

local function GetTalentConfigInfo(configID)
	if not C_Traits or not C_Traits.GetConfigInfo then
		return
	end

	local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID)
	if ok and type(configInfo) == "table" then
		return configInfo
	end
end

local function GetTalentConfigImportString(configID)
	if not C_Traits or not C_Traits.GenerateImportString then
		return
	end

	local ok, importString = pcall(C_Traits.GenerateImportString, configID)
	if ok and type(importString) == "string" and importString ~= "" then
		return importString
	end
end

local function GetCurrentSpecID()
	local specializationIndex
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
		local ok, index = pcall(C_SpecializationInfo.GetSpecialization)
		if ok then
			specializationIndex = index
		end
	elseif GetSpecialization then
		local ok, index = pcall(GetSpecialization)
		if ok then
			specializationIndex = index
		end
	end
	if not specializationIndex then
		return
	end

	local specID
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
		local ok, id = pcall(C_SpecializationInfo.GetSpecializationInfo, specializationIndex)
		if ok then
			specID = id
		end
	elseif GetSpecializationInfo then
		local ok, id = pcall(GetSpecializationInfo, specializationIndex)
		if ok then
			specID = id
		end
	end
	if not specID then
		return
	end

	return specID
end

local function GetTalentConfigIDsForCurrentSpec()
	local specID = GetCurrentSpecID()
	if not specID then
		return
	end

	if C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
		local ok, configIDs = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
		if ok and type(configIDs) == "table" then
			return configIDs
		end
	end

	if C_Traits and C_Traits.GetConfigIDsBySpecID then
		local ok, configIDs = pcall(C_Traits.GetConfigIDsBySpecID, specID)
		if ok and type(configIDs) == "table" then
			return configIDs
		end
	end
end

local function GetSelectedSavedTalentConfigID()
	if not C_ClassTalents or not C_ClassTalents.GetLastSelectedSavedConfigID then
		return
	end

	local specID = GetCurrentSpecID()
	if not specID then
		return
	end

	local ok, configID = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
	if ok and configID then
		return configID
	end
end

local function GetTalentLoadoutState(context)
	local selectedSavedConfigID = GetSelectedSavedTalentConfigID()
	local selectedInfo = selectedSavedConfigID and GetTalentConfigInfo(selectedSavedConfigID)
	if NameContainsContext(selectedInfo and selectedInfo.name, context) then
		return true, true
	end

	local activeConfigID = GetActiveTalentConfigID()
	if not activeConfigID then
		return false, true
	end

	local activeInfo = GetTalentConfigInfo(activeConfigID)
	if NameContainsContext(activeInfo and activeInfo.name, context) then
		return true, true
	end
	local activeImportString
	local configIDs = GetTalentConfigIDsForCurrentSpec()
	if not configIDs then
		return false, true
	end

	local hasContextPreset = false
	for _, configID in ipairs(configIDs) do
		local configInfo = GetTalentConfigInfo(configID)
		if NameContainsContext(configInfo and configInfo.name, context) then
			hasContextPreset = true
			if configID == activeConfigID or tostring(configID) == tostring(activeConfigID) then
				return true, true
			end

			activeImportString = activeImportString or GetTalentConfigImportString(activeConfigID)
			if activeImportString and GetTalentConfigImportString(configID) == activeImportString then
				return true, true
			end
		end
	end

	return hasContextPreset, not hasContextPreset
end

local function GetLoadoutDebugState()
	local context = GetLoadoutContext()
	local hasEquipmentPreset, isEquipmentCorrect = false, true
	local hasTalentPreset, isTalentCorrect = false, true
	if context then
		hasEquipmentPreset, isEquipmentCorrect = GetEquipmentLoadoutState(context)
		hasTalentPreset, isTalentCorrect = GetTalentLoadoutState(context)
	end

	local activeConfigID = GetActiveTalentConfigID()
	local activeInfo = activeConfigID and GetTalentConfigInfo(activeConfigID)
	local activeImportString = activeConfigID and GetTalentConfigImportString(activeConfigID)
	local selectedSavedConfigID = GetSelectedSavedTalentConfigID()
	local selectedSavedInfo = selectedSavedConfigID and GetTalentConfigInfo(selectedSavedConfigID)
	local contextTalentNames = {}
	local configIDs = GetTalentConfigIDsForCurrentSpec()
	if configIDs then
		for _, configID in ipairs(configIDs) do
			local configInfo = GetTalentConfigInfo(configID)
			if context and NameContainsContext(configInfo and configInfo.name, context) then
				local isApplied = configID == activeConfigID or tostring(configID) == tostring(activeConfigID)
				if not isApplied and activeImportString then
					isApplied = GetTalentConfigImportString(configID) == activeImportString
				end
				local isSelected = selectedSavedConfigID and (configID == selectedSavedConfigID or tostring(configID) == tostring(selectedSavedConfigID))
				local state = isApplied and "applied" or (isSelected and "selected" or "inactive")
				contextTalentNames[#contextTalentNames + 1] = string_format("%s:%s", tostring(configInfo.name), state)
			end
		end
	end

	return string_format(
		"LOADOUT state: context=%s enabled=%s gearPreset=%s gearCorrect=%s talentPreset=%s talentCorrect=%s activeTalentID=%s activeTalentName=%s selectedTalentID=%s selectedTalentName=%s contextTalents=%s",
		tostring(context),
		tostring(IsLoadoutMismatchAlertEnabled()),
		tostring(hasEquipmentPreset),
		tostring(isEquipmentCorrect),
		tostring(hasTalentPreset),
		tostring(isTalentCorrect),
		tostring(activeConfigID),
		tostring(activeInfo and activeInfo.name),
		tostring(selectedSavedConfigID),
		tostring(selectedSavedInfo and selectedSavedInfo.name),
		#contextTalentNames > 0 and table_concat(contextTalentNames, ", ") or "none"
	)
end

local function RefreshLoadoutMismatchState()
	if MSBTProfiles.IsModDisabled and MSBTProfiles.IsModDisabled() then
		SetLoadoutMismatchAlertShown(false)
		return
	end

	if not IsLoadoutMismatchAlertEnabled() then
		SetLoadoutMismatchAlertShown(false)
		return
	end

	local context = GetLoadoutContext()
	if not context then
		SetLoadoutMismatchAlertShown(false)
		return
	end

	local mismatches = {}
	local hasEquipmentPreset, isEquipmentCorrect = GetEquipmentLoadoutState(context)
	if hasEquipmentPreset and not isEquipmentCorrect then
		mismatches[#mismatches + 1] = "gear"
	end

	local hasTalentPreset, isTalentCorrect = GetTalentLoadoutState(context)
	if hasTalentPreset and not isTalentCorrect then
		mismatches[#mismatches + 1] = "talents"
	end

	if #mismatches == 0 then
		SetLoadoutMismatchAlertShown(false)
		return
	end

	local alertSettings = MSBTProfiles.currentProfile.alerts and MSBTProfiles.currentProfile.alerts.LOADOUT_MISMATCH
	local message = FormatMessage(
		(alertSettings and alertSettings.message) or "CHECK %c LOADOUT: %m",
		{
			context = LOADOUT_CONTEXT_LABELS[context] or context,
			mismatch = table_concat(mismatches, " + "),
		}
	)
	SetLoadoutMismatchAlertShown(true, message)
end

local function RefreshLoadoutMismatchStateSoon()
	RefreshLoadoutMismatchState()
	if not C_Timer or not C_Timer.After then
		return
	end

	loadoutRefreshSequence = loadoutRefreshSequence + 1
	local sequence = loadoutRefreshSequence
	for _, delay in ipairs(LOADOUT_REFRESH_DELAYS) do
		C_Timer.After(delay, function()
			if sequence ~= loadoutRefreshSequence then
				return
			end

			RefreshLoadoutMismatchState()
		end)
	end
end

module.RefreshLoadoutMismatchState = RefreshLoadoutMismatchState

local function RefreshBloodlustState()
	if not IsBloodlustAlertEnabled() or not CanPlayerClassProvideBloodlust() then
		RefreshBloodlustInstanceState()
		currentBloodlustSpellID = nil
		hasBloodlustLockoutDebuff = false
		isBloodlustChallengeMode = false
		SetBloodlustAlertShown(false)
		return
	end

	RefreshBloodlustInstanceState()
	ResolveBloodlustSpell(true)
	if isBloodlustDungeon and currentBloodlustSpellID then
		RefreshBloodlustLockoutDebuff()
	else
		hasBloodlustLockoutDebuff = false
	end
	UpdateBloodlustAlert()
end

module.RefreshBloodlustState = RefreshBloodlustState
module.RefreshReadyAlertStates = function()
	RefreshBloodlustState()
	RefreshPotionState()
	RefreshLoadoutMismatchState()
end

local function RefreshBloodlustStateSoon()
	RefreshBloodlustState()
	if C_Timer and C_Timer.After then
		C_Timer.After(0.25, RefreshBloodlustState)
		C_Timer.After(1, RefreshBloodlustState)
	end
end

local function RefreshReadyAlertStatesSoon()
	module.RefreshReadyAlertStates()
	if C_Timer and C_Timer.After then
		C_Timer.After(0.25, module.RefreshReadyAlertStates)
		C_Timer.After(1, module.RefreshReadyAlertStates)
	end
end

local function RefreshPlayerState()
	playerClass = select(2, UnitClass("player"))
	lowHealthActive = false
	lowManaActive = false
	ShowLowHealth()
	ShowLowMana()
	module.RefreshReadyAlertStates()
end

local function GetBloodlustDebugState()
	RefreshBloodlustInstanceState()
	ResolveBloodlustSpell(true)
	if isBloodlustDungeon and currentBloodlustSpellID then
		RefreshBloodlustLockoutDebuff()
	end

	local inInstance, instanceType = false, "unknown"
	if IsInInstance then
		local ok
		ok, inInstance, instanceType = pcall(IsInInstance)
		if not ok then
			inInstance, instanceType = false, "error"
		end
	end

	local difficultyID = "unknown"
	if GetInstanceInfo then
		local ok
		ok, _, _, difficultyID = pcall(GetInstanceInfo)
		if not ok then
			difficultyID = "error"
		end
	end

	return string_format(
		"BL state: class=%s enabled=%s modDisabled=%s dungeon=%s challenge=%s inInstance=%s instanceType=%s difficultyID=%s spell=%s lockout=%s shown=%s shouldShow=%s",
		tostring(playerClass),
		tostring(IsBloodlustAlertEnabled()),
		tostring(MSBTProfiles.IsModDisabled and MSBTProfiles.IsModDisabled()),
		tostring(isBloodlustDungeon),
		tostring(isBloodlustChallengeMode),
		tostring(inInstance),
		tostring(instanceType),
		tostring(difficultyID),
		tostring(currentBloodlustSpellID),
		tostring(hasBloodlustLockoutDebuff),
		tostring(bloodlustAlertFrame and bloodlustAlertFrame:IsShown()),
		tostring(ShouldShowBloodlustAlert())
	)
end

local function GetPotionDebugState()
	RefreshBloodlustInstanceState()
	RefreshPlayerDamageRole()

	local hasPotion = false
	for _, itemID in ipairs(combatPotionItemIDs) do
		if GetCombatPotionCount(itemID) > 0 then
			hasPotion = true
			break
		end
	end

	return string_format(
		"POT state: enabled=%s modDisabled=%s dungeon=%s dps=%s hasPotion=%s shown=%s ready=%s",
		tostring(IsPotionAlertEnabled()),
		tostring(MSBTProfiles.IsModDisabled and MSBTProfiles.IsModDisabled()),
		tostring(isBloodlustDungeon),
		tostring(isPlayerDamageRole),
		tostring(hasPotion),
		tostring(potionAlertFrame and potionAlertFrame:IsShown()),
		tostring(HasReadyCombatPotion())
	)
end

local function GetSoundChannelDebugState()
	local numericValue, rawValue = ReadSoundNumChannels()
	return string_format(
		"SOUND state: enabled=%s modDisabled=%s cvar=%s raw=%s target=%s changed=%s",
		tostring(IsSoundChannelCapEnabled()),
		tostring(MSBTProfiles.IsModDisabled and MSBTProfiles.IsModDisabled()),
		tostring(numericValue),
		tostring(rawValue),
		tostring(SOUND_NUM_CHANNELS_TARGET),
		tostring(EnforceSoundChannelCap())
	)
end

function eventFrame:PLAYER_LOGIN()
	MSBTAnimations.UpdateScrollAreas()
	MSBTAnimations.LoadFont(MSBTProfiles.currentProfile.normalFontName)
	MSBTAnimations.LoadFont(MSBTProfiles.currentProfile.critFontName)
	EnforceSoundChannelCapSoon()
	RefreshPlayerState()
	RefreshReadyAlertStatesSoon()
end

function eventFrame:PLAYER_ENTERING_WORLD()
	EnforceSoundChannelCapSoon()
	RefreshPlayerState()
	RefreshReadyAlertStatesSoon()
end

function eventFrame:PLAYER_SPECIALIZATION_CHANGED(unitID)
	if unitID and unitID ~= "player" then
		return
	end

	RefreshPlayerState()
	RefreshLoadoutMismatchStateSoon()
end

function eventFrame:PLAYER_EQUIPMENT_CHANGED()
	RefreshLoadoutMismatchState()
end

function eventFrame:EQUIPMENT_SETS_CHANGED()
	RefreshLoadoutMismatchState()
end

function eventFrame:TRAIT_CONFIG_UPDATED()
	RefreshLoadoutMismatchStateSoon()
end

function eventFrame:TRAIT_CONFIG_LIST_UPDATED()
	RefreshLoadoutMismatchStateSoon()
end

function eventFrame:ACTIVE_COMBAT_CONFIG_CHANGED()
	RefreshLoadoutMismatchStateSoon()
end

function eventFrame:CVAR_UPDATE(cvarName)
	if string_lower(tostring(cvarName or "")) == string_lower(SOUND_NUM_CHANNELS_CVAR) then
		EnforceSoundChannelCapSoon()
	end
end

function eventFrame:GROUP_ROSTER_UPDATE()
	module.RefreshReadyAlertStates()
end

function eventFrame:SPELLS_CHANGED()
	module.RefreshReadyAlertStates()
end

function eventFrame:UPDATE_INSTANCE_INFO()
	module.RefreshReadyAlertStates()
	RefreshLoadoutMismatchStateSoon()
end

function eventFrame:PLAYER_DIFFICULTY_CHANGED()
	module.RefreshReadyAlertStates()
	RefreshLoadoutMismatchStateSoon()
end

function eventFrame:CHALLENGE_MODE_START()
	RefreshReadyAlertStatesSoon()
end

function eventFrame:CHALLENGE_MODE_RESET()
	RefreshReadyAlertStatesSoon()
end

function eventFrame:UNIT_PET(unitID)
	if unitID == "player" then
		currentBloodlustSpellID = nil
		RefreshBloodlustState()
	end
end

function eventFrame:PLAYER_ROLES_ASSIGNED()
	RefreshPotionState()
end

function eventFrame:BAG_UPDATE_DELAYED()
	RefreshPotionState()
end

function eventFrame:BAG_UPDATE_COOLDOWN()
	RefreshPotionState()
end

function eventFrame:UNIT_HEALTH(unitID)
	if unitID == "player" then
		ShowLowHealth()
	end
end

function eventFrame:UNIT_MAXHEALTH(unitID)
	if unitID == "player" then
		ShowLowHealth()
	end
end

function eventFrame:UNIT_POWER_UPDATE(unitID, powerToken)
	if unitID ~= "player" then
		return
	end

	if powerToken == "MANA" then
		ShowLowMana()
	end
end

function eventFrame:UNIT_MAXPOWER(unitID, powerToken)
	if unitID ~= "player" then
		return
	end

	if powerToken == "MANA" then
		ShowLowMana()
	end
end

function eventFrame:UNIT_DISPLAYPOWER(unitID)
	if unitID == "player" then
		ShowLowMana()
	end
end

function eventFrame:UNIT_AURA(unitID, updateInfo)
	if unitID ~= "player" or not isBloodlustDungeon or not currentBloodlustSpellID then
		return
	end

	if not updateInfo or updateInfo.isFullUpdate then
		RefreshBloodlustLockoutDebuff()
		UpdateBloodlustAlert()
		return
	end

	local shouldRefreshBloodlust = hasBloodlustLockoutDebuff
	if updateInfo.addedAuras and #updateInfo.addedAuras > 0 then
		for _, auraInfo in ipairs(updateInfo.addedAuras) do
			if IsBloodlustLockoutAuraInfo(auraInfo) then
				shouldRefreshBloodlust = true
				break
			end
		end
	end

	if not shouldRefreshBloodlust and updateInfo.updatedAuraInstanceIDs and #updateInfo.updatedAuraInstanceIDs > 0 then
		shouldRefreshBloodlust = true
	end

	if not shouldRefreshBloodlust and updateInfo.removedAuraInstanceIDs and #updateInfo.removedAuraInstanceIDs > 0 then
		shouldRefreshBloodlust = true
	end

	if shouldRefreshBloodlust then
		RefreshBloodlustLockoutDebuff()
		UpdateBloodlustAlert()
	end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		self[event](self, ...)
	end
end)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
eventFrame:RegisterEvent("UNIT_AURA")

SLASH_DORQUTILITIES1 = DorqUtilities.COMMAND
SlashCmdList.DORQUTILITIES = function(input)
	input = string_lower(input or "")
	if input == "bl" then
		RefreshBloodlustState()
		Print(GetBloodlustDebugState())
		return
	elseif input == "pot" then
		RefreshPotionState()
		Print(GetPotionDebugState())
		return
	elseif input == "loadout" then
		RefreshLoadoutMismatchState()
		Print(GetLoadoutDebugState())
		return
	elseif input == "sound" then
		EnforceSoundChannelCapSoon()
		Print(GetSoundChannelDebugState())
		return
	elseif input == "bltest" then
		SetBloodlustAlertShown(true)
		Print("Showing BL READY test frame for 5 seconds.")
		if C_Timer and C_Timer.After then
			C_Timer.After(5, RefreshBloodlustState)
		end
		return
	end

	if DorqUtilities.Profiles and DorqUtilities.Profiles.ToggleOptions then
		DorqUtilities.Profiles.ToggleOptions()
		return
	end

	Print("DorqUtilities options are unavailable right now.")
end
