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
