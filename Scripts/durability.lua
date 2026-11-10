-- Read-only equipped-tool durability, inside the existing weapon HUD tile.
local helpers = require("UEHelpers")
local unarmed = require("unarmed")
local CLASS = "WBP_Ingame_PlayerGauge_Separated_C"
local PATH = "/Game/Pal/Blueprint/UI/UserInterface/InGame/PlayerGauge/WBP_Ingame_PlayerGauge_Separated.WBP_Ingame_PlayerGauge_Separated_C"
local state = {hud=nil, bar=nil, text=nil, last=nil, error=nil}
local function valid(x) return x and x:IsValid() end
local function log(s) print("[PKRepairKeys.HUD] "..tostring(s).."\n") end
local function hide()
    if valid(state.bar) then state.bar:SetVisibility(1) end
    if valid(state.text) then state.text:SetVisibility(1) end
end
local function remove()
    unarmed.clear()
    if valid(state.bar) then state.bar:RemoveFromParent() end
    if valid(state.text) then state.text:RemoveFromParent() end
    state.bar=nil;state.text=nil;state.last=nil
end
local function create(hud)
    remove()
    assert(valid(hud.WidgetTree) and valid(hud.Canvas_WeaponInfo),"HUD tree unavailable")
    local iconSlot=hud.Icon_Weapon.Slot
    local pos,size,anchors=iconSlot:GetPosition(),iconSlot:GetSize(),iconSlot:GetAnchors()
    local bar=StaticConstructObject(StaticFindObject("/Script/UMG.ProgressBar"),hud.WidgetTree,FName("PKToolDurabilityBar"))
    local text=StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),hud.WidgetTree,FName("PKToolDurabilityText"))
    assert(valid(bar) and valid(text),"Could not construct durability widgets")
    state.bar=bar;state.text=text
    bar.WidgetStyle=hud.ProgressBar_CoolProgress.WidgetStyle
    bar.BorderPadding={X=0,Y=0}
    local bs=hud.Canvas_WeaponInfo:AddChildToCanvas(bar)
    bs:SetAnchors(anchors);bs:SetAlignment({X=1,Y=0})
    bs:SetPosition({X=pos.X+size.X-2,Y=pos.Y+size.Y*0.5-5});bs:SetSize({X=size.X*0.50,Y=3});bs:SetZOrder(20)
    bar:SetPercent(0)
    local ts=hud.Canvas_WeaponInfo:AddChildToCanvas(text)
    ts:SetAnchors(anchors);ts:SetAlignment({X=1,Y=1})
    ts:SetPosition({X=pos.X+size.X-2,Y=pos.Y+size.Y*0.5-7});ts:SetSize({X=46,Y=14});ts:SetZOrder(21)
    text:SetFont(hud.Text_WeaponName.Font)
    text.Font.Size=9;text.Font.FontMaterial=nil;text:SetFont(text.Font);text:SetJustification(2)
    text:SetShadowColorAndOpacity({R=0,G=0,B=0,A=1});text:SetShadowOffset({X=1,Y=1})
    bar:SetVisibility(3);text:SetVisibility(3)
    log("Widgets created inside weapon tile")
end
local function update()
    local hud=state.hud
    if not valid(hud) then return end
    if not valid(state.bar) or not valid(state.text) then create(hud) end
    if unarmed.update(hud) then hide();state.last=nil;return end
    if hud.isRiding or not hud.Canvas_WeaponInfo:IsVisible() or not hud.Icon_Weapon:IsVisible() then hide();state.last=nil;return end
    local weapon=helpers.GetKismetSystemLibrary():Conv_SoftObjectReferenceToObject(hud.nowHasWeapon)
    if not valid(weapon) then hide();state.last=nil;return end
    local dynamic=weapon.ownWeaponDynamicData
    if not valid(dynamic) then hide();state.last=nil;return end
    local current,maximum=dynamic:GetDurability(),dynamic:GetMaxDurability()
    if maximum<=0 or current~=current or maximum~=maximum then hide();state.last=nil;return end
    local ratio=math.max(0,math.min(1,current/maximum))
    local percent=math.floor(ratio*100+0.5)
    local color=ratio<0.10 and {R=1,G=0.12,B=0.08,A=1}
        or ratio<0.30 and {R=1,G=0.55,B=0.08,A=1}
        or {R=0.35,G=0.85,B=1,A=1}
    state.bar:SetPercent(ratio);state.bar:SetFillColorAndOpacity(color)
    if state.last~=percent then
        state.text:SetText(helpers.GetKismetTextLibrary():Conv_StringToText(tostring(percent).." %"))
        state.last=percent
    end
    state.text:SetColorAndOpacity({SpecifiedColor=color,ColorUseRule=0})
    state.bar:SetVisibility(3);state.text:SetVisibility(3)
end
local function guarded()
    local ok,err=pcall(update)
    if not ok then
        hide()
        if state.error~=tostring(err) then state.error=tostring(err);log("ERROR "..tostring(err)) end
    end
end
local function adopt(hud)
    if not valid(hud) or hud:HasAnyFlags(0x30) then return end
    if not hud:GetFullName():find("/Engine/Transient.",1,true) then return end
    if valid(state.hud) and state.hud:GetAddress()==hud:GetAddress() then return end
    remove();state.hud=hud;state.error=nil;guarded()
end
NotifyOnNewObject(PATH,function(hud)
    ExecuteInGameThreadWithDelay(500,function()adopt(hud)end)
end)
for _,ms in ipairs({2000,10000,30000}) do
    ExecuteInGameThreadWithDelay(ms,function()
        for _,hud in ipairs(FindAllOf(CLASS) or {}) do adopt(hud) end
    end)
end
LoopInGameThreadWithDelay(250,guarded)
log("Loaded: equipped-tool durability only; no item/stat writes")
