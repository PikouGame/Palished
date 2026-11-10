local root=assert(arg[1],'pass mod root with trailing slash')
local notify,jobs,scans,hook,found=nil,{},0,nil,nil
local delays={}
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
ExecuteInGameThreadWithDelay=function(ms,fn)jobs[#jobs+1]=fn;delays[#jobs]=ms end
FindAllOf=function()scans=scans+1;return found end
StaticFindObject=function()return obj('function')end
RegisterHook=function(_,fn)hook=fn end
-- a menu that exists when the mod loads, and a class default object beside it
local cdo=obj('default menu',{})
function cdo:HasAnyFlags()return true end
function cdo:GetOwningPlayer()return owner end
found={menu,cdo}
local U=dofile(root..'Scripts/unarmed.lua')
assert(not U.update(hud),'absent selector must not be mistaken for unarmed')
assert(#jobs==1 and delays[1]==0 and scans==0,'one load pass at once, nothing scanned before it runs')
jobs[1]()
assert(U.update(hud) and icon.Brush.ResourceObject==fist and label.value=='Mains nues')
local before,passes=writes,scans
for i=1,20 do assert(U.update(hud)) end
assert(writes==before and scans==passes and #jobs==1,'no repeated paints, scans or timers')
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
local weaponRow=obj('weapon row')
menu.LastSelectedWeaponActor=weapon;menu.CachedSelectedWeaponListWidget=weaponRow
icon.Brush.ResourceObject=weapon;icon.visible=true;label.value='Pickaxe'
assert(not U.update(hud) and icon.Brush.ResourceObject==weapon and icon.visible and label.value=='Pickaxe')
-- A selected weapon actor settles it before the two rows are even read.
do
    local rows,reads={NonWeaponWidget=source,CachedSelectedWeaponListWidget=menu.CachedSelectedWeaponListWidget},{}
    menu.NonWeaponWidget=nil;menu.CachedSelectedWeaponListWidget=nil
    setmetatable(menu,{__index=function(_,k) if rows[k] then reads[k]=true end return rows[k] end})
    assert(not U.update(hud) and not next(reads),'rows read although a weapon actor is selected')
    -- even when that weapon row is the unarmed one, a weapon actor refuses the fist
    rows.CachedSelectedWeaponListWidget=source
    assert(not U.update(hud) and not next(reads) and icon.Brush.ResourceObject==weapon and label.value=='Pickaxe')
    setmetatable(menu,nil);menu.NonWeaponWidget=rows.NonWeaponWidget;menu.CachedSelectedWeaponListWidget=weaponRow
end
menu.LastSelectedWeaponActor=nil
assert(not U.update(hud),'missing weapon without native unarmed selection is not enough')
menu.CachedSelectedWeaponListWidget=source
hud.GetOwningPlayer=function()return obj('other local player')end
assert(not U.update(hud),'never borrow another player\'s weapon selection')
hud.GetOwningPlayer=function()return owner end
assert(U.update(hud))
-- Without the native fist texture or its localized name there is nothing to show.
source.Icon_Weapon.Brush.ResourceObject=nil
assert(not U.update(hud) and not icon.visible and label.value=='','missing fist texture')
source.Icon_Weapon.Brush.ResourceObject=fist;assert(U.update(hud))
local nativeName=source.Text_WeaponName.GetText
source.Text_WeaponName.GetText=function()return text('')end
assert(not U.update(hud) and not icon.visible and label.value=='','missing fist name')
source.Text_WeaponName.GetText=nativeName;assert(U.update(hud))
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
