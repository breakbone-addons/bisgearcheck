-- BISGearCheck UI.lua
-- UI constants, main frame creation, scroll frame, CreateRow, ClearScrollContent

BISGearCheck = BISGearCheck or {}

-- UI Constants (accessible across all UI files via namespace)
BISGearCheck.FRAME_WIDTH = 480
BISGearCheck.FRAME_HEIGHT = 540
BISGearCheck.CONTENT_PADDING = 10
BISGearCheck.SLOT_HEADER_HEIGHT = 20
BISGearCheck.ITEM_ROW_HEIGHT = 18
BISGearCheck.SECTION_SPACING = 8

BISGearCheck.COLOR_GOLD = { r = 1.0, g = 0.82, b = 0.0 }
BISGearCheck.COLOR_GREEN = { r = 0.0, g = 1.0, b = 0.0 }
BISGearCheck.COLOR_GRAY = { r = 0.5, g = 0.5, b = 0.5 }
BISGearCheck.COLOR_WHITE = { r = 1.0, g = 1.0, b = 1.0 }
BISGearCheck.COLOR_RED = { r = 1.0, g = 0.3, b = 0.3 }
BISGearCheck.COLOR_CYAN = { r = 0.0, g = 0.82, b = 1.0 }

-- Track collapsed state per slot (persists within session)
BISGearCheck.collapsedSlots = BISGearCheck.collapsedSlots or {}

-- ============================================================
-- CLEAR SCROLL CONTENT
-- ============================================================

function BISGearCheck:ClearScrollContent(scrollChild)
    if scrollChild.rows then
        for _, row in ipairs(scrollChild.rows) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    scrollChild.rows = {}
end

-- ============================================================
-- CREATE ROW HELPER
-- ============================================================

function BISGearCheck:CreateRow(parent, yOffset, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, self.ITEM_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    if not parent.rows then parent.rows = {} end
    table.insert(parent.rows, row)

    return row
end

-- ============================================================
-- MAIN FRAME
-- ============================================================

function BISGearCheck:CreateUI()
    if self.mainFrame then return end

    local f = CreateFrame("Frame", "BISGearCheckFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(self.FRAME_WIDTH, self.FRAME_HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    table.insert(UISpecialFrames, "BISGearCheckFrame")

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -3)
    f.title:SetText("BiS Gear Check")

    -- Setup all control groups (defined in other UI files)
    self:SetupTabs(f)
    self:SetupCharacterSelector(f)
    self:SetupSourceSpecDropdowns(f)
    self:SetupCollapseControls(f)
    self:SetupWishlistFilterBar(f)
    self:SetupWishlistSelectorBar(f)
    self:SetupBisListBar(f)

    -- ============================================================
    -- SCROLL FRAME
    -- ============================================================

    local scrollFrame = CreateFrame("ScrollFrame", "BISGearCheckScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -90)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", "BISGearCheckScrollChild")
    scrollChild:SetWidth(self.FRAME_WIDTH - 40)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    f.scrollFrame = scrollFrame
    f.scrollChild = scrollChild

    -- Retry refresh when item data has been received
    f._retryElapsed = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        f._retryElapsed = f._retryElapsed + elapsed
        if f._retryElapsed < 0.5 then return end
        f._retryElapsed = 0
        if BISGearCheck.needsRefresh then
            BISGearCheck.needsRefresh = false
            BISGearCheck:Refresh()
        end
    end)

    self.mainFrame = f
end
