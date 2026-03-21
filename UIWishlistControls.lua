-- BISGearCheck UIWishlistControls.lua
-- Wishlist filter bar (zone dropdown, auto-filter), wishlist selector bar, static popup dialogs

BISGearCheck = BISGearCheck or {}

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

-- ============================================================
-- WISHLIST FILTER BAR (zone dropdown + auto-filter checkbox)
-- ============================================================

function BISGearCheck:SetupWishlistFilterBar(f)
    local filterBar = CreateFrame("Frame", nil, f)
    filterBar:SetSize(self.FRAME_WIDTH - 20, 26)
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
end

-- ============================================================
-- WISHLIST SELECTOR BAR (dropdown + New / Rename / Delete)
-- ============================================================

function BISGearCheck:SetupWishlistSelectorBar(f)
    local wlSelectorBar = CreateFrame("Frame", nil, f)
    wlSelectorBar:SetSize(self.FRAME_WIDTH - 20, 26)
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
end
