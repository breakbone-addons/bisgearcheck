-- Tests for Wishlist.lua
-- CRUD operations, active wishlist, auto-filter

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function setupWishlistState()
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
    BiSGearCheck.activeWishlist = "Default"
    BiSGearCheck.selectedSpec = "WarriorFury"
    BiSGearCheck.dataSource = "wowtbcgg"
    BiSGearCheck.pendingItems = {}
    -- Stub RefreshView to prevent UI calls
    BiSGearCheck.RefreshView = function() end
    BiSGearCheck.mainFrame = nil
end

-- ============================================================
-- TESTS: CreateWishlist
-- ============================================================

function T.test_create_wishlist_success()
    setupWishlistState()
    local ok = BiSGearCheck:CreateWishlist("Raid")
    assert_true(ok)
    assert_equal("Raid", BiSGearCheck.activeWishlist)
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_not_nil(charData.wishlists["Raid"])
end

function T.test_create_wishlist_empty_name()
    setupWishlistState()
    assert_false(BiSGearCheck:CreateWishlist(""))
    assert_false(BiSGearCheck:CreateWishlist(nil))
end

function T.test_create_wishlist_duplicate()
    setupWishlistState()
    assert_false(BiSGearCheck:CreateWishlist("Default"))
end

-- ============================================================
-- TESTS: RenameWishlist
-- ============================================================

function T.test_rename_wishlist_success()
    setupWishlistState()
    local ok = BiSGearCheck:RenameWishlist("My List")
    assert_true(ok)
    assert_equal("My List", BiSGearCheck.activeWishlist)
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_nil(charData.wishlists["Default"])
    assert_not_nil(charData.wishlists["My List"])
end

function T.test_rename_wishlist_empty_name()
    setupWishlistState()
    assert_false(BiSGearCheck:RenameWishlist(""))
    assert_false(BiSGearCheck:RenameWishlist(nil))
end

function T.test_rename_wishlist_name_taken()
    setupWishlistState()
    BiSGearCheck:CreateWishlist("Other")
    BiSGearCheck.activeWishlist = "Default"
    assert_false(BiSGearCheck:RenameWishlist("Other"))
end

-- ============================================================
-- TESTS: DeleteWishlist
-- ============================================================

function T.test_delete_wishlist_success()
    setupWishlistState()
    BiSGearCheck:CreateWishlist("Raid")
    BiSGearCheck.activeWishlist = "Raid"
    local ok = BiSGearCheck:DeleteWishlist()
    assert_true(ok)
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_nil(charData.wishlists["Raid"])
    -- Should switch to remaining wishlist
    assert_not_nil(BiSGearCheck.activeWishlist)
end

function T.test_delete_last_wishlist_fails()
    setupWishlistState()
    assert_false(BiSGearCheck:DeleteWishlist())
    -- Default should still exist
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_not_nil(charData.wishlists["Default"])
end

-- ============================================================
-- TESTS: AddToWishlist / RemoveFromWishlist / IsOnWishlist
-- ============================================================

function T.test_add_to_wishlist()
    setupWishlistState()
    BiSGearCheck:AddToWishlist(28000, "Head", 1, "Karazhan", "Boss Drop")
    assert_true(BiSGearCheck:IsOnWishlist(28000))
    local wl = BiSGearCheck:GetActiveWishlistTable()
    assert_not_nil(wl[28000])
    assert_equal("Head", wl[28000].slotName)
    assert_equal(1, wl[28000].rank)
    assert_equal("WarriorFury", wl[28000].specKey)
end

function T.test_remove_from_wishlist()
    setupWishlistState()
    BiSGearCheck:AddToWishlist(28000, "Head", 1, "Karazhan", "Boss Drop")
    assert_true(BiSGearCheck:IsOnWishlist(28000))
    BiSGearCheck:RemoveFromWishlist(28000)
    assert_false(BiSGearCheck:IsOnWishlist(28000))
end

function T.test_is_on_wishlist_empty()
    setupWishlistState()
    assert_false(BiSGearCheck:IsOnWishlist(99999))
end

-- ============================================================
-- TESTS: GetWishlistNames
-- ============================================================

function T.test_get_wishlist_names_sorted()
    setupWishlistState()
    BiSGearCheck:CreateWishlist("Zebra")
    BiSGearCheck:CreateWishlist("Alpha")
    local names = BiSGearCheck:GetWishlistNames()
    assert_equal(3, #names)
    assert_equal("Alpha", names[1])
    assert_equal("Default", names[2])
    assert_equal("Zebra", names[3])
end

-- ============================================================
-- TESTS: SetActiveWishlist
-- ============================================================

function T.test_set_active_wishlist()
    setupWishlistState()
    BiSGearCheck:CreateWishlist("Raid")
    BiSGearCheck.activeWishlist = "Default" -- reset
    BiSGearCheck:SetActiveWishlist("Raid")
    assert_equal("Raid", BiSGearCheck.activeWishlist)
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_equal("Raid", charData.activeWishlist)
end

function T.test_set_active_wishlist_nonexistent()
    setupWishlistState()
    BiSGearCheck:SetActiveWishlist("DoesNotExist")
    assert_equal("Default", BiSGearCheck.activeWishlist, "should not change")
end

-- ============================================================
-- TESTS: SetWishlistAutoFilter
-- ============================================================

function T.test_auto_filter_enable_known_zone()
    setupWishlistState()
    BiSGearCheck.currentZone = "Karazhan"
    BiSGearCheck:SetWishlistAutoFilter(true)
    assert_true(BiSGearCheck.wishlistAutoFilter)
    assert_equal("Karazhan", BiSGearCheck.wishlistZoneFilter)
end

function T.test_auto_filter_enable_unknown_zone()
    setupWishlistState()
    BiSGearCheck.currentZone = "Some Random Place"
    BiSGearCheck:SetWishlistAutoFilter(true)
    assert_true(BiSGearCheck.wishlistAutoFilter)
    assert_nil(BiSGearCheck.wishlistZoneFilter)
end

function T.test_auto_filter_disable()
    setupWishlistState()
    BiSGearCheck:SetWishlistAutoFilter(false)
    assert_false(BiSGearCheck.wishlistAutoFilter)
end

-- ============================================================
-- TESTS: GetWishlistItems
-- ============================================================

function T.test_get_wishlist_items_sorted_by_slot()
    setupWishlistState()
    BiSGearCheckSources = {
        [100] = { source = "Karazhan", sourceType = "Boss" },
        [200] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetItemInfo(100, { name = "Boots", quality = 4, icon = "icon1" })
    MockWoW.SetItemInfo(200, { name = "Helm", quality = 4, icon = "icon2" })

    BiSGearCheck:AddToWishlist(100, "Feet", 2, "Karazhan", "Boss")
    BiSGearCheck:AddToWishlist(200, "Head", 1, "Karazhan", "Boss")

    local items = BiSGearCheck:GetWishlistItems()
    assert_equal(2, #items)
    -- Head comes before Feet in SlotOrder
    assert_equal("Head", items[1].slotName)
    assert_equal("Feet", items[2].slotName)
end

function T.test_get_wishlist_items_same_slot_sorted_by_rank()
    setupWishlistState()
    BiSGearCheckSources = {}
    MockWoW.SetItemInfo(100, { name = "Item A", quality = 4 })
    MockWoW.SetItemInfo(200, { name = "Item B", quality = 4 })

    BiSGearCheck:AddToWishlist(100, "Head", 3, "Karazhan", "Boss")
    BiSGearCheck:AddToWishlist(200, "Head", 1, "Karazhan", "Boss")

    local items = BiSGearCheck:GetWishlistItems()
    assert_equal(2, #items)
    assert_equal(200, items[1].id) -- rank 1 first
    assert_equal(100, items[2].id) -- rank 3 second
end

return T
