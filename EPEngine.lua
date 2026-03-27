-- BiSGearCheck EPEngine.lua
-- EP (Equivalence Points) gear scoring engine
-- Scores items using per-spec stat weights with hit cap awareness

BiSGearCheck = BiSGearCheck or {}

-- Ensure EP settings exist with defaults
function BiSGearCheck:EnsureEPSettings()
    if not BiSGearCheckSaved then BiSGearCheckSaved = { characters = {} } end
    if not BiSGearCheckSaved.ep then
        BiSGearCheckSaved.ep = {}
    end
    local ep = BiSGearCheckSaved.ep
    if ep.showInTooltip == nil then ep.showInTooltip = true end
    if ep.showInCompare == nil then ep.showInCompare = true end
    if ep.hasDraenei == nil then ep.hasDraenei = false end
    if ep.hasTotemOfWrath == nil then ep.hasTotemOfWrath = false end
    if ep.hasImpFaerieFire == nil then ep.hasImpFaerieFire = false end
end

-- Parse the compact weights format: {idx1,weight1,idx2,weight2,...}
-- into a lookup table: weights[statIndex] = weight
local function ParseWeights(compact)
    local result = {}
    if not compact then return result end
    local i = 1
    while i < #compact do
        local idx = compact[i]
        local w = compact[i + 1]
        if idx and w then
            result[idx] = w
        end
        i = i + 2
    end
    return result
end

-- Cache parsed weights per spec
local parsedWeightsCache = {}
local function GetParsedWeights(specKey)
    if parsedWeightsCache[specKey] then
        return parsedWeightsCache[specKey]
    end
    local specData = BiSGearCheckEPWeights and BiSGearCheckEPWeights[specKey]
    if not specData or not specData.weights then return nil end
    local parsed = ParseWeights(specData.weights)
    parsedWeightsCache[specKey] = parsed
    return parsed
end

-- Calculate the effective hit cap for a spec, accounting for talents and party buffs
function BiSGearCheck:GetEffectiveHitCap(specKey)
    local specData = BiSGearCheckEPWeights and BiSGearCheckEPWeights[specKey]
    if not specData then return 0, 0, 0 end

    local baseMiss = specData.baseMiss or 0
    local talentHit = specData.talentHit or 0
    local hitStatIndex = specData.hitStatIndex or 14
    local hitRatingPerPct = specData.hitRatingPerPct or 12.62

    -- Party buff reductions (from user settings)
    local partyHit = 0
    self:EnsureEPSettings()
    local epSettings = BiSGearCheckSaved.ep
    if epSettings then
        if epSettings.hasDraenei then partyHit = partyHit + 1 end
        if hitStatIndex == 14 then
            -- Spell hit buffs
            if epSettings.hasTotemOfWrath then partyHit = partyHit + 3 end
        else
            -- Melee hit buffs
            if epSettings.hasImpFaerieFire then partyHit = partyHit + 3 end
        end
    end

    local hitCap = baseMiss - talentHit - partyHit
    if hitCap < 0 then hitCap = 0 end

    local hitCapRating = hitCap * hitRatingPerPct
    return hitCap, hitCapRating, hitStatIndex
end

-- Score an item for a given spec
-- Returns: totalEP, breakdown (table of stat contributions)
function BiSGearCheck:ScoreItem(itemID, specKey)
    if not BiSGearCheckEPWeights or not BiSGearCheckItemStats then
        return 0, nil
    end

    local specData = BiSGearCheckEPWeights[specKey]
    if not specData then return 0, nil end

    local itemStats = BiSGearCheckItemStats[itemID]
    if not itemStats then return 0, nil end

    local weights = GetParsedWeights(specKey)
    if not weights then return 0, nil end

    local _, hitCapRating, hitStatIndex = self:GetEffectiveHitCap(specKey)

    local totalEP = 0
    local breakdown = {}

    for statIdx, amount in pairs(itemStats) do
        local weight = weights[statIdx]
        if weight and weight > 0 then
            local effectiveAmount = amount

            -- Hit cap awareness: if this is the hit stat, cap its contribution
            if statIdx == hitStatIndex and hitCapRating > 0 then
                -- We'd need the character's current total hit to do this precisely.
                -- For now, use the full weight but flag if over cap.
                -- TODO: integrate with character gear data for precise cap tracking
            end

            local ep = effectiveAmount * weight
            totalEP = totalEP + ep
            breakdown[statIdx] = { amount = amount, weight = weight, ep = ep }
        end
    end

    return totalEP, breakdown
end

-- Score an item and return a formatted string for tooltips
function BiSGearCheck:GetItemEPString(itemID, specKey)
    local ep = self:ScoreItem(itemID, specKey)
    if ep == 0 then return nil end
    return string.format("%.1f", ep)
end

-- Compare two items for a spec, returning the EP difference
-- positive = newItem is better, negative = currentItem is better
function BiSGearCheck:CompareItemEP(newItemID, currentItemID, specKey)
    local newEP = self:ScoreItem(newItemID, specKey)
    local currentEP = self:ScoreItem(currentItemID, specKey)
    return newEP - currentEP, newEP, currentEP
end

-- Get upgrade percentage for an item vs currently equipped
function BiSGearCheck:GetUpgradePercent(newItemID, currentItemID, specKey)
    local diff, newEP, currentEP = self:CompareItemEP(newItemID, currentItemID, specKey)
    if currentEP == 0 then
        if newEP > 0 then return 100 end
        return 0
    end
    return (diff / currentEP) * 100
end

-- ============================================================
-- EP-RANKED BIS LIST BUILDER
-- ============================================================
-- Builds BiSGearCheckDB_EPScore by collecting all known items per slot
-- from all loaded data sources, scoring them with EP, and ranking.

function BiSGearCheck:BuildEPRankedList()
    if not BiSGearCheckEPWeights or not BiSGearCheckItemStats then return end

    local db = {}
    _G["BiSGearCheckDB_EPScore"] = db

    -- For each spec that has EP weights
    for specKey, specData in pairs(BiSGearCheckEPWeights) do
        -- Collect all items per slot from all loaded sources
        local slotItems = {}  -- [slotName] = { [itemID] = true }

        for _, src in ipairs(self.DataSources) do
            if src.key ~= "epscore" then
                local phase = self.phaseFilter or 1
                local dbName = self:GetSourceDBName(src, phase)
                local sourceDB = dbName and _G[dbName]
                if sourceDB and sourceDB[specKey] and sourceDB[specKey].slots then
                    for slotName, items in pairs(sourceDB[specKey].slots) do
                        if not slotItems[slotName] then
                            slotItems[slotName] = {}
                        end
                        for _, itemID in ipairs(items) do
                            slotItems[slotName][itemID] = true
                        end
                    end
                end
            end
        end

        -- Score and sort each slot, filtering by phase and source filters
        local maxPhase = self.phaseFilter or 1
        local slots = {}
        for slotName, itemSet in pairs(slotItems) do
            local scored = {}
            for itemID in pairs(itemSet) do
                local classicFiltered = BiSGearCheckSaved and BiSGearCheckSaved.includeClassicZones == false and self:IsClassicZoneItem(itemID)
                if self:ItemInPhase(itemID, maxPhase) and not self:GetSourceFilterReason(itemID) and not classicFiltered then
                    local ep = self:ScoreItem(itemID, specKey)
                    if ep and ep > 0 then
                        scored[#scored + 1] = { id = itemID, ep = ep }
                    end
                end
            end
            table.sort(scored, function(a, b) return a.ep > b.ep end)

            local ranked = {}
            for _, entry in ipairs(scored) do
                ranked[#ranked + 1] = entry.id
            end
            if #ranked > 0 then
                slots[slotName] = ranked
            end
        end

        -- Determine class and spec label
        local classToken, specLabel
        for cls, specList in pairs(self.ClassSpecs or {}) do
            for _, info in ipairs(specList) do
                if info.key == specKey then
                    classToken = cls
                    specLabel = info.label
                    break
                end
            end
            if classToken then break end
        end

        if classToken and next(slots) then
            db[specKey] = {
                class = classToken,
                spec = specLabel or specKey,
                slots = slots,
            }
        end
    end
end
