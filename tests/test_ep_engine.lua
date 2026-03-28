-- Tests for EPEngine.lua
-- EP scoring, hit caps, item comparison, upgrade percentages

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function setupEPWeights()
    BiSGearCheckEPWeights = {
        WarriorFury = {
            weights = { 4, 2.2, 32, 1.8, 14, 0.5 },  -- Strength(4)=2.2, AP(32)=1.8, SpellHitRating(14)=0.5
            baseMiss = 9,
            talentHit = 3,
            hitStatIndex = 14,
            hitRatingPerPct = 12.62,
        },
        MageFrost = {
            weights = { 14, 1.0, 15, 0.8 },  -- SpellHitRating(14)=1.0, SpellCrit(15)=0.8
            baseMiss = 16,
            talentHit = 0,
            hitStatIndex = 14,
            hitRatingPerPct = 12.62,
        },
    }
end

local function setupItemStats()
    BiSGearCheckItemStats = {
        [28000] = { [4] = 30, [32] = 60 },      -- 30 Str, 60 AP
        [28001] = { [4] = 40, [32] = 80 },      -- 40 Str, 80 AP (better)
        [28002] = { [14] = 20, [15] = 15 },     -- 20 SpellHit, 15 SpellCrit
        [28003] = {},                             -- empty stats
    }
end

-- ============================================================
-- TESTS: EnsureEPSettings
-- ============================================================

function T.test_ensure_ep_settings_creates_defaults()
    BiSGearCheckSaved = nil
    BiSGearCheck:EnsureEPSettings()
    assert_not_nil(BiSGearCheckSaved)
    assert_not_nil(BiSGearCheckSaved.ep)
    assert_equal(true, BiSGearCheckSaved.ep.showInTooltip)
    assert_equal(true, BiSGearCheckSaved.ep.showInCompare)
    assert_equal(false, BiSGearCheckSaved.ep.hasDraenei)
    assert_equal(false, BiSGearCheckSaved.ep.hasTotemOfWrath)
    assert_equal(false, BiSGearCheckSaved.ep.hasImpFaerieFire)
end

function T.test_ensure_ep_settings_preserves_existing()
    BiSGearCheckSaved = { characters = {}, ep = { showInTooltip = false, hasDraenei = true } }
    BiSGearCheck:EnsureEPSettings()
    assert_equal(false, BiSGearCheckSaved.ep.showInTooltip, "should not overwrite existing")
    assert_equal(true, BiSGearCheckSaved.ep.hasDraenei, "should not overwrite existing")
    assert_equal(true, BiSGearCheckSaved.ep.showInCompare, "should fill missing default")
end

-- ============================================================
-- TESTS: ScoreItem
-- ============================================================

function T.test_score_item_basic()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local ep, breakdown = BiSGearCheck:ScoreItem(28000, "WarriorFury")
    -- 30 * 2.2 + 60 * 1.8 = 66 + 108 = 174
    assert_near(174.0, ep, 0.1, "EP for item 28000")
    assert_not_nil(breakdown)
    assert_near(66.0, breakdown[4].ep, 0.1, "Strength EP")
    assert_near(108.0, breakdown[32].ep, 0.1, "AP EP")
end

function T.test_score_item_better_item()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local ep = BiSGearCheck:ScoreItem(28001, "WarriorFury")
    -- 40 * 2.2 + 80 * 1.8 = 88 + 144 = 232
    assert_near(232.0, ep, 0.1, "EP for item 28001")
end

function T.test_score_item_no_weights_returns_zero()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local ep = BiSGearCheck:ScoreItem(28000, "NonexistentSpec")
    assert_equal(0, ep)
end

function T.test_score_item_no_stats_returns_zero()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local ep = BiSGearCheck:ScoreItem(99999, "WarriorFury")
    assert_equal(0, ep)
end

function T.test_score_item_empty_stats_returns_zero()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local ep = BiSGearCheck:ScoreItem(28003, "WarriorFury")
    assert_equal(0, ep)
end

function T.test_score_item_nil_globals_returns_zero()
    BiSGearCheckEPWeights = nil
    BiSGearCheckItemStats = nil
    local ep = BiSGearCheck:ScoreItem(28000, "WarriorFury")
    assert_equal(0, ep)
end

-- ============================================================
-- TESTS: GetEffectiveHitCap
-- ============================================================

function T.test_hit_cap_basic()
    setupEPWeights()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local hitCap, hitCapRating, hitStatIndex = BiSGearCheck:GetEffectiveHitCap("WarriorFury")
    -- baseMiss(9) - talentHit(3) - partyHit(0) = 6
    assert_equal(6, hitCap, "hit cap pct")
    assert_near(6 * 12.62, hitCapRating, 0.1, "hit cap rating")
    assert_equal(14, hitStatIndex)
end

function T.test_hit_cap_with_draenei()
    setupEPWeights()
    BiSGearCheckSaved = { characters = {}, ep = { hasDraenei = true } }
    BiSGearCheck:EnsureEPSettings()

    local hitCap = BiSGearCheck:GetEffectiveHitCap("WarriorFury")
    -- 9 - 3 - 1 (draenei) = 5
    assert_equal(5, hitCap)
end

function T.test_hit_cap_with_totem_of_wrath_for_spell_hit()
    setupEPWeights()
    BiSGearCheckSaved = { characters = {}, ep = { hasTotemOfWrath = true } }
    BiSGearCheck:EnsureEPSettings()

    -- MageFrost uses hitStatIndex=14 (spell hit), so TotemOfWrath applies
    local hitCap = BiSGearCheck:GetEffectiveHitCap("MageFrost")
    -- 16 - 0 - 3 (totem) = 13
    assert_equal(13, hitCap)
end

function T.test_hit_cap_with_imp_faerie_fire_for_melee()
    setupEPWeights()
    -- Simulate a melee spec with hitStatIndex != 14
    BiSGearCheckEPWeights.WarriorMelee = {
        weights = {},
        baseMiss = 9,
        talentHit = 0,
        hitStatIndex = 31, -- melee hit
        hitRatingPerPct = 15.77,
    }
    BiSGearCheckSaved = { characters = {}, ep = { hasImpFaerieFire = true } }
    BiSGearCheck:EnsureEPSettings()

    local hitCap = BiSGearCheck:GetEffectiveHitCap("WarriorMelee")
    -- 9 - 0 - 3 (faerie fire) = 6
    assert_equal(6, hitCap)
end

function T.test_hit_cap_nonexistent_spec()
    setupEPWeights()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local hitCap, hitCapRating, hitStatIndex = BiSGearCheck:GetEffectiveHitCap("NonexistentSpec")
    assert_equal(0, hitCap)
    assert_equal(0, hitCapRating)
    assert_equal(0, hitStatIndex)
end

function T.test_hit_cap_floors_at_zero()
    setupEPWeights()
    -- Massive talent hit + buffs should floor at 0
    BiSGearCheckEPWeights.OverCapped = {
        weights = {},
        baseMiss = 5,
        talentHit = 10, -- more than baseMiss
        hitStatIndex = 14,
        hitRatingPerPct = 12.62,
    }
    BiSGearCheckSaved = { characters = {}, ep = { hasDraenei = true, hasTotemOfWrath = true } }
    BiSGearCheck:EnsureEPSettings()

    local hitCap = BiSGearCheck:GetEffectiveHitCap("OverCapped")
    assert_equal(0, hitCap)
end

-- ============================================================
-- TESTS: CompareItemEP
-- ============================================================

function T.test_compare_item_ep_upgrade()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local diff, newEP, currentEP = BiSGearCheck:CompareItemEP(28001, 28000, "WarriorFury")
    assert_near(232 - 174, diff, 0.1, "EP difference")
    assert_near(232, newEP, 0.1)
    assert_near(174, currentEP, 0.1)
end

function T.test_compare_item_ep_downgrade()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local diff = BiSGearCheck:CompareItemEP(28000, 28001, "WarriorFury")
    assert_true(diff < 0, "should be negative for downgrade")
end

-- ============================================================
-- TESTS: GetUpgradePercent
-- ============================================================

function T.test_upgrade_percent_positive()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local pct = BiSGearCheck:GetUpgradePercent(28001, 28000, "WarriorFury")
    -- (232-174)/174 * 100 = ~33.3%
    assert_near(33.33, pct, 0.1)
end

function T.test_upgrade_percent_zero_current()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    -- Item with no stats (0 EP) as current
    local pct = BiSGearCheck:GetUpgradePercent(28000, 28003, "WarriorFury")
    assert_equal(100, pct, "should be 100% upgrade from nothing")
end

function T.test_upgrade_percent_both_zero()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local pct = BiSGearCheck:GetUpgradePercent(28003, 28003, "WarriorFury")
    assert_equal(0, pct)
end

-- ============================================================
-- TESTS: GetItemEPString
-- ============================================================

function T.test_get_item_ep_string()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local str = BiSGearCheck:GetItemEPString(28000, "WarriorFury")
    assert_equal("174.0", str)
end

function T.test_get_item_ep_string_zero_returns_nil()
    setupEPWeights()
    setupItemStats()
    BiSGearCheckSaved = { characters = {}, ep = {} }
    BiSGearCheck:EnsureEPSettings()

    local str = BiSGearCheck:GetItemEPString(28003, "WarriorFury")
    assert_nil(str)
end

return T
