-- Tests for Character.lua
-- Character key, migration, registration, snapshots, inspection, ignore list, viewing context

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function setupCharState()
    BiSGearCheckSaved = {
        characters = {
            ["TestChar-TestRealm"] = {
                class = "WARRIOR",
                faction = "Alliance",
                level = 70,
                wishlists = { Default = {} },
                activeWishlist = "Default",
            }
        },
        minCharLevel = 70,
        ignoredCharacters = {},
    }
    BiSGearCheckChar = { selectedSpec = "WarriorFury" }
    BiSGearCheck.playerKey = "TestChar-TestRealm"
    BiSGearCheck.viewingCharKey = "TestChar-TestRealm"
    BiSGearCheck.playerFaction = "Alliance"
    BiSGearCheck.selectedSpec = "WarriorFury"
    BiSGearCheck.activeWishlist = "Default"
    BiSGearCheck.pendingItems = {}
    -- Stub Refresh to prevent UI calls
    BiSGearCheck.Refresh = function() end
    BiSGearCheck.RefreshView = function() end
    BiSGearCheck.mainFrame = nil
end

-- ============================================================
-- TESTS: GetCharacterKey
-- ============================================================

function T.test_get_character_key()
    local key = BiSGearCheck:GetCharacterKey()
    assert_equal("TestChar-TestRealm", key)
end

function T.test_get_character_key_custom()
    MockWoW._playerName = "MyHero"
    MockWoW._playerRealm = "Grobbulus"
    local key = BiSGearCheck:GetCharacterKey()
    assert_equal("MyHero-Grobbulus", key)
end

-- ============================================================
-- TESTS: MigrateSavedVars
-- ============================================================

function T.test_migrate_creates_fresh_structure()
    BiSGearCheckSaved = nil
    BiSGearCheckChar = nil
    BiSGearCheck:MigrateSavedVars()
    assert_not_nil(BiSGearCheckSaved)
    assert_not_nil(BiSGearCheckSaved.characters)
    assert_equal(70, BiSGearCheckSaved.minCharLevel)
    assert_not_nil(BiSGearCheckSaved.ignoredCharacters)
    assert_not_nil(BiSGearCheckChar)
end

function T.test_migrate_old_wishlists_format()
    BiSGearCheckSaved = {
        wishlists = { Default = { [28000] = { slotName = "Head" } }, Raid = {} },
        activeWishlist = "Default",
        selectedSpec = "WarriorFury",
        dataSource = "wowtbcgg",
    }
    BiSGearCheckChar = nil
    BiSGearCheck:MigrateSavedVars()

    -- Old top-level fields should be removed
    assert_nil(BiSGearCheckSaved.wishlists)
    assert_nil(BiSGearCheckSaved.activeWishlist)
    assert_nil(BiSGearCheckSaved.selectedSpec)

    -- Should be moved to character registry
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_not_nil(charData)
    assert_not_nil(charData.wishlists.Default)
    assert_not_nil(charData.wishlists.Raid)
    assert_equal("Default", charData.activeWishlist)

    -- Per-char settings moved to BiSGearCheckChar
    assert_equal("WarriorFury", BiSGearCheckChar.selectedSpec)
    assert_equal("wowtbcgg", BiSGearCheckChar.dataSource)
end

function T.test_migrate_old_single_wishlist()
    BiSGearCheckSaved = {
        wishlist = { [28000] = { slotName = "Head" } },
    }
    BiSGearCheckChar = nil
    BiSGearCheck:MigrateSavedVars()

    assert_nil(BiSGearCheckSaved.wishlist)
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_not_nil(charData)
    assert_not_nil(charData.wishlists.Default[28000])
end

-- ============================================================
-- TESTS: RegisterCharacter
-- ============================================================

function T.test_register_character_creates_entry()
    setupCharState()
    BiSGearCheckSaved.characters = {}
    BiSGearCheck:RegisterCharacter()
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_not_nil(charData)
    assert_equal("WARRIOR", charData.class)
    assert_equal("Alliance", charData.faction)
    assert_equal(70, charData.level)
    assert_not_nil(charData.wishlists.Default)
end

function T.test_register_character_updates_existing()
    setupCharState()
    MockWoW._playerLevel = 71
    BiSGearCheck:RegisterCharacter()
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_equal(71, charData.level)
end

function T.test_register_character_skips_ignored()
    setupCharState()
    BiSGearCheckSaved.ignoredCharacters["TestChar-TestRealm"] = true
    BiSGearCheckSaved.characters = {}
    BiSGearCheck:RegisterCharacter()
    assert_nil(BiSGearCheckSaved.characters["TestChar-TestRealm"])
end

function T.test_register_character_skips_below_level()
    setupCharState()
    MockWoW._playerLevel = 60
    BiSGearCheckSaved.characters = {}
    BiSGearCheck:RegisterCharacter()
    assert_nil(BiSGearCheckSaved.characters["TestChar-TestRealm"])
end

-- ============================================================
-- TESTS: SnapshotEquippedGear
-- ============================================================

function T.test_snapshot_equipped_gear()
    setupCharState()
    MockWoW.SetInventory({
        [1] = { id = 28000, link = "|Hitem:28000:0:0:0:0:0|h[Helm]|h" },
        [2] = { id = 28001, link = "|Hitem:28001:0:0:0:0:0|h[Neck]|h" },
    })
    BiSGearCheck:SnapshotEquippedGear()
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_not_nil(charData.equipped)
    assert_equal(1, #charData.equipped.Head)
    assert_equal(28000, charData.equipped.Head[1].id)
    assert_equal(1, #charData.equipped.Neck)
    assert_equal(28001, charData.equipped.Neck[1].id)
end

function T.test_snapshot_equipped_gear_skips_ignored()
    setupCharState()
    BiSGearCheckSaved.ignoredCharacters["TestChar-TestRealm"] = true
    MockWoW.SetInventory({ [1] = { id = 28000, link = "link" } })
    BiSGearCheck:SnapshotEquippedGear()
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_nil(charData.equipped)
end

function T.test_snapshot_equipped_gear_records_spec()
    setupCharState()
    BiSGearCheck.selectedSpec = "WarriorArms"
    BiSGearCheck:SnapshotEquippedGear()
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_equal("WarriorArms", charData.selectedSpec)
end

-- ============================================================
-- TESTS: SnapshotInspectedGear
-- ============================================================

function T.test_snapshot_inspected_gear_basic()
    setupCharState()
    MockWoW.SetInspectUnit({
        name = "OtherPlayer",
        realm = "TestRealm",
        class = "MAGE",
        classDisplay = "Mage",
        level = 70,
        faction = "Alliance",
        exists = true,
        canInspect = true,
        inventory = {
            [1] = { id = 30000, link = "|Hitem:30000:0:0:0:0:0|h[Helm]|h" },
            [15] = { id = 30001, link = "|Hitem:30001:0:0:0:0:0|h[Cloak]|h" },
        },
    })

    local charKey = BiSGearCheck:SnapshotInspectedGear()
    assert_equal("OtherPlayer-TestRealm", charKey)

    local charData = BiSGearCheckSaved.characters[charKey]
    assert_not_nil(charData)
    assert_equal("MAGE", charData.class)
    assert_equal(true, charData.inspected)
    assert_not_nil(charData.equipped)
    assert_equal(30000, charData.equipped.Head[1].id)
end

function T.test_snapshot_inspected_self_returns_nil()
    setupCharState()
    MockWoW.SetInspectUnit({
        name = "TestChar",
        realm = "TestRealm",
        class = "WARRIOR",
        classDisplay = "Warrior",
        level = 70,
        faction = "Alliance",
        exists = true,
        canInspect = true,
        isSelf = true,
        inventory = { [1] = { id = 28000, link = "|Hitem:28000:0:0:0:0:0|h[Helm]|h" } },
    })

    local charKey = BiSGearCheck:SnapshotInspectedGear()
    assert_nil(charKey, "should not snapshot self")
end

function T.test_snapshot_inspected_no_target()
    setupCharState()
    MockWoW._inspectUnit = nil
    local charKey = BiSGearCheck:SnapshotInspectedGear()
    assert_nil(charKey)
end

function T.test_snapshot_inspected_no_items()
    setupCharState()
    MockWoW.SetInspectUnit({
        name = "OtherPlayer",
        realm = "TestRealm",
        class = "MAGE",
        classDisplay = "Mage",
        level = 70,
        faction = "Alliance",
        exists = true,
        canInspect = true,
        inventory = {},
    })
    local charKey = BiSGearCheck:SnapshotInspectedGear()
    assert_nil(charKey, "should not save with 0 items")
end

function T.test_snapshot_inspected_sets_default_spec()
    setupCharState()
    MockWoW.SetInspectUnit({
        name = "OtherPlayer",
        realm = "TestRealm",
        class = "MAGE",
        classDisplay = "Mage",
        level = 70,
        faction = "Alliance",
        exists = true,
        canInspect = true,
        inventory = { [1] = { id = 30000, link = "|Hitem:30000:0:0:0:0:0|h[Helm]|h" } },
    })

    local charKey = BiSGearCheck:SnapshotInspectedGear()
    local charData = BiSGearCheckSaved.characters[charKey]
    assert_equal("MageArcane", charData.selectedSpec, "should default to first spec for class")
end

-- ============================================================
-- TESTS: GetCharacterKeys (filtered)
-- ============================================================

function T.test_get_character_keys_filtered()
    setupCharState()
    BiSGearCheckSaved.characters["Alt-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        wishlists = { Default = {} }, activeWishlist = "Default",
    }
    BiSGearCheckSaved.characters["LowLevel-TestRealm"] = {
        class = "ROGUE", faction = "Alliance", level = 30,
        wishlists = { Default = {} }, activeWishlist = "Default",
    }
    local keys = BiSGearCheck:GetCharacterKeys()
    -- Should include TestChar and Alt (both 70+), exclude LowLevel (30)
    assert_equal(2, #keys)
end

function T.test_get_character_keys_ignores_ignored()
    setupCharState()
    BiSGearCheckSaved.characters["Ignored-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        wishlists = { Default = {} }, activeWishlist = "Default",
    }
    BiSGearCheckSaved.ignoredCharacters["Ignored-TestRealm"] = true
    local keys = BiSGearCheck:GetCharacterKeys()
    for _, k in ipairs(keys) do
        assert_true(k ~= "Ignored-TestRealm", "ignored char should not appear")
    end
end

function T.test_get_character_keys_hides_inspected()
    setupCharState()
    BiSGearCheckSaved.characters["Inspected-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        wishlists = { Default = {} }, activeWishlist = "Default",
        inspected = true,
    }
    BiSGearCheckSaved.showInspectedInDropdown = false
    local keys = BiSGearCheck:GetCharacterKeys()
    for _, k in ipairs(keys) do
        assert_true(k ~= "Inspected-TestRealm", "inspected char should be hidden")
    end
end

function T.test_get_character_keys_shows_inspected()
    setupCharState()
    BiSGearCheckSaved.characters["Inspected-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        wishlists = { Default = {} }, activeWishlist = "Default",
        inspected = true,
    }
    BiSGearCheckSaved.showInspectedInDropdown = true
    local keys = BiSGearCheck:GetCharacterKeys()
    local found = false
    for _, k in ipairs(keys) do
        if k == "Inspected-TestRealm" then found = true end
    end
    assert_true(found, "inspected char should be visible when setting is on")
end

function T.test_get_character_keys_sorted()
    setupCharState()
    BiSGearCheckSaved.characters["Zebra-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        wishlists = { Default = {} }, activeWishlist = "Default",
    }
    BiSGearCheckSaved.characters["Alpha-TestRealm"] = {
        class = "ROGUE", faction = "Alliance", level = 70,
        wishlists = { Default = {} }, activeWishlist = "Default",
    }
    local keys = BiSGearCheck:GetCharacterKeys()
    for i = 2, #keys do
        assert_true(keys[i - 1] <= keys[i], "should be sorted")
    end
end

-- ============================================================
-- TESTS: GetAllCharacterKeys (unfiltered)
-- ============================================================

function T.test_get_all_character_keys_includes_everything()
    setupCharState()
    BiSGearCheckSaved.characters["LowLevel-TestRealm"] = {
        class = "ROGUE", faction = "Alliance", level = 1,
        wishlists = { Default = {} },
    }
    BiSGearCheckSaved.ignoredCharacters["LowLevel-TestRealm"] = true
    local keys = BiSGearCheck:GetAllCharacterKeys()
    assert_equal(2, #keys) -- TestChar + LowLevel
end

-- ============================================================
-- TESTS: Ignore / Unignore
-- ============================================================

function T.test_ignore_character()
    setupCharState()
    BiSGearCheck:IgnoreCharacter("SomeChar-Realm")
    assert_true(BiSGearCheck:IsCharacterIgnored("SomeChar-Realm"))
end

function T.test_unignore_character()
    setupCharState()
    BiSGearCheck:IgnoreCharacter("SomeChar-Realm")
    BiSGearCheck:UnignoreCharacter("SomeChar-Realm")
    assert_false(BiSGearCheck:IsCharacterIgnored("SomeChar-Realm"))
end

function T.test_is_character_ignored_empty()
    setupCharState()
    assert_false(BiSGearCheck:IsCharacterIgnored("Nobody-Realm"))
end

function T.test_ignore_lazy_init()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheck:IgnoreCharacter("Test-Realm")
    assert_true(BiSGearCheck:IsCharacterIgnored("Test-Realm"))
end

-- ============================================================
-- TESTS: IsInspectedCharacter
-- ============================================================

function T.test_is_inspected_true()
    setupCharState()
    BiSGearCheckSaved.characters["Other-Realm"] = { inspected = true }
    assert_true(BiSGearCheck:IsInspectedCharacter("Other-Realm"))
end

function T.test_is_inspected_false()
    setupCharState()
    assert_false(BiSGearCheck:IsInspectedCharacter("TestChar-TestRealm"))
end

-- ============================================================
-- TESTS: RemoveInspectedCharacter
-- ============================================================

function T.test_remove_inspected_character()
    setupCharState()
    BiSGearCheckSaved.characters["Other-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        inspected = true,
        wishlists = { Default = {} }, activeWishlist = "Default",
    }
    BiSGearCheck:RemoveInspectedCharacter("Other-TestRealm")
    assert_nil(BiSGearCheckSaved.characters["Other-TestRealm"])
end

function T.test_remove_inspected_never_deletes_self()
    setupCharState()
    BiSGearCheck:RemoveInspectedCharacter("TestChar-TestRealm")
    assert_not_nil(BiSGearCheckSaved.characters["TestChar-TestRealm"])
end

function T.test_remove_inspected_switches_view()
    setupCharState()
    BiSGearCheckSaved.characters["Other-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        inspected = true,
        wishlists = { Default = {} }, activeWishlist = "Default",
    }
    BiSGearCheck.viewingCharKey = "Other-TestRealm"
    BiSGearCheck:RemoveInspectedCharacter("Other-TestRealm")
    assert_equal("TestChar-TestRealm", BiSGearCheck.viewingCharKey)
end

-- ============================================================
-- TESTS: Viewing Context
-- ============================================================

function T.test_get_viewing_char_key_default()
    setupCharState()
    BiSGearCheck.viewingCharKey = nil
    assert_equal("TestChar-TestRealm", BiSGearCheck:GetViewingCharKey())
end

function T.test_get_viewing_class_own()
    setupCharState()
    assert_equal("WARRIOR", BiSGearCheck:GetViewingClass())
end

function T.test_get_viewing_class_other()
    setupCharState()
    BiSGearCheckSaved.characters["Other-TestRealm"] = {
        class = "MAGE", faction = "Horde", level = 70,
        wishlists = { Default = {} }, activeWishlist = "Default",
    }
    BiSGearCheck.viewingCharKey = "Other-TestRealm"
    assert_equal("MAGE", BiSGearCheck:GetViewingClass())
end

function T.test_get_viewing_faction_other()
    setupCharState()
    BiSGearCheckSaved.characters["Other-TestRealm"] = {
        class = "MAGE", faction = "Horde", level = 70,
        wishlists = { Default = {} }, activeWishlist = "Default",
    }
    BiSGearCheck.viewingCharKey = "Other-TestRealm"
    assert_equal("Horde", BiSGearCheck:GetViewingFaction())
end

function T.test_is_viewing_own_character()
    setupCharState()
    assert_true(BiSGearCheck:IsViewingOwnCharacter())
    BiSGearCheck.viewingCharKey = "Other-TestRealm"
    assert_false(BiSGearCheck:IsViewingOwnCharacter())
end

-- ============================================================
-- TESTS: SetViewingCharacter
-- ============================================================

function T.test_set_viewing_character_self()
    setupCharState()
    BiSGearCheck.viewingCharKey = "Other-TestRealm"
    BiSGearCheck:SetViewingCharacter("TestChar-TestRealm")
    assert_equal("TestChar-TestRealm", BiSGearCheck.viewingCharKey)
    assert_equal("WarriorFury", BiSGearCheck.selectedSpec)
end

function T.test_set_viewing_character_other()
    setupCharState()
    BiSGearCheckSaved.characters["Other-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        wishlists = { Default = {}, Raid = {} },
        activeWishlist = "Raid",
        selectedSpec = "MageFrost",
    }
    BiSGearCheck:SetViewingCharacter("Other-TestRealm")
    assert_equal("Other-TestRealm", BiSGearCheck.viewingCharKey)
    assert_equal("MageFrost", BiSGearCheck.selectedSpec)
    assert_equal("Raid", BiSGearCheck.activeWishlist)
end

function T.test_set_viewing_character_unknown_spec()
    setupCharState()
    BiSGearCheckSaved.characters["Other-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        wishlists = { Default = {} },
        activeWishlist = "Default",
    }
    BiSGearCheck:SetViewingCharacter("Other-TestRealm")
    -- Should pick first spec for MAGE
    assert_equal("MageArcane", BiSGearCheck.selectedSpec)
end

function T.test_set_viewing_character_nonexistent()
    setupCharState()
    BiSGearCheck:SetViewingCharacter("Nobody-Realm")
    -- Should not change
    assert_equal("TestChar-TestRealm", BiSGearCheck.viewingCharKey)
end

return T
