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
local w=obj('repair');w.active=true;w.CanAllRepair=true;w.Overlay_Repairing=obj('overlay');w.Overlay_Repairing.visible=false
w.WBP_IngameMenu_Repair=obj('panel');w.WBP_IngameMenu_Repair.WBP_IngameMenu_RepairButton=single;w.WBP_IngameMenu_Repair.WBP_IngameMenu_RepairAllButton=all
w.BndEvt__WBP_RepairEquipment_WBP_IngameMenu_Repair_K2Node_ComponentBoundEvent_2_OnClickedRepairButton__DelegateSignature=function()count.single=count.single+1 end
w.BndEvt__WBP_RepairEquipment_WBP_IngameMenu_Repair_K2Node_ComponentBoundEvent_3_OnClickedRepairAllButton__DelegateSignature=function()count.all=count.all+1 end
package.preload.UEHelpers=function()return {GetKismetTextLibrary=function()return {Conv_StringToText=function(_,s)return s end}end}end
package.preload.durability=function()return {}end
package.preload.equipment_layout=function()return function()end end
Key={R=82};ModifierKey={CONTROL=17}
function RegisterKeyBind(_,a,b)keys[b and 'all' or 'single']=b or a end
function ExecuteWithDelay(ms,fn)jobs[#jobs+1]={at=time+ms,fn=fn}end
function ExecuteInGameThread(fn)fn()end
function FindAllOf()return windows end
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
dofile((arg[1] or './')..'Scripts/main.lua')
press('single');press('all');assert(count.single==0 and count.all==0,'acted outside menu')
windows={w};for _,fn in pairs(notifications)do fn(w)end;advance(650)
assert(singleText.text=='Repair [R]' and allText.text=='Repair All [Ctrl+R]','labels')
for _,fn in pairs(hooks)do fn({get=function()return w end})end;advance(200)
assert(singleText.text=='Repair [R]' and allText.text=='Repair All [Ctrl+R]','duplicate suffix')
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
for _,line in ipairs(logs)do assert(not line:find('ERROR',1,true),line)end
oldprint('PASS: menu-only actions; hidden/inactive/destroyed guards; disabled hit testing; no repair during pending repair; native single/all routes; Ctrl priority both orders; cooldown; localized idempotent labels.')
