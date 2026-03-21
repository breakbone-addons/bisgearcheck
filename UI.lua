-- BISGearCheck UI.lua
-- Main frame, scroll content, slot sections, wishlist view, zone filtering

BISGearCheck = BISGearCheck or {}

local FRAME_WIDTH = 480
local FRAME_HEIGHT = 540
local CONTENT_PADDING = 10
local SLOT_HEADER_HEIGHT = 20
local ITEM_ROW_HEIGHT = 18
local SECTION_SPACING = 8

local COLOR_GOLD = { r = 1.0, g = 0.82, b = 0.0 }
local COLOR_GREEN = { r = 0.0, g = 1.0, b = 0.0 }
local COLOR_GRAY = { r = 0.5, g = 0.5, b = 0.5 }
local COLOR_WHITE = { r = 1.0, g = 1.0, b = 1.0 }
local COLOR_RED = { r = 1.0, g = 0.3, b = 0.3 }
local COLOR_CYAN = { r = 0.0, g = 0.82, b = 1.0 }

-- Track collapsed state per slot (persists within session)
BISGearCheck.collapsedSlots = BISGearCheck.collapsedSlots or {}

-- ============================================================
-- MAIN FRAME
-- ============================================================

function BISGearCheck:CreateUI()
    if self.mainFrame then return end

    local f = CreateFrame("Frame", "BISGearCheckFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    table.insert(UISpecialFrames, "BISGearCheckFrame")

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -3)
    f.title:SetText("BiS Gear Check")

    -- ============================================================
    -- TABS: Compare + Wishlist + BiS Lists (right under title bar)
    -- ============================================================

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

    -- ============================================================
    -- CHARACTER SELECTOR (top-level, right of tabs)
    -- ============================================================

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

    -- ============================================================
    -- DROPDOWNS ROW: Data Source + Spec (below tabs)
    -- ============================================================

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

    -- ============================================================
    -- Collapse All / Expand All links (below dropdowns)
    -- ============================================================

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

    -- ============================================================
    -- WISHLIST FILTER BAR (shown only in wishlist mode)
    -- ============================================================

    local filterBar = CreateFrame("Frame", nil, f)
    filterBar:SetSize(FRAME_WIDTH - 20, 26)
    filterBar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -74)
    filterBar:Hide()

    local zoneDropdown = CreateFrame("Frame", "BISGearCheckZoneDropdown", filterBar, "UIDropDownMenuTemplate")
    zoneDropdown:SetPoint("TOPLEFT", filterBar, "TOPLEFT", -15, 2)
    UIDropDownMenu_SetWidth(zoneDropdown, 160)

    local function ZoneDropdownInit(self, level)
        -- "All Zones" option
        local info = UIDropDownMenu_CreateInfo()
        info.text = "All Zones"
        info.value = ""
        info.func = function(self)
            UIDropDownMenu_SetSelectedValue(zoneDropdown, "")
            UIDropDownMenu_SetText(zoneDropdown, "All Zones")
            BISGearCheck.wishlistZoneFilter = nil
            BISGearCheck:RefreshView()
        end
        info.checked = (BISGearCheck.wishlistZoneFilter == nil)
        UIDropDownMenu_AddButton(info, level)

        -- Categorized zones with dividers
        for catIdx, category in ipairs(BISGearCheck.ZoneCategories) do
            -- Section header (non-clickable divider)
            local hdr = UIDropDownMenu_CreateInfo()
            hdr.text = category.label
            hdr.isTitle = true
            hdr.notCheckable = true
            UIDropDownMenu_AddButton(hdr, level)

            -- Zone entries in this category
            for _, zone in ipairs(category.zones) do
                local hasItems = BISGearCheck:ZoneHasWishlistItems(zone)
                local zInfo = UIDropDownMenu_CreateInfo()
                if hasItems then
                    zInfo.text = "|cff00ff00" .. zone .. "|r"
                else
                    zInfo.text = zone
                end
                zInfo.value = zone
                zInfo.func = function(self)
                    UIDropDownMenu_SetSelectedValue(zoneDropdown, self.value)
                    UIDropDownMenu_SetText(zoneDropdown, zone)
                    BISGearCheck.wishlistZoneFilter = self.value
                    BISGearCheck:RefreshView()
                end
                zInfo.checked = (BISGearCheck.wishlistZoneFilter == zone)
                UIDropDownMenu_AddButton(zInfo, level)
            end
        end
    end
    UIDropDownMenu_Initialize(zoneDropdown, ZoneDropdownInit)
    UIDropDownMenu_SetText(zoneDropdown, "All Zones")

    local autoCheck = CreateFrame("CheckButton", "BISGearCheckAutoFilter", filterBar, "UICheckButtonTemplate")
    autoCheck:SetSize(24, 24)
    autoCheck:SetPoint("LEFT", zoneDropdown, "RIGHT", -5, 0)
    autoCheck:SetChecked(self.wishlistAutoFilter)
    autoCheck.text = autoCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoCheck.text:SetPoint("LEFT", autoCheck, "RIGHT", 2, 0)
    autoCheck.text:SetText("Auto")
    autoCheck:SetScript("OnClick", function(self)
        BISGearCheck:SetWishlistAutoFilter(self:GetChecked())
        BISGearCheck:RefreshView()
    end)
    autoCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Auto Zone Filter", 1, 1, 1)
        GameTooltip:AddLine("Automatically filter wishlist by your current zone when in a dungeon or raid.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    autoCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.filterBar = filterBar
    f.zoneDropdown = zoneDropdown
    f.autoCheck = autoCheck

    -- ============================================================
    -- WISHLIST SELECTOR BAR (dropdown + New / Rename / Delete)
    -- ============================================================

    local wlSelectorBar = CreateFrame("Frame", nil, f)
    wlSelectorBar:SetSize(FRAME_WIDTH - 20, 26)
    wlSelectorBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -48)
    wlSelectorBar:Hide()

    -- Wishlist name dropdown
    local wlNameDropdown = CreateFrame("Frame", "BISGearCheckWLNameDropdown", wlSelectorBar, "UIDropDownMenuTemplate")
    wlNameDropdown:SetPoint("TOPLEFT", wlSelectorBar, "TOPLEFT", -5, 2)
    UIDropDownMenu_SetWidth(wlNameDropdown, 130)

    local function WLNameDropdownInit(self, level)
        local names = BISGearCheck:GetWishlistNames()
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(wlNameDropdown, self.value)
                UIDropDownMenu_SetText(wlNameDropdown, self.value)
                BISGearCheck:SetActiveWishlist(self.value)
            end
            info.checked = (name == BISGearCheck.activeWishlist)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(wlNameDropdown, WLNameDropdownInit)
    UIDropDownMenu_SetText(wlNameDropdown, self.activeWishlist)

    -- Helper to get editBox from a static popup frame
    local function GetPopupEditBox(dialog)
        return dialog.editBox or _G[dialog:GetName() .. "EditBox"]
    end

    -- Static popup: New Wishlist
    StaticPopupDialogs["BISGEARCHECK_NEW_WISHLIST"] = {
        text = "Enter a name for the new wishlist:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self)
            local eb = GetPopupEditBox(self)
            local name = eb and eb:GetText():trim() or ""
            if name ~= "" then
                if BISGearCheck:CreateWishlist(name) then
                    BISGearCheck:RefreshView()
                else
                    print("|cffff6666BiS Gear Check:|r A wishlist named '" .. name .. "' already exists.")
                end
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local name = self:GetText():trim()
            if name ~= "" then
                if BISGearCheck:CreateWishlist(name) then
                    BISGearCheck:RefreshView()
                else
                    print("|cffff6666BiS Gear Check:|r A wishlist named '" .. name .. "' already exists.")
                end
            end
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0,
        whileDead = true,
        preferredIndex = 3,
    }

    -- Static popup: Rename Wishlist
    StaticPopupDialogs["BISGEARCHECK_RENAME_WISHLIST"] = {
        text = "Rename '%s' to:",
        button1 = "Rename",
        button2 = "Cancel",
        hasEditBox = true,
        OnShow = function(self)
            local eb = GetPopupEditBox(self)
            if eb then
                eb:SetText(BISGearCheck.activeWishlist)
                eb:HighlightText()
            end
        end,
        OnAccept = function(self)
            local eb = GetPopupEditBox(self)
            local name = eb and eb:GetText():trim() or ""
            if name ~= "" then
                if BISGearCheck:RenameWishlist(name) then
                    BISGearCheck:RefreshView()
                else
                    print("|cffff6666BiS Gear Check:|r A wishlist named '" .. name .. "' already exists.")
                end
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local name = self:GetText():trim()
            if name ~= "" then
                if BISGearCheck:RenameWishlist(name) then
                    BISGearCheck:RefreshView()
                else
                    print("|cffff6666BiS Gear Check:|r A wishlist named '" .. name .. "' already exists.")
                end
            end
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0,
        whileDead = true,
        preferredIndex = 3,
    }

    -- Static popup: Delete Wishlist
    StaticPopupDialogs["BISGEARCHECK_DELETE_WISHLIST"] = {
        text = "Delete wishlist '%s'?\n\nThis cannot be undone.",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function()
            if BISGearCheck:DeleteWishlist() then
                BISGearCheck:RefreshView()
            end
        end,
        timeout = 0,
        whileDead = true,
        preferredIndex = 3,
    }

    local wlNewBtn = CreateFrame("Button", nil, wlSelectorBar, "UIPanelButtonTemplate")
    wlNewBtn:SetSize(50, 22)
    wlNewBtn:SetPoint("LEFT", wlNameDropdown, "RIGHT", -10, 0)
    wlNewBtn:SetText("New")
    wlNewBtn:SetScript("OnClick", function()
        StaticPopup_Show("BISGEARCHECK_NEW_WISHLIST")
    end)

    local wlRenameBtn = CreateFrame("Button", nil, wlSelectorBar, "UIPanelButtonTemplate")
    wlRenameBtn:SetSize(60, 22)
    wlRenameBtn:SetPoint("LEFT", wlNewBtn, "RIGHT", 2, 0)
    wlRenameBtn:SetText("Rename")
    wlRenameBtn:SetScript("OnClick", function()
        StaticPopupDialogs["BISGEARCHECK_RENAME_WISHLIST"].text = "Rename '" .. BISGearCheck.activeWishlist .. "' to:"
        StaticPopup_Show("BISGEARCHECK_RENAME_WISHLIST")
    end)

    local wlDeleteBtn = CreateFrame("Button", nil, wlSelectorBar, "UIPanelButtonTemplate")
    wlDeleteBtn:SetSize(55, 22)
    wlDeleteBtn:SetPoint("LEFT", wlRenameBtn, "RIGHT", 2, 0)
    wlDeleteBtn:SetText("Delete")
    wlDeleteBtn:SetScript("OnClick", function()
        StaticPopupDialogs["BISGEARCHECK_DELETE_WISHLIST"].text = "Delete wishlist '" .. BISGearCheck.activeWishlist .. "'?\n\nThis cannot be undone."
        StaticPopup_Show("BISGEARCHECK_DELETE_WISHLIST")
    end)

    f.wlSelectorBar = wlSelectorBar
    f.wlNameDropdown = wlNameDropdown

    -- ============================================================
    -- BIS LISTS BAR: Data Source + All-Specs dropdown
    -- ============================================================

    local bislistBar = CreateFrame("Frame", nil, f)
    bislistBar:SetSize(FRAME_WIDTH - 20, 26)
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

    -- ============================================================
    -- SCROLL FRAME
    -- ============================================================

    local scrollFrame = CreateFrame("ScrollFrame", "BISGearCheckScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_PADDING, -90)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", "BISGearCheckScrollChild")
    scrollChild:SetWidth(FRAME_WIDTH - 40)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    f.scrollFrame = scrollFrame
    f.scrollChild = scrollChild
    f.sourceDropdown = sourceDropdown
    f.specDropdown = specDropdown

    -- Retry refresh when item data has been received
    f._retryElapsed = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        f._retryElapsed = f._retryElapsed + elapsed
        if f._retryElapsed < 0.5 then return end
        f._retryElapsed = 0
        if BISGearCheck.needsRefresh then
            BISGearCheck.needsRefresh = false
            BISGearCheck:Refresh()
        end
    end)

    self.mainFrame = f
end

-- ============================================================
-- CLEAR SCROLL CONTENT
-- ============================================================

local function ClearScrollContent(scrollChild)
    if scrollChild.rows then
        for _, row in ipairs(scrollChild.rows) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    scrollChild.rows = {}
end

-- ============================================================
-- RENDER COMPARISON RESULTS
-- ============================================================

function BISGearCheck:RenderResults()
    local f = self.mainFrame
    if not f then return end

    f.filterBar:Hide()
    f.bislistBar:Hide()
    f.wlSelectorBar:Hide()
    f.collapseAllBtn:Show()
    f.expandAllBtn:Show()
    f.compareWLDropdown:Show()
    f.compareWLLabel:Show()
    UIDropDownMenu_SetText(f.compareWLDropdown, self.activeWishlist)
    f.sourceDropdown:Show()
    f.specDropdown:Show()
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_PADDING, -90)

    local scrollChild = f.scrollChild
    ClearScrollContent(scrollChild)

    -- Update character dropdown
    self:UpdateCharDropdownText()

    if self.selectedSpec then
        local db = self:GetActiveDB()
        if db and db[self.selectedSpec] then
            local specData = db[self.selectedSpec]
            local classToken = self:GetViewingClass()
            local classColored = self:ClassColor(classToken, specData.spec)
            f.title:SetText("BiS Gear Check - " .. classColored)
            UIDropDownMenu_SetText(f.specDropdown, specData.spec)
        end
    end

    for _, srcInfo in ipairs(self.DataSources) do
        if srcInfo.key == self.dataSource then
            UIDropDownMenu_SetText(f.sourceDropdown, srcInfo.label)
            break
        end
    end

    local yOffset = -5
    local contentWidth = FRAME_WIDTH - 45

    for _, slotResult in ipairs(self.comparisonResults) do
        yOffset = self:RenderSlotSection(scrollChild, slotResult, yOffset, contentWidth)
        yOffset = yOffset - SECTION_SPACING
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

function BISGearCheck:RenderSlotSection(parent, slotResult, yOffset, width)
    local slotName = slotResult.slotName
    local isCollapsed = self.collapsedSlots[slotName]
    local isDualSlot = (slotName == "Rings" or slotName == "Trinkets")

    -- Build rank text helper
    local function rankStr(eq)
        if eq.rank then
            if eq.rank == 1 then
                return "|cff00ff00BiS!|r"
            else
                return string.format("|cffffffffRank %d|r", eq.rank)
            end
        end
        return "|cff999999Not on list|r"
    end

    local arrow = isCollapsed and "|cffffd100[+]|r " or "|cffffd100[-]|r "

    if not isDualSlot and #slotResult.equipped == 1 then
        -- Single-slot: combine header + equipped on one line
        local eq = slotResult.equipped[1]
        local header = self:CreateRow(parent, yOffset, width)
        local eqText = eq.link or GetInventoryItemLink("player", eq.invSlot) or ("Item #" .. eq.id)
        header.text:SetText(arrow .. "|cffffd100" .. slotName .. ":|r " .. eqText .. " - " .. rankStr(eq))
        -- same size as item rows
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", function()
            BISGearCheck.collapsedSlots[slotName] = not BISGearCheck.collapsedSlots[slotName]
            BISGearCheck:RefreshView()
        end)
        if eq.link then
            header:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(eq.link)
                GameTooltip:Show()
            end)
            header:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        yOffset = yOffset - SLOT_HEADER_HEIGHT
    elseif not isDualSlot and #slotResult.equipped == 0 then
        -- Single-slot empty: combine header + empty
        local header = self:CreateRow(parent, yOffset, width)
        header.text:SetText(arrow .. "|cffffd100" .. slotName .. ":|r |cff999999(empty)|r")
        -- same size as item rows
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", function()
            BISGearCheck.collapsedSlots[slotName] = not BISGearCheck.collapsedSlots[slotName]
            BISGearCheck:RefreshView()
        end)
        yOffset = yOffset - SLOT_HEADER_HEIGHT
    else
        -- Dual-slot: header then equipped items
        local header = self:CreateRow(parent, yOffset, width)
        header.text:SetText(arrow .. "|cffffd100" .. slotName .. "|r")
        -- same size as item rows
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", function()
            BISGearCheck.collapsedSlots[slotName] = not BISGearCheck.collapsedSlots[slotName]
            BISGearCheck:RefreshView()
        end)
        yOffset = yOffset - SLOT_HEADER_HEIGHT

        if not isCollapsed then
            for _, eq in ipairs(slotResult.equipped) do
                local row = self:CreateRow(parent, yOffset, width)
                local lateLink = eq.link or GetInventoryItemLink("player", eq.invSlot)
                local eqText = lateLink or ("Item #" .. eq.id)
                row.text:SetText("  Equipped: " .. eqText .. " - " .. rankStr(eq))
                if lateLink then
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetHyperlink(lateLink)
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                end
                yOffset = yOffset - ITEM_ROW_HEIGHT
            end

            if #slotResult.equipped == 0 then
                local row = self:CreateRow(parent, yOffset, width)
                row.text:SetText("  |cff999999(empty slots)|r")
                yOffset = yOffset - ITEM_ROW_HEIGHT
            end
        end
    end

    if not isCollapsed then
        for _, upgrade in ipairs(slotResult.upgrades) do
            local row = self:CreateRow(parent, yOffset, width)

            -- Re-query item info at render time in case it loaded since comparison
            local lateName, lateLink, lateQuality, _, _, _, _, _, _, lateIcon = GetItemInfo(upgrade.id)
            local itemName = lateLink or upgrade.link or lateName or upgrade.name or ("Item #" .. upgrade.id)
            local sourceText = ""
            if upgrade.source and upgrade.source ~= "" and upgrade.source ~= "Unknown" then
                if upgrade.sourceType and upgrade.sourceType ~= "" then
                    sourceText = string.format("|cff888888- %s (%s)|r", upgrade.source, upgrade.sourceType)
                else
                    sourceText = string.format("|cff888888- %s|r", upgrade.source)
                end
            end

            row.text:SetText(string.format("  |cff00ccff#%d|r %s %s", upgrade.rank, itemName, sourceText))
            row.text:SetPoint("RIGHT", row, "RIGHT", -30, 0)

            -- Wishlist + button (enlarged with green background)
            local onWL = self:IsOnWishlist(upgrade.id)
            local addBtn = CreateFrame("Button", nil, row)
            addBtn:SetSize(24, 18)
            addBtn:SetPoint("RIGHT", row, "RIGHT", -1, 0)

            -- Background texture
            local btnBg = addBtn:CreateTexture(nil, "BACKGROUND")
            btnBg:SetAllPoints()
            if onWL then
                btnBg:SetColorTexture(0.0, 0.5, 0.0, 0.8)
            else
                btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
            end
            addBtn.bg = btnBg

            local btnText = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btnText:SetPoint("CENTER", 0, 0)
            btnText:SetText("|cffffffff+|r")
            addBtn.label = btnText

            local capturedUpgrade = upgrade
            addBtn:SetScript("OnClick", function()
                if BISGearCheck:IsOnWishlist(capturedUpgrade.id) then
                    BISGearCheck:RemoveFromWishlist(capturedUpgrade.id)
                    btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
                else
                    BISGearCheck:AddToWishlist(capturedUpgrade.id, capturedUpgrade.slotName, capturedUpgrade.rank, capturedUpgrade.source, capturedUpgrade.sourceType)
                    btnBg:SetColorTexture(0.0, 0.5, 0.0, 0.8)
                end
            end)
            addBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if BISGearCheck:IsOnWishlist(capturedUpgrade.id) then
                    GameTooltip:AddLine("Click to remove from Wishlist", 1, 0.3, 0.3)
                else
                    GameTooltip:AddLine("Click to add to Wishlist", 0, 1, 0)
                end
                GameTooltip:Show()
            end)
            addBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            table.insert(parent.rows, addBtn)

            -- Item tooltip on hover
            local itemID = upgrade.id
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local _, link = GetItemInfo(itemID)
                if link then
                    GameTooltip:SetHyperlink(link)
                else
                    GameTooltip:AddLine("Item #" .. itemID)
                    GameTooltip:AddLine("Loading...", 0.5, 0.5, 0.5)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            yOffset = yOffset - ITEM_ROW_HEIGHT
        end
    end

    -- Separator
    local sep = self:CreateRow(parent, yOffset, width)
    local line = sep:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", sep, "TOPLEFT", 5, -2)
    line:SetPoint("TOPRIGHT", sep, "TOPRIGHT", -5, -2)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    yOffset = yOffset - 6

    return yOffset
end

-- ============================================================
-- RENDER WISHLIST
-- ============================================================

function BISGearCheck:RenderWishlist()
    local f = self.mainFrame
    if not f then return end

    f.wlSelectorBar:Show()
    f.filterBar:Show()
    f.filterBar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -74)
    f.bislistBar:Hide()
    f.compareWLDropdown:Hide()
    f.compareWLLabel:Hide()
    f.collapseAllBtn:Hide()
    f.expandAllBtn:Hide()
    f.sourceDropdown:Hide()
    f.specDropdown:Hide()
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_PADDING, -100)

    -- Update character dropdown text
    self:UpdateCharDropdownText()

    -- Update wishlist name dropdown
    UIDropDownMenu_SetText(f.wlNameDropdown, self.activeWishlist)

    if self.wishlistZoneFilter then
        UIDropDownMenu_SetText(f.zoneDropdown, self.wishlistZoneFilter)
    else
        UIDropDownMenu_SetText(f.zoneDropdown, "All Zones")
    end
    f.autoCheck:SetChecked(self.wishlistAutoFilter)

    local scrollChild = f.scrollChild
    ClearScrollContent(scrollChild)

    -- Show character name in title if viewing another character's wishlist
    local titleSuffix = "|cff00ccff" .. self.activeWishlist .. "|r"
    if self.viewingCharKey and self.viewingCharKey ~= self.playerKey then
        local vcd = self:GetCharacterData(self.viewingCharKey)
        local vcc = vcd and RAID_CLASS_COLORS[vcd.class]
        local charName = self.viewingCharKey:match("^([^-]+)")
        if vcc then
            titleSuffix = string.format("|cff%02x%02x%02x%s|r - %s", vcc.r * 255, vcc.g * 255, vcc.b * 255, charName, titleSuffix)
        else
            titleSuffix = charName .. " - " .. titleSuffix
        end
    end
    f.title:SetText("BiS Gear Check - " .. titleSuffix)

    local items = self:GetWishlistItems()
    local yOffset = -5
    local contentWidth = FRAME_WIDTH - 45

    -- Apply zone filter
    local filteredItems = {}
    for _, item in ipairs(items) do
        if not self.wishlistZoneFilter or self:ItemMatchesZone(item.id, self.wishlistZoneFilter) then
            table.insert(filteredItems, item)
        end
    end

    if #filteredItems == 0 then
        local row = self:CreateRow(scrollChild, yOffset, contentWidth)
        if self.wishlistZoneFilter then
            row.text:SetText("|cff999999No wishlist items for " .. self.wishlistZoneFilter .. "|r")
        else
            row.text:SetText("|cff999999Your wishlist is empty. Add items from the comparison view.|r")
        end
        yOffset = yOffset - ITEM_ROW_HEIGHT
    else
        local currentSlot = nil
        for _, item in ipairs(filteredItems) do
            if item.slotName ~= currentSlot then
                currentSlot = item.slotName
                local header = self:CreateRow(scrollChild, yOffset, contentWidth)
                header.text:SetText("|cffffd100" .. (currentSlot or "Unknown") .. "|r")
                -- same size as item rows
                yOffset = yOffset - SLOT_HEADER_HEIGHT
            end

            local row = self:CreateRow(scrollChild, yOffset, contentWidth)

            local itemName = item.link or item.name
            local sourceText = ""
            if item.source and item.source ~= "" and item.source ~= "Unknown" then
                if item.sourceType and item.sourceType ~= "" then
                    sourceText = string.format("|cff888888- %s (%s)|r", item.source, item.sourceType)
                else
                    sourceText = string.format("|cff888888- %s|r", item.source)
                end
            end

            local prefix = ""
            if item.isEquipped then
                prefix = "|cff00ff00[Equipped]|r "
            end

            row.text:SetText(string.format("  %s%s %s", prefix, itemName, sourceText))
            row.text:SetPoint("RIGHT", row, "RIGHT", -30, 0)

            -- Remove button (X) - enlarged with red background
            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(24, 18)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", -1, 0)

            local removeBg = removeBtn:CreateTexture(nil, "BACKGROUND")
            removeBg:SetAllPoints()
            removeBg:SetColorTexture(0.5, 0.0, 0.0, 0.8)

            local btnText = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btnText:SetPoint("CENTER", 0, 0)
            btnText:SetText("|cffffffffx|r")

            local capturedID = item.id
            removeBtn:SetScript("OnClick", function()
                BISGearCheck:RemoveFromWishlist(capturedID)
                BISGearCheck:RefreshView()
            end)
            removeBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Remove from Wishlist", 1, 0.3, 0.3)
                GameTooltip:Show()
            end)
            removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            table.insert(scrollChild.rows, removeBtn)

            -- Item tooltip
            local itemID = item.id
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local _, link = GetItemInfo(itemID)
                if link then
                    GameTooltip:SetHyperlink(link)
                else
                    GameTooltip:AddLine("Item #" .. itemID)
                    GameTooltip:AddLine("Loading...", 0.5, 0.5, 0.5)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            yOffset = yOffset - ITEM_ROW_HEIGHT
        end
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- ============================================================
-- RENDER BIS LISTS
-- ============================================================

function BISGearCheck:RenderBisList()
    local f = self.mainFrame
    if not f then return end

    f.filterBar:Hide()
    f.bislistBar:Show()
    f.wlSelectorBar:Hide()
    f.compareWLDropdown:Hide()
    f.compareWLLabel:Hide()
    f.collapseAllBtn:Show()
    f.expandAllBtn:Show()
    f.sourceDropdown:Hide()
    f.specDropdown:Hide()
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_PADDING, -90)

    -- Update character dropdown
    self:UpdateCharDropdownText()

    -- Update bislist source dropdown text
    for _, srcInfo in ipairs(self.DataSources) do
        if srcInfo.key == self.dataSource then
            UIDropDownMenu_SetText(f.bislistSourceDropdown, srcInfo.label)
            break
        end
    end

    -- Update bislist spec dropdown text
    if self.bislistSpec then
        local db = self:GetActiveDB()
        if db and db[self.bislistSpec] then
            UIDropDownMenu_SetText(f.bislistSpecDropdown, db[self.bislistSpec].spec)
        end
    else
        UIDropDownMenu_SetText(f.bislistSpecDropdown, "Select Spec")
    end

    local scrollChild = f.scrollChild
    ClearScrollContent(scrollChild)

    local specKey = self.bislistSpec
    local db = self:GetActiveDB()

    if not specKey or not db or not db[specKey] then
        f.title:SetText("BiS Gear Check - |cff00ccffBiS Lists|r")
        local yOffset = -5
        local contentWidth = FRAME_WIDTH - 45
        local row = self:CreateRow(scrollChild, yOffset, contentWidth)
        row.text:SetText("|cff999999Select a spec from the dropdown above.|r")
        scrollChild:SetHeight(40)
        return
    end

    local specData = db[specKey]
    local classColor = RAID_CLASS_COLORS[specData.class]
    if classColor then
        local colored = string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, specData.spec)
        f.title:SetText("BiS Gear Check - " .. colored)
    else
        f.title:SetText("BiS Gear Check - " .. specData.spec)
    end

    local yOffset = -5
    local contentWidth = FRAME_WIDTH - 45

    for _, slotName in ipairs(self.SlotOrder) do
        local rawItems = specData.slots[slotName]
        local items = rawItems and self:FilterBisListByFaction(rawItems) or {}
        if #items > 0 then
            local isCollapsed = self.collapsedSlots[slotName]
            local arrow = isCollapsed and "|cffffd100[+]|r " or "|cffffd100[-]|r "

            -- Slot header
            local header = self:CreateRow(scrollChild, yOffset, contentWidth)
            header.text:SetText(arrow .. "|cffffd100" .. slotName .. "|r")
            header:EnableMouse(true)
            header:SetScript("OnMouseDown", function()
                BISGearCheck.collapsedSlots[slotName] = not BISGearCheck.collapsedSlots[slotName]
                BISGearCheck:RefreshView()
            end)
            yOffset = yOffset - SLOT_HEADER_HEIGHT

            if not isCollapsed then
                for rank, itemID in ipairs(items) do
                    local row = self:CreateRow(scrollChild, yOffset, contentWidth)

                    local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
                    if not name then
                        self.pendingItems[itemID] = true
                        C_Item.RequestLoadItemDataByID(itemID)
                    end

                    local itemText = link or name or ("Item #" .. itemID)
                    local sourceInfo = BISGearCheckSources and BISGearCheckSources[itemID]
                    local sourceText = ""
                    if sourceInfo and sourceInfo.source and sourceInfo.source ~= "Unknown" then
                        if sourceInfo.sourceType and sourceInfo.sourceType ~= "" then
                            sourceText = string.format("|cff888888- %s (%s)|r", sourceInfo.source, sourceInfo.sourceType)
                        else
                            sourceText = string.format("|cff888888- %s|r", sourceInfo.source)
                        end
                    end

                    row.text:SetText(string.format("  |cff00ccff#%d|r %s %s", rank, itemText, sourceText))

                    -- Item tooltip on hover
                    row:EnableMouse(true)
                    local capturedID = itemID
                    row:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        local _, rLink = GetItemInfo(capturedID)
                        if rLink then
                            GameTooltip:SetHyperlink(rLink)
                        else
                            GameTooltip:AddLine("Item #" .. capturedID)
                            GameTooltip:AddLine("Loading...", 0.5, 0.5, 0.5)
                        end
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

                    yOffset = yOffset - ITEM_ROW_HEIGHT
                end
            end

            -- Separator
            local sep = self:CreateRow(scrollChild, yOffset, contentWidth)
            local line = sep:CreateTexture(nil, "ARTWORK")
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", sep, "TOPLEFT", 5, -2)
            line:SetPoint("TOPRIGHT", sep, "TOPRIGHT", -5, -2)
            line:SetColorTexture(0.3, 0.3, 0.3, 0.5)
            yOffset = yOffset - 6
            yOffset = yOffset - SECTION_SPACING
        end
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- ============================================================
-- HELPERS
-- ============================================================

function BISGearCheck:CreateRow(parent, yOffset, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, ITEM_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    if not parent.rows then parent.rows = {} end
    table.insert(parent.rows, row)

    return row
end
