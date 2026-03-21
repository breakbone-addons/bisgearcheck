-- BiSGearCheck UIRenderComparison.lua
-- RenderResults and RenderSlotSection for the Compare tab

BiSGearCheck = BiSGearCheck or {}

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
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -90)

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
        yOffset = self:RenderSlotSection(scrollChild, slotResult, yOffset, contentWidth)
        yOffset = yOffset - self.SECTION_SPACING
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
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", function()
            BiSGearCheck.collapsedSlots[slotName] = not BiSGearCheck.collapsedSlots[slotName]
            BiSGearCheck:RefreshView()
        end)
        if eq.link then
            header:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(eq.link)
                GameTooltip:Show()
            end)
            header:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT
    elseif not isDualSlot and #slotResult.equipped == 0 then
        -- Single-slot empty: combine header + empty
        local header = self:CreateRow(parent, yOffset, width)
        header.text:SetText(arrow .. "|cffffd100" .. slotName .. ":|r |cff999999(empty)|r")
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", function()
            BiSGearCheck.collapsedSlots[slotName] = not BiSGearCheck.collapsedSlots[slotName]
            BiSGearCheck:RefreshView()
        end)
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT
    else
        -- Dual-slot: header then equipped items
        local header = self:CreateRow(parent, yOffset, width)
        header.text:SetText(arrow .. "|cffffd100" .. slotName .. "|r")
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", function()
            BiSGearCheck.collapsedSlots[slotName] = not BiSGearCheck.collapsedSlots[slotName]
            BiSGearCheck:RefreshView()
        end)
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT

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
                if BiSGearCheck:IsOnWishlist(capturedUpgrade.id) then
                    BiSGearCheck:RemoveFromWishlist(capturedUpgrade.id)
                    btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
                else
                    BiSGearCheck:AddToWishlist(capturedUpgrade.id, capturedUpgrade.slotName, capturedUpgrade.rank, capturedUpgrade.source, capturedUpgrade.sourceType)
                    btnBg:SetColorTexture(0.0, 0.5, 0.0, 0.8)
                end
            end)
            addBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if BiSGearCheck:IsOnWishlist(capturedUpgrade.id) then
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

            yOffset = yOffset - self.ITEM_ROW_HEIGHT
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
