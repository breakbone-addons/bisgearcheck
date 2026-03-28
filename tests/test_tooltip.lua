-- Tests for Tooltip.lua
-- BuildTooltipIndex, tooltip settings, conflict detection

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function setupTooltipState()
    BiSGearCheckSaved = {
        characters = {
            ["TestChar-TestRealm"] = {
                class = "WARRIOR", faction = "Alliance", level = 70,
                wishlists = { Default = {} }, activeWishlist = "Default",
            }
        },
    }
    BiSGearCheckChar = {}
    BiSGearCheck.playerKey = "TestChar-TestRealm"
    BiSGearCheck.viewingCharKey = "TestChar-TestRealm"
    BiSGearCheck.playerFaction = "Alliance"
    BiSGearCheck.selectedSpec = "WarriorFury"
    BiSGearCheck.phaseFilter = 1
    BiSGearCheck.pendingItems = {}
end

-- ============================================================
-- TESTS: EnsureTooltipSettings
-- ============================================================

function T.test_ensure_tooltip_settings_creates_defaults()
    BiSGearCheckSaved = nil
    BiSGearCheck:EnsureTooltipSettings()
    assert_not_nil(BiSGearCheckSaved.tooltip)
    assert_equal(true, BiSGearCheckSaved.tooltip.showBiS)
    assert_equal(false, BiSGearCheckSaved.tooltip.showOnlyMyClass)
end

function T.test_ensure_tooltip_settings_preserves_existing()
    BiSGearCheckSaved = { characters = {}, tooltip = { showBiS = false } }
    BiSGearCheck:EnsureTooltipSettings()
    assert_equal(false, BiSGearCheckSaved.tooltip.showBiS)
    assert_equal(false, BiSGearCheckSaved.tooltip.showOnlyMyClass) -- fills missing
end

-- ============================================================
-- TESTS: GetTooltipSetting / SetTooltipSetting
-- ============================================================

function T.test_get_tooltip_setting()
    BiSGearCheckSaved = { characters = {}, tooltip = { showBiS = true } }
    assert_equal(true, BiSGearCheck:GetTooltipSetting("showBiS"))
end

function T.test_get_tooltip_setting_nil()
    BiSGearCheckSaved = nil
    assert_nil(BiSGearCheck:GetTooltipSetting("showBiS"))
end

function T.test_set_tooltip_setting()
    BiSGearCheckSaved = nil
    BiSGearCheck:SetTooltipSetting("showBiS", false)
    assert_equal(false, BiSGearCheckSaved.tooltip.showBiS)
end

-- ============================================================
-- TESTS: BuildTooltipIndex
-- ============================================================

function T.test_build_tooltip_index_empty()
    setupTooltipState()
    BiSGearCheck:EnsureSourceSettings()
    -- No database globals loaded
    BiSGearCheck:BuildTooltipIndex()
    assert_not_nil(BiSGearCheck.TooltipIndex)
end

function T.test_build_tooltip_index_single_source()
    setupTooltipState()
    BiSGearCheck:EnsureSourceSettings()
    _G["BiSGearCheckDB_WowTBCgg"] = {
        WarriorFury = {
            class = "WARRIOR", spec = "Fury",
            slots = {
                Head = { 28000, 28001 },
                Chest = { 29000 },
            },
        },
    }

    BiSGearCheck:BuildTooltipIndex()
    local idx = BiSGearCheck.TooltipIndex

    -- Item 28000 should be indexed
    assert_not_nil(idx["28000"])
    assert_equal(1, #idx["28000"])
    assert_equal("WarriorFury", idx["28000"][1].specKey)
    assert_equal("WARRIOR", idx["28000"][1].class)
    assert_equal("Fury", idx["28000"][1].spec)
    assert_equal("Head", idx["28000"][1].slot)
    assert_equal(1, idx["28000"][1].rank)
    assert_equal("wowtbcgg", idx["28000"][1].source)

    -- Item 28001 at rank 2
    assert_not_nil(idx["28001"])
    assert_equal(2, idx["28001"][1].rank)

    -- Chest item
    assert_not_nil(idx["29000"])
    assert_equal("Chest", idx["29000"][1].slot)

    -- Cleanup
    _G["BiSGearCheckDB_WowTBCgg"] = nil
end

function T.test_build_tooltip_index_multiple_sources()
    setupTooltipState()
    BiSGearCheck:EnsureSourceSettings()
    _G["BiSGearCheckDB_WowTBCgg"] = {
        WarriorFury = {
            class = "WARRIOR", spec = "Fury",
            slots = { Head = { 28000 } },
        },
    }
    _G["BiSGearCheckDB_Phase1"] = {
        WarriorFury = {
            class = "WARRIOR", spec = "Fury",
            slots = { Head = { 28000, 28001 } },
        },
    }

    BiSGearCheck:BuildTooltipIndex()
    local idx = BiSGearCheck.TooltipIndex

    -- Item 28000 should appear from both sources
    assert_not_nil(idx["28000"])
    assert_equal(2, #idx["28000"])

    -- Cleanup
    _G["BiSGearCheckDB_WowTBCgg"] = nil
    _G["BiSGearCheckDB_Phase1"] = nil
end

function T.test_build_tooltip_index_respects_disabled_sources()
    setupTooltipState()
    BiSGearCheck:EnsureSourceSettings()
    -- Disable wowtbcgg for tooltips
    BiSGearCheckSaved.sourceSettings.wowtbcgg.tooltip = false

    _G["BiSGearCheckDB_WowTBCgg"] = {
        WarriorFury = {
            class = "WARRIOR", spec = "Fury",
            slots = { Head = { 28000 } },
        },
    }
    _G["BiSGearCheckDB_Phase1"] = {
        WarriorFury = {
            class = "WARRIOR", spec = "Fury",
            slots = { Head = { 28000 } },
        },
    }

    BiSGearCheck:BuildTooltipIndex()
    local idx = BiSGearCheck.TooltipIndex

    -- Should only have entry from bistooltip, not wowtbcgg
    if idx["28000"] then
        for _, entry in ipairs(idx["28000"]) do
            assert_true(entry.source ~= "wowtbcgg",
                "disabled tooltip source should not appear")
        end
    end

    _G["BiSGearCheckDB_WowTBCgg"] = nil
    _G["BiSGearCheckDB_Phase1"] = nil
end

-- ============================================================
-- TESTS: CheckTooltipConflict
-- ============================================================

function T.test_conflict_no_conflict_installs_hooks()
    setupTooltipState()
    BiSGearCheck:EnsureTooltipSettings()
    MockWoW._loadedAddons = {}
    BiSGearCheck.tooltipHooked = false
    BiSGearCheck:CheckTooltipConflict()
    assert_true(BiSGearCheck.tooltipHooked)
end

function T.test_conflict_resolved_bisgearcheck()
    setupTooltipState()
    BiSGearCheck:EnsureTooltipSettings()
    MockWoW._loadedAddons = { AtlasBIStooltips = true }
    BiSGearCheckSaved.tooltip.conflictResolved = "AtlasBIStooltips"
    BiSGearCheckSaved.tooltip.conflictChoice = "bisgearcheck"
    BiSGearCheck.tooltipHooked = false
    BiSGearCheck:CheckTooltipConflict()
    assert_true(BiSGearCheck.tooltipHooked, "should install hooks with bisgearcheck choice")
end

function T.test_conflict_resolved_other()
    setupTooltipState()
    BiSGearCheck:EnsureTooltipSettings()
    MockWoW._loadedAddons = { AtlasBIStooltips = true }
    BiSGearCheckSaved.tooltip.conflictResolved = "AtlasBIStooltips"
    BiSGearCheckSaved.tooltip.conflictChoice = "other"
    BiSGearCheck.tooltipHooked = false
    BiSGearCheck:CheckTooltipConflict()
    assert_false(BiSGearCheck.tooltipHooked, "should NOT install hooks with other choice")
end

function T.test_conflict_resolved_both()
    setupTooltipState()
    BiSGearCheck:EnsureTooltipSettings()
    MockWoW._loadedAddons = { AtlasBIStooltips = true }
    BiSGearCheckSaved.tooltip.conflictResolved = "AtlasBIStooltips"
    BiSGearCheckSaved.tooltip.conflictChoice = "both"
    BiSGearCheck.tooltipHooked = false
    BiSGearCheck:CheckTooltipConflict()
    assert_true(BiSGearCheck.tooltipHooked, "should install hooks with both choice")
end

return T
