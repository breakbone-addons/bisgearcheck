-- BiSGearCheck Data_GemsEnchants.lua
-- TBC Classic Best in Slot Gems and Enchants by Spec
-- Sources: Wowhead TBC Classic guides, Warcraft Wiki EnchantId database
-- Generated from community guide research
--
-- GEM FORMAT: { itemID, "Item Name" }
-- ENCHANT FORMAT: { enchantID, "Enchant Name" }
--
-- NOTE ON ENCHANT IDs:
-- enchantID is the number in item links: item:itemID:ENCHANTID:gem1:gem2:gem3
-- These are NOT spell IDs. Verified from warcraft.wiki.gg/wiki/EnchantId
--
-- ENCHANT ID REFERENCE (verified):
--   Weapon:
--     2673 = Mongoose (+120 agi proc)
--     2671 = Sunfire (+50 arcane/fire SP)
--     2672 = Soulfrost (+54 shadow/frost SP)
--     2669 = Major Spellpower (+40 SP)
--     2670 = Major Agility 2H (+35 agi)
--     2667 = Savagery (+70 AP)
--     2675 = Battlemaster (heal proc)
--     2674 = Spellsurge (mana proc)
--     2666 = Major Intellect (+30 int)
--     2668 = Potency (+20 str)
--     2564 = Greater Agility 1H (+15 agi)  [UNVERIFIED - may be gloves]
--     2646 = Greater Agility (+25 agi) [UNVERIFIED - could be weapon or 2H]
--   Head (applied via items - enchantIDs from SpellItemEnchantment):
--     3002 = Glyph of Power (+22 SP, +14 hit) - Sha'tar Revered
--     3003 = Glyph of Ferocity (+34 AP, +16 hit) - Cenarion Expedition Revered
--     3001 = Glyph of Renewal (+19 SP, +9 mp5) - Honor Hold/Thrallmar Revered
--     2999 = Arcanum of the Defender (+16 def, +17 dodge) - Keepers of Time Revered [UNVERIFIED exact ID]
--   Shoulder (applied via items):
--     2986 = Greater Inscription of Vengeance (+30 AP, +10 crit) - Aldor Exalted
--     2982 = Greater Inscription of Discipline (+18 SP, +10 crit) - Aldor Exalted
--     2980 = Greater Inscription of Faith (+18 SP, +5 mp5) - Aldor Exalted [UNVERIFIED]
--     2995 = Greater Inscription of the Orb (+15 crit, +12 SP) - Scryer Exalted
--     2997 = Greater Inscription of the Blade (+15 crit, +20 AP) - Scryer Exalted
--     2978 = Greater Inscription of Warding (+15 dodge, +10 def) - Aldor Exalted [UNVERIFIED]
--     2993 = Greater Inscription of the Knight (+12 SP, +8 mp5) - Scryer Exalted [UNVERIFIED - stats suggest healer]
--   Back:
--     2621 = Subtlety (2% threat reduction)
--     2622 = Dodge (+12 dodge rating)
--     2657 = Greater Agility (+12 agi)
--     2662 = Major Armor (+120 armor)
--     2664 = Major Resistance (+7 all resist)
--     2938 = Spell Penetration (+20 spell pen)
--   Chest:
--     2661 = Exceptional Stats (+6 all stats)
--     2659 = Exceptional Health (+150 HP)
--     2665 = Major Spirit (+15 spirit) [UNVERIFIED - stats match but could be different slot]
--     2679 = Restore Mana Prime (8 mp5) [UNVERIFIED]
--   Wrist:
--     2647 = Brawn (+12 str)
--     2650 = Spellpower (+15 SP)
--     2649 = Fortitude (+12 stam)
--     369 = Major Intellect (+12 int) [spell 34001]
--     2648 = Major Defense (+12 def rating)
--     2617 = Superior Healing (+16 SP) [UNVERIFIED - listed as +16 SP, actual is +30 healing]
--     2606 = Assault (+30 AP) [UNVERIFIED]
--   Hands:
--     2564 = Superior Agility (+15 agi) [UNVERIFIED - same ID as cloak enchant?]
--     2618 = Superior Agility (+15 agi) [alternative ID]
--     2563 = Major Strength (+15 str) [UNVERIFIED]
--     2937 = Major Spellpower (+20 SP)
--     2613 = Threat (+2% threat)
--     2658 = Precise Strikes (+10 hit, +10 crit) [UNVERIFIED - name may differ]
--     2935 = Spell Strike (+15 hit rating)
--   Legs:
--     3012 = Nethercobra Leg Armor (+50 AP, +12 crit)
--     3013 = Nethercleft Leg Armor (+40 stam, +12 agi)
--     2748 = Runic Spellthread (+35 SP, +20 stam)
--     2746 = Golden Spellthread (+66 healing, +20 stam) [healer version]
--     3011 = Clefthide Leg Armor (+30 stam, +10 agi)
--   Feet:
--     2940 = Boar's Speed (+9 stam, minor speed)
--     2939 = Cat's Swiftness (+6 agi, minor speed)
--     2649 = Fortitude (+12 stam) [same ID as bracer]
--     2657 = Dexterity (+12 agi) [same ID as cloak Greater Agility]
--     2658 = Surefooted (+10 hit, +10 crit)
--     2656 = Vitality (+5 hp5 and +5 mp5)
--     2969 = Boar's Speed alt (+20 AP, minor speed) [UNVERIFIED]
--   Shield:
--     2653 = Major Stamina (+36 block value) [UNVERIFIED - stats say block value]
--     2654 = Intellect (+12 int) [spell 27945, different ID from bracer Major Intellect]
--   Ranged:
--     2724 = Stabilized Eternium Scope (+28 crit rating)
--     2723 = Khorium Scope (+12 damage)
--
-- IMPORTANT: Some enchantIDs marked [UNVERIFIED] need in-game verification.
-- The enchantID system reuses some IDs across different equipment slots
-- (the game determines slot from context). This is expected behavior.

BiSGearCheckGemsDB = {}
BiSGearCheckEnchantsDB = {}

-- ============================================================
-- ENCHANT LINK LOOKUP (enchantID -> spell or item for tooltips)
-- ============================================================
-- For enchanting profession enchants: { "spell", spellID }
-- For consumable items (arcanums, leg armor, scopes): { "item", itemID }
-- Used by the OnEnchantEnter handler for working tooltips in TBC Classic

BiSGearCheckEnchantLinks = {
    -- Weapon enchants (enchanting spells)
    [2673] = { "spell", 27984 },  -- Mongoose
    [2671] = { "spell", 27981 },  -- Sunfire
    [2672] = { "spell", 27982 },  -- Soulfrost
    [2669] = { "spell", 27975 },  -- Major Spellpower / Major Healing
    [2670] = { "spell", 27977 },  -- Major Agility (2H)
    [2667] = { "spell", 27971 },  -- Savagery (2H)
    [2675] = { "spell", 28004 },  -- Battlemaster
    [2666] = { "spell", 27968 },  -- Major Intellect
    [2668] = { "spell", 27972 },  -- Potency
    [2674] = { "spell", 28003 },  -- Spellsurge
    [3225] = { "spell", 42974 },  -- Executioner
    [2646] = { "spell", 42620 },  -- Greater Agility

    -- Head enchants (consumable items - Arcanums/Glyphs)
    [3002] = { "item", 29191 },   -- Glyph of Power
    [3003] = { "item", 29192 },   -- Glyph of Ferocity
    [3001] = { "item", 29189, horde = 29190 },   -- Glyph of Renewal (Alliance: Honor Hold 29189, Horde: Thrallmar 29190)
    [2999] = { "item", 29186 },   -- Glyph of the Defender

    -- Shoulder enchants (consumable items - Inscriptions)
    [2986] = { "item", 28888 },   -- Greater Inscription of Vengeance
    [2982] = { "item", 28886 },   -- Greater Inscription of Discipline
    [2980] = { "item", 28887 },   -- Greater Inscription of Faith
    [2995] = { "item", 28909 },   -- Greater Inscription of the Orb
    [2997] = { "item", 28910 },   -- Greater Inscription of the Blade
    [2978] = { "item", 28889 },   -- Greater Inscription of Warding
    [2993] = { "item", 28911 },   -- Greater Inscription of the Knight
    -- Lesser shoulder inscriptions (common "wrong" enchants)
    [2985] = { "item", 28878 },   -- Inscription of Vengeance
    [2981] = { "item", 28881 },   -- Inscription of Discipline
    [2979] = { "item", 28878 },   -- Inscription of Faith
    [2994] = { "item", 28903 },   -- Inscription of the Orb
    [2996] = { "item", 28904 },   -- Inscription of the Blade
    [2977] = { "item", 28907 },   -- Inscription of Warding
    [2992] = { "item", 28905 },   -- Inscription of the Knight

    -- Back enchants (enchanting spells)
    [2621] = { "spell", 25084 },  -- Subtlety
    [2657] = { "spell", 34004, Feet = { "spell", 27951 } },  -- Greater Agility (back) / Dexterity (boots)
    [2622] = { "spell", 25086 },  -- Dodge
    [2662] = { "spell", 27961 },  -- Major Armor
    [2664] = { "spell", 27962 },  -- Major Resistance
    [2938] = { "spell", 34003 },  -- Spell Penetration

    -- Chest enchants (enchanting spells)
    [2661] = { "spell", 27960 },  -- Exceptional Stats
    [2659] = { "spell", 27957 },  -- Exceptional Health
    [2665] = { "spell", 33990 },  -- Major Spirit
    [2679] = { "spell", 33991 },  -- Restore Mana Prime

    -- Wrist enchants (enchanting spells)
    [2647] = { "spell", 27899 },  -- Brawn
    [2650] = { "spell", 27917 },  -- Spellpower
    [2649] = { "spell", 27914, Feet = { "spell", 27950 } },  -- Fortitude (bracer) / Fortitude (boots)
    [369]  = { "spell", 34001 },  -- Bracer - Major Intellect
    [2654] = { "spell", 27945 },  -- Shield - Intellect
    [2648] = { "spell", 27906 },  -- Major Defense
    [2617] = { "spell", 27911 },  -- Superior Healing
    [2606] = { "spell", 34002 },  -- Assault

    -- Hands enchants (enchanting spells)
    [2618] = { "spell", 25080 },  -- Superior Agility
    [2563] = { "spell", 33995 },  -- Major Strength
    [2937] = { "spell", 33997 },  -- Major Spellpower
    [2612] = { "spell", 33999 },  -- Major Healing
    [2613] = { "spell", 25072 },  -- Threat
    [2935] = { "spell", 33994 },  -- Spell Strike
    [2658] = { "spell", 33994 },  -- Precise Strikes (same spell as Spell Strike)
    [2946] = { "spell", 33996 },  -- Assault

    -- Legs (consumable items - Leg Armors / Spellthreads)
    [3012] = { "item", 29535 },   -- Nethercobra Leg Armor
    [3013] = { "item", 29536 },   -- Nethercleft Leg Armor
    [3011] = { "item", 29534 },   -- Clefthide Leg Armor
    [3010] = { "item", 29533 },   -- Cobrahide Leg Armor
    [2746] = { "item", 24276 },   -- Golden Spellthread (enchant 2746)
    [2748] = { "item", 24274 },   -- Runic Spellthread (enchant 2748)
    [2745] = { "item", 24275 },   -- Silver Spellthread (enchant 2745)
    [2747] = { "item", 24273 },   -- Mystic Spellthread (enchant 2747)

    -- Feet enchants (enchanting spells)
    [2940] = { "spell", 34008 },  -- Boar's Speed
    [2939] = { "spell", 34007 },  -- Cat's Swiftness
    [2656] = { "spell", 27948 },  -- Vitality

    -- Shield enchants (enchanting spells)
    [2653] = { "spell", 34009 },  -- Major Stamina

    -- Ranged (consumable items - Scopes)
    [2724] = { "item", 23766 },   -- Stabilized Eternium Scope
    [2723] = { "item", 23765 },   -- Khorium Scope
}

-- ============================================================
-- GEM DATABASE (by itemID)
-- ============================================================

-- Meta Gems
local META_GEMS = {
    CHAOTIC_SKYFIRE        = { 34220, "Chaotic Skyfire Diamond" },       -- +12 SP, 3% crit damage
    RELENTLESS_EARTHSTORM  = { 32409, "Relentless Earthstorm Diamond" }, -- +12 agi, 3% crit damage
    BRACING_EARTHSTORM     = { 25897, "Bracing Earthstorm Diamond" },   -- +26 healing, 2% threat reduction
    INSIGHTFUL_EARTHSTORM  = { 25901, "Insightful Earthstorm Diamond" },-- +12 int, mana restore proc
    POWERFUL_EARTHSTORM    = { 25896, "Powerful Earthstorm Diamond" },   -- +18 stam
    MYSTICAL_SKYFIRE        = { 25893, "Mystical Skyfire Diamond" },     -- spell haste proc
    SWIFT_SKYFIRE           = { 25894, "Swift Skyfire Diamond" },        -- +24 AP, minor speed
    SWIFT_WINDFIRE          = { 28556, "Swift Windfire Diamond" },       -- +20 AP, minor speed
    THUNDERING_SKYFIRE      = { 32410, "Thundering Skyfire Diamond" },   -- weapon haste proc
}

-- Red Gems (pure)
local RED_GEMS = {
    RUNED_LIVING_RUBY    = { 24030, "Runed Living Ruby" },      -- +8 spell damage
    BOLD_LIVING_RUBY     = { 24027, "Bold Living Ruby" },       -- +8 strength
    DELICATE_LIVING_RUBY = { 24028, "Delicate Living Ruby" },   -- +8 agility
    TEARDROP_LIVING_RUBY = { 24029, "Teardrop Living Ruby" },   -- +18 healing
    BRIGHT_LIVING_RUBY   = { 24031, "Bright Living Ruby" },     -- +16 attack power
    RUNED_CRIMSON_SPINEL = { 32196, "Runed Crimson Spinel" },   -- +12 spell damage (epic)
    BOLD_CRIMSON_SPINEL  = { 32193, "Bold Crimson Spinel" },    -- +10 strength (epic)
    DELICATE_CRIMSON_SPINEL = { 32194, "Delicate Crimson Spinel" }, -- +10 agi (epic)
    TEARDROP_CRIMSON_SPINEL = { 32195, "Teardrop Crimson Spinel" }, -- +26 healing (epic)
}

-- Yellow Gems (pure)
local YELLOW_GEMS = {
    SMOOTH_DAWNSTONE    = { 24048, "Smooth Dawnstone" },    -- +8 crit rating
    RIGID_DAWNSTONE     = { 24051, "Rigid Dawnstone" },     -- +8 hit rating
    BRILLIANT_DAWNSTONE = { 24047, "Brilliant Dawnstone" }, -- +8 intellect
    GLEAMING_DAWNSTONE  = { 24050, "Gleaming Dawnstone" },  -- +8 spell hit
    MYSTIC_DAWNSTONE    = { 24053, "Mystic Dawnstone" },    -- +8 resilience
    QUICK_DAWNSTONE     = { 35315, "Quick Dawnstone" },     -- +8 haste rating
}

-- Blue Gems (pure)
local BLUE_GEMS = {
    SOLID_STAR_OF_ELUNE = { 24033, "Solid Star of Elune" },  -- +12 stamina
    SPARKLING_STAR_OF_ELUNE = { 24035, "Sparkling Star of Elune" }, -- +8 spirit
    LUSTROUS_STAR_OF_ELUNE = { 24036, "Lustrous Star of Elune" },  -- +4 mp5
    STORMY_STAR_OF_ELUNE   = { 24039, "Stormy Star of Elune" },    -- +8 spell pen
}

-- Orange Gems (Red + Yellow)
local ORANGE_GEMS = {
    INSCRIBED_NOBLE_TOPAZ = { 24058, "Inscribed Noble Topaz" },  -- +4 str, +4 crit
    POTENT_NOBLE_TOPAZ    = { 24059, "Potent Noble Topaz" },     -- +4 SP, +4 crit
    LUMINOUS_NOBLE_TOPAZ  = { 24060, "Luminous Noble Topaz" },   -- +4 healing, +4 int
    GLINTING_NOBLE_TOPAZ  = { 24061, "Glinting Noble Topaz" },   -- +4 agi, +4 hit
    VEILED_NOBLE_TOPAZ    = { 31867, "Veiled Noble Topaz" },     -- +4 SP, +4 hit
    WICKED_NOBLE_TOPAZ    = { 24062, "Wicked Noble Topaz" },     -- +4 AP, +4 crit [UNVERIFIED itemID]
    RECKLESS_NOBLE_TOPAZ  = { 35316, "Reckless Noble Topaz" },   -- +4 SP, +4 haste
}

-- Purple Gems (Red + Blue)
local PURPLE_GEMS = {
    GLOWING_NIGHTSEYE   = { 24056, "Glowing Nightseye" },    -- +5 SP, +6 stam
    SOVEREIGN_NIGHTSEYE = { 24054, "Sovereign Nightseye" },  -- +4 str, +6 stam
    SHIFTING_NIGHTSEYE  = { 24055, "Shifting Nightseye" },   -- +4 agi, +6 stam
    ROYAL_NIGHTSEYE     = { 24057, "Royal Nightseye" },      -- +9 healing, +2 mp5
    PURIFIED_SHADOW_PEARL = { 32836, "Purified Shadow Pearl" }, -- +9 healing, +4 spirit
}

-- Green Gems (Yellow + Blue)
local GREEN_GEMS = {
    ENDURING_TALASITE  = { 24066, "Enduring Talasite" },   -- +4 def, +6 stam
    JAGGED_TALASITE    = { 24067, "Jagged Talasite" },     -- +4 crit, +6 stam
    STEADY_TALASITE    = { 33782, "Steady Talasite" },     -- +4 resilience, +6 stam
    DAZZLING_TALASITE  = { 24065, "Dazzling Talasite" },   -- +4 int, +2 mp5
}

-- ============================================================
-- ENCHANT DATABASE (by enchantID)
-- ============================================================

-- Shorthand references for enchants used across many specs
local ENCHANTS = {
    -- Head
    HEAD_GLYPH_POWER       = { 3002, "Glyph of Power" },           -- +22 SP, +14 hit
    HEAD_GLYPH_FEROCITY    = { 3003, "Glyph of Ferocity" },        -- +34 AP, +16 hit
    HEAD_GLYPH_RENEWAL     = { 3001, "Glyph of Renewal" },         -- +19 SP, +9 mp5 [UNVERIFIED exact enchantID]
    HEAD_ARCANUM_DEFENDER  = { 2999, "Arcanum of the Defender" },   -- +16 def, +17 dodge [UNVERIFIED exact enchantID]

    -- Shoulder
    SHOULDER_VENGEANCE     = { 2986, "Greater Inscription of Vengeance" }, -- +30 AP, +10 crit
    SHOULDER_DISCIPLINE    = { 2982, "Greater Inscription of Discipline" },-- +18 SP, +10 crit
    SHOULDER_FAITH         = { 2980, "Greater Inscription of Faith" },     -- +18 SP, +5 mp5 [UNVERIFIED]
    SHOULDER_ORB           = { 2995, "Greater Inscription of the Orb" },   -- +15 crit, +12 SP
    SHOULDER_BLADE         = { 2997, "Greater Inscription of the Blade" }, -- +15 crit, +20 AP
    SHOULDER_WARDING       = { 2978, "Greater Inscription of Warding" },   -- +15 dodge, +10 def [UNVERIFIED]
    SHOULDER_KNIGHT        = { 2993, "Greater Inscription of the Knight" },-- +12 SP, +8 mp5 [UNVERIFIED - check stats]

    -- Back
    BACK_SUBTLETY          = { 2621, "Enchant Cloak - Subtlety" },          -- 2% threat reduction
    BACK_GREATER_AGILITY   = { 2657, "Enchant Cloak - Greater Agility" },   -- +12 agi [UNVERIFIED - 2657 is +12 agi but may be boots]
    BACK_DODGE             = { 2622, "Enchant Cloak - Dodge" },              -- +12 dodge rating
    BACK_MAJOR_ARMOR       = { 2662, "Enchant Cloak - Major Armor" },        -- +120 armor
    BACK_MAJOR_RESISTANCE  = { 2664, "Enchant Cloak - Major Resistance" },   -- +7 all resist
    BACK_SPELL_PEN         = { 2938, "Enchant Cloak - Spell Penetration" },  -- +20 spell pen

    -- Chest
    CHEST_STATS            = { 2661, "Enchant Chest - Exceptional Stats" },  -- +6 all stats
    CHEST_HEALTH           = { 2659, "Enchant Chest - Exceptional Health" }, -- +150 HP
    CHEST_SPIRIT           = { 2665, "Enchant Chest - Major Spirit" },       -- +15 spirit [UNVERIFIED]
    CHEST_MANA_PRIME       = { 2679, "Enchant Chest - Restore Mana Prime" }, -- 8 mp5 [UNVERIFIED - listed as 8 mp5]

    -- Wrist
    WRIST_BRAWN            = { 2647, "Enchant Bracer - Brawn" },           -- +12 str
    WRIST_SPELLPOWER       = { 2650, "Enchant Bracer - Spellpower" },     -- +15 SP
    WRIST_FORTITUDE        = { 2649, "Enchant Bracer - Fortitude" },      -- +12 stam
    WRIST_MAJOR_INTELLECT  = { 369, "Enchant Bracer - Major Intellect" }, -- +12 int [spell 34001]
    WRIST_MAJOR_DEFENSE    = { 2648, "Enchant Bracer - Major Defense" },  -- +12 def
    WRIST_SUP_HEALING      = { 2617, "Enchant Bracer - Superior Healing" },-- +30 healing [UNVERIFIED - stored as +16 SP]
    WRIST_ASSAULT          = { 2606, "Enchant Bracer - Assault" },         -- +24 AP [UNVERIFIED]

    -- Hands
    HANDS_SUP_AGILITY      = { 2618, "Enchant Gloves - Superior Agility" },-- +15 agi
    HANDS_MAJOR_STRENGTH   = { 2563, "Enchant Gloves - Major Strength" },  -- +15 str [UNVERIFIED]
    HANDS_MAJOR_SPELLPOWER = { 2937, "Enchant Gloves - Major Spellpower" },-- +20 SP
    HANDS_MAJOR_HEALING    = { 2612, "Enchant Gloves - Major Healing" },   -- +35 healing [UNVERIFIED]
    HANDS_THREAT           = { 2613, "Enchant Gloves - Threat" },          -- +2% threat
    HANDS_SPELL_STRIKE     = { 2935, "Enchant Gloves - Spell Strike" },   -- +15 hit [UNVERIFIED]
    HANDS_PRECISE_STRIKES  = { 2658, "Enchant Gloves - Precise Strikes" },-- +10 hit, +10 crit [UNVERIFIED]
    HANDS_ASSAULT          = { 2946, "Enchant Gloves - Assault" },         -- +26 AP [UNVERIFIED]

    -- Legs
    LEGS_NETHERCOBRA       = { 3012, "Nethercobra Leg Armor" },     -- +50 AP, +12 crit
    LEGS_NETHERCLEFT       = { 3013, "Nethercleft Leg Armor" },     -- +40 stam, +12 agi
    LEGS_CLEFTHIDE         = { 3011, "Clefthide Leg Armor" },       -- +30 stam, +10 agi
    LEGS_RUNIC_SPELLTHREAD = { 2748, "Runic Spellthread" },         -- +35 SP, +20 stam
    LEGS_GOLDEN_SPELLTHREAD= { 2746, "Golden Spellthread" },        -- +66 healing, +20 stam

    -- Feet
    FEET_BOAR_SPEED        = { 2940, "Enchant Boots - Boar's Speed" },    -- +9 stam, minor speed
    FEET_CAT_SWIFTNESS     = { 2939, "Enchant Boots - Cat's Swiftness" }, -- +6 agi, minor speed
    FEET_FORTITUDE         = { 2649, "Enchant Boots - Fortitude" },       -- +12 stam [same enchantID as bracer]
    FEET_DEXTERITY         = { 2657, "Enchant Boots - Dexterity" },       -- +12 agi [UNVERIFIED - same as back agi?]
    FEET_SUREFOOTED        = { 2658, "Enchant Boots - Surefooted" },      -- +10 hit, +10 crit [UNVERIFIED]
    FEET_VITALITY          = { 2656, "Enchant Boots - Vitality" },        -- +5 hp5 and mp5

    -- Shield
    SHIELD_MAJOR_STAMINA   = { 2653, "Enchant Shield - Major Stamina" },  -- +18 stam [UNVERIFIED - listed as +36 block]
    SHIELD_INTELLECT       = { 2654, "Enchant Shield - Intellect" },      -- +12 int [spell 27945]

    -- Weapon (references to top-level definitions)
    WEAPON_MONGOOSE        = { 2673, "Enchant Weapon - Mongoose" },
    WEAPON_SUNFIRE         = { 2671, "Enchant Weapon - Sunfire" },
    WEAPON_SOULFROST       = { 2672, "Enchant Weapon - Soulfrost" },
    WEAPON_MAJOR_SPELLPOWER= { 2669, "Enchant Weapon - Major Spellpower" },
    WEAPON_MAJOR_HEALING   = { 2669, "Enchant Weapon - Major Healing" },   -- [UNVERIFIED - may differ from Major SP]
    WEAPON_SAVAGERY        = { 2667, "Enchant Weapon - Savagery" },
    WEAPON_MAJOR_AGILITY_2H= { 2670, "Enchant 2H Weapon - Major Agility" },
    WEAPON_MAJOR_INTELLECT = { 2666, "Enchant Weapon - Major Intellect" },
    WEAPON_BATTLEMASTER    = { 2675, "Enchant Weapon - Battlemaster" },
    WEAPON_POTENCY         = { 2668, "Enchant Weapon - Potency" },
    WEAPON_EXECUTIONER     = { 3225, "Enchant Weapon - Executioner" },     -- Phase 4+

    -- Ranged
    RANGED_STAB_SCOPE      = { 2724, "Stabilized Eternium Scope" },  -- +28 crit
    RANGED_KHORIUM_SCOPE   = { 2723, "Khorium Scope" },             -- +12 damage
}


-- ============================================================
-- PER-SPEC GEM AND ENCHANT RECOMMENDATIONS
-- ============================================================

-- Format for each spec:
-- gems = {
--     meta = { itemID, "name" },
--     red = { { itemID, "name" }, ... },     -- 1-2 options
--     yellow = { { itemID, "name" }, ... },
--     blue = { { itemID, "name" }, ... },
-- }
-- enchants = {
--     Head = { { enchantID, "name" }, ... },
--     Shoulder = { ... },
--     Back = { ... },
--     Chest = { ... },
--     Wrist = { ... },
--     Hands = { ... },
--     Legs = { ... },
--     Feet = { ... },
--     Weapon = { ... },
--     Shield = { ... },  -- only for shield-using specs
-- }

-- ============================================================
-- DRUID
-- ============================================================

BiSGearCheckGemsDB["DruidBalance"] = {
    meta = { 34220, "Chaotic Skyfire Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 31867, "Veiled Noble Topaz" }, { 24059, "Potent Noble Topaz" } },
    blue = { { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["DruidBalance"] = {
    Head     = { { 3002, "Glyph of Power" } },
    Shoulder = { { 2995, "Greater Inscription of the Orb" }, { 2982, "Greater Inscription of Discipline" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2938, "Enchant Cloak - Spell Penetration" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" }, { 2679, "Enchant Chest - Restore Mana Prime" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2937, "Enchant Gloves - Major Spellpower" }, { 2935, "Enchant Gloves - Spell Strike" } },
    Legs     = { { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" }, { 2656, "Enchant Boots - Vitality" } },
    Weapon   = { { 2671, "Enchant Weapon - Sunfire" }, { 2669, "Enchant Weapon - Major Spellpower" } },
}

BiSGearCheckGemsDB["DruidFeralDPS"] = {
    meta = nil, -- Wolfshead Helm has no meta socket
    red = { { 24028, "Delicate Living Ruby" } },
    yellow = { { 24061, "Glinting Noble Topaz" } },
    blue = { { 24055, "Shifting Nightseye" } },
}
BiSGearCheckEnchantsDB["DruidFeralDPS"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2606, "Enchant Bracer - Assault" }, { 2647, "Enchant Bracer - Brawn" } },
    Hands    = { { 2618, "Enchant Gloves - Superior Agility" }, { 2563, "Enchant Gloves - Major Strength" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2670, "Enchant 2H Weapon - Major Agility" }, { 2667, "Enchant Weapon - Savagery" } },
}

BiSGearCheckGemsDB["DruidFeralTank"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24028, "Delicate Living Ruby" }, { 24055, "Shifting Nightseye" } },
    yellow = { { 24061, "Glinting Noble Topaz" } },
    blue = { { 24033, "Solid Star of Elune" }, { 24055, "Shifting Nightseye" } },
}
BiSGearCheckEnchantsDB["DruidFeralTank"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2662, "Enchant Cloak - Major Armor" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" }, { 2659, "Enchant Chest - Exceptional Health" } },
    Wrist    = { { 2649, "Enchant Bracer - Fortitude" }, { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2613, "Enchant Gloves - Threat" }, { 2618, "Enchant Gloves - Superior Agility" } },
    Legs     = { { 3013, "Nethercleft Leg Armor" }, { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" }, { 2939, "Enchant Boots - Cat's Swiftness" } },
    Weapon   = { { 2670, "Enchant 2H Weapon - Major Agility" } },
}

BiSGearCheckGemsDB["DruidRestoration"] = {
    meta = { 25897, "Bracing Earthstorm Diamond" },
    red = { { 24029, "Teardrop Living Ruby" } },
    yellow = { { 24060, "Luminous Noble Topaz" } },
    blue = { { 32836, "Purified Shadow Pearl" }, { 24057, "Royal Nightseye" } },
}
BiSGearCheckEnchantsDB["DruidRestoration"] = {
    Head     = { { 3001, "Glyph of Renewal" } },
    Shoulder = { { 2980, "Greater Inscription of Faith" }, { 2982, "Greater Inscription of Discipline" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2664, "Enchant Cloak - Major Resistance" } },
    Chest    = { { 2665, "Enchant Chest - Major Spirit" }, { 2661, "Enchant Chest - Exceptional Stats" }, { 2679, "Enchant Chest - Restore Mana Prime" } },
    Wrist    = { { 2617, "Enchant Bracer - Superior Healing" }, { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2612, "Enchant Gloves - Major Healing" }, { 2937, "Enchant Gloves - Major Spellpower" } },
    Legs     = { { 2746, "Golden Spellthread" }, { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" }, { 2656, "Enchant Boots - Vitality" } },
    Weapon   = { { 2669, "Enchant Weapon - Major Healing" }, { 2674, "Enchant Weapon - Spellsurge" } },
}

-- ============================================================
-- HUNTER (all 3 specs use very similar gems/enchants)
-- ============================================================

BiSGearCheckGemsDB["HunterBM"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24028, "Delicate Living Ruby" } },
    yellow = { { 24061, "Glinting Noble Topaz" }, { 24051, "Rigid Dawnstone" } },
    blue = { { 24055, "Shifting Nightseye" } },
}
BiSGearCheckEnchantsDB["HunterBM"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2618, "Enchant Gloves - Superior Agility" }, { 2946, "Enchant Gloves - Assault" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2646, "Enchant Weapon - Greater Agility" } },
    Ranged   = { { 2724, "Stabilized Eternium Scope" }, { 2723, "Khorium Scope" } },
}

BiSGearCheckGemsDB["HunterMM"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24028, "Delicate Living Ruby" } },
    yellow = { { 24061, "Glinting Noble Topaz" }, { 24051, "Rigid Dawnstone" } },
    blue = { { 24055, "Shifting Nightseye" } },
}
BiSGearCheckEnchantsDB["HunterMM"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2618, "Enchant Gloves - Superior Agility" }, { 2946, "Enchant Gloves - Assault" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2646, "Enchant Weapon - Greater Agility" } },
    Ranged   = { { 2724, "Stabilized Eternium Scope" }, { 2723, "Khorium Scope" } },
}

BiSGearCheckGemsDB["HunterSV"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24028, "Delicate Living Ruby" } },
    yellow = { { 24061, "Glinting Noble Topaz" }, { 24051, "Rigid Dawnstone" } },
    blue = { { 24055, "Shifting Nightseye" } },
}
BiSGearCheckEnchantsDB["HunterSV"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2618, "Enchant Gloves - Superior Agility" }, { 2946, "Enchant Gloves - Assault" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2646, "Enchant Weapon - Greater Agility" } },
    Ranged   = { { 2724, "Stabilized Eternium Scope" }, { 2723, "Khorium Scope" } },
}

-- ============================================================
-- MAGE
-- ============================================================

BiSGearCheckGemsDB["MageArcane"] = {
    meta = { 34220, "Chaotic Skyfire Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 31867, "Veiled Noble Topaz" }, { 24047, "Brilliant Dawnstone" } },
    blue = { { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["MageArcane"] = {
    Head     = { { 3002, "Glyph of Power" } },
    Shoulder = { { 2982, "Greater Inscription of Discipline" }, { 2995, "Greater Inscription of the Orb" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2938, "Enchant Cloak - Spell Penetration" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2937, "Enchant Gloves - Major Spellpower" }, { 2935, "Enchant Gloves - Spell Strike" } },
    Legs     = { { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2671, "Enchant Weapon - Sunfire" }, { 2669, "Enchant Weapon - Major Spellpower" } },
}

BiSGearCheckGemsDB["MageFire"] = {
    meta = { 34220, "Chaotic Skyfire Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 31867, "Veiled Noble Topaz" }, { 24059, "Potent Noble Topaz" } },
    blue = { { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["MageFire"] = {
    Head     = { { 3002, "Glyph of Power" } },
    Shoulder = { { 2982, "Greater Inscription of Discipline" }, { 2995, "Greater Inscription of the Orb" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2938, "Enchant Cloak - Spell Penetration" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2937, "Enchant Gloves - Major Spellpower" }, { 2935, "Enchant Gloves - Spell Strike" } },
    Legs     = { { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2671, "Enchant Weapon - Sunfire" }, { 2669, "Enchant Weapon - Major Spellpower" } },
}

BiSGearCheckGemsDB["MageFrost"] = {
    meta = { 34220, "Chaotic Skyfire Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 31867, "Veiled Noble Topaz" }, { 24059, "Potent Noble Topaz" } },
    blue = { { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["MageFrost"] = {
    Head     = { { 3002, "Glyph of Power" } },
    Shoulder = { { 2982, "Greater Inscription of Discipline" }, { 2995, "Greater Inscription of the Orb" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2938, "Enchant Cloak - Spell Penetration" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2937, "Enchant Gloves - Major Spellpower" }, { 2935, "Enchant Gloves - Spell Strike" } },
    Legs     = { { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2672, "Enchant Weapon - Soulfrost" }, { 2669, "Enchant Weapon - Major Spellpower" } },
}

-- ============================================================
-- PALADIN
-- ============================================================

BiSGearCheckGemsDB["PaladinHoly"] = {
    meta = { 25901, "Insightful Earthstorm Diamond" },
    red = { { 24029, "Teardrop Living Ruby" } },
    yellow = { { 24060, "Luminous Noble Topaz" }, { 24047, "Brilliant Dawnstone" } },
    blue = { { 24057, "Royal Nightseye" } },
}
BiSGearCheckEnchantsDB["PaladinHoly"] = {
    Head     = { { 3001, "Glyph of Renewal" } },
    Shoulder = { { 2980, "Greater Inscription of Faith" }, { 2982, "Greater Inscription of Discipline" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2664, "Enchant Cloak - Major Resistance" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" }, { 2665, "Enchant Chest - Major Spirit" }, { 2679, "Enchant Chest - Restore Mana Prime" } },
    Wrist    = { { 2617, "Enchant Bracer - Superior Healing" }, { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2612, "Enchant Gloves - Major Healing" } },
    Legs     = { { 2746, "Golden Spellthread" }, { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" }, { 2656, "Enchant Boots - Vitality" } },
    Weapon   = { { 2666, "Enchant Weapon - Major Intellect" }, { 2669, "Enchant Weapon - Major Healing" } },
    Shield   = { { 2654, "Enchant Shield - Intellect" } },
}

BiSGearCheckGemsDB["PaladinProtection"] = {
    meta = { 25896, "Powerful Earthstorm Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 31867, "Veiled Noble Topaz" }, { 24066, "Enduring Talasite" } },
    blue = { { 24033, "Solid Star of Elune" }, { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["PaladinProtection"] = {
    Head     = { { 2999, "Arcanum of the Defender" } },
    Shoulder = { { 2978, "Greater Inscription of Warding" }, { 2993, "Greater Inscription of the Knight" } },
    Back     = { { 2622, "Enchant Cloak - Dodge" }, { 2662, "Enchant Cloak - Major Armor" } },
    Chest    = { { 2659, "Enchant Chest - Exceptional Health" }, { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 2649, "Enchant Bracer - Fortitude" }, { 2648, "Enchant Bracer - Major Defense" } },
    Hands    = { { 2613, "Enchant Gloves - Threat" }, { 2937, "Enchant Gloves - Major Spellpower" } },
    Legs     = { { 3013, "Nethercleft Leg Armor" }, { 2748, "Runic Spellthread" } },
    Feet     = { { 2649, "Enchant Boots - Fortitude" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2669, "Enchant Weapon - Major Spellpower" } },
    Shield   = { { 2653, "Enchant Shield - Major Stamina" } },
}

BiSGearCheckGemsDB["PaladinRetribution"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24027, "Bold Living Ruby" } },
    yellow = { { 24058, "Inscribed Noble Topaz" }, { 24051, "Rigid Dawnstone" } },
    blue = { { 24054, "Sovereign Nightseye" } },
}
BiSGearCheckEnchantsDB["PaladinRetribution"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2647, "Enchant Bracer - Brawn" }, { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2563, "Enchant Gloves - Major Strength" }, { 2618, "Enchant Gloves - Superior Agility" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2657, "Enchant Boots - Dexterity" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2673, "Enchant Weapon - Mongoose" }, { 2667, "Enchant Weapon - Savagery" } },
}

-- ============================================================
-- PRIEST
-- ============================================================

BiSGearCheckGemsDB["PriestHoly"] = {
    meta = { 25901, "Insightful Earthstorm Diamond" },
    red = { { 24029, "Teardrop Living Ruby" } },
    yellow = { { 24060, "Luminous Noble Topaz" } },
    blue = { { 32836, "Purified Shadow Pearl" }, { 24057, "Royal Nightseye" } },
}
BiSGearCheckEnchantsDB["PriestHoly"] = {
    Head     = { { 3001, "Glyph of Renewal" } },
    Shoulder = { { 2980, "Greater Inscription of Faith" }, { 2982, "Greater Inscription of Discipline" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2664, "Enchant Cloak - Major Resistance" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" }, { 2665, "Enchant Chest - Major Spirit" }, { 2679, "Enchant Chest - Restore Mana Prime" } },
    Wrist    = { { 2617, "Enchant Bracer - Superior Healing" }, { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2612, "Enchant Gloves - Major Healing" } },
    Legs     = { { 2746, "Golden Spellthread" }, { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" }, { 2656, "Enchant Boots - Vitality" } },
    Weapon   = { { 2669, "Enchant Weapon - Major Healing" } },
}

BiSGearCheckGemsDB["PriestShadow"] = {
    meta = { 25893, "Mystical Skyfire Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 24059, "Potent Noble Topaz" }, { 31867, "Veiled Noble Topaz" } },
    blue = { { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["PriestShadow"] = {
    Head     = { { 3002, "Glyph of Power" } },
    Shoulder = { { 2982, "Greater Inscription of Discipline" }, { 2995, "Greater Inscription of the Orb" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2938, "Enchant Cloak - Spell Penetration" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2937, "Enchant Gloves - Major Spellpower" }, { 2935, "Enchant Gloves - Spell Strike" } },
    Legs     = { { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2672, "Enchant Weapon - Soulfrost" }, { 2669, "Enchant Weapon - Major Spellpower" } },
}

-- ============================================================
-- ROGUE (all 3 specs use similar gems/enchants)
-- ============================================================

BiSGearCheckGemsDB["RogueAssassination"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24028, "Delicate Living Ruby" } },
    yellow = { { 24061, "Glinting Noble Topaz" }, { 24051, "Rigid Dawnstone" } },
    blue = { { 24055, "Shifting Nightseye" } },
}
BiSGearCheckEnchantsDB["RogueAssassination"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2618, "Enchant Gloves - Superior Agility" }, { 2946, "Enchant Gloves - Assault" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2673, "Enchant Weapon - Mongoose" } },
}

BiSGearCheckGemsDB["RogueCombat"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24028, "Delicate Living Ruby" } },
    yellow = { { 24061, "Glinting Noble Topaz" }, { 24051, "Rigid Dawnstone" } },
    blue = { { 24055, "Shifting Nightseye" } },
}
BiSGearCheckEnchantsDB["RogueCombat"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2618, "Enchant Gloves - Superior Agility" }, { 2946, "Enchant Gloves - Assault" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2673, "Enchant Weapon - Mongoose" } },
}

BiSGearCheckGemsDB["RogueSubtlety"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24028, "Delicate Living Ruby" } },
    yellow = { { 24061, "Glinting Noble Topaz" }, { 24051, "Rigid Dawnstone" } },
    blue = { { 24055, "Shifting Nightseye" } },
}
BiSGearCheckEnchantsDB["RogueSubtlety"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2618, "Enchant Gloves - Superior Agility" }, { 2946, "Enchant Gloves - Assault" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2673, "Enchant Weapon - Mongoose" } },
}

-- ============================================================
-- SHAMAN
-- ============================================================

BiSGearCheckGemsDB["ShamanElemental"] = {
    meta = { 34220, "Chaotic Skyfire Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 24059, "Potent Noble Topaz" }, { 31867, "Veiled Noble Topaz" } },
    blue = { { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["ShamanElemental"] = {
    Head     = { { 3002, "Glyph of Power" } },
    Shoulder = { { 2982, "Greater Inscription of Discipline" }, { 2995, "Greater Inscription of the Orb" } },
    Back     = { { 2938, "Enchant Cloak - Spell Penetration" }, { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2937, "Enchant Gloves - Major Spellpower" }, { 2935, "Enchant Gloves - Spell Strike" } },
    Legs     = { { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2669, "Enchant Weapon - Major Spellpower" } },
    Shield   = { { 2654, "Enchant Shield - Intellect" } },
}

BiSGearCheckGemsDB["ShamanEnhancement"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24027, "Bold Living Ruby" } },
    yellow = { { 24058, "Inscribed Noble Topaz" } },
    blue = { { 24054, "Sovereign Nightseye" } },
}
BiSGearCheckEnchantsDB["ShamanEnhancement"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2647, "Enchant Bracer - Brawn" }, { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2563, "Enchant Gloves - Major Strength" }, { 2618, "Enchant Gloves - Superior Agility" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2673, "Enchant Weapon - Mongoose" } },
}

BiSGearCheckGemsDB["ShamanRestoration"] = {
    meta = { 25897, "Bracing Earthstorm Diamond" },
    red = { { 24029, "Teardrop Living Ruby" } },
    yellow = { { 35315, "Quick Dawnstone" }, { 24060, "Luminous Noble Topaz" } },
    blue = { { 24057, "Royal Nightseye" } },
}
BiSGearCheckEnchantsDB["ShamanRestoration"] = {
    Head     = { { 3001, "Glyph of Renewal" } },
    Shoulder = { { 2980, "Greater Inscription of Faith" }, { 2982, "Greater Inscription of Discipline" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2679, "Enchant Chest - Restore Mana Prime" }, { 2661, "Enchant Chest - Exceptional Stats" }, { 2665, "Enchant Chest - Major Spirit" } },
    Wrist    = { { 2617, "Enchant Bracer - Superior Healing" }, { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2612, "Enchant Gloves - Major Healing" } },
    Legs     = { { 2746, "Golden Spellthread" }, { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" }, { 2656, "Enchant Boots - Vitality" } },
    Weapon   = { { 2669, "Enchant Weapon - Major Healing" } },
    Shield   = { { 2654, "Enchant Shield - Intellect" } },
}

-- ============================================================
-- WARLOCK
-- ============================================================

BiSGearCheckGemsDB["WarlockAffliction"] = {
    meta = { 25893, "Mystical Skyfire Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 31867, "Veiled Noble Topaz" }, { 24059, "Potent Noble Topaz" } },
    blue = { { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["WarlockAffliction"] = {
    Head     = { { 3002, "Glyph of Power" } },
    Shoulder = { { 2982, "Greater Inscription of Discipline" }, { 2995, "Greater Inscription of the Orb" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2938, "Enchant Cloak - Spell Penetration" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2937, "Enchant Gloves - Major Spellpower" }, { 2935, "Enchant Gloves - Spell Strike" } },
    Legs     = { { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2672, "Enchant Weapon - Soulfrost" }, { 2669, "Enchant Weapon - Major Spellpower" } },
}

BiSGearCheckGemsDB["WarlockDemonology"] = {
    meta = { 25893, "Mystical Skyfire Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 31867, "Veiled Noble Topaz" }, { 24059, "Potent Noble Topaz" } },
    blue = { { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["WarlockDemonology"] = {
    Head     = { { 3002, "Glyph of Power" } },
    Shoulder = { { 2982, "Greater Inscription of Discipline" }, { 2995, "Greater Inscription of the Orb" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2938, "Enchant Cloak - Spell Penetration" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2937, "Enchant Gloves - Major Spellpower" }, { 2935, "Enchant Gloves - Spell Strike" } },
    Legs     = { { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2672, "Enchant Weapon - Soulfrost" }, { 2669, "Enchant Weapon - Major Spellpower" } },
}

BiSGearCheckGemsDB["WarlockDestruction"] = {
    meta = { 34220, "Chaotic Skyfire Diamond" },
    red = { { 24030, "Runed Living Ruby" } },
    yellow = { { 31867, "Veiled Noble Topaz" }, { 24059, "Potent Noble Topaz" } },
    blue = { { 24056, "Glowing Nightseye" } },
}
BiSGearCheckEnchantsDB["WarlockDestruction"] = {
    Head     = { { 3002, "Glyph of Power" } },
    Shoulder = { { 2982, "Greater Inscription of Discipline" }, { 2995, "Greater Inscription of the Orb" } },
    Back     = { { 2621, "Enchant Cloak - Subtlety" }, { 2938, "Enchant Cloak - Spell Penetration" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2650, "Enchant Bracer - Spellpower" }, { 369, "Enchant Bracer - Major Intellect" } },
    Hands    = { { 2937, "Enchant Gloves - Major Spellpower" }, { 2935, "Enchant Gloves - Spell Strike" } },
    Legs     = { { 2748, "Runic Spellthread" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2671, "Enchant Weapon - Sunfire" }, { 2672, "Enchant Weapon - Soulfrost" }, { 2669, "Enchant Weapon - Major Spellpower" } },
}

-- ============================================================
-- WARRIOR
-- ============================================================

BiSGearCheckGemsDB["WarriorArms"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24027, "Bold Living Ruby" } },
    yellow = { { 24058, "Inscribed Noble Topaz" }, { 24051, "Rigid Dawnstone" } },
    blue = { { 24054, "Sovereign Nightseye" } },
}
BiSGearCheckEnchantsDB["WarriorArms"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2647, "Enchant Bracer - Brawn" }, { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2563, "Enchant Gloves - Major Strength" }, { 2618, "Enchant Gloves - Superior Agility" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2673, "Enchant Weapon - Mongoose" }, { 2667, "Enchant Weapon - Savagery" } },
}

BiSGearCheckGemsDB["WarriorFury"] = {
    meta = { 32409, "Relentless Earthstorm Diamond" },
    red = { { 24027, "Bold Living Ruby" } },
    yellow = { { 24058, "Inscribed Noble Topaz" }, { 24048, "Smooth Dawnstone" } },
    blue = { { 24054, "Sovereign Nightseye" }, { 24067, "Jagged Talasite" } },
}
BiSGearCheckEnchantsDB["WarriorFury"] = {
    Head     = { { 3003, "Glyph of Ferocity" } },
    Shoulder = { { 2986, "Greater Inscription of Vengeance" }, { 2997, "Greater Inscription of the Blade" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2621, "Enchant Cloak - Subtlety" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" } },
    Wrist    = { { 2647, "Enchant Bracer - Brawn" }, { 2606, "Enchant Bracer - Assault" } },
    Hands    = { { 2563, "Enchant Gloves - Major Strength" }, { 2618, "Enchant Gloves - Superior Agility" } },
    Legs     = { { 3012, "Nethercobra Leg Armor" } },
    Feet     = { { 2939, "Enchant Boots - Cat's Swiftness" }, { 2940, "Enchant Boots - Boar's Speed" } },
    Weapon   = { { 2673, "Enchant Weapon - Mongoose" }, { 2667, "Enchant Weapon - Savagery" } },
    Ranged   = { { 2723, "Khorium Scope" }, { 2724, "Stabilized Eternium Scope" } },
}

BiSGearCheckGemsDB["WarriorProtection"] = {
    meta = { 25896, "Powerful Earthstorm Diamond" },
    red = { { 24055, "Shifting Nightseye" } },
    yellow = { { 24061, "Glinting Noble Topaz" }, { 33782, "Steady Talasite" } },
    blue = { { 24033, "Solid Star of Elune" } },
}
BiSGearCheckEnchantsDB["WarriorProtection"] = {
    Head     = { { 2999, "Arcanum of the Defender" } },
    Shoulder = { { 2978, "Greater Inscription of Warding" }, { 2986, "Greater Inscription of Vengeance" } },
    Back     = { { 2657, "Enchant Cloak - Greater Agility" }, { 2622, "Enchant Cloak - Dodge" }, { 2662, "Enchant Cloak - Major Armor" } },
    Chest    = { { 2661, "Enchant Chest - Exceptional Stats" }, { 2659, "Enchant Chest - Exceptional Health" } },
    Wrist    = { { 2649, "Enchant Bracer - Fortitude" }, { 2648, "Enchant Bracer - Major Defense" } },
    Hands    = { { 2613, "Enchant Gloves - Threat" }, { 2618, "Enchant Gloves - Superior Agility" } },
    Legs     = { { 3013, "Nethercleft Leg Armor" }, { 3011, "Clefthide Leg Armor" } },
    Feet     = { { 2940, "Enchant Boots - Boar's Speed" }, { 2939, "Enchant Boots - Cat's Swiftness" } },
    Weapon   = { { 2673, "Enchant Weapon - Mongoose" }, { 2668, "Enchant Weapon - Potency" } },
    Shield   = { { 2653, "Enchant Shield - Major Stamina" } },
    Ranged   = { { 2723, "Khorium Scope" }, { 2724, "Stabilized Eternium Scope" } },
}
