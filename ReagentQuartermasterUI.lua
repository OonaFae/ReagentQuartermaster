--[[
    ReagentQuartermaster
    Configuration UI

    WotLK 3.3.5 — pure Lua, no ScrollFrame/Slider templates.
    Scroll is driven entirely by an integer row-offset so there
    is no SetVerticalScroll call and no hidden template hooks.
--]]

local RQ = ReagentQuartermaster

-- ============================================================
-- Layout constants
-- ============================================================
local FRAME_W     = 480
local FRAME_H     = 520
local ROW_H       = 26
local ROW_PAD     = 2
local LIST_TOP    = -170
local LIST_BOTTOM = 44

-- ============================================================
-- Helper: styled EditBox with placeholder text
-- ============================================================
local function MakeEditBox(parent, w, h, x, y, placeholder)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(w, h)
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetTextInsets(6, 6, 0, 0)
    eb:SetMaxLetters(127)
    eb:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    eb:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    eb:SetBackdropBorderColor(0.4, 0.35, 0.25, 1)

    if placeholder then
        eb:SetText(placeholder)
        eb:SetTextColor(0.5, 0.5, 0.5, 1)
        local isPlaceholder = true
        eb:SetScript("OnEditFocusGained", function(self)
            if isPlaceholder then
                self:SetText("")
                self:SetTextColor(1, 1, 1, 1)
                isPlaceholder = false
            end
        end)
        eb:SetScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then
                self:SetText(placeholder)
                self:SetTextColor(0.5, 0.5, 0.5, 1)
                isPlaceholder = true
            end
        end)
        eb.IsPlaceholder = function() return isPlaceholder end
    else
        eb.IsPlaceholder = function() return false end
    end
    return eb
end

-- ============================================================
-- Helper: UIPanelButton
-- ============================================================
local function MakeButton(parent, label, w, h, x, y, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w, h)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- ============================================================
-- Row pool — rows are always children of the list content frame.
-- We hide/show them; we never nil the parent.
-- ============================================================
local rowPool = {}

local function AcquireRow(parent)
    local r = table.remove(rowPool)
    if not r then
        r = CreateFrame("Frame", nil, parent)
        r:SetHeight(ROW_H)

        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()

        r.nameLabel = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.nameLabel:SetPoint("LEFT", r, "LEFT", 8, 0)
        r.nameLabel:SetWidth(252)
        r.nameLabel:SetJustifyH("LEFT")
        r.nameLabel:SetWordWrap(false)

        r.qtyLabel = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.qtyLabel:SetPoint("LEFT", r, "LEFT", 268, 0)
        r.qtyLabel:SetWidth(58)
        r.qtyLabel:SetJustifyH("CENTER")

        r.haveLabel = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.haveLabel:SetPoint("LEFT", r, "LEFT", 334, 0)
        r.haveLabel:SetWidth(50)
        r.haveLabel:SetJustifyH("CENTER")

        r.deleteBtn = CreateFrame("Button", nil, r, "UIPanelCloseButton")
        r.deleteBtn:SetSize(20, 20)
        r.deleteBtn:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    else
        r:SetParent(parent)
    end
    r:ClearAllPoints()
    r:Show()
    return r
end

local function ReleaseRow(r)
    r:ClearAllPoints()
    r:Hide()
    r.deleteBtn:SetScript("OnClick", nil)
    table.insert(rowPool, r)
end

-- ============================================================
-- BuildUI — called once
-- ============================================================
function RQ:BuildUI()
    if RQ.UI then return end

    local f = CreateFrame("Frame", "ReagentQuartermasterUI", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
    f:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
    f:Hide()

    -- Title bar
    local titleBg = f:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  5, -5)
    titleBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    titleBg:SetHeight(36)
    titleBg:SetTexture(0.15, 0.12, 0.04, 1)

    local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", f, "TOP", 0, -16)
    titleText:SetText("|cffFFD700Reagent|r|cffFFFFFFQuartermaster|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT",  f, "TOPLEFT",  10, -46)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -46)
    divider:SetHeight(1)
    divider:SetTexture(0.5, 0.42, 0.15, 0.8)

    -- Toggles
    f.enableCB = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.enableCB:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -56)
    f.enableCB:SetSize(24, 24)
    f.enableCB:SetScript("OnClick", function(self) RQ.db.enabled = self:GetChecked() end)
    local enableLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableLabel:SetPoint("LEFT", f.enableCB, "RIGHT", 2, 0)
    enableLabel:SetText("Auto-buy enabled")

    f.verboseCB = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.verboseCB:SetPoint("TOPLEFT", f, "TOPLEFT", 210, -56)
    f.verboseCB:SetSize(24, 24)
    f.verboseCB:SetScript("OnClick", function(self) RQ.db.verbose = self:GetChecked() end)
    local verboseLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    verboseLabel:SetPoint("LEFT", f.verboseCB, "RIGHT", 2, 0)
    verboseLabel:SetText("Show purchase messages")

    -- Add-item area
    local addBg = f:CreateTexture(nil, "ARTWORK")
    addBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  10, -88)
    addBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -88)
    addBg:SetHeight(52)
    addBg:SetTexture(0.10, 0.10, 0.06, 0.55)

    local nameLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -94)
    nameLbl:SetText("Item Name")

    local qtyLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qtyLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 300, -94)
    qtyLbl:SetText("Want Qty")

    f.nameEB = MakeEditBox(f, 272, 24, 14, -106, "e.g. Rune of Portals")
    f.qtyEB  = MakeEditBox(f, 72,  24, 294, -106, "20")
    f.nameEB:SetScript("OnEnterPressed", function() f.qtyEB:SetFocus() end)
    f.qtyEB:SetScript("OnEnterPressed",  function() RQ:UIAddItem() end)
    MakeButton(f, "Add / Update", 88, 24, 374, -106, function() RQ:UIAddItem() end)

    -- Column headers
    local hdrBg = f:CreateTexture(nil, "ARTWORK")
    hdrBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  10, -150)
    hdrBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -150)
    hdrBg:SetHeight(18)
    hdrBg:SetTexture(0.20, 0.17, 0.06, 0.9)

    local hdrName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrName:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -152)
    hdrName:SetText("|cffFFD700Item Name|r")

    local hdrQty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrQty:SetPoint("TOPLEFT", f, "TOPLEFT", 276, -152)
    hdrQty:SetText("|cffFFD700Want|r")

    local hdrHave = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrHave:SetPoint("TOPLEFT", f, "TOPLEFT", 342, -152)
    hdrHave:SetText("|cff88FF88Have|r")

    -- ── List area ─────────────────────────────────────────────
    -- Plain clipped Frame — no ScrollFrame, no Slider template.
    -- Rows are placed by index offset; no pixel scrolling needed.
    local listFrame = CreateFrame("Frame", nil, f)
    listFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",    10,  LIST_TOP)
    listFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, LIST_BOTTOM)
    listFrame:SetClipsChildren(true)

    local content = CreateFrame("Frame", nil, listFrame)
    content:SetAllPoints(listFrame)

    f.listFrame     = listFrame
    f.scrollContent = content
    f.activeRows    = {}
    f.scrollOffset  = 0
    f.scrollMax     = 0

    -- Mousewheel scrolling
    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(self, delta)
        RQ:ScrollList(-delta)
    end)

    -- ── Scroll bar (100% manual, zero templates) ───────────────
    local barFrame = CreateFrame("Frame", nil, f)
    barFrame:SetPoint("TOPLEFT",    listFrame, "TOPRIGHT",    2, 0)
    barFrame:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMRIGHT", 2, 0)
    barFrame:SetWidth(14)
    barFrame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left=2, right=2, top=2, bottom=2 },
    })
    barFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.8)
    barFrame:SetBackdropBorderColor(0.30, 0.25, 0.10, 0.8)

    -- Up arrow button
    local upBtn = CreateFrame("Button", nil, barFrame)
    upBtn:SetSize(14, 14)
    upBtn:SetPoint("TOP", barFrame, "TOP", 0, -1)
    local upTex = upBtn:CreateTexture(nil, "ARTWORK")
    upTex:SetAllPoints()
    upTex:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
    upBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
    upBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
    upBtn:SetScript("OnClick", function() RQ:ScrollList(-1) end)

    -- Down arrow button
    local downBtn = CreateFrame("Button", nil, barFrame)
    downBtn:SetSize(14, 14)
    downBtn:SetPoint("BOTTOM", barFrame, "BOTTOM", 0, 1)
    downBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    downBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    downBtn:SetScript("OnClick", function() RQ:ScrollList(1) end)

    -- Thumb texture (decorative indicator, not draggable to keep it simple)
    local thumb = barFrame:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(10)
    thumb:SetTexture(0.5, 0.42, 0.15, 0.85)
    f.scrollThumb = thumb
    f.scrollBar   = barFrame

    -- ── Status bar ─────────────────────────────────────────────
    local statusBg = f:CreateTexture(nil, "ARTWORK")
    statusBg:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  5, 5)
    statusBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)
    statusBg:SetHeight(34)
    statusBg:SetTexture(0.08, 0.08, 0.05, 0.9)

    f.statusLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.statusLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    f.statusLabel:SetText("Open a vendor to trigger auto-buy.")

    tinsert(UISpecialFrames, "ReagentQuartermasterUI")
    RQ.UI = f   -- assign LAST; no callbacks fire during construction
end

-- ============================================================
-- Scroll helper
-- ============================================================
function RQ:ScrollList(delta)
    if not RQ.UI then return end
    local newOffset = math.max(0, math.min(RQ.UI.scrollMax, RQ.UI.scrollOffset + delta))
    if newOffset ~= RQ.UI.scrollOffset then
        RQ.UI.scrollOffset = newOffset
        RQ:RefreshList()
    end
end

-- ============================================================
-- Open / Refresh
-- ============================================================
function RQ:OpenUI()
    RQ:BuildUI()
    RQ.UI.enableCB:SetChecked(RQ.db.enabled)
    RQ.UI.verboseCB:SetChecked(RQ.db.verbose)
    RQ.UI.scrollOffset = 0
    RQ:RefreshList()
    RQ.UI:Show()
end

function RQ:RefreshUI()
    if not RQ.UI or not RQ.UI:IsShown() then return end
    RQ.UI.enableCB:SetChecked(RQ.db.enabled)
    RQ.UI.verboseCB:SetChecked(RQ.db.verbose)
    RQ:RefreshList()
end

function RQ:RefreshList()
    if not RQ.UI then return end

    local content = RQ.UI.scrollContent

    -- Return all active rows to pool
    for _, row in ipairs(RQ.UI.activeRows) do
        ReleaseRow(row)
    end
    RQ.UI.activeRows = {}

    -- Sorted item list
    local sorted = {}
    for name, qty in pairs(RQ.db.items) do
        table.insert(sorted, { name = name, qty = qty })
    end
    table.sort(sorted, function(a, b) return a.name:lower() < b.name:lower() end)

    local total = #sorted

    -- How many rows fit?
    local listH      = RQ.UI.listFrame:GetHeight() or (FRAME_H - math.abs(LIST_TOP) - LIST_BOTTOM)
    local visRows    = math.max(1, math.floor(listH / (ROW_H + ROW_PAD)))

    -- Clamp scroll offset
    RQ.UI.scrollMax    = math.max(0, total - visRows)
    RQ.UI.scrollOffset = math.max(0, math.min(RQ.UI.scrollMax, RQ.UI.scrollOffset))
    local offset       = RQ.UI.scrollOffset

    -- Place rows
    for i = 1, visRows do
        local idx = i + offset
        if idx > total then break end

        local entry = sorted[idx]
        local row   = AcquireRow(content)

        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0,  -(i - 1) * (ROW_H + ROW_PAD))
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -(i - 1) * (ROW_H + ROW_PAD))

        if i % 2 == 0 then
            row.bg:SetTexture(0.12, 0.10, 0.04, 0.5)
        else
            row.bg:SetTexture(0.04, 0.04, 0.02, 0.3)
        end

        row.nameLabel:SetText(entry.name)
        row.qtyLabel:SetText("|cffFFD700" .. entry.qty .. "|r")

        local have   = RQ:CountItemInBags(entry.name)
        local colour = (have >= entry.qty) and "|cff00FF00" or "|cffFF8800"
        row.haveLabel:SetText(colour .. have .. "|r")

        local captureName = entry.name
        row.deleteBtn:SetScript("OnClick", function()
            RQ.db.items[captureName] = nil
            RQ:RefreshList()
            RQ:Print("Removed |cffffcc00" .. captureName .. "|r.", true)
        end)

        table.insert(RQ.UI.activeRows, row)
    end

    -- Update thumb position
    local thumb  = RQ.UI.scrollThumb
    local bar    = RQ.UI.scrollBar
    if bar and thumb then
        local barH   = bar:GetHeight() - 32   -- leave room for up/down buttons
        if RQ.UI.scrollMax > 0 and barH > 0 then
            local tH     = math.max(12, barH / (RQ.UI.scrollMax + visRows) * visRows)
            local travel = barH - tH
            local pos    = (RQ.UI.scrollOffset / RQ.UI.scrollMax) * travel
            thumb:SetHeight(tH)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", bar, "TOP", 0, -(16 + pos))
            thumb:SetPoint("LEFT",  bar, "LEFT",  2, 0)
            thumb:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
            thumb:Show()
        else
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPLEFT",  bar, "TOPLEFT",  2, -16)
            thumb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 16)
            thumb:Show()
        end
    end

    -- Status
    local count = 0
    for _ in pairs(RQ.db.items) do count = count + 1 end
    RQ.UI.statusLabel:SetText(
        count .. " item(s) configured  |  Auto-buy: " ..
        (RQ.db.enabled and "|cff00FF00ON|r" or "|cffFF4444OFF|r")
    )
end

-- ============================================================
-- Add item from UI inputs
-- ============================================================
function RQ:UIAddItem()
    if not RQ.UI then return end

    local nameEB = RQ.UI.nameEB
    local qtyEB  = RQ.UI.qtyEB

    local name = (not nameEB:IsPlaceholder()) and nameEB:GetText():trim() or ""
    local qty  = (not qtyEB:IsPlaceholder())  and qtyEB:GetText():trim()  or ""

    if name == "" then
        RQ:Print("|cffFF4444Please enter an item name.|r", true)
        return
    end

    local qtyNum = tonumber(qty)
    if not qtyNum or qtyNum < 1 then
        RQ:Print("|cffFF4444Please enter a valid quantity (1 or more).|r", true)
        return
    end

    qtyNum = math.floor(qtyNum)
    RQ.db.items[name] = qtyNum
    RQ:Print("Saved: |cffffcc00" .. name .. "|r x" .. qtyNum, true)

    nameEB:ClearFocus()
    qtyEB:ClearFocus()
    nameEB:SetText("e.g. Rune of Portals")
    nameEB:SetTextColor(0.5, 0.5, 0.5, 1)
    qtyEB:SetText("20")
    qtyEB:SetTextColor(0.5, 0.5, 0.5, 1)

    RQ:RefreshList()
end
