-- BISGearCheck Wishlist.lua
-- Wishlist CRUD operations, item retrieval, zone filtering, auto-filter

BISGearCheck = BISGearCheck or {}

-- ============================================================
-- WISHLIST DATA ACCESS
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

-- ============================================================
-- WISHLIST CRUD
-- ============================================================

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

-- ============================================================
-- WISHLIST ITEM MANAGEMENT
-- ============================================================

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

        -- Prefer fresh SourceDB data over stale saved strings
        local sourceInfo = BISGearCheckSources and BISGearCheckSources[itemID]
        local source = (sourceInfo and sourceInfo.source) or info.source
        local sourceType = (sourceInfo and sourceInfo.sourceType) or info.sourceType

        table.insert(items, {
            id = itemID,
            name = name or ("Item #" .. itemID),
            link = link,
            quality = quality,
            icon = icon,
            slotName = info.slotName,
            rank = info.rank,
            source = source,
            sourceType = sourceType,
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

-- ============================================================
-- WISHLIST AUTO-FILTER
-- ============================================================

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
