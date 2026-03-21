-- BISGearCheck Util.lua
-- Slot mappings, class/spec tables, zone mappings, helpers

BISGearCheck = BISGearCheck or {}

-- Map our slot names to WoW inventory slot IDs
BISGearCheck.SlotToInvSlot = {
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
BISGearCheck.SlotOrder = {
    "Head", "Neck", "Shoulders", "Back", "Chest", "Wrist", "Hands",
    "Waist", "Legs", "Feet", "Rings", "Trinkets",
    "Main Hand", "Offhand", "Twohand", "Ranged"
}

-- Map class token -> list of spec keys
BISGearCheck.ClassSpecs = {
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
BISGearCheck.DataSources = {
    { key = "wowtbcgg",   label = "WowTBC.gg",  db = "BISGearCheckDB" },
    { key = "atlasloot",  label = "AtlasLoot",   db = "BISGearCheckDB_AtlasLoot" },
}

-- Map SourceDB source strings to zone names returned by GetRealZoneText()
-- Multiple source strings can map to the same zone
BISGearCheck.SourceToZone = {
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
BISGearCheck.ZoneToSources = {}
for src, zone in pairs(BISGearCheck.SourceToZone) do
    if not BISGearCheck.ZoneToSources[zone] then
        BISGearCheck.ZoneToSources[zone] = {}
    end
    BISGearCheck.ZoneToSources[zone][src] = true
end

-- Categorized zone lists for the dropdown
BISGearCheck.ZoneCategories = {
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
function BISGearCheck:GetZoneList()
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
function BISGearCheck:ZoneHasWishlistItems(zone)
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
function BISGearCheck:ItemMatchesZone(itemID, zone)
    local sourceInfo = BISGearCheckSources and BISGearCheckSources[itemID]
    if not sourceInfo or not sourceInfo.source then return false end
    local itemZone = self.SourceToZone[sourceInfo.source]
    return itemZone == zone
end

-- Try to auto-detect spec from talent points
function BISGearCheck:GuessSpec()
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
function BISGearCheck:ClassColor(classToken, text)
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

function BISGearCheck:QualityColor(quality)
    return QUALITY_COLORS[quality] or "ffffff"
end
