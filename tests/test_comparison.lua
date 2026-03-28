-- Tests for Comparison.lua
-- Faction filtering, CompareSlot ranking, RunComparison orchestration

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function setupBasicState()
    BiSGearCheckSaved = {
        characters = {
            ["TestChar-TestRealm"] = {
                class = "WARRIOR",
                faction = "Alliance",
                level = 70,
                wishlists = { Default = {} },
                activeWishlist = "Default",
            }
        }
    }
    BiSGearCheckChar = {}
    BiSGearCheck.playerKey = "TestChar-TestRealm"
    BiSGearCheck.viewingCharKey = "TestChar-TestRealm"
    BiSGearCheck.playerFaction = "Alliance"
    BiSGearCheck.pendingItems = {}
    BiSGearCheck.selectedSpec = "WarriorFury"
    BiSGearCheck.phaseFilter = 1
    BiSGearCheck.dataSource = "wowtbcgg"
end

-- ============================================================
-- TESTS: IsItemAvailableForFaction
-- ============================================================

function T.test_faction_available_no_source_data()
    setupBasicState()
    BiSGearCheckSources = {}
    assert_true(BiSGearCheck:IsItemAvailableForFaction(100))
end

function T.test_faction_available_no_faction_tag()
    setupBasicState()
    BiSGearCheckSources = { [100] = { source = "Karazhan" } }
    assert_true(BiSGearCheck:IsItemAvailableForFaction(100))
end

function T.test_faction_available_matching()
    setupBasicState()
    BiSGearCheckSources = { [100] = { source = "PvP", faction = "Alliance" } }
    assert_true(BiSGearCheck:IsItemAvailableForFaction(100))
end

function T.test_faction_unavailable()
    setupBasicState()
    BiSGearCheckSources = { [100] = { source = "PvP", faction = "Horde" } }
    assert_false(BiSGearCheck:IsItemAvailableForFaction(100))
end

-- ============================================================
-- TESTS: FilterBisListByFaction
-- ============================================================

function T.test_filter_bis_list_mixed()
    setupBasicState()
    BiSGearCheckSources = {
        [101] = { source = "PvP", faction = "Alliance" },
        [102] = { source = "PvP", faction = "Horde" },
        [103] = { source = "Karazhan" }, -- neutral
    }
    local result = BiSGearCheck:FilterBisListByFaction({ 101, 102, 103 })
    assert_equal(2, #result)
    assert_equal(101, result[1])
    assert_equal(103, result[2])
end

function T.test_filter_bis_list_all_neutral()
    setupBasicState()
    BiSGearCheckSources = {}
    local result = BiSGearCheck:FilterBisListByFaction({ 101, 102, 103 })
    assert_equal(3, #result)
end

function T.test_filter_bis_list_empty()
    setupBasicState()
    local result = BiSGearCheck:FilterBisListByFaction({})
    assert_equal(0, #result)
end

-- ============================================================
-- TESTS: CompareSlot
-- ============================================================

function T.test_compare_slot_equipped_at_rank()
    setupBasicState()
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
        [203] = { source = "Karazhan", sourceType = "Boss" },
    }
    -- Equipped item is rank 3 in BiS list
    MockWoW.SetInventory({ [1] = { id = 203, link = "|Hitem:203:0:0:0:0:0|h[Helm]|h" } })
    -- Provide item info for upgrades
    MockWoW.SetItemInfo(201, { name = "Best Helm", quality = 4 })
    MockWoW.SetItemInfo(202, { name = "Good Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203 })
    assert_not_nil(result)
    assert_equal("Head", result.slotName)
    assert_equal(1, #result.equipped)
    assert_equal(203, result.equipped[1].id)
    assert_equal(3, result.equipped[1].rank)
    assert_equal(3, result.bestEquippedRank)
    -- Upgrades: items ranked 1 and 2 (above equipped rank 3)
    assert_equal(2, #result.upgrades)
    assert_equal(201, result.upgrades[1].id)
    assert_equal(1, result.upgrades[1].rank)
    assert_equal(202, result.upgrades[2].id)
    assert_equal(2, result.upgrades[2].rank)
end

function T.test_compare_slot_equipped_is_bis()
    setupBasicState()
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({ [1] = { id = 201, link = "|Hitem:201:0:0:0:0:0|h[Best Helm]|h" } })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203 })
    assert_equal(1, result.bestEquippedRank)
    assert_equal(0, #result.upgrades, "no upgrades when equipped is BiS")
end

function T.test_compare_slot_unranked_equipped()
    setupBasicState()
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
    }
    -- Equipped item not on BiS list at all
    MockWoW.SetInventory({ [1] = { id = 999, link = "|Hitem:999:0:0:0:0:0|h[Bad Helm]|h" } })
    MockWoW.SetItemInfo(201, { name = "Best Helm", quality = 4 })
    MockWoW.SetItemInfo(202, { name = "Good Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202 })
    assert_equal(999, result.bestEquippedRank, "unranked stays at 999")
    assert_nil(result.equipped[1].rank)
    -- All BiS items should be shown as upgrades
    assert_equal(2, #result.upgrades)
end

function T.test_compare_slot_dual_slot_uses_worst_rank()
    setupBasicState()
    BiSGearCheckSources = {
        [301] = { source = "Karazhan", sourceType = "Boss" },
        [302] = { source = "Karazhan", sourceType = "Boss" },
        [303] = { source = "Karazhan", sourceType = "Boss" },
        [304] = { source = "Karazhan", sourceType = "Boss" },
        [305] = { source = "Karazhan", sourceType = "Boss" },
    }
    -- Two rings equipped: rank 2 and rank 4
    MockWoW.SetInventory({
        [11] = { id = 302, link = "|Hitem:302:0:0:0:0:0|h[Ring A]|h" },
        [12] = { id = 304, link = "|Hitem:304:0:0:0:0:0|h[Ring B]|h" },
    })
    MockWoW.SetItemInfo(301, { name = "BiS Ring", quality = 4 })
    MockWoW.SetItemInfo(303, { name = "Third Ring", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Rings", { 301, 302, 303, 304, 305 })
    assert_equal(2, result.bestEquippedRank)
    assert_equal(4, result.worstEquippedRank)
    -- For dual slots, cutoff is worst rank (4), so upgrades are ranks 1 and 3
    assert_equal(2, #result.upgrades)
    assert_equal(301, result.upgrades[1].id)
    assert_equal(303, result.upgrades[2].id)
end

function T.test_compare_slot_inspected_character()
    setupBasicState()
    -- Set up an inspected character
    BiSGearCheckSaved.characters["OtherPlayer-TestRealm"] = {
        class = "WARRIOR",
        faction = "Alliance",
        level = 70,
        wishlists = { Default = {} },
        activeWishlist = "Default",
        inspected = true,
        equipped = {
            Head = { { id = 203, link = "|Hitem:203:0:0:0:0:0|h[Helm]|h", invSlot = 1 } },
        },
    }
    BiSGearCheck.viewingCharKey = "OtherPlayer-TestRealm"

    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
        [203] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetItemInfo(201, { name = "Best Helm", quality = 4 })
    MockWoW.SetItemInfo(202, { name = "Good Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203 })
    assert_equal(1, #result.equipped)
    assert_equal(203, result.equipped[1].id)
    assert_equal(3, result.bestEquippedRank)
    assert_equal(2, #result.upgrades)
end

-- ============================================================
-- TESTS: RunComparison
-- ============================================================

function T.test_run_comparison_no_spec()
    setupBasicState()
    BiSGearCheck.selectedSpec = nil
    BiSGearCheck:RunComparison()
    assert_equal(0, #BiSGearCheck.comparisonResults)
end

function T.test_run_comparison_no_db()
    setupBasicState()
    -- No database globals loaded
    BiSGearCheck:RunComparison()
    assert_equal(0, #BiSGearCheck.comparisonResults)
end

function T.test_run_comparison_with_data()
    setupBasicState()
    -- Set up a mock database
    _G["BiSGearCheckDB_WowTBCgg"] = {
        WarriorFury = {
            class = "WARRIOR",
            spec = "Fury",
            slots = {
                Head = { 201, 202, 203 },
            },
        },
    }
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
        [203] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({ [1] = { id = 203, link = "|Hitem:203:0:0:0:0:0|h[Helm]|h" } })
    MockWoW.SetItemInfo(201, { name = "Best Helm", quality = 4 })
    MockWoW.SetItemInfo(202, { name = "Good Helm", quality = 4 })

    BiSGearCheck:RunComparison()
    assert_true(#BiSGearCheck.comparisonResults > 0)
    assert_equal("Head", BiSGearCheck.comparisonResults[1].slotName)
end

return T
