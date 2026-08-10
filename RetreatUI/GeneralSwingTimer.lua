local RUI = RetreatUITBC
if not RUI then return end

local PACKAGE = RUI.generalWeakAuraPackage
if not PACKAGE or type(PACKAGE.Build) ~= "function" then return end

local ROOT = "RetreatUI - General — Swing Timer"
local MAIN_ID = ROOT .. " — Main Hand"
local OFF_ID = ROOT .. " — Off Hand"
local RANGED_ID = ROOT .. " — Auto Shot"

-- Compact timer lane directly above the 360x16 resource bar.
-- The group grows upward from Y -142 so dual-wield timers do not collide with
-- the resource bar below or the combo-point lane at Y -118 above.
local SWING_X, SWING_Y = 0, -142
local SWING_WIDTH, SWING_HEIGHT = 360, 5
local SWING_SPACING = 1

-- WeakAuras TBC class/spec IDs. Using class_and_spec means the Load tab shows
-- the exact checked specs instead of loading this aura on caster/healer specs
-- and hiding it later in custom trigger code.
local ACTIVE_SPECS = {
  -- Warrior: Arms / Fury / Protection
  [71] = true,
  [72] = true,
  [73] = true,

  -- Paladin: Protection / Retribution
  [66] = true,
  [70] = true,

  -- Druid: Feral Combat
  [103] = true,

  -- Hunter: Beast Mastery / Marksmanship / Survival
  [253] = true,
  [254] = true,
  [255] = true,

  -- Rogue: Assassination / Combat / Subtlety
  [259] = true,
  [260] = true,
  [261] = true,

  -- Shaman: Enhancement
  [263] = true,
}

local function InternalVersion()
  if WeakAuras and type(WeakAuras.InternalVersion) == "function" then
    return WeakAuras.InternalVersion()
  end
  return 90
end

local function TocVersion()
  local _, _, _, toc = GetBuildInfo()
  return toc or 20506
end

local function SwingLoad()
  local multi = {}
  for specID, enabled in pairs(ACTIVE_SPECS) do
    multi[specID] = enabled
  end
  return {
    class_and_spec = { multi = multi },
    use_class_and_spec = false,
    use_never = false,
  }
end

local function Base(id, parent)
  return {
    id = id,
    parent = parent,
    internalVersion = InternalVersion(),
    tocversion = TocVersion(),
    actions = {
      start = { do_custom = false },
      finish = { do_custom = false },
      init = { do_custom = false },
    },
    animation = {
      start = { type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3 },
      main = { type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3 },
      finish = { type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3 },
    },
    authorOptions = {},
    conditions = {},
    config = {},
    information = {},
    load = SwingLoad(),
    alpha = 1,
    frameStrata = 1,
  }
end

local function GroupTrigger()
  return {
    [1] = {
      trigger = {
        type = "aura2",
        event = "Health",
        unit = "player",
        debuffType = "HELPFUL",
        names = {},
        spellIds = {},
        subeventPrefix = "SPELL",
        subeventSuffix = "_CAST_START",
      },
      untrigger = {},
    },
    activeTriggerMode = -10,
    disjunctive = "any",
  }
end

local function SwingTrigger(kind)
  local code = string.format([[
function(allstates, event, unit)
  if (event == "UNIT_ATTACK_SPEED" or event == "UNIT_RANGEDDAMAGE" or event == "UNIT_INVENTORY_CHANGED")
    and unit and unit ~= "player" then
    return false
  end

  local state = allstates[""] or {}
  allstates[""] = state
  local now = GetTime()
  local kind = %q

  local function CurrentSpeed()
    if kind == "ranged" then
      local speed = UnitRangedDamage and UnitRangedDamage("player") or 0
      return tonumber(speed) or 0
    end

    local mainSpeed, offSpeed = 0, 0
    if UnitAttackSpeed then
      mainSpeed, offSpeed = UnitAttackSpeed("player")
    end
    if kind == "off" then return tonumber(offSpeed) or 0 end
    return tonumber(mainSpeed) or 0
  end

  local function Hide()
    if state.show then
      state.show = false
      state.changed = true
      return true
    end
    return false
  end

  local function Reset(speed)
    speed = tonumber(speed) or CurrentSpeed()
    if not speed or speed <= 0 then return Hide() end
    state.show = true
    state.changed = true
    state.progressType = "timed"
    state.duration = speed
    state.expirationTime = now + speed
    state.autoHide = false
    state.name = kind == "ranged" and "Auto Shot" or (kind == "off" and "Off Hand" or "Main Hand")
    return true
  end

  local function Rescale()
    local newSpeed = CurrentSpeed()
    if newSpeed <= 0 then return Hide() end
    if not state.show or not state.duration or not state.expirationTime then return false end

    local oldDuration = tonumber(state.duration) or newSpeed
    local remaining = math.max(0, (tonumber(state.expirationTime) or now) - now)
    local progress = oldDuration > 0 and math.max(0, math.min(1, 1 - (remaining / oldDuration))) or 0
    state.duration = newSpeed
    state.expirationTime = now + (newSpeed * (1 - progress))
    state.changed = true
    return true
  end

  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
    return Hide()
  end

  if event == "UNIT_ATTACK_SPEED" or event == "UNIT_RANGEDDAMAGE"
    or event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
    return Rescale()
  end

  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" or not CombatLogGetCurrentEventInfo then
    return false
  end

  local info = { CombatLogGetCurrentEventInfo() }
  local subevent = info[2]
  local sourceGUID = info[4]
  if sourceGUID ~= UnitGUID("player") then return false end

  if kind == "ranged" then
    if (subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED") and tonumber(info[12]) == 75 then
      return Reset(CurrentSpeed())
    end
    return false
  end

  if subevent ~= "SWING_DAMAGE" and subevent ~= "SWING_MISSED" then
    return false
  end

  local isOffHand
  if subevent == "SWING_DAMAGE" then
    isOffHand = info[21] == true
  else
    isOffHand = info[13] == true
  end

  if kind == "off" then
    if isOffHand then return Reset(CurrentSpeed()) end
  elseif not isOffHand then
    return Reset(CurrentSpeed())
  end

  return false
end
]], kind)

  return {
    [1] = {
      trigger = {
        type = "custom",
        event = "Health",
        check = "event",
        custom_type = "stateupdate",
        custom_hide = "custom",
        custom = code,
        events = "PLAYER_ENTERING_WORLD PLAYER_REGEN_DISABLED PLAYER_REGEN_ENABLED COMBAT_LOG_EVENT_UNFILTERED UNIT_ATTACK_SPEED UNIT_RANGEDDAMAGE PLAYER_EQUIPMENT_CHANGED UNIT_INVENTORY_CHANGED UPDATE_SHAPESHIFT_FORM",
        unit = "player",
        debuffType = "HELPFUL",
        names = {},
        spellIds = {},
        subeventPrefix = "SPELL",
        subeventSuffix = "_CAST_START",
      },
      untrigger = { custom = "" },
    },
    activeTriggerMode = -10,
    disjunctive = "any",
  }
end

local function SwingBar(id, kind, color)
  local data = Base(id, ROOT)
  data.regionType = "aurabar"
  data.width = SWING_WIDTH
  data.height = SWING_HEIGHT
  data.selfPoint = "CENTER"
  data.anchorPoint = "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset = 0
  data.yOffset = 0
  data.orientation = "HORIZONTAL"
  data.inverse = true
  data.icon = false
  data.texture = "ElvUI Norm"
  data.textureSource = "LSM"
  data.barColor = color
  data.backgroundColor = { 0.018, 0.018, 0.022, 0.96 }
  data.spark = false
  data.progressSource = { 1, "" }
  data.triggers = SwingTrigger(kind)
  data.subRegions = {
    { type = "subbackground" },
    {
      type = "subborder",
      border_visible = true,
      border_color = { 0, 0, 0, 1 },
      border_edge = "Square Full White",
      border_offset = 0,
      border_size = 1,
      anchor_area = "bar",
    },
  }
  return data
end

local function SwingGroup(children)
  local data = Base(ROOT, "RetreatUI - General")
  data.regionType = "dynamicgroup"
  data.controlledChildren = children
  data.anchorFrameType = "SCREEN"
  data.anchorPoint = "CENTER"
  data.selfPoint = "BOTTOM"
  data.xOffset = SWING_X
  data.yOffset = SWING_Y
  data.grow = "UP"
  data.align = "CENTER"
  data.sort = "none"
  data.space = SWING_SPACING
  data.stagger = 0
  data.animate = false
  data.scale = 1
  data.gridType = "RD"
  data.centerType = "LR"
  data.gridWidth = 1
  data.rowSpace = SWING_SPACING
  data.columnSpace = 0
  data.useLimit = false
  data.limit = 3
  data.fullCircle = true
  data.rotation = 0
  data.radius = 200
  data.stepAngle = 15
  data.constantFactor = "RADIUS"
  data.subRegions = {}
  data.triggers = GroupTrigger()
  return data
end

local OriginalBuild = PACKAGE.Build
function PACKAGE:Build()
  local packageData = OriginalBuild(self)
  if type(packageData) ~= "table" or type(packageData.root) ~= "table" then return packageData end

  local children = { MAIN_ID, OFF_ID, RANGED_ID }
  local group = SwingGroup(children)

  packageData.groups = packageData.groups or {}
  packageData.displays = packageData.displays or {}
  packageData.expected = packageData.expected or {}
  packageData.root.controlledChildren = packageData.root.controlledChildren or {}

  packageData.root.controlledChildren[#packageData.root.controlledChildren + 1] = ROOT
  packageData.groups[#packageData.groups + 1] = group
  packageData.displays[#packageData.displays + 1] = SwingBar(MAIN_ID, "main", { 0.95, 0.58, 0.12, 1 })
  packageData.displays[#packageData.displays + 1] = SwingBar(OFF_ID, "off", { 0.68, 0.70, 0.74, 1 })
  packageData.displays[#packageData.displays + 1] = SwingBar(RANGED_ID, "ranged", { 0.36, 0.78, 0.42, 1 })

  packageData.expected.swing = ROOT
  packageData.expected.swingX = SWING_X
  packageData.expected.swingY = SWING_Y
  packageData.expected.swingWidth = SWING_WIDTH
  packageData.expected.swingHeight = SWING_HEIGHT
  packageData.expected.swingSpacing = SWING_SPACING
  packageData.expected.swingSpecs = ACTIVE_SPECS

  return packageData
end
