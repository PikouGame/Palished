-- Behavioral harness: inventory equipment columns, driven through the real
-- equipment_layout.lua on a fake widget tree. Native numbers come from the live
-- inventory (gap 16.98499; Accessory 406 -> 393.98999; Food 624 -> 611.98999;
-- content bottom 585.98999; right gaps 16.4974975).
local root=arg[1] or './'
local realprint=print
local EPS=1e-6
local H=1000 -- height of Canvas_EquipmentSlots
local NAMES={'Weapon_00','Accessory_01','Food_00','Head','Body','Shield','Glider','Modifier'}

local function copy(t) local c={} for k,v in pairs(t) do c[k]=type(v)=='table' and copy(v) or v end return c end
local function isnum(n) return type(n)=='number' and n==n end
local function vec(v) assert(type(v)=='table' and isnum(v.X) and isnum(v.Y),'bad vector') end
local function near(a,b,what) assert(math.abs(a-b)<=EPS,(what or 'value')..': '..tostring(a)..' ~= '..tostring(b)) end

local writes,logs,jobs,notify,now={},{},{},{},0
local nextId=0
local function stubobj(name,t)
    t=t or {};nextId=nextId+1
    t.name=name;t.id=nextId;t.alive=true;t.flags=t.flags or 0
    function t:IsValid() return self.alive end
    function t:HasAnyFlags(mask) assert(math.type(mask)=='integer') return self.flags&mask~=0 end
    function t:GetParent() return self.parent end
    function t:GetDesiredSize()
        -- the engine reports nothing until the layout has been prepared
        if not self.window.prepared then return {X=0,Y=0} end
        return copy(self.desired)
    end
    return t
end
local SlotMT={}
SlotMT.__index=function(s,k)
    if k=='Padding' then return copy(s._padding) end
    return SlotMT[k]
end
function SlotMT.IsValid(s) return s.alive end
function SlotMT.IsA(s,path) assert(type(path)=='string') return s.kind==path end
function SlotMT.GetPosition(s) return copy(s.pos) end
function SlotMT.GetSize(s) return copy(s.size) end
function SlotMT.GetAnchors(s) return copy(s.anchors) end
function SlotMT.GetAlignment(s) return copy(s.align) end
local function record(s,fn,arg) writes[#writes+1]={slot=s.name,fn=fn,arg=copy(arg)} end
function SlotMT.SetPosition(s,v) vec(v) record(s,'SetPosition',v) s.pos=copy(v) end
function SlotMT.SetAnchors(s,a)
    vec(a.Minimum) vec(a.Maximum) record(s,'SetAnchors',a) s.anchors=copy(a)
end
function SlotMT.SetPadding(s,p)
    assert(s.kind=='/Script/UMG.VerticalBoxSlot')
    for _,k in ipairs({'Left','Top','Right','Bottom'}) do assert(isnum(p[k]),'padding '..k) end
    record(s,'SetPadding',p) s._padding=copy(p)
end
local function slot(name,kind,t)
    t.name=name;t.kind=kind;t.alive=true
    return setmetatable(t,SlotMT)
end
local function topOf(s) -- where the slot's top edge really is
    return s.pos.Y+s.anchors.Minimum.Y*H-s.align.Y*s.size.Y
end

-- one inventory window. spec tops are the original native tops.
local function build(o)
    o=o or {}
    local A=o.anchor or 0
    local win=stubobj('window',{flags=o.flags,prepared=false})
    function win:ForceLayoutPrepass() self.prepared=true end
    win.Canvas_EquipmentSlots=stubobj('canvas',{window=win})
    win.Canvas_EquipmentSlots.Slot=slot('canvas','/Script/UMG.CanvasPanelSlot',{size={X=800,Y=H},pos={X=0,Y=0},
        anchors={Minimum={X=0,Y=0},Maximum={X=0,Y=0}},align={X=0,Y=0}})
    local parts={window=win}
    -- name, original top, slot height, desired (content) height, anchor, alignment, padding.Left, levels below the vertical box
    local spec={
        Weapon_00={top=100,height=277.005,content=177,anchor=A,align=0,left=24,deep=false},
        Accessory_01={top=406,height=201.01501,content=192,anchor=0,align=0.5,left=8,deep=true,minX=0.1,maxX=0.6},
        Food_00={top=624,height=120,content=120,anchor=1,align=1,left=0,deep=false},
        Head={top=120,height=80,content=80,anchor=A,align=0},
        Body={top=230,height=90,content=80,anchor=0,align=0},
        Shield={top=330,height=100,content=80,anchor=0.5,align=0.5},
        Glider={top=440,height=90,content=80,anchor=1,align=1},
        Modifier={top=530,height=80,content=80,anchor=0,align=0}}
    for k,v in pairs(o.spec or {}) do for f,x in pairs(v) do spec[k][f]=x end end
    for _,name in ipairs(NAMES) do
        local s=spec[name]
        local position=s.top-s.anchor*H+s.align*s.height
        local section=stubobj('section '..name,{window=win,desired={X=300,Y=s.content}})
        section.Slot=slot('section '..name,'/Script/UMG.CanvasPanelSlot',{pos={X=7,Y=position},size={X=300,Y=s.height},
            anchors={Minimum={X=s.minX or 0,Y=s.stretch and 0 or s.anchor},Maximum={X=s.maxX or 0,Y=s.stretch and 1 or s.anchor}},
            align={X=0,Y=s.align}})
        local wrapper=stubobj('wrapper '..name,{window=win})
        wrapper.Slot=slot('cases '..name,'/Script/UMG.VerticalBoxSlot',{parent=section,Parent=section,
            _padding={Left=s.left or 5,Top=3,Right=2,Bottom=1}})
        local item=stubobj('item '..name,{window=win})
        if s.deep then
            local row=stubobj('row '..name,{window=win,parent=wrapper})
            row.Slot=slot('row '..name,'/Script/UMG.HorizontalBoxSlot',{})
            item.parent=row
        else
            item.parent=wrapper
        end
        parts[name]={section=section,cases=wrapper.Slot,item=item,spec=s}
        if not o.missing or o.missing~=name then win['WBP_ItemSlotButton_'..name]=item end
    end
    return win,parts
end

-- `existing` fills the windows that are already in the game when the mod loads; without it the game is empty at load
local function load(existing)
    writes,logs,jobs,notify,now={},{},{},{},0
    local windows={}
    local env={windows=windows}
    function NotifyOnNewObject(path,fn) notify[path]=fn end
    function FindAllOf(class)
        assert(class=='WBP_InventoryEquipment_C','unexpected class '..tostring(class))
        if #windows==0 then return nil end
        return {table.unpack(windows)}
    end
    function print(...) logs[#logs+1]=table.concat({...},'\t') end
    -- the loader's async-thread callbacks can be lost: the module only gets `later`
    function ExecuteWithDelay() error('ExecuteWithDelay: use ExecuteInGameThreadWithDelay',2) end
    function ExecuteInGameThread() error('ExecuteInGameThread: use ExecuteInGameThreadWithDelay',2) end
    local function later(ms,fn)
        assert(isnum(ms) and type(fn)=='function','Ref was not function')
        jobs[#jobs+1]={at=now+ms,fn=fn,seq=#jobs}
    end
    function env.advance(ms)
        local target=now+ms
        while true do
            table.sort(jobs,function(a,b)return a.at<b.at or (a.at==b.at and a.seq<b.seq)end)
            if not jobs[1] or jobs[1].at>target then break end
            local j=table.remove(jobs,1);now=j.at;j.fn()
        end
        now=target
    end
    if existing then existing(windows) end
    dofile(root..'Scripts/equipment_layout.lua')(later)
    -- NotifyOnNewObject receives the class path
    env.announce=function(win) local fn
        for p,f in pairs(notify) do assert(p:find('WBP_InventoryEquipment_C',1,true));fn=f end
        fn(win)
    end
    if not existing then env.advance(0) end -- the load pass finds an empty game
    return env
end

local FULL='Equipment columns aligned; Sphere Module follows Accessory bottom.'
local LEFT='Left equipment column aligned.'
local function logTexts() local t={} for _,l in ipairs(logs) do t[#t+1]=l:gsub('^%[[^%]]*%] ',''):gsub('\n$','') end return t end
local function expectLog(text)
    local t=logTexts();assert(#t==1 and t[1]==text,'log: '..table.concat(t,' | '))
    assert(logs[1]:sub(-1)=='\n','log line ends with a newline')
end
local function expectQuiet() assert(#writes==0 and #logs==0,'wrote '..#writes..' / logged '..#logs) end
local function run(win,env)
    env=env or load()
    env.windows[1]=win
    env.announce(win);env.advance(100)
    return env
end
local function wroteTo(name) for _,w in ipairs(writes) do if w.slot==name then return true end end return false end
-- an engine position for a slot whose top edge ends up at `top`
local function expectTop(s,top,anchor,what)
    near(topOf(s),top,what..' top')
    near(s.anchors.Minimum.Y,anchor,what..' anchor min');near(s.anchors.Maximum.Y,anchor,what..' anchor max')
end

-- 1. first pass, with the native numbers
for _,A in ipairs({0,0.5}) do
    local win,p=build{anchor=A}
    local env=load()
    run(win,env)
    -- left padding comes from Weapon; the other three sides stay
    for _,n in ipairs({'Accessory_01','Food_00'}) do
        local pad=p[n].cases.Padding
        near(pad.Left,24,n..' left padding');near(pad.Top,3,'top');near(pad.Right,2,'right');near(pad.Bottom,1,'bottom')
    end
    assert(p.Weapon_00.cases.Padding.Left==24 and not wroteTo('cases Weapon_00'),'Weapon padding is the source')
    -- left column: Weapon fixed, gap 16.98499 below it
    local w,a,f=p.Weapon_00.section.Slot,p.Accessory_01.section.Slot,p.Food_00.section.Slot
    near(topOf(w),100,'weapon top');assert(not wroteTo('section Weapon_00'))
    expectTop(a,393.98999,A,'Accessory')
    expectTop(f,611.98999,A,'Food')
    near(a.pos.Y,393.98999-A*H+0.5*201.01501,'Accessory position')
    near(f.pos.Y,611.98999-A*H+1*120,'Food position')
    near(a.pos.X,7,'x kept');near(f.pos.X,7,'x kept')
    near(a.anchors.Minimum.X,0.1,'anchor X kept');near(a.anchors.Maximum.X,0.6,'anchor X kept')
    near(a.size.Y,201.01501,'size kept');near(f.size.Y,120,'size kept');near(a.size.X,300,'size kept')
    -- right column: Head fixed, the rest spread to the Accessory content bottom (585.98999), 16.4974975 apart
    local tops={}
    for i,n in ipairs({'Head','Body','Shield','Glider','Modifier'}) do tops[i]=p[n].section.Slot end
    near(topOf(tops[1]),120,'head top');assert(not wroteTo('section Head'))
    local expected={120,216.4974975,312.994995,409.4924925,505.98999}
    for i=2,5 do expectTop(tops[i],expected[i],A,'right '..i) end
    near(topOf(tops[5])+80,585.98999,'right column bottom')
    near(tops[3].pos.Y,expected[3]-A*H+0.5*100,'Shield position (centre aligned)')
    near(tops[4].pos.Y,expected[4]-A*H+1*90,'Glider position (bottom aligned)')
    for i=2,5 do near(tops[i].pos.X,7,'x kept');near(tops[i].size.Y,({0,90,100,90,80})[i],'size kept') end
    expectLog(FULL)
    -- no section other than the six was written, and never a size
    for _,w in ipairs(writes) do
        assert(w.fn=='SetPadding' or w.fn=='SetAnchors' or w.fn=='SetPosition',w.fn)
        assert(w.slot~='section Weapon_00' and w.slot~='section Head' and w.slot~='cases Weapon_00')
    end
    -- the second pass (600 ms) and the later seconds change nothing and print nothing
    local nw,nl=#writes,#logs
    env.advance(3000)
    assert(#writes==nw and #logs==nl,'second pass wrote or logged')
end

-- 2. a window that already exists at load is found by the one load pass; nothing before it
do
    local win,p=build{}
    local env=load(function(w) w[1]=win end)
    expectQuiet()
    env.advance(0)
    expectTop(p.Accessory_01.section.Slot,393.98999,0,'Accessory');expectLog(FULL)
    local nw=#writes;env.advance(40000);assert(#writes==nw and #logs==1)
    -- a window made later without a creation notice is not looked for
    local late,q=build{}
    env.windows[2]=late;env.advance(40000)
    assert(q.Food_00.section.Slot.anchors.Minimum.Y==1,'a later scan found a window')
end

-- 2b. a class default object existing at load is refused by the load pass
do
    local env=load(function(w) w[1]=build{flags=0x10} end)
    env.advance(0);env.advance(40000)
    expectQuiet()
end

-- 3. the layout is prepared before sizes are read
do
    local win,p=build{}
    run(win)
    assert(win.prepared,'ForceLayoutPrepass not called')
    expectTop(p.Head.section.Slot,120,0,'Head')
end

-- 4. refusals that leave everything untouched
local function refused(what,o,mutate,line)
    local win,p=build(o)
    if mutate then mutate(p,win) end
    local before={}
    for _,n in ipairs(NAMES) do
        local s=p[n].section.Slot;before[n]={copy(s.pos),copy(s.anchors),copy(s.size),copy(p[n].cases.Padding)}
    end
    local env=run(win);env.advance(3000)
    for i,n in ipairs(NAMES) do
        if line and i<=3 then goto skip end -- the left column is expected to move
        local s=p[n].section.Slot
        local b=before[n]
        local function eq(a,c) for k,v in pairs(a) do if type(v)=='table' then eq(v,c[k]) else assert(v==c[k],what..': '..n..' changed') end end end
        eq(b[1],s.pos);eq(b[2],s.anchors);eq(b[3],s.size);eq(b[4],p[n].cases.Padding)
        ::skip::
    end
    if line then
        -- only the left column may have moved
        for _,n in ipairs({'Head','Body','Shield','Glider','Modifier'}) do assert(not wroteTo('section '..n),what..': right column written') end
        assert(wroteTo('section Accessory_01'),what..': left column should still be aligned');expectLog(line)
    else expectQuiet() end
    return p
end
-- padding already equal, so only a stack refusal could write anything
local EQ={Accessory_01={left=24},Food_00={left=24}}
refused('class default object',{flags=0x10})
refused('class default object, padding already equal',{flags=0x10,spec=EQ})
refused('stretched Accessory',{spec={Accessory_01={left=24,stretch=true},Food_00={left=24}}})
refused('stretched Weapon',{spec={Weapon_00={stretch=true},Accessory_01={left=24},Food_00={left=24}}})
refused('stretched Food',{spec={Food_00={left=24,stretch=true},Accessory_01={left=24}}})
refused('missing Weapon',{missing='Weapon_00'})
refused('missing Accessory',{missing='Accessory_01'})
refused('missing Food',{missing='Food_00'})
refused('negative gap',{spec={Accessory_01={left=24},Food_00={left=24,top=500}}})
refused('canvas invalid',{spec=EQ},function(p,win) win.Canvas_EquipmentSlots.alive=false end)
refused('canvas has no slot',{spec=EQ},function(p,win) win.Canvas_EquipmentSlots.Slot=nil end)
-- a missing slot, a stretched section or a negative gap on the left even stops the padding copy / right column
do
    local win,p=build({missing='Food_00'})
    run(win)
    assert(p.Accessory_01.cases.Padding.Left==8,'padding copied although a slot is missing')
end

-- 5. right-column refusals: the left column is still aligned, the right one untouched, the shorter line is logged
local function right(what,spec,mutate,o)
    o=o or {}
    local s={Accessory_01={left=24},Food_00={left=24}}
    for k,v in pairs(spec or {}) do s[k]=v end
    o.spec=s
    return refused('right: '..what,o,mutate,LEFT)
end
right('stretched Shield',{Shield={stretch=true}})
right('stretched Head',{Head={stretch=true}})
right('missing Modifier',nil,nil,{missing='Modifier'})
right('missing Head',nil,nil,{missing='Head'})
right('Head without content',{Head={content=0}})
right('Modifier without content',{Modifier={content=0}})
right('Accessory without content',{Accessory_01={left=24,content=0}})
right('too tall to fit (negative spacing)',{Glider={content=200}})
-- the left alignment itself must not depend on the right column
do
    local win,p=build({missing='Head'})
    run(win);expectLog(LEFT)
    expectTop(p.Accessory_01.section.Slot,393.98999,0,'Accessory');expectTop(p.Food_00.section.Slot,611.98999,0,'Food')
end

-- 6. padding only: positions already right, padding wrong -> aligned line without moving anything
do
    local win,p=build({})
    local env=run(win)
    for _,n in ipairs({'Accessory_01','Food_00'}) do p[n].cases._padding.Left=3 end
    logs={};writes={}
    env.announce(win);env.advance(100)
    assert(#writes==2 and wroteTo('cases Accessory_01') and wroteTo('cases Food_00'),'only the two paddings are written')
    expectLog(FULL)
    -- the chain follows Weapon, the one fixed section, keeping the Accessory -> Food gap
    logs={};writes={}
    p.Weapon_00.section.Slot.pos.Y=p.Weapon_00.section.Slot.pos.Y+5
    env.announce(win);env.advance(100)
    expectTop(p.Accessory_01.section.Slot,398.98999,0,'Accessory follows')
    expectTop(p.Food_00.section.Slot,616.98999,0,'Food follows')
    expectLog(FULL)
    -- a nudge below a hundredth of a unit is not worth a write
    logs={};writes={}
    p.Food_00.section.Slot.pos.Y=p.Food_00.section.Slot.pos.Y+0.005
    env.announce(win);env.advance(100)
    expectQuiet()
end

-- 7. two windows are handled independently
do
    local w1,p1=build({});local w2,p2=build({})
    local env=load();env.windows[1]=w1;env.windows[2]=w2
    env.announce(w1);env.advance(100)
    expectTop(p1.Food_00.section.Slot,611.98999,0,'first')
    assert(p2.Food_00.section.Slot.anchors.Minimum.Y==1,'second window untouched so far')
    env.announce(w2);env.advance(100)
    expectTop(p2.Food_00.section.Slot,611.98999,0,'second')
end

print=realprint
print('PASS: native gap/tops/content bottom on both columns for two anchors; padding copied from Weapon; X, sizes and Head untouched; second pass and late scan silent; class default object, stretched, missing, negative-gap and bad-canvas refusals; right-column refusals keep the left aligned with the shorter log line.')
