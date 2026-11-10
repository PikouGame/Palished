-- Behavioral harness: durability bar in the weapon tile, driven through the real
-- durability.lua and unarmed.lua on a fake engine. Both timer families share one clock.
local root=arg[1] or './'
package.path=root..'Scripts/?.lua;'..package.path
local realprint=print
local PATH='/Game/Pal/Blueprint/UI/UserInterface/InGame/PlayerGauge/WBP_Ingame_PlayerGauge_Separated.WBP_Ingame_PlayerGauge_Separated_C'
local MENU='/Game/Pal/Blueprint/UI/UserInterface/InGame/PlayerGauge/WBP_Ingame_WeaponChange.WBP_Ingame_WeaponChange_C'
local CYAN,RED={R=0.35,G=0.85,B=1,A=1},{R=1,G=0.12,B=0.08,A=1}

local W,nextId
local function onGame() assert(W.thread=='game','UObject used off the game thread') end
local function copy(t) local c={} for k,v in pairs(t) do c[k]=type(v)=='table' and copy(v) or v end return c end
local function isnum(n) return type(n)=='number' and n==n end
local function vec(v) assert(type(v)=='table' and isnum(v.X) and isnum(v.Y),'bad vector') end
local function color(c) assert(type(c)=='table' and isnum(c.R) and isnum(c.G) and isnum(c.B) and isnum(c.A),'bad color') end
local function text(s) return {ToString=function()return s end} end

local Widget={}
Widget.__index=Widget
local function alive(s) assert(s.alive,'object is not valid') end
function Widget:IsValid() return self.alive end
function Widget:GetAddress() return self.id end
function Widget:GetFullName() alive(self) return self.fullName end
function Widget:HasAnyFlags(mask) alive(self) assert(math.type(mask)=='integer') return self.flags&mask~=0 end
function Widget:GetOwningPlayer() alive(self) return W.owner end
function Widget:GetVisibility() onGame() alive(self) return self.visibility end
function Widget:IsVisible() onGame() alive(self) return self.visibility==0 or self.visibility==3 or self.visibility==4 end
function Widget:SetVisibility(v)
    onGame() alive(self)
    assert(math.type(v)=='integer' and v>=0 and v<=4,'bad visibility');W.writes=W.writes+1
    self.visibility=v
end
function Widget:RemoveFromParent()
    onGame() alive(self);W.writes=W.writes+1
    local p=self.parent
    if p then for i,c in ipairs(p.children) do if c==self then table.remove(p.children,i) break end end end
    self.parent=nil;self.Slot=nil;self.removed=(self.removed or 0)+1
end
local Canvas=setmetatable({},{__index=Widget});Canvas.__index=Canvas
local Image=setmetatable({},{__index=Widget});Image.__index=Image
local Bar=setmetatable({},{__index=Widget});Bar.__index=Bar
local Label=setmetatable({},{__index=Widget});Label.__index=Label
local Slot={}
Slot.__index=Slot
function Slot:IsValid() return true end
function Slot:GetPosition() return copy(self.pos) end
function Slot:GetSize() return copy(self.size) end
function Slot:GetAnchors() return copy(self.anchors) end
function Slot:SetPosition(v) onGame() vec(v);W.writes=W.writes+1;self.pos=copy(v) end
function Slot:SetSize(v) onGame() vec(v);W.writes=W.writes+1;self.size=copy(v) end
function Slot:SetAlignment(v) onGame() vec(v);W.writes=W.writes+1;self.align=copy(v) end
function Slot:SetAnchors(a)
    onGame() vec(a.Minimum) vec(a.Maximum);W.writes=W.writes+1;self.anchors=copy(a)
end
function Slot:SetZOrder(z) onGame() assert(math.type(z)=='integer');W.writes=W.writes+1;self.z=z end
local function newSlot(parent,pos,size,anchors)
    return setmetatable({parent=parent,pos=pos,size=size,anchors=anchors,align={X=0,Y=0}},Slot)
end
function Canvas:AddChildToCanvas(w)
    onGame() alive(self) assert(type(w)=='table' and w.alive,'no widget')
    if w.parent then w:RemoveFromParent() end
    W.writes=W.writes+1
    local s=newSlot(self,{X=0,Y=0},{X=100,Y=100},{Minimum={X=0,Y=0},Maximum={X=0,Y=0}})
    w.Slot=s;w.parent=self;self.children[#self.children+1]=w
    return s
end
function Image:SetBrushFromTexture(t,matchSize)
    onGame() alive(self) assert(t and t.alive and matchSize==false,'icon size must be preserved');W.writes=W.writes+1
    self.Brush.ResourceObject=t
end
function Bar:SetPercent(p)
    onGame() alive(self) assert(isnum(p) and p>=0 and p<=1,'bad percent');W.writes=W.writes+1;self.percent=p
end
function Bar:SetFillColorAndOpacity(c) onGame() alive(self) color(c);W.writes=W.writes+1;self.fill=copy(c) end
function Label:GetText() onGame() alive(self) return text(self.text) end
function Label:SetText(t)
    onGame() alive(self) assert(type(t)=='table' and type(t.ToString)=='function','SetText wants FText')
    W.writes=W.writes+1;self.text=t:ToString()
end
function Label:SetFont(f) onGame() alive(self) assert(type(f)=='table');W.writes=W.writes+1;self.Font=copy(f) end
function Label:SetJustification(j) onGame() alive(self);W.writes=W.writes+1;self.justification=j end
function Label:SetShadowColorAndOpacity(c) onGame() alive(self) color(c);W.writes=W.writes+1;self.shadow=copy(c) end
function Label:SetShadowOffset(v) onGame() alive(self) vec(v);W.writes=W.writes+1;self.shadowOffset=copy(v) end
function Label:SetColorAndOpacity(c)
    onGame() alive(self) assert(type(c)=='table' and c.ColorUseRule==0,'bad text color');color(c.SpecifiedColor)
    W.writes=W.writes+1;self.textColor=copy(c)
end
local function new(class,name,t)
    t=t or {};nextId=nextId+1
    t.name=name;t.id=nextId;t.alive=true;t.flags=t.flags or 0;t.children=t.children or {}
    t.fullName=t.fullName or '/Engine/Transient.'..name
    if t.visibility==nil then t.visibility=0 end
    return setmetatable(t,{__index=class})
end

local function newHud(opts)
    opts=opts or {}
    local n=#W.allHuds+1
    local hud=new(Widget,'Gauge'..n,{flags=opts.flags,fullName=opts.fullName,isRiding=false,nowHasWeapon={}})
    hud.WidgetTree=new(Widget,'Tree'..n)
    hud.Canvas_WeaponInfo=new(Canvas,'Canvas_WeaponInfo')
    hud.Icon_Weapon=new(Image,'Icon_Weapon',{Brush={ResourceObject=W.invisible}})
    hud.Text_WeaponName=new(Label,'Text_WeaponName',{text='',Font={Size=18,FontMaterial='native material'}})
    hud.ProgressBar_CoolProgress={WidgetStyle={fill='cool'}}
    local canvas=hud.Canvas_WeaponInfo
    hud.Icon_Weapon.Slot=newSlot(canvas,{X=10,Y=20},{X=60,Y=40},{Minimum={X=1,Y=0.5},Maximum={X=1,Y=0.5}})
    hud.Icon_Weapon.parent=canvas
    canvas.children={hud.Icon_Weapon,hud.Text_WeaponName}
    W.allHuds[n]=hud
    if not opts.hidden then W.huds[#W.huds+1]=hud end
    return hud
end
local function die(hud)
    hud.alive=false
    for i,h in ipairs(W.huds) do if h==hud then table.remove(W.huds,i) break end end
end
local function newWeapon(cur,max)
    local dyn=new(Widget,'dynamic',{cur=cur,max=max})
    function dyn:GetDurability() alive(self) return self.cur end
    function dyn:GetMaxDurability() alive(self) return self.max end
    return new(Widget,'weapon',{ownWeaponDynamicData=dyn})
end
local function equip(hud,weapon) hud.nowHasWeapon={obj=weapon} end
local function announce(path,obj) for _,fn in ipairs(W.notify[path] or {}) do fn(obj) end end

local function newMenu()
    local fist=new(Widget,'native fist')
    local source=new(Widget,'unarmed row',{Icon_Weapon={Brush={ResourceObject=fist}},
        Text_WeaponName={GetText=function()return text('Mains nues')end}})
    local selector=new(Widget,'selector',{primary=3})
    function selector:GetPrimaryInventoryType() return self.primary end
    local pawn=new(Widget,'pawn',{LoadoutSelectorComponent=selector})
    local menu=new(Widget,'selection',{NonWeaponWidget=source,CachedSelectedWeaponListWidget=new(Widget,'weapon row')})
    function menu:GetOwningPlayerPawn() return pawn end
    W.menus[#W.menus+1]=menu
    return menu,source,fist
end

-- `existing` builds the widgets that are already in the game when the mod loads; without it the game is empty at load
local function boot(existing)
    nextId=0
    W={now=0,jobs={},seq=0,thread='game',logs={},writes=0,notify={},huds={},allHuds={},menus={},
        constructed={},hooks={},owner=nil,
        counts={ExecuteInGameThreadWithDelay=0,LoopInGameThreadWithDelay=0}}
    W.owner=new(Widget,'owner');W.invisible=new(Widget,'native invisible')
    local function sched(ms,fn,kind,every)
        assert(isnum(ms) and ms>=0,'bad delay');assert(type(fn)=='function','Ref was not function')
        W.seq=W.seq+1
        local job={at=W.now+ms,seq=W.seq,fn=fn,kind=kind,every=every,live=true}
        W.jobs[#W.jobs+1]=job
        return job
    end
    -- the loader runs these callbacks on its own thread, where a lost one cannot be told apart: never used
    function ExecuteWithDelay() error('ExecuteWithDelay: use ExecuteInGameThreadWithDelay',2) end
    function ExecuteInGameThread() error('ExecuteInGameThread: use ExecuteInGameThreadWithDelay',2) end
    function ExecuteInGameThreadWithDelay(ms,fn)
        W.counts.ExecuteInGameThreadWithDelay=W.counts.ExecuteInGameThreadWithDelay+1
        return sched(ms,fn,'game')
    end
    function LoopInGameThreadWithDelay(ms,fn) -- a callback that returns true ends the loop
        W.counts.LoopInGameThreadWithDelay=W.counts.LoopInGameThreadWithDelay+1
        assert(ms>0,'loop needs a delay');return sched(ms,fn,'game',ms)
    end
    function CancelDelayedAction(h) assert(type(h)=='table' and h.fn,'bad handle');h.live=false end
    function IsInGameThread() return W.thread=='game' end
    function W.advance(ms)
        local target=W.now+ms
        while true do
            local best
            for _,j in ipairs(W.jobs) do
                if j.live and j.at<=target and (not best or j.at<best.at or (j.at==best.at and j.seq<best.seq)) then best=j end
            end
            if not best then break end
            W.now=best.at
            if best.every then best.at=best.at+best.every;W.seq=W.seq+1;best.seq=W.seq else best.live=false end
            local r=best.fn()
            -- a loop callback that returns anything (true ends it) is a defect of the mod
            if best.every then assert(r==nil,'loop callback must return nothing') end
        end
        W.now=target
        local kept={}
        for _,j in ipairs(W.jobs) do if j.live then kept[#kept+1]=j end end
        W.jobs=kept
    end
    function NotifyOnNewObject(path,fn)
        assert(type(path)=='string' and type(fn)=='function')
        W.notify[path]=W.notify[path] or {};table.insert(W.notify[path],fn)
    end
    function FindAllOf(class)
        local list
        if class=='WBP_Ingame_PlayerGauge_Separated_C' then list=W.huds
        elseif class=='WBP_Ingame_WeaponChange_C' then list=W.menus else error('unknown class '..tostring(class)) end
        if #list==0 then return nil end
        return {table.unpack(list)}
    end
    function RegisterHook(path,fn) W.hooks[path]=fn end
    function FName(s) return {name=s} end
    function FText(s) return text(s) end
    local classes={['/Script/UMG.ProgressBar']=new(Widget,'ProgressBarClass',{make=function(n,o)return new(Bar,n,{outer=o,percent=0,Font=nil})end}),
        ['/Script/UMG.TextBlock']=new(Widget,'TextBlockClass',{make=function(n,o)return new(Label,n,{outer=o,text='',Font={Size=24,FontMaterial='default'}})end})}
    function StaticFindObject(path)
        if classes[path] then return classes[path] end
        if path:sub(-13)==':SelectWeapon' then return new(Widget,'SelectWeapon') end
    end
    function StaticConstructObject(class,outer,fname)
        assert(type(class)=='table' and class.make and class.alive,'bad class');assert(type(outer)=='table' and outer.alive,'bad outer')
        assert(type(fname)=='table' and fname.name,'bad name')
        local w=class.make(fname.name,outer)
        W.constructed[#W.constructed+1]=w
        return w
    end
    function print(...)
        local parts={}
        for i=1,select('#',...) do parts[i]=tostring((select(i,...))) end
        assert(parts[1] and parts[1]:find('^%[Palished%] '),'log tag: '..tostring(parts[1]))
        W.logs[#W.logs+1]=table.concat(parts,'\t')
    end
    W.library=new(Widget,'KismetSystemLibrary');W.libraryCalls=0
    function W.library:Conv_SoftObjectReferenceToObject(ref)
        onGame() alive(self);assert(type(ref)=='table','soft reference expected');return ref.obj
    end
    local helpers={
        GetKismetSystemLibrary=function() W.libraryCalls=W.libraryCalls+1;return W.library end,
        GetKismetTextLibrary=function() return {Conv_StringToText=function(_,s)
            assert(type(s)=='string','string expected');return text(s) end} end}
    package.loaded.durability=nil;package.loaded.unarmed=nil;package.loaded.UEHelpers=nil
    package.preload.UEHelpers=function() return helpers end
    if existing then existing() end
    assert(require('durability')==true,'the HUD module exposes nothing (no stop switch, no state)')
    W.unarmed=require('unarmed')
    if not existing then W.advance(1000) end -- the load pass finds an empty game
    return W
end

-- helpers on the Palished widgets of one HUD
local function ours(hud)
    local bar,label
    for _,c in ipairs(hud.Canvas_WeaponInfo.children) do
        if c.name=='PalishedDurabilityBar' then assert(not bar,'bar twice');bar=c end
        if c.name=='PalishedDurabilityText' then assert(not label,'text twice');label=c end
    end
    return bar,label
end
local function same(a,b) for k,v in pairs(b) do assert(a[k]==v,k..' differs') end end
local function hidden(w) return not w:IsVisible() end
local function expectHidden(hud,why)
    local bar,label=ours(hud)
    assert(bar and label and hidden(bar) and hidden(label),'must be hidden: '..why)
end
local function expectShown(hud,percent,col,why)
    local bar,label=ours(hud)
    assert(bar and label,'widgets missing: '..why)
    assert(bar.visibility==3 and label.visibility==3,'must be shown: '..why)
    assert(label.text==string.format('%d %%',percent),why..': text '..tostring(label.text))
    same(bar.fill,col);same(label.textColor.SpecifiedColor,col);assert(label.textColor.ColorUseRule==0)
end
local function count(list,needle)
    local n=0
    for _,l in ipairs(list) do if l:find(needle,1,true) then n=n+1 end end
    return n
end
-- one HUD announced, adopted, with a healthy tool
local function start(cur,max)
    boot()
    local hud=newHud();local weapon=newWeapon(cur or 100,max or 100);equip(hud,weapon)
    W.advance(100);announce(PATH,hud);W.advance(700)
    return hud,weapon
end

-- 1. nothing happens while no HUD exists
do
    boot()
    local menu=newMenu();announce(MENU,menu)
    W.advance(31000)
    assert(W.writes==0 and #W.constructed==0,'work done without a HUD')
    assert(count(W.logs,'Loaded')==1 and #W.logs==1,'only the load line may be logged')
end

-- 2. a HUD announced by NotifyOnNewObject is adopted after its delay
do
    boot()
    local hud=newHud();equip(hud,newWeapon(100,100))
    W.advance(100);announce(PATH,hud);W.advance(50)
    assert(#W.constructed==0,'adopted before its delay')
    W.advance(650)
    assert(#W.constructed==2,'announced HUD not adopted')
    expectShown(hud,100,CYAN,'announced')
end

-- 3. a HUD that already exists when the mod loads is adopted by the single load pass, and only then
do
    local hud
    boot(function() hud=newHud();equip(hud,newWeapon(50,100)) end)
    W.advance(999)
    assert(not ours(hud),'adopted before the load pass ran, a second after load')
    W.advance(1)
    expectShown(hud,50,CYAN,'load pass')
    local later=newHud();equip(later,newWeapon(40,100))
    die(hud);W.advance(31000)
    assert(not ours(later),'a new HUD without notification is never scanned for')
end

-- 3b. one game-thread loop is started at load (no start delay) and follows the tool every 250 ms
do
    boot()
    assert(W.counts.LoopInGameThreadWithDelay==1,'one loop at load')
    local hud=newHud();local weapon=newWeapon(80,100);equip(hud,weapon)
    announce(PATH,hud);W.advance(500)
    expectShown(hud,80,CYAN,'adopted at 500 ms')
    weapon.ownWeaponDynamicData.cur=20;W.advance(250)
    expectShown(hud,20,CYAN,'the loop is running 250 ms later, not after a 1000 ms start delay')
    assert(W.counts.LoopInGameThreadWithDelay==1,'the loop is never re-armed')
end

-- 4. class default objects, archetypes and non-transient objects are never adopted
do
    boot()
    local cdo=newHud{flags=0x10};local arch=newHud{flags=0x20}
    local pkg=newHud{fullName='/Game/Pal/Blueprint/UI/Default__WBP_Ingame_PlayerGauge_Separated_C'}
    local dead=newHud();dead.alive=false
    for _,h in ipairs({cdo,arch,pkg,dead}) do equip(h,newWeapon(100,100));announce(PATH,h) end
    W.advance(31000)
    assert(#W.constructed==0 and W.writes==0,'adopted something that is not a live HUD')
    for _,h in ipairs({cdo,arch,pkg}) do assert(not ours(h)) end
    -- a real HUD arriving afterwards is still adopted
    local hud=newHud();equip(hud,newWeapon(100,100));announce(PATH,hud);W.advance(700)
    expectShown(hud,100,CYAN,'real HUD after the others')
    -- the same objects already existing at load are refused by the load pass too
    boot(function()
        cdo=newHud{flags=0x10};arch=newHud{flags=0x20}
        pkg=newHud{fullName='/Game/Pal/Blueprint/UI/Default__WBP_Ingame_PlayerGauge_Separated_C'}
        for _,h in ipairs({cdo,arch,pkg}) do equip(h,newWeapon(100,100)) end
    end)
    W.advance(31000)
    assert(#W.constructed==0 and W.writes==0,'the load pass adopted something that is not a live HUD')
    for _,h in ipairs({cdo,arch,pkg}) do assert(not ours(h)) end
end

-- 5. widgets are created once per HUD, inside Canvas_WeaponInfo, with the icon's geometry
do
    local hud,weapon=start(100,100)
    local bar,label=ours(hud)
    assert(bar and label and #W.constructed==2)
    assert(bar.parent==hud.Canvas_WeaponInfo and label.parent==hud.Canvas_WeaponInfo,'not inside Canvas_WeaponInfo')
    assert(W.constructed[1].outer==hud.WidgetTree and W.constructed[2].outer==hud.WidgetTree,'outer is the widget tree')
    assert(bar.WidgetStyle==hud.ProgressBar_CoolProgress.WidgetStyle,'native bar style')
    same(bar.BorderPadding,{X=0,Y=0})
    local a=bar.Slot.anchors;assert(a.Minimum.X==1 and a.Minimum.Y==0.5 and a.Maximum.X==1 and a.Maximum.Y==0.5)
    same(bar.Slot.align,{X=1,Y=0});same(bar.Slot.pos,{X=68,Y=35});same(bar.Slot.size,{X=30,Y=3});assert(bar.Slot.z==20)
    a=label.Slot.anchors;assert(a.Minimum.X==1 and a.Maximum.Y==0.5)
    same(label.Slot.align,{X=1,Y=1});same(label.Slot.pos,{X=68,Y=33});same(label.Slot.size,{X=46,Y=14});assert(label.Slot.z==21)
    assert(label.Font.Size==9 and label.Font.FontMaterial==nil,'small font without material')
    assert(hud.Text_WeaponName.Font.Size==18 and hud.Text_WeaponName.Font.FontMaterial=='native material','native name font untouched')
    assert(label.justification==2)
    same(label.shadow,{R=0,G=0,B=0,A=1});same(label.shadowOffset,{X=1,Y=1})
    assert(count(W.logs,'Widgets created inside weapon tile')==1)
    -- announced again, many ticks: still one pair
    announce(PATH,hud);W.advance(31000)
    assert(#W.constructed==2 and #hud.Canvas_WeaponInfo.children==4 and ours(hud)==bar,'created twice')
    assert(count(W.logs,'Widgets created inside weapon tile')==1)
    -- the native widgets are never moved or removed
    assert(hud.Icon_Weapon.parent==hud.Canvas_WeaponInfo and hud.Icon_Weapon.visibility==0)
    same(hud.Icon_Weapon.Slot.pos,{X=10,Y=20})
end

-- 6. percent, colours, text and visibility over the range of ratios
do
    local cases={
        {100,100,1,100,CYAN,'full'},{50,100,0.5,50,CYAN,'half'},
        {25,100,0.25,25,CYAN,'between 0.20 and 0.30 there is no middle colour'},
        {20,100,0.20,20,CYAN,'exactly 0.20 is not low'},{1999,10000,0.1999,20,RED,'just under 0.20'},
        {10,100,0.10,10,RED,'low'},
        {0,100,0,0,RED,'empty'},{150,100,1,100,CYAN,'above the maximum is clamped'},
        {-5,100,0,0,RED,'negative is clamped'}}
    local hud,weapon=start(100,100)
    for _,c in ipairs(cases) do
        weapon.ownWeaponDynamicData.cur,weapon.ownWeaponDynamicData.max=c[1],c[2]
        W.advance(300)
        expectShown(hud,c[4],c[5],c[6])
        local bar=ours(hud);assert(math.abs(bar.percent-c[3])<1e-9,c[6]..': bar percent '..bar.percent)
    end
    -- each of them as the first reading of a fresh HUD too
    for _,c in ipairs(cases) do
        local h,w=start(c[1],c[2])
        expectShown(h,c[4],c[5],'first reading, '..c[6])
        assert(math.abs(ours(h).percent-c[3])<1e-9)
    end
    -- the text follows the percentage when it changes and comes back after a hide
    local h,w=start(100,100)
    for _,v in ipairs({50,49,49,100,1}) do
        w.ownWeaponDynamicData.cur=v;W.advance(300);expectShown(h,v,v<20 and RED or CYAN,'text '..v)
    end
end

-- 7. an unusable maximum hides both, and the next good reading brings them back
do
    local nan=0/0
    local hud,weapon=start(100,100)
    local dyn=weapon.ownWeaponDynamicData
    for _,bad in ipairs({{50,0},{50,-10},{nan,100},{50,nan},{nan,nan}}) do
        dyn.cur,dyn.max=bad[1],bad[2];W.advance(300)
        expectHidden(hud,'max '..tostring(bad[2])..' cur '..tostring(bad[1]))
        dyn.cur,dyn.max=60,100;W.advance(300);expectShown(hud,60,CYAN,'back after bad reading')
    end
    assert(count(W.logs,'ERROR')==0,'a bad reading is not an error')
end

-- 8. riding, hidden tile or icon, invalid weapon or data hide both
do
    local hud,weapon=start(80,100)
    hud.isRiding=true;W.advance(300);expectHidden(hud,'riding')
    hud.isRiding=false;W.advance(300);expectShown(hud,80,CYAN,'dismounted')
    for _,v in ipairs({1,2}) do
        hud.Canvas_WeaponInfo.visibility=v;W.advance(300);expectHidden(hud,'canvas hidden '..v)
        hud.Canvas_WeaponInfo.visibility=0;W.advance(300);expectShown(hud,80,CYAN,'canvas back')
        hud.Icon_Weapon.visibility=v;W.advance(300);expectHidden(hud,'icon hidden '..v)
        hud.Icon_Weapon.visibility=0;W.advance(300);expectShown(hud,80,CYAN,'icon back')
    end
    hud.nowHasWeapon={};W.advance(300);expectHidden(hud,'no weapon reference')
    equip(hud,weapon);W.advance(300);expectShown(hud,80,CYAN,'weapon back')
    weapon.alive=false;W.advance(300);expectHidden(hud,'invalid weapon')
    weapon.alive=true;W.advance(300);expectShown(hud,80,CYAN,'weapon valid again')
    local dyn=weapon.ownWeaponDynamicData
    weapon.ownWeaponDynamicData=nil;W.advance(300);expectHidden(hud,'missing dynamic data')
    weapon.ownWeaponDynamicData=dyn;dyn.alive=false;W.advance(300);expectHidden(hud,'invalid dynamic data')
    dyn.alive=true;W.advance(300);expectShown(hud,80,CYAN,'dynamic data back')
    assert(count(W.logs,'ERROR')==0)
end

-- 9. a destroyed HUD is left alone
do
    local hud=start(80,100)
    local writes=W.writes
    die(hud);W.advance(5000)
    assert(W.writes==writes and count(W.logs,'ERROR')==0,'touched a destroyed HUD')
end

-- 10. the bare-hands icon wins and the bar steps aside
do
    local hud,weapon=start(80,100)
    local menu,source,fist=newMenu();announce(MENU,menu);W.advance(700)
    expectShown(hud,80,CYAN,'menu known, a weapon is selected')
    menu.CachedSelectedWeaponListWidget=source;W.advance(300)
    expectHidden(hud,'bare hands selected')
    assert(hud.Icon_Weapon.Brush.ResourceObject==fist and hud.Icon_Weapon.visibility==3 and hud.Text_WeaponName.text=='Mains nues')
    menu.CachedSelectedWeaponListWidget=new(Widget,'weapon row');W.advance(300)
    assert(hud.Icon_Weapon.visibility==1 and hud.Text_WeaponName.text=='','fist not cleared')
    expectHidden(hud,'the native HUD has not refreshed its icon yet')
    hud.Icon_Weapon.visibility=0;hud.Icon_Weapon.Brush.ResourceObject=new(Widget,'pickaxe icon');hud.Text_WeaponName.text='Pickaxe'
    W.advance(300);expectShown(hud,80,CYAN,'weapon selected again')
    assert(hud.Text_WeaponName.text=='Pickaxe','a real weapon name must stay')
    menu.CachedSelectedWeaponListWidget=source;W.advance(300);expectHidden(hud,'bare hands again')
    hud.isRiding=true;W.advance(300)
    expectHidden(hud,'riding with bare hands');assert(hud.Icon_Weapon.visibility==1,'fist shown while riding')
end

-- 11. a second HUD gets its own widgets and the first one's are removed
for _,firstAlive in ipairs({true,false}) do
    local hud1=start(80,100)
    local menu,source=newMenu();announce(MENU,menu);W.advance(700)
    menu.CachedSelectedWeaponListWidget=source;W.advance(300)
    local bar1,label1=ours(hud1);assert(bar1 and label1 and hud1.Icon_Weapon.visibility==3)
    if not firstAlive then die(hud1) else W.huds={} end
    local hud2=newHud();equip(hud2,newWeapon(25,100))
    announce(PATH,hud2);W.advance(700)
    local bar2,label2=ours(hud2)
    assert(bar2 and label2 and bar2~=bar1 and label2~=label1,'second HUD shares widgets')
    assert(bar1.parent==nil and label1.parent==nil and (bar1.removed or 0)>=1 and (label1.removed or 0)>=1,'first widgets not removed')
    assert(#hud2.Canvas_WeaponInfo.children==4 and bar2.parent==hud2.Canvas_WeaponInfo)
    if firstAlive then
        assert(not ours(hud1) and #hud1.Canvas_WeaponInfo.children==2,'first HUD keeps our widgets')
        assert(hud1.Icon_Weapon.visibility==1 and hud1.Text_WeaponName.text=='','first HUD keeps the fist')
    end
    expectHidden(hud2,'bare hands on the second HUD')
    assert(hud2.Icon_Weapon.Brush.ResourceObject~=W.invisible and hud2.Icon_Weapon.visibility==3)
    menu.CachedSelectedWeaponListWidget=new(Widget,'weapon row');W.advance(300)
    hud2.Icon_Weapon.visibility=0;W.advance(300) -- the native HUD shows its own icon again
    expectShown(hud2,25,CYAN,'second HUD')
    assert(#W.constructed==4 and count(W.logs,'Widgets created inside weapon tile')==2)
    if not firstAlive then -- a destroyed HUD is never adopted again
        announce(PATH,hud1);W.advance(31000)
        assert(#W.constructed==4,'old HUD adopted again')
    end
end

-- 12. errors: logged once, the bar hides, and it is back on the next good tick
do
    local hud,weapon=start(80,100)
    local dyn=weapon.ownWeaponDynamicData
    function dyn:GetDurability() error('engine says no',0) end
    W.advance(300)
    expectHidden(hud,'error');assert(count(W.logs,'engine says no')==1,'error not logged')
    W.advance(5000)
    assert(count(W.logs,'ERROR')==1 and count(W.logs,'engine says no')==1,'error logged more than once')
    assert(W.logs[#W.logs]:find('ERROR engine says no',1,true),'error line')
    function dyn:GetDurability() return self.cur end
    W.advance(300);expectShown(hud,80,CYAN,'recovered')
    -- a tree that is not ready yet: reported once, nothing half-built, retried until it works
    local late=newHud{};late.WidgetTree.alive=false;equip(late,newWeapon(70,100))
    W.huds={late};announce(PATH,late);W.advance(5000)
    assert(not ours(late) and count(W.logs,'HUD tree unavailable')==1,'tree error')
    late.WidgetTree.alive=true;W.advance(300)
    expectShown(late,70,CYAN,'tree ready')
end

-- 13. a tick in which nothing changed writes nothing, and every way back from hidden writes it all again
do
    local function quiet(why)
        W.advance(250);local before=W.writes
        W.advance(2000);assert(W.writes==before,why..': '..(W.writes-before)..' writes in 8 unchanged ticks')
    end
    local function drawn(hud,percent,ratio,col,why)
        expectShown(hud,percent,col,why);assert(math.abs(ours(hud).percent-ratio)<1e-9,why..': bar percent '..ours(hud).percent)
    end
    local hud,weapon=start(80,100)
    quiet('tool in hand')
    hud.isRiding=true;W.advance(250);expectHidden(hud,'riding');quiet('mounted')
    do local bar,label=ours(hud);bar.percent=0;bar.fill=nil;label.text='';label.textColor=nil end
    hud.isRiding=false;W.advance(250);drawn(hud,80,0.8,CYAN,'dismounted');quiet('after the mount')
    hud.Canvas_WeaponInfo.visibility=2;W.advance(250);expectHidden(hud,'canvas hidden');quiet('canvas hidden')
    hud.Canvas_WeaponInfo.visibility=0;W.advance(250);drawn(hud,80,0.8,CYAN,'canvas back');quiet('canvas back')
    local menu,source=newMenu();announce(MENU,menu);W.advance(700)
    quiet('menu known, a weapon is selected')
    menu.CachedSelectedWeaponListWidget=source;W.advance(250);expectHidden(hud,'bare hands');quiet('bare hands')
    menu.CachedSelectedWeaponListWidget=new(Widget,'weapon row');W.advance(250)
    hud.Icon_Weapon.visibility=0;W.advance(250);drawn(hud,80,0.8,CYAN,'weapon back');quiet('weapon back')
    -- the same reading is drawn again after an error, hidden by a bad reading, or on a new HUD;
    -- whatever happened to the widgets while hidden is not trusted
    local function forgotten() local bar,label=ours(hud);bar.percent=0;bar.fill=nil;label.text='';label.textColor=nil end
    local dyn=weapon.ownWeaponDynamicData
    function dyn:GetDurability() error('engine says no',0) end
    W.advance(250);expectHidden(hud,'error');forgotten()
    function dyn:GetDurability() return self.cur end
    W.advance(250);drawn(hud,80,0.8,CYAN,'first good tick after the error');quiet('after the error')
    dyn.max=0;W.advance(250);expectHidden(hud,'bad maximum');forgotten();dyn.max=100
    W.advance(250);drawn(hud,80,0.8,CYAN,'good reading after a bad one');quiet('after a bad reading')
    W.huds={};local second=newHud();equip(second,weapon);announce(PATH,second);W.advance(700)
    drawn(second,80,0.8,CYAN,'new HUD, same reading as the old one');quiet('new HUD')
    -- the bar follows a ratio that moves inside one rounded percent; the colour follows 0.20 exactly
    local h,w=start(5000,10000);local d=w.ownWeaponDynamicData
    for _,c in ipairs({{5004,50,0.5004,CYAN},{4996,50,0.4996,CYAN},{2004,20,0.2004,CYAN},{2000,20,0.20,CYAN},
        {1999,20,0.1999,RED},{2000,20,0.20,CYAN},{3,0,0.0003,RED},{0,0,0,RED}}) do
        d.cur=c[1];W.advance(250);drawn(h,c[2],c[3],c[4],'ratio '..c[3]);quiet('ratio '..c[3])
    end
end

-- 14. the Kismet system library is asked for once, at the first tool tick
do
    boot()
    assert(W.libraryCalls==0,'library fetched at load')
    local hud=newHud();local weapon=newWeapon(80,100);equip(hud,weapon)
    announce(PATH,hud);W.advance(700)
    assert(W.libraryCalls==1,'first tool tick: '..W.libraryCalls)
    weapon.ownWeaponDynamicData.cur=20;W.advance(5000)
    hud.isRiding=true;W.advance(500);hud.isRiding=false;W.advance(500)
    assert(W.libraryCalls==1,'library fetched again: '..W.libraryCalls)
    expectShown(hud,20,CYAN,'drawn with the kept library')
end

print=realprint
print('PASS: no work without a HUD; announced and scanned adoption; default objects refused; widgets once per HUD inside Canvas_WeaponInfo; ratios, colours, text and clamping; no writes on an unchanged tick, everything redrawn after any hide; NaN/zero maximum; riding, hidden tile/icon, invalid weapon/data; unarmed priority; second HUD cleanup; error logged once and recovery; library fetched once.')
