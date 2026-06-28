-------------------------------------------------------------------------------
-- Title: DorqUtilities Options
-------------------------------------------------------------------------------

local Profiles = DorqUtilities.Profiles
local Print = DorqUtilities.Print

local settingsPanel
local checkButtons = {}

local function RefreshCheckButtons()
	for _, button in ipairs(checkButtons) do
		button:SetChecked(Profiles.IsFeatureEnabled(button.feature))
	end
end

local function RefreshRuntimeState()
	local core = DorqUtilities.Core
	if core and core.RefreshReadyAlertStates then
		core.RefreshReadyAlertStates()
	end
	if core and core.RefreshSoundChannelCap then
		core.RefreshSoundChannelCap()
	end
end

local function CreateWrappedText(parent, template, width, text, xOffset, yOffset)
	local label = parent:CreateFontString(nil, "ARTWORK", template)
	label:SetWidth(width)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("TOP")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
	label:SetText(text)
	return label
end

local function CreateFeatureRow(parent, feature, xOffset, yOffset, rowWidth)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
	row:SetWidth(rowWidth)

	local button = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	button:SetSize(26, 26)
	button:SetHitRectInsets(0, -(rowWidth - 26), 0, 0)
	button:SetChecked(Profiles.IsFeatureEnabled(feature))
	button.feature = feature

	local title = CreateWrappedText(row, "GameFontNormal", rowWidth - 36, feature.label, 34, -5)
	local displayText = CreateWrappedText(row, "GameFontHighlightSmall", rowWidth - 36, "Display: " .. (feature.displayNote or "Default notification area."), 34, -(title:GetStringHeight() + 8))

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(feature.label)
		if feature.tooltip then
			GameTooltip:AddLine(feature.tooltip, 1, 1, 1, true)
		end
		if feature.displayNote then
			GameTooltip:AddLine("Display: " .. feature.displayNote, 0.8, 0.8, 0.8, true)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnClick", function(self)
		Profiles.SetFeatureEnabled(feature, self:GetChecked())
		RefreshRuntimeState()
		RefreshCheckButtons()
	end)

	local rowHeight = math.max(26, title:GetStringHeight() + displayText:GetStringHeight() + 12)
	row:SetHeight(rowHeight)
	checkButtons[#checkButtons + 1] = button
	return row, rowHeight
end

local function BuildSettingsPanel(panel)
	if panel.content then
		return
	end

	local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
	scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 8)
	panel.scrollFrame = scrollFrame

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(1, 1)
	scrollFrame:SetScrollChild(content)
	panel.content = content

	local contentWidth = 680
	local leftPadding = 16
	local currentY = -16
	content:SetWidth(contentWidth)

	local intro = CreateWrappedText(
		content,
		"GameFontHighlightSmall",
		contentWidth - 32,
		"Toggle each remaining DorqUtilities feature on or off below. Each option includes where it appears or is accessed.",
		leftPadding,
		currentY
	)
	currentY = currentY - intro:GetStringHeight() - 18

	for _, group in ipairs(Profiles.featureGroups) do
		local header = CreateWrappedText(content, "GameFontNormalLarge", contentWidth - 32, group.title, leftPadding, currentY)
		currentY = currentY - header:GetStringHeight() - 6

		local details = CreateWrappedText(content, "GameFontHighlightSmall", contentWidth - 32, group.description, leftPadding, currentY)
		currentY = currentY - details:GetStringHeight() - 12

		for _, feature in ipairs(group.features) do
			local _, rowHeight = CreateFeatureRow(content, feature, leftPadding, currentY, contentWidth - 32)
			currentY = currentY - rowHeight - 10
		end

		currentY = currentY - 4
	end

	local resetButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	resetButton:SetSize(140, 24)
	resetButton:SetPoint("TOPLEFT", content, "TOPLEFT", leftPadding, currentY)
	resetButton:SetText("Reset Toggles")
	resetButton:SetScript("OnClick", function()
		Profiles.ResetFeatureToggles()
		RefreshRuntimeState()
		RefreshCheckButtons()
		Print("DorqUtilities major feature toggles were reset to their defaults.")
	end)

	local slashHint = CreateWrappedText(content, "GameFontDisableSmall", contentWidth - 200, "Use /dorq to jump to this settings page.", leftPadding + 156, currentY - 4)
	currentY = currentY - math.max(24, slashHint:GetStringHeight()) - 20

	content:SetHeight(-currentY + 24)
end

local function EnsureSettingsPanel()
	if settingsPanel then
		return settingsPanel
	end

	settingsPanel = CreateFrame("Frame", "DorqUtilitiesSettingsPanel", UIParent)
	settingsPanel.name = "DorqUtilities"
	settingsPanel:SetScript("OnShow", function(self)
		BuildSettingsPanel(self)
		RefreshCheckButtons()
		if self.scrollFrame then
			self.scrollFrame:SetVerticalScroll(0)
		end
	end)

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
		Settings.RegisterAddOnCategory(category)
		settingsPanel.settingsCategory = category
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(settingsPanel)
	end

	return settingsPanel
end

function Profiles.OpenOptions()
	local panel = EnsureSettingsPanel()
	if panel.settingsCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(panel.settingsCategory.ID)
		return
	end

	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

function Profiles.ToggleOptions()
	Profiles.OpenOptions()
end

EnsureSettingsPanel()
