-- Behavioral harness: menu lifecycle, disabled buttons, key overlap, native routes.
local jobs, hooks, notifications, keys, logs = {}, {}, {}, {}, {}
local time, windows, count = 0, {}, {single=0,all=0}
local function obj(name)
 return {name=name,valid=true,visible=true,enabled=true,visibility=0,
  IsValid=function(s)return s.valid end, GetFName=function(s)return {ToString=function()return s.name end}end,
  GetFullName=function(s)return s.name end, HasAnyFlags=function(s)return s.cdo or false end,
  IsVisible=function(s)return s.visible end,GetIsEnabled=function(s)return s.enabled end,
  GetVisibility=function(s)return s.visibility end,IsActivated=function(s)return s.active end,
  IsA=function(s)return s.children~=nil end,
  GetChildrenCount=function(s)return #s.children end,GetChildAt=function(s,i)return s.children[i+1]end}
end
local function label(name,text)
 local x=obj(name);x.text=text
 x.GetText=function(s)return {ToString=function()return s.text end}end
 x.SetText=function(s,t)s.text=t end
 return x
end
local singleText=label('Text_Main','Repair')
local allText=label('BP_PalTextBlock_C_44','Repair All')
local single,all=obj('single'),obj('all')
single.Text_Main=singleText;single.WBP_PalInvisibleButton=obj('hit')
all.WBP_PalInvisibleButton=obj('hit');all.WidgetTree=obj('tree');all.WidgetTree.RootWidget=obj('root');all.WidgetTree.RootWidget.children={allText}
all.WBP_PalInvisibleButton.visibility=4 -- observed native Repair All default
local w=obj('repair');w.GetFullName=function()error('GetFullName: nothing may read the window name')end;w.active=true;w.CanAllRepair=true;w.Overlay_Repairing=obj('overlay');w.Overlay_Repairing.visible=false
w.WBP_IngameMenu_Repair=obj('panel');w.WBP_IngameMenu_Repair.WBP_IngameMenu_RepairButton=single;w.WBP_IngameMenu_Repair.WBP_IngameMenu_RepairAllButton=all
w.BndEvt__WBP_RepairEquipment_WBP_IngameMenu_Repair_K2Node_ComponentBoundEvent_2_OnClickedRepairButton__DelegateSignature=function()count.single=count.single+1 end
w.BndEvt__WBP_RepairEquipment_WBP_IngameMenu_Repair_K2Node_ComponentBoundEvent_3_OnClickedRepairAllButton__DelegateSignature=function()count.all=count.all+1 end
package.preload.UEHelpers=function()return {GetKismetTextLibrary=function()return {Conv_StringToText=function(_,s)return s end}end}end
package.preload.durability=function()return {}end
local layoutLater
package.preload.equipment_layout=function()return function(later)layoutLater=later end end
Key={R=82};ModifierKey={CONTROL=17}
function RegisterKeyBind(_,a,b)keys[b and 'all' or 'single']=b or a end
-- the loader's async-thread callbacks can be lost: only the game-thread timers are allowed
function ExecuteWithDelay()error('ExecuteWithDelay: use ExecuteInGameThreadWithDelay',2)end
function ExecuteInGameThread()error('ExecuteInGameThread: use ExecuteInGameThreadWithDelay',2)end
function ExecuteInGameThreadWithDelay(ms,fn)jobs[#jobs+1]={at=time+ms,fn=fn}end
function LoopInGameThreadWithDelay()end
local searched={}
function FindAllOf(c)searched[#searched+1]=c;return windows end
function StaticFindObject(path)local x=obj(path);x.GetAddress=function()return path end;return x end
function RegisterHook(path,fn)hooks[path]=fn end
function NotifyOnNewObject(path,fn)notifications[path]=fn end
local oldprint=print
function print(s)logs[#logs+1]=s end
local function advance(ms)
 local target=time+ms
 while true do
  table.sort(jobs,function(a,b)return a.at<b.at end)
  if not jobs[1] or jobs[1].at>target then break end
  local j=table.remove(jobs,1);time=j.at;j.fn()
 end
 time=target
end
local function press(mode)keys[mode]();advance(400)end
local function loadMain()dofile((arg[1] or './')..'Scripts/main.lua')end
for _,missing in ipairs({'ExecuteInGameThreadWithDelay','LoopInGameThreadWithDelay'})do
 local kept=_G[missing];_G[missing]=nil
 local ok,err=pcall(loadMain)
 _G[missing]=kept
 assert(not ok and tostring(err):find('Palished needs a UE4SS loader with ExecuteInGameThreadWithDelay and LoopInGameThreadWithDelay',1,true),'loading without '..missing)
 assert(not next(keys) and not next(notifications) and #logs==0,'nothing may load before the loader check')
end
loadMain()
press('single');press('all');assert(count.single==0 and count.all==0,'acted outside menu')
local ran=0;layoutLater(100,function()ran=ran+1 end);advance(99);assert(ran==0,'later fired early');advance(1);assert(ran==1,'the layout module gets a game-thread timer')
layoutLater(0,function()error('boom')end);advance(1);assert(logs[#logs]:find('ERROR',1,true) and logs[#logs]:find('boom',1,true));logs[#logs]=nil
windows={w};for _,fn in pairs(notifications)do fn(w)end;advance(650)
assert(singleText.text=='Repair [R]' and allText.text=='Repair All [Ctrl+R]','labels')
local function labelLogs(text)local n=0;for _,l in ipairs(logs)do if l:find('Label: '..text..'\n',1,true)then n=n+1 end end;return n end
assert(labelLogs('Repair [R]')==1 and labelLogs('Repair All [Ctrl+R]')==1,'one line per real SetText, with the new text')
for _,fn in pairs(hooks)do fn({get=function()return w end})end;advance(200)
assert(singleText.text=='Repair [R]' and allText.text=='Repair All [Ctrl+R]','duplicate suffix')
assert(labelLogs('Repair [R]')==1 and labelLogs('Repair All [Ctrl+R]')==1,'no line when nothing was set')
press('single');assert(count.single==1 and count.all==0,'R route')
press('all');assert(count.single==1 and count.all==1,'Ctrl route')
keys.single();keys.all();advance(400);assert(count.single==1 and count.all==2,'double dispatch R then Ctrl')
keys.all();keys.single();advance(400);assert(count.single==1 and count.all==3,'double dispatch Ctrl then R')
single.WBP_PalInvisibleButton.visibility=3;press('single');assert(count.single==1,'disabled hit-test button accepted');single.WBP_PalInvisibleButton.visibility=0
w.CanAllRepair=false;press('all');assert(count.all==3,'repair-all disallowed');w.CanAllRepair=true
all.WBP_PalInvisibleButton.visibility=3;press('all');assert(count.all==3,'disabled Repair All');all.WBP_PalInvisibleButton.visibility=4
w.Overlay_Repairing.visible=true;press('single');press('all');assert(count.single==1 and count.all==3,'repair overlay ignored');w.Overlay_Repairing.visible=false
w.active=false;press('single');press('all');assert(count.single==1 and count.all==3,'inactive/cached menu');w.active=true
w.visible=false;press('single');assert(count.single==1,'hidden menu');w.visible=true
w.valid=false;press('all');assert(count.all==3,'destroyed menu');w.valid=true
keys.single();advance(35);keys.all();advance(400);assert(count.single==2 and count.all==3,'cooldown')
singleText.text='Réparer';allText.text='Tout réparer'
for _,fn in pairs(hooks)do fn({get=function()return w end})end;advance(200)
assert(singleText.text=='Réparer [R]' and allText.text=='Tout réparer [Ctrl+R]','localization lost')
-- a label that is empty or still the design-time placeholder is not suffixed
for _,placeholder in ipairs({'','TEXT'})do
 singleText.text=placeholder;allText.text=placeholder;local before=#logs
 for _,fn in pairs(hooks)do fn({get=function()return w end})end;advance(200)
 assert(singleText.text==placeholder and allText.text==placeholder and #logs==before,'placeholder label suffixed: "'..placeholder..'"')
end
-- a mod loaded while a repair window already exists: one pass at load, no notice needed, no later scan
local function reload()
 singleText.text='Repair';allText.text='Repair All'
 jobs,hooks,notifications,keys={},{},{},{}
 loadMain()
end
w.cdo=true;windows={w};reload();advance(0)
assert(singleText.text=='Repair' and allText.text=='Repair All','a class default object was labeled at load')
w.cdo=false;windows={w};reload()
assert(singleText.text=='Repair' and not next(hooks),'nothing may happen before the load pass runs')
advance(0)
assert(singleText.text=='Repair [R]' and allText.text=='Repair All [Ctrl+R]' and next(hooks),'existing window not adopted at load')
singleText.text='Repair';allText.text='Repair All';advance(40000)
assert(singleText.text=='Repair' and allText.text=='Repair All','the load pass must not repeat')
local was=count.single;press('single');assert(count.single==was+1,'R works after a reload '..was..' '..count.single)
-- the Repair All label is found at any depth of that button's own tree, and no search is made for text blocks
local deep=allText;for i=1,20 do local p=obj('panel'..i);p.children={deep};deep=p end
all.WidgetTree.RootWidget.children={deep};singleText.text='Repair';allText.text='Repair All';windows={w};reload();advance(0)
assert(allText.text=='Repair All [Ctrl+R]','label in a deep tree')
for _,c in ipairs(searched)do assert(c=='WBP_RepairEquipment_C','global search for '..tostring(c))end
for _,line in ipairs(logs)do assert(not line:find('ERROR',1,true),line)end
oldprint('PASS: menu-only actions; hidden/inactive/destroyed guards; disabled hit testing; no repair during pending repair; native single/all routes; Ctrl priority both orders; cooldown; localized idempotent labels.')
