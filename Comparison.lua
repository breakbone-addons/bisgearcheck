-- BISGearCheck Comparison.lua
-- Faction filtering, gear comparison engine

BISGearCheck = BISGearCheck or {}

-- ============================================================
-- FACTION FILTERING
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

-- ============================================================
-- CORE COMPARISON
-- ============================================================

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
