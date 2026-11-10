-- Reuse the native unarmed selection's texture and localized name.
-- An absent weapon alone is not evidence of being unarmed (spheres, riding,
-- loading and special actions can also leave the weapon tile empty).
local U = {}
local path='/Game/Pal/Blueprint/UI/UserInterface/InGame/PlayerGauge/WBP_Ingame_WeaponChange.WBP_Ingame_WeaponChange_C'
local menu,painted
local hooked=false
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
function U.clear()
    if not painted then return end
    local hud=painted.hud
    if valid(hud) then
        -- Native weapon/riding updates may already have replaced our content.
        if same(hud.Icon_Weapon.Brush.ResourceObject,painted.texture) then
            hud.Icon_Weapon:SetVisibility(1)
        end
        if hud.Text_WeaponName:GetText():ToString()==painted.name then
            hud.Text_WeaponName:SetText(FText(''))
        end
    end
    painted=nil
end
function U.update(hud)
    local source=valid(menu) and menu.NonWeaponWidget
    local selected=valid(source) and same(menu.CachedSelectedWeaponListWidget,source)
        and not valid(menu.LastSelectedWeaponActor)
    if not selected or hud.isRiding or not hud.Canvas_WeaponInfo:IsVisible()
        or not same(menu:GetOwningPlayer(),hud:GetOwningPlayer()) then
        U.clear();return false
    end
    local pawn=menu:GetOwningPlayerPawn()
    local selector=valid(pawn) and pawn.LoadoutSelectorComponent
    if not valid(selector) or selector:GetPrimaryInventoryType()~=3 then
        U.clear();return false
    end
    local texture=source.Icon_Weapon.Brush.ResourceObject
    local name=source.Text_WeaponName:GetText()
    if not valid(texture) or name:ToString()=='' then U.clear();return false end
    if painted and not same(painted.hud,hud) then U.clear() end
    if not same(hud.Icon_Weapon.Brush.ResourceObject,texture) or not hud.Icon_Weapon:IsVisible() then
        hud.Icon_Weapon:SetBrushFromTexture(texture,false) -- preserve the HUD's own icon size/tint
        hud.Icon_Weapon:SetVisibility(3)
    end
    if hud.Text_WeaponName:GetText():ToString()~=name:ToString() then
        hud.Text_WeaponName:SetText(name)
    end
    painted={hud=hud,texture=texture,name=name:ToString()}
    return true
end
local function adopt(candidate)
    if valid(candidate) and not candidate:HasAnyFlags(0x30)
        and valid(candidate:GetOwningPlayer()) then menu=candidate end
end
local function installHook()
    if hooked or not valid(StaticFindObject(path..':SelectWeapon')) then return end
    RegisterHook(path..':SelectWeapon',function(context) adopt(context:get()) end)
    hooked=true
end
NotifyOnNewObject(path,function(candidate)
    -- Creation notifications can precede widget initialization. Read its flags
    -- after construction, on the game thread, as the other HUD modules do.
    ExecuteInGameThreadWithDelay(100,function()
        adopt(candidate);installHook()
    end)
end)
-- A mod loaded in the middle of a game finds the menu that already exists.
ExecuteInGameThreadWithDelay(0,function()
    installHook()
    for _,candidate in ipairs(FindAllOf('WBP_Ingame_WeaponChange_C') or {}) do adopt(candidate) end
end)
return U
