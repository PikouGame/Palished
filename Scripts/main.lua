-- PKRepairKeys 1.1 — client only, Palworld 1.0.5.102999 / UE4SS 2281fa31.
-- Invoke the vanilla UI button handlers. No inventory, durability or cost writes.
local UEHelpers = require("UEHelpers")
local CLASS = "WBP_RepairEquipment_C"
local PATH = "/Game/Pal/Blueprint/UI/Repair/WBP_RepairEquipment.WBP_RepairEquipment_C"
local SINGLE = "BndEvt__WBP_RepairEquipment_WBP_IngameMenu_Repair_K2Node_ComponentBoundEvent_2_OnClickedRepairButton__DelegateSignature"
local ALL = "BndEvt__WBP_RepairEquipment_WBP_IngameMenu_Repair_K2Node_ComponentBoundEvent_3_OnClickedRepairAllButton__DelegateSignature"
local hooked, labeled = {}, {}
local pending, cooldown = nil, false
local function log(s) print("[PKRepairKeys] " .. tostring(s) .. "\n") end
local function valid(o) return o and o:IsValid() end
local function safe(fn)
    local ok, err = pcall(fn)
    if not ok then log("ERROR " .. tostring(err)) end
end
local function later(ms, fn)
    ExecuteWithDelay(ms, function() ExecuteInGameThread(function() safe(fn) end) end)
end

-- The repair-all label is not a reflected variable in this game build.
-- Walk only that button's small widget tree, never all text objects in the game.
local function findLabel(node, target, depth)
    if not valid(node) or depth > 12 then return nil end
    if node:GetFName():ToString() == target then return node end
    if node:IsA("/Script/UMG.PanelWidget") then
        for i = 0, node:GetChildrenCount() - 1 do
            local result = findLabel(node:GetChildAt(i), target, depth + 1)
            if result then return result end
        end
    end
end
local function suffix(label, hint)
    assert(valid(label), "Repair label unavailable")
    local text = label:GetText():ToString()
    -- Preserve the currently selected language and avoid appending twice.
    if text == "" or text == "TEXT" or text == "Text Block" then return false end
    if text:sub(-#hint) ~= hint then
        label:SetText(UEHelpers.GetKismetTextLibrary():Conv_StringToText(text .. hint))
    end
    return label:GetText():ToString():sub(-#hint) == hint
end
local function labelWindow(window)
    if not valid(window) or window:HasAnyFlags(0x10) then return end -- class default object
    local panel = window.WBP_IngameMenu_Repair
    if not valid(panel) then return end
    local single, all = panel.WBP_IngameMenu_RepairButton, panel.WBP_IngameMenu_RepairAllButton
    if not valid(single) or not valid(all) or not valid(all.WidgetTree) then return end
    local a = suffix(single.Text_Main, " [R]")
    local b = suffix(findLabel(all.WidgetTree.RootWidget, "BP_PalTextBlock_C_44", 0), " [Ctrl+R]")
    local id = window:GetFullName()
    if a and b and not labeled[id] then
        labeled[id] = true
        log("Labels ready: " .. single.Text_Main:GetText():ToString() .. " / Repair All [Ctrl+R]")
    end
end
local function installHooks()
    -- Blueprint functions exist only after their package has loaded.
    for _, name in ipairs({"OnSetup", "Setup"}) do
        local path = PATH .. ":" .. name
        local fn = StaticFindObject(path)
        if valid(fn) then
            local id = tostring(fn:GetAddress())
            if not hooked[id] then
                RegisterHook(path, function(context)
                    local window = context:get()
                    later(100, function() labelWindow(window) end)
                end)
                hooked[id] = true
            end
        end
    end
end
NotifyOnNewObject(PATH, function(window)
    later(100, function() installHooks(); labelWindow(window) end)
    later(600, function() labelWindow(window) end)
end)
for _, delay in ipairs({2000, 10000, 30000}) do
    later(delay, function()
        installHooks()
        for _, window in ipairs(FindAllOf(CLASS) or {}) do labelWindow(window) end
    end)
end

local function activeWindow()
    for _, window in ipairs(FindAllOf(CLASS) or {}) do
        if valid(window) and not window:HasAnyFlags(0x10)
            and window:IsActivated() and window:IsVisible() and window:GetIsEnabled()
            and window:GetVisibility() ~= 3 then
            -- Repairing overlay blocks a second request while the server responds.
            if not window.Overlay_Repairing:IsVisible() then return window end
        end
    end
end
local function dispatch(mode)
    local window = activeWindow()
    if not window then return end
    local panel = window.WBP_IngameMenu_Repair
    if not valid(panel) or not panel:IsVisible() then return end
    local button = mode == "all" and panel.WBP_IngameMenu_RepairAllButton or panel.WBP_IngameMenu_RepairButton
    if not valid(button) or not button:IsVisible() then return end
    local hit = button.WBP_PalInvisibleButton
    -- Single repair uses Visible/HitTestInvisible; Repair All uses SelfHitTestInvisible.
    if not valid(hit) or not hit:GetIsEnabled() then return end
    local visibility = hit:GetVisibility()
    if visibility ~= 0 and not (mode == "all" and visibility == 4) then return end
    if mode == "all" and not window.CanAllRepair then return end
    safe(function() labelWindow(window) end)
    if mode == "all" then window[ALL](window) else window[SINGLE](window) end
    log(mode == "all" and "Ctrl+R: vanilla Repair All confirmation opened" or "R: vanilla selected-item repair requested")
end
local function queue(mode)
    if cooldown then return end
    -- Some input handlers deliver both R and Ctrl+R. Merge them, with Ctrl priority.
    if pending then
        if mode == "all" then pending = "all" end
        return
    end
    pending = mode
    later(30, function()
        local selected = pending
        pending = nil
        cooldown = true
        later(300, function() cooldown = false end)
        dispatch(selected)
    end)
end
RegisterKeyBind(Key.R, function() queue("single") end)
RegisterKeyBind(Key.R, {ModifierKey.CONTROL}, function() queue("all") end)
log("Loaded: R = selected item; Ctrl+R = Repair All. Repair bench only; vanilla costs and confirmation.")
local hudOK, hudError = pcall(require, "durability")
if not hudOK then log("HUD load failed: " .. tostring(hudError)) end
local layoutOK, layoutError = pcall(function() require("equipment_layout")(later) end)
if not layoutOK then log("Equipment layout load failed: " .. tostring(layoutError)) end
