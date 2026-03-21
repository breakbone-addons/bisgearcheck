-- BISGearCheck Core.lua
-- Slash command, event handling, gear comparison, wishlist, data source management

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
-- CHARACTER KEY HELPER
-- ============================================================

function BISGearCheck:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if name and realm then
        return name .. "-" .. realm
    end
    return nil
end

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
-- SAVED VARIABLE MIGRATION
-- ============================================================

function BISGearCheck:MigrateSavedVars()
    -- Initialize account-wide saved vars if needed
    if not BISGearCheckSaved then
        BISGearCheckSaved = { characters = {} }
    end

    -- Detect old format: wishlists at top level (pre-2.1.0)
    if BISGearCheckSaved.wishlists or BISGearCheckSaved.wishlist then
        local oldWishlists = BISGearCheckSaved.wishlists

        -- Handle even older single-wishlist format
        if BISGearCheckSaved.wishlist and not oldWishlists then
            oldWishlists = { ["Default"] = BISGearCheckSaved.wishlist }
        end

        if not oldWishlists then
            oldWishlists = { ["Default"] = {} }
        end

        -- Move per-character settings to BISGearCheckChar
        if not BISGearCheckChar then
            BISGearCheckChar = {}
        end
        BISGearCheckChar.selectedSpec = BISGearCheckChar.selectedSpec or BISGearCheckSaved.selectedSpec
        BISGearCheckChar.dataSource = BISGearCheckChar.dataSource or BISGearCheckSaved.dataSource
        BISGearCheckChar.wishlistAutoFilter = BISGearCheckChar.wishlistAutoFilter or BISGearCheckSaved.wishlistAutoFilter

        -- Move wishlists to character registry
        if not BISGearCheckSaved.characters then
            BISGearCheckSaved.characters = {}
        end

        local charKey = self:GetCharacterKey()
        if charKey then
            BISGearCheckSaved.characters[charKey] = {
                class = select(2, UnitClass("player")),
                faction = UnitFactionGroup("player") or "Alliance",
                wishlists = oldWishlists,
                activeWishlist = BISGearCheckSaved.activeWishlist or "Default",
            }
        end

        -- Clean up old top-level fields
        BISGearCheckSaved.wishlists = nil
        BISGearCheckSaved.wishlist = nil
        BISGearCheckSaved.activeWishlist = nil
        BISGearCheckSaved.selectedSpec = nil
        BISGearCheckSaved.dataSource = nil
        BISGearCheckSaved.wishlistAutoFilter = nil
    end

    -- Ensure characters table exists
    if not BISGearCheckSaved.characters then
        BISGearCheckSaved.characters = {}
    end

    -- Ensure per-character vars exist
    if not BISGearCheckChar then
        BISGearCheckChar = {}
    end
end

-- ============================================================
-- CHARACTER REGISTRY
-- ============================================================

function BISGearCheck:RegisterCharacter()
    local charKey = self.playerKey
    if not charKey then return end

    if not BISGearCheckSaved.characters[charKey] then
        BISGearCheckSaved.characters[charKey] = {
            class = select(2, UnitClass("player")),
            faction = self.playerFaction,
            wishlists = { ["Default"] = {} },
            activeWishlist = "Default",
        }
    else
        -- Update class/faction in case of changes
        local charData = BISGearCheckSaved.characters[charKey]
        charData.class = select(2, UnitClass("player"))
        charData.faction = self.playerFaction
    end

    -- Snapshot equipped gear for cross-character viewing
    self:SnapshotEquippedGear()
end

-- Save current equipped item IDs so other characters can view this character's gear
function BISGearCheck:SnapshotEquippedGear()
    local charData = self:GetCharacterData(self.playerKey)
    if not charData then return end

    local equipped = {}
    for slotName, invSlots in pairs(self.SlotToInvSlot) do
        equipped[slotName] = {}
        for _, invSlotID in ipairs(invSlots) do
            local itemID = GetInventoryItemID("player", invSlotID)
            local itemLink = GetInventoryItemLink("player", invSlotID)
            if itemID then
                table.insert(equipped[slotName], {
                    id = itemID,
                    link = itemLink,
                    invSlot = invSlotID,
                })
            end
        end
    end
    charData.equipped = equipped
    charData.selectedSpec = self.selectedSpec
end

-- Get character data (for any character on the account)
function BISGearCheck:GetCharacterData(charKey)
    if not charKey or not BISGearCheckSaved or not BISGearCheckSaved.characters then
        return nil
    end
    return BISGearCheckSaved.characters[charKey]
end

-- Get sorted list of all character keys on the account
function BISGearCheck:GetCharacterKeys()
    local keys = {}
    if BISGearCheckSaved and BISGearCheckSaved.characters then
        for key in pairs(BISGearCheckSaved.characters) do
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

-- Get the character key we're currently viewing wishlists for
function BISGearCheck:GetViewingCharKey()
    return self.viewingCharKey or self.playerKey
end

-- Switch which character the entire UI operates as
function BISGearCheck:SetViewingCharacter(charKey)
    local charData = self:GetCharacterData(charKey)
    if not charData then return end

    self.viewingCharKey = charKey

    -- Switch wishlist context
    self.activeWishlist = charData.activeWishlist or "Default"
    if not charData.wishlists[self.activeWishlist] then
        for name in pairs(charData.wishlists) do
            self.activeWishlist = name
            break
        end
    end

    -- Switch spec context to the viewed character's spec/class
    if charKey == self.playerKey then
        -- Viewing own character — restore per-character spec
        self.selectedSpec = BISGearCheckChar.selectedSpec or self:GuessSpec()
    else
        -- Viewing another character — use their last-known spec
        self.selectedSpec = charData.selectedSpec
        -- If their spec is unknown, pick the first available for their class
        if not self.selectedSpec then
            local specs = self.ClassSpecs[charData.class]
            if specs then
                self.selectedSpec = specs[1].key
            end
        end
    end

    self:Refresh()
end

-- Get the class token for the character we're currently viewing
function BISGearCheck:GetViewingClass()
    local charKey = self:GetViewingCharKey()
    if charKey == self.playerKey then
        return select(2, UnitClass("player"))
    end
    local charData = self:GetCharacterData(charKey)
    return charData and charData.class
end

-- Get the faction for the character we're currently viewing
function BISGearCheck:GetViewingFaction()
    local charKey = self:GetViewingCharKey()
    if charKey == self.playerKey then
        return self.playerFaction
    end
    local charData = self:GetCharacterData(charKey)
    return charData and charData.faction or "Alliance"
end

-- Check if viewing the currently logged-in character
function BISGearCheck:IsViewingOwnCharacter()
    return self.viewingCharKey == nil or self.viewingCharKey == self.playerKey
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

-- Zone change handler
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

-- ============================================================
-- CORE COMPARISON (faction-aware)
-- ============================================================

-- Check if an item is available to the player's faction.
-- Items with a "faction" field in SourceDB are restricted; items without it are available to both.
function BISGearCheck:IsItemAvailableForFaction(itemID)
    local sourceInfo = BISGearCheckSources and BISGearCheckSources[itemID]
    if not sourceInfo or not sourceInfo.faction then
        return true -- no faction tag = available to both
    end
    return sourceInfo.faction == self:GetViewingFaction()
end

-- Filter a BiS item list to only include items available to the player's faction.
function BISGearCheck:FilterBisListByFaction(bisItems)
    local filtered = {}
    for _, itemID in ipairs(bisItems) do
        if self:IsItemAvailableForFaction(itemID) then
            table.insert(filtered, itemID)
        end
    end
    return filtered
end

function BISGearCheck:RunComparison()
    local specKey = self.selectedSpec
    local db = self:GetActiveDB()
    if not specKey or not db or not db[specKey] then
        self.comparisonResults = {}
        return
    end

    local specData = db[specKey]
    local results = {}

    for _, slotName in ipairs(self.SlotOrder) do
        local bisItems = specData.slots[slotName]
        if bisItems and #bisItems > 0 then
            local factionItems = self:FilterBisListByFaction(bisItems)
            if #factionItems > 0 then
                local slotResult = self:CompareSlot(slotName, factionItems)
                if slotResult then
                    table.insert(results, slotResult)
                end
            end
        end
    end

    self.comparisonResults = results

    -- Update gear snapshot for current character after comparison
    if self:IsViewingOwnCharacter() then
        self:SnapshotEquippedGear()
    end
end

function BISGearCheck:CompareSlot(slotName, bisItems)
    local invSlots = self.SlotToInvSlot[slotName]
    if not invSlots then return nil end

    local isDualSlot = (slotName == "Rings" or slotName == "Trinkets")
    local maxShow = isDualSlot and 10 or nil

    local result = {
        slotName = slotName,
        equipped = {},
        bisItems = bisItems,
        upgrades = {},
        bestEquippedRank = 999,
        worstEquippedRank = 0,
    }

    local equippedIDs = {}

    if self:IsViewingOwnCharacter() then
        -- Live equipped gear from the current character
        for _, invSlotID in ipairs(invSlots) do
            local itemID = GetInventoryItemID("player", invSlotID)
            local itemLink = GetInventoryItemLink("player", invSlotID)
            if itemID then
                table.insert(result.equipped, {
                    id = itemID,
                    link = itemLink,
                    invSlot = invSlotID,
                })
                equippedIDs[itemID] = true
            end
        end
    else
        -- Snapshot data from another character
        local charData = self:GetViewingCharData()
        if charData and charData.equipped and charData.equipped[slotName] then
            for _, eqInfo in ipairs(charData.equipped[slotName]) do
                table.insert(result.equipped, {
                    id = eqInfo.id,
                    link = eqInfo.link,
                    invSlot = eqInfo.invSlot,
                })
                equippedIDs[eqInfo.id] = true
            end
        end
    end

    for _, eq in ipairs(result.equipped) do
        eq.rank = nil
        for rank, bisID in ipairs(bisItems) do
            if bisID == eq.id then
                eq.rank = rank
                if rank < result.bestEquippedRank then
                    result.bestEquippedRank = rank
                end
                if rank > result.worstEquippedRank then
                    result.worstEquippedRank = rank
                end
                break
            end
        end
    end

    local cutoff
    if isDualSlot then
        cutoff = #bisItems + 1
    else
        cutoff = result.bestEquippedRank
        if cutoff == 999 then cutoff = #bisItems + 1 end
    end

    local shown = 0
    for rank = 1, math.min(cutoff - 1, #bisItems) do
        if maxShow and shown >= maxShow then break end
        local bisID = bisItems[rank]
        if not equippedIDs[bisID] then
            local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(bisID)
            if not name then
                self.pendingItems[bisID] = true
                C_Item.RequestLoadItemDataByID(bisID)
            end

            local sourceInfo = BISGearCheckSources and BISGearCheckSources[bisID]
            table.insert(result.upgrades, {
                id = bisID,
                rank = rank,
                name = name,
                link = link,
                quality = quality,
                icon = icon,
                source = sourceInfo and sourceInfo.source or "Unknown",
                sourceType = sourceInfo and sourceInfo.sourceType or "",
                slotName = slotName,
            })
            shown = shown + 1
        end
    end

    return result
end

-- ============================================================
-- WISHLIST MANAGEMENT (character-aware)
-- ============================================================

-- Get wishlist data for the character we're currently viewing
function BISGearCheck:GetViewingCharData()
    local charKey = self:GetViewingCharKey()
    return self:GetCharacterData(charKey)
end

-- Get the active wishlist table for the character we're viewing
function BISGearCheck:GetActiveWishlistTable()
    local charData = self:GetViewingCharData()
    if not charData or not charData.wishlists then return {} end
    return charData.wishlists[self.activeWishlist] or {}
end

-- Switch to a named wishlist
function BISGearCheck:SetActiveWishlist(name)
    local charData = self:GetViewingCharData()
    if not charData or not charData.wishlists or not charData.wishlists[name] then return end
    self.activeWishlist = name
    charData.activeWishlist = name
    -- Also save to current character's data if viewing own wishlists
    if self.viewingCharKey == self.playerKey then
        local myData = self:GetCharacterData(self.playerKey)
        if myData then myData.activeWishlist = name end
    end
    self:RefreshView()
end

-- Create a new wishlist for the character we're viewing
function BISGearCheck:CreateWishlist(name)
    if not name or name == "" then return false end
    local charData = self:GetViewingCharData()
    if not charData then return false end
    if not charData.wishlists then charData.wishlists = {} end
    if charData.wishlists[name] then return false end -- already exists
    charData.wishlists[name] = {}
    self.activeWishlist = name
    charData.activeWishlist = name
    return true
end

-- Rename the active wishlist
function BISGearCheck:RenameWishlist(newName)
    if not newName or newName == "" then return false end
    local charData = self:GetViewingCharData()
    if not charData or not charData.wishlists then return false end
    if charData.wishlists[newName] then return false end -- name taken
    local oldName = self.activeWishlist
    charData.wishlists[newName] = charData.wishlists[oldName]
    charData.wishlists[oldName] = nil
    self.activeWishlist = newName
    charData.activeWishlist = newName
    return true
end

-- Delete the active wishlist (cannot delete the last one)
function BISGearCheck:DeleteWishlist()
    local charData = self:GetViewingCharData()
    if not charData or not charData.wishlists then return false end
    local count = 0
    for _ in pairs(charData.wishlists) do count = count + 1 end
    if count <= 1 then return false end -- can't delete the last one

    charData.wishlists[self.activeWishlist] = nil
    -- Switch to the first remaining wishlist
    for name, _ in pairs(charData.wishlists) do
        self.activeWishlist = name
        charData.activeWishlist = name
        break
    end
    return true
end

-- Get sorted list of wishlist names for the character we're viewing
function BISGearCheck:GetWishlistNames()
    local names = {}
    local charData = self:GetViewingCharData()
    if charData and charData.wishlists then
        for name in pairs(charData.wishlists) do
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function BISGearCheck:AddToWishlist(itemID, slotName, rank, source, sourceType)
    local charData = self:GetViewingCharData()
    if not charData then return end
    if not charData.wishlists then charData.wishlists = {} end
    if not charData.wishlists[self.activeWishlist] then
        charData.wishlists[self.activeWishlist] = {}
    end

    charData.wishlists[self.activeWishlist][itemID] = {
        slotName = slotName,
        rank = rank,
        source = source or "Unknown",
        sourceType = sourceType or "",
        specKey = self.selectedSpec,
        dataSource = self.dataSource,
    }
end

function BISGearCheck:RemoveFromWishlist(itemID)
    local wl = self:GetActiveWishlistTable()
    if wl then
        wl[itemID] = nil
    end
end

function BISGearCheck:IsOnWishlist(itemID)
    local wl = self:GetActiveWishlistTable()
    return wl and wl[itemID] ~= nil
end

function BISGearCheck:GetWishlistItems()
    local wl = self:GetActiveWishlistTable()
    if not wl then return {} end

    local isViewingOwnChar = (self.viewingCharKey == self.playerKey)

    local items = {}
    for itemID, info in pairs(wl) do
        local isEquipped = false
        -- Can only check equipped status for the current character
        if isViewingOwnChar and info.slotName then
            local invSlots = self.SlotToInvSlot[info.slotName]
            if invSlots then
                for _, invSlotID in ipairs(invSlots) do
                    local equippedID = GetInventoryItemID("player", invSlotID)
                    if equippedID == itemID then
                        isEquipped = true
                        break
                    end
                end
            end
        end

        local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
        if not name then
            self.pendingItems[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
        end

        table.insert(items, {
            id = itemID,
            name = name or ("Item #" .. itemID),
            link = link,
            quality = quality,
            icon = icon,
            slotName = info.slotName,
            rank = info.rank,
            source = info.source,
            sourceType = info.sourceType,
            isEquipped = isEquipped,
        })
    end

    local slotIndex = {}
    for i, s in ipairs(self.SlotOrder) do slotIndex[s] = i end
    table.sort(items, function(a, b)
        local ai = slotIndex[a.slotName] or 99
        local bi = slotIndex[b.slotName] or 99
        if ai ~= bi then return ai < bi end
        return (a.rank or 99) < (b.rank or 99)
    end)

    return items
end

function BISGearCheck:SetWishlistAutoFilter(enabled)
    self.wishlistAutoFilter = enabled
    BISGearCheckChar.wishlistAutoFilter = enabled

    if enabled then
        local isKnownZone = false
        for _, zone in pairs(self.SourceToZone) do
            if zone == self.currentZone then
                isKnownZone = true
                break
            end
        end
        self.wishlistZoneFilter = isKnownZone and self.currentZone or nil
    end
end
