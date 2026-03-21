-- BISGearCheck UIRenderLists.lua
-- RenderWishlist and RenderBisList for the Wishlists and BiS Lists tabs

BISGearCheck = BISGearCheck or {}

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
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -100)

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

            yOffset = yOffset - self.ITEM_ROW_HEIGHT
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
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -90)

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
            yOffset = yOffset - self.SLOT_HEADER_HEIGHT

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

                    yOffset = yOffset - self.ITEM_ROW_HEIGHT
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
            yOffset = yOffset - self.SECTION_SPACING
        end
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end
