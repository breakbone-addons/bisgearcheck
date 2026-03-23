-- BiSGearCheck Util.lua
-- Slot mappings, class/spec tables, zone mappings, helpers

BiSGearCheck = BiSGearCheck or {}

-- Map our slot names to WoW inventory slot IDs
BiSGearCheck.SlotToInvSlot = {
    ["Head"]      = { 1 },
    ["Neck"]      = { 2 },
    ["Shoulders"] = { 3 },
    ["Back"]      = { 15 },
    ["Chest"]     = { 5 },
    ["Wrist"]     = { 9 },
    ["Hands"]     = { 10 },
    ["Waist"]     = { 6 },
    ["Legs"]      = { 7 },
    ["Feet"]      = { 8 },
    ["Rings"]     = { 11, 12 },
    ["Trinkets"]  = { 13, 14 },
    ["Main Hand"] = { 16 },
    ["Offhand"]   = { 17 },
    ["Twohand"]   = { 16 },
    ["Ranged"]    = { 18 },
}

-- Display order for slots
BiSGearCheck.SlotOrder = {
    "Head", "Neck", "Shoulders", "Back", "Chest", "Wrist", "Hands",
    "Waist", "Legs", "Feet", "Rings", "Trinkets",
    "Main Hand", "Offhand", "Twohand", "Ranged"
}

-- Map class token -> list of spec keys
BiSGearCheck.ClassSpecs = {
    ["DRUID"]   = {
        { key = "DruidBalance",       label = "Balance" },
        { key = "DruidFeralDPS",      label = "Feral DPS" },
        { key = "DruidFeralTank",     label = "Feral Tank" },
        { key = "DruidRestoration",   label = "Restoration" },
    },
    ["HUNTER"]  = {
        { key = "HunterBM",           label = "Beast Mastery" },
        { key = "HunterMM",           label = "Marksmanship" },
        { key = "HunterSV",           label = "Survival" },
    },
    ["MAGE"]    = {
        { key = "MageArcane",         label = "Arcane" },
        { key = "MageFire",           label = "Fire" },
        { key = "MageFrost",          label = "Frost" },
    },
    ["PALADIN"] = {
        { key = "PaladinHoly",        label = "Holy" },
        { key = "PaladinProtection",  label = "Protection" },
        { key = "PaladinRetribution", label = "Retribution" },
    },
    ["PRIEST"]  = {
        { key = "PriestHoly",         label = "Holy" },
        { key = "PriestShadow",       label = "Shadow" },
    },
    ["ROGUE"]   = {
        { key = "RogueAssassination", label = "Assassination" },
        { key = "RogueCombat",        label = "Combat" },
        { key = "RogueSubtlety",      label = "Subtlety" },
    },
    ["SHAMAN"]  = {
        { key = "ShamanElemental",    label = "Elemental" },
        { key = "ShamanEnhancement",  label = "Enhancement" },
        { key = "ShamanRestoration",  label = "Restoration" },
    },
    ["WARLOCK"] = {
        { key = "WarlockAffliction",  label = "Affliction" },
        { key = "WarlockDemonology",  label = "Demonology" },
        { key = "WarlockDestruction", label = "Destruction" },
    },
    ["WARRIOR"] = {
        { key = "WarriorArms",        label = "Arms" },
        { key = "WarriorFury",        label = "Fury" },
        { key = "WarriorProtection",  label = "Protection" },
    },
}

-- Data source definitions
BiSGearCheck.DataSources = {
    { key = "wowtbcgg",   label = "WowTBC.gg",  db = "BiSGearCheckDB" },
    { key = "atlasloot",  label = "AtlasLoot",   db = "BiSGearCheckDB_AtlasLoot" },
}

-- Map SourceDB source strings to zone names returned by GetRealZoneText()
-- Multiple source strings can map to the same zone
BiSGearCheck.SourceToZone = {
    -- Raids
    ["Karazhan"]            = "Karazhan",
    ["Gruul's Lair"]        = "Gruul's Lair",
    ["Magtheridon's Lair"]  = "Magtheridon's Lair",
    -- Hellfire Citadel
    ["Hellfire Ramparts"]   = "Hellfire Ramparts",
    ["Blood Furnace"]       = "The Blood Furnace",
    ["The Blood Furnace"]   = "The Blood Furnace",
    ["Shattered Halls"]     = "The Shattered Halls",
    ["The Shattered Halls"] = "The Shattered Halls",
    -- Coilfang Reservoir
    ["Slave Pens"]          = "The Slave Pens",
    ["The Slave Pens"]      = "The Slave Pens",
    ["Underbog"]            = "The Underbog",
    ["The Underbog"]        = "The Underbog",
    ["Steamvaults"]         = "The Steamvault",
    ["The Steamvault"]      = "The Steamvault",
    -- Auchindoun
    ["Mana-Tombs"]          = "Mana-Tombs",
    ["Mana Tombs"]          = "Mana-Tombs",
    ["Auchenai Crypts"]     = "Auchenai Crypts",
    ["Sethekk Halls"]       = "Sethekk Halls",
    ["Shadow Labyrinth"]    = "Shadow Labyrinth",
    -- Tempest Keep
    ["The Mechanar"]        = "The Mechanar",
    ["Mechanar"]            = "The Mechanar",
    ["The Botanica"]        = "The Botanica",
    ["Botanica"]            = "The Botanica",
    ["The Arcatraz"]        = "The Arcatraz",
    ["Arcatraz"]            = "The Arcatraz",
    -- Caverns of Time
    ["Old Hillsbrad Foothills"] = "Old Hillsbrad Foothills",
    ["The Black Morass"]    = "The Black Morass",
    ["Black Morass"]        = "The Black Morass",
    -- Classic raids
    ["Molten Core"]         = "Molten Core",
    ["Blackwing Lair"]      = "Blackwing Lair",
    ["Naxxramas"]           = "Naxxramas",
    ["Ahn'Qiraj"]           = "Ahn'Qiraj",
    -- Classic dungeons
    ["Blackrock Depths"]    = "Blackrock Depths",
    ["Stratholme"]          = "Stratholme",
}

-- Reverse map: zone name -> list of source strings that drop items there
BiSGearCheck.ZoneToSources = {}
for src, zone in pairs(BiSGearCheck.SourceToZone) do
    if not BiSGearCheck.ZoneToSources[zone] then
        BiSGearCheck.ZoneToSources[zone] = {}
    end
    BiSGearCheck.ZoneToSources[zone][src] = true
end

-- Categorized zone lists for the dropdown
BiSGearCheck.ZoneCategories = {
    {
        label = "TBC Raids",
        zones = { "Karazhan", "Gruul's Lair", "Magtheridon's Lair" },
    },
    {
        label = "TBC Dungeons",
        zones = {
            "Hellfire Ramparts", "The Blood Furnace", "The Shattered Halls",
            "The Slave Pens", "The Underbog", "The Steamvault",
            "Mana-Tombs", "Auchenai Crypts", "Sethekk Halls", "Shadow Labyrinth",
            "The Mechanar", "The Botanica", "The Arcatraz",
            "Old Hillsbrad Foothills", "The Black Morass",
        },
    },
    {
        label = "Classic",
        zones = {
            "Molten Core", "Blackwing Lair", "Ahn'Qiraj", "Naxxramas",
            "Blackrock Depths", "Stratholme",
        },
    },
}

-- Get unique zone names (sorted) for filter dropdown
function BiSGearCheck:GetZoneList()
    local zones = {}
    local seen = {}
    for _, zone in pairs(self.SourceToZone) do
        if not seen[zone] then
            seen[zone] = true
            table.insert(zones, zone)
        end
    end
    table.sort(zones)
    return zones
end

-- Check if a zone has any wishlist items
function BiSGearCheck:ZoneHasWishlistItems(zone)
    local wl = self:GetActiveWishlistTable()
    if not wl then return false end
    for itemID, _ in pairs(wl) do
        if self:ItemMatchesZone(itemID, zone) then
            return true
        end
    end
    return false
end

-- Check if an item's source matches a zone
function BiSGearCheck:ItemMatchesZone(itemID, zone)
    local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]
    if not sourceInfo or not sourceInfo.source then return false end
    local itemZone = self.SourceToZone[sourceInfo.source]
    return itemZone == zone
end

-- Try to auto-detect spec from talent points
function BiSGearCheck:GuessSpec()
    local _, classToken = UnitClass("player")
    local specs = self.ClassSpecs[classToken]
    if not specs then return nil end

    local bestTab, bestPoints = 0, 0
    for i = 1, GetNumTalentTabs() do
        local results = { GetTalentTabInfo(i) }
        -- Points spent could be at index 3 or 5 depending on client version
        local points = 0
        for j = 3, #results do
            local val = tonumber(results[j])
            if val and val >= 0 and val <= 71 then
                points = val
                break
            end
        end
        if points > bestPoints then
            bestPoints = points
            bestTab = i
        end
    end

    if bestTab > 0 and bestTab <= #specs then
        return specs[bestTab].key
    end

    return specs[1].key
end

-- Get class-colored text
function BiSGearCheck:ClassColor(classToken, text)
    local color = RAID_CLASS_COLORS[classToken]
    if color then
        return string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, text)
    end
    return text
end

-- Quality color for item links
local QUALITY_COLORS = {
    [0] = "9d9d9d", -- Poor
    [1] = "ffffff", -- Common
    [2] = "1eff00", -- Uncommon
    [3] = "0070dd", -- Rare
    [4] = "a335ee", -- Epic
    [5] = "ff8000", -- Legendary
}

function BiSGearCheck:QualityColor(quality)
    return QUALITY_COLORS[quality] or "ffffff"
end

-- ============================================================
-- ITEM LINK PARSING (for enchant/gem detection)
-- ============================================================

-- Map our slot names to enchant DB slot keys
BiSGearCheck.SlotToEnchantSlot = {
    ["Head"]      = "Head",
    ["Shoulders"] = "Shoulder",
    ["Back"]      = "Back",
    ["Chest"]     = "Chest",
    ["Wrist"]     = "Wrist",
    ["Hands"]     = "Hands",
    ["Legs"]      = "Legs",
    ["Feet"]      = "Feet",
    ["Main Hand"] = "Weapon",
    ["Offhand"]   = "Shield",
    ["Twohand"]   = "Weapon",
    ["Ranged"]    = "Ranged",
    ["Rings"]     = "Ring",
}

-- Slots that can have enchants (used for warnings)
-- Excludes Neck, Waist, Trinkets (not enchantable in TBC)
BiSGearCheck.EnchantableSlots = {
    ["Head"] = true, ["Shoulders"] = true, ["Back"] = true,
    ["Chest"] = true, ["Wrist"] = true, ["Hands"] = true,
    ["Legs"] = true, ["Feet"] = true,
    ["Main Hand"] = true, ["Offhand"] = true, ["Twohand"] = true,
    ["Ranged"] = true, ["Rings"] = true,
}

-- Parse an item link string, extracting enchantID and gem itemIDs
-- Format: item:itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:uniqueID
function BiSGearCheck:ParseItemLink(itemLink)
    if not itemLink then return nil end
    local fields = { itemLink:match("item:(%d+):(%d*):(%d*):(%d*):(%d*):(%d*)") }
    if not fields[1] then return nil end
    local result = {}
    for i = 1, 6 do
        result[i] = tonumber(fields[i]) or 0
    end
    return result[1], result[2], result[3], result[4], result[5], result[6]
    -- returns: itemID, enchantID, gem1, gem2, gem3, gem4
end

-- Check if an enchantID is in the spec's recommended list for a given slot
function BiSGearCheck:IsEnchantRecommended(specKey, slotName, enchantID)
    if not enchantID or enchantID == 0 then return false end
    local enchantSlot = self.SlotToEnchantSlot[slotName]
    if not enchantSlot then return false end
    local specEnchants = BiSGearCheckEnchantsDB and BiSGearCheckEnchantsDB[specKey]
    if not specEnchants then return false end
    local slotEnchants = specEnchants[enchantSlot]
    if not slotEnchants then return false end
    for _, enchant in ipairs(slotEnchants) do
        if enchant[1] == enchantID then return true end
    end
    return false
end

-- Get a hidden tooltip for scanning item socket info
function BiSGearCheck:GetScanTooltip()
    if not self.scanTooltip then
        local tip = CreateFrame("GameTooltip", "BiSGearCheckScanTip", nil, "GameTooltipTemplate")
        tip:SetOwner(WorldFrame, "ANCHOR_NONE")
        self.scanTooltip = tip
    end
    return self.scanTooltip
end

-- Count sockets on an equipped item by scanning its tooltip
function BiSGearCheck:CountItemSockets(itemLink)
    if not itemLink then return 0 end
    local tip = self:GetScanTooltip()
    tip:ClearLines()
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:SetHyperlink(itemLink)
    local count = 0
    for i = 1, tip:NumLines() do
        local left = _G["BiSGearCheckScanTipTextLeft" .. i]
        if left then
            local text = left:GetText()
            if text then
                if text:find("Red Socket") or text:find("Blue Socket")
                   or text:find("Yellow Socket") or text:find("Meta Socket") then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Build warning text for an equipped item's enchant and gems
-- Returns a string like " |cffff4d4d[No Enchant] [Empty Socket]|r" or ""
function BiSGearCheck:GetEquipWarnings(itemLink, slotName, specKey)
    if not itemLink or not specKey then return "" end

    local _, enchantID, gem1, gem2, gem3, gem4 = self:ParseItemLink(itemLink)
    local warnings = {}

    -- Enchant check (only for enchantable slots that have spec recommendations)
    if self.EnchantableSlots[slotName] then
        local enchantSlot = self.SlotToEnchantSlot[slotName]
        local specEnchants = BiSGearCheckEnchantsDB and BiSGearCheckEnchantsDB[specKey]
        local hasRecommendations = specEnchants and specEnchants[enchantSlot] and #specEnchants[enchantSlot] > 0
        if hasRecommendations then
            if not enchantID or enchantID == 0 then
                warnings[#warnings + 1] = "[No Enchant]"
            elseif not self:IsEnchantRecommended(specKey, slotName, enchantID) then
                warnings[#warnings + 1] = "[Wrong Enchant]"
            end
        end
    end

    -- Gem check: count sockets vs filled gems, check quality
    local totalSockets = self:CountItemSockets(itemLink)
    if totalSockets > 0 then
        local gems = { gem1, gem2, gem3, gem4 }
        local filledCount = 0
        local lowQualityCount = 0
        for i = 1, totalSockets do
            local gemID = gems[i]
            if gemID and gemID > 0 then
                filledCount = filledCount + 1
                local _, _, quality = GetItemInfo(gemID)
                if quality and quality < 3 then
                    lowQualityCount = lowQualityCount + 1
                end
            end
        end

        local emptyCount = totalSockets - filledCount
        if emptyCount > 0 then
            if emptyCount == 1 then
                warnings[#warnings + 1] = "[Empty Socket]"
            else
                warnings[#warnings + 1] = "[" .. emptyCount .. " Empty Sockets]"
            end
        end
        if lowQualityCount > 0 then
            if lowQualityCount == 1 then
                warnings[#warnings + 1] = "[Low Gem]"
            else
                warnings[#warnings + 1] = "[" .. lowQualityCount .. " Low Gems]"
            end
        end
    end

    if #warnings == 0 then return "" end
    return " |cffff4d4d" .. table.concat(warnings, " ") .. "|r"
end
