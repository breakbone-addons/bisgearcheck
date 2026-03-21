-- BISGearCheck Tooltip.lua
-- Injects BiS ranking info into item tooltips using Data.lua

BISGearCheck = BISGearCheck or {}

-- Reverse lookup: itemID -> { { specKey, slotName, rank }, ... }
BISGearCheck.TooltipIndex = {}

-- Build the reverse index from all data sources
function BISGearCheck:BuildTooltipIndex()
    self.TooltipIndex = {}

    for _, src in ipairs(self.DataSources) do
        local db = _G[src.db]
        if db then
            for specKey, specData in pairs(db) do
                if specData.slots then
                    for slotName, items in pairs(specData.slots) do
                        for rank, itemID in ipairs(items) do
                            local id = tostring(itemID)
                            if not self.TooltipIndex[id] then
                                self.TooltipIndex[id] = {}
                            end
                            table.insert(self.TooltipIndex[id], {
                                specKey = specKey,
                                class = specData.class,
                                spec = specData.spec,
                                slot = slotName,
                                rank = rank,
                                source = src.key,
                                sourceLabel = src.label,
                            })
                        end
                    end
                end
            end
        end
    end
end

-- Settings helpers
function BISGearCheck:GetTooltipSetting(key)
    if BISGearCheckSaved and BISGearCheckSaved.tooltip then
        return BISGearCheckSaved.tooltip[key]
    end
    return nil
end

function BISGearCheck:SetTooltipSetting(key, value)
    if not BISGearCheckSaved then BISGearCheckSaved = { wishlist = {} } end
    if not BISGearCheckSaved.tooltip then
        BISGearCheckSaved.tooltip = {}
    end
    BISGearCheckSaved.tooltip[key] = value
end

function BISGearCheck:EnsureTooltipSettings()
    if not BISGearCheckSaved then BISGearCheckSaved = { wishlist = {} } end
    if not BISGearCheckSaved.tooltip then
        BISGearCheckSaved.tooltip = {}
    end
    local t = BISGearCheckSaved.tooltip
    if t.showBiS == nil then t.showBiS = true end
    if t.showOnlyMyClass == nil then t.showOnlyMyClass = false end
    if t.dataSource == nil then t.dataSource = "all" end -- "all", "wowtbcgg", "atlasloot"
end

-- Render BiS info into a tooltip
function BISGearCheck:OnTooltipSetItem(tooltip)
    if not tooltip or tooltip:IsForbidden() then return end

    self:EnsureTooltipSettings()
    if not BISGearCheckSaved.tooltip.showBiS then return end

    local _, link = tooltip:GetItem()
    if not link then return end

    local itemID = link:match("item:(%d+)")
    if not itemID or not self.TooltipIndex[itemID] then return end

    local entries = self.TooltipIndex[itemID]
    local _, playerClass = UnitClass("player")
    local filterClass = BISGearCheckSaved.tooltip.showOnlyMyClass
    local sourceFilter = BISGearCheckSaved.tooltip.dataSource or "all"

    local headerShown = false

    for _, entry in ipairs(entries) do
        local show = true

        -- Class filter
        if filterClass and entry.class ~= playerClass then
            show = false
        end

        -- Source filter
        if sourceFilter ~= "all" and entry.source ~= sourceFilter then
            show = false
        end

        if show then
            if not headerShown then
                tooltip:AddLine(" ")
                tooltip:AddDoubleLine(
                    "BiS Gear Check",
                    "Rank",
                    1.0, 0.82, 0.0,
                    0, 1, 0.82
                )
                headerShown = true
            end

            local classColor = RAID_CLASS_COLORS[entry.class]
            if classColor then
                tooltip:AddDoubleLine(
                    entry.spec,
                    entry.rank,
                    classColor.r, classColor.g, classColor.b,
                    classColor.r, classColor.g, classColor.b
                )
            end
        end
    end

    if headerShown then
        tooltip:Show()
    end
end

-- Hook tooltips
function BISGearCheck:InstallTooltipHooks()
    if self.tooltipHooked then return end
    self.tooltipHooked = true

    local tooltips = {
        "GameTooltip",
        "ItemRefTooltip",
        "ShoppingTooltip1",
        "ShoppingTooltip2",
    }

    for _, name in ipairs(tooltips) do
        local tt = _G[name]
        if tt and tt.HookScript then
            tt:HookScript("OnTooltipSetItem", function(self)
                pcall(function()
                    BISGearCheck:OnTooltipSetItem(self)
                end)
            end)
        end
    end
end

-- ============================================================
-- CONFLICT DETECTION
-- ============================================================

-- Conflicting addons that also inject BiS data into tooltips
local CONFLICTING_ADDONS = {
    {
        name = "AtlasBIStooltips",
        label = "AtlasBIS Tooltips",
    },
}

-- Static popup dialog definition
StaticPopupDialogs["BISGEARCHECK_TOOLTIP_CONFLICT"] = {
    text = "BiS Gear Check has detected that |cff00ccff%s|r is also adding BiS rankings to item tooltips.\n\nWhich would you like to use?",
    button1 = "BiS Gear Check",
    button2 = "Keep Both",
    button3 = "%s",
    OnAccept = function()
        -- Use BiS Gear Check only — disable the conflicting addon's tooltips
        BISGearCheck:EnsureTooltipSettings()
        BISGearCheckSaved.tooltip.showBiS = true
        BISGearCheckSaved.tooltip.conflictResolved = BISGearCheck._conflictAddon
        BISGearCheckSaved.tooltip.conflictChoice = "bisgearcheck"
        -- Disable the other addon's tooltip output
        BISGearCheck:DisableConflictingTooltips()
        BISGearCheck:InstallTooltipHooks()
    end,
    OnCancel = function()
        -- Keep both
        BISGearCheck:EnsureTooltipSettings()
        BISGearCheckSaved.tooltip.conflictResolved = BISGearCheck._conflictAddon
        BISGearCheckSaved.tooltip.conflictChoice = "both"
        BISGearCheck:InstallTooltipHooks()
    end,
    OnAlt = function()
        -- Use the other addon only — disable BiS Gear Check tooltips
        BISGearCheck:EnsureTooltipSettings()
        BISGearCheckSaved.tooltip.showBiS = false
        BISGearCheckSaved.tooltip.conflictResolved = BISGearCheck._conflictAddon
        BISGearCheckSaved.tooltip.conflictChoice = "other"
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    preferredIndex = 3,
}

function BISGearCheck:CheckTooltipConflict()
    for _, conflict in ipairs(CONFLICTING_ADDONS) do
        local loaded = IsAddOnLoaded(conflict.name)
        if loaded then
            -- Check if we already resolved this conflict
            local resolved = BISGearCheckSaved and BISGearCheckSaved.tooltip
                and BISGearCheckSaved.tooltip.conflictResolved == conflict.name

            if resolved then
                -- Apply the previous choice silently
                local choice = BISGearCheckSaved.tooltip.conflictChoice
                if choice == "bisgearcheck" then
                    self:DisableConflictingTooltips()
                    self:InstallTooltipHooks()
                elseif choice == "both" then
                    self:InstallTooltipHooks()
                elseif choice == "other" then
                    -- Don't install our hooks
                end
            else
                -- Show the dialog
                self._conflictAddon = conflict.name
                -- Set button3 text dynamically
                StaticPopupDialogs["BISGEARCHECK_TOOLTIP_CONFLICT"].button3 = conflict.label
                StaticPopupDialogs["BISGEARCHECK_TOOLTIP_CONFLICT"].text =
                    "BiS Gear Check has detected that |cff00ccff" .. conflict.label ..
                    "|r is also adding BiS rankings to item tooltips.\n\nWhich would you like to use?"
                StaticPopup_Show("BISGEARCHECK_TOOLTIP_CONFLICT")
            end
            return
        end
    end

    -- No conflict — just install hooks
    self:InstallTooltipHooks()
end

-- Disable the conflicting addon's tooltip injection
function BISGearCheck:DisableConflictingTooltips()
    -- AtlasBIStooltips uses slcDB.showBiS to control its tooltip output
    if _G.slcDB then
        _G.slcDB.showBiS = 0
    end
end
