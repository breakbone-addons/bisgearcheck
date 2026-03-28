-- Tests for Core.lua
-- GetActiveDB, SetSpec, SetDataSource, OnPhaseChanged, OnZoneChanged, RefreshView

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function setupCoreState()
    BiSGearCheckSaved = {
        characters = {
            ["TestChar-TestRealm"] = {
                class = "WARRIOR", faction = "Alliance", level = 70,
                wishlists = { Default = {} }, activeWishlist = "Default",
                selectedSpec = "WarriorFury",
            }
        },
        minCharLevel = 70,
        ignoredCharacters = {},
        minimap = { hide = false },
    }
    BiSGearCheckChar = { selectedSpec = "WarriorFury", dataSource = "wowtbcgg" }
    BiSGearCheck.playerKey = "TestChar-TestRealm"
    BiSGearCheck.viewingCharKey = "TestChar-TestRealm"
    BiSGearCheck.playerFaction = "Alliance"
    BiSGearCheck.selectedSpec = "WarriorFury"
    BiSGearCheck.dataSource = "wowtbcgg"
    BiSGearCheck.phaseFilter = 1
    BiSGearCheck.pendingItems = {}
    BiSGearCheck.comparisonResults = {}
    BiSGearCheck.viewMode = "comparison"
    BiSGearCheck.currentZone = "Shattrath City"
    BiSGearCheck.wishlistAutoFilter = false
    BiSGearCheck.activeWishlist = "Default"
    BiSGearCheck.mainFrame = nil
    BiSGearCheck:EnsureSourceSettings()

    -- Track calls instead of doing real work
    BiSGearCheck._refreshCalled = false
    BiSGearCheck._renderResultsCalled = false
    BiSGearCheck._renderWishlistCalled = false
    BiSGearCheck._renderBisListCalled = false
    BiSGearCheck._comparisonRan = false

    BiSGearCheck.Refresh = function(self)
        self._refreshCalled = true
    end
    BiSGearCheck.RunComparison = function(self)
        self._comparisonRan = true
    end
    BiSGearCheck.RenderResults = function(self) self._renderResultsCalled = true end
    BiSGearCheck.RenderWishlist = function(self) self._renderWishlistCalled = true end
    BiSGearCheck.RenderBisList = function(self) self._renderBisListCalled = true end
    BiSGearCheck.GuessSpec = function() return "WarriorFury" end
    BiSGearCheck.BuildTooltipIndex = function() end
end

-- ============================================================
-- TESTS: GetActiveDB
-- ============================================================

function T.test_get_active_db_found()
    setupCoreState()
    _G["BiSGearCheckDB_WowTBCgg"] = { WarriorFury = { class = "WARRIOR", spec = "Fury", slots = {} } }
    local db = BiSGearCheck:GetActiveDB()
    assert_not_nil(db)
    assert_not_nil(db.WarriorFury)
    _G["BiSGearCheckDB_WowTBCgg"] = nil
end

function T.test_get_active_db_not_loaded()
    setupCoreState()
    _G["BiSGearCheckDB_WowTBCgg"] = nil
    local db = BiSGearCheck:GetActiveDB()
    assert_nil(db)
end

function T.test_get_active_db_unknown_source()
    setupCoreState()
    BiSGearCheck.dataSource = "nonexistent"
    local db = BiSGearCheck:GetActiveDB()
    assert_nil(db)
end

-- ============================================================
-- TESTS: SetSpec
-- ============================================================

function T.test_set_spec()
    setupCoreState()
    BiSGearCheck:SetSpec("WarriorArms")
    assert_equal("WarriorArms", BiSGearCheck.selectedSpec)
    assert_equal("WarriorArms", BiSGearCheckChar.selectedSpec)
    assert_true(BiSGearCheck._refreshCalled)
end

function T.test_set_spec_updates_char_data()
    setupCoreState()
    BiSGearCheck:SetSpec("WarriorProtection")
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    assert_equal("WarriorProtection", charData.selectedSpec)
end

function T.test_set_spec_other_char_no_chardata_update()
    setupCoreState()
    BiSGearCheck.viewingCharKey = "Other-Realm"
    BiSGearCheck:SetSpec("WarriorArms")
    local charData = BiSGearCheckSaved.characters["TestChar-TestRealm"]
    -- Should NOT update char data when viewing other character
    assert_equal("WarriorFury", charData.selectedSpec)
end

-- ============================================================
-- TESTS: SetDataSource
-- ============================================================

function T.test_set_data_source()
    setupCoreState()
    BiSGearCheck:SetDataSource("bistooltip")
    assert_equal("bistooltip", BiSGearCheck.dataSource)
    assert_equal("bistooltip", BiSGearCheckChar.dataSource)
    assert_true(BiSGearCheck._refreshCalled)
end

function T.test_set_data_source_spec_fallback()
    setupCoreState()
    -- New source has data but not for current spec
    _G["BiSGearCheckDB_Phase1"] = {
        WarriorArms = { class = "WARRIOR", spec = "Arms", slots = {} },
        -- No WarriorFury
    }
    BiSGearCheck.dataSource = "bistooltip"
    BiSGearCheck:SetDataSource("bistooltip")
    -- Should fall back to first available spec for WARRIOR
    assert_equal("WarriorArms", BiSGearCheck.selectedSpec)
    _G["BiSGearCheckDB_Phase1"] = nil
end

-- ============================================================
-- TESTS: OnPhaseChanged
-- ============================================================

function T.test_on_phase_changed_source_available()
    setupCoreState()
    BiSGearCheck.phaseFilter = 1
    -- Real Refresh for phase changes
    BiSGearCheck.Refresh = function(self) self._refreshCalled = true end
    BiSGearCheck:OnPhaseChanged()
    assert_equal("wowtbcgg", BiSGearCheck.dataSource, "should keep source when it has phase")
    assert_true(BiSGearCheck._refreshCalled)
end

function T.test_on_phase_changed_source_fallback()
    setupCoreState()
    -- Set phase that wowtbcgg doesn't have (only has phase 1)
    BiSGearCheck.phaseFilter = 5
    BiSGearCheck.Refresh = function(self) self._refreshCalled = true end
    BiSGearCheck:OnPhaseChanged()
    -- Should fall back to epscore (which has all phases)
    assert_equal("epscore", BiSGearCheck.dataSource)
end

-- ============================================================
-- TESTS: OnZoneChanged
-- ============================================================

function T.test_on_zone_changed_no_autofilter()
    setupCoreState()
    BiSGearCheck.wishlistAutoFilter = false
    MockWoW._currentZone = "Karazhan"
    BiSGearCheck:OnZoneChanged()
    assert_equal("Karazhan", BiSGearCheck.currentZone)
    -- wishlistZoneFilter should not be set when autofilter is off
end

function T.test_on_zone_changed_with_autofilter_known_zone()
    setupCoreState()
    BiSGearCheck.wishlistAutoFilter = true
    BiSGearCheck.viewMode = "wishlist"
    MockWoW._currentZone = "Karazhan"
    BiSGearCheck:OnZoneChanged()
    assert_equal("Karazhan", BiSGearCheck.currentZone)
    assert_equal("Karazhan", BiSGearCheck.wishlistZoneFilter)
end

function T.test_on_zone_changed_with_autofilter_unknown_zone()
    setupCoreState()
    BiSGearCheck.wishlistAutoFilter = true
    BiSGearCheck.viewMode = "wishlist"
    MockWoW._currentZone = "Some Random Place"
    BiSGearCheck:OnZoneChanged()
    assert_equal("Some Random Place", BiSGearCheck.currentZone)
    assert_nil(BiSGearCheck.wishlistZoneFilter)
end

function T.test_on_zone_changed_same_zone_no_op()
    setupCoreState()
    BiSGearCheck.currentZone = "Karazhan"
    BiSGearCheck.wishlistAutoFilter = true
    BiSGearCheck.viewMode = "wishlist"
    MockWoW._currentZone = "Karazhan"
    BiSGearCheck.wishlistZoneFilter = nil
    BiSGearCheck:OnZoneChanged()
    -- Same zone, should not update
    assert_nil(BiSGearCheck.wishlistZoneFilter)
end

-- ============================================================
-- TESTS: RefreshView
-- ============================================================

function T.test_refresh_view_comparison()
    setupCoreState()
    BiSGearCheck.mainFrame = setmetatable({}, { __index = { IsShown = function() return true end } })
    BiSGearCheck.viewMode = "comparison"
    BiSGearCheck:RefreshView()
    assert_true(BiSGearCheck._renderResultsCalled)
end

function T.test_refresh_view_wishlist()
    setupCoreState()
    BiSGearCheck.mainFrame = setmetatable({}, { __index = { IsShown = function() return true end } })
    BiSGearCheck.viewMode = "wishlist"
    BiSGearCheck:RefreshView()
    assert_true(BiSGearCheck._renderWishlistCalled)
end

function T.test_refresh_view_bislist()
    setupCoreState()
    BiSGearCheck.mainFrame = setmetatable({}, { __index = { IsShown = function() return true end } })
    BiSGearCheck.viewMode = "bislist"
    BiSGearCheck:RefreshView()
    assert_true(BiSGearCheck._renderBisListCalled)
end

function T.test_refresh_view_no_frame()
    setupCoreState()
    BiSGearCheck.mainFrame = nil
    -- Should not error
    BiSGearCheck:RefreshView()
end

return T
