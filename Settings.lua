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
