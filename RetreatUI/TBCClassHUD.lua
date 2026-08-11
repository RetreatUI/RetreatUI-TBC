local RUI = RetreatUITBC
if not RUI then return end

local DATA = RUI.tbcClassData
if type(DATA) ~= "table" then return end

RUI.weakAuraPackages = RUI.weakAuraPackages or {}

-- RetreatUI TBC class-native HUD.
-- Functional organization is based on the supplied TBC reference pack, while
-- all WeakAura data, triggers, layout and code below are RetreatUI's own.
local RESOURCE_X, RESOURCE_Y = 0, -152
local MAIN_X, MAIN_Y = 0, -183
local UTILITY_X, UTILITY_Y = 0, -224
local COMBO_X, COMBO_Y = 0, -118
local SYSTEM_X, SYSTEM_Y = 0, -254

local RESOURCE_WIDTH, RESOURCE_HEIGHT = 360, 16
local MAIN_ICON, UTILITY_ICON = 38, 32
local ICON_SPACING = 1
local COMBO_WIDTH, COMBO_HEIGHT = 160, 8
local SYSTEM_WIDTH, SYSTEM_HEIGHT = 360, 8
local SYSTEM_SMALL_WIDTH = 176
local SYSTEM_SPACING = 2

local POWER_COLORS = {
  [0] = { 0.10, 0.42, 0.95, 1 },
  [1] = { 0.95, 0.20, 0.06, 1 },
  [3] = { 0.95, 0.82, 0.08, 1 },
  [4] = { 0.95, 0.82, 0.08, 1 },
}
local POWER_NAMES = { [0] = "Mana", [1] = "Rage", [3] = "Energy", [4] = "Combo Points" }

local MANA_CLASSES = {
  DRUID=true, HUNTER=true, MAGE=true, PALADIN=true, PRIEST=true, SHAMAN=true, WARLOCK=true,
}
local WAND_CLASSES = { MAGE=true, PRIEST=true, WARLOCK=true }
local ENERGY_TICK_CLASSES = { DRUID=true, ROGUE=true }

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

local function ClassLoad(classToken, spellKnown)
  local load = {
    class = { multi = { [classToken] = true }, single = classToken },
    spec = { multi = {} },
    use_class = true,
    use_never = false,
  }
  if spellKnown then
    load.spellknown = spellKnown
    load.use_spellknown = true
  end
  return load
end

local function Base(id, parent, classToken, spellKnown)
  return {
    id = id,
    parent = parent,
    internalVersion = InternalVersion(),
    tocversion = TocVersion(),
    actions = { start={do_custom=false}, finish={do_custom=false}, init={do_custom=false} },
    animation = {
      start={type="none",duration_type="seconds",easeType="none",easeStrength=3},
      main={type="none",duration_type="seconds",easeType="none",easeStrength=3},
      finish={type="none",duration_type="seconds",easeType="none",easeStrength=3},
    },
    authorOptions = {}, conditions = {}, config = {}, information = {},
    load = ClassLoad(classToken, spellKnown), alpha = 1, frameStrata = 1,
  }
end

local function Border(anchorArea)
  local border = {
    type="subborder", border_visible=true, border_color={0,0,0,1},
    border_edge="Square Full White", border_offset=0, border_size=1,
  }
  if anchorArea then border.anchor_area = anchorArea end
  return border
end

local function GroupTrigger()
  return {
    [1] = {
      trigger = {
        type="aura2", event="Health", unit="player", debuffType="HELPFUL",
        names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
      },
      untrigger = {},
    },
    activeTriggerMode = -10,
    disjunctive = "any",
  }
end

local function DynamicGroup(id, classToken, x, y, children, grow, spacing)
  local data = Base(id, nil, classToken)
  data.regionType = "dynamicgroup"
  data.controlledChildren = children
  data.anchorFrameType = "SCREEN"
  data.anchorPoint = "CENTER"
  data.selfPoint = "CENTER"
  data.xOffset = x
  data.yOffset = y
  data.grow = grow or "HORIZONTAL"
  data.align = "CENTER"
  data.sort = "none"
  data.space = spacing or ICON_SPACING
  data.stagger = 0
  data.animate = false
  data.scale = 1
  data.gridType = "RD"
  data.centerType = "LR"
  data.gridWidth = 24
  data.rowSpace = spacing or ICON_SPACING
  data.columnSpace = spacing or ICON_SPACING
  data.useLimit = false
  data.limit = 24
  data.fullCircle = true
  data.rotation = 0
  data.radius = 200
  data.stepAngle = 15
  data.constantFactor = "RADIUS"
  data.subRegions = {}
  data.triggers = GroupTrigger()
  return data
end

local function CooldownTrigger(spellId)
  return {
    trigger = {
      type="spell", event="Cooldown Progress (Spell)", unit="player", use_unit=true,
      spellName=spellId, use_spellName=true, realSpellName=(GetSpellInfo and GetSpellInfo(spellId)) or nil,
      genericShowOn="showAlways", use_genericShowOn=true, use_showOn=true,
      track="auto", use_track=true, use_showgcd=true, use_remaining=false,
      debuffType="HELPFUL", names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
    },
    untrigger = {},
  }
end

local function AuraTrigger(ids, unit)
  local names = {}
  for i, spellId in ipairs(ids or {}) do names[i] = tostring(spellId) end
  return {
    trigger = {
      type="aura2", event="Health", unit=unit or "target", use_unit=true,
      debuffType=(unit == "player") and "HELPFUL" or "HARMFUL",
      auranames=names, useName=true, ownOnly=(unit ~= "player"), matchesShowOn="showAlways",
      names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
    },
    untrigger = {},
  }
end

local function PowerCondition(powerType)
  return {
    trigger = {
      type="unit", event="Power", unit="player", use_unit=true,
      powertype=powerType, use_powertype=true, use_requirePowerType=true,
      genericShowOn="showOnActive", use_genericShowOn=true,
      debuffType="HELPFUL", names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
    },
    untrigger = {},
  }
end

local function IconBase(id, parent, classToken, size, spellKnown)
  local data = Base(id, parent, classToken, spellKnown)
  data.regionType = "icon"
  data.width = size
  data.height = size
  data.selfPoint = "CENTER"
  data.anchorPoint = "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset = 0
  data.yOffset = 0
  data.color = {1,1,1,1}
  data.icon = true
  data.iconSource = -1
  data.displayIcon = (spellKnown and GetSpellTexture and GetSpellTexture(spellKnown)) or 134400
  data.progressSource = {1, ""}
  data.cooldown = true
  data.cooldownSwipe = true
  data.cooldownTextDisabled = false
  data.cooldownEdge = false
  data.zoom = 0.08
  data.subRegions = {
    { type="subbackground" },
    Border(),
    {
      type="subtext", text_visible=true, text_text="%s", text_font="Fira Sans Heavy",
      text_fontSize=10, text_fontType="OUTLINE", text_color={1,1,1,1},
      text_justify="RIGHT", text_selfPoint="BOTTOMRIGHT", anchor_point="BOTTOMRIGHT",
      anchorXOffset=-1, anchorYOffset=1,
    },
  }
  return data
end

local function MainIcon(id, parent, classToken, entry)
  local data = IconBase(id, parent, classToken, MAIN_ICON, entry.spell)
  if entry.auraOnly and entry.auras then
    data.triggers = { [1]=AuraTrigger(entry.auras, entry.unit), activeTriggerMode=-10, disjunctive="any" }
    data.progressSource = {-1, ""}
  elseif entry.requiredPower then
    data.triggers = {
      [1]=CooldownTrigger(entry.spell), [2]=PowerCondition(entry.requiredPower),
      activeTriggerMode=1, disjunctive="all",
    }
    data.progressSource = {1, ""}
  elseif entry.auras and entry.unit == "target" then
    data.triggers = {
      [1]=AuraTrigger(entry.auras, "target"), [2]=CooldownTrigger(entry.spell),
      activeTriggerMode=-10, disjunctive="any",
    }
    data.progressSource = {-1, ""}
  else
    data.triggers = { [1]=CooldownTrigger(entry.spell), activeTriggerMode=-10, disjunctive="any" }
  end
  return data
end

local function UtilityIcon(id, parent, classToken, entry)
  if entry.kind == "item" then
    local data = IconBase(id, parent, classToken, UTILITY_ICON, nil)
    data.displayIcon = (GetItemIcon and GetItemIcon(entry.id)) or 134400
    data.triggers = {
      [1] = {
        trigger = {
          type="item", event="Cooldown Progress (Item)", itemName=entry.id, use_itemName=true,
          genericShowOn="showAlways", use_genericShowOn=true, unit="player", use_unit=true,
          names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
        },
        untrigger = {},
      },
      activeTriggerMode=-10, disjunctive="any",
    }
    return data
  end
  local data = IconBase(id, parent, classToken, UTILITY_ICON, entry.id)
  data.triggers = { [1]=CooldownTrigger(entry.id), activeTriggerMode=-10, disjunctive="any" }
  return data
end

local function BarBase(id, parent, classToken, width, height, color)
  local data = Base(id, parent, classToken)
  data.regionType = "aurabar"
  data.width = width
  data.height = height
  data.selfPoint = "CENTER"
  data.anchorPoint = "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset = 0
  data.yOffset = 0
  data.orientation = "HORIZONTAL"
  data.inverse = false
  data.icon = false
  data.texture = "ElvUI Norm"
  data.textureSource = "LSM"
  data.barColor = color or {0.65,0.65,0.68,1}
  data.backgroundColor = {0.018,0.018,0.022,0.96}
  data.spark = false
  data.progressSource = {1, ""}
  data.subRegions = {
    {type="subbackground"}, Border("bar"),
    {
      type="subtext", text_visible=true, text_text="%p / %t", text_font="Fira Sans Heavy",
      text_fontSize=10, text_fontType="OUTLINE", text_color={1,1,1,1},
      text_justify="CENTER", text_selfPoint="CENTER", anchor_point="CENTER",
      anchorXOffset=0, anchorYOffset=0,
    },
  }
  return data
end

local function PowerBar(id, parent, classToken, powerType)
  local data = BarBase(id, parent, classToken, RESOURCE_WIDTH, RESOURCE_HEIGHT, POWER_COLORS[powerType])
  data.triggers = {
    [1] = {
      trigger = {
        type="unit", event="Power", unit="player", use_unit=true,
        powertype=powerType, use_powertype=true, use_requirePowerType=true,
        genericShowOn="showOnActive", use_genericShowOn=true, use_showCost=false,
        debuffType="HELPFUL", names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
      },
      untrigger = {},
    },
    activeTriggerMode=-10, disjunctive="any",
  }
  return data
end

local function ComboBar(id, parent, classToken)
  local data = BarBase(id, parent, classToken, COMBO_WIDTH, COMBO_HEIGHT, POWER_COLORS[4])
  data.subRegions[3].text_text = "%p / %t"
  data.triggers = {
    [1] = {
      trigger = {
        type="unit", event="Power", unit="player", use_unit=true,
        powertype=4, use_powertype=true, genericShowOn="showOnActive",
        matchesShowOn="showAlways", use_genericShowOn=true,
        debuffType="HELPFUL", names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
      },
      untrigger = {},
    },
    activeTriggerMode=-10, disjunctive="any",
  }
  return data
end

local function CastBar(id, parent, classToken)
  local data = BarBase(id, parent, classToken, SYSTEM_WIDTH, 10, {0.82,0.55,0.12,1})
  data.subRegions[3].text_text = "%n"
  data.triggers = {
    [1] = {
      trigger = {
        type="unit", event="Cast", unit="player", use_unit=true,
        debuffType="HELPFUL", names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
      },
      untrigger = {},
    },
    activeTriggerMode=-10, disjunctive="any",
  }
  return data
end

local function SwingBar(id, parent, classToken, hand)
  local data = BarBase(id, parent, classToken, SYSTEM_WIDTH, SYSTEM_HEIGHT, {0.58,0.60,0.64,1})
  data.inverse = true
  data.subRegions[3].text_text = hand == "ranged" and "Shot" or "Swing"
  data.triggers = {
    [1] = {
      trigger = {
        type="unit", event="Swing Timer", unit="player", use_unit=true,
        hand=hand, use_hand=true, genericShowOn="showOnActive",
        debuffType="HELPFUL", names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
      },
      untrigger = {},
    },
    activeTriggerMode=-10, disjunctive="any",
  }
  return data
end

local function CustomStateTrigger(code, events)
  return {
    [1] = {
      trigger = {
        type="custom", event="Health", check="event", custom_type="stateupdate",
        custom_hide="custom", custom=code, events=events, unit="player",
        debuffType="HELPFUL", names={}, spellIds={}, subeventPrefix="SPELL", subeventSuffix="_CAST_START",
      },
      untrigger = {custom=""},
    },
    activeTriggerMode=-10, disjunctive="any",
  }
end

local function EnergyTickBar(id, parent, classToken)
  local data = BarBase(id, parent, classToken, SYSTEM_SMALL_WIDTH, SYSTEM_HEIGHT, {0.95,0.82,0.08,1})
  data.subRegions[3].text_text = "Energy Tick"
  data.triggers = CustomStateTrigger([[
function(allstates,event,unit)
  if event=="UNIT_POWER_UPDATE" and unit and unit~="player" then return false end
  local state=allstates[""] or {}; allstates[""]=state
  local powerType=UnitPowerType("player")
  local current=UnitPower("player",3) or 0
  local maximum=UnitPowerMax("player",3) or 0
  local previous=aura_env.lastEnergy
  aura_env.lastEnergy=current
  if powerType~=3 or maximum<=0 or current>=maximum then
    if state.show then state.show=false; state.changed=true; return true end
    return false
  end
  if previous~=nil and current>previous then
    state.show=true; state.changed=true; state.progressType="timed"; state.duration=2
    state.expirationTime=GetTime()+2; state.autoHide=true; state.name="Energy Tick"
    return true
  end
  if event=="PLAYER_ENTERING_WORLD" or event=="UNIT_DISPLAYPOWER" or event=="UPDATE_SHAPESHIFT_FORM" then
    state.show=false; state.changed=true; return true
  end
  return false
end
]], "PLAYER_ENTERING_WORLD UNIT_DISPLAYPOWER UPDATE_SHAPESHIFT_FORM UNIT_POWER_UPDATE")
  return data
end

local function FiveSecondRuleBar(id, parent, classToken)
  local data = BarBase(id, parent, classToken, SYSTEM_SMALL_WIDTH, SYSTEM_HEIGHT, {0.20,0.50,0.95,1})
  data.subRegions[3].text_text = "5SR"
  data.triggers = CustomStateTrigger([[
function(allstates,event,unit)
  if event=="UNIT_POWER_UPDATE" and unit and unit~="player" then return false end
  local state=allstates[""] or {}; allstates[""]=state
  local current=UnitPower("player",0) or 0
  local maximum=UnitPowerMax("player",0) or 0
  local previous=aura_env.lastMana
  aura_env.lastMana=current
  if maximum<=0 or current>=maximum then
    if state.show then state.show=false; state.changed=true; return true end
    return false
  end
  if previous~=nil and current<previous then
    state.show=true; state.changed=true; state.progressType="timed"; state.duration=5
    state.expirationTime=GetTime()+5; state.autoHide=true; state.name="Five Second Rule"
    return true
  end
  if event=="PLAYER_ENTERING_WORLD" then state.show=false; state.changed=true; return true end
  return false
end
]], "PLAYER_ENTERING_WORLD UNIT_POWER_UPDATE UNIT_MAXPOWER")
  return data
end

local function FeralManaBar(id, parent, classToken)
  local data = BarBase(id, parent, classToken, SYSTEM_SMALL_WIDTH, SYSTEM_HEIGHT, POWER_COLORS[0])
  data.subRegions[3].text_text = "Mana %p / %t"
  data.triggers = CustomStateTrigger([[
function(allstates,event,unit)
  if (event=="UNIT_POWER_UPDATE" or event=="UNIT_MAXPOWER") and unit and unit~="player" then return false end
  local state=allstates[""] or {}; allstates[""]=state
  if UnitPowerType("player")==0 then state.show=false; state.changed=true; return true end
  local value=UnitPower("player",0) or 0
  local total=UnitPowerMax("player",0) or 0
  state.show=total>0; state.changed=true; state.progressType="static"
  state.value=value; state.total=math.max(1,total); state.name="Mana"
  return true
end
]], "PLAYER_ENTERING_WORLD UPDATE_SHAPESHIFT_FORM UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER")
  return data
end

local function SoulShardBar(id, parent, classToken)
  local data = BarBase(id, parent, classToken, SYSTEM_SMALL_WIDTH, SYSTEM_HEIGHT, {0.55,0.30,0.78,1})
  data.subRegions[3].text_text = "Shards: %p"
  data.triggers = CustomStateTrigger([[
function(allstates)
  local state=allstates[""] or {}; allstates[""]=state
  local count=(GetItemCount and GetItemCount(6265)) or 0
  state.show=true; state.changed=true; state.progressType="static"
  state.value=count; state.total=32; state.name="Soul Shards"; state.stacks=count
  return true
end
]], "PLAYER_ENTERING_WORLD BAG_UPDATE BAG_UPDATE_DELAYED")
  return data
end

local function TotemIcon(id, parent, classToken, slot)
  local data = IconBase(id, parent, classToken, UTILITY_ICON, nil)
  data.displayIcon = 136008
  data.subRegions = {{type="subbackground"}, Border()}
  data.triggers = CustomStateTrigger(string.format([[
function(allstates,event,changedSlot)
  if event=="PLAYER_TOTEM_UPDATE" and changedSlot and changedSlot~=%d then return false end
  local state=allstates[""] or {}; allstates[""]=state
  if not GetTotemInfo then state.show=false; state.changed=true; return true end
  local have,name,startTime,duration,icon=GetTotemInfo(%d)
  if have and name and duration and duration>0 then
    state.show=true; state.changed=true; state.progressType="timed"; state.duration=duration
    state.expirationTime=startTime+duration; state.name=name; state.icon=icon; state.autoHide=false
  else
    state.show=false; state.changed=true
  end
  return true
end
]], slot, slot), "PLAYER_ENTERING_WORLD PLAYER_TOTEM_UPDATE")
  return data
end

local function AddUnique(children, id)
  for _, existing in ipairs(children) do if existing == id then return false end end
  children[#children+1] = id
  return true
end

local function RegisterClass(classToken, definition)
  local PACKAGE = {}
  RUI.weakAuraPackages[classToken:lower()] = PACKAGE

  local displayClass = DisplayClass(classToken)
  local ROOT_RESOURCE = "RetreatUI TBC — " .. displayClass .. " Resource"
  local ROOT_MAIN = "RetreatUI TBC — " .. displayClass .. " Main"
  local ROOT_UTILITY = "RetreatUI TBC — " .. displayClass .. " Utility"
  local ROOT_SYSTEMS = "RetreatUI TBC — " .. displayClass .. " Systems"
  local ROOT_COMBO = "RetreatUI TBC — " .. displayClass .. " Combo Points"

  PACKAGE.rootIds = {ROOT_RESOURCE, ROOT_MAIN, ROOT_UTILITY, ROOT_SYSTEMS}
  if classToken == "DRUID" or classToken == "ROGUE" then PACKAGE.rootIds[#PACKAGE.rootIds+1] = ROOT_COMBO end

  function PACKAGE:Build()
    local displays, roots, expected = {}, {}, {}
    local resourceChildren, mainChildren, utilityChildren, systemChildren = {}, {}, {}, {}

    for _, powerType in ipairs(definition.power or {}) do
      local id = ROOT_RESOURCE .. " — " .. (POWER_NAMES[powerType] or "Resource")
      resourceChildren[#resourceChildren+1] = id
      displays[#displays+1] = PowerBar(id, ROOT_RESOURCE, classToken, powerType)
    end

    for _, entry in ipairs(definition.main or {}) do
      local id = ROOT_MAIN .. " — " .. entry.name
      mainChildren[#mainChildren+1] = id
      displays[#displays+1] = MainIcon(id, ROOT_MAIN, classToken, entry)
    end

    for _, entry in ipairs(definition.utility or {}) do
      local id = ROOT_UTILITY .. " — " .. entry.name
      if AddUnique(utilityChildren, id) then
        displays[#displays+1] = UtilityIcon(id, ROOT_UTILITY, classToken, entry)
      end
    end

    -- Native Shaman totem slots: Fire, Earth, Water and Air are tracked by the
    -- client's totem API instead of hard-coded totem spell ranks.
    if classToken == "SHAMAN" then
      for slot=1,4 do
        local id = ROOT_UTILITY .. " — Active Totem " .. tostring(slot)
        utilityChildren[#utilityChildren+1] = id
        displays[#displays+1] = TotemIcon(id, ROOT_UTILITY, classToken, slot)
      end
    end

    local castId = ROOT_SYSTEMS .. " — Cast"
    systemChildren[#systemChildren+1] = castId
    displays[#displays+1] = CastBar(castId, ROOT_SYSTEMS, classToken)

    -- The shared General package already owns melee/Hunter swing timers. Only
    -- caster wand/shot timers live here to avoid duplicate bars.
    if WAND_CLASSES[classToken] then
      local shotId = ROOT_SYSTEMS .. " — Shot"
      systemChildren[#systemChildren+1] = shotId
      displays[#displays+1] = SwingBar(shotId, ROOT_SYSTEMS, classToken, "ranged")
    end

    if ENERGY_TICK_CLASSES[classToken] then
      local id = ROOT_SYSTEMS .. " — Energy Tick"
      systemChildren[#systemChildren+1] = id
      displays[#displays+1] = EnergyTickBar(id, ROOT_SYSTEMS, classToken)
    end

    if MANA_CLASSES[classToken] then
      local id = ROOT_SYSTEMS .. " — Five Second Rule"
      systemChildren[#systemChildren+1] = id
      displays[#displays+1] = FiveSecondRuleBar(id, ROOT_SYSTEMS, classToken)
    end

    if classToken == "DRUID" then
      local id = ROOT_SYSTEMS .. " — Mana in Form"
      systemChildren[#systemChildren+1] = id
      displays[#displays+1] = FeralManaBar(id, ROOT_SYSTEMS, classToken)
    elseif classToken == "WARLOCK" then
      local id = ROOT_SYSTEMS .. " — Soul Shards"
      systemChildren[#systemChildren+1] = id
      displays[#displays+1] = SoulShardBar(id, ROOT_SYSTEMS, classToken)
    end

    roots[#roots+1] = DynamicGroup(ROOT_RESOURCE, classToken, RESOURCE_X, RESOURCE_Y, resourceChildren, "HORIZONTAL", 0)
    roots[#roots+1] = DynamicGroup(ROOT_MAIN, classToken, MAIN_X, MAIN_Y, mainChildren, "HORIZONTAL", ICON_SPACING)
    roots[#roots+1] = DynamicGroup(ROOT_UTILITY, classToken, UTILITY_X, UTILITY_Y, utilityChildren, "HORIZONTAL", ICON_SPACING)
    roots[#roots+1] = DynamicGroup(ROOT_SYSTEMS, classToken, SYSTEM_X, SYSTEM_Y, systemChildren, "DOWN", SYSTEM_SPACING)
    expected[ROOT_RESOURCE] = {x=RESOURCE_X,y=RESOURCE_Y}
    expected[ROOT_MAIN] = {x=MAIN_X,y=MAIN_Y}
    expected[ROOT_UTILITY] = {x=UTILITY_X,y=UTILITY_Y}
    expected[ROOT_SYSTEMS] = {x=SYSTEM_X,y=SYSTEM_Y}

    if classToken == "DRUID" or classToken == "ROGUE" then
      local comboId = ROOT_COMBO .. " — Native"
      roots[#roots+1] = DynamicGroup(ROOT_COMBO, classToken, COMBO_X, COMBO_Y, {comboId}, "HORIZONTAL", 0)
      displays[#displays+1] = ComboBar(comboId, ROOT_COMBO, classToken)
      expected[ROOT_COMBO] = {x=COMBO_X,y=COMBO_Y}
    end

    return { roots=roots, displays=displays, expected=expected }
  end
end

for classToken, definition in pairs(DATA) do
  RegisterClass(classToken, definition)
end
