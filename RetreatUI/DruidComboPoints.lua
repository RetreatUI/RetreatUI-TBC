local RUI = RetreatUITBC
if not RUI then return end

local PACKAGE = RUI.weakAuraPackages and RUI.weakAuraPackages.druid
if not PACKAGE or type(PACKAGE.Build) ~= "function" then return end

local ROOT = "RetreatUI TBC — Druid Combo Points"
local COMBO_X, COMBO_Y = 0, -118
local SEGMENT_WIDTH, SEGMENT_HEIGHT = 22, 8
local SEGMENT_SPACING = 2
local SEGMENTS = 5

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

local function DruidLoad()
  return {
    class = { multi = { DRUID = true }, single = "DRUID" },
    spec = { multi = {} },
    use_class = true,
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
    load = DruidLoad(),
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

local function SegmentTrigger(index)
  local code = string.format([[
function(allstates, event, unit)
  if event == "UNIT_POWER_UPDATE" and unit and unit ~= "player" then
    return false
  end

  local state = allstates[""] or {}
  allstates[""] = state

  -- Combo points are only relevant while the Druid is using Energy/Cat Form.
  if UnitPowerType("player") ~= 3 then
    state.show = false
    state.changed = true
    return true
  end

  local combo = GetComboPoints and GetComboPoints("player", "target") or 0
  state.show = true
  state.changed = true
  state.progressType = "static"
  state.value = combo >= %d and 1 or 0
  state.total = 1
  state.name = "Combo Point %d"
  return true
end
]], index, index)

  return {
    [1] = {
      trigger = {
        type = "custom",
        event = "Health",
        check = "event",
        custom_type = "stateupdate",
        custom_hide = "custom",
        custom = code,
        events = "PLAYER_ENTERING_WORLD PLAYER_TARGET_CHANGED PLAYER_COMBO_POINTS UNIT_POWER_UPDATE UNIT_DISPLAYPOWER UPDATE_SHAPESHIFT_FORM",
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

local function Segment(id, index)
  local data = Base(id, ROOT)
  data.regionType = "aurabar"
  data.width = SEGMENT_WIDTH
  data.height = SEGMENT_HEIGHT
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
  data.barColor = { 0.95, 0.82, 0.08, 1 }
  data.backgroundColor = { 0.018, 0.018, 0.022, 0.96 }
  data.spark = false
  data.progressSource = { 1, "" }
  data.triggers = SegmentTrigger(index)
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

local function ComboGroup(children)
  local data = Base(ROOT)
  data.regionType = "dynamicgroup"
  data.controlledChildren = children
  data.anchorFrameType = "SCREEN"
  data.anchorPoint = "CENTER"
  data.selfPoint = "CENTER"
  data.xOffset = COMBO_X
  data.yOffset = COMBO_Y
  data.grow = "HORIZONTAL"
  data.align = "CENTER"
  data.sort = "none"
  data.space = SEGMENT_SPACING
  data.stagger = 0
  data.animate = false
  data.scale = 1
  data.gridType = "RD"
  data.centerType = "LR"
  data.gridWidth = SEGMENTS
  data.rowSpace = 0
  data.columnSpace = SEGMENT_SPACING
  data.useLimit = false
  data.limit = SEGMENTS
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
  if type(packageData) ~= "table" then return packageData end

  local children = {}
  for index = 1, SEGMENTS do
    children[index] = ROOT .. " — " .. tostring(index)
  end

  packageData.roots = packageData.roots or {}
  packageData.displays = packageData.displays or {}
  packageData.expected = packageData.expected or {}

  packageData.roots[#packageData.roots + 1] = ComboGroup(children)
  for index, id in ipairs(children) do
    packageData.displays[#packageData.displays + 1] = Segment(id, index)
  end
  packageData.expected[ROOT] = { x = COMBO_X, y = COMBO_Y }

  return packageData
end

PACKAGE.rootIds = PACKAGE.rootIds or {}
local found = false
for _, id in ipairs(PACKAGE.rootIds) do
  if id == ROOT then found = true break end
end
if not found then PACKAGE.rootIds[#PACKAGE.rootIds + 1] = ROOT end
