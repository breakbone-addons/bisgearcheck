-- Tests for Settings logic
-- Settings initialization, source settings, EP settings, tooltip settings

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function setupSettingsState()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheckChar = {}
    BiSGearCheck.playerKey = "TestChar-TestRealm"
    BiSGearCheck.viewingCharKey = "TestChar-TestRealm"
    BiSGearCheck.phaseFilter = 1
end

-- ============================================================
-- TESTS: Source Settings Initialization
-- ============================================================

function T.test_all_sources_have_settings_after_ensure()
    setupSettingsState()
    BiSGearCheck:EnsureSourceSettings()
    for _, src in ipairs(BiSGearCheck.DataSources) do
        local s = BiSGearCheckSaved.sourceSettings[src.key]
        assert_not_nil(s, "missing settings for " .. src.key)
        assert_true(s.addon ~= nil, "addon field missing for " .. src.key)
        assert_true(s.tooltip ~= nil, "tooltip field missing for " .. src.key)
    end
end

function T.test_source_toggle_persists()
    setupSettingsState()
    BiSGearCheck:EnsureSourceSettings()
    BiSGearCheckSaved.sourceSettings.wowtbcgg.addon = false
    assert_false(BiSGearCheck:IsSourceEnabled("wowtbcgg"))
    BiSGearCheckSaved.sourceSettings.wowtbcgg.addon = true
    assert_true(BiSGearCheck:IsSourceEnabled("wowtbcgg"))
end

function T.test_tooltip_source_toggle()
    setupSettingsState()
    BiSGearCheck:EnsureSourceSettings()
    BiSGearCheckSaved.sourceSettings.wowhead.tooltip = false
    assert_false(BiSGearCheck:IsTooltipSourceEnabled("wowhead"))
    local sources = BiSGearCheck:GetTooltipDataSources()
    for _, src in ipairs(sources) do
        assert_true(src.key ~= "wowhead", "disabled tooltip source should not appear")
    end
end

-- ============================================================
-- TESTS: EP Settings
-- ============================================================

function T.test_ep_settings_defaults()
    BiSGearCheckSaved = nil
    BiSGearCheck:EnsureEPSettings()
    local ep = BiSGearCheckSaved.ep
    assert_equal(true, ep.showInTooltip)
    assert_equal(true, ep.showInCompare)
    assert_equal(false, ep.hasDraenei)
    assert_equal(false, ep.hasTotemOfWrath)
    assert_equal(false, ep.hasImpFaerieFire)
end

function T.test_ep_settings_preserve()
    BiSGearCheckSaved = { characters = {}, ep = { hasDraenei = true } }
    BiSGearCheck:EnsureEPSettings()
    assert_equal(true, BiSGearCheckSaved.ep.hasDraenei)
end

-- ============================================================
-- TESTS: Tooltip Settings
-- ============================================================

function T.test_tooltip_settings_defaults()
    BiSGearCheckSaved = nil
    BiSGearCheck:EnsureTooltipSettings()
    assert_equal(true, BiSGearCheckSaved.tooltip.showBiS)
    assert_equal(false, BiSGearCheckSaved.tooltip.showOnlyMyClass)
end

function T.test_tooltip_settings_preserve()
    BiSGearCheckSaved = { characters = {}, tooltip = { showBiS = false } }
    BiSGearCheck:EnsureTooltipSettings()
    assert_equal(false, BiSGearCheckSaved.tooltip.showBiS)
end

-- ============================================================
-- TESTS: UnloadDisabledSources
-- ============================================================

function T.test_unload_disabled_sources()
    setupSettingsState()
    BiSGearCheck:EnsureSourceSettings()
    -- Disable wowtbcgg for both addon and tooltip
    BiSGearCheckSaved.sourceSettings.wowtbcgg.addon = false
    BiSGearCheckSaved.sourceSettings.wowtbcgg.tooltip = false
    -- Set up a global that should be unloaded
    _G["BiSGearCheckDB_WowTBCgg"] = { some = "data" }

    BiSGearCheck:UnloadDisabledSources()
    assert_nil(_G["BiSGearCheckDB_WowTBCgg"], "fully disabled source should be unloaded")
end

function T.test_unload_keeps_partially_enabled()
    setupSettingsState()
    BiSGearCheck:EnsureSourceSettings()
    -- Disable addon but keep tooltip
    BiSGearCheckSaved.sourceSettings.wowtbcgg.addon = false
    BiSGearCheckSaved.sourceSettings.wowtbcgg.tooltip = true
    _G["BiSGearCheckDB_WowTBCgg"] = { some = "data" }

    BiSGearCheck:UnloadDisabledSources()
    assert_not_nil(_G["BiSGearCheckDB_WowTBCgg"], "partially enabled source should stay")
    _G["BiSGearCheckDB_WowTBCgg"] = nil
end

-- ============================================================
-- TESTS: Migration from old format
-- ============================================================

function T.test_migration_old_enabled_sources()
    BiSGearCheckSaved = {
        characters = {},
        enabledSources = { wowtbcgg = true, bistooltip = false, atlasloot = true },
    }
    BiSGearCheck:EnsureSourceSettings()
    assert_equal(true, BiSGearCheckSaved.sourceSettings.wowtbcgg.addon)
    assert_equal(false, BiSGearCheckSaved.sourceSettings.bistooltip.addon)
    assert_equal(true, BiSGearCheckSaved.sourceSettings.atlasloot.addon)
end

function T.test_migration_old_tooltip_sources()
    BiSGearCheckSaved = {
        characters = {},
        enabledSources = { wowtbcgg = true },
        tooltipSources = { wowtbcgg = false },
    }
    BiSGearCheck:EnsureSourceSettings()
    assert_equal(true, BiSGearCheckSaved.sourceSettings.wowtbcgg.addon)
    assert_equal(false, BiSGearCheckSaved.sourceSettings.wowtbcgg.tooltip)
end

-- ============================================================
-- TESTS: Character filter settings
-- ============================================================

function T.test_min_char_level_default()
    BiSGearCheckSaved = nil
    BiSGearCheckChar = nil
    BiSGearCheck:MigrateSavedVars()
    assert_equal(70, BiSGearCheckSaved.minCharLevel)
end

function T.test_ignored_characters_default()
    BiSGearCheckSaved = nil
    BiSGearCheckChar = nil
    BiSGearCheck:MigrateSavedVars()
    assert_not_nil(BiSGearCheckSaved.ignoredCharacters)
end

return T
