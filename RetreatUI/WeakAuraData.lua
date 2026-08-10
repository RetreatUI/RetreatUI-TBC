local RUI = RetreatUITBC
if not RUI then return end

RUI.weakAuraPackages = RUI.weakAuraPackages or {}

local PACKAGE = {}
RUI.weakAuraPackages.druid = PACKAGE

local ROOT_RESOURCE = "RetreatUI TBC — Druid Resource"
local ROOT_MAIN = "RetreatUI TBC — Druid Main"
local ROOT_UTILITY = "RetreatUI TBC — Druid Utility"

-- These are the live RetreatUI CoA HUD coordinates. TBC uses WeakAuras at the
-- same screen positions so the center HUD sits in the same player/target gap.
local COA_RESOURCE_X, COA_RESOURCE_Y = 0, -152
local COA_MAIN_X, COA_MAIN_Y = 0, -183
local COA_UTILITY_X, COA_UTILITY_Y = 0, -224
local COA_RESOURCE_WIDTH, COA_RESOURCE_HEIGHT = 360, 16
local COA_MAIN_ICON, COA_UTILITY_ICON = 38, 32
local COA_ICON_SPACING = 1

PACKAGE.rootIds = { ROOT_RESOURCE, ROOT_MAIN, ROOT_UTILITY }

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

local function CustomTrigger(code, events)
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

local function ResourceTrigger(powerType, includeCombo)
  local comboLine = includeCombo and [[
  local combo = GetComboPoints and GetComboPoints("player", "target") or 0
  state.stacks = combo > 0 and combo or nil
]] or ""

  local code = string.format([[
function(allstates, event, unit)
  if (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER") and unit and unit ~= "player" then
    return false
  end

  local state = allstates[""] or {}
  allstates[""] = state
  local activePower = UnitPowerType("player")
  if activePower ~= %d then
    state.show = false
    state.changed = true
    return true
  end

  local current = UnitPower("player", activePower) or 0
  local maximum = UnitPowerMax("player", activePower) or 0
  state.show = true
  state.changed = true
  state.progressType = "static"
  state.value = current
  state.total = math.max(1, maximum)
  state.name = "%s"
%s
  return true
end
]], powerType, powerType == 3 and "Energy" or (powerType == 1 and "Rage" or "Mana"), comboLine)

  return CustomTrigger(code, "PLAYER_ENTERING_WORLD UPDATE_SHAPESHIFT_FORM UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER PLAYER_TARGET_CHANGED PLAYER_COMBO_POINTS")
end

local function AbilityTrigger(spellId, requiredPowerType, auraUnit)
  local powerCheck = requiredPowerType ~= nil and string.format([[
  if UnitPowerType("player") ~= %d then
    state.show = false
    state.changed = true
    return true
  end
]], requiredPowerType) or ""

  local auraCheck = ""
  if auraUnit == "target" or auraUnit == "player" then
    local auraFunction = auraUnit == "target" and "UnitDebuff" or "UnitBuff"
    auraCheck = string.format([[
  if UnitExists("%s") then
    for index = 1, 40 do
      local auraName, _, _, _, _, auraDuration, auraExpiration, auraCaster, _, _, auraSpellId = %s("%s", index)
      if not auraName then break end
      if (auraSpellId == %d or auraName == spellName) and (not auraCaster or auraCaster == "player") then
        if auraDuration and auraDuration > 0 and auraExpiration and auraExpiration > GetTime() then
          state.show = true
          state.changed = true
          state.progressType = "timed"
          state.duration = auraDuration
          state.expirationTime = auraExpiration
          state.autoHide = false
          state.name = spellName
          state.icon = spellIcon
          state.spellId = %d
          return true
        end
      end
    end
  end
]], auraUnit, auraFunction, auraUnit, spellId, spellId)
  end

  local code = string.format([[
function(allstates, event, unit)
  if event == "UNIT_AURA" and unit and unit ~= "player" and unit ~= "target" then
    return false
  end

  local state = allstates[""] or {}
  allstates[""] = state
  local spellName, _, spellIcon = GetSpellInfo(%d)
  if not spellName then
    state.show = false
    state.changed = true
    return true
  end

  local known = IsSpellKnown and IsSpellKnown(%d) or false
  if not known and GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
    for tab = 1, GetNumSpellTabs() do
      local _, _, offset, count = GetSpellTabInfo(tab)
      for slot = offset + 1, offset + count do
        local knownName = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
        if knownName == spellName then
          known = true
          break
        end
      end
      if known then break end
    end
  end

  if not known then
    state.show = false
    state.changed = true
    return true
  end

%s
%s
  local startTime, cooldownDuration, enabled = GetSpellCooldown(spellName)
  state.show = true
  state.changed = true
  state.name = spellName
  state.icon = spellIcon
  state.spellId = %d
  if enabled ~= 0 and startTime and startTime > 0 and cooldownDuration and cooldownDuration > 1.5 then
    state.progressType = "timed"
    state.duration = cooldownDuration
    state.expirationTime = startTime + cooldownDuration
    state.autoHide = false
  else
    state.progressType = "static"
    state.value = 1
    state.total = 1
  end
  return true
end
]], spellId, spellId, powerCheck, auraCheck, spellId)

  return CustomTrigger(code, "PLAYER_ENTERING_WORLD SPELLS_CHANGED PLAYER_TALENT_UPDATE CHARACTER_POINTS_CHANGED UPDATE_SHAPESHIFT_FORM UNIT_DISPLAYPOWER SPELL_UPDATE_COOLDOWN PLAYER_TARGET_CHANGED UNIT_AURA")
end

local function ResourceBar(id, parent, powerType, color, includeCombo)
  local data = Base(id, parent)
  data.regionType = "aurabar"
  data.width = COA_RESOURCE_WIDTH
  data.height = COA_RESOURCE_HEIGHT
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
  data.barColor = color
  data.backgroundColor = { 0.018, 0.018, 0.022, 0.96 }
  data.spark = false
  data.progressSource = { 1, "" }
  data.triggers = ResourceTrigger(powerType, includeCombo)
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
    {
      type = "subtext",
      text_visible = true,
      text_text = "%p / %t",
      text_font = "Fira Sans Heavy",
      text_fontSize = 10,
      text_fontType = "OUTLINE",
      text_color = { 1, 1, 1, 1 },
      text_justify = "CENTER",
      text_selfPoint = "CENTER",
      anchor_point = "CENTER",
      anchorXOffset = 0,
      anchorYOffset = 0,
    },
  }
  if includeCombo then
    data.subRegions[#data.subRegions + 1] = {
      type = "subtext",
      text_visible = true,
      text_text = "%s",
      text_font = "Fira Sans Heavy",
      text_fontSize = 13,
      text_fontType = "OUTLINE",
      text_color = { 1, 1, 1, 1 },
      text_justify = "LEFT",
      text_selfPoint = "LEFT",
      anchor_point = "RIGHT",
      anchorXOffset = 8,
      anchorYOffset = 0,
    }
  end
  return data
end

local function Icon(id, parent, spellId, requiredPowerType, auraUnit, size)
  local data = Base(id, parent)
  data.regionType = "icon"
  data.width = size
  data.height = size
  data.selfPoint = "CENTER"
  data.anchorPoint = "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset = 0
  data.yOffset = 0
  data.color = { 1, 1, 1, 1 }
  data.icon = true
  data.iconSource = -1
  data.displayIcon = GetSpellTexture(spellId) or 134400
  data.progressSource = { 1, "" }
  data.cooldown = true
  data.cooldownSwipe = true
  data.cooldownTextDisabled = false
  data.cooldownEdge = false
  data.zoom = 0.08
  data.triggers = AbilityTrigger(spellId, requiredPowerType, auraUnit)
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
  }
  return data
end

local function DynamicGroup(id, x, y, children, space)
  local data = Base(id)
  data.regionType = "dynamicgroup"
  data.controlledChildren = children
  data.anchorFrameType = "SCREEN"
  data.anchorPoint = "CENTER"
  data.selfPoint = "CENTER"
  data.xOffset = x
  data.yOffset = y
  data.grow = "HORIZONTAL"
  data.align = "CENTER"
  data.sort = "none"
  data.space = space or COA_ICON_SPACING
  data.stagger = 0
  data.animate = false
  data.scale = 1
  data.gridType = "RD"
  data.centerType = "LR"
  data.gridWidth = 18
  data.rowSpace = 0
  data.columnSpace = space or COA_ICON_SPACING
  data.useLimit = false
  data.limit = 18
  data.fullCircle = true
  data.rotation = 0
  data.radius = 200
  data.stepAngle = 15
  data.constantFactor = "RADIUS"
  data.subRegions = {}
  -- Keep the same harmless group trigger shape used by normal WeakAuras
  -- exports. Child visibility remains the actual source of group visibility.
  data.triggers = {
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
  }
  return data
end

local function AddAbility(displays, children, rootId, label, spellId, powerType, auraUnit, size)
  local id = rootId .. " — " .. label
  children[#children + 1] = id
  displays[#displays + 1] = Icon(id, rootId, spellId, powerType, auraUnit, size)
end

function PACKAGE:Build()
  RUI:EnsureDB()

  local displays = {}
  local resourceChildren = {}
  local mainChildren = {}
  local utilityChildren = {}

  local energyId = ROOT_RESOURCE .. " — Energy"
  local rageId = ROOT_RESOURCE .. " — Rage"
  local manaId = ROOT_RESOURCE .. " — Mana"
  resourceChildren = { energyId, rageId, manaId }
  displays[#displays + 1] = ResourceBar(energyId, ROOT_RESOURCE, 3, { 0.95, 0.82, 0.08, 1 }, true)
  displays[#displays + 1] = ResourceBar(rageId, ROOT_RESOURCE, 1, { 0.95, 0.20, 0.06, 1 }, false)
  displays[#displays + 1] = ResourceBar(manaId, ROOT_RESOURCE, 0, { 0.10, 0.42, 0.95, 1 }, false)

  -- Cat Form: compact rotational row.
  AddAbility(displays, mainChildren, ROOT_MAIN, "Cat — Shred", 27002, 3, nil, COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Cat — Rake", 27003, 3, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Cat — Rip", 27008, 3, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Cat — Mangle", 33983, 3, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Cat — Faerie Fire", 27011, 3, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Cat — Pounce", 27006, 3, nil, COA_MAIN_ICON)

  -- Bear Form. Mangle (Bear) rank 3 / canonical ID is 33987 in the TBC DB.
  AddAbility(displays, mainChildren, ROOT_MAIN, "Bear — Mangle", 33987, 1, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Bear — Lacerate", 33745, 1, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Bear — Swipe", 26997, 1, nil, COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Bear — Maul", 26996, 1, nil, COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Bear — Faerie Fire", 27011, 1, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Bear — Bash", 8983, 1, nil, COA_MAIN_ICON)

  -- Caster fallback keeps the Druid package useful outside Cat/Bear forms.
  AddAbility(displays, mainChildren, ROOT_MAIN, "Caster — Moonfire", 26988, 0, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Caster — Insect Swarm", 27013, 0, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Caster — Wrath", 26985, 0, nil, COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Caster — Starfire", 26986, 0, nil, COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Caster — Entangling Roots", 26989, 0, "target", COA_MAIN_ICON)
  AddAbility(displays, mainChildren, ROOT_MAIN, "Caster — Cyclone", 33786, 0, "target", COA_MAIN_ICON)

  -- Curated utility row. Form-specific abilities only appear in the relevant form.
  AddAbility(displays, utilityChildren, ROOT_UTILITY, "Barkskin", 22812, nil, "player", COA_UTILITY_ICON)
  AddAbility(displays, utilityChildren, ROOT_UTILITY, "Dash", 33357, 3, "player", COA_UTILITY_ICON)
  AddAbility(displays, utilityChildren, ROOT_UTILITY, "Feral Charge", 16979, 1, nil, COA_UTILITY_ICON)
  AddAbility(displays, utilityChildren, ROOT_UTILITY, "Innervate", 29166, nil, "player", COA_UTILITY_ICON)
  AddAbility(displays, utilityChildren, ROOT_UTILITY, "Rebirth", 26994, nil, nil, COA_UTILITY_ICON)
  AddAbility(displays, utilityChildren, ROOT_UTILITY, "Tranquility", 26983, nil, nil, COA_UTILITY_ICON)

  local roots = {
    DynamicGroup(ROOT_RESOURCE, COA_RESOURCE_X, COA_RESOURCE_Y, resourceChildren, 0),
    DynamicGroup(ROOT_MAIN, COA_MAIN_X, COA_MAIN_Y, mainChildren, COA_ICON_SPACING),
    DynamicGroup(ROOT_UTILITY, COA_UTILITY_X, COA_UTILITY_Y, utilityChildren, COA_ICON_SPACING),
  }

  return {
    roots = roots,
    displays = displays,
    expected = {
      [ROOT_RESOURCE] = { x = COA_RESOURCE_X, y = COA_RESOURCE_Y },
      [ROOT_MAIN] = { x = COA_MAIN_X, y = COA_MAIN_Y },
      [ROOT_UTILITY] = { x = COA_UTILITY_X, y = COA_UTILITY_Y },
    },
  }
end
