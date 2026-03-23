#!/usr/bin/env python3
"""
Fetch TBC BiS data from BiS-Tooltip addon (boegi1's backport) and WoWSims,
then generate Lua data files for BiSGearCheck addon.

Sources:
  - BiS-Tooltip: https://github.com/boegi1/BiS-Tooltip_335a_backport_TBC
    Contains ranked BiS lists for all 9 classes, all specs, all 6 phases
  - WoWSims TBC: https://github.com/wowsims/tbc
    Contains P1/P2 single-item presets for most specs

Output: One Lua file per phase (Data_PreRaid.lua, Data_Phase2.lua, etc.)
"""

import re
import urllib.request
import sys
import os

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #

BIS_TOOLTIP_URL = (
    "https://raw.githubusercontent.com/boegi1/"
    "BiS-Tooltip_335a_backport_TBC/main/Bistooltip_wowtbc_bislists.lua"
)

# WoWSims preset URLs: (spec_key, url)
WOWSIMS_PRESETS = [
    ("DruidBalance", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/druid/balance/presets.go"),
    ("DruidFeralDPS", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/druid/feral/presets.go"),
    ("DruidFeralTank", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/druid/tank/presets.go"),
    ("HunterBM", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/hunter/presets.go"),
    ("MageFire", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/mage/presets.go"),
    ("PaladinRetribution", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/paladin/retribution/presets.go"),
    ("PaladinProtection", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/paladin/protection/presets.go"),
    ("PriestShadow", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/priest/shadow/presets.go"),
    ("RogueCombat", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/rogue/presets.go"),
    ("ShamanElemental", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/shaman/elemental/presets.go"),
    ("ShamanEnhancement", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/shaman/enhancement/presets.go"),
    ("WarlockDestruction", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/warlock/presets.go"),
    ("WarriorFury", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/warrior/dps/presets.go"),
    ("WarriorProtection", "https://raw.githubusercontent.com/wowsims/tbc/master/sim/warrior/protection/presets.go"),
]

# BiS-Tooltip phase keys -> our phase names
PHASE_MAP = {
    "PreRaid": "PreRaid",
    "T4": "Phase1",   # Kara/Gruul/Mag = Phase 1 (skip, we already have this)
    "T5": "Phase2",   # SSC/TK = Phase 2
    "T6": "Phase3",   # Hyjal/BT = Phase 3
    "ZA": "Phase4",   # Zul'Aman = Phase 4
    "SWP": "Phase5",  # Sunwell = Phase 5
}

# BiS-Tooltip slot_name values -> our slot names
SLOT_NAME_MAP = {
    # Standard names
    "Head": "Head",
    "Shoulders": "Shoulders",
    "Shoulder": "Shoulders",
    "Back": "Back",
    "Cloak": "Back",
    "Chest": "Chest",
    "Wrists": "Wrist",
    "Wrist": "Wrist",
    "Bracer": "Wrist",
    "Hands": "Hands",
    "Gloves": "Hands",
    "Waist": "Waist",
    "Belt": "Waist",
    "Legs": "Legs",
    "Feet": "Feet",
    "Boots": "Feet",
    "Neck": "Neck",
    "Rings": "Rings",
    "Ring": "Rings",
    "Finger": "Rings",
    "Trinkets": "Trinkets",
    "Trinket": "Trinkets",
    # Weapon slot variants
    "1HandedWeapons": "Main Hand",
    "MainHand": "Main Hand",
    "MainHandWeapons": "Main Hand",
    "MainHandAndTwoHandedWeapons": "Main Hand",
    "MainAndTwohanded": "Main Hand",
    "MainAndTwohandedWeapons": "Main Hand",
    "1Handed": "Main Hand",
    "DwArmsMh": "Main Hand",
    "2HandedWeapons": "Twohand",
    "TwoHanded": "Twohand",
    "TwoHandWeapons": "Twohand",
    "2HandedWeapon": "Twohand",
    "WeaponsAndOffhands": "Main Hand",
    "Weapons": "Main Hand",
    # Offhand variants
    "Offhands": "Offhand",
    "Offhand": "Offhand",
    "OffHand": "Offhand",
    "OffHands": "Offhand",
    "OffhandsAndShields": "Offhand",
    "Shields": "Offhand",
    "ShieldsOffHands": "Offhand",
    "OffHandWeapons": "Offhand",
    # Ranged variants
    "Idols": "Ranged",
    "Totems": "Ranged",
    "Librams": "Ranged",
    "Wands": "Ranged",
    "Wand": "Ranged",
    "Ranged": "Ranged",
    "RangedWeapon": "Ranged",
    "GunsAndBows": "Ranged",
    # Skip these (ammo/special trinket categories)
    "Quivers": None,
    "AmmoPouches": None,
    "Arrows": None,
    "Bullets": None,
    "Jewelry": None,
    "MitigationTrinkets": "Trinkets",
    "StaminaTrinkets": "Trinkets",
    "ThreatTrinkets": "Trinkets",
    "MitigationRings": "Rings",
    "ThreatRings": "Rings",
    "DefensiveRings": "Rings",
    "SpellpowerRings": "Rings",
    "ThreatGenerationCloaks": "Back",
}

# BiS-Tooltip class/spec keys -> our spec keys
SPEC_KEY_MAP = {
    ("Druid", "Balance"): "DruidBalance",
    ("Druid", "FeralDps"): "DruidFeralDPS",
    ("Druid", "FeralTank"): "DruidFeralTank",
    ("Druid", "Restoration"): "DruidRestoration",
    ("Hunter", "BeastMastery"): "HunterBM",
    ("Hunter", "Marksmanship"): "HunterMM",
    ("Hunter", "Survival"): "HunterSV",
    ("Mage", "Arcane"): "MageArcane",
    ("Mage", "Fire"): "MageFire",
    ("Mage", "Frost"): "MageFrost",
    ("Paladin", "Holy"): "PaladinHoly",
    ("Paladin", "Protection"): "PaladinProtection",
    ("Paladin", "Retribution"): "PaladinRetribution",
    ("Priest", "Holy"): "PriestHoly",
    ("Priest", "Shadow"): "PriestShadow",
    ("Rogue", "DPS"): "RogueCombat",       # BiS-Tooltip has "DPS" for rogue
    ("Rogue", "Assassination"): "RogueAssassination",
    ("Rogue", "Combat"): "RogueCombat",
    ("Rogue", "Subtlety"): "RogueSubtlety",
    ("Shaman", "Elemental"): "ShamanElemental",
    ("Shaman", "Enhancement"): "ShamanEnhancement",
    ("Shaman", "Restoration"): "ShamanRestoration",
    ("Warlock", "Affliction"): "WarlockAffliction",
    ("Warlock", "Demonology"): "WarlockDemonology",
    ("Warlock", "Destruction"): "WarlockDestruction",
    ("Warrior", "Arms"): "WarriorArms",
    ("Warrior", "Fury"): "WarriorFury",
    ("Warrior", "DPS"): "WarriorFury",      # BiS-Tooltip has "DPS" for warrior
    ("Warrior", "Protection"): "WarriorProtection",
}

# Our spec key -> (class token, spec label) for Lua output
SPEC_INFO = {
    "DruidBalance":       ("DRUID", "Balance"),
    "DruidFeralDPS":      ("DRUID", "Feral DPS"),
    "DruidFeralTank":     ("DRUID", "Feral Tank"),
    "DruidRestoration":   ("DRUID", "Restoration"),
    "HunterBM":           ("HUNTER", "Beast Mastery"),
    "HunterMM":           ("HUNTER", "Marksmanship"),
    "HunterSV":           ("HUNTER", "Survival"),
    "MageArcane":         ("MAGE", "Arcane"),
    "MageFire":           ("MAGE", "Fire"),
    "MageFrost":          ("MAGE", "Frost"),
    "PaladinHoly":        ("PALADIN", "Holy"),
    "PaladinProtection":  ("PALADIN", "Protection"),
    "PaladinRetribution": ("PALADIN", "Retribution"),
    "PriestHoly":         ("PRIEST", "Holy"),
    "PriestShadow":       ("PRIEST", "Shadow"),
    "RogueAssassination": ("ROGUE", "Assassination"),
    "RogueCombat":        ("ROGUE", "Combat"),
    "RogueSubtlety":      ("ROGUE", "Subtlety"),
    "ShamanElemental":    ("SHAMAN", "Elemental"),
    "ShamanEnhancement":  ("SHAMAN", "Enhancement"),
    "ShamanRestoration":  ("SHAMAN", "Restoration"),
    "WarlockAffliction":  ("WARLOCK", "Affliction"),
    "WarlockDemonology":  ("WARLOCK", "Demonology"),
    "WarlockDestruction": ("WARLOCK", "Destruction"),
    "WarriorArms":        ("WARRIOR", "Arms"),
    "WarriorFury":        ("WARRIOR", "Fury"),
    "WarriorProtection":  ("WARRIOR", "Protection"),
}

# Canonical spec ordering (matches Data.lua)
SPEC_ORDER = [
    "DruidBalance", "DruidFeralDPS", "DruidFeralTank", "DruidRestoration",
    "HunterBM", "HunterMM", "HunterSV",
    "MageArcane", "MageFire", "MageFrost",
    "PaladinHoly", "PaladinProtection", "PaladinRetribution",
    "PriestHoly", "PriestShadow",
    "RogueAssassination", "RogueCombat", "RogueSubtlety",
    "ShamanElemental", "ShamanEnhancement", "ShamanRestoration",
    "WarlockAffliction", "WarlockDemonology", "WarlockDestruction",
    "WarriorArms", "WarriorFury", "WarriorProtection",
]

# Slot display order (matches Util.lua SlotOrder)
SLOT_ORDER = [
    "Head", "Neck", "Shoulders", "Back", "Chest", "Wrist", "Hands",
    "Waist", "Legs", "Feet", "Rings", "Trinkets",
    "Main Hand", "Offhand", "Twohand", "Ranged",
]


# --------------------------------------------------------------------------- #
# Fetching
# --------------------------------------------------------------------------- #

def fetch_url(url):
    """Fetch URL content, return string or None on error."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "BiSGearCheck-DataFetcher/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  WARNING: Failed to fetch {url}: {e}", file=sys.stderr)
        return None


# --------------------------------------------------------------------------- #
# BiS-Tooltip Parser
# --------------------------------------------------------------------------- #

def parse_bis_tooltip_lua(lua_text):
    """
    Parse the Bistooltip_wowtbc_bislists.lua file.
    Each line looks like:
      Bistooltip_wowtbc_bislists["Class"]["Spec"]["Phase"][N] = { ["slot_name"] = "...", ["enhs"] = { }, [1] = NNN, [2] = NNN, ... };

    Returns: dict[our_phase][our_spec_key][our_slot_name] = [item_id, ...]
    """
    result = {}

    # Regex to match data lines
    line_pattern = re.compile(
        r'Bistooltip_wowtbc_bislists\["(\w+)"\]\["(\w+)"\]\["(\w+)"\]\[\d+\]\s*=\s*\{(.+?)\};'
    )

    for line in lua_text.split("\n"):
        m = line_pattern.match(line.strip())
        if not m:
            continue

        cls = m.group(1)
        spec = m.group(2)
        phase_key = m.group(3)
        data_block = m.group(4)

        # Map phase
        our_phase = PHASE_MAP.get(phase_key)
        if not our_phase:
            continue

        # Map spec
        our_spec = SPEC_KEY_MAP.get((cls, spec))
        if not our_spec:
            continue

        # Extract slot_name
        slot_match = re.search(r'\["slot_name"\]\s*=\s*"([^"]+)"', data_block)
        if not slot_match:
            continue
        raw_slot = slot_match.group(1)
        if raw_slot not in SLOT_NAME_MAP:
            print(f"  WARNING: Unknown slot name '{raw_slot}' for {cls}/{spec}", file=sys.stderr)
            continue
        our_slot = SLOT_NAME_MAP[raw_slot]
        if our_slot is None:
            continue  # Skip ammo/quiver slots

        # Extract item IDs from numbered keys: [1] = 29093, [2] = 28762, etc.
        items = []
        for item_m in re.finditer(r'\[(\d+)\]\s*=\s*(-?\d+)', data_block):
            idx = int(item_m.group(1))
            item_id = int(item_m.group(2))
            if idx >= 1 and item_id > 0:
                items.append((idx, item_id))

        # Sort by index and extract just the IDs
        items.sort(key=lambda x: x[0])
        item_ids = [i[1] for i in items]

        if not item_ids:
            continue

        # Store
        if our_phase not in result:
            result[our_phase] = {}
        if our_spec not in result[our_phase]:
            result[our_phase][our_spec] = {}

        if our_slot in result[our_phase][our_spec]:
            # Merge, avoiding duplicates
            existing = result[our_phase][our_spec][our_slot]
            for item_id in item_ids:
                if item_id not in existing:
                    existing.append(item_id)
        else:
            result[our_phase][our_spec][our_slot] = item_ids

    return result


# --------------------------------------------------------------------------- #
# WoWSims Parser
# --------------------------------------------------------------------------- #

def parse_wowsims_presets(spec_key, go_text):
    """
    Parse WoWSims presets.go and extract item IDs per phase preset.
    Returns: dict[phase_name] -> [item_ids]
    """
    results = {}

    # Find preset variable assignments with JSON-like Items blocks
    preset_blocks = re.findall(
        r'(P\d+\w*Gear|Phase\d+\w*Gear|MutilateP\d+Gear)\s*(?:=|:=)\s*.*?Items\s*:\s*\{(.*?)\}\s*\}',
        go_text, re.DOTALL
    )

    for name, items_block in preset_blocks:
        item_ids = [int(m) for m in re.findall(r'"Id"\s*:\s*(\d+)', items_block)]
        if item_ids:
            phase = None
            if "P1" in name or "Phase1" in name:
                phase = "Phase1"
            elif "P2" in name or "Phase2" in name:
                phase = "Phase2"
            elif "P3" in name or "Phase3" in name:
                phase = "Phase3"
            elif "P4" in name or "Phase4" in name:
                phase = "Phase4"
            elif "P5" in name or "Phase5" in name:
                phase = "Phase5"
            if phase:
                results[phase] = item_ids

    return results


# --------------------------------------------------------------------------- #
# Lua Generation
# --------------------------------------------------------------------------- #

def generate_lua_file(phase_name, phase_data, db_name, description):
    """Generate a Lua file string for one phase."""
    lines = []
    lines.append(f"-- BiSGearCheck {phase_name}")
    lines.append(f"-- {description}")
    lines.append("-- Auto-generated by scripts/fetch_bis_data.py")
    lines.append(f"-- Source: BiS-Tooltip (boegi1) + WoWSims TBC presets")
    lines.append("")
    lines.append(f"{db_name} = {{}}")
    lines.append("")

    for spec_key in SPEC_ORDER:
        if spec_key not in phase_data:
            continue

        class_token, spec_label = SPEC_INFO[spec_key]
        slots = phase_data[spec_key]

        lines.append(f'{db_name}["{spec_key}"] = {{')
        lines.append(f'    class = "{class_token}",')
        lines.append(f'    spec = "{spec_label}",')
        lines.append("    slots = {")

        for slot_name in SLOT_ORDER:
            if slot_name not in slots:
                continue
            items = slots[slot_name]
            if not items:
                continue
            items_str = ", ".join(str(i) for i in items)
            lines.append(f'        ["{slot_name}"] = {{ {items_str} }},')

        lines.append("    }")
        lines.append("}")
        lines.append("")

    return "\n".join(lines)


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #

def main():
    output_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # 1. Fetch and parse BiS-Tooltip data
    print("Fetching BiS-Tooltip data...")
    bis_lua = fetch_url(BIS_TOOLTIP_URL)
    if not bis_lua:
        print("ERROR: Could not fetch BiS-Tooltip data", file=sys.stderr)
        sys.exit(1)

    print(f"  Got {len(bis_lua)} bytes, parsing...")
    all_phases = parse_bis_tooltip_lua(bis_lua)

    # Clone missing specs from similar specs
    # Rogue "DPS" -> Combat; also use for Assassination and Subtlety (armor is same)
    # Warrior "DPS" -> Fury; also use for Arms
    CLONE_MAP = {
        "RogueAssassination": "RogueCombat",
        "RogueSubtlety": "RogueCombat",
        "WarriorArms": "WarriorFury",
    }
    import copy
    for phase in all_phases:
        for target, source in CLONE_MAP.items():
            if target not in all_phases[phase] and source in all_phases[phase]:
                all_phases[phase][target] = copy.deepcopy(all_phases[phase][source])
                print(f"  Cloned {source} -> {target} for {phase}")

    for phase, specs in sorted(all_phases.items()):
        total_items = sum(
            len(items)
            for slots in specs.values()
            for items in slots.values()
        )
        print(f"  {phase}: {len(specs)} specs, {total_items} total item entries")

    # 2. Fetch WoWSims presets (supplementary data)
    print("\nFetching WoWSims presets...")
    wowsims_data = {}  # phase -> spec -> [item_ids]
    for spec_key, url in WOWSIMS_PRESETS:
        go_text = fetch_url(url)
        if not go_text:
            continue
        presets = parse_wowsims_presets(spec_key, go_text)
        for phase, items in presets.items():
            print(f"  {spec_key} {phase}: {len(items)} items")
            if phase not in wowsims_data:
                wowsims_data[phase] = {}
            wowsims_data[phase][spec_key] = items

    # 3. Merge WoWSims data into BiS-Tooltip data
    # WoWSims slot order in presets:
    # 0=Head, 1=Neck, 2=Shoulder, 3=Back, 4=Chest, 5=Wrist, 6=Hands,
    # 7=Waist, 8=Legs, 9=Feet, 10=Ring1, 11=Ring2, 12=Trinket1, 13=Trinket2,
    # 14=MainHand, 15=OffHand, 16=Ranged
    WOWSIMS_SLOT_ORDER = [
        "Head", "Neck", "Shoulders", "Back", "Chest", "Wrist", "Hands",
        "Waist", "Legs", "Feet", "Rings", "Rings", "Trinkets", "Trinkets",
        "Main Hand", "Offhand", "Ranged",
    ]

    for phase, specs in wowsims_data.items():
        if phase not in all_phases:
            all_phases[phase] = {}
        for spec_key, items in specs.items():
            if spec_key not in all_phases[phase]:
                all_phases[phase][spec_key] = {}
            spec_slots = all_phases[phase][spec_key]
            for i, item_id in enumerate(items):
                if i >= len(WOWSIMS_SLOT_ORDER):
                    break
                slot_name = WOWSIMS_SLOT_ORDER[i]
                if slot_name not in spec_slots:
                    spec_slots[slot_name] = []
                if item_id not in spec_slots[slot_name]:
                    spec_slots[slot_name].insert(0, item_id)

    # 4. Generate output files
    phase_configs = {
        "PreRaid": {
            "file": "Data_PreRaid.lua",
            "db": "BiSGearCheckDB_PreRaid",
            "desc": "Pre-Raid BiS data (dungeons, heroics, crafted, quest, reputation)",
        },
        # Skip Phase1 -- we already have it in Data.lua
        "Phase2": {
            "file": "Data_Phase2.lua",
            "db": "BiSGearCheckDB_Phase2",
            "desc": "Phase 2 BiS data (SSC/TK tier, badge gear)",
        },
        "Phase3": {
            "file": "Data_Phase3.lua",
            "db": "BiSGearCheckDB_Phase3",
            "desc": "Phase 3 BiS data (Hyjal/BT tier, badge gear)",
        },
        "Phase4": {
            "file": "Data_Phase4.lua",
            "db": "BiSGearCheckDB_Phase4",
            "desc": "Phase 4 BiS data (Zul'Aman, badge gear)",
        },
        "Phase5": {
            "file": "Data_Phase5.lua",
            "db": "BiSGearCheckDB_Phase5",
            "desc": "Phase 5 BiS data (Sunwell Plateau)",
        },
    }

    print("\nGenerating Lua files...")
    for phase_key, config in phase_configs.items():
        if phase_key not in all_phases:
            print(f"  SKIP {config['file']}: no data for {phase_key}")
            continue

        phase_data = all_phases[phase_key]
        lua_content = generate_lua_file(
            config["file"].replace(".lua", ""),
            phase_data,
            config["db"],
            config["desc"],
        )

        out_path = os.path.join(output_dir, config["file"])
        with open(out_path, "w") as f:
            f.write(lua_content)

        spec_count = len(phase_data)
        total_items = sum(
            len(items)
            for slots in phase_data.values()
            for items in slots.values()
        )
        print(f"  Wrote {config['file']}: {spec_count} specs, {total_items} items")

    # 5. Summary
    print("\nDone! Generated files:")
    for config in phase_configs.values():
        path = os.path.join(output_dir, config["file"])
        if os.path.exists(path):
            size = os.path.getsize(path)
            print(f"  {config['file']} ({size:,} bytes)")


if __name__ == "__main__":
    main()
