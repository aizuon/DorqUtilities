-------------------------------------------------------------------------------
-- Warcraft Logs context menu integration.
-------------------------------------------------------------------------------

local moduleName = "WarcraftLogs"
local module = {}
DorqUtilities[moduleName] = module

local ADDON_NAME = "DorqUtilities"
local COPY_OPTION_TEXT = "Copy Warcraft Logs Profile"
local POPUP_ID = "DORQUTILITIES_COPY_WARCRAFTLOGS_PROFILE"

local REGION_NAMES = {
	[1] = "US",
	[2] = "KR",
	[3] = "EU",
	[4] = "TW",
	[5] = "CN",
	[72] = "PTR",
}

local VALID_MENU_TYPES = {
	PLAYER = true,
	PARTY = true,
	RAID = true,
	RAID_PLAYER = true,
	FRIEND = true,
	BN_FRIEND = true,
	CHAT_ROSTER = true,
	TARGET = true,
	FOCUS = true,
	ARENAENEMY = true,
	ENEMY_PLAYER = true,
	GUILD = true,
	GUILD_OFFLINE = true,
	SELF = true,
	WORLD_STATE_SCORE = true,
	COMMUNITIES_WOW_MEMBER = true,
	COMMUNITIES_GUILD_MEMBER = true,
}

local VALID_MENU_TAGS = {
	MENU_LFG_FRAME_SEARCH_ENTRY = true,
	MENU_LFG_FRAME_MEMBER_APPLY = true,
}

local function Print(msg)
	if DorqUtilities and DorqUtilities.Print then
		DorqUtilities.Print(msg)
	end
end

local function IsEnabled()
	local profiles = DorqUtilities and DorqUtilities.Profiles
	if profiles and profiles.IsModDisabled and profiles.IsModDisabled() then
		return false
	end

	local settings = profiles and profiles.currentProfile and profiles.currentProfile.settings
	return not settings or settings.warcraftLogsContextMenu ~= false
end

local function UrlEncode(text)
	text = tostring(text or "")
	text = text:gsub("\n", "\r\n")
	text = text:gsub("([^%w%-_%.~])", function(char)
		return string.format("%%%02X", string.byte(char))
	end)
	return text
end

local function SlugifyRealm(realm)
	if not realm or realm == "" then
		return nil
	end

	realm = realm:gsub("^%s+", ""):gsub("%s+$", "")
	realm = realm:gsub("'", "")
	realm = realm:gsub("%s+", "-")
	realm = realm:gsub("(%l)(%u)", "%1-%2")
	realm = realm:gsub("(%a)(%d)", "%1-%2")
	realm = realm:gsub("(%d)(%a)", "%1-%2")
	realm = realm:gsub("%-+", "-")

	return UrlEncode(realm:lower())
end

local function GetRegion()
	local regionID = GetCurrentRegion and GetCurrentRegion()
	return REGION_NAMES[regionID] or REGION_NAMES[1]
end

local function SplitNameRealm(name, realm)
	if type(name) ~= "string" or name == "" then
		return nil, nil
	end

	local splitName, splitRealm = strsplit("-", name)
	if splitRealm and splitRealm ~= "" then
		name = splitName
		realm = splitRealm
	end

	if not realm or realm == "" then
		realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
	end

	return name, realm
end

local GetNameRealmForBNetFriend

local function GetNameRealmFromPlayerLink(playerLink)
	if type(playerLink) ~= "string" then
		return nil, nil
	end

	local linkString = playerLink:match("^|H(.+)|h.*|h$")
	if not linkString then
		return nil, nil
	end

	local linkType, linkData = linkString:match("(.-):(.*)")
	if linkType == "player" then
		return SplitNameRealm(linkData)
	elseif linkType == "BNplayer" then
		local _, bnetIDAccount = strsplit(":", linkData)
		bnetIDAccount = tonumber(bnetIDAccount)
		if bnetIDAccount then
			local name, realm = GetNameRealmForBNetFriend(bnetIDAccount)
			return SplitNameRealm(name, realm)
		end
	end

	return nil, nil
end

GetNameRealmForBNetFriend = function(bnetIDAccount)
	if not bnetIDAccount or not BNGetFriendIndex or not C_BattleNet then
		return nil, nil
	end

	local index = BNGetFriendIndex(bnetIDAccount)
	if not index or not C_BattleNet.GetFriendNumGameAccounts or not C_BattleNet.GetFriendGameAccountInfo then
		return nil, nil
	end

	local fallbackName, fallbackRealm
	local numAccounts = C_BattleNet.GetFriendNumGameAccounts(index) or 0
	for i = 1, numAccounts do
		local accountInfo = C_BattleNet.GetFriendGameAccountInfo(index, i)
		if accountInfo and accountInfo.clientProgram == BNET_CLIENT_WOW and (not accountInfo.wowProjectID or accountInfo.wowProjectID == WOW_PROJECT_MAINLINE) then
			local name, realm = SplitNameRealm(accountInfo.characterName, accountInfo.realmName)
			if name and realm then
				local level = tonumber(accountInfo.characterLevel)
				if level and GetMaxLevelForPlayerExpansion and level >= GetMaxLevelForPlayerExpansion() then
					return name, realm
				end
				fallbackName, fallbackRealm = fallbackName or name, fallbackRealm or realm
			end
		end
	end

	return fallbackName, fallbackRealm
end

local function GetUnitNameRealm(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return nil, nil
	end

	local name, realm
	if UnitNameUnmodified then
		name, realm = UnitNameUnmodified(unit)
	else
		name, realm = UnitFullName(unit)
	end

	if not name or name == "" then
		return nil, nil
	end

	if not realm or realm == "" then
		realm = GetRealmName()
	elseif realm == (GetNormalizedRealmName and GetNormalizedRealmName()) then
		realm = GetRealmName()
	end

	return name, realm
end

local function GetBNetNameRealm(accountInfo)
	if not accountInfo or not accountInfo.gameAccountInfo then
		return nil, nil
	end

	local gameAccountInfo = accountInfo.gameAccountInfo
	return SplitNameRealm(gameAccountInfo.characterName, gameAccountInfo.realmName)
end

local function GetDropdownNameRealm(dropdown)
	if not dropdown then
		return nil, nil
	end

	if dropdown.unit then
		local name, realm = GetUnitNameRealm(dropdown.unit)
		if name and realm then
			return name, realm
		end
	end

	if dropdown.bnetIDAccount then
		local name, realm = GetNameRealmForBNetFriend(dropdown.bnetIDAccount)
		if name and realm then
			return name, realm
		end
	end

	if dropdown.menuList then
		for i = 1, #dropdown.menuList do
			local whisperButton = dropdown.menuList[i]
			if whisperButton and (whisperButton.text == WHISPER_LEADER or whisperButton.text == WHISPER) then
				local name, realm = SplitNameRealm(whisperButton.arg1)
				if name and realm then
					return name, realm
				end
			end
		end
	end

	local quickJoinMember = dropdown.quickJoinMember or (dropdown.quickJoinButton and dropdown.quickJoinButton.Members and dropdown.quickJoinButton.Members[1])
	if quickJoinMember and quickJoinMember.playerLink then
		local name, realm = GetNameRealmFromPlayerLink(quickJoinMember.playerLink)
		if name and realm then
			return name, realm
		end
	end

	return SplitNameRealm(dropdown.name, dropdown.server)
end

local function GetLFGListInfo(owner)
	if not owner then
		return nil, nil
	end

	if owner.resultID and C_LFGList and C_LFGList.GetSearchResultInfo then
		local searchResultInfo = C_LFGList.GetSearchResultInfo(owner.resultID)
		if searchResultInfo and searchResultInfo.leaderName then
			return SplitNameRealm(searchResultInfo.leaderName)
		end
	end

	if owner.memberIdx then
		local parent = owner.GetParent and owner:GetParent()
		if parent and parent.applicantID and C_LFGList and C_LFGList.GetApplicantMemberInfo then
			local fullName = C_LFGList.GetApplicantMemberInfo(parent.applicantID, owner.memberIdx)
			return SplitNameRealm(fullName)
		end
	end

	return nil, nil
end

local function GetNameRealmForMenu(owner, rootDescription, contextData)
	if not contextData then
		if rootDescription and VALID_MENU_TAGS[rootDescription.tag] then
			return GetLFGListInfo(owner)
		end
		return nil, nil
	end

	if contextData.unit then
		local name, realm = GetUnitNameRealm(contextData.unit)
		if name and realm then
			return name, realm
		end
	end

	if contextData.accountInfo then
		local name, realm = GetBNetNameRealm(contextData.accountInfo)
		if name and realm then
			return name, realm
		end
	end

	if contextData.playerLocation and contextData.playerLocation.IsUnit and contextData.playerLocation:IsUnit() then
		local unit = contextData.playerLocation:GetUnit()
		local name, realm = GetUnitNameRealm(unit)
		if name and realm then
			return name, realm
		end
	end

	if contextData.friendsList and C_FriendList and C_FriendList.GetFriendInfoByIndex then
		local friendInfo = C_FriendList.GetFriendInfoByIndex(contextData.friendsList)
		if friendInfo then
			local name, realm = SplitNameRealm(friendInfo.name)
			if name and realm then
				return name, realm
			end
		end
	end

	return SplitNameRealm(contextData.name, contextData.server)
end

local function GetWarcraftLogsProfileUrl(name, realm)
	name, realm = SplitNameRealm(name, realm)
	if not name or not realm then
		return nil
	end

	local realmSlug = SlugifyRealm(realm)
	if not realmSlug then
		return nil
	end

	return string.format("https://www.warcraftlogs.com/character/%s/%s/%s", GetRegion(), realmSlug, UrlEncode(name)), name, realm
end

StaticPopupDialogs[POPUP_ID] = {
	text = "%s",
	button2 = CLOSE,
	hasEditBox = true,
	hasWideEditBox = true,
	maxLetters = 0,
	editBoxWidth = 350,
	preferredIndex = 3,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnShow = function(self)
		self:SetWidth(420)
		local editBox = self.editBox or self.EditBox
		if not editBox then
			return
		end

		editBox:SetText(self.text_arg2 or self.data or "")
		editBox:SetFocus()
		editBox:HighlightText()

		local button = self.button2 or self.Button2 or (self.GetButton2 and self:GetButton2())
		if button then
			button:ClearAllPoints()
			button:SetWidth(200)
			button:SetPoint("CENTER", editBox, "CENTER", 0, -30)
		end
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
}

local function ShowCopyPopup(name, realm)
	local url, displayName, displayRealm = GetWarcraftLogsProfileUrl(name, realm)
	if not url then
		Print("Could not build a Warcraft Logs profile URL for this player.")
		return
	end

	if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatFrame_OpenChat then
		local editBox = ChatFrame_OpenChat(url, DEFAULT_CHAT_FRAME)
		if editBox then
			editBox:HighlightText()
		end
		return
	end

	StaticPopup_Show(POPUP_ID, string.format("%s (%s)", displayName, displayRealm), url, url)
end

local function IsValidMenu(rootDescription, contextData)
	if not contextData then
		return rootDescription and VALID_MENU_TAGS[rootDescription.tag]
	end

	return contextData.which and VALID_MENU_TYPES[contextData.which]
end

local function OnMenuShow(owner, rootDescription, contextData)
	if not IsEnabled() then
		return
	end

	if not IsValidMenu(rootDescription, contextData) then
		return
	end

	local name, realm = GetNameRealmForMenu(owner, rootDescription, contextData)
	if not name or not realm then
		return
	end

	rootDescription:CreateDivider()
	rootDescription:CreateTitle(ADDON_NAME)
	rootDescription:CreateButton(COPY_OPTION_TEXT, function()
		ShowCopyPopup(name, realm)
	end)
end

local function RegisterModernMenus()
	if not Menu or not Menu.ModifyMenu or not Menu.GetManager then
		return false
	end

	local menuManager = Menu.GetManager()
	if not menuManager then
		return false
	end

	local isInitialized = false
	local function Initialize()
		if isInitialized then
			return
		end
		isInitialized = true

		local callback = GenerateClosure and GenerateClosure(OnMenuShow) or OnMenuShow
		for menuType in pairs(VALID_MENU_TYPES) do
			Menu.ModifyMenu(string.format("MENU_UNIT_%s", menuType), callback)
		end
		for tag in pairs(VALID_MENU_TAGS) do
			Menu.ModifyMenu(tag, callback)
		end
	end

	Initialize()
	hooksecurefunc(menuManager, "OpenMenu", Initialize)
	hooksecurefunc(menuManager, "OpenContextMenu", Initialize)
	return true
end

local function RegisterLegacyMenus()
	if not UnitPopupButtons or not UnitPopupMenus then
		return
	end

	local buttonKey = "DORQUTILITIES_COPY_WARCRAFTLOGS_PROFILE"
	UnitPopupButtons[buttonKey] = { text = COPY_OPTION_TEXT, dist = 0 }

	for menuType in pairs(VALID_MENU_TYPES) do
		local menu = UnitPopupMenus[menuType]
		if type(menu) == "table" then
			local exists = false
			for _, key in ipairs(menu) do
				if key == buttonKey then
					exists = true
					break
				end
			end
			if not exists then
				table.insert(menu, buttonKey)
			end
		end
	end

	hooksecurefunc("UnitPopup_OnClick", function(self)
		local dropdownFrame = UIDROPDOWNMENU_INIT_MENU
		if self.value ~= buttonKey or not dropdownFrame then
			return
		end
		if not IsEnabled() then
			return
		end

		local name, realm
		if dropdownFrame.unit then
			name, realm = GetUnitNameRealm(dropdownFrame.unit)
		end
		if not name then
			name, realm = SplitNameRealm(dropdownFrame.name, dropdownFrame.server)
		end
		ShowCopyPopup(name, realm)
	end)
end

local function RegisterDropDownExtension()
	local LibDropDownExtension = LibStub and LibStub:GetLibrary("LibDropDownExtension-1.0", true)
	if not LibDropDownExtension then
		return
	end

	local selected = {}
	local options = {
		{
			text = ADDON_NAME,
			isTitle = true,
			notCheckable = true,
		},
		{
			text = COPY_OPTION_TEXT,
			notCheckable = true,
			func = function()
				ShowCopyPopup(selected.name, selected.realm)
			end,
		},
	}

	local function OnToggle(dropdown, event, extensionOptions)
		if not IsEnabled() then
			return
		end

		if event == "OnShow" then
			if not ((dropdown == LFGListFrameDropDown) or (type(dropdown.which) == "string" and VALID_MENU_TYPES[dropdown.which])) then
				return
			end

			selected.name, selected.realm = GetDropdownNameRealm(dropdown)
			if not selected.name or not selected.realm then
				return
			end

			if not extensionOptions[1] then
				extensionOptions[1] = options[1]
				extensionOptions[2] = options[2]
				return true
			end
		elseif event == "OnHide" then
			if extensionOptions[1] then
				for i = #extensionOptions, 1, -1 do
					extensionOptions[i] = nil
				end
				return true
			end
		end
	end

	LibDropDownExtension:RegisterEvent("OnShow OnHide", OnToggle, 1, module)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	if not RegisterModernMenus() then
		RegisterLegacyMenus()
	end
	RegisterDropDownExtension()
end)

module.GetWarcraftLogsProfileUrl = GetWarcraftLogsProfileUrl
module.ShowCopyPopup = ShowCopyPopup
