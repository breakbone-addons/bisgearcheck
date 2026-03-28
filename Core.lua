-- BiSGearCheck Core.lua
-- State variables, event handling, initialization, minimap button, refresh, spec/source management

BiSGearCheck = BiSGearCheck or {}
BiSGearCheck.selectedSpec = nil
BiSGearCheck.dataSource = "wowtbcgg"
BiSGearCheck.comparisonResults = {}
BiSGearCheck.itemCache = {}
BiSGearCheck.pendingItems = {}
BiSGearCheck.viewMode = "comparison" -- "comparison", "wishlist", or "bislist"
BiSGearCheck.bislistSpec = nil -- selected spec on BiS Lists tab (any class)
BiSGearCheck.wishlistZoneFilter = nil -- nil = no filter, string = zone name
BiSGearCheck.zoneFilter = nil -- zone filter for Compare and BiS Lists tabs
BiSGearCheck.wishlistAutoFilter = false
BiSGearCheck.activeWishlist = "Default" -- name of current wishlist
BiSGearCheck.currentZone = ""
BiSGearCheck.playerFaction = "Alliance" -- detected at init
BiSGearCheck.playerKey = nil -- "Name-Realm" key for character registry
BiSGearCheck.viewingCharKey = nil -- which character the UI is operating as (nil = current)

-- Event frame
local eventFrame = CreateFrame("Frame", "BiSGearCheckEventFrame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("INSPECT_READY")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        BiSGearCheck:Initialize()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID, success = ...
        if itemID and BiSGearCheck.pendingItems[itemID] then
            if success then
                BiSGearCheck.pendingItems[itemID] = nil
                BiSGearCheck.needsRefresh = true
            else
                -- Item failed to load — leave in pendingItems so we don't re-request
                BiSGearCheck.pendingItems[itemID] = "failed"
            end
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Update gear snapshot for cross-character viewing
        if BiSGearCheck.playerKey then
            BiSGearCheck:SnapshotEquippedGear()
        end
        if BiSGearCheck.mainFrame and BiSGearCheck.mainFrame:IsShown() then
            BiSGearCheck:Refresh()
        end
    elseif event == "INSPECT_READY" then
        if BiSGearCheck.isRaidScanning then
            BiSGearCheck:OnRaidScanInspectReady()
        else
            BiSGearCheck:OnInspectReady()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if BiSGearCheck.isRaidScanning then
            BiSGearCheck.raidScanRosterChanged = true
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        BiSGearCheck:OnZoneChanged()
    end
end)

-- ============================================================
-- INSPECT HANDLER
-- ============================================================

function BiSGearCheck:OnInspectReady()
    -- Keep INSPECT_READY registered — addons like Examiner use NotifyInspect
    -- directly (bypassing InspectUnit), so unregistering would miss future inspects
    self.expectingInspect = false

    local charKey = self:SnapshotInspectedGear()
    if not charKey then return end

    -- Refresh the settings inspect list if it's open
    if self.RefreshInspectedList then
        self:RefreshInspectedList()
    end

    -- Only auto-show when a user-initiated inspect frame is visible.
    -- Other addons (GearScore, Details, etc.) may call InspectUnit in the
    -- background — we capture their gear data above but should NOT pop
    -- open the BGC window for those.
    local inspectFrameOpen = (_G["InspectFrame"] and _G["InspectFrame"]:IsShown())
                          or (_G["Examiner"] and _G["Examiner"]:IsShown())
    if not inspectFrameOpen then return end

    if BiSGearCheckSaved and BiSGearCheckSaved.autoShowOnInspect ~= false then
        self:CreateUI()
        self:SetViewingCharacter(charKey)
        if self.UpdateCharDropdownText then
            self:UpdateCharDropdownText()
        end
        self.viewMode = "comparison"
        self.mainFrame:Show()
        self:Refresh()
    end
end

-- Hook InspectUnit: register INSPECT_READY only when user initiates inspect
if InspectUnit then
    hooksecurefunc("InspectUnit", function(unit)
        if not BiSGearCheck.isRaidScanning then
            BiSGearCheck.expectingInspect = true
        end
        eventFrame:RegisterEvent("INSPECT_READY")
    end)
end

-- Also hook the Blizzard InspectFrame when it loads
local inspectHooked = false
local function HookInspectFrame()
    if inspectHooked then return end
    local frame = _G["InspectFrame"]
    if frame then
        inspectHooked = true
        frame:HookScript("OnShow", function()
            if not BiSGearCheck.expectingInspect and not BiSGearCheck.isRaidScanning then
                BiSGearCheck.expectingInspect = true
                eventFrame:RegisterEvent("INSPECT_READY")
            end
        end)
    end
end
-- InspectFrame is load-on-demand, so hook when it becomes available
if IsAddOnLoaded and IsAddOnLoaded("Blizzard_InspectUI") then
    HookInspectFrame()
else
    local hookFrame = CreateFrame("Frame")
    hookFrame:RegisterEvent("ADDON_LOADED")
    hookFrame:SetScript("OnEvent", function(self, event, addon)
        if addon == "Blizzard_InspectUI" then
            HookInspectFrame()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

-- ============================================================
-- INITIALIZE
-- ============================================================

function BiSGearCheck:Initialize()
    -- Detect faction
    self.playerFaction = UnitFactionGroup("player") or "Alliance"

    -- Build character key
    self.playerKey = self:GetCharacterKey()

    -- Migrate and initialize saved variables
    self:MigrateSavedVars()
    self:RegisterCharacter()

    -- Restore per-character settings
    if BiSGearCheckChar then
        self.selectedSpec = BiSGearCheckChar.selectedSpec
        self.dataSource = BiSGearCheckChar.dataSource or "wowtbcgg"
        self.wishlistAutoFilter = BiSGearCheckChar.wishlistAutoFilter or false
    else
        BiSGearCheckChar = {}
    end

    -- Restore active wishlist for this character
    local charData = self:GetCharacterData(self.playerKey)
    if charData then
        self.activeWishlist = charData.activeWishlist or "Default"
        if not charData.wishlists[self.activeWishlist] then
            self.activeWishlist = "Default"
        end
    end

    -- Default to viewing own wishlists
    self.viewingCharKey = self.playerKey

    if not self.selectedSpec then
        self.selectedSpec = self:GuessSpec()
    end

    -- Force Phase 1 while phase selection is disabled
    self.phaseFilter = 1
    BiSGearCheckSaved.phaseFilter = 1

    -- Initialize data source settings and unload fully disabled sources
    self:EnsureSourceSettings()
    self:UnloadDisabledSources()

    -- Ensure the saved data source is valid for the current phase
    local currentSrc
    for _, src in ipairs(self.DataSources) do
        if src.key == self.dataSource then currentSrc = src; break end
    end
    if not currentSrc or not self:SourceHasPhase(currentSrc, self.phaseFilter or 1) then
        local available = self:GetEnabledDataSourcesForPhase()
        if available[1] then
            self.dataSource = available[1].key
            BiSGearCheckChar.dataSource = self.dataSource
        end
    end

    -- Ensure minimap saved vars
    if not BiSGearCheckSaved.minimap then
        BiSGearCheckSaved.minimap = { hide = false }
    end

    -- Create minimap button via LibDBIcon
    self:CreateMinimapButton()

    -- Track current zone
    self.currentZone = GetRealZoneText() or ""

    -- Initialize tooltip system
    self:EnsureTooltipSettings()
    self:BuildTooltipIndex()
    self:CheckTooltipConflict()

    -- Restore last raid scan results (if any)
    self:RestoreLastRaidScan()

    -- Register slash commands
    SLASH_BISGEARCHECK1 = "/bisgear"
    SLASH_BISGEARCHECK2 = "/bgc"
    SlashCmdList["BISGEARCHECK"] = function(msg)
        if msg == "wishlist" or msg == "wl" then
            BiSGearCheck.viewMode = "wishlist"
        else
            BiSGearCheck.viewMode = "comparison"
        end
        BiSGearCheck:Toggle()
    end
end

-- ============================================================
-- MINIMAP BUTTON
-- ============================================================

function BiSGearCheck:CreateMinimapButton()
    local ldb = LibStub("LibDataBroker-1.1", true)
    if not ldb then return end

    local dataObj = ldb:NewDataObject("BiSGearCheck", {
        type = "launcher",
        text = "BiSGearCheck",
        icon = "Interface\\AddOns\\BiSGearCheck\\minimap-icon",
        label = "BiSGearCheck",
        OnClick = function(_, button)
            if IsAltKeyDown() then
                if Settings and Settings.OpenToCategory and BiSGearCheck.settingsCategoryID then
                    Settings.OpenToCategory(BiSGearCheck.settingsCategoryID)
                elseif InterfaceOptionsFrame_OpenToCategory then
                    InterfaceOptionsFrame_OpenToCategory("BiSGearCheck")
                    InterfaceOptionsFrame_OpenToCategory("BiSGearCheck")
                end
                return
            end
            if button == "LeftButton" then
                BiSGearCheck.viewMode = "comparison"
                BiSGearCheck:Toggle()
            elseif button == "RightButton" then
                BiSGearCheck.viewMode = "wishlist"
                if not BiSGearCheck.mainFrame then
                    BiSGearCheck:CreateUI()
                end
                BiSGearCheck:Refresh()
                BiSGearCheck.mainFrame:Show()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("BiSGearCheck", 0, 0.82, 1)
            tt:AddLine("Left-click: Compare gear", 1, 1, 1)
            tt:AddLine("Right-click: Wishlist", 1, 1, 1)
            tt:AddLine("Alt-click: Settings", 1, 1, 1)
            tt:AddLine("/bisgear or /bgc", 0.5, 0.5, 0.5)
        end,
    })

    local icon = LibStub("LibDBIcon-1.0", true)
    if icon then
        icon:Register("BiSGearCheck", dataObj, BiSGearCheckSaved.minimap)
    end
end

-- ============================================================
-- TOGGLE / REFRESH
-- ============================================================

function BiSGearCheck:Toggle()
    if not self.mainFrame then
        self:CreateUI()
    end
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
        -- Prompt garbage collection to reclaim render/comparison tables
        collectgarbage("collect")
    else
        self:Refresh()
        self.mainFrame:Show()
    end
end

function BiSGearCheck:Refresh()
    if not self.selectedSpec then
        self.selectedSpec = self:GuessSpec()
    end
    self:RunComparison()
    self:RefreshView()
end

function BiSGearCheck:RefreshView()
    if not self.mainFrame then return end
    if self.viewMode == "wishlist" then
        self:RenderWishlist()
    elseif self.viewMode == "bislist" then
        self:RenderBisList()
    elseif self.viewMode == "raid" then
        self:RenderRaid()
    else
        self:RenderResults()
    end
end

-- ============================================================
-- SPEC / DATA SOURCE MANAGEMENT
-- ============================================================

function BiSGearCheck:SetSpec(specKey)
    self.selectedSpec = specKey
    if self:IsViewingOwnCharacter() then
        -- Persist to player's per-character saved var
        BiSGearCheckChar.selectedSpec = specKey
        local charData = self:GetCharacterData(self.playerKey)
        if charData then charData.selectedSpec = specKey end
    else
        -- Persist to the inspected character's saved data
        local charKey = self:GetViewingCharKey()
        local charData = self:GetCharacterData(charKey)
        if charData then charData.selectedSpec = specKey end
    end
    self:Refresh()
end

function BiSGearCheck:SetDataSource(sourceKey)
    self.dataSource = sourceKey
    BiSGearCheckChar.dataSource = sourceKey

    -- If current spec doesn't exist in new data source, pick first available
    local db = self:GetActiveDB()
    if db and self.selectedSpec and not db[self.selectedSpec] then
        local _, classToken = UnitClass("player")
        local specs = self.ClassSpecs[classToken]
        if specs then
            for _, specInfo in ipairs(specs) do
                if db[specInfo.key] then
                    self.selectedSpec = specInfo.key
                    BiSGearCheckChar.selectedSpec = specInfo.key
                    break
                end
            end
        end
    end

    self:Refresh()
end

-- Called when the phase dropdown changes — switch source if needed and refresh
function BiSGearCheck:OnPhaseChanged()
    -- If the current source has no data for the new phase, switch to one that does
    local phase = self.phaseFilter or 1
    local currentSrc
    for _, src in ipairs(self.DataSources) do
        if src.key == self.dataSource then
            currentSrc = src
            break
        end
    end
    if not currentSrc or not self:SourceHasPhase(currentSrc, phase) then
        local available = self:GetEnabledDataSourcesForPhase()
        if available[1] then
            self.dataSource = available[1].key
            BiSGearCheckChar.dataSource = self.dataSource
        end
    end
    self:BuildTooltipIndex()
    self:Refresh()
end

-- Get the active BiS database based on selected data source and phase
function BiSGearCheck:GetActiveDB()
    local phase = self.phaseFilter or 1
    for _, src in ipairs(self.DataSources) do
        if src.key == self.dataSource then
            local dbName = self:GetSourceDBName(src, phase)
            if dbName then return _G[dbName] end
            return nil
        end
    end
    return nil
end

-- ============================================================
-- ZONE CHANGE HANDLER
-- ============================================================

function BiSGearCheck:OnZoneChanged()
    local newZone = GetRealZoneText() or ""
    if newZone ~= self.currentZone then
        self.currentZone = newZone
        if self.wishlistAutoFilter and self.viewMode == "wishlist" then
            local isKnownZone = false
            for _, zone in pairs(self.SourceToZone) do
                if zone == newZone then
                    isKnownZone = true
                    break
                end
            end
            self.wishlistZoneFilter = isKnownZone and newZone or nil
            if self.mainFrame and self.mainFrame:IsShown() then
                self:RefreshView()
            end
        end
    end
end
