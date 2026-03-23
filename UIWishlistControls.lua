-- BiSGearCheck UIWishlistControls.lua
-- Wishlist filter bar (zone dropdown, auto-filter), wishlist selector bar, static popup dialogs

BiSGearCheck = BiSGearCheck or {}

-- ============================================================
-- STATIC POPUP DIALOGS (defined at file scope)
-- ============================================================

-- Helper to get editBox from a static popup frame
local function GetPopupEditBox(dialog)
    return dialog.editBox or _G[dialog:GetName() .. "EditBox"]
end

StaticPopupDialogs["BISGEARCHECK_NEW_WISHLIST"] = {
    text = "Enter a name for the new wishlist:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self)
        local eb = GetPopupEditBox(self)
        local name = eb and eb:GetText():trim() or ""
        if name ~= "" then
            if BiSGearCheck:CreateWishlist(name) then
                BiSGearCheck:RefreshView()
            else
                print("|cffff6666BiS Gear Check:|r A wishlist named '" .. name .. "' already exists.")
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = self:GetText():trim()
        if name ~= "" then
            if BiSGearCheck:CreateWishlist(name) then
                BiSGearCheck:RefreshView()
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

StaticPopupDialogs["BISGEARCHECK_RENAME_WISHLIST"] = {
    text = "Rename '%s' to:",
    button1 = "Rename",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        local eb = GetPopupEditBox(self)
        if eb then
            eb:SetText(BiSGearCheck.activeWishlist)
            eb:HighlightText()
        end
    end,
    OnAccept = function(self)
        local eb = GetPopupEditBox(self)
        local name = eb and eb:GetText():trim() or ""
        if name ~= "" then
            if BiSGearCheck:RenameWishlist(name) then
                BiSGearCheck:RefreshView()
            else
                print("|cffff6666BiS Gear Check:|r A wishlist named '" .. name .. "' already exists.")
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = self:GetText():trim()
        if name ~= "" then
            if BiSGearCheck:RenameWishlist(name) then
                BiSGearCheck:RefreshView()
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

StaticPopupDialogs["BISGEARCHECK_DELETE_WISHLIST"] = {
    text = "Delete wishlist '%s'?\n\nThis cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        if BiSGearCheck:DeleteWishlist() then
            BiSGearCheck:RefreshView()
        end
    end,
    timeout = 0,
    whileDead = true,
    preferredIndex = 3,
}

-- ============================================================
-- WISHLIST FILTER BAR (zone dropdown + auto-filter checkbox)
-- ============================================================

function BiSGearCheck:SetupWishlistFilterBar(f)
    local filterBar = CreateFrame("Frame", nil, f)
    filterBar:SetSize(self.FRAME_WIDTH - 20, 52)
    filterBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -52)
    filterBar:Hide()

    -- Zone dropdown (right-aligned, same row as wishlist name dropdown)
    local zoneDropdown = CreateFrame("Frame", "BiSGearCheckZoneDropdown", filterBar, "UIDropDownMenuTemplate")
    zoneDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -52)
    UIDropDownMenu_SetWidth(zoneDropdown, 130)

    local function ZoneDropdownInit(self, level)
        -- "All Zones" option
        local info = UIDropDownMenu_CreateInfo()
        info.text = "All Zones"
        info.value = ""
        info.func = function(self)
            UIDropDownMenu_SetSelectedValue(zoneDropdown, "")
            UIDropDownMenu_SetText(zoneDropdown, "All Zones")
            BiSGearCheck.wishlistZoneFilter = nil
            BiSGearCheck:RefreshView()
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        -- Categorized zones with dividers
        for catIdx, category in ipairs(BiSGearCheck.ZoneCategories) do
            -- Section header (non-clickable divider)
            local hdr = UIDropDownMenu_CreateInfo()
            hdr.text = category.label
            hdr.isTitle = true
            hdr.notCheckable = true
            UIDropDownMenu_AddButton(hdr, level)

            -- Zone entries in this category
            for _, zone in ipairs(category.zones) do
                local hasItems = BiSGearCheck:ZoneHasWishlistItems(zone)
                local zInfo = UIDropDownMenu_CreateInfo()
                if hasItems then
                    zInfo.text = "  |cff00ff00" .. zone .. "|r"
                else
                    zInfo.text = "  " .. zone
                end
                zInfo.value = zone
                zInfo.func = function(self)
                    UIDropDownMenu_SetSelectedValue(zoneDropdown, self.value)
                    UIDropDownMenu_SetText(zoneDropdown, zone)
                    BiSGearCheck.wishlistZoneFilter = self.value
                    BiSGearCheck:RefreshView()
                end
                zInfo.notCheckable = true
                UIDropDownMenu_AddButton(zInfo, level)
            end
        end
    end
    UIDropDownMenu_Initialize(zoneDropdown, ZoneDropdownInit)
    UIDropDownMenu_SetText(zoneDropdown, "All Zones")

    -- Auto checkbox (right-aligned, below zone dropdown)
    local autoCheck = CreateFrame("CheckButton", "BiSGearCheckAutoFilter", filterBar, "UICheckButtonTemplate")
    autoCheck:SetSize(24, 24)
    autoCheck:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -78)
    autoCheck:SetChecked(self.wishlistAutoFilter)
    autoCheck.text = autoCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoCheck.text:SetPoint("RIGHT", autoCheck, "LEFT", -2, 0)
    autoCheck.text:SetText("Auto")
    autoCheck:SetScript("OnClick", function(self)
        BiSGearCheck:SetWishlistAutoFilter(self:GetChecked())
        BiSGearCheck:RefreshView()
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
end

-- ============================================================
-- WISHLIST SELECTOR BAR (dropdown + New / Rename / Delete)
-- ============================================================

function BiSGearCheck:SetupWishlistSelectorBar(f)
    local wlSelectorBar = CreateFrame("Frame", nil, f)
    wlSelectorBar:SetSize(self.FRAME_WIDTH - 20, 52)
    wlSelectorBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -52)
    wlSelectorBar:Hide()

    -- Wishlist name dropdown (left side, row 2)
    local wlNameDropdown = CreateFrame("Frame", "BiSGearCheckWLNameDropdown", wlSelectorBar, "UIDropDownMenuTemplate")
    wlNameDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -5, -52)
    UIDropDownMenu_SetWidth(wlNameDropdown, 130)

    local function WLNameDropdownInit(self, level)
        local names = BiSGearCheck:GetWishlistNames()
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(wlNameDropdown, self.value)
                UIDropDownMenu_SetText(wlNameDropdown, self.value)
                BiSGearCheck:SetActiveWishlist(self.value)
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(wlNameDropdown, WLNameDropdownInit)
    UIDropDownMenu_SetText(wlNameDropdown, self.activeWishlist)

    -- New / Rename / Delete buttons (below wishlist dropdown, row 3)
    local wlNewBtn = CreateFrame("Button", nil, wlSelectorBar, "UIPanelButtonTemplate")
    wlNewBtn:SetSize(50, 22)
    wlNewBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -78)
    wlNewBtn:SetText("New")
    wlNewBtn:SetScript("OnClick", function()
        StaticPopup_Show("BISGEARCHECK_NEW_WISHLIST")
    end)

    local wlRenameBtn = CreateFrame("Button", nil, wlSelectorBar, "UIPanelButtonTemplate")
    wlRenameBtn:SetSize(60, 22)
    wlRenameBtn:SetPoint("LEFT", wlNewBtn, "RIGHT", 2, 0)
    wlRenameBtn:SetText("Rename")
    wlRenameBtn:SetScript("OnClick", function()
        StaticPopupDialogs["BISGEARCHECK_RENAME_WISHLIST"].text = "Rename '" .. BiSGearCheck.activeWishlist .. "' to:"
        StaticPopup_Show("BISGEARCHECK_RENAME_WISHLIST")
    end)

    local wlDeleteBtn = CreateFrame("Button", nil, wlSelectorBar, "UIPanelButtonTemplate")
    wlDeleteBtn:SetSize(55, 22)
    wlDeleteBtn:SetPoint("LEFT", wlRenameBtn, "RIGHT", 2, 0)
    wlDeleteBtn:SetText("Delete")
    wlDeleteBtn:SetScript("OnClick", function()
        StaticPopupDialogs["BISGEARCHECK_DELETE_WISHLIST"].text = "Delete wishlist '" .. BiSGearCheck.activeWishlist .. "'?\n\nThis cannot be undone."
        StaticPopup_Show("BISGEARCHECK_DELETE_WISHLIST")
    end)

    f.wlSelectorBar = wlSelectorBar
    f.wlNameDropdown = wlNameDropdown
end
