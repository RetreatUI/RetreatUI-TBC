local RUI = RetreatUITBC
if not RUI then return end

local PACKAGE = {}
RUI.generalWeakAuraPackage = PACKAGE

local ROOT = "RetreatUI - General"
local ROOT_TRINKETS = "RetreatUI - General — Trinkets"
local ROOT_PROCS = "RetreatUI - General — Buffs & Procs"

-- Match the live CoA General HUD exactly.
-- Trinkets: 30px icons, 3px spacing, directly above the player frame with
-- BOTTOMRIGHT -> TOPRIGHT at 0,+2.
-- Buffs/procs: centered at screen X 0 / Y -83, 30px icons, 3px spacing.
local GENERAL_ICON_SIZE = 30
local GENERAL_ICON_SPACING = 3
local GENERAL_PROC_X, GENERAL_PROC_Y = 0, -83
local GENERAL_MAX_PROC_DURATION = 60

PACKAGE.rootId = ROOT
PACKAGE.rootIds = { ROOT, ROOT_TRINKETS, ROOT_PROCS }

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

local function GeneralLoad()
  return {
    spec = { multi = {} },
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
    load = GeneralLoad(),
    alpha = 1,
    frameStrata = 1,
  }
end

local function DummyGroupTrigger()
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

local function StaticGroup(id, children)
  local data = Base(id)
  data.regionType = "group"
  data.controlledChildren = children
  data.anchorFrameType = "SCREEN"
  data.anchorPoint = "CENTER"
  data.selfPoint = "CENTER"
  data.xOffset = 0
  data.yOffset = 0
  data.scale = 1
  data.subRegions = {}
  data.triggers = DummyGroupTrigger()
  return data
end

local function DynamicGroup(id, parent, children)
  local data = Base(id, parent)
  data.regionType = "dynamicgroup"
  data.controlledChildren = children
  data.grow = "HORIZONTAL"
  data.align = "CENTER"
  data.sort = "none"
  data.space = GENERAL_ICON_SPACING
  data.stagger = 0
  data.animate = false
  data.scale = 1
  data.gridType = "RD"
  data.centerType = "LR"
  data.gridWidth = 18
  data.rowSpace = 0
  data.columnSpace = GENERAL_ICON_SPACING
  data.useLimit = false
  data.limit = 18
  data.fullCircle = true
  data.rotation = 0
  data.radius = 200
  data.stepAngle = 15
  data.constantFactor = "RADIUS"
  data.subRegions = {}
  data.triggers = DummyGroupTrigger()
  return data
end

local function IconBase(id, parent)
  local data = Base(id, parent)
  data.regionType = "icon"
  data.width = GENERAL_ICON_SIZE
  data.height = GENERAL_ICON_SIZE
  data.selfPoint = "CENTER"
  data.anchorPoint = "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset = 0
  data.yOffset = 0
  data.color = { 1, 1, 1, 1 }
  data.icon = true
  data.iconSource = -1
  data.displayIcon = 134400
  data.progressSource = { 1, "" }
  data.cooldown = true
  data.cooldownSwipe = true
  data.cooldownTextDisabled = false
  data.cooldownEdge = false
  data.zoom = 0.08
  data.subRegions = {
    { type = "subbackground" },
    {
      type = "subborder",
      border_visible = true,
      border_color = { 0, 0, 0, 1 },
      border_edge = "Square Full White",
      border_offset = 0,
      border_size = 1,
    },
    {
      type = "subtext",
      text_visible = true,
      text_text = "%s",
      text_font = "Fira Sans Heavy",
      text_fontSize = 10,
      text_fontType = "OUTLINE",
      text_color = { 1, 1, 1, 1 },
      text_justify = "RIGHT",
      text_selfPoint = "BOTTOMRIGHT",
      anchor_point = "BOTTOMRIGHT",
      anchorXOffset = -1,
      anchorYOffset = 1,
    },
  }
  return data
end

local function CustomStateTrigger(code, events)
  return {
    [1] = {
      trigger = {
        type = "custom",
        event = "Health",
        check = "event",
        custom_type = "stateupdate",
        custom_hide = "custom",
        custom = code,
        events = events,
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

local function TrinketTrigger(slot)
  local code = string.format([[
function(allstates, event, unit)
  if (event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_AURA") and unit and unit ~= "player" then
    return false
  end

  local state = allstates[""] or {}
  allstates[""] = state
  local texture = GetInventoryItemTexture and GetInventoryItemTexture("player", %d)
  if not texture then
    state.show = false
    state.changed = true
    return true
  end

  local itemID = GetInventoryItemID and GetInventoryItemID("player", %d)
  local itemName = itemID and GetItemInfo and GetItemInfo(itemID) or nil
  local startTime, duration, enabled = 0, 0, 0
  if GetInventoryItemCooldown then
    startTime, duration, enabled = GetInventoryItemCooldown("player", %d)
  end

  state.show = true
  state.changed = true
  state.name = itemName or "Trinket"
  state.icon = texture
  state.stacks = nil
  state.itemID = itemID

  if enabled ~= 0 and startTime and startTime > 0 and duration and duration > 1.5 then
    state.progressType = "timed"
    state.duration = duration
    state.expirationTime = startTime + duration
    state.autoHide = false
  else
    state.progressType = "static"
    state.value = 1
    state.total = 1
  end
  return true
end
]], slot, slot, slot)

  return CustomStateTrigger(code, "PLAYER_ENTERING_WORLD PLAYER_EQUIPMENT_CHANGED UNIT_INVENTORY_CHANGED BAG_UPDATE_DELAYED SPELL_UPDATE_COOLDOWN UNIT_AURA")
end

local function TrinketIcon(id, slot)
  local data = IconBase(id, ROOT_TRINKETS)
  data.triggers = TrinketTrigger(slot)
  data.subRegions[3].text_text = ""
  return data
end

local function ProcTrigger()
  local code = string.format([[
function(allstates, event, unit)
  if event == "UNIT_AURA" and unit and unit ~= "player" then
    return false
  end

  local now = GetTime()
  local seen = {}
  for index = 1, 40 do
    local name, _, icon, count, _, duration, expirationTime, caster, _, _, spellID = UnitBuff("player", index)
    if not name then break end

    duration = tonumber(duration) or 0
    expirationTime = tonumber(expirationTime) or 0
    local remaining = expirationTime - now
    local temporary = duration > 0 and duration <= %d and remaining > 0

    if temporary then
      local key = spellID and ("spell:" .. tostring(spellID)) or ("name:" .. tostring(name))
      seen[key] = true
      local state = allstates[key] or {}
      allstates[key] = state
      state.show = true
      state.changed = true
      state.progressType = "timed"
      state.duration = duration
      state.expirationTime = expirationTime
      state.autoHide = true
      state.name = name
      state.icon = icon
      state.stacks = count and count > 1 and count or nil
      state.spellId = spellID
      state.index = index
    end
  end

  for key, state in pairs(allstates) do
    if not seen[key] and state.show then
      state.show = false
      state.changed = true
    end
  end
  return true
end
]], GENERAL_MAX_PROC_DURATION)

  return CustomStateTrigger(code, "PLAYER_ENTERING_WORLD UNIT_AURA PLAYER_EQUIPMENT_CHANGED UNIT_INVENTORY_CHANGED")
end

local function ProcIcon(id)
  local data = IconBase(id, ROOT_PROCS)
  data.triggers = ProcTrigger()
  return data
end

function PACKAGE:Build()
  local trinketOne = ROOT_TRINKETS .. " — Slot 13"
  local trinketTwo = ROOT_TRINKETS .. " — Slot 14"
  local procIcon = ROOT_PROCS .. " — Active"

  local trinkets = DynamicGroup(ROOT_TRINKETS, ROOT, { trinketOne, trinketTwo })
  -- Exact CoA player-frame attachment: the tracker row's bottom-right sits two
  -- pixels above the player's top-right corner.
  trinkets.anchorFrameType = "SELECTFRAME"
  trinkets.anchorFrameFrame = "ElvUF_Player"
  trinkets.anchorPoint = "TOPRIGHT"
  trinkets.selfPoint = "BOTTOMRIGHT"
  trinkets.xOffset = 0
  trinkets.yOffset = 2

  local procs = DynamicGroup(ROOT_PROCS, ROOT, { procIcon })
  procs.anchorFrameType = "SCREEN"
  procs.anchorPoint = "CENTER"
  procs.selfPoint = "CENTER"
  procs.xOffset = GENERAL_PROC_X
  procs.yOffset = GENERAL_PROC_Y

  local root = StaticGroup(ROOT, { ROOT_TRINKETS, ROOT_PROCS })

  return {
    root = root,
    groups = { trinkets, procs },
    displays = {
      TrinketIcon(trinketOne, 13),
      TrinketIcon(trinketTwo, 14),
      ProcIcon(procIcon),
    },
    expected = {
      root = ROOT,
      trinkets = ROOT_TRINKETS,
      procs = ROOT_PROCS,
      procX = GENERAL_PROC_X,
      procY = GENERAL_PROC_Y,
      trinketAnchorFrame = "ElvUF_Player",
      trinketAnchorPoint = "TOPRIGHT",
      trinketSelfPoint = "BOTTOMRIGHT",
      trinketX = 0,
      trinketY = 2,
      iconSize = GENERAL_ICON_SIZE,
      spacing = GENERAL_ICON_SPACING,
      maxProcDuration = GENERAL_MAX_PROC_DURATION,
    },
  }
end
