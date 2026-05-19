--[[
    ReagentQuartermaster
    Core Logic
    
    Automatically purchases configured items from vendors up to a desired quantity.
    Quantity represents the total you want in your bags; the addon buys the difference.
--]]

-- ============================================================
-- Namespace & Saved Variables
-- ============================================================

ReagentQuartermaster = {}
local RQ = ReagentQuartermaster

-- Default database structure 
local DB_DEFAULTS = {
    items = {},       -- { [itemName] = desiredQty, ... }
    enabled = true,
    verbose = true,
    buyDelay = 0.3,   -- seconds between each purchase (to avoid server spam)
}

-- ============================================================
-- Initialization
-- ============================================================

local addonFrame = CreateFrame("Frame", "ReagentQuartermasterFrame")

addonFrame:RegisterEvent("ADDON_LOADED")
addonFrame:RegisterEvent("MERCHANT_SHOW")
addonFrame:RegisterEvent("MERCHANT_CLOSED")

addonFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        RQ:OnAddonLoaded(...)
    elseif event == "MERCHANT_SHOW" then
        RQ:OnMerchantShow()
    elseif event == "MERCHANT_CLOSED" then
        RQ:OnMerchantClosed()
    end
end)

function RQ:OnAddonLoaded(addonName)
    if addonName ~= "ReagentQuartermaster" then return end

    -- Initialize or migrate saved variables
    if not ReagentQuartermasterDB then
        ReagentQuartermasterDB = {}
    end

    -- Apply defaults for any missing keys
    for k, v in pairs(DB_DEFAULTS) do
        if ReagentQuartermasterDB[k] == nil then
            ReagentQuartermasterDB[k] = v
        end
    end

    RQ.db = ReagentQuartermasterDB

    print("|cff00ccff[ReagentQuartermaster]|r Loaded. Type |cffffcc00/rq|r or |cffffcc00/reagentqm|r to open settings.")
end

-- ============================================================
-- Utility
-- ============================================================

-- Count how many of an item (by name) the player currently carries
function RQ:CountItemInBags(itemName)
    local total = 0
    local lowerTarget = itemName:lower()
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                -- Strip color codes and pull out name
                local name = link:match("%[(.-)%]")
                if name and name:lower() == lowerTarget then
                    local _, count = GetContainerItemInfo(bag, slot)
                    total = total + (count or 1)
                end
            end
        end
    end
    return total
end

-- Scan the current merchant for a named item; returns merchant index or nil
function RQ:FindMerchantItem(itemName)
    local lowerTarget = itemName:lower()
    local numItems = GetMerchantNumItems()
    for i = 1, numItems do
        local name = GetMerchantItemInfo(i)
        if name and name:lower() == lowerTarget then
            return i
        end
    end
    return nil
end

-- Print a message with addon prefix (only if verbose)
function RQ:Print(msg, force)
    if force or RQ.db.verbose then
        print("|cff00ccff[ReagentQuartermaster]|r " .. msg)
    end
end

-- ============================================================
-- Purchase Queue
-- ============================================================

local purchaseQueue = {}
local purchaseTimer = nil

local function ProcessNextPurchase()
    if #purchaseQueue == 0 then
        purchaseTimer = nil
        return
    end

    local entry = table.remove(purchaseQueue, 1)
    local merchantIndex = entry.merchantIndex
    local qty           = entry.qty
    local itemName      = entry.itemName

    -- Confirm merchant is still open and item is still there
    local name = GetMerchantItemInfo(merchantIndex)
    if not name then
        RQ:Print("|cffff4444Could not find '" .. itemName .. "' on merchant anymore.|r")
    else
        -- GetMerchantItemInfo returns: name, texture, price, quantity, numInStock, isUsable, extendedCost
        local _, _, _, stackSize = GetMerchantItemInfo(merchantIndex)
        stackSize = stackSize or 1

        local numStacks = math.ceil(qty / stackSize)
        -- BuyMerchantItem(index, quantity) — quantity is number of stacks
        BuyMerchantItem(merchantIndex, numStacks)
        RQ:Print("Purchased |cffffcc00" .. qty .. "x " .. itemName .. "|r.")
    end

    -- Schedule the next purchase
    purchaseTimer = C_Timer and C_Timer.After and C_Timer.After(RQ.db.buyDelay, ProcessNextPurchase)
        or (function()
            -- WotLK 3.3.5 fallback — use OnUpdate ticker
            local elapsed = 0
            local delay = RQ.db.buyDelay
            local ticker = CreateFrame("Frame")
            ticker:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                if elapsed >= delay then
                    self:SetScript("OnUpdate", nil)
                    ProcessNextPurchase()
                end
            end)
        end)()
end

local function QueuePurchase(merchantIndex, qty, itemName)
    table.insert(purchaseQueue, { merchantIndex = merchantIndex, qty = qty, itemName = itemName })
    if not purchaseTimer then
        -- Start processing immediately
        ProcessNextPurchase()
    end
end

-- ============================================================
-- Merchant Logic
-- ============================================================

function RQ:OnMerchantShow()
    if not RQ.db.enabled then return end
    if not RQ.db.items or next(RQ.db.items) == nil then return end

    -- Small delay so the merchant frame fully loads all items
    local elapsed = 0
    local delay = 0.5
    local starter = CreateFrame("Frame")
    starter:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            RQ:ScanAndBuy()
        end
    end)
end

function RQ:OnMerchantClosed()
    -- Clear any pending queue if player closes vendor early
    purchaseQueue = {}
end

function RQ:ScanAndBuy()
    local bought = 0
    for itemName, desiredQty in pairs(RQ.db.items) do
        local have = RQ:CountItemInBags(itemName)
        local need = desiredQty - have

        if need > 0 then
            local merchantIndex = RQ:FindMerchantItem(itemName)
            if merchantIndex then
                QueuePurchase(merchantIndex, need, itemName)
                bought = bought + 1
            end
            -- If not found at this vendor, silently skip
        end
    end

    if bought == 0 and RQ.db.verbose then
        -- Only print if nothing needed restocking (to reduce noise you can turn off verbose)
    end
end

-- ============================================================
-- Slash Commands
-- ============================================================

SLASH_REAGENTQM1 = "/rq"
SLASH_REAGENTQM2 = "/reagentqm"

SlashCmdList["REAGENTQM"] = function(msg)
    msg = msg:lower():trim()

    if msg == "" or msg == "show" or msg == "config" then
        RQ:OpenUI()
        return
    end

    if msg == "enable" then
        RQ.db.enabled = true
        RQ:Print("Auto-buy |cff00ff00ENABLED|r.", true)
        return
    end

    if msg == "disable" then
        RQ.db.enabled = false
        RQ:Print("Auto-buy |cffff4444DISABLED|r.", true)
        return
    end

    if msg == "verbose" then
        RQ.db.verbose = not RQ.db.verbose
        RQ:Print("Verbose " .. (RQ.db.verbose and "|cff00ff00ON|r" or "|cffff4444OFF|r") .. ".", true)
        return
    end

    if msg == "list" then
        if not next(RQ.db.items) then
            RQ:Print("No items configured.", true)
        else
            RQ:Print("Configured items:", true)
            for name, qty in pairs(RQ.db.items) do
                print("  |cffffcc00" .. name .. "|r  →  " .. qty)
            end
        end
        return
    end

    -- add <name> <qty>
    local addName, addQty = msg:match("^add%s+(.+)%s+(%d+)$")
    if addName and addQty then
        RQ.db.items[addName] = tonumber(addQty)
        RQ:Print("Added: |cffffcc00" .. addName .. "|r  ×  " .. addQty, true)
        if RQ.UI and RQ.UI:IsShown() then RQ:RefreshUI() end
        return
    end

    -- remove <name>
    local removeName = msg:match("^remove%s+(.+)$")
    if removeName then
        if RQ.db.items[removeName] then
            RQ.db.items[removeName] = nil
            RQ:Print("Removed: |cffffcc00" .. removeName .. "|r", true)
            if RQ.UI and RQ.UI:IsShown() then RQ:RefreshUI() end
        else
            RQ:Print("Item not found: " .. removeName, true)
        end
        return
    end

    -- Help
    RQ:Print("Commands:", true)
    print("  |cffffcc00/rq|r                       — Open the configuration UI")
    print("  |cffffcc00/rq add <name> <qty>|r       — Add or update an item")
    print("  |cffffcc00/rq remove <name>|r          — Remove an item")
    print("  |cffffcc00/rq list|r                   — List all configured items")
    print("  |cffffcc00/rq enable|r / |cffffcc00disable|r         — Toggle auto-buy")
    print("  |cffffcc00/rq verbose|r                — Toggle purchase messages")
end
