-- BiSGearCheck UI.lua
-- UI constants, main frame creation, scroll frame, CreateRow, ClearScrollContent

BiSGearCheck = BiSGearCheck or {}
local T = BiSGearCheck.Theme

-- UI Constants (accessible across all UI files via namespace)
BiSGearCheck.FRAME_WIDTH = 480
BiSGearCheck.FRAME_HEIGHT = 540
BiSGearCheck.CONTENT_PADDING = 10
BiSGearCheck.SLOT_HEADER_HEIGHT = 20
BiSGearCheck.ITEM_ROW_HEIGHT = 18
BiSGearCheck.SECTION_SPACING = 8

-- Track collapsed state per slot (persists within session)
BiSGearCheck.collapsedSlots = BiSGearCheck.collapsedSlots or {}

-- Frame pool for recycling scroll content rows
BiSGearCheck.framePool = BiSGearCheck.framePool or {}

-- ============================================================
-- CLEAR SCROLL CONTENT
-- ============================================================

function BiSGearCheck:ClearScrollContent(scrollChild)
    if scrollChild.rows then
        for i, row in ipairs(scrollChild.rows) do
            row:Hide()
            row:ClearAllPoints()
            row:EnableMouse(false)
            row:SetScript("OnMouseDown", nil)
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
            row.text:SetText("")
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            -- Clear per-row data references
            row._slotName = nil
            row._itemLink = nil
            row._itemID = nil
            row._upgrade = nil
            row._enchantID = nil
            if row._linkFrame then
                row._linkFrame:Hide()
                row._linkFrame:EnableMouse(false)
                row._linkFrame:SetScript("OnEnter", nil)
                row._linkFrame:SetScript("OnLeave", nil)
                row._linkFrame._enchantID = nil
                row._linkFrame._enchantSpellOverride = nil
            end
            if row._warnFrame then
                row._warnFrame:Hide()
                row._warnFrame:EnableMouse(false)
                row._warnFrame:SetScript("OnEnter", nil)
                row._warnFrame:SetScript("OnLeave", nil)
                row._warnFrame._enchantID = nil
            end
            if row.actionBtn then
                row.actionBtn:Hide()
                row.actionBtn:SetScript("OnClick", nil)
                row.actionBtn:SetScript("OnEnter", nil)
                row.actionBtn:SetScript("OnLeave", nil)
            end
            if row.sepLine then
                row.sepLine:Hide()
            end
            self.framePool[#self.framePool + 1] = row
            scrollChild.rows[i] = nil
        end
    else
        scrollChild.rows = {}
    end
end

-- ============================================================
-- CREATE ROW HELPER (pools and reuses frames)
-- ============================================================

function BiSGearCheck:CreateRow(parent, yOffset, width)
    local row = table.remove(self.framePool)
    if row then
        row:SetParent(parent)
        row:SetSize(width, self.ITEM_ROW_HEIGHT)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
        row:Show()
    else
        row = CreateFrame("Frame", nil, parent)
        row:SetSize(width, self.ITEM_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        T.applyFont(row.text, "small")
    end

    if not parent.rows then parent.rows = {} end
    parent.rows[#parent.rows + 1] = row

    return row
end

-- ============================================================
-- ACTION BUTTON HELPER (reuses button on a row)
-- ============================================================

function BiSGearCheck:GetActionButton(row)
    if row.actionBtn then
        row.actionBtn:Show()
        return row.actionBtn, row.actionBtn.bg, row.actionBtn.label
    end

    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(24, 18)
    btn:SetPoint("RIGHT", row, "RIGHT", -1, 0)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    btn.bg = bg

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 0)
    T.applyFont(label, "normal")
    btn.label = label

    row.actionBtn = btn
    return btn, bg, label
end

-- ============================================================
-- WARNING LABEL HELPER (pinned-right tooltip zone on a row)
-- ============================================================

function BiSGearCheck:GetWarningLabel(row)
    if row._warnFrame then
        row._warnFrame:Show()
        return row._warnFrame, row._warnFrame.label
    end

    local wf = CreateFrame("Frame", nil, row)
    wf:SetHeight(18)
    wf:SetPoint("RIGHT", row, "RIGHT", -1, 0)
    wf:EnableMouse(true)

    local label = wf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    T.applyFont(label, "small")
    wf.label = label

    row._warnFrame = wf
    return wf, label
end

-- ============================================================
-- SEPARATOR LINE HELPER (reuses texture on a row)
-- ============================================================

function BiSGearCheck:GetSeparatorLine(row)
    if row.sepLine then
        row.sepLine:Show()
        return row.sepLine
    end

    local line = row:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -2)
    line:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -2)
    row.sepLine = line
    return line
end

-- ============================================================
-- LINK FRAME HELPER (tooltip target sized to text, not full row)
-- ============================================================

function BiSGearCheck:GetLinkFrame(row)
    local lf = row._linkFrame
    if not lf then
        lf = CreateFrame("Frame", nil, row)
        row._linkFrame = lf
    end
    lf:ClearAllPoints()
    lf:SetPoint("LEFT", row.text, "LEFT", -2, 0)
    lf:SetPoint("TOP", row, "TOP")
    lf:SetPoint("BOTTOM", row, "BOTTOM")
    local tw = row.text:GetStringWidth()
    lf:SetWidth(math.max(tw + 4, 20))
    lf:EnableMouse(true)
    lf:Show()
    return lf
end

-- ============================================================
-- SHARED SCRIPT HANDLERS (eliminates per-render closure creation)
-- ============================================================

-- Slot header click: toggle collapse
BiSGearCheck.OnSlotHeaderClick = function(frame)
    local slotName = frame._slotName
    BiSGearCheck.collapsedSlots[slotName] = not BiSGearCheck.collapsedSlots[slotName]
    BiSGearCheck:RefreshView()
end

-- Item tooltip via hyperlink (for equipped items with known links)
BiSGearCheck.OnItemLinkEnter = function(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(frame._itemLink)
    GameTooltip:Show()
end

-- Item tooltip via item ID (for upgrade/bis items)
BiSGearCheck.OnItemIDEnter = function(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    local _, link = GetItemInfo(frame._itemID)
    if link then
        GameTooltip:SetHyperlink(link)
    else
        GameTooltip:AddLine("Item #" .. frame._itemID)
        GameTooltip:AddLine("Loading...", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

-- Enchant tooltip via spell or item link (uses BiSGearCheckEnchantLinks lookup)
-- Works on both rows (frame._enchantID) and link frames (frame._enchantID)
BiSGearCheck.OnEnchantEnter = function(frame)
    local enchantID = frame._enchantID
    if not enchantID then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    -- Direct spell override (for shared enchantIDs like Major Healing / Major Spellpower)
    if frame._enchantSpellOverride then
        GameTooltip:SetHyperlink("spell:" .. frame._enchantSpellOverride)
        GameTooltip:Show()
        return
    end
    local linkData = BiSGearCheckEnchantLinks and BiSGearCheckEnchantLinks[enchantID]
    if linkData then
        -- Check for slot-specific override (e.g., same enchantID used on different slots)
        local slotName = frame._enchantSlot
        if slotName and linkData[slotName] then
            linkData = linkData[slotName]
        end
        local linkType, linkID = linkData[1], linkData[2]
        if linkType == "spell" then
            GameTooltip:SetHyperlink("spell:" .. linkID)
        elseif linkType == "item" then
            local itemID = linkID
            -- Faction-aware: use horde variant if player is Horde
            if linkData.horde and UnitFactionGroup("player") == "Horde" then
                itemID = linkData.horde
            end
            local _, link = GetItemInfo(itemID)
            if link then
                GameTooltip:SetHyperlink(link)
            else
                GameTooltip:AddLine("Loading item...")
                C_Item.RequestLoadItemDataByID(itemID)
            end
        end
    else
        -- Try enchant hyperlink (works in some Classic builds)
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "enchant:" .. enchantID)
        if not ok then
            GameTooltip:AddLine("Unknown enchant (ID: " .. enchantID .. ")", 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

-- Tooltip for "X items filtered" rows
BiSGearCheck.OnFilteredRowEnter = function(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Filtered Items")
    local counts = row._hiddenCounts
    if counts then
        for reason, count in pairs(counts) do
            GameTooltip:AddDoubleLine(reason, count, 0.6, 0.6, 0.6, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

-- Hide tooltip (shared by all leave handlers)
BiSGearCheck.OnTooltipLeave = function()
    GameTooltip:Hide()
end

-- Wishlist add/remove button click
BiSGearCheck.OnWishlistToggleClick = function(btn)
    local row = btn:GetParent()
    local upgrade = row._upgrade
    if BiSGearCheck:IsOnWishlist(upgrade.id) then
        BiSGearCheck:RemoveFromWishlist(upgrade.id)
        T.applyWishlistBtn(btn.bg, false)
    else
        BiSGearCheck:AddToWishlist(upgrade.id, upgrade.slotName, upgrade.rank, upgrade.source, upgrade.sourceType)
        T.applyWishlistBtn(btn.bg, true)
    end
end

-- Wishlist add/remove button tooltip
BiSGearCheck.OnWishlistToggleEnter = function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    local row = btn:GetParent()
    if BiSGearCheck:IsOnWishlist(row._upgrade.id) then
        GameTooltip:AddLine("Click to remove from Wishlist", 1, 0.3, 0.3)
    else
        GameTooltip:AddLine("Click to add to Wishlist", 0, 1, 0)
    end
    GameTooltip:Show()
end

-- Wishlist remove button click
BiSGearCheck.OnWishlistRemoveClick = function(btn)
    local row = btn:GetParent()
    BiSGearCheck:RemoveFromWishlist(row._itemID)
    BiSGearCheck:RefreshView()
end

-- Wishlist remove button tooltip
BiSGearCheck.OnWishlistRemoveEnter = function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Remove from Wishlist", 1, 0.3, 0.3)
    GameTooltip:Show()
end

-- ============================================================
-- MAIN FRAME
-- ============================================================

function BiSGearCheck:CreateUI()
    if self.mainFrame then return end

    local f = CreateFrame("Frame", "BiSGearCheckFrame", UIParent, "BackdropTemplate")

    -- Restore saved size or fall back to defaults
    local savedW = BiSGearCheckSaved and BiSGearCheckSaved.frameWidth
    local savedH = BiSGearCheckSaved and BiSGearCheckSaved.frameHeight
    self.FRAME_WIDTH = savedW or self.FRAME_WIDTH
    self.FRAME_HEIGHT = savedH or self.FRAME_HEIGHT

    f:SetSize(self.FRAME_WIDTH, self.FRAME_HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(420, 400, 900, 900)
    else
        f:SetMinResize(420, 400)
        f:SetMaxResize(900, 900)
    end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    f:SetClampedToScreen(true)
    T.applyBackdrop(f)
    f:Hide()

    -- Resize grip (bottom-right corner)
    local resizeGrip = CreateFrame("Button", nil, f)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function(self)
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function(self)
        f:StopMovingOrSizing()
        -- Persist size after resize completes
        if BiSGearCheckSaved then
            BiSGearCheckSaved.frameWidth = math.floor(f:GetWidth() + 0.5)
            BiSGearCheckSaved.frameHeight = math.floor(f:GetHeight() + 0.5)
        end
    end)
    f.resizeGrip = resizeGrip

    -- Track size changes: update FRAME_WIDTH/HEIGHT and re-render content
    f:SetScript("OnSizeChanged", function(self, w, h)
        BiSGearCheck.FRAME_WIDTH = math.floor(w + 0.5)
        BiSGearCheck.FRAME_HEIGHT = math.floor(h + 0.5)
        if self.scrollChild then
            self.scrollChild:SetWidth(BiSGearCheck.FRAME_WIDTH - 40)
        end
        -- Defer the refresh so rapid resizing doesn't thrash render
        BiSGearCheck.needsRefresh = true
    end)

    table.insert(UISpecialFrames, "BiSGearCheckFrame")

    -- Title bar
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetText("BiSGearCheck")
    T.applyFont(f.title, "normal")

    local titleBar = f:CreateTexture(nil, "ARTWORK")
    titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBar:SetSize(200, 64)
    titleBar:SetPoint("TOP", 0, 12)

    f.title:SetPoint("TOP", titleBar, "TOP", 0, -14)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    -- Setup all control groups (defined in other UI files)
    self:SetupTabs(f)
    self:SetupCharacterSelector(f)
    self:SetupSourceSpecDropdowns(f)
    self:SetupCollapseControls(f)
    self:SetupWishlistFilterBar(f)
    self:SetupWishlistSelectorBar(f)
    self:SetupBisListBar(f)
    self:SetupRaidControls(f)

    -- ============================================================
    -- SCROLL FRAME
    -- ============================================================

    local scrollFrame = CreateFrame("ScrollFrame", "BiSGearCheckScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -124)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 14)

    local scrollChild = CreateFrame("Frame", "BiSGearCheckScrollChild")
    scrollChild:SetWidth(self.FRAME_WIDTH - 40)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    f.scrollFrame = scrollFrame
    f.scrollChild = scrollChild

    -- Retry refresh when item data has been received + raid scan timer
    f._retryElapsed = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        -- Raid scan timer (runs even when frame is hidden)
        BiSGearCheck:UpdateRaidScanTimer(elapsed)

        f._retryElapsed = f._retryElapsed + elapsed
        if f._retryElapsed < 0.5 then return end
        f._retryElapsed = 0
        if BiSGearCheck.needsRefresh then
            BiSGearCheck.needsRefresh = false
            BiSGearCheck:Refresh()
        end
    end)

    self.mainFrame = f

    -- Apply theme font to dropdown display text (internal <name>Text FontStrings)
    local dropdownNames = {
        "BiSGearCheckCharDropdown", "BiSGearCheckSourceDropdown", "BiSGearCheckSpecDropdown",
        "BiSGearCheckCompareWLDropdown", "BiSGearCheckZoneFilterDropdown",
        "BiSGearCheckBislistSourceDropdown", "BiSGearCheckBislistSpecDropdown",
        "BiSGearCheckZoneDropdown", "BiSGearCheckWLNameDropdown",
    }
    for _, name in ipairs(dropdownNames) do
        local txt = _G[name .. "Text"]
        if txt then T.applyFont(txt, "small") end
    end

    -- Apply ElvUI skin if enabled
    if self:IsElvUILoaded() and self:IsElvUISkinEnabled() then
        self:ApplyElvUISkin()
    end
end
