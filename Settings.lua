-- BiSGearCheck Settings.lua
-- Interface Options panel for tooltip preferences

BiSGearCheck = BiSGearCheck or {}

local panel = CreateFrame("Frame", "BiSGearCheckSettingsPanel", UIParent)
panel.name = "BiS Gear Check"

local SOURCE_OPTIONS = {
    { key = "all",       label = "Both Sources" },
    { key = "wowtbcgg",  label = "WowTBC.gg" },
    { key = "atlasloot", label = "AtlasLoot" },
}

-- ============================================================
-- Title
-- ============================================================

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("BiS Gear Check Settings")

-- ============================================================
-- Checkbox: Show BiS rankings in tooltips
-- ============================================================

local showBiSCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsShowBiS", panel, "InterfaceOptionsCheckButtonTemplate")
showBiSCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
showBiSCheck.Text = _G["BiSGearCheckSettingsShowBiSText"] or showBiSCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
showBiSCheck.Text:SetPoint("LEFT", showBiSCheck, "RIGHT", 4, 0)
showBiSCheck.Text:SetText("Show BiS rankings in tooltips")
showBiSCheck:SetScript("OnClick", function(self)
    BiSGearCheck:EnsureTooltipSettings()
    BiSGearCheckSaved.tooltip.showBiS = self:GetChecked() and true or false
    -- Clear conflict resolution so the dialog reappears on next reload
    BiSGearCheckSaved.tooltip.conflictResolved = nil
    BiSGearCheckSaved.tooltip.conflictChoice = nil
end)

local reloadBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reloadBtn:SetSize(70, 22)
reloadBtn:SetPoint("LEFT", showBiSCheck.Text, "RIGHT", 10, 0)
reloadBtn:SetText("Reload")
reloadBtn:SetScript("OnClick", function() ReloadUI() end)

-- ============================================================
-- Checkbox: Show only my class
-- ============================================================

local classCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsClassFilter", panel, "InterfaceOptionsCheckButtonTemplate")
classCheck:SetPoint("TOPLEFT", showBiSCheck, "BOTTOMLEFT", 0, -8)
classCheck.Text = _G["BiSGearCheckSettingsClassFilterText"] or classCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
classCheck.Text:SetPoint("LEFT", classCheck, "RIGHT", 4, 0)
classCheck.Text:SetText("Show only my class")
classCheck:SetScript("OnClick", function(self)
    BiSGearCheck:EnsureTooltipSettings()
    BiSGearCheckSaved.tooltip.showOnlyMyClass = self:GetChecked() and true or false
end)

-- ============================================================
-- Dropdown: Tooltip Data Source
-- ============================================================

local sourceLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sourceLabel:SetPoint("TOPLEFT", classCheck, "BOTTOMLEFT", 4, -20)
sourceLabel:SetText("Tooltip Data Source:")

local sourceDropdown = CreateFrame("Frame", "BiSGearCheckSettingsSourceDropdown", panel, "UIDropDownMenuTemplate")
sourceDropdown:SetPoint("TOPLEFT", sourceLabel, "BOTTOMLEFT", -16, -4)
UIDropDownMenu_SetWidth(sourceDropdown, 180)

local function SourceDropdownInit(self, level)
    BiSGearCheck:EnsureTooltipSettings()
    for _, src in ipairs(SOURCE_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = src.label
        info.value = src.key
        info.func = function(self)
            UIDropDownMenu_SetSelectedValue(sourceDropdown, self.value)
            UIDropDownMenu_SetText(sourceDropdown, self:GetText())
            BiSGearCheckSaved.tooltip.dataSource = self.value
        end
        info.checked = (src.key == (BiSGearCheckSaved and BiSGearCheckSaved.tooltip and BiSGearCheckSaved.tooltip.dataSource or "all"))
        UIDropDownMenu_AddButton(info, level)
    end
end
UIDropDownMenu_Initialize(sourceDropdown, SourceDropdownInit)

-- ============================================================
-- Separator: Character Filters
-- ============================================================

local charFilterHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
charFilterHeader:SetPoint("TOPLEFT", sourceDropdown, "BOTTOMLEFT", 16, -16)
charFilterHeader:SetText("|cffffd100Character Filters|r")

-- ============================================================
-- Slider: Minimum Character Level
-- ============================================================

local levelLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
levelLabel:SetPoint("TOPLEFT", charFilterHeader, "BOTTOMLEFT", 0, -12)
levelLabel:SetText("Minimum Character Level:")

local levelSlider = CreateFrame("Slider", "BiSGearCheckSettingsLevelSlider", panel, "OptionsSliderTemplate")
levelSlider:SetPoint("TOPLEFT", levelLabel, "BOTTOMLEFT", 0, -12)
levelSlider:SetWidth(200)
levelSlider:SetMinMaxValues(1, 70)
levelSlider:SetValueStep(1)
levelSlider:SetObeyStepOnDrag(true)
_G["BiSGearCheckSettingsLevelSliderLow"]:SetText("1")
_G["BiSGearCheckSettingsLevelSliderHigh"]:SetText("70")

local levelValueText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
levelValueText:SetPoint("LEFT", levelSlider, "RIGHT", 10, 0)

levelSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    levelValueText:SetText(tostring(value))
    if BiSGearCheckSaved then
        BiSGearCheckSaved.minCharLevel = value
    end
end)

local levelDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
levelDesc:SetPoint("TOPLEFT", levelSlider, "BOTTOMLEFT", 0, -6)
levelDesc:SetTextColor(0.5, 0.5, 0.5)
levelDesc:SetText("Characters below this level won't be saved or shown in the dropdown.")

-- ============================================================
-- Character Ignore List
-- ============================================================

local ignoreHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ignoreHeader:SetPoint("TOPLEFT", levelDesc, "BOTTOMLEFT", 0, -16)
ignoreHeader:SetText("Character Ignore List:")

local ignoreDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ignoreDesc:SetPoint("TOPLEFT", ignoreHeader, "BOTTOMLEFT", 0, -4)
ignoreDesc:SetTextColor(0.5, 0.5, 0.5)
ignoreDesc:SetText("Ignored characters won't appear in the dropdown or be updated on login.")

-- Scrollable container for character checkboxes
local ignoreContainer = CreateFrame("Frame", nil, panel)
ignoreContainer:SetPoint("TOPLEFT", ignoreDesc, "BOTTOMLEFT", 0, -8)
ignoreContainer:SetSize(300, 140)

local ignoreBg = ignoreContainer:CreateTexture(nil, "BACKGROUND")
ignoreBg:SetAllPoints()
ignoreBg:SetColorTexture(0.05, 0.05, 0.05, 0.5)

local ignoreScrollFrame = CreateFrame("ScrollFrame", "BiSGearCheckIgnoreScroll", ignoreContainer, "UIPanelScrollFrameTemplate")
ignoreScrollFrame:SetPoint("TOPLEFT", 4, -4)
ignoreScrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

local ignoreScrollChild = CreateFrame("Frame", "BiSGearCheckIgnoreScrollChild")
ignoreScrollChild:SetWidth(260)
ignoreScrollChild:SetHeight(1)
ignoreScrollFrame:SetScrollChild(ignoreScrollChild)

-- Storage for dynamically created checkboxes
local ignoreCheckboxes = {}

local function RefreshIgnoreList()
    -- Hide existing checkboxes
    for _, cb in ipairs(ignoreCheckboxes) do
        cb:Hide()
    end

    local charKeys = BiSGearCheck:GetAllCharacterKeys()
    local yOffset = 0

    for i, charKey in ipairs(charKeys) do
        local cb = ignoreCheckboxes[i]
        if not cb then
            cb = CreateFrame("CheckButton", "BiSGearCheckIgnoreCB" .. i, ignoreScrollChild, "UICheckButtonTemplate")
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            ignoreCheckboxes[i] = cb
        end

        cb:SetPoint("TOPLEFT", ignoreScrollChild, "TOPLEFT", 0, yOffset)
        cb:SetSize(24, 24)

        local charData = BiSGearCheckSaved and BiSGearCheckSaved.characters and BiSGearCheckSaved.characters[charKey]
        local charName = charKey:match("^([^-]+)") or charKey
        local realm = charKey:match("-(.+)$") or ""
        local classColor = charData and RAID_CLASS_COLORS[charData.class]
        local levelStr = charData and charData.level and (" L" .. charData.level) or ""

        if classColor then
            cb.text:SetText(string.format("|cff%02x%02x%02x%s|r|cff888888-%s%s|r",
                classColor.r * 255, classColor.g * 255, classColor.b * 255,
                charName, realm, levelStr))
        else
            cb.text:SetText(charName .. "|cff888888-" .. realm .. levelStr .. "|r")
        end

        cb:SetChecked(BiSGearCheck:IsCharacterIgnored(charKey))
        cb._charKey = charKey
        cb:SetScript("OnClick", function(self)
            if self:GetChecked() then
                BiSGearCheck:IgnoreCharacter(self._charKey)
            else
                BiSGearCheck:UnignoreCharacter(self._charKey)
            end
        end)

        cb:Show()
        yOffset = yOffset - 26
    end

    ignoreScrollChild:SetHeight(math.max(1, math.abs(yOffset)))
end

-- ============================================================
-- Refresh controls when panel is shown
-- ============================================================

panel:SetScript("OnShow", function(self)
    BiSGearCheck:EnsureTooltipSettings()
    showBiSCheck:SetChecked(BiSGearCheckSaved.tooltip.showBiS)
    classCheck:SetChecked(BiSGearCheckSaved.tooltip.showOnlyMyClass)

    local currentSource = BiSGearCheckSaved.tooltip.dataSource or "all"
    for _, src in ipairs(SOURCE_OPTIONS) do
        if src.key == currentSource then
            UIDropDownMenu_SetText(sourceDropdown, src.label)
            UIDropDownMenu_SetSelectedValue(sourceDropdown, src.key)
            break
        end
    end

    -- Refresh character filter controls
    local minLevel = BiSGearCheckSaved.minCharLevel or 70
    levelSlider:SetValue(minLevel)
    levelValueText:SetText(tostring(minLevel))

    RefreshIgnoreList()
end)

-- ============================================================
-- Register in Interface Options
-- ============================================================

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    BiSGearCheck.settingsCategoryID = category:GetID()
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end
