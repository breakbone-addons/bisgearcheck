-- BISGearCheck Core.lua
-- Slash command, event handling, gear comparison, wishlist, data source management

BISGearCheck = BISGearCheck or {}
BISGearCheck.selectedSpec = nil
BISGearCheck.dataSource = "wowtbcgg"
BISGearCheck.comparisonResults = {}
BISGearCheck.itemCache = {}
BISGearCheck.pendingItems = {}
BISGearCheck.viewMode = "comparison" -- "comparison" or "wishlist"
BISGearCheck.wishlistZoneFilter = nil -- nil = no filter, string = zone name
BISGearCheck.wishlistAutoFilter = false
BISGearCheck.currentZone = ""

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
            local pending = 0
            for _ in pairs(BISGearCheck.pendingItems) do pending = pending + 1 end
            if pending == 0 and BISGearCheck.mainFrame and BISGearCheck.mainFrame:IsShown() then
                BISGearCheck:RefreshView()
            end
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if BISGearCheck.mainFrame and BISGearCheck.mainFrame:IsShown() then
            BISGearCheck:Refresh()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        BISGearCheck:OnZoneChanged()
    end
end)

function BISGearCheck:Initialize()
    -- Restore saved state
    if BISGearCheckSaved then
        self.selectedSpec = BISGearCheckSaved.selectedSpec
        self.dataSource = BISGearCheckSaved.dataSource or "wowtbcgg"
        self.wishlistAutoFilter = BISGearCheckSaved.wishlistAutoFilter or false
        if not BISGearCheckSaved.wishlist then
            BISGearCheckSaved.wishlist = {}
        end
    else
        BISGearCheckSaved = { wishlist = {} }
    end

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
                if Settings and Settings.OpenToCategory then
                    Settings.OpenToCategory("BiS Gear Check")
                elseif InterfaceOptionsFrame_OpenToCategory then
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
    else
        self:RenderResults()
    end
end

function BISGearCheck:SetSpec(specKey)
    self.selectedSpec = specKey
    if not BISGearCheckSaved then BISGearCheckSaved = { wishlist = {} } end
    BISGearCheckSaved.selectedSpec = specKey
    self:Refresh()
end

function BISGearCheck:SetDataSource(sourceKey)
    self.dataSource = sourceKey
    if not BISGearCheckSaved then BISGearCheckSaved = { wishlist = {} } end
    BISGearCheckSaved.dataSource = sourceKey
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

-- Core comparison logic
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
            local slotResult = self:CompareSlot(slotName, bisItems)
            if slotResult then
                table.insert(results, slotResult)
            end
        end
    end

    self.comparisonResults = results
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
        -- For dual-slot items, show up to 10 items total
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
-- WISHLIST MANAGEMENT
-- ============================================================

function BISGearCheck:AddToWishlist(itemID, slotName, rank, source, sourceType)
    if not BISGearCheckSaved then BISGearCheckSaved = { wishlist = {} } end
    if not BISGearCheckSaved.wishlist then BISGearCheckSaved.wishlist = {} end

    BISGearCheckSaved.wishlist[itemID] = {
        slotName = slotName,
        rank = rank,
        source = source or "Unknown",
        sourceType = sourceType or "",
        specKey = self.selectedSpec,
        dataSource = self.dataSource,
    }
end

function BISGearCheck:RemoveFromWishlist(itemID)
    if BISGearCheckSaved and BISGearCheckSaved.wishlist then
        BISGearCheckSaved.wishlist[itemID] = nil
    end
end

function BISGearCheck:IsOnWishlist(itemID)
    return BISGearCheckSaved and BISGearCheckSaved.wishlist and BISGearCheckSaved.wishlist[itemID] ~= nil
end

function BISGearCheck:GetWishlistItems()
    if not BISGearCheckSaved or not BISGearCheckSaved.wishlist then return {} end

    local items = {}
    for itemID, info in pairs(BISGearCheckSaved.wishlist) do
        local isEquipped = false
        if info.slotName then
            local invSlots = self.SlotToInvSlot[info.slotName]
            if invSlots then
                for _, invSlotID in ipairs(invSlots) do
                    if GetInventoryItemID("player", invSlotID) == itemID then
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
    if not BISGearCheckSaved then BISGearCheckSaved = { wishlist = {} } end
    BISGearCheckSaved.wishlistAutoFilter = enabled

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
