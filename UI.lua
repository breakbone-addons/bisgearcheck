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
    -- TABS: Compare + Wishlist (right under title bar)
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

    local wlTab = CreateTab(f, "Wishlist", 2)
    wlTab:SetPoint("LEFT", compTab, "RIGHT", 2, 0)

    local function UpdateTabAppearance()
        if BISGearCheck.viewMode == "comparison" then
            compTab.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
            compTab.label:SetTextColor(1, 0.82, 0)
            wlTab.bg:SetColorTexture(0.08, 0.08, 0.08, 0.8)
            wlTab.label:SetTextColor(0.5, 0.5, 0.5)
        else
            wlTab.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
            wlTab.label:SetTextColor(1, 0.82, 0)
            compTab.bg:SetColorTexture(0.08, 0.08, 0.08, 0.8)
            compTab.label:SetTextColor(0.5, 0.5, 0.5)
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

    f.compTab = compTab
    f.wlTab = wlTab
    f.UpdateTabAppearance = UpdateTabAppearance

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
        local _, classToken = UnitClass("player")
        local specs = BISGearCheck.ClassSpecs[classToken]
        if not specs then return end

        for _, specInfo in ipairs(specs) do
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

    f.collapseAllBtn = collapseAllBtn
    f.expandAllBtn = expandAllBtn

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
    f.collapseAllBtn:Show()
    f.expandAllBtn:Show()
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_PADDING, -90)

    local scrollChild = f.scrollChild
    ClearScrollContent(scrollChild)

    if self.selectedSpec then
        local db = self:GetActiveDB()
        if db and db[self.selectedSpec] then
            local specData = db[self.selectedSpec]
            local _, classToken = UnitClass("player")
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
        local eqText = eq.link or ("Item #" .. eq.id)
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
                local eqText = eq.link or ("Item #" .. eq.id)
                row.text:SetText("  Equipped: " .. eqText .. " - " .. rankStr(eq))
                if eq.link then
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetHyperlink(eq.link)
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

            local itemName = upgrade.link or upgrade.name or ("Item #" .. upgrade.id)
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

    f.filterBar:Show()
    f.collapseAllBtn:Hide()
    f.expandAllBtn:Hide()
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_PADDING, -100)

    if self.wishlistZoneFilter then
        UIDropDownMenu_SetText(f.zoneDropdown, self.wishlistZoneFilter)
    else
        UIDropDownMenu_SetText(f.zoneDropdown, "All Zones")
    end
    f.autoCheck:SetChecked(self.wishlistAutoFilter)

    local scrollChild = f.scrollChild
    ClearScrollContent(scrollChild)

    f.title:SetText("BiS Gear Check - |cff00ccffWishlist|r")

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
