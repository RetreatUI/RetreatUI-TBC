local RUI = RetreatUITBC
if not RUI or type(RUI.tbcClassData) ~= "table" or type(RUI.weakAuraPackages) ~= "table" then return end

-- Class mechanics layered onto the shared TBC HUD engine. This keeps the
-- core renderer small while allowing class-native load rules and reminders.
local REMINDER_X, REMINDER_Y = 0, -310
local REMINDER_WIDTH, REMINDER_HEIGHT = 360, 14
local REMINDER_SPACING = 1

local function InternalVersion()
  if WeakAuras and type(WeakAuras.InternalVersion) == "function" then return WeakAuras.InternalVersion() end
  return 90
end

local function TocVersion()
  local _, _, _, toc = GetBuildInfo()
  return toc or 20506
end

local function DisplayClass(classToken)
  return classToken:sub(1, 1) .. classToken:sub(2):lower()
end

local function ClassLoad(classToken)
  return {
    class = { multi = { [classToken] = true }, single = classToken },
    spec = { multi = {} },
    use_class = true,
    use_never = false,
  }
end

local function Base(id, parent, classToken)
  return {
    id=id, parent=parent, internalVersion=InternalVersion(), tocversion=TocVersion(),
    actions={start={do_custom=false},finish={do_custom=false},init={do_custom=false}},
    animation={
      start={type="none",duration_type="seconds",easeType="none",easeStrength=3},
      main={type="none",duration_type="seconds",easeType="none",easeStrength=3},
      finish={type="none",duration_type="seconds",easeType="none",easeStrength=3},
    },
    authorOptions={}, conditions={}, config={}, information={}, load=ClassLoad(classToken),
    alpha=1, frameStrata=1,
  }
end

local function GroupTrigger()
  return {
    [1]={trigger={type="aura2",event="Health",unit="player",debuffType="HELPFUL",names={},spellIds={},subeventPrefix="SPELL",subeventSuffix="_CAST_START"},untrigger={}},
    activeTriggerMode=-10, disjunctive="any",
  }
end

local function ReminderGroup(id, classToken, children)
  local data=Base(id,nil,classToken)
  data.regionType="dynamicgroup"
  data.controlledChildren=children
  data.anchorFrameType="SCREEN"; data.anchorPoint="CENTER"; data.selfPoint="CENTER"
  data.xOffset=REMINDER_X; data.yOffset=REMINDER_Y
  data.grow="DOWN"; data.align="CENTER"; data.sort="none"; data.space=REMINDER_SPACING
  data.stagger=0; data.animate=false; data.scale=1; data.gridType="RD"; data.centerType="LR"
  data.gridWidth=20; data.rowSpace=REMINDER_SPACING; data.columnSpace=REMINDER_SPACING
  data.useLimit=false; data.limit=20; data.fullCircle=true; data.rotation=0; data.radius=200
  data.stepAngle=15; data.constantFactor="RADIUS"; data.subRegions={}; data.triggers=GroupTrigger()
  return data
end

local function CustomStateTrigger(code, events)
  return {
    [1]={trigger={type="custom",event="Health",check="event",custom_type="stateupdate",custom_hide="custom",custom=code,events=events,unit="player",debuffType="HELPFUL",names={},spellIds={},subeventPrefix="SPELL",subeventSuffix="_CAST_START"},untrigger={custom=""}},
    activeTriggerMode=-10, disjunctive="any",
  }
end

local function TextDisplay(id, parent, classToken, trigger)
  local data=Base(id,parent,classToken)
  data.regionType="text"; data.width=REMINDER_WIDTH; data.height=REMINDER_HEIGHT
  data.selfPoint="CENTER"; data.anchorPoint="CENTER"; data.anchorFrameType="SCREEN"
  data.xOffset=0; data.yOffset=0; data.font="Fira Sans Heavy"; data.fontSize=10
  data.outline="OUTLINE"; data.color={1,0.45,0.18,1}; data.justify="CENTER"
  data.wordWrap="WordWrap"; data.displayText="%n"; data.subRegions={}; data.triggers=trigger
  return data
end

local function JoinNumbers(values)
  local out={}
  for _,value in ipairs(values or {}) do out[#out+1]=tostring(tonumber(value) or 0) end
  return table.concat(out,",")
end

local function QuoteList(values)
  local out={}
  for _,value in ipairs(values or {}) do out[#out+1]=string.format("%q",tostring(value)) end
  return table.concat(out,",")
end

local function ReminderTrigger(entry)
  local text=string.format("%q",entry.text or "REMINDER")
  if entry.mode=="buffAny" then
    return CustomStateTrigger(string.format([[
function(allstates,event,unit)
  if event=="UNIT_AURA" and unit and unit~="player" then return false end
  local state=allstates[""] or {}; allstates[""]=state
  local wanted={%s}; local names={}
  for _,id in ipairs(wanted) do local name=GetSpellInfo(id); if name then names[name]=true end end
  local found=false
  for index=1,40 do local name=UnitBuff("player",index); if not name then break end; if names[name] then found=true; break end end
  state.show=not found; state.changed=true; state.progressType="static"; state.value=1; state.total=1; state.name=%s
  return true
end
]],JoinNumbers(entry.spellIds),text),"PLAYER_ENTERING_WORLD UNIT_AURA SPELLS_CHANGED")
  elseif entry.mode=="buffPrefix" then
    return CustomStateTrigger(string.format([[
function(allstates,event,unit)
  if event=="UNIT_AURA" and unit and unit~="player" then return false end
  local state=allstates[""] or {}; allstates[""]=state
  local prefixes={%s}; local found=false
  for index=1,40 do
    local name=UnitBuff("player",index); if not name then break end
    for _,prefix in ipairs(prefixes) do if string.sub(name,1,string.len(prefix))==prefix then found=true; break end end
    if found then break end
  end
  state.show=not found; state.changed=true; state.progressType="static"; state.value=1; state.total=1; state.name=%s
  return true
end
]],QuoteList(entry.prefixes),text),"PLAYER_ENTERING_WORLD UNIT_AURA")
  elseif entry.mode=="aspect" then
    return CustomStateTrigger(string.format([[
function(allstates,event,unit)
  if event=="UNIT_AURA" and unit and unit~="player" then return false end
  local state=allstates[""] or {}; allstates[""]=state
  local ids={13165,13163,5118,13159,13161,20043,34074}; local names={}
  for _,id in ipairs(ids) do local name=GetSpellInfo(id); if name then names[name]=true end end
  local found=false
  for index=1,40 do local name=UnitBuff("player",index); if not name then break end; if names[name] then found=true; break end end
  state.show=not found; state.changed=true; state.progressType="static"; state.value=1; state.total=1; state.name=%s
  return true
end
]],text),"PLAYER_ENTERING_WORLD UNIT_AURA")
  elseif entry.mode=="petMissing" then
    return CustomStateTrigger(string.format([[
function(allstates)
  local state=allstates[""] or {}; allstates[""]=state
  state.show=not UnitExists("pet"); state.changed=true; state.progressType="static"; state.value=1; state.total=1; state.name=%s
  return true
end
]],text),"PLAYER_ENTERING_WORLD UNIT_PET PLAYER_ALIVE PLAYER_UNGHOST")
  elseif entry.mode=="warlockPet" then
    return CustomStateTrigger(string.format([[
function(allstates,event,unit)
  if event=="UNIT_AURA" and unit and unit~="player" then return false end
  local state=allstates[""] or {}; allstates[""]=state
  local sacrifice=false; local ids={18789,18790,18791,18792}; local names={}
  for _,id in ipairs(ids) do local name=GetSpellInfo(id); if name then names[name]=true end end
  for index=1,40 do local name=UnitBuff("player",index); if not name then break end; if names[name] then sacrifice=true; break end end
  state.show=(not UnitExists("pet")) and (not sacrifice); state.changed=true; state.progressType="static"; state.value=1; state.total=1; state.name=%s
  return true
end
]],text),"PLAYER_ENTERING_WORLD UNIT_PET UNIT_AURA PLAYER_ALIVE PLAYER_UNGHOST")
  elseif entry.mode=="weaponEnchant" then
    local off=entry.hand=="off" and "true" or "false"
    return CustomStateTrigger(string.format([[
function(allstates)
  local state=allstates[""] or {}; allstates[""]=state
  if not GetWeaponEnchantInfo then state.show=false; state.changed=true; return true end
  local main,_,_,offhand=GetWeaponEnchantInfo(); local found=(%s and offhand) or ((not %s) and main)
  state.show=not found; state.changed=true; state.progressType="static"; state.value=1; state.total=1; state.name=%s
  return true
end
]],off,off,text),"PLAYER_ENTERING_WORLD UNIT_INVENTORY_CHANGED PLAYER_EQUIPMENT_CHANGED")
  elseif entry.mode=="stance" then
    return CustomStateTrigger([[
function(allstates)
  local state=allstates[""] or {}; allstates[""]=state
  local form=GetShapeshiftForm and GetShapeshiftForm() or 0
  local labels={[1]="BATTLE STANCE",[2]="DEFENSIVE STANCE",[3]="BERSERKER STANCE"}
  state.show=form>0; state.changed=true; state.progressType="static"; state.value=1; state.total=1; state.name=labels[form] or "STANCE"
  return true
end
]],"PLAYER_ENTERING_WORLD UPDATE_SHAPESHIFT_FORM")
  elseif entry.mode=="execute" then
    return CustomStateTrigger(string.format([[
function(allstates,event,unit)
  if event=="UNIT_HEALTH" and unit and unit~="target" then return false end
  local state=allstates[""] or {}; allstates[""]=state; local show=false
  local known=(not IsSpellKnown) or IsSpellKnown(5308)
  if known and UnitExists("target") and UnitCanAttack("player","target") then
    local maximum=UnitHealthMax("target") or 0; local current=UnitHealth("target") or 0
    show=maximum>0 and (current/maximum)<=0.20
  end
  state.show=show; state.changed=true; state.progressType="static"; state.value=1; state.total=1; state.name=%s
  return true
end
]],text),"PLAYER_ENTERING_WORLD PLAYER_TARGET_CHANGED UNIT_HEALTH")
  end
  return CustomStateTrigger(string.format([[function(allstates) local s=allstates[""] or {}; allstates[""]=s; s.show=false; s.changed=true; s.name=%s; return true end]],text),"PLAYER_ENTERING_WORLD")
end

local function AuraTrigger(ids,unit)
  local names={}
  for i,id in ipairs(ids or {}) do names[i]=tostring(id) end
  return {
    trigger={type="aura2",event="Health",unit=unit or "target",use_unit=true,debuffType=(unit=="player") and "HELPFUL" or "HARMFUL",auranames=names,useName=true,ownOnly=(unit~="player"),matchesShowOn="showAlways",names={},spellIds={},subeventPrefix="SPELL",subeventSuffix="_CAST_START"},
    untrigger={},
  }
end

local function FormCondition(forms)
  local form={}
  if type(forms)=="table" then form.multi={}; for _,index in ipairs(forms) do form.multi[index]=true end else form.single=forms end
  return {trigger={type="unit",event="Stance/Form/Aura",unit="player",use_unit=true,use_form=true,form=form,debuffType="HELPFUL",names={},spellIds={},subeventPrefix="SPELL",subeventSuffix="_CAST_START"},untrigger={}}
end

local function FindDisplay(packageData,id)
  for _,display in ipairs(packageData.displays or {}) do if display.id==id then return display end end
end

local function AddRootId(package,id)
  package.rootIds=package.rootIds or {}
  for _,existing in ipairs(package.rootIds) do if existing==id then return end end
  package.rootIds[#package.rootIds+1]=id
end

local function ExtendClass(classToken,definition)
  local key=classToken:lower(); local package=RUI.weakAuraPackages[key]
  if not package or type(package.Build)~="function" or package.__retreatParityExtended then return end
  package.__retreatParityExtended=true
  local originalBuild=package.Build
  local displayClass=DisplayClass(classToken)
  local rootMain="RetreatUI TBC — "..displayClass.." Main"
  local rootUtility="RetreatUI TBC — "..displayClass.." Utility"
  local rootReminders="RetreatUI TBC — "..displayClass.." Reminders"
  AddRootId(package,rootReminders)

  function package:Build()
    local built=originalBuild(self)
    if type(built)~="table" then return built end
    built.roots=built.roots or {}; built.displays=built.displays or {}; built.expected=built.expected or {}

    for _,root in ipairs(built.roots) do
      if root.id==rootMain then root.gridWidth=40; root.limit=40 end
    end

    for _,entry in ipairs(definition.main or {}) do
      local display=FindDisplay(built,rootMain.." — "..entry.name)
      if display then
        if entry.loadSpell==false then
          display.load=display.load or {}; display.load.use_spellknown=false; display.load.spellknown=nil
          if entry.auras and entry.auras[1] and GetSpellTexture then display.displayIcon=GetSpellTexture(entry.auras[1]) or display.displayIcon end
        elseif type(entry.loadSpell)=="number" then
          display.load=display.load or {}; display.load.use_spellknown=true; display.load.spellknown=entry.loadSpell
        end
        if entry.form or entry.forms then
          display.triggers=display.triggers or {}
          display.triggers[2]=FormCondition(entry.forms or entry.form)
          display.triggers.activeTriggerMode=1; display.triggers.disjunctive="all"
        end
      end
    end

    for _,entry in ipairs(definition.utility or {}) do
      if entry.kind=="aura" then
        local display=FindDisplay(built,rootUtility.." — "..entry.name)
        if display then
          display.load=display.load or {}; display.load.use_spellknown=false; display.load.spellknown=nil
          display.triggers={ [1]=AuraTrigger({entry.id},"player"), activeTriggerMode=-10, disjunctive="any" }
          display.progressSource={-1,""}
        end
      end
    end

    local children={}
    for index,entry in ipairs(definition.reminders or {}) do
      local id=rootReminders.." — "..tostring(index).." — "..(entry.text or entry.mode or "Reminder")
      children[#children+1]=id
      built.displays[#built.displays+1]=TextDisplay(id,rootReminders,classToken,ReminderTrigger(entry))
    end
    built.roots[#built.roots+1]=ReminderGroup(rootReminders,classToken,children)
    built.expected[rootReminders]={x=REMINDER_X,y=REMINDER_Y}
    return built
  end
end

for classToken,definition in pairs(RUI.tbcClassData) do ExtendClass(classToken,definition) end
