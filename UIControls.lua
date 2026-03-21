-- BISGearCheck UIControls.lua
-- Tabs, character selector, data source/spec dropdowns, collapse controls, BiS Lists bar

BISGearCheck = BISGearCheck or {}

-- ============================================================
-- TABS: Compare + Wishlist + BiS Lists
-- ============================================================

function BISGearCheck:SetupTabs(f)
    local TAB_WIDTH = 80
    local TAB_HEIGHT = 22

    local function CreateTab(parent, text, index)
        local tab = CreateFrame("Button", "BISGearCheckTab" .. index, parent)
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
    compTab:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)

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
        local mode = BISGearCheck.viewMode
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
        BISGearCheck.viewMode = "comparison"
        UpdateTabAppearance()
        BISGearCheck:Refresh()
    end)

    wlTab:SetScript("OnClick", function()
        BISGearCheck.viewMode = "wishlist"
        UpdateTabAppearance()
        BISGearCheck:RefreshView()
    end)

    bisTab:SetScript("OnClick", function()
        BISGearCheck.viewMode = "bislist"
        UpdateTabAppearance()
        BISGearCheck:RefreshView()
    end)

    f.compTab = compTab
    f.wlTab = wlTab
    f.bisTab = bisTab
    f.UpdateTabAppearance = UpdateTabAppearance
end

-- ============================================================
-- CHARACTER SELECTOR (top-level, right of tabs)
-- ============================================================

function BISGearCheck:SetupCharacterSelector(f)
    local charDropdown = CreateFrame("Frame", "BISGearCheckCharDropdown", f, "UIDropDownMenuTemplate")
    charDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -22)
    UIDropDownMenu_SetWidth(charDropdown, 110)
    UIDropDownMenu_JustifyText(charDropdown, "RIGHT")

    local function CharDropdownInit(self, level)
        local charKeys = BISGearCheck:GetCharacterKeys()
        for _, charKey in ipairs(charKeys) do
            local charData = BISGearCheck:GetCharacterData(charKey)
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
                BISGearCheck:UpdateCharDropdownText()
                BISGearCheck:SetViewingCharacter(self.value)
            end
            info.checked = (charKey == BISGearCheck:GetViewingCharKey())
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(charDropdown, CharDropdownInit)

    f.charDropdown = charDropdown

    -- Helper to update character dropdown text with class color
    function BISGearCheck:UpdateCharDropdownText()
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

function BISGearCheck:SetupSourceSpecDropdowns(f)
    -- Data source dropdown
    local sourceDropdown = CreateFrame("Frame", "BISGearCheckSourceDropdown", f, "UIDropDownMenuTemplate")
    sourceDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -5, -48)
    UIDropDownMenu_SetWidth(sourceDropdown, 100)

    local function SourceDropdownInit(self, level)
        for _, srcInfo in ipairs(BISGearCheck.DataSources) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = srcInfo.label
            info.value = srcInfo.key
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(sourceDropdown, self.value)
                UIDropDownMenu_SetText(sourceDropdown, self:GetText())
                BISGearCheck:SetDataSource(self.value)
            end
            info.checked = (srcInfo.key == BISGearCheck.dataSource)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(sourceDropdown, SourceDropdownInit)

    -- Set initial source text
    for _, srcInfo in ipairs(self.DataSources) do
        if srcInfo.key == self.dataSource then
            UIDropDownMenu_SetText(sourceDropdown, srcInfo.label)
            UIDropDownMenu_SetSelectedValue(sourceDropdown, srcInfo.key)
            break
        end
    end

    -- Spec dropdown
    local specDropdown = CreateFrame("Frame", "BISGearCheckSpecDropdown", f, "UIDropDownMenuTemplate")
    specDropdown:SetPoint("LEFT", sourceDropdown, "RIGHT", -15, 0)
    UIDropDownMenu_SetWidth(specDropdown, 120)

    local function SpecDropdownInit(self, level)
        local classToken = BISGearCheck:GetViewingClass()
        local specs = classToken and BISGearCheck.ClassSpecs[classToken]
        if not specs then return end

        local db = BISGearCheck:GetActiveDB()
        for _, specInfo in ipairs(specs) do
            if db and db[specInfo.key] then
                local info = UIDropDownMenu_CreateInfo()
                info.text = specInfo.label
                info.value = specInfo.key
                info.func = function(self)
                    UIDropDownMenu_SetSelectedValue(specDropdown, self.value)
                    UIDropDownMenu_SetText(specDropdown, self:GetText())
                    BISGearCheck:SetSpec(self.value)
                end
                info.checked = (specInfo.key == BISGearCheck.selectedSpec)
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

function BISGearCheck:SetupCollapseControls(f)
    local collapseAllBtn = CreateFrame("Button", nil, f)
    collapseAllBtn:SetSize(70, 16)
    collapseAllBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -74)
    local collapseText = collapseAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collapseText:SetPoint("LEFT")
    collapseText:SetText("|cff00ccffCollapse All|r")
    collapseAllBtn:SetScript("OnClick", function()
        for _, slotName in ipairs(BISGearCheck.SlotOrder) do
            BISGearCheck.collapsedSlots[slotName] = true
        end
        BISGearCheck:RefreshView()
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
        for _, slotName in ipairs(BISGearCheck.SlotOrder) do
            BISGearCheck.collapsedSlots[slotName] = false
        end
        BISGearCheck:RefreshView()
    end)
    expandAllBtn:SetScript("OnEnter", function(self) expandText:SetText("|cffffffffExpand All|r") end)
    expandAllBtn:SetScript("OnLeave", function(self) expandText:SetText("|cff00ccffExpand All|r") end)

    -- Wishlist picker (right-aligned, shown on Compare tab)
    local compareWLDropdown = CreateFrame("Frame", "BISGearCheckCompareWLDropdown", f, "UIDropDownMenuTemplate")
    compareWLDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -70)
    UIDropDownMenu_SetWidth(compareWLDropdown, 90)
    UIDropDownMenu_JustifyText(compareWLDropdown, "RIGHT")

    local function CompareWLDropdownInit(self, level)
        local names = BISGearCheck:GetWishlistNames()
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(compareWLDropdown, self.value)
                UIDropDownMenu_SetText(compareWLDropdown, self.value)
                BISGearCheck:SetActiveWishlist(self.value)
            end
            info.checked = (name == BISGearCheck.activeWishlist)
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

    f.collapseAllBtn = collapseAllBtn
    f.expandAllBtn = expandAllBtn
    f.compareWLDropdown = compareWLDropdown
    f.compareWLLabel = compareWLLabel
end

-- ============================================================
-- BIS LISTS BAR: Data Source + All-Specs dropdown
-- ============================================================

function BISGearCheck:SetupBisListBar(f)
    local bislistBar = CreateFrame("Frame", nil, f)
    bislistBar:SetSize(self.FRAME_WIDTH - 20, 26)
    bislistBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -48)
    bislistBar:Hide()

    local bislistSourceDropdown = CreateFrame("Frame", "BISGearCheckBislistSourceDropdown", bislistBar, "UIDropDownMenuTemplate")
    bislistSourceDropdown:SetPoint("TOPLEFT", bislistBar, "TOPLEFT", -5, 2)
    UIDropDownMenu_SetWidth(bislistSourceDropdown, 100)

    local function BislistSourceInit(self, level)
        for _, srcInfo in ipairs(BISGearCheck.DataSources) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = srcInfo.label
            info.value = srcInfo.key
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(bislistSourceDropdown, self.value)
                UIDropDownMenu_SetText(bislistSourceDropdown, self:GetText())
                BISGearCheck:SetDataSource(self.value)
            end
            info.checked = (srcInfo.key == BISGearCheck.dataSource)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(bislistSourceDropdown, BislistSourceInit)

    -- Set initial text
    for _, srcInfo in ipairs(self.DataSources) do
        if srcInfo.key == self.dataSource then
            UIDropDownMenu_SetText(bislistSourceDropdown, srcInfo.label)
            break
        end
    end

    local bislistSpecDropdown = CreateFrame("Frame", "BISGearCheckBislistSpecDropdown", bislistBar, "UIDropDownMenuTemplate")
    bislistSpecDropdown:SetPoint("LEFT", bislistSourceDropdown, "RIGHT", -15, 0)
    UIDropDownMenu_SetWidth(bislistSpecDropdown, 160)

    local CLASS_ORDER = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

    local function BislistSpecInit(self, level)
        local db = BISGearCheck:GetActiveDB()
        if not db then return end

        for _, classToken in ipairs(CLASS_ORDER) do
            local specs = BISGearCheck.ClassSpecs[classToken]
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
                        sInfo.text = specInfo.label
                        sInfo.value = specInfo.key
                        sInfo.func = function(self)
                            UIDropDownMenu_SetSelectedValue(bislistSpecDropdown, self.value)
                            UIDropDownMenu_SetText(bislistSpecDropdown, self:GetText())
                            BISGearCheck.bislistSpec = self.value
                            BISGearCheck:RefreshView()
                        end
                        sInfo.checked = (specInfo.key == BISGearCheck.bislistSpec)
                        UIDropDownMenu_AddButton(sInfo, level)
                    end
                end
            end
        end
    end
    UIDropDownMenu_Initialize(bislistSpecDropdown, BislistSpecInit)
    UIDropDownMenu_SetText(bislistSpecDropdown, "Select Spec")

    f.bislistBar = bislistBar
    f.bislistSourceDropdown = bislistSourceDropdown
    f.bislistSpecDropdown = bislistSpecDropdown
end
