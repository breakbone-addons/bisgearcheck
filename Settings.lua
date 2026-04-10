-- BiSGearCheck Settings.lua
-- Standalone settings window + Interface Options proxy

BiSGearCheck = BiSGearCheck or {}

-- Current content phase on Anniversary servers (update when new phases launch)
local CURRENT_CONTENT_PHASE = 1

local PHASE_OPTIONS = {
    { value = 1, label = "Phase 1" },
    { value = 2, label = "Phase 2" },
}

-- Tag the current phase label
for _, opt in ipairs(PHASE_OPTIONS) do
    if opt.value == CURRENT_CONTENT_PHASE then
        opt.label = opt.label .. " (Current)"
    end
end

local PANEL_WIDTH = 440
local PANEL_HEIGHT = 560
local CONTENT_WIDTH = PANEL_WIDTH - 12 - 32 - 16  -- left inset, scrollbar, padding

-- ============================================================
-- Standalone settings window
-- ============================================================

local panel = CreateFrame("Frame", "BiSGearCheckSettingsPanel", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
panel:Hide()
tinsert(UISpecialFrames, "BiSGearCheckSettingsPanel")

-- Title bar
local titleBar = panel:CreateTexture(nil, "ARTWORK")
titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
titleBar:SetSize(280, 64)
titleBar:SetPoint("TOP", 0, 12)

local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOP", titleBar, "TOP", 0, -14)
titleText:SetText("BiSGearCheck Settings")

-- Close button
local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)

-- Scroll frame fills the panel below the title
local scrollFrame = CreateFrame("ScrollFrame", "BiSGearCheckSettingsScroll", panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 12, -32)
scrollFrame:SetPoint("BOTTOMRIGHT", -32, 12)

local scrollChild = CreateFrame("Frame", "BiSGearCheckSettingsScrollChild")
scrollChild:SetWidth(CONTENT_WIDTH)
scrollChild:SetHeight(800)
scrollFrame:SetScrollChild(scrollChild)

local SECTION_GAP = 16   -- vertical space between the end of one section and the header of the next

-- Helper: create a section header with a horizontal rule.
-- `prevEnd` is the previous section's end marker (or any anchor frame).
local function CreateSectionHeader(prevEnd, text)
    local header = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", prevEnd, "BOTTOMLEFT", 0, -SECTION_GAP)
    header:SetText("|cffffd100" .. text .. "|r")

    local line = scrollChild:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    line:SetWidth(CONTENT_WIDTH)
    line:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    return header, line
end

-- Helper: invisible anchor marking the bottom of a section.
-- Pass the last visible element and its bottom offset.
local function CreateSectionEnd(lastElement, yOffset)
    local marker = CreateFrame("Frame", nil, scrollChild)
    marker:SetSize(1, 1)
    marker:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, yOffset or 0)
    return marker
end

-- ============================================================
-- Section: Tooltips
-- ============================================================

-- Initial anchor at the top of the scroll content
local topAnchor = CreateFrame("Frame", nil, scrollChild)
topAnchor:SetSize(1, 1)
topAnchor:SetPoint("TOPLEFT", 12, 8)  -- offset so first SECTION_GAP lands at the right spot

local tooltipHeader, tooltipLine = CreateSectionHeader(topAnchor, "Tooltips")

local showBiSCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsShowBiS", scrollChild, "InterfaceOptionsCheckButtonTemplate")
showBiSCheck:SetPoint("TOPLEFT", tooltipLine, "BOTTOMLEFT", -4, -8)
showBiSCheck.Text = _G["BiSGearCheckSettingsShowBiSText"] or showBiSCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
showBiSCheck.Text:SetPoint("LEFT", showBiSCheck, "RIGHT", 4, 0)
showBiSCheck.Text:SetText("Show BiS rankings in tooltips")
showBiSCheck:SetScript("OnClick", function(self)
    BiSGearCheck:EnsureTooltipSettings()
    BiSGearCheckSaved.tooltip.showBiS = self:GetChecked() and true or false
    BiSGearCheckSaved.tooltip.conflictResolved = nil
    BiSGearCheckSaved.tooltip.conflictChoice = nil
end)

local showBiSReload = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
showBiSReload:SetPoint("LEFT", showBiSCheck.Text, "RIGHT", 8, 0)
showBiSReload:SetTextColor(0.6, 0.6, 0.6)
showBiSReload:SetText("Requires")

local reloadBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
reloadBtn:SetSize(60, 18)
reloadBtn:SetPoint("LEFT", showBiSReload, "RIGHT", 4, 0)
reloadBtn:SetText("Reload")
reloadBtn:SetScript("OnClick", function() ReloadUI() end)

local classCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsClassFilter", scrollChild, "InterfaceOptionsCheckButtonTemplate")
classCheck:SetPoint("TOPLEFT", showBiSCheck, "BOTTOMLEFT", 0, -4)
classCheck.Text = _G["BiSGearCheckSettingsClassFilterText"] or classCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
classCheck.Text:SetPoint("LEFT", classCheck, "RIGHT", 4, 0)
classCheck.Text:SetText("Show only my class in tooltips")
classCheck:SetScript("OnClick", function(self)
    BiSGearCheck:EnsureTooltipSettings()
    BiSGearCheckSaved.tooltip.showOnlyMyClass = self:GetChecked() and true or false
end)

local tooltipSectionEnd = CreateSectionEnd(classCheck, 0)

-- ============================================================
-- Helper: adaptive checkbox list (flat <=5, scrollable >5)
-- ============================================================

local SCROLL_THRESHOLD = 5
local ROW_HEIGHT = 26
local SCROLL_VISIBLE_ROWS = 5

-- Creates a container that holds checkboxes.
-- Returns { anchor, container, scrollChild, checkboxes }
-- anchor = the frame to chain the next section from
local function CreateCheckboxList(parent, anchorFrame, globalNamePrefix)
    -- Outer wrapper — always present, sized dynamically
    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
    wrapper:SetWidth(CONTENT_WIDTH)
    wrapper:SetHeight(1) -- resized at refresh time

    -- Scroll container (hidden when <=threshold)
    local sc = CreateFrame("Frame", nil, wrapper)
    sc:SetPoint("TOPLEFT")
    sc:SetSize(CONTENT_WIDTH, SCROLL_VISIBLE_ROWS * ROW_HEIGHT + 8)

    local scBg = sc:CreateTexture(nil, "BACKGROUND")
    scBg:SetAllPoints()
    scBg:SetColorTexture(0.05, 0.05, 0.05, 0.5)

    local sf = CreateFrame("ScrollFrame", globalNamePrefix .. "Scroll", sc, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 4, -4)
    sf:SetPoint("BOTTOMRIGHT", -24, 4)

    local sch = CreateFrame("Frame", globalNamePrefix .. "ScrollChild")
    sch:SetWidth(CONTENT_WIDTH - 32)
    sch:SetHeight(1)
    sf:SetScrollChild(sch)

    sc:Hide()

    return {
        wrapper = wrapper,
        scrollContainer = sc,
        scrollChild = sch,
        flatParent = wrapper,  -- flat checkboxes parent to wrapper directly
        checkboxes = {},
    }
end

-- Lay out N checkboxes in a list, switching between flat and scrollable.
-- cbParent is the parent for new checkboxes.
-- Returns nothing; mutates list.checkboxes and resizes list.wrapper.
local function LayoutCheckboxList(list, count)
    local useScroll = count > SCROLL_THRESHOLD
    if useScroll then
        list.scrollContainer:Show()
        list.wrapper:SetHeight(SCROLL_VISIBLE_ROWS * ROW_HEIGHT + 8)
        list.scrollChild:SetHeight(math.max(1, count * ROW_HEIGHT))
    else
        list.scrollContainer:Hide()
        list.wrapper:SetHeight(math.max(1, count * ROW_HEIGHT))
    end

    -- Re-parent and position existing checkboxes
    local parent = useScroll and list.scrollChild or list.flatParent
    for i, cb in ipairs(list.checkboxes) do
        if i <= count then
            cb:SetParent(parent)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            cb:Show()
        else
            cb:Hide()
        end
    end
end

-- ============================================================
-- Section: Data Sources
-- ============================================================

local sourcesHeader, sourcesLine = CreateSectionHeader(tooltipSectionEnd, "Data Sources")

-- Phase dropdown inside Data Sources section
local settingsPhaseDropdown = CreateFrame("Frame", "BiSGearCheckSettingsPhaseDropdown", scrollChild, "UIDropDownMenuTemplate")
settingsPhaseDropdown:SetPoint("TOPLEFT", sourcesLine, "BOTTOMLEFT", -16, -2)
UIDropDownMenu_SetWidth(settingsPhaseDropdown, 110)

local sourcesDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sourcesDesc:SetPoint("TOPLEFT", settingsPhaseDropdown, "BOTTOMLEFT", 16, -2)
sourcesDesc:SetTextColor(0.6, 0.6, 0.6)
sourcesDesc:SetText("Uncheck both to skip loading a source entirely. Requires")

local sourcesReloadBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
sourcesReloadBtn:SetSize(60, 18)
sourcesReloadBtn:SetPoint("LEFT", sourcesDesc, "RIGHT", 4, 0)
sourcesReloadBtn:SetText("Reload")
sourcesReloadBtn:SetScript("OnClick", function() ReloadUI() end)

-- Column layout constants
local COL_LABEL_X = 4
local COL_ADDON_X = 130
local COL_TOOLTIP_X = 195
local COL_SPECS_X = 262
local COL_ITEMS_X = 310
local TABLE_ROW_HEIGHT = 24

-- Table header row
local sourceTableHeader = CreateFrame("Frame", nil, scrollChild)
sourceTableHeader:SetPoint("TOPLEFT", sourcesDesc, "BOTTOMLEFT", 0, -8)
sourceTableHeader:SetSize(CONTENT_WIDTH, 16)

local hdrLabel = sourceTableHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrLabel:SetPoint("LEFT", sourceTableHeader, "LEFT", COL_LABEL_X, 0)
hdrLabel:SetText("|cffffd100Data Source|r")

local hdrAddon = sourceTableHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrAddon:SetPoint("LEFT", sourceTableHeader, "LEFT", COL_ADDON_X, 0)
hdrAddon:SetText("|cffffd100Addon|r")

local hdrTooltip = sourceTableHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrTooltip:SetPoint("LEFT", sourceTableHeader, "LEFT", COL_TOOLTIP_X, 0)
hdrTooltip:SetText("|cffffd100Tooltip|r")

local hdrSpecs = sourceTableHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrSpecs:SetPoint("LEFT", sourceTableHeader, "LEFT", COL_SPECS_X, 0)
hdrSpecs:SetText("|cffffd100Specs|r")

local hdrItems = sourceTableHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrItems:SetPoint("LEFT", sourceTableHeader, "LEFT", COL_ITEMS_X, 0)
hdrItems:SetText("|cffffd100Items|r")

-- Table rows
local sourceTableRows = {}

local sourceTableWrapper = CreateFrame("Frame", nil, scrollChild)
sourceTableWrapper:SetPoint("TOPLEFT", sourceTableHeader, "BOTTOMLEFT", 0, -4)
sourceTableWrapper:SetSize(CONTENT_WIDTH, #BiSGearCheck.DataSources * TABLE_ROW_HEIGHT)

for i, srcInfo in ipairs(BiSGearCheck.DataSources) do
    local row = CreateFrame("Frame", nil, sourceTableWrapper)
    row:SetSize(CONTENT_WIDTH, TABLE_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", sourceTableWrapper, "TOPLEFT", 0, -(i - 1) * TABLE_ROW_HEIGHT)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", row, "LEFT", COL_LABEL_X, 0)
    label:SetText(srcInfo.label)

    -- Info icon with tooltip description
    if srcInfo.desc then
        local infoBtn = CreateFrame("Button", nil, row)
        infoBtn:SetSize(14, 14)
        infoBtn:SetPoint("LEFT", label, "RIGHT", 4, 0)
        infoBtn:SetNormalTexture("Interface\\FriendsFrame\\InformationIcon")
        infoBtn:SetHighlightTexture("Interface\\FriendsFrame\\InformationIcon")
        infoBtn._desc = srcInfo.desc
        infoBtn._label = srcInfo.label
        infoBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self._label, 1, 0.82, 0)
            GameTooltip:AddLine(self._desc, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        infoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local addonCB = CreateFrame("CheckButton", "BiSGearCheckSrcAddon" .. i, row, "UICheckButtonTemplate")
    addonCB:SetSize(24, 24)
    addonCB:SetPoint("LEFT", row, "LEFT", COL_ADDON_X + 8, 0)
    addonCB._sourceKey = srcInfo.key
    addonCB:SetScript("OnClick", function(self)
        BiSGearCheck:EnsureSourceSettings()
        BiSGearCheckSaved.sourceSettings[self._sourceKey].addon = self:GetChecked() and true or false
        BiSGearCheck:OnSourceSettingsChanged()
    end)

    local tooltipCB = CreateFrame("CheckButton", "BiSGearCheckSrcTooltip" .. i, row, "UICheckButtonTemplate")
    tooltipCB:SetSize(24, 24)
    tooltipCB:SetPoint("LEFT", row, "LEFT", COL_TOOLTIP_X + 8, 0)
    tooltipCB._sourceKey = srcInfo.key
    tooltipCB:SetScript("OnClick", function(self)
        BiSGearCheck:EnsureSourceSettings()
        BiSGearCheckSaved.sourceSettings[self._sourceKey].tooltip = self:GetChecked() and true or false
        BiSGearCheck:OnSourceSettingsChanged()
    end)

    -- Stats columns: specs with data & unique item count
    local specsLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    specsLabel:SetPoint("LEFT", row, "LEFT", COL_SPECS_X, 0)

    local itemsLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemsLabel:SetPoint("LEFT", row, "LEFT", COL_ITEMS_X, 0)

    sourceTableRows[i] = { addonCB = addonCB, tooltipCB = tooltipCB, key = srcInfo.key,
                           specsLabel = specsLabel, itemsLabel = itemsLabel, srcInfo = srcInfo }
end

-- Refresh spec/item counts for the current phase
local function RefreshSourceStats()
    local phase = BiSGearCheck.phaseFilter or 1
    for _, rowData in ipairs(sourceTableRows) do
        local dbName = BiSGearCheck:GetSourceDBName(rowData.srcInfo, phase)
        local db = dbName and _G[dbName]
        local specCount, uniqueItems = 0, {}
        if db then
            for _, specData in pairs(db) do
                if specData.slots then
                    local hasItems = false
                    for _, items in pairs(specData.slots) do
                        for _, itemID in ipairs(items) do
                            uniqueItems[itemID] = true
                            hasItems = true
                        end
                    end
                    if hasItems then specCount = specCount + 1 end
                end
            end
        end
        local itemCount = 0
        for _ in pairs(uniqueItems) do itemCount = itemCount + 1 end
        rowData.specsLabel:SetText(specCount > 0 and tostring(specCount) or "-")
        rowData.itemsLabel:SetText(itemCount > 0 and tostring(itemCount) or "-")
    end
end

-- Initialize phase dropdown
local function PhaseDropdownInit(self, level)
    local currentPhase = BiSGearCheckSaved and BiSGearCheckSaved.phaseFilter or 1
    for _, opt in ipairs(PHASE_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.label
        info.value = opt.value
        info.func = function(self)
            UIDropDownMenu_SetSelectedValue(settingsPhaseDropdown, self.value)
            for _, o in ipairs(PHASE_OPTIONS) do
                if o.value == self.value then
                    UIDropDownMenu_SetText(settingsPhaseDropdown, o.label)
                    break
                end
            end
            BiSGearCheckSaved.phaseFilter = self.value
            BiSGearCheck.phaseFilter = self.value
            RefreshSourceStats()
            BiSGearCheck:OnPhaseChanged()
        end
        info.checked = (opt.value == currentPhase)
        UIDropDownMenu_AddButton(info, level)
    end
end
UIDropDownMenu_Initialize(settingsPhaseDropdown, PhaseDropdownInit)

-- Set initial state
local initPhase = BiSGearCheckSaved and BiSGearCheckSaved.phaseFilter or 1
for _, opt in ipairs(PHASE_OPTIONS) do
    if opt.value == initPhase then
        UIDropDownMenu_SetText(settingsPhaseDropdown, opt.label)
        break
    end
end
RefreshSourceStats()

local sourcesSectionEnd = CreateSectionEnd(sourceTableWrapper, 0)

-- ============================================================
-- Section: Zone Filters
-- ============================================================

local zoneHeader, zoneLine = CreateSectionHeader(sourcesSectionEnd, "Zone and Source Filters")

local classicCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsClassicZones", scrollChild, "UICheckButtonTemplate")
classicCheck:SetPoint("TOPLEFT", zoneLine, "BOTTOMLEFT", 0, -6)
_G["BiSGearCheckSettingsClassicZonesText"]:SetText("Include Classic zones (Molten Core, BWL, AQ, Naxx, etc.)")
classicCheck:SetScript("OnClick", function(self)
    BiSGearCheckSaved.includeClassicZones = self:GetChecked() and true or false
    BiSGearCheck:RefreshView()
end)

local pvpCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsIncludePvP", scrollChild, "UICheckButtonTemplate")
pvpCheck:SetPoint("TOPLEFT", classicCheck, "BOTTOMLEFT", 0, 0)
_G["BiSGearCheckSettingsIncludePvPText"]:SetText("Include PvP items (Honor, Arena, Marks)")
pvpCheck:SetScript("OnClick", function(self)
    BiSGearCheckSaved.includePvP = self:GetChecked() and true or false
    BiSGearCheck:RefreshView()
end)

local worldBossCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsIncludeWorldBoss", scrollChild, "UICheckButtonTemplate")
worldBossCheck:SetPoint("TOPLEFT", pvpCheck, "BOTTOMLEFT", 0, 0)
_G["BiSGearCheckSettingsIncludeWorldBossText"]:SetText("Include World Boss items (Doom Lord Kazzak, Doomwalker)")
worldBossCheck:SetScript("OnClick", function(self)
    BiSGearCheckSaved.includeWorldBoss = self:GetChecked() and true or false
    BiSGearCheck:RefreshView()
end)

local bopCraftedCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsFilterBoPCrafted", scrollChild, "UICheckButtonTemplate")
bopCraftedCheck:SetPoint("TOPLEFT", worldBossCheck, "BOTTOMLEFT", 0, 0)
_G["BiSGearCheckSettingsFilterBoPCraftedText"]:SetText("Include BoP crafted items from unknown professions")
bopCraftedCheck:SetScript("OnClick", function(self)
    BiSGearCheckSaved.includeBoPCraftedOther = self:GetChecked() and true or false
    BiSGearCheck:RefreshView()
end)

-- ============================================================
-- Section: Character Filters
-- ============================================================

local zoneSectionEnd = CreateSectionEnd(bopCraftedCheck, 0)

local charHeader, charLine = CreateSectionHeader(zoneSectionEnd, "Character Filters")

local levelLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
levelLabel:SetPoint("TOPLEFT", charLine, "BOTTOMLEFT", 0, -10)
levelLabel:SetText("Minimum Character Level:")

local levelSlider = CreateFrame("Slider", "BiSGearCheckSettingsLevelSlider", scrollChild, "OptionsSliderTemplate")
levelSlider:SetPoint("TOPLEFT", levelLabel, "BOTTOMLEFT", 0, -14)
levelSlider:SetWidth(200)
levelSlider:SetMinMaxValues(1, 70)
levelSlider:SetValueStep(1)
levelSlider:SetObeyStepOnDrag(true)
_G["BiSGearCheckSettingsLevelSliderLow"]:SetText("1")
_G["BiSGearCheckSettingsLevelSliderHigh"]:SetText("70")

-- Slider track background for visibility
local sliderBg = levelSlider:CreateTexture(nil, "BACKGROUND")
sliderBg:SetPoint("LEFT", 4, 0)
sliderBg:SetPoint("RIGHT", -4, 0)
sliderBg:SetHeight(6)
sliderBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

local levelValueText = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
levelValueText:SetPoint("LEFT", levelSlider, "RIGHT", 10, 0)

levelSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    levelValueText:SetText(tostring(value))
    if BiSGearCheckSaved then
        BiSGearCheckSaved.minCharLevel = value
    end
end)

local levelDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
levelDesc:SetPoint("TOPLEFT", levelSlider, "BOTTOMLEFT", 0, -8)
levelDesc:SetTextColor(0.5, 0.5, 0.5)
levelDesc:SetWidth(CONTENT_WIDTH)
levelDesc:SetWordWrap(true)
levelDesc:SetText("Characters below this level won't be saved or shown in the dropdown.")

local ignoreLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
ignoreLabel:SetPoint("TOPLEFT", levelDesc, "BOTTOMLEFT", 0, -16)
ignoreLabel:SetText("Character Ignore List:")

local ignoreDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ignoreDesc:SetPoint("TOPLEFT", ignoreLabel, "BOTTOMLEFT", 0, -4)
ignoreDesc:SetTextColor(0.5, 0.5, 0.5)
ignoreDesc:SetWidth(CONTENT_WIDTH)
ignoreDesc:SetWordWrap(true)
ignoreDesc:SetText("Ignored characters won't appear in the dropdown or be updated on login.")

local ignoreList = CreateCheckboxList(scrollChild, ignoreDesc, "BiSGearCheckIgnoreList")

-- ============================================================
-- Section: Inspected Characters
-- ============================================================

local charSectionEnd = CreateSectionEnd(ignoreList.wrapper, 0)

local inspectHeader, inspectLine = CreateSectionHeader(charSectionEnd, "Inspected Characters")

local autoShowCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsAutoShowInspect", scrollChild, "UICheckButtonTemplate")
autoShowCheck:SetPoint("TOPLEFT", inspectLine, "BOTTOMLEFT", 0, -6)
_G["BiSGearCheckSettingsAutoShowInspectText"]:SetText("Auto-show Compare tab when inspecting")
autoShowCheck:SetScript("OnClick", function(self)
    BiSGearCheckSaved.autoShowOnInspect = self:GetChecked() and true or false
end)

local showInDropdownCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsShowInspectedDropdown", scrollChild, "UICheckButtonTemplate")
showInDropdownCheck:SetPoint("TOPLEFT", autoShowCheck, "BOTTOMLEFT", 0, 0)
_G["BiSGearCheckSettingsShowInspectedDropdownText"]:SetText("Show inspected characters in Character dropdown")
showInDropdownCheck:SetScript("OnClick", function(self)
    BiSGearCheckSaved.showInspectedInDropdown = self:GetChecked() and true or false
end)

local inspectedListLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
inspectedListLabel:SetPoint("TOPLEFT", showInDropdownCheck, "BOTTOMLEFT", 0, -10)
inspectedListLabel:SetText("Saved Inspections:")

local inspectedListDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
inspectedListDesc:SetPoint("TOPLEFT", inspectedListLabel, "BOTTOMLEFT", 0, -4)
inspectedListDesc:SetTextColor(0.5, 0.5, 0.5)
inspectedListDesc:SetWidth(CONTENT_WIDTH)
inspectedListDesc:SetWordWrap(true)
inspectedListDesc:SetText("Click Remove to delete an inspected character's saved data.")

-- Remove All button
local removeAllBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
removeAllBtn:SetSize(80, 20)
removeAllBtn:SetPoint("TOPLEFT", inspectedListDesc, "BOTTOMLEFT", 0, -6)
removeAllBtn:SetText("Remove All")
removeAllBtn:SetScript("OnClick", function()
    if BiSGearCheckSaved and BiSGearCheckSaved.characters then
        for key, data in pairs(BiSGearCheckSaved.characters) do
            if data.inspected then
                BiSGearCheckSaved.characters[key] = nil
            end
        end
        -- Switch back to self if viewing an inspected char
        if BiSGearCheck:IsInspectedCharacter(BiSGearCheck.viewingCharKey) then
            BiSGearCheck:SetViewingCharacter(BiSGearCheck.playerKey)
        end
    end
    panel:Hide()
    panel:Show()
end)

-- Scrollable container for inspected character rows
local inspectedScOuter = CreateFrame("Frame", nil, scrollChild)
inspectedScOuter:SetPoint("TOPLEFT", removeAllBtn, "BOTTOMLEFT", 0, -4)
inspectedScOuter:SetSize(CONTENT_WIDTH, SCROLL_VISIBLE_ROWS * ROW_HEIGHT + 8)

local inspectedScBg = inspectedScOuter:CreateTexture(nil, "BACKGROUND")
inspectedScBg:SetAllPoints()
inspectedScBg:SetColorTexture(0.05, 0.05, 0.05, 0.5)

local inspectedSF = CreateFrame("ScrollFrame", "BiSGearCheckInspectedScroll", inspectedScOuter, "UIPanelScrollFrameTemplate")
inspectedSF:SetPoint("TOPLEFT", 4, -4)
inspectedSF:SetPoint("BOTTOMRIGHT", -24, 4)

local inspectedSCH = CreateFrame("Frame", "BiSGearCheckInspectedScrollChild")
inspectedSCH:SetWidth(CONTENT_WIDTH - 32)
inspectedSCH:SetHeight(1)
inspectedSF:SetScrollChild(inspectedSCH)

-- Wrapper that controls section height (switches between scroll and "no data" message)
local inspectedWrapper = CreateFrame("Frame", nil, scrollChild)
inspectedWrapper:SetPoint("TOPLEFT", removeAllBtn, "BOTTOMLEFT", 0, -4)
inspectedWrapper:SetWidth(CONTENT_WIDTH)
inspectedWrapper:SetHeight(1)

local inspectedNoData = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
inspectedNoData:SetPoint("TOPLEFT", inspectedWrapper, "TOPLEFT", 4, 0)
inspectedNoData:SetTextColor(0.5, 0.5, 0.5)
inspectedNoData:SetText("No inspected characters saved.")
inspectedNoData:Hide()

-- ============================================================
-- Section: Raid Scanning
-- ============================================================

local inspectSectionEnd = CreateSectionEnd(inspectedWrapper, 0)

local raidHeader, raidLine = CreateSectionHeader(inspectSectionEnd, "Raid Scanning")

local raidFilterNote = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
raidFilterNote:SetPoint("TOPLEFT", raidLine, "BOTTOMLEFT", 0, -6)
raidFilterNote:SetWidth(CONTENT_WIDTH)
raidFilterNote:SetJustifyH("LEFT")
raidFilterNote:SetText("|cff888888These filters apply to upgrade suggestions in the Raid tab.|r")

local raidClassicCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsRaidClassicZones", scrollChild, "UICheckButtonTemplate")
raidClassicCheck:SetPoint("TOPLEFT", raidFilterNote, "BOTTOMLEFT", 0, -4)
_G["BiSGearCheckSettingsRaidClassicZonesText"]:SetText("Include Classic zones (Molten Core, BWL, AQ, Naxx, etc.)")
raidClassicCheck:SetScript("OnClick", function(self)
    BiSGearCheckSaved.raidIncludeClassicZones = self:GetChecked() and true or false
    BiSGearCheck:RefreshView()
end)

local raidPvpCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsRaidIncludePvP", scrollChild, "UICheckButtonTemplate")
raidPvpCheck:SetPoint("TOPLEFT", raidClassicCheck, "BOTTOMLEFT", 0, 0)
_G["BiSGearCheckSettingsRaidIncludePvPText"]:SetText("Include PvP items (Honor, Arena, Marks)")
raidPvpCheck:SetScript("OnClick", function(self)
    BiSGearCheckSaved.raidIncludePvP = self:GetChecked() and true or false
    BiSGearCheck:RefreshView()
end)

local raidWorldBossCheck = CreateFrame("CheckButton", "BiSGearCheckSettingsRaidIncludeWorldBoss", scrollChild, "UICheckButtonTemplate")
raidWorldBossCheck:SetPoint("TOPLEFT", raidPvpCheck, "BOTTOMLEFT", 0, 0)
_G["BiSGearCheckSettingsRaidIncludeWorldBossText"]:SetText("Include World Boss items (Doom Lord Kazzak, Doomwalker)")
raidWorldBossCheck:SetScript("OnClick", function(self)
    BiSGearCheckSaved.raidIncludeWorldBoss = self:GetChecked() and true or false
    BiSGearCheck:RefreshView()
end)

local raidSectionEnd = CreateSectionEnd(raidWorldBossCheck, 0)

-- ============================================================
-- Section: About
-- ============================================================

local aboutHeader, aboutLine = CreateSectionHeader(raidSectionEnd, "About")

local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = getMetadata("BiSGearCheck", "Version") or "?"
local aboutVersion = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
aboutVersion:SetPoint("TOPLEFT", aboutLine, "BOTTOMLEFT", 0, -8)
aboutVersion:SetText("Version: |cffffd100" .. version .. "|r  March 23, 2026")

local aboutAuthor = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
aboutAuthor:SetPoint("TOPLEFT", aboutVersion, "BOTTOMLEFT", 0, -6)
aboutAuthor:SetText("Author: |cffffd100Breakbone - Dreamscythe|r")

local function CreateLinkRow(anchor, label, url)
    local row = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    row:SetText(label .. "  |cff69ccf0" .. url .. "|r")
    local btn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    btn:SetSize(50, 18)
    btn:SetPoint("LEFT", row, "RIGHT", 6, 0)
    btn:SetText("Copy")
    btn:SetScript("OnClick", function()
        local editBox = ChatFrame1EditBox or ChatFrame1.editBox
        if editBox then
            editBox:Show()
            editBox:SetText("https://" .. url)
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end)
    return row
end

local aboutCurse = CreateLinkRow(aboutAuthor, "CurseForge:", "curseforge.com/wow/addons/bisgearcheck")
local aboutGithub = CreateLinkRow(aboutCurse, "GitHub:", "github.com/breakbone-addons/bisgearcheck")
local aboutCoffee = CreateLinkRow(aboutGithub, "Support:", "buymeacoffee.com/breakbone")

-- Bottom spacer — used to calculate scroll child height
local bottomSpacer = scrollChild:CreateTexture(nil, "ARTWORK")
bottomSpacer:SetPoint("TOPLEFT", aboutCoffee, "BOTTOMLEFT", 0, -20)
bottomSpacer:SetSize(1, 1)

local function RefreshIgnoreList()
    for _, cb in ipairs(ignoreList.checkboxes) do
        cb:Hide()
    end

    local allKeys = BiSGearCheck:GetAllCharacterKeys()
    local charKeys = {}
    for _, key in ipairs(allKeys) do
        if not BiSGearCheck:IsInspectedCharacter(key) then
            charKeys[#charKeys + 1] = key
        end
    end

    for i, charKey in ipairs(charKeys) do
        local cb = ignoreList.checkboxes[i]
        if not cb then
            cb = CreateFrame("CheckButton", "BiSGearCheckIgnoreCB" .. i, ignoreList.flatParent, "UICheckButtonTemplate")
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            ignoreList.checkboxes[i] = cb
        end

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
    end

    LayoutCheckboxList(ignoreList, #charKeys)
end

-- ============================================================
-- Refresh controls when panel is shown
-- ============================================================

panel:SetScript("OnShow", function(self)
    BiSGearCheck:EnsureTooltipSettings()
    BiSGearCheck:EnsureSourceSettings()

    showBiSCheck:SetChecked(BiSGearCheckSaved.tooltip.showBiS)
    classCheck:SetChecked(BiSGearCheckSaved.tooltip.showOnlyMyClass)

    if BiSGearCheckSaved.includeClassicZones == nil then BiSGearCheckSaved.includeClassicZones = true end
    classicCheck:SetChecked(BiSGearCheckSaved.includeClassicZones)

    if BiSGearCheckSaved.includePvP == nil then BiSGearCheckSaved.includePvP = true end
    pvpCheck:SetChecked(BiSGearCheckSaved.includePvP)

    if BiSGearCheckSaved.includeWorldBoss == nil then BiSGearCheckSaved.includeWorldBoss = true end
    worldBossCheck:SetChecked(BiSGearCheckSaved.includeWorldBoss)

    if BiSGearCheckSaved.includeBoPCraftedOther == nil then BiSGearCheckSaved.includeBoPCraftedOther = true end
    bopCraftedCheck:SetChecked(BiSGearCheckSaved.includeBoPCraftedOther)

    -- PHASE SELECTION DISABLED
    -- local currentPhase = BiSGearCheckSaved.phaseFilter or 1
    -- UIDropDownMenu_SetText(settingsPhaseDropdown, PHASE_OPTIONS[currentPhase + 1].label)
    -- UIDropDownMenu_SetSelectedValue(settingsPhaseDropdown, currentPhase)

    for _, row in ipairs(sourceTableRows) do
        local s = BiSGearCheckSaved.sourceSettings[row.key]
        row.addonCB:SetChecked(s and s.addon ~= false)
        row.tooltipCB:SetChecked(s and s.tooltip ~= false)
    end

    local minLevel = BiSGearCheckSaved.minCharLevel or 64
    levelSlider:SetValue(minLevel)
    levelValueText:SetText(tostring(minLevel))

    RefreshIgnoreList()

    -- Inspect settings
    if BiSGearCheckSaved.autoShowOnInspect == nil then BiSGearCheckSaved.autoShowOnInspect = true end
    autoShowCheck:SetChecked(BiSGearCheckSaved.autoShowOnInspect)

    if BiSGearCheckSaved.showInspectedInDropdown == nil then BiSGearCheckSaved.showInspectedInDropdown = true end
    showInDropdownCheck:SetChecked(BiSGearCheckSaved.showInspectedInDropdown)

    BiSGearCheck:RefreshInspectedList()

    -- Raid scan filter defaults
    BiSGearCheck:EnsureRaidFilterSettings()
    raidClassicCheck:SetChecked(BiSGearCheckSaved.raidIncludeClassicZones)
    raidPvpCheck:SetChecked(BiSGearCheckSaved.raidIncludePvP)
    raidWorldBossCheck:SetChecked(BiSGearCheckSaved.raidIncludeWorldBoss)
end)

local inspectedRowPool = {}

function BiSGearCheck:RefreshInspectedList()
    if not BiSGearCheckSaved then return end
    for _, row in ipairs(inspectedRowPool) do row:Hide() end
    local inspectedKeys = {}
    if BiSGearCheckSaved.characters then
        for key, data in pairs(BiSGearCheckSaved.characters) do
            if data.inspected then
                table.insert(inspectedKeys, key)
            end
        end
    end
    table.sort(inspectedKeys)

    if #inspectedKeys == 0 then
        inspectedScOuter:Hide()
        inspectedNoData:Show()
        removeAllBtn:Hide()
        inspectedWrapper:SetHeight(20)
    else
        inspectedNoData:Hide()
        removeAllBtn:Show()
        local inspectY = 0
        for i, charKey in ipairs(inspectedKeys) do
            local charData = BiSGearCheckSaved.characters[charKey]
            local row = inspectedRowPool[i]
            if not row then
                row = CreateFrame("Frame", nil, inspectedSCH)
                row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.removeBtn:SetSize(60, 18)
                row.removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                row.removeBtn:SetText("Remove")
                row.removeBtn:SetScript("OnClick", function(self)
                    BiSGearCheck:RemoveInspectedCharacter(self._charKey)
                    panel:Hide()
                    panel:Show()
                end)
                inspectedRowPool[i] = row
            end
            row:SetSize(inspectedSCH:GetWidth(), ROW_HEIGHT)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", inspectedSCH, "TOPLEFT", 0, -inspectY)

            local classColor = charData and RAID_CLASS_COLORS[charData.class]
            local charName = charKey:match("^([^%-]+)") or charKey
            local realm = charKey:match("%-(.+)$") or ""
            if classColor then
                row.label:SetText(string.format("|cff%02x%02x%02x%s|r |cff888888%s L%d|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, charName, realm, charData.level or 0))
            else
                row.label:SetText(charName .. " " .. realm)
            end

            row.removeBtn._charKey = charKey
            row:Show()

            inspectY = inspectY + ROW_HEIGHT
        end
        inspectedSCH:SetHeight(math.max(inspectY, 1))

        -- Show scrollable if more than threshold, otherwise shrink to fit
        if #inspectedKeys > SCROLL_VISIBLE_ROWS then
            inspectedScOuter:SetHeight(SCROLL_VISIBLE_ROWS * ROW_HEIGHT + 8)
            inspectedScOuter:Show()
            inspectedWrapper:SetHeight(SCROLL_VISIBLE_ROWS * ROW_HEIGHT + 8)
        else
            inspectedScOuter:SetHeight(inspectY + 8)
            inspectedScOuter:Show()
            inspectedWrapper:SetHeight(inspectY + 8)
        end
    end

    -- Recalculate scroll child height after layout settles
    C_Timer.After(0, function()
        local top = scrollChild:GetTop()
        local bottom = bottomSpacer:GetBottom()
        if top and bottom and (top - bottom) > 0 then
            scrollChild:SetHeight(top - bottom)
        end
    end)
end

-- ============================================================
-- Public API: open settings (from gear icon or slash command)
-- ============================================================

function BiSGearCheck:ShowSettings()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

-- ============================================================
-- Register proxy in Interface Options (Esc > Options > AddOns)
-- ============================================================

local proxy = CreateFrame("Frame", "BiSGearCheckSettingsProxy", UIParent)
proxy.name = "BiSGearCheck"

local proxyText = proxy:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
proxyText:SetPoint("TOPLEFT", 16, -16)
proxyText:SetText("BiSGearCheck")

local proxyBtn = CreateFrame("Button", nil, proxy, "UIPanelButtonTemplate")
proxyBtn:SetSize(160, 26)
proxyBtn:SetPoint("TOPLEFT", proxyText, "BOTTOMLEFT", 0, -12)
proxyBtn:SetText("Open Settings Window")
proxyBtn:SetScript("OnClick", function() BiSGearCheck:ShowSettings() end)

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(proxy, proxy.name)
    Settings.RegisterAddOnCategory(category)
    BiSGearCheck.settingsCategoryID = category:GetID()
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(proxy)
end
