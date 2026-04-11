-- BiSGearCheck Test Runner
--
-- Thin wrapper around libBreakboneTest — shared test harness across Breakbone
-- addons. The full assertion library and discovery/execution logic lives in
-- tests/libBreakboneTest.lua (canonical source: WoWAddons/breakbone-shared/).
--
-- Usage: lua tests/run.lua [test_file_pattern]
-- Example: lua tests/run.lua test_raid_scan  (runs only test_raid_scan.lua)

dofile("tests/libBreakboneTest.lua")

BreakboneTest.run({
    addon_name = "BiSGearCheck",
    mock_file  = "tests/wow_mock.lua",
    test_glob  = "tests/test_*.lua",
    pattern    = arg[1],
})
