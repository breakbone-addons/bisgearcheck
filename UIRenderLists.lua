-- BiSGearCheck UIRenderLists.lua
-- RenderWishlist and RenderBisList for the Wishlists and BiS Lists tabs

BiSGearCheck = BiSGearCheck or {}

-- Reusable buffer for wishlist zone filtering
local _wlFilterBuf = {}

-- ============================================================
-- RENDER WISHLIST
-- ============================================================

function BiSGearCheck:RenderWishlist()
    local f = self.mainFrame
    if not f then return end

    f.wlSelectorBar:Show()
    f.filterBar:Show()
    f.bislistBar:Hide()
    f.compareWLDropdown:Hide()
    f.compareWLLabel:Hide()
    f.collapseAllBtn:Hide()
    f.expandAllBtn:Hide()
    f.zoneFilterDropdown:Hide()
    f.sourceDropdown:Hide()
    f.specDropdown:Hide()
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -104)

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
    self:ClearScrollContent(scrollChild)

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
    local contentWidth = self.FRAME_WIDTH - 45

    -- Apply zone filter (reuse buffer)
    wipe(_wlFilterBuf)
    for _, item in ipairs(items) do
        if not self.wishlistZoneFilter or self:ItemMatchesZone(item.id, self.wishlistZoneFilter) then
            _wlFilterBuf[#_wlFilterBuf + 1] = item
        end
    end
    local filteredItems = _wlFilterBuf

    if #filteredItems == 0 then
        local row = self:CreateRow(scrollChild, yOffset, contentWidth)
        if self.wishlistZoneFilter then
            row.text:SetText("|cff999999No wishlist items for " .. self.wishlistZoneFilter .. "|r")
        else
            row.text:SetText("|cff999999Your wishlist is empty. Add items from the comparison view.|r")
        end
        yOffset = yOffset - self.ITEM_ROW_HEIGHT
    else
        local currentSlot = nil
        for _, item in ipairs(filteredItems) do
            if item.slotName ~= currentSlot then
                currentSlot = item.slotName
                local header = self:CreateRow(scrollChild, yOffset, contentWidth)
                header.text:SetText("|cffffd100" .. (currentSlot or "Unknown") .. "|r")
                yOffset = yOffset - self.SLOT_HEADER_HEIGHT
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

            -- Store data on the row for shared handlers
            row._itemID = item.id

            -- Remove button (reused from pool, shared handlers)
            local removeBtn, removeBg, btnText = self:GetActionButton(row)
            removeBg:SetColorTexture(0.5, 0.0, 0.0, 0.8)
            btnText:SetText("|cffffffffx|r")

            removeBtn:SetScript("OnClick", self.OnWishlistRemoveClick)
            removeBtn:SetScript("OnEnter", self.OnWishlistRemoveEnter)
            removeBtn:SetScript("OnLeave", self.OnTooltipLeave)

            -- Item tooltip (shared handler)
            row:EnableMouse(true)
            row:SetScript("OnEnter", self.OnItemIDEnter)
            row:SetScript("OnLeave", self.OnTooltipLeave)

            yOffset = yOffset - self.ITEM_ROW_HEIGHT
        end
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- ============================================================
-- RENDER BIS LISTS
-- ============================================================

function BiSGearCheck:RenderBisList()
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
    -- Position zone filter on the bislist bar row, after the spec dropdown
    f.zoneFilterDropdown:ClearAllPoints()
    f.zoneFilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -52)
    f.zoneFilterDropdown:Show()
    UIDropDownMenu_SetText(f.zoneFilterDropdown, self.zoneFilter or "All Zones")
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -104)

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
    self:ClearScrollContent(scrollChild)

    local specKey = self.bislistSpec
    local db = self:GetActiveDB()

    if not specKey or not db or not db[specKey] then
        f.title:SetText("BiS Gear Check - |cff00ccffBiS Lists|r")
        local yOffset = -5
        local contentWidth = self.FRAME_WIDTH - 45
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
    local contentWidth = self.FRAME_WIDTH - 45

    for _, slotName in ipairs(self.SlotOrder) do
        local rawItems = specData.slots[slotName]
        local items = rawItems and self:FilterBisListByFaction(rawItems) or {}

        -- When zone filter is active, check if any items match
        if self.zoneFilter and #items > 0 then
            local hasMatch = false
            for _, itemID in ipairs(items) do
                if self:ItemMatchesZone(itemID, self.zoneFilter) then
                    hasMatch = true
                    break
                end
            end
            if not hasMatch then items = {} end
        end

        if #items > 0 then
            local isCollapsed = self.collapsedSlots[slotName]
            local arrow = isCollapsed and "|cffffd100[+]|r " or "|cffffd100[-]|r "

            -- Slot header (shared handler)
            local header = self:CreateRow(scrollChild, yOffset, contentWidth)
            header.text:SetText(arrow .. "|cffffd100" .. slotName .. "|r")
            header._slotName = slotName
            header:EnableMouse(true)
            header:SetScript("OnMouseDown", self.OnSlotHeaderClick)
            yOffset = yOffset - self.SLOT_HEADER_HEIGHT

            if not isCollapsed then
                for rank, itemID in ipairs(items) do
                    -- Skip items that don't match zone filter
                    if not self.zoneFilter or self:ItemMatchesZone(itemID, self.zoneFilter) then
                    local row = self:CreateRow(scrollChild, yOffset, contentWidth)

                    local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
                    if not name then
                        self.pendingItems[itemID] = true
                        C_Item.RequestLoadItemDataByID(itemID)
                    end

                    local itemText = link or name or ("Item #" .. itemID)
                    local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]
                    local sourceText = ""
                    if sourceInfo and sourceInfo.source and sourceInfo.source ~= "Unknown" then
                        if sourceInfo.sourceType and sourceInfo.sourceType ~= "" then
                            sourceText = string.format("|cff888888- %s (%s)|r", sourceInfo.source, sourceInfo.sourceType)
                        else
                            sourceText = string.format("|cff888888- %s|r", sourceInfo.source)
                        end
                    end

                    row.text:SetText(string.format("  |cff00ccff#%d|r %s %s", rank, itemText, sourceText))

                    -- Item tooltip on hover (shared handler)
                    row._itemID = itemID
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", self.OnItemIDEnter)
                    row:SetScript("OnLeave", self.OnTooltipLeave)

                    yOffset = yOffset - self.ITEM_ROW_HEIGHT
                    end -- end zone filter check
                end

                -- Enchant recommendations for this slot
                local enchantSlot = self.SlotToEnchantSlot[slotName]
                local specEnchants = specKey and BiSGearCheckEnchantsDB and BiSGearCheckEnchantsDB[specKey]
                local slotEnchants = enchantSlot and specEnchants and specEnchants[enchantSlot]
                if slotEnchants and #slotEnchants > 0 then
                    local enchHeader = self:CreateRow(scrollChild, yOffset, contentWidth)
                    enchHeader.text:SetText("  |cff00ccffEnchants:|r")
                    yOffset = yOffset - self.ITEM_ROW_HEIGHT

                    for _, enchant in ipairs(slotEnchants) do
                        local row = self:CreateRow(scrollChild, yOffset, contentWidth)
                        row.text:SetText(string.format("    |cffa335ee%s|r", enchant[2]))
                        row._enchantID = enchant[1]
                        row:EnableMouse(true)
                        row:SetScript("OnEnter", self.OnEnchantEnter)
                        row:SetScript("OnLeave", self.OnTooltipLeave)
                        yOffset = yOffset - self.ITEM_ROW_HEIGHT
                    end
                end
            end

            -- Separator (reused from pool)
            local sep = self:CreateRow(scrollChild, yOffset, contentWidth)
            local line = self:GetSeparatorLine(sep)
            line:SetColorTexture(0.3, 0.3, 0.3, 0.5)
            yOffset = yOffset - 6
            yOffset = yOffset - self.SECTION_SPACING
        end
    end

    -- Recommended gems section at bottom
    local gemsData = specKey and BiSGearCheckGemsDB and BiSGearCheckGemsDB[specKey]
    if gemsData then
        local gemHeader = self:CreateRow(scrollChild, yOffset, contentWidth)
        gemHeader.text:SetText("|cffffd100Recommended Gems|r")
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT

        if gemsData.meta then
            local row = self:CreateRow(scrollChild, yOffset, contentWidth)
            row.text:SetText(string.format("  |cff888888Meta:|r |cffa335ee%s|r", gemsData.meta[2]))
            row._itemID = gemsData.meta[1]
            row:EnableMouse(true)
            row:SetScript("OnEnter", self.OnItemIDEnter)
            row:SetScript("OnLeave", self.OnTooltipLeave)
            yOffset = yOffset - self.ITEM_ROW_HEIGHT
        end

        for _, color in ipairs({"red", "yellow", "blue"}) do
            local gems = gemsData[color]
            if gems and #gems > 0 then
                local label = color:sub(1,1):upper() .. color:sub(2)
                for _, gem in ipairs(gems) do
                    local row = self:CreateRow(scrollChild, yOffset, contentWidth)
                    row.text:SetText(string.format("  |cff888888%s:|r |cffa335ee%s|r", label, gem[2]))
                    row._itemID = gem[1]
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", self.OnItemIDEnter)
                    row:SetScript("OnLeave", self.OnTooltipLeave)
                    yOffset = yOffset - self.ITEM_ROW_HEIGHT
                end
            end
        end

        local sep = self:CreateRow(scrollChild, yOffset, contentWidth)
        local line = self:GetSeparatorLine(sep)
        line:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        yOffset = yOffset - 6
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end
