local root=assert(arg[1],'pass mod root with trailing slash')
local notify,jobs,scans,hook=nil,{},0,nil
local function obj(id,t)
    t=t or {};t.alive=true
    function t:IsValid()return self.alive end
    function t:GetAddress()return id end
    function t:HasAnyFlags()return false end
    function t:GetOwningPlayer()return nil end
    return t
end
local function text(s) return {ToString=function()return s end} end
FText=text
local owner=obj('owner')
local selector=obj('selector',{primary=3})
function selector:GetPrimaryInventoryType()return self.primary end
local pawn=obj('pawn',{LoadoutSelectorComponent=selector})
local fist,weapon,invisible=obj('native fist'),obj('pickaxe'),obj('native invisible')
local source=obj('unarmed row',{Icon_Weapon={Brush={ResourceObject=fist}},
    Text_WeaponName={GetText=function()return text('Mains nues')end}})
local menu=obj('selection',{NonWeaponWidget=source,CachedSelectedWeaponListWidget=source})
function menu:GetOwningPlayer()return owner end
function menu:GetOwningPlayerPawn()return pawn end
local writes=0
local icon={Brush={ResourceObject=invisible},visible=true}
function icon:IsVisible()return self.visible end
function icon:SetBrushFromTexture(t,resize)assert(not resize);self.Brush.ResourceObject=t;writes=writes+1 end
function icon:SetVisibility(v)self.visible=v~=1 end
local label={value=''}
function label:GetText()return text(self.value)end
function label:SetText(t)self.value=t:ToString();writes=writes+1 end
local hud=obj('hud',{Icon_Weapon=icon,Text_WeaponName=label,isRiding=false,
    Canvas_WeaponInfo={IsVisible=function()return true end}})
function hud:GetOwningPlayer()return owner end
NotifyOnNewObject=function(_,fn)notify=fn end
-- the loader's async-thread callbacks can be lost: only the game-thread timers are allowed
ExecuteWithDelay=function()error('ExecuteWithDelay: use ExecuteInGameThreadWithDelay',2)end
ExecuteInGameThread=function()error('ExecuteInGameThread: use ExecuteInGameThreadWithDelay',2)end
ExecuteInGameThreadWithDelay=function(_,fn)jobs[#jobs+1]=fn end
FindAllOf=function()scans=scans+1;return {menu}end
StaticFindObject=function()return obj('function')end
RegisterHook=function(_,fn)hook=fn end
local U=dofile(root..'Scripts/unarmed.lua')
assert(not U.update(hud),'absent selector must not be mistaken for unarmed')
jobs[1]()
assert(U.update(hud) and icon.Brush.ResourceObject==fist and label.value=='Mains nues')
local before=writes
for i=1,20 do assert(U.update(hud)) end
assert(writes==before and scans==1,'no repeated paints or steady object scans')
-- The native HUD may clear its empty tile again; repaint only then.
icon.Brush.ResourceObject=invisible;label.value=''
assert(U.update(hud) and label.value=='Mains nues')
selector.primary=0
assert(not U.update(hud) and not icon.visible and label.value=='','sphere action clears only our content')
selector.primary=3;assert(U.update(hud))
hud.isRiding=true
assert(not U.update(hud) and not icon.visible,'riding cannot show the fist')
hud.isRiding=false;assert(U.update(hud))
-- A native real-weapon update must never be erased during cleanup.
menu.LastSelectedWeaponActor=weapon;menu.CachedSelectedWeaponListWidget=obj('weapon row')
icon.Brush.ResourceObject=weapon;icon.visible=true;label.value='Pickaxe'
assert(not U.update(hud) and icon.Brush.ResourceObject==weapon and icon.visible and label.value=='Pickaxe')
menu.LastSelectedWeaponActor=nil
assert(not U.update(hud),'missing weapon without native unarmed selection is not enough')
menu.CachedSelectedWeaponListWidget=source
hud.GetOwningPlayer=function()return obj('other local player')end
assert(not U.update(hud),'never borrow another player\'s weapon selection')
hud.GetOwningPlayer=function()return owner end
assert(U.update(hud))
menu.alive=false;assert(not U.update(hud) and label.value=='')
menu.alive=true;notify(menu);jobs[#jobs]();assert(U.update(hud))
-- The live native selector is authoritative even if a different widget was
-- notified later (templates, reconstruction or another local menu).
notify(obj('uninitialized menu'));jobs[#jobs]()
assert(U.update(hud),'unowned template must not replace the active player menu')
hook({get=function()return menu end})
assert(U.update(hud))
hud.alive=false;U.clear() -- destroyed widget cleanup must not touch its fields
print('PASS: native fist/localized label, explicit selection, riding/sphere exclusion, real-weapon ownership, lifecycle and no repeated writes/scans')
