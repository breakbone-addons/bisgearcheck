-- BiSGearCheck UIControls.lua
-- Tabs, character selector, data source/spec dropdowns, collapse controls, BiS Lists bar

BiSGearCheck = BiSGearCheck or {}

-- ============================================================
-- TABS: Compare + Wishlist + BiS Lists
-- ============================================================

function BiSGearCheck:SetupTabs(f)
    local TAB_WIDTH = 80
    local TAB_HEIGHT = 22

    local function CreateTab(parent, text, index)
        local tab = CreateFrame("Button", "BiSGearCheckTab" .. index, parent)
        tab:SetSize(TAB_WIDTH, TAB_HEIGHT)

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        tab.bg = bg

        local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", 0, 0)
        label:SetText(text)
        tab.label = label

        return tab
    end

    local compTab = CreateTab(f, "Compare", 1)
    compTab:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)

    local wlTab = CreateTab(f, "Wishlists", 2)
    wlTab:SetPoint("LEFT", compTab, "RIGHT", 2, 0)

    local bisTab = CreateTab(f, "BiS Lists", 3)
    bisTab:SetPoint("LEFT", wlTab, "RIGHT", 2, 0)

    local function SetTabActive(tab)
        tab.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        tab.label:SetTextColor(1, 0.82, 0)
    end
    local function SetTabInactive(tab)
        tab.bg:SetColorTexture(0.08, 0.08, 0.08, 0.8)
        tab.label:SetTextColor(0.5, 0.5, 0.5)
    end

    local function UpdateTabAppearance()
        local mode = BiSGearCheck.viewMode
        if mode == "comparison" then
            SetTabActive(compTab)
            SetTabInactive(wlTab)
            SetTabInactive(bisTab)
        elseif mode == "wishlist" then
            SetTabInactive(compTab)
            SetTabActive(wlTab)
            SetTabInactive(bisTab)
        elseif mode == "bislist" then
            SetTabInactive(compTab)
            SetTabInactive(wlTab)
            SetTabActive(bisTab)
        end
    end

    compTab:SetScript("OnClick", function()
        BiSGearCheck.viewMode = "comparison"
        UpdateTabAppearance()
        BiSGearCheck:Refresh()
    end)

    wlTab:SetScript("OnClick", function()
        BiSGearCheck.viewMode = "wishlist"
        UpdateTabAppearance()
        BiSGearCheck:RefreshView()
    end)

    bisTab:SetScript("OnClick", function()
        BiSGearCheck.viewMode = "bislist"
        UpdateTabAppearance()
        BiSGearCheck:RefreshView()
    end)

    -- Gear icon button to open settings
    local settingsBtn = CreateFrame("Button", "BiSGearCheckSettingsBtn", f)
    settingsBtn:SetSize(20, 20)
    settingsBtn:SetPoint("RIGHT", f, "TOPRIGHT", -38, -20)

    local settingsIcon = settingsBtn:CreateTexture(nil, "ARTWORK")
    settingsIcon:SetAllPoints()
    settingsIcon:SetTexture("Interface\\Scenarios\\ScenarioIcon-Interact")
    settingsIcon:SetVertexColor(0.8, 0.8, 0.8)
    settingsBtn.icon = settingsIcon

    settingsBtn:SetScript("OnClick", function()
        BiSGearCheck:ShowSettings()
    end)
    settingsBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Settings")
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.8, 0.8, 0.8)
        GameTooltip:Hide()
    end)

    f.compTab = compTab
    f.wlTab = wlTab
    f.bisTab = bisTab
    f.settingsBtn = settingsBtn
    f.UpdateTabAppearance = UpdateTabAppearance
end

-- ============================================================
-- CHARACTER SELECTOR (top-level, right of tabs)
-- ============================================================

function BiSGearCheck:SetupCharacterSelector(f)
    local charDropdown = CreateFrame("Frame", "BiSGearCheckCharDropdown", f, "UIDropDownMenuTemplate")
    charDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -32)
    UIDropDownMenu_SetWidth(charDropdown, 130)
    UIDropDownMenu_JustifyText(charDropdown, "RIGHT")

    local function CharDropdownInit(self, level)
        local charKeys = BiSGearCheck:GetCharacterKeys()
        for _, charKey in ipairs(charKeys) do
            local charData = BiSGearCheck:GetCharacterData(charKey)
            local info = UIDropDownMenu_CreateInfo()
            local classColor = charData and RAID_CLASS_COLORS[charData.class]
            local charName = charKey:match("^([^-]+)") or charKey
            if classColor then
                info.text = string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, charName)
            else
                info.text = charName
            end
            info.value = charKey
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(charDropdown, self.value)
                BiSGearCheck:UpdateCharDropdownText()
                BiSGearCheck:SetViewingCharacter(self.value)
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(charDropdown, CharDropdownInit)

    f.charDropdown = charDropdown

    -- Helper to update character dropdown text with class color
    function BiSGearCheck:UpdateCharDropdownText()
        local ck = self:GetViewingCharKey()
        local cd = self:GetCharacterData(ck)
        local cn = ck and ck:match("^([^-]+)") or ck
        local cc = cd and RAID_CLASS_COLORS[cd.class]
        if cc and cn then
            UIDropDownMenu_SetText(f.charDropdown, string.format("|cff%02x%02x%02x%s|r", cc.r * 255, cc.g * 255, cc.b * 255, cn))
        elseif cn then
            UIDropDownMenu_SetText(f.charDropdown, cn)
        end
    end
    self:UpdateCharDropdownText()
end

-- ============================================================
-- DATA SOURCE + SPEC DROPDOWNS (below tabs)
-- ============================================================

function BiSGearCheck:SetupSourceSpecDropdowns(f)
    -- Data source dropdown
    local sourceDropdown = CreateFrame("Frame", "BiSGearCheckSourceDropdown", f, "UIDropDownMenuTemplate")
    sourceDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -5, -60)
    UIDropDownMenu_SetWidth(sourceDropdown, 100)

    local function SourceDropdownInit(self, level)
        for _, srcInfo in ipairs(BiSGearCheck:GetEnabledDataSourcesForPhase()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = srcInfo.label
            info.value = srcInfo.key
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(sourceDropdown, self.value)
                UIDropDownMenu_SetText(sourceDropdown, self:GetText())
                BiSGearCheck:SetDataSource(self.value)
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(sourceDropdown, SourceDropdownInit)

    -- Set initial source text
    for _, srcInfo in ipairs(self:GetEnabledDataSourcesForPhase()) do
        if srcInfo.key == self.dataSource then
            UIDropDownMenu_SetText(sourceDropdown, srcInfo.label)
            UIDropDownMenu_SetSelectedValue(sourceDropdown, srcInfo.key)
            break
        end
    end

    -- Spec dropdown
    local specDropdown = CreateFrame("Frame", "BiSGearCheckSpecDropdown", f, "UIDropDownMenuTemplate")
    specDropdown:SetPoint("LEFT", sourceDropdown, "RIGHT", -15, 0)
    UIDropDownMenu_SetWidth(specDropdown, 120)

    local function SpecDropdownInit(self, level)
        local classToken = BiSGearCheck:GetViewingClass()
        local specs = classToken and BiSGearCheck.ClassSpecs[classToken]
        if not specs then return end

        local db = BiSGearCheck:GetActiveDB()
        for _, specInfo in ipairs(specs) do
            if db and db[specInfo.key] then
                local info = UIDropDownMenu_CreateInfo()
                info.text = specInfo.label
                info.value = specInfo.key
                info.func = function(self)
                    UIDropDownMenu_SetSelectedValue(specDropdown, self.value)
                    UIDropDownMenu_SetText(specDropdown, self:GetText())
                    BiSGearCheck:SetSpec(self.value)
                end
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end
    UIDropDownMenu_Initialize(specDropdown, SpecDropdownInit)

    if self.selectedSpec then
        local db = self:GetActiveDB()
        if db and db[self.selectedSpec] then
            UIDropDownMenu_SetText(specDropdown, db[self.selectedSpec].spec)
            UIDropDownMenu_SetSelectedValue(specDropdown, self.selectedSpec)
        end
    end

    f.sourceDropdown = sourceDropdown
    f.specDropdown = specDropdown
end

-- ============================================================
-- COLLAPSE ALL / EXPAND ALL + COMPARE TAB WISHLIST PICKER
-- ============================================================

function BiSGearCheck:SetupCollapseControls(f)
    local collapseAllBtn = CreateFrame("Button", nil, f)
    collapseAllBtn:SetSize(70, 16)
    collapseAllBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -92)
    local collapseText = collapseAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collapseText:SetPoint("LEFT")
    collapseText:SetText("|cff00ccffCollapse All|r")
    collapseAllBtn:SetScript("OnClick", function()
        for _, slotName in ipairs(BiSGearCheck.SlotOrder) do
            BiSGearCheck.collapsedSlots[slotName] = true
        end
        BiSGearCheck:RefreshView()
    end)
    collapseAllBtn:SetScript("OnEnter", function(self) collapseText:SetText("|cffffffffCollapse All|r") end)
    collapseAllBtn:SetScript("OnLeave", function(self) collapseText:SetText("|cff00ccffCollapse All|r") end)

    local expandAllBtn = CreateFrame("Button", nil, f)
    expandAllBtn:SetSize(65, 16)
    expandAllBtn:SetPoint("LEFT", collapseAllBtn, "RIGHT", 5, 0)
    local expandText = expandAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expandText:SetPoint("LEFT")
    expandText:SetText("|cff00ccffExpand All|r")
    expandAllBtn:SetScript("OnClick", function()
        for _, slotName in ipairs(BiSGearCheck.SlotOrder) do
            BiSGearCheck.collapsedSlots[slotName] = false
        end
        BiSGearCheck:RefreshView()
    end)
    expandAllBtn:SetScript("OnEnter", function(self) expandText:SetText("|cffffffffExpand All|r") end)
    expandAllBtn:SetScript("OnLeave", function(self) expandText:SetText("|cff00ccffExpand All|r") end)

    -- Wishlist picker (right-aligned, shown on Compare tab)
    local compareWLDropdown = CreateFrame("Frame", "BiSGearCheckCompareWLDropdown", f, "UIDropDownMenuTemplate")
    compareWLDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -90)
    UIDropDownMenu_SetWidth(compareWLDropdown, 130)
    UIDropDownMenu_JustifyText(compareWLDropdown, "RIGHT")

    local function CompareWLDropdownInit(self, level)
        local names = BiSGearCheck:GetWishlistNames()
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(compareWLDropdown, self.value)
                UIDropDownMenu_SetText(compareWLDropdown, self.value)
                BiSGearCheck:SetActiveWishlist(self.value)
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(compareWLDropdown, CompareWLDropdownInit)
    UIDropDownMenu_SetText(compareWLDropdown, self.activeWishlist)
    compareWLDropdown:Hide()

    local compareWLLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    compareWLLabel:SetPoint("RIGHT", compareWLDropdown, "LEFT", 15, 2)
    compareWLLabel:SetText("|cffffd100Wishlist:|r")
    compareWLLabel:Hide()

    -- Zone filter dropdown (shown on Compare and BiS Lists tabs, positioned dynamically)
    local zoneFilterDropdown = CreateFrame("Frame", "BiSGearCheckZoneFilterDropdown", f, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(zoneFilterDropdown, 130)

    local function ZoneFilterInit(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "All Zones"
        info.value = ""
        info.func = function()
            UIDropDownMenu_SetSelectedValue(zoneFilterDropdown, "")
            UIDropDownMenu_SetText(zoneFilterDropdown, "All Zones")
            BiSGearCheck.zoneFilter = nil
            BiSGearCheck:RefreshView()
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        -- Build a set of zones that have items for the current spec
        local specKey = BiSGearCheck.viewMode == "bislist" and BiSGearCheck.bislistSpec or BiSGearCheck.selectedSpec
        local db = BiSGearCheck:GetActiveDB()
        local specData = specKey and db and db[specKey]
        local zoneHasItems = {}
        if specData and specData.slots then
            for _, items in pairs(specData.slots) do
                for _, itemID in ipairs(items) do
                    local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]
                    if sourceInfo and sourceInfo.source then
                        local zone = BiSGearCheck.SourceToZone[sourceInfo.source]
                        if zone then zoneHasItems[zone] = true end
                    end
                end
            end
        end

        for _, category in ipairs(BiSGearCheck.ZoneCategories) do
            local hdr = UIDropDownMenu_CreateInfo()
            hdr.text = category.label
            hdr.isTitle = true
            hdr.notCheckable = true
            UIDropDownMenu_AddButton(hdr, level)

            for _, zone in ipairs(category.zones) do
                local zInfo = UIDropDownMenu_CreateInfo()
                if zoneHasItems[zone] then
                    zInfo.text = "  |cff00ff00" .. zone .. "|r"
                else
                    zInfo.text = "  " .. zone
                end
                zInfo.value = zone
                zInfo.func = function(self)
                    UIDropDownMenu_SetSelectedValue(zoneFilterDropdown, self.value)
                    UIDropDownMenu_SetText(zoneFilterDropdown, zone)
                    BiSGearCheck.zoneFilter = self.value
                    BiSGearCheck:RefreshView()
                end
                zInfo.notCheckable = true
                UIDropDownMenu_AddButton(zInfo, level)
            end
        end
    end
    UIDropDownMenu_Initialize(zoneFilterDropdown, ZoneFilterInit)
    UIDropDownMenu_SetText(zoneFilterDropdown, "All Zones")
    zoneFilterDropdown:Hide()

    f.collapseAllBtn = collapseAllBtn
    f.expandAllBtn = expandAllBtn
    f.zoneFilterDropdown = zoneFilterDropdown
    f.compareWLDropdown = compareWLDropdown
    f.compareWLLabel = compareWLLabel
end

-- ============================================================
-- BIS LISTS BAR: Data Source + All-Specs dropdown
-- ============================================================

function BiSGearCheck:SetupBisListBar(f)
    local bislistBar = CreateFrame("Frame", nil, f)
    bislistBar:SetSize(self.FRAME_WIDTH - 20, 26)
    bislistBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -60)
    bislistBar:Hide()

    local bislistSourceDropdown = CreateFrame("Frame", "BiSGearCheckBislistSourceDropdown", bislistBar, "UIDropDownMenuTemplate")
    bislistSourceDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -5, -60)
    UIDropDownMenu_SetWidth(bislistSourceDropdown, 100)

    local function BislistSourceInit(self, level)
        for _, srcInfo in ipairs(BiSGearCheck:GetEnabledDataSourcesForPhase()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = srcInfo.label
            info.value = srcInfo.key
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(bislistSourceDropdown, self.value)
                UIDropDownMenu_SetText(bislistSourceDropdown, self:GetText())
                BiSGearCheck:SetDataSource(self.value)
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(bislistSourceDropdown, BislistSourceInit)

    -- Set initial text
    for _, srcInfo in ipairs(self:GetEnabledDataSourcesForPhase()) do
        if srcInfo.key == self.dataSource then
            UIDropDownMenu_SetText(bislistSourceDropdown, srcInfo.label)
            break
        end
    end

    local bislistSpecDropdown = CreateFrame("Frame", "BiSGearCheckBislistSpecDropdown", bislistBar, "UIDropDownMenuTemplate")
    bislistSpecDropdown:SetPoint("LEFT", bislistSourceDropdown, "RIGHT", -15, 0)
    UIDropDownMenu_SetWidth(bislistSpecDropdown, 120)

    local CLASS_ORDER = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

    local function BislistSpecInit(self, level)
        local db = BiSGearCheck:GetActiveDB()
        if not db then return end

        for _, classToken in ipairs(CLASS_ORDER) do
            local specs = BiSGearCheck.ClassSpecs[classToken]
            if specs then
                -- Class header
                local hdr = UIDropDownMenu_CreateInfo()
                local classColor = RAID_CLASS_COLORS[classToken]
                if classColor then
                    hdr.text = string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, classToken:sub(1,1) .. classToken:sub(2):lower())
                else
                    hdr.text = classToken:sub(1,1) .. classToken:sub(2):lower()
                end
                hdr.isTitle = true
                hdr.notCheckable = true
                UIDropDownMenu_AddButton(hdr, level)

                for _, specInfo in ipairs(specs) do
                    if db[specInfo.key] then
                        local sInfo = UIDropDownMenu_CreateInfo()
                        sInfo.text = "  " .. specInfo.label
                        sInfo.value = specInfo.key
                        sInfo.func = function(self)
                            UIDropDownMenu_SetSelectedValue(bislistSpecDropdown, self.value)
                            UIDropDownMenu_SetText(bislistSpecDropdown, self:GetText())
                            BiSGearCheck.bislistSpec = self.value
                            BiSGearCheck:RefreshView()
                        end
                        sInfo.notCheckable = true
                        UIDropDownMenu_AddButton(sInfo, level)
                    end
                end
            end
        end
    end
    UIDropDownMenu_Initialize(bislistSpecDropdown, BislistSpecInit)
    UIDropDownMenu_SetText(bislistSpecDropdown, "Select Spec")

    local CURRENT_CONTENT_PHASE = 1
    local PHASE_OPTIONS = {
        { value = 0, label = "Pre-Raid" },
        { value = 1, label = "Phase 1" },
        { value = 2, label = "Phase 2" },
        { value = 3, label = "Phase 3" },
        { value = 4, label = "Phase 4" },
        { value = 5, label = "Phase 5" },
    }
    for _, opt in ipairs(PHASE_OPTIONS) do
        if opt.value == CURRENT_CONTENT_PHASE then
            opt.label = opt.label .. " (Current)"
        end
    end

    local phaseDropdown = CreateFrame("Frame", "BiSGearCheckPhaseDropdown", bislistBar, "UIDropDownMenuTemplate")
    phaseDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -5, -92)
    UIDropDownMenu_SetWidth(phaseDropdown, 110)

    local function PhaseDropdownInit(self, level)
        local currentPhase = BiSGearCheck.phaseFilter or 1
        for _, opt in ipairs(PHASE_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.value = opt.value
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(phaseDropdown, self.value)
                UIDropDownMenu_SetText(phaseDropdown, PHASE_OPTIONS[self.value + 1].label)
                BiSGearCheckSaved.phaseFilter = self.value
                BiSGearCheck.phaseFilter = self.value
                BiSGearCheck:OnPhaseChanged()
            end
            info.checked = (opt.value == currentPhase)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(phaseDropdown, PhaseDropdownInit)

    local savedPhase = BiSGearCheck.phaseFilter or 1
    UIDropDownMenu_SetText(phaseDropdown, PHASE_OPTIONS[savedPhase + 1].label)
    f.phaseDropdown = phaseDropdown

    f.bislistBar = bislistBar
    f.bislistSourceDropdown = bislistSourceDropdown
    f.bislistSpecDropdown = bislistSpecDropdown
end
