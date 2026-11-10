-- Align both equipment columns using their native widget dimensions.
-- Keep each section's title, cases, dimensions and item-slot behavior intact.
local CLASS = "WBP_InventoryEquipment_C"
local PATH = "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/InventoryEquipment/WBP_InventoryEquipment." .. CLASS
local function valid(object) return object and object:IsValid() end

local function groupSlot(window, name)
    local item = window[name]
    if not valid(item) then return end
    local node = item:GetParent()
    -- Right-hand cases sit directly in their section; left-hand cases use a grid/row.
    for _ = 1, 2 do
        if not valid(node) or not valid(node.Slot) then return end
        if node.Slot:IsA("/Script/UMG.VerticalBoxSlot") then return node.Slot end
        node = node:GetParent()
    end
end

local function frame(contentSlot, canvasHeight)
    local section = contentSlot.Parent
    local slot = section.Slot
    if not valid(slot) or not slot:IsA("/Script/UMG.CanvasPanelSlot") then return end
    local position, size = slot:GetPosition(), slot:GetSize()
    local anchors, alignment = slot:GetAnchors(), slot:GetAlignment()
    -- Stretched sections need different sizing rules; preserve that layout.
    if anchors.Minimum.Y ~= anchors.Maximum.Y then return end
    return {slot=slot, x=position.X, y=position.Y, height=size.Y,
        contentHeight=section:GetDesiredSize().Y,
        anchor=anchors.Minimum.Y, left=anchors.Minimum.X, right=anchors.Maximum.X,
        align=alignment.Y,
        top=position.Y + anchors.Minimum.Y * canvasHeight - alignment.Y * size.Y}
end

local function place(current, top, anchor, canvasHeight)
    current.top = top
    local y = top - anchor * canvasHeight + current.align * current.height
    if current.anchor == anchor and math.abs(current.y - y) <= 0.01 then return false end
    current.slot:SetAnchors({Minimum={X=current.left, Y=anchor}, Maximum={X=current.right, Y=anchor}})
    current.slot:SetPosition({X=current.x, Y=y})
    return true
end

local function stack(window, slots)
    local canvas = window.Canvas_EquipmentSlots
    if not valid(canvas) or not valid(canvas.Slot) then return false, false end
    local height, frames = canvas.Slot:GetSize().Y, {}
    window:ForceLayoutPrepass()
    for i, contentSlot in ipairs(slots) do
        frames[i] = frame(contentSlot, height)
        if not frames[i] then return false, false end
    end
    -- Reuse the Accessory-to-Food gap (tops are measured independently of anchors).
    local gap = frames[3].top - (frames[2].top + frames[2].height)
    if gap < 0 then return false, false end
    local changed, anchor = false, frames[1].anchor
    for i = 2, #frames do
        local previous, current = frames[i - 1], frames[i]
        changed = place(current, previous.top + previous.height + gap, anchor, height) or changed
    end

    -- Distribute the right column between Head's top and the last Accessory case (Modifier is the Sphere Module slot).
    local right, occupied = {}, 0
    for i, name in ipairs({"Head", "Body", "Shield", "Glider", "Modifier"}) do
        local slot = groupSlot(window, "WBP_ItemSlotButton_" .. name)
        right[i] = slot and frame(slot, height)
        if not right[i] or right[i].contentHeight <= 0 then return changed, false end
        occupied = occupied + right[i].contentHeight
    end
    if frames[2].contentHeight <= 0 then return changed, false end
    local bottom = frames[2].top + frames[2].contentHeight
    local spacing = (bottom - right[1].top - occupied) / (#right - 1)
    if spacing < 0 then return changed, false end
    for i = 2, #right do
        local previous = right[i - 1]
        changed = place(right[i], previous.top + previous.contentHeight + spacing,
            right[1].anchor, height) or changed
    end
    return changed, true
end

local function align(window)
    if not valid(window) or window:HasAnyFlags(0x10) then return end
    local weapon = groupSlot(window, "WBP_ItemSlotButton_Weapon_00")
    local accessory = groupSlot(window, "WBP_ItemSlotButton_Accessory_01")
    local food = groupSlot(window, "WBP_ItemSlotButton_Food_00")
    if not weapon or not accessory or not food then return end
    local left, changed = weapon.Padding.Left, false
    for _, slot in ipairs({accessory, food}) do
        local padding = slot.Padding
        if padding.Left ~= left then
            slot:SetPadding({Left=left, Top=padding.Top, Right=padding.Right, Bottom=padding.Bottom})
            changed = true
        end
    end
    local stacked, rightReady = stack(window, {weapon, accessory, food})
    if changed or stacked then
        print(rightReady and "[Palished] Equipment columns aligned; Sphere Module follows Accessory bottom.\n"
            or "[Palished] Left equipment column aligned.\n")
    end
end

return function(later)
    NotifyOnNewObject(PATH, function(window)
        -- Object notification can precede construction of the widget tree.
        later(100, function() align(window) end)
        later(600, function() align(window) end)
    end)
    -- A mod loaded in the middle of a game finds the screen that already exists.
    later(0, function()
        for _, window in ipairs(FindAllOf(CLASS) or {}) do align(window) end
    end)
end
