-- BiSGearCheck ElvUISkin.lua
-- Optional ElvUI skin integration. Detected at runtime, applied when enabled.

BiSGearCheck = BiSGearCheck or {}

function BiSGearCheck:IsElvUILoaded()
    return ElvUI ~= nil
end

function BiSGearCheck:IsElvUISkinEnabled()
    return BiSGearCheckSaved and BiSGearCheckSaved.elvuiSkin == true
end

-- ============================================================
-- APPLY ELVUI SKIN TO ALL FRAMES
-- ============================================================

function BiSGearCheck:ApplyElvUISkin()
    if not self:IsElvUILoaded() then return end

    local E = unpack(ElvUI)
    local S = E:GetModule("Skins")
    if not S then return end

    self._elvuiSkinApplied = true
    self._elvuiE = E
    self._elvuiS = S

    local f = self.mainFrame
    if not f then return end

    -- Main frame
    pcall(function()
        f:StripTextures()
        f:SetTemplate("Transparent")
    end)

    -- Title bar: re-create since StripTextures removes the header texture
    if f.title then
        f.title:SetPoint("TOP", f, "TOP", 0, -6)
    end

    -- Close button
    for _, child in ipairs({ f:GetChildren() }) do
        if child:GetObjectType() == "Button" and child:GetName() == nil then
            -- UIPanelCloseButton has no global name here
            local regions = { child:GetRegions() }
            for _, r in ipairs(regions) do
                if r:GetObjectType() == "Texture" then
                    local tex = r:GetTexture()
                    if tex and type(tex) == "string" and tex:find("CloseButton") then
                        pcall(S.HandleCloseButton, S, child)
                        break
                    end
                end
            end
        end
    end

    -- Tabs
    local tabs = { f.compTab, f.wlTab, f.bisTab, f.raidTab }
    for _, tab in ipairs(tabs) do
        if tab then
            pcall(S.HandleButton, S, tab)
        end
    end

    -- Dropdowns: use old=true to preserve the clickable button area
    local dropdowns = {
        f.charDropdown, f.sourceDropdown, f.specDropdown,
        f.compareWLDropdown, f.zoneFilterDropdown,
        f.bislistSourceDropdown, f.bislistSpecDropdown,
    }
    if f.zoneDropdown then dropdowns[#dropdowns + 1] = f.zoneDropdown end
    if f.wlNameDropdown then dropdowns[#dropdowns + 1] = f.wlNameDropdown end

    for _, dd in ipairs(dropdowns) do
        if dd then pcall(S.HandleDropDownBox, S, dd, nil, nil, true) end
    end

    -- Scroll bar
    local scrollBar = f.scrollFrame and (f.scrollFrame.ScrollBar or _G["BiSGearCheckScrollFrameScrollBar"])
    if scrollBar then
        pcall(S.HandleScrollBar, S, scrollBar)
    end

    -- Auto-filter checkbox
    if f.autoCheck then
        pcall(S.HandleCheckBox, S, f.autoCheck)
    end

    -- UIPanelButtonTemplate buttons on raid bar
    if f.raidBar then
        self:SkinChildButtons(f.raidBar, S)
    end

    -- UIPanelButtonTemplate buttons on wishlist selector bar
    if f.wlSelectorBar then
        self:SkinChildButtons(f.wlSelectorBar, S)
    end

    -- Settings panel
    self:ApplyElvUISkinToSettings(S)
end

-- ============================================================
-- SKIN SETTINGS PANEL
-- ============================================================

function BiSGearCheck:ApplyElvUISkinToSettings(S)
    local panel = _G["BiSGearCheckSettingsPanel"]
    if not panel then return end

    pcall(function()
        panel:StripTextures()
        panel:SetTemplate("Transparent")
    end)

    -- Re-anchor title
    local titleText = nil
    for _, region in ipairs({ panel:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            local text = region:GetText()
            if text and text:find("Settings") then
                titleText = region
                break
            end
        end
    end
    if titleText then
        titleText:ClearAllPoints()
        titleText:SetPoint("TOP", panel, "TOP", 0, -6)
    end

    -- Close button
    for _, child in ipairs({ panel:GetChildren() }) do
        if child:GetObjectType() == "Button" then
            local regions = { child:GetRegions() }
            for _, r in ipairs(regions) do
                if r:GetObjectType() == "Texture" then
                    local tex = r:GetTexture()
                    if tex and type(tex) == "string" and tex:find("CloseButton") then
                        pcall(S.HandleCloseButton, S, child)
                        break
                    end
                end
            end
        end
    end

    -- Settings scroll bar
    local settingsScrollBar = _G["BiSGearCheckSettingsScrollScrollBar"]
    if settingsScrollBar then
        pcall(S.HandleScrollBar, S, settingsScrollBar)
    end

    -- Skin all CheckButtons and UIPanelButtons in the settings scroll child
    local settingsSCH = _G["BiSGearCheckSettingsScrollChild"]
    if settingsSCH then
        self:SkinChildCheckboxes(settingsSCH, S)
        self:SkinChildButtons(settingsSCH, S)

        -- Slider
        local slider = _G["BiSGearCheckSettingsLevelSlider"]
        if slider then pcall(S.HandleSliderFrame, S, slider) end

        -- Phase dropdown
        local phaseDd = _G["BiSGearCheckSettingsPhaseDropdown"]
        if phaseDd then pcall(S.HandleDropDownBox, S, phaseDd, nil, nil, true) end

        -- Nested scroll bars (ignore list, inspected list)
        for _, name in ipairs({ "BiSGearCheckIgnoreListScrollScrollBar", "BiSGearCheckInspectedScrollScrollBar" }) do
            local sb = _G[name]
            if sb then pcall(S.HandleScrollBar, S, sb) end
        end
    end
end

-- ============================================================
-- SKIN EXPORT FRAME (called lazily after creation)
-- ============================================================

function BiSGearCheck:ApplyElvUISkinToExport()
    if not self._elvuiSkinApplied then return end
    local ef = self.exportFrame
    if not ef or ef._elvuiSkinned then return end
    ef._elvuiSkinned = true

    local S = self._elvuiS
    if not S then return end

    pcall(function()
        ef:StripTextures()
        ef:SetTemplate("Transparent")
    end)

    -- Close button
    for _, child in ipairs({ ef:GetChildren() }) do
        if child:GetObjectType() == "Button" then
            local regions = { child:GetRegions() }
            for _, r in ipairs(regions) do
                if r:GetObjectType() == "Texture" then
                    local tex = r:GetTexture()
                    if tex and type(tex) == "string" and tex:find("CloseButton") then
                        pcall(S.HandleCloseButton, S, child)
                        break
                    end
                end
            end
        end
    end

    -- Export scroll bar
    local exportScrollBar = _G["BiSGearCheckExportScrollScrollBar"]
    if exportScrollBar then
        pcall(S.HandleScrollBar, S, exportScrollBar)
    end
end

-- ============================================================
-- HELPERS: walk children and skin by type
-- ============================================================

function BiSGearCheck:SkinChildButtons(parent, S)
    for _, child in ipairs({ parent:GetChildren() }) do
        if child:GetObjectType() == "Button" then
            -- Only skin UIPanelButtonTemplate-style buttons (have NormalTexture)
            local nt = child:GetNormalTexture()
            if nt then
                pcall(S.HandleButton, S, child)
            end
        end
    end
end

function BiSGearCheck:SkinChildCheckboxes(parent, S)
    for _, child in ipairs({ parent:GetChildren() }) do
        if child:GetObjectType() == "CheckButton" then
            pcall(S.HandleCheckBox, S, child)
        end
        -- Recurse one level into wrapper frames
        if child:GetObjectType() == "Frame" then
            for _, grandchild in ipairs({ child:GetChildren() }) do
                if grandchild:GetObjectType() == "CheckButton" then
                    pcall(S.HandleCheckBox, S, grandchild)
                end
            end
        end
    end
end
