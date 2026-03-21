-- BiSGearCheck Character.lua
-- Character key helper, saved variable migration, character registry, viewing character helpers

BiSGearCheck = BiSGearCheck or {}

-- ============================================================
-- CHARACTER KEY HELPER
-- ============================================================

function BiSGearCheck:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if name and realm then
        return name .. "-" .. realm
    end
    return nil
end

-- ============================================================
-- SAVED VARIABLE MIGRATION
-- ============================================================

function BiSGearCheck:MigrateSavedVars()
    -- Initialize account-wide saved vars if needed
    if not BiSGearCheckSaved then
        BiSGearCheckSaved = { characters = {} }
    end

    -- Detect old format: wishlists at top level (pre-2.1.0)
    if BiSGearCheckSaved.wishlists or BiSGearCheckSaved.wishlist then
        local oldWishlists = BiSGearCheckSaved.wishlists

        -- Handle even older single-wishlist format
        if BiSGearCheckSaved.wishlist and not oldWishlists then
            oldWishlists = { ["Default"] = BiSGearCheckSaved.wishlist }
        end

        if not oldWishlists then
            oldWishlists = { ["Default"] = {} }
        end

        -- Move per-character settings to BiSGearCheckChar
        if not BiSGearCheckChar then
            BiSGearCheckChar = {}
        end
        BiSGearCheckChar.selectedSpec = BiSGearCheckChar.selectedSpec or BiSGearCheckSaved.selectedSpec
        BiSGearCheckChar.dataSource = BiSGearCheckChar.dataSource or BiSGearCheckSaved.dataSource
        BiSGearCheckChar.wishlistAutoFilter = BiSGearCheckChar.wishlistAutoFilter or BiSGearCheckSaved.wishlistAutoFilter

        -- Move wishlists to character registry
        if not BiSGearCheckSaved.characters then
            BiSGearCheckSaved.characters = {}
        end

        local charKey = self:GetCharacterKey()
        if charKey then
            BiSGearCheckSaved.characters[charKey] = {
                class = select(2, UnitClass("player")),
                faction = UnitFactionGroup("player") or "Alliance",
                wishlists = oldWishlists,
                activeWishlist = BiSGearCheckSaved.activeWishlist or "Default",
            }
        end

        -- Clean up old top-level fields
        BiSGearCheckSaved.wishlists = nil
        BiSGearCheckSaved.wishlist = nil
        BiSGearCheckSaved.activeWishlist = nil
        BiSGearCheckSaved.selectedSpec = nil
        BiSGearCheckSaved.dataSource = nil
        BiSGearCheckSaved.wishlistAutoFilter = nil
    end

    -- Ensure characters table exists
    if not BiSGearCheckSaved.characters then
        BiSGearCheckSaved.characters = {}
    end

    -- Ensure per-character vars exist
    if not BiSGearCheckChar then
        BiSGearCheckChar = {}
    end
end

-- ============================================================
-- CHARACTER REGISTRY
-- ============================================================

function BiSGearCheck:RegisterCharacter()
    local charKey = self.playerKey
    if not charKey then return end

    if not BiSGearCheckSaved.characters[charKey] then
        BiSGearCheckSaved.characters[charKey] = {
            class = select(2, UnitClass("player")),
            faction = self.playerFaction,
            wishlists = { ["Default"] = {} },
            activeWishlist = "Default",
        }
    else
        -- Update class/faction in case of changes
        local charData = BiSGearCheckSaved.characters[charKey]
        charData.class = select(2, UnitClass("player"))
        charData.faction = self.playerFaction
    end

    -- Snapshot equipped gear for cross-character viewing
    self:SnapshotEquippedGear()
end

-- Save current equipped item IDs so other characters can view this character's gear
function BiSGearCheck:SnapshotEquippedGear()
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
function BiSGearCheck:GetCharacterData(charKey)
    if not charKey or not BiSGearCheckSaved or not BiSGearCheckSaved.characters then
        return nil
    end
    return BiSGearCheckSaved.characters[charKey]
end

-- Get sorted list of all character keys on the account
function BiSGearCheck:GetCharacterKeys()
    local keys = {}
    if BiSGearCheckSaved and BiSGearCheckSaved.characters then
        for key in pairs(BiSGearCheckSaved.characters) do
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

-- Get the character key we're currently viewing wishlists for
function BiSGearCheck:GetViewingCharKey()
    return self.viewingCharKey or self.playerKey
end

-- Switch which character the entire UI operates as
function BiSGearCheck:SetViewingCharacter(charKey)
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
        self.selectedSpec = BiSGearCheckChar.selectedSpec or self:GuessSpec()
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
function BiSGearCheck:GetViewingClass()
    local charKey = self:GetViewingCharKey()
    if charKey == self.playerKey then
        return select(2, UnitClass("player"))
    end
    local charData = self:GetCharacterData(charKey)
    return charData and charData.class
end

-- Get the faction for the character we're currently viewing
function BiSGearCheck:GetViewingFaction()
    local charKey = self:GetViewingCharKey()
    if charKey == self.playerKey then
        return self.playerFaction
    end
    local charData = self:GetCharacterData(charKey)
    return charData and charData.faction or "Alliance"
end

-- Check if viewing the currently logged-in character
function BiSGearCheck:IsViewingOwnCharacter()
    return self.viewingCharKey == nil or self.viewingCharKey == self.playerKey
end
