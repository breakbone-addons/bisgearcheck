-- BISGearCheck Core.lua
-- State variables, event handling, initialization, minimap button, refresh, spec/source management

BISGearCheck = BISGearCheck or {}
BISGearCheck.selectedSpec = nil
BISGearCheck.dataSource = "wowtbcgg"
BISGearCheck.comparisonResults = {}
BISGearCheck.itemCache = {}
BISGearCheck.pendingItems = {}
BISGearCheck.viewMode = "comparison" -- "comparison", "wishlist", or "bislist"
BISGearCheck.bislistSpec = nil -- selected spec on BiS Lists tab (any class)
BISGearCheck.wishlistZoneFilter = nil -- nil = no filter, string = zone name
BISGearCheck.wishlistAutoFilter = false
BISGearCheck.activeWishlist = "Default" -- name of current wishlist
BISGearCheck.currentZone = ""
BISGearCheck.playerFaction = "Alliance" -- detected at init
BISGearCheck.playerKey = nil -- "Name-Realm" key for character registry
BISGearCheck.viewingCharKey = nil -- which character the UI is operating as (nil = current)

-- Event frame
local eventFrame = CreateFrame("Frame", "BISGearCheckEventFrame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        BISGearCheck:Initialize()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        if itemID and BISGearCheck.pendingItems[itemID] then
            BISGearCheck.pendingItems[itemID] = nil
            BISGearCheck.needsRefresh = true
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Update gear snapshot for cross-character viewing
        if BISGearCheck.playerKey then
            BISGearCheck:SnapshotEquippedGear()
        end
        if BISGearCheck.mainFrame and BISGearCheck.mainFrame:IsShown() then
            BISGearCheck:Refresh()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        BISGearCheck:OnZoneChanged()
    end
end)

-- ============================================================
-- INITIALIZE
-- ============================================================

function BISGearCheck:Initialize()
    -- Detect faction
    self.playerFaction = UnitFactionGroup("player") or "Alliance"

    -- Build character key
    self.playerKey = self:GetCharacterKey()

    -- Migrate and initialize saved variables
    self:MigrateSavedVars()
    self:RegisterCharacter()

    -- Restore per-character settings
    if BISGearCheckChar then
        self.selectedSpec = BISGearCheckChar.selectedSpec
        self.dataSource = BISGearCheckChar.dataSource or "wowtbcgg"
        self.wishlistAutoFilter = BISGearCheckChar.wishlistAutoFilter or false
    else
        BISGearCheckChar = {}
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

    -- Ensure minimap saved vars
    if not BISGearCheckSaved.minimap then
        BISGearCheckSaved.minimap = { hide = false }
    end

    -- Create minimap button via LibDBIcon
    self:CreateMinimapButton()

    -- Track current zone
    self.currentZone = GetRealZoneText() or ""

    -- Initialize tooltip system
    self:EnsureTooltipSettings()
    self:BuildTooltipIndex()
    self:CheckTooltipConflict()

    -- Register slash commands
    SLASH_BISGEARCHECK1 = "/bisgear"
    SLASH_BISGEARCHECK2 = "/bgc"
    SlashCmdList["BISGEARCHECK"] = function(msg)
        if msg == "wishlist" or msg == "wl" then
            BISGearCheck.viewMode = "wishlist"
        else
            BISGearCheck.viewMode = "comparison"
        end
        BISGearCheck:Toggle()
    end
end

-- ============================================================
-- MINIMAP BUTTON
-- ============================================================

function BISGearCheck:CreateMinimapButton()
    local ldb = LibStub("LibDataBroker-1.1", true)
    if not ldb then return end

    local dataObj = ldb:NewDataObject("BISGearCheck", {
        type = "launcher",
        text = "BiS Gear Check",
        icon = "Interface\\Icons\\INV_Misc_Book_01",
        label = "BiS Gear Check",
        OnClick = function(_, button)
            if IsAltKeyDown() then
                if Settings and Settings.OpenToCategory and BISGearCheck.settingsCategoryID then
                    Settings.OpenToCategory(BISGearCheck.settingsCategoryID)
                elseif InterfaceOptionsFrame_OpenToCategory then
                    InterfaceOptionsFrame_OpenToCategory("BiS Gear Check")
                    InterfaceOptionsFrame_OpenToCategory("BiS Gear Check")
                end
                return
            end
            if button == "LeftButton" then
                BISGearCheck.viewMode = "comparison"
                BISGearCheck:Toggle()
            elseif button == "RightButton" then
                BISGearCheck.viewMode = "wishlist"
                if not BISGearCheck.mainFrame then
                    BISGearCheck:CreateUI()
                end
                BISGearCheck:Refresh()
                BISGearCheck.mainFrame:Show()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("BiS Gear Check", 0, 0.82, 1)
            tt:AddLine("Left-click: Compare gear", 1, 1, 1)
            tt:AddLine("Right-click: Wishlist", 1, 1, 1)
            tt:AddLine("Alt-click: Settings", 1, 1, 1)
            tt:AddLine("/bisgear or /bgc", 0.5, 0.5, 0.5)
        end,
    })

    local icon = LibStub("LibDBIcon-1.0", true)
    if icon then
        icon:Register("BISGearCheck", dataObj, BISGearCheckSaved.minimap)
    end
end

-- ============================================================
-- TOGGLE / REFRESH
-- ============================================================

function BISGearCheck:Toggle()
    if not self.mainFrame then
        self:CreateUI()
    end
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self:Refresh()
        self.mainFrame:Show()
    end
end

function BISGearCheck:Refresh()
    if not self.selectedSpec then
        self.selectedSpec = self:GuessSpec()
    end
    self:RunComparison()
    self:RefreshView()
end

function BISGearCheck:RefreshView()
    if not self.mainFrame then return end
    if self.viewMode == "wishlist" then
        self:RenderWishlist()
    elseif self.viewMode == "bislist" then
        self:RenderBisList()
    else
        self:RenderResults()
    end
end

-- ============================================================
-- SPEC / DATA SOURCE MANAGEMENT
-- ============================================================

function BISGearCheck:SetSpec(specKey)
    self.selectedSpec = specKey
    BISGearCheckChar.selectedSpec = specKey
    -- Update snapshot so other characters see the correct spec
    if self:IsViewingOwnCharacter() then
        local charData = self:GetCharacterData(self.playerKey)
        if charData then charData.selectedSpec = specKey end
    end
    self:Refresh()
end

function BISGearCheck:SetDataSource(sourceKey)
    self.dataSource = sourceKey
    BISGearCheckChar.dataSource = sourceKey

    -- If current spec doesn't exist in new data source, pick first available
    local db = self:GetActiveDB()
    if db and self.selectedSpec and not db[self.selectedSpec] then
        local _, classToken = UnitClass("player")
        local specs = self.ClassSpecs[classToken]
        if specs then
            for _, specInfo in ipairs(specs) do
                if db[specInfo.key] then
                    self.selectedSpec = specInfo.key
                    BISGearCheckChar.selectedSpec = specInfo.key
                    break
                end
            end
        end
    end

    self:Refresh()
end

-- Get the active BiS database based on selected data source
function BISGearCheck:GetActiveDB()
    for _, src in ipairs(self.DataSources) do
        if src.key == self.dataSource then
            return _G[src.db]
        end
    end
    return BISGearCheckDB
end

-- ============================================================
-- ZONE CHANGE HANDLER
-- ============================================================

function BISGearCheck:OnZoneChanged()
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
