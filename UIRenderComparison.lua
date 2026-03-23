-- BiSGearCheck UIRenderComparison.lua
-- RenderResults and RenderSlotSection for the Compare tab

BiSGearCheck = BiSGearCheck or {}

-- Rank text helper (module-level, not per-call)
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

-- ============================================================
-- RENDER COMPARISON RESULTS
-- ============================================================

function BiSGearCheck:RenderResults()
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
    -- Position zone filter on the source/spec row, after the spec dropdown
    f.zoneFilterDropdown:ClearAllPoints()
    f.zoneFilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -52)
    f.zoneFilterDropdown:Show()
    UIDropDownMenu_SetText(f.zoneFilterDropdown, self.zoneFilter or "All Zones")
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -104)

    local scrollChild = f.scrollChild
    self:ClearScrollContent(scrollChild)

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
    local contentWidth = self.FRAME_WIDTH - 45

    for _, slotResult in ipairs(self.comparisonResults) do
        -- When zone filter is active, skip slots with no matching upgrades
        if self.zoneFilter then
            local hasMatch = false
            for _, upgrade in ipairs(slotResult.upgrades) do
                if self:ItemMatchesZone(upgrade.id, self.zoneFilter) then
                    hasMatch = true
                    break
                end
            end
            if not hasMatch then
                -- skip this slot entirely
            else
                yOffset = self:RenderSlotSection(scrollChild, slotResult, yOffset, contentWidth)
                yOffset = yOffset - self.SECTION_SPACING
            end
        else
            yOffset = self:RenderSlotSection(scrollChild, slotResult, yOffset, contentWidth)
            yOffset = yOffset - self.SECTION_SPACING
        end
    end

    -- Recommended gems section at bottom
    local specKey = self.selectedSpec
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

-- ============================================================
-- RENDER SLOT SECTION
-- ============================================================

function BiSGearCheck:RenderSlotSection(parent, slotResult, yOffset, width)
    local slotName = slotResult.slotName
    local isCollapsed = self.collapsedSlots[slotName]
    local isDualSlot = (slotName == "Rings" or slotName == "Trinkets")
    local specKey = self.selectedSpec

    local arrow = isCollapsed and "|cffffd100[+]|r " or "|cffffd100[-]|r "

    if not isDualSlot and #slotResult.equipped == 1 then
        -- Single-slot: combine header + equipped on one line
        local eq = slotResult.equipped[1]
        local header = self:CreateRow(parent, yOffset, width)
        local eqLink = eq.link or GetInventoryItemLink("player", eq.invSlot)
        local eqText = eqLink or ("Item #" .. eq.id)
        local warnings, wrongEnchantID = {}, nil
        if eqLink then
            warnings, wrongEnchantID = self:GetEquipWarnings(eqLink, slotName, specKey)
        end
        header.text:SetText(arrow .. "|cffffd100" .. slotName .. ":|r " .. eqText .. " - " .. rankStr(eq))
        header._slotName = slotName
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", self.OnSlotHeaderClick)
        if eqLink then
            header._itemLink = eqLink
            header:SetScript("OnEnter", self.OnItemLinkEnter)
            header:SetScript("OnLeave", self.OnTooltipLeave)
        end

        -- All warnings pinned to right side of same row
        if #warnings > 0 then
            local warnText = table.concat(warnings, " ")
            header.text:SetPoint("RIGHT", header, "RIGHT", -100, 0)
            local wf, wLabel = self:GetWarningLabel(header)
            wLabel:SetText(warnText)
            wf:SetWidth(wLabel:GetStringWidth() + 8)
            if wrongEnchantID then
                wf._enchantID = wrongEnchantID
                wf:SetScript("OnEnter", self.OnEnchantEnter)
                wf:SetScript("OnLeave", self.OnTooltipLeave)
            end
        end

        yOffset = yOffset - self.SLOT_HEADER_HEIGHT
    elseif not isDualSlot and #slotResult.equipped == 0 then
        -- Single-slot empty: combine header + empty
        local header = self:CreateRow(parent, yOffset, width)
        header.text:SetText(arrow .. "|cffffd100" .. slotName .. ":|r |cff999999(empty)|r")
        header._slotName = slotName
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", self.OnSlotHeaderClick)
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT
    else
        -- Dual-slot: header then equipped items
        local header = self:CreateRow(parent, yOffset, width)
        header.text:SetText(arrow .. "|cffffd100" .. slotName .. "|r")
        header._slotName = slotName
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", self.OnSlotHeaderClick)
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT

        if not isCollapsed then
            for _, eq in ipairs(slotResult.equipped) do
                local row = self:CreateRow(parent, yOffset, width)
                local lateLink = eq.link or GetInventoryItemLink("player", eq.invSlot)
                local eqText = lateLink or ("Item #" .. eq.id)
                local warnings, wrongEnchantID = {}, nil
                if lateLink then
                    warnings, wrongEnchantID = self:GetEquipWarnings(lateLink, slotName, specKey)
                end
                row.text:SetText("  Equipped: " .. eqText .. " - " .. rankStr(eq))
                if lateLink then
                    row._itemLink = lateLink
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", self.OnItemLinkEnter)
                    row:SetScript("OnLeave", self.OnTooltipLeave)
                end

                -- All warnings pinned to right side of same row
                if #warnings > 0 then
                    local warnText = table.concat(warnings, " ")
                    row.text:SetPoint("RIGHT", row, "RIGHT", -100, 0)
                    local wf, wLabel = self:GetWarningLabel(row)
                    wLabel:SetText(warnText)
                    wf:SetWidth(wLabel:GetStringWidth() + 8)
                    if wrongEnchantID then
                        wf._enchantID = wrongEnchantID
                        wf:SetScript("OnEnter", self.OnEnchantEnter)
                        wf:SetScript("OnLeave", self.OnTooltipLeave)
                    end
                end

                yOffset = yOffset - self.ITEM_ROW_HEIGHT
            end

            if #slotResult.equipped == 0 then
                local row = self:CreateRow(parent, yOffset, width)
                row.text:SetText("  |cff999999(empty slots)|r")
                yOffset = yOffset - self.ITEM_ROW_HEIGHT
            end
        end
    end

    if not isCollapsed then
        for _, upgrade in ipairs(slotResult.upgrades) do
            -- Skip items that don't match the zone filter
            if self.zoneFilter and not self:ItemMatchesZone(upgrade.id, self.zoneFilter) then
                -- skip
            else
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

            -- Store data on the row for shared handlers
            row._upgrade = upgrade
            row._itemID = upgrade.id

            -- Wishlist + button (reused from pool, shared handlers)
            local onWL = self:IsOnWishlist(upgrade.id)
            local addBtn, btnBg, btnText = self:GetActionButton(row)

            if onWL then
                btnBg:SetColorTexture(0.0, 0.5, 0.0, 0.8)
            else
                btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
            end
            btnText:SetText("|cffffffff+|r")

            addBtn:SetScript("OnClick", self.OnWishlistToggleClick)
            addBtn:SetScript("OnEnter", self.OnWishlistToggleEnter)
            addBtn:SetScript("OnLeave", self.OnTooltipLeave)

            -- Item tooltip on hover (shared handler)
            row:EnableMouse(true)
            row:SetScript("OnEnter", self.OnItemIDEnter)
            row:SetScript("OnLeave", self.OnTooltipLeave)

            yOffset = yOffset - self.ITEM_ROW_HEIGHT
            end -- end zone filter else
        end

        -- Enchant recommendations for this slot
        local enchantSlot = self.SlotToEnchantSlot[slotName]
        local specEnchants = specKey and BiSGearCheckEnchantsDB and BiSGearCheckEnchantsDB[specKey]
        local slotEnchants = enchantSlot and specEnchants and specEnchants[enchantSlot]
        if slotEnchants and #slotEnchants > 0 then
            -- Filter out enchants from the opposing Shattrath faction
            local hasVisible = false
            for _, enchant in ipairs(slotEnchants) do
                if not self:IsWrongShattFaction(enchant[1]) then
                    hasVisible = true
                    break
                end
            end

            if hasVisible then
                local enchHeader = self:CreateRow(parent, yOffset, width)
                enchHeader.text:SetText("  |cff00ccffEnchants:|r")
                yOffset = yOffset - self.ITEM_ROW_HEIGHT

                for _, enchant in ipairs(slotEnchants) do
                    if not self:IsWrongShattFaction(enchant[1]) then
                        local row = self:CreateRow(parent, yOffset, width)
                        row.text:SetText(string.format("    |cffa335ee%s|r", enchant[2]))
                        local lf = self:GetLinkFrame(row)
                        lf._enchantID = enchant[1]
                        lf:SetScript("OnEnter", self.OnEnchantEnter)
                        lf:SetScript("OnLeave", self.OnTooltipLeave)
                        yOffset = yOffset - self.ITEM_ROW_HEIGHT
                    end
                end
            end
        end
    end

    -- Separator (reused from pool)
    local sep = self:CreateRow(parent, yOffset, width)
    local line = self:GetSeparatorLine(sep)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    yOffset = yOffset - 6

    return yOffset
end
