-- BiSGearCheck UIRenderRaid.lua
-- Raid tab controls and rendering: scan button, progress, per-character issue/upgrade display

BiSGearCheck = BiSGearCheck or {}

-- ============================================================
-- RAID CHARACTER CONTEXT MENU
-- ============================================================

local raidContextMenuFrame

function BiSGearCheck:ShowRaidCharContextMenu(charKey)
    local result = self.raidScanResults[charKey]
    if not result then return end

    if not raidContextMenuFrame then
        raidContextMenuFrame = CreateFrame("Frame", "BiSGearCheckRaidContextMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local name = charKey:match("^([^%-]+)") or charKey

    UIDropDownMenu_Initialize(raidContextMenuFrame, function(self, level)
        local info = UIDropDownMenu_CreateInfo()

        if result.issueCount > 0 then
            info.text = "Whisper Issues to " .. name
            info.notCheckable = true
            info.func = function()
                BiSGearCheck:WhisperIssues(charKey)
            end
            UIDropDownMenu_AddButton(info, level)
        else
            info.text = "No issues to whisper"
            info.notCheckable = true
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
        end

        info = UIDropDownMenu_CreateInfo()
        info.text = "Cancel"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end, "MENU")

    ToggleDropDownMenu(1, nil, raidContextMenuFrame, "cursor", 0, 0)
end

-- ============================================================
-- RAID CONTROLS SETUP
-- ============================================================

function BiSGearCheck:SetupRaidControls(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetHeight(54)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -56)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -56)
    bar:Hide()

    -- Row 1: Scan / Export / Report buttons (zone dropdown positioned in RenderRaid)
    local scanBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    scanBtn:SetSize(90, 22)
    scanBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -4)
    scanBtn:SetText("Scan Raid")
    scanBtn:SetScript("OnClick", function()
        if BiSGearCheck.raidScanState == "scanning" then
            BiSGearCheck:CancelRaidScan()
        else
            BiSGearCheck:StartRaidScan()
        end
    end)

    local exportBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    exportBtn:SetSize(56, 22)
    exportBtn:SetPoint("LEFT", scanBtn, "RIGHT", 4, 0)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        BiSGearCheck:ShowRaidScanExport()
    end)

    local reportBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    reportBtn:SetSize(56, 22)
    reportBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
    reportBtn:SetText("Report")
    reportBtn:SetScript("OnClick", function()
        BiSGearCheck:PrintRaidIssueReport()
    end)

    -- Row 2: Collapse/Expand All + progress text
    local collapseBtn = CreateFrame("Button", nil, bar)
    collapseBtn:SetSize(70, 16)
    collapseBtn:SetPoint("TOPLEFT", scanBtn, "BOTTOMLEFT", 3, -4)
    local collapseText = collapseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collapseText:SetPoint("LEFT")
    collapseText:SetText("|cff00ccffCollapse All|r")
    collapseBtn:SetScript("OnClick", function()
        for charKey in pairs(BiSGearCheck.raidScanResults) do
            BiSGearCheck.raidCollapsedChars[charKey] = true
        end
        BiSGearCheck:RefreshView()
    end)

    local expandBtn = CreateFrame("Button", nil, bar)
    expandBtn:SetSize(65, 16)
    expandBtn:SetPoint("LEFT", collapseBtn, "RIGHT", 8, 0)
    local expandText = expandBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expandText:SetPoint("LEFT")
    expandText:SetText("|cff00ccffExpand All|r")
    expandBtn:SetScript("OnClick", function()
        wipe(BiSGearCheck.raidCollapsedChars)
        BiSGearCheck:RefreshView()
    end)

    local progressText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("LEFT", expandBtn, "RIGHT", 10, 0)
    progressText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    progressText:SetJustifyH("LEFT")
    progressText:SetTextColor(0.7, 0.7, 0.7)

    bar.scanBtn = scanBtn
    bar.exportBtn = exportBtn
    bar.reportBtn = reportBtn
    bar.collapseBtn = collapseBtn
    bar.expandBtn = expandBtn
    bar.progressText = progressText
    f.raidBar = bar
end

-- ============================================================
-- RENDER RAID TAB
-- ============================================================

function BiSGearCheck:RenderRaid()
    local f = self.mainFrame
    if not f then return end

    -- Hide other tab controls
    f.filterBar:Hide()
    f.bislistBar:Hide()
    f.wlSelectorBar:Hide()
    f.compareWLDropdown:Hide()
    f.compareWLLabel:Hide()
    f.collapseAllBtn:Hide()
    f.expandAllBtn:Hide()
    f.sourceDropdown:Hide()
    f.specDropdown:Hide()
    if f.phaseDropdown then f.phaseDropdown:Hide() end
    f.charDropdown:Hide()
    if f.charDropdownLabel then f.charDropdownLabel:Hide() end

    -- Show raid controls + zone filter on the same row as buttons
    f.raidBar:Show()
    f.zoneFilterDropdown:ClearAllPoints()
    f.zoneFilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -56)
    f.zoneFilterDropdown:Show()
    UIDropDownMenu_SetText(f.zoneFilterDropdown, self.zoneFilter or "All Zones")
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -112)

    -- Update scan button text
    local scanBtn = f.raidBar.scanBtn
    if self.raidScanState == "scanning" then
        scanBtn:SetText("Cancel")
    elseif IsInRaid() then
        scanBtn:SetText("Scan Raid")
    elseif GetNumGroupMembers() > 0 then
        scanBtn:SetText("Scan Group")
    else
        scanBtn:SetText("Scan Raid")
    end

    -- Update progress text
    local progressText = f.raidBar.progressText
    if self.raidScanState == "scanning" then
        local total = #self.raidScanQueue
        local current = math.min(self.raidScanIndex, total)
        progressText:SetText(string.format("Scanning %d/%d...", current, total))
    elseif self.raidScanState == "complete" then
        local scanned = self:GetRaidScanCount()
        local skipped = #self.raidScanSkipped
        local timeStr = ""
        if BiSGearCheckSaved and BiSGearCheckSaved.lastRaidScan then
            local elapsed = time() - BiSGearCheckSaved.lastRaidScan.time
            if elapsed < 60 then
                timeStr = " (just now)"
            elseif elapsed < 3600 then
                timeStr = string.format(" (%d min ago)", math.floor(elapsed / 60))
            else
                timeStr = string.format(" (%d hr ago)", math.floor(elapsed / 3600))
            end
        end
        local msg = string.format("Complete: %d scanned", scanned)
        if skipped > 0 then
            msg = msg .. string.format(", %d skipped", skipped)
        end
        if self.raidScanRosterChanged then
            msg = msg .. " |cffff6600(roster changed)|r"
        end
        progressText:SetText(msg .. timeStr)
    else
        if GetNumGroupMembers() == 0 then
            progressText:SetText("Join a group to scan.")
        else
            progressText:SetText("")
        end
    end

    -- Render scroll content
    local scrollChild = f.scrollChild
    self:ClearScrollContent(scrollChild)

    local yOffset = -5
    local contentWidth = self.FRAME_WIDTH - 45

    -- If no results, show placeholder
    if not next(self.raidScanResults) and self.raidScanState ~= "scanning" then
        local row = self:CreateRow(scrollChild, yOffset, contentWidth)
        if GetNumGroupMembers() == 0 then
            row.text:SetText("|cff999999Join a raid or party and click Scan to check gear.|r")
        else
            row.text:SetText("|cff999999Click Scan to inspect group members.|r")
        end
        yOffset = yOffset - self.ITEM_ROW_HEIGHT
        scrollChild:SetHeight(math.abs(yOffset) + 20)
        return
    end

    -- Render each scanned character
    local sortedKeys = self:GetSortedRaidScanKeys()
    for _, charKey in ipairs(sortedKeys) do
        yOffset = self:RenderRaidCharacter(scrollChild, charKey, yOffset, contentWidth)
    end

    -- Render skipped section
    if #self.raidScanSkipped > 0 then
        yOffset = yOffset - self.SECTION_SPACING

        local header = self:CreateRow(scrollChild, yOffset, contentWidth)
        header.text:SetText("|cff888888Skipped:|r")
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT

        for _, skip in ipairs(self.raidScanSkipped) do
            local row = self:CreateRow(scrollChild, yOffset, contentWidth)
            local coloredName = self:ClassColor(skip.class, skip.name)
            row.text:SetText("  " .. coloredName .. " |cff888888- " .. skip.reason .. "|r")
            yOffset = yOffset - self.ITEM_ROW_HEIGHT
        end
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- ============================================================
-- RENDER SINGLE CHARACTER
-- ============================================================

function BiSGearCheck:RenderRaidCharacter(parent, charKey, yOffset, width)
    local result = self.raidScanResults[charKey]
    if not result then return yOffset end

    local charData = self:GetCharacterData(charKey)
    if not charData then return yOffset end

    local isCollapsed = self.raidCollapsedChars[charKey]
    local arrow = isCollapsed and "|cffffd100[+]|r " or "|cffffd100[-]|r "

    -- Spec label
    local specLabel = ""
    local specs = self.ClassSpecs[charData.class]
    if specs and result.specKey then
        for _, s in ipairs(specs) do
            if s.key == result.specKey then
                specLabel = s.label
                break
            end
        end
    end

    -- Character name (class-colored)
    local name = charKey:match("^([^%-]+)")
    local coloredName = self:ClassColor(charData.class, name)

    -- Upgrade count
    local upgradeCount = 0
    for _, slotUpgrades in pairs(result.upgrades) do
        upgradeCount = upgradeCount + #slotUpgrades
    end
    local upgradeBadge = ""
    if upgradeCount > 0 then
        upgradeBadge = string.format(" |cff00ccff[%d Upgrade%s]|r",
            upgradeCount, upgradeCount == 1 and "" or "s")
    end

    -- Header row
    local header = self:CreateRow(parent, yOffset, width)
    local headerText = arrow .. coloredName
    if specLabel ~= "" then
        headerText = headerText .. " |cff888888(" .. specLabel .. ")|r"
    end
    header.text:SetText(headerText)
    header.text:SetPoint("RIGHT", header, "RIGHT", -120, 0)

    -- Issue badge (hoverable with tooltip showing specifics)
    local issueBadgeText
    if result.issueCount > 0 then
        issueBadgeText = string.format("|cffff3333[%d Issue%s]|r",
            result.issueCount, result.issueCount == 1 and "" or "s")
    else
        issueBadgeText = "|cff00ff00[OK]|r"
    end
    local wf, wLabel = self:GetWarningLabel(header)
    wLabel:SetText(issueBadgeText .. upgradeBadge)
    wf:SetWidth(wLabel:GetStringWidth() + 8)
    wf._raidCharKey = charKey

    if result.issueCount > 0 then
        wf:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine(coloredName .. " — Issues", 1, 0.82, 0)
            local res = BiSGearCheck.raidScanResults[frame._raidCharKey]
            if res then
                for _, issue in ipairs(res.issues) do
                    local itemName
                    if issue.itemLink then
                        itemName = issue.itemLink
                    elseif issue.itemID then
                        local name = GetItemInfo(issue.itemID)
                        itemName = name or ("Item #" .. issue.itemID)
                    else
                        itemName = "?"
                    end
                    -- Strip color codes from warnings for cleaner tooltip
                    local warnList = table.concat(issue.warnings, " ")
                    GameTooltip:AddDoubleLine(
                        issue.slotName .. ": " .. itemName,
                        warnList,
                        1, 1, 1, 1, 1, 1
                    )
                end
            end
            GameTooltip:Show()
        end)
        wf:SetScript("OnLeave", self.OnTooltipLeave)
    end

    header._raidCharKey = charKey
    header:EnableMouse(true)
    header:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            BiSGearCheck:ShowRaidCharContextMenu(charKey)
        else
            BiSGearCheck.raidCollapsedChars[charKey] = not BiSGearCheck.raidCollapsedChars[charKey]
            BiSGearCheck:RefreshView()
        end
    end)
    yOffset = yOffset - self.SLOT_HEADER_HEIGHT

    if isCollapsed then
        -- Separator
        local sep = self:CreateRow(parent, yOffset, width)
        local line = self:GetSeparatorLine(sep)
        line:SetColorTexture(0.3, 0.3, 0.3, 0.3)
        yOffset = yOffset - 6
        return yOffset
    end

    -- Issues by slot
    if result.issueCount > 0 then
        for _, issue in ipairs(result.issues) do
            local row = self:CreateRow(parent, yOffset, width)
            local itemText = issue.itemLink or ("Item #" .. (issue.itemID or "?"))
            local warnText = table.concat(issue.warnings, " ")
            row.text:SetText(string.format("  |cffffd100%s:|r %s %s",
                issue.slotName, itemText, warnText))

            if issue.itemLink then
                row._itemLink = issue.itemLink
                row:EnableMouse(true)
                row:SetScript("OnEnter", self.OnItemLinkEnter)
                row:SetScript("OnLeave", self.OnTooltipLeave)
            elseif issue.itemID then
                row._itemID = issue.itemID
                row:EnableMouse(true)
                row:SetScript("OnEnter", self.OnItemIDEnter)
                row:SetScript("OnLeave", self.OnTooltipLeave)
            end

            yOffset = yOffset - self.ITEM_ROW_HEIGHT
        end
    end

    -- Upgrades
    local hasUpgrades = false
    for _, slotName in ipairs(self.SlotOrder) do
        local slotUpgrades = result.upgrades[slotName]
        if slotUpgrades and #slotUpgrades > 0 then
            -- Apply zone filter
            local visibleUpgrades = {}
            for _, upgrade in ipairs(slotUpgrades) do
                local hideSource = self:IsItemFilteredByRaidSource(upgrade.id)
                local hideZone = self.zoneFilter and not self:ItemMatchesZone(upgrade.id, self.zoneFilter)
                if not hideSource and not hideZone then
                    visibleUpgrades[#visibleUpgrades + 1] = upgrade
                end
            end

            if #visibleUpgrades > 0 then
                if not hasUpgrades then
                    local hdr = self:CreateRow(parent, yOffset, width)
                    hdr.text:SetText("  |cff00ccffUpgrades:|r")
                    yOffset = yOffset - self.ITEM_ROW_HEIGHT
                    hasUpgrades = true
                else
                    -- Small gap between slot sections
                    yOffset = yOffset - 4
                end

                -- Slot label
                local slotRow = self:CreateRow(parent, yOffset, width)
                slotRow.text:SetText("    |cffffd100" .. slotName .. "|r")
                yOffset = yOffset - self.ITEM_ROW_HEIGHT

                for _, upgrade in ipairs(visibleUpgrades) do
                    local row = self:CreateRow(parent, yOffset, width)
                    local lateName, lateLink = GetItemInfo(upgrade.id)
                    local itemText = lateLink or lateName or ("Item #" .. upgrade.id)

                    local sourceText = ""
                    if upgrade.source and upgrade.source ~= "Unknown" then
                        if upgrade.sourceType and upgrade.sourceType ~= "" then
                            sourceText = string.format("|cff888888%s (%s)|r", upgrade.source, upgrade.sourceType)
                        else
                            sourceText = string.format("|cff888888%s|r", upgrade.source)
                        end
                    end

                    row.text:SetText(string.format("      |cff00ccff#%d|r %s %s",
                        upgrade.rank, itemText, sourceText))

                    row._itemID = upgrade.id
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", self.OnItemIDEnter)
                    row:SetScript("OnLeave", self.OnTooltipLeave)

                    yOffset = yOffset - self.ITEM_ROW_HEIGHT
                end
            end
        end
    end

    -- Separator
    local sep = self:CreateRow(parent, yOffset, width)
    local line = self:GetSeparatorLine(sep)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.3)
    yOffset = yOffset - 6

    return yOffset
end
