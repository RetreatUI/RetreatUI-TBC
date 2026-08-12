local RUI = RetreatUITBC
if not RUI then return end

local AURAS = RUI.tbcAuraBarData
local PACKAGES = RUI.weakAuraPackages
if type(AURAS) ~= "table" or type(PACKAGES) ~= "table" then return end

local AURA_WIDTH, AURA_HEIGHT = 34, 26
local AURA_SPACING = 4
local AURA_Y = 47
local POWER_ANCHOR = "WeakAuras:Class Power Bar"

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
    class = { single = classToken, multi = {} },
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
    actions = {start = {do_custom = false}, finish = {do_custom = false}, init = {do_custom = false}},
    animation = {
      start = {type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3},
      main = {type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3},
      finish = {type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3},
    },
    authorOptions = {}, conditions = {}, config = {}, information = {},
    load = ClassLoad(classToken, spellKnown), alpha = 1, frameStrata = 1,
  }
end

local function DummyTrigger()
  return {
    [1] = {
      trigger = {
        type = "aura2", event = "Health", unit = "player", debuffType = "HELPFUL",
        names = {}, spellIds = {}, subeventPrefix = "SPELL", subeventSuffix = "_CAST_START",
      },
      untrigger = {},
    },
    activeTriggerMode = -10,
    disjunctive = "any",
  }
end

local function AuraGroup(id, classToken, children)
  local data = Base(id, nil, classToken)
  data.regionType = "dynamicgroup"
  data.controlledChildren = children or {}
  data.anchorFrameType = "SELECTFRAME"
  data.anchorFrameFrame = POWER_ANCHOR
  data.anchorPoint = "TOP"
  data.selfPoint = "CENTER"
  data.xOffset = 0
  data.yOffset = AURA_Y
  data.grow = "HORIZONTAL"
  data.align = "CENTER"
  data.sort = "none"
  data.space = AURA_SPACING
  data.stagger = 0
  data.animate = false
  data.scale = 1
  data.gridType = "RD"
  data.centerType = "LR"
  data.gridWidth = 24
  data.rowSpace = AURA_SPACING
  data.columnSpace = AURA_SPACING
  data.useLimit = false
  data.limit = 24
  data.fullCircle = true
  data.rotation = 0
  data.radius = 200
  data.stepAngle = 15
  data.constantFactor = "RADIUS"
  data.subRegions = {}
  data.triggers = DummyTrigger()
  return data
end

local function Border()
  return {
    type = "subborder", border_visible = true, border_color = {0, 0, 0, 1},
    border_edge = "Square Full White", border_offset = 0, border_size = 1,
  }
end

local function Icon(id, parent, classToken, entry)
  local data = Base(id, parent, classToken, entry.loadSpell)
  data.regionType = "icon"
  data.width, data.height = AURA_WIDTH, AURA_HEIGHT
  data.selfPoint, data.anchorPoint = "CENTER", "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset, data.yOffset = 0, 0
  data.color = {1, 1, 1, 1}
  data.icon = true
  data.iconSource = -1
  local textureSpell = entry.spell or entry.loadSpell or (entry.auras and tonumber(entry.auras[1]))
  data.displayIcon = (textureSpell and GetSpellTexture and GetSpellTexture(textureSpell)) or 134400
  data.progressSource = {1, ""}
  data.cooldown = true
  data.cooldownSwipe = true
  data.cooldownTextDisabled = false
  data.cooldownEdge = false
  data.zoom = 0.08
  data.subRegions = {
    {type = "subbackground"},
    Border(),
    {
      type = "subtext", text_visible = true, text_text = "%s", text_font = "Fira Sans Heavy",
      text_fontSize = 10, text_fontType = "OUTLINE", text_color = {1, 1, 1, 1},
      text_justify = "RIGHT", text_selfPoint = "BOTTOMRIGHT", anchor_point = "BOTTOMRIGHT",
      anchorXOffset = -1, anchorYOffset = 1,
    },
  }
  return data
end

local function AuraTrigger(entry)
  local ids = {}
  for index, value in ipairs(entry.auras or {}) do ids[index] = tostring(value) end
  return {
    trigger = {
      type = "aura2", event = "Health", unit = entry.unit or "player", use_unit = true,
      debuffType = entry.debuffType or "HELPFUL", auraspellids = ids, useExactSpellId = true,
      matchesShowOn = "showOnActive", buffShowOn = "showOnActive", ownOnly = entry.unit == "target",
      names = {}, spellIds = {}, subeventPrefix = "SPELL", subeventSuffix = "_CAST_START",
    },
    untrigger = {},
  }
end

local function SpellTrigger(entry, event)
  return {
    trigger = {
      type = "spell", event = event, unit = "player", use_unit = true,
      spellName = entry.spell, use_spellName = true, genericShowOn = "showOnActive", use_genericShowOn = true,
      debuffType = "HELPFUL", names = {}, spellIds = {}, subeventPrefix = "SPELL", subeventSuffix = "_CAST_START",
    },
    untrigger = {},
  }
end

local function CombatLogTrigger(entry)
  local ids = {}
  for index, value in ipairs(entry.spellIds or {}) do ids[index] = tostring(value) end
  return {
    trigger = {
      type = "combatlog", event = "Combat Log", subeventPrefix = "SPELL", subeventSuffix = "_CAST_SUCCESS",
      sourceUnit = "player", use_sourceUnit = true, spellId = ids, use_spellId = true,
      duration = tostring(entry.duration or 30), unevent = "timed", custom_hide = "timed",
      unit = "target", debuffType = "HARMFUL", names = {}, spellIds = {},
    },
    untrigger = {},
  }
end

local function HealthTrigger(entry)
  return {
    trigger = {
      type = "unit", event = "Health", unit = "target", use_unit = true,
      use_percenthealth = true, percenthealth = {tostring(entry.healthPercent or 20)}, percenthealth_operator = {"<="},
      debuffType = "HELPFUL", names = {}, spellIds = {}, subeventPrefix = "SPELL", subeventSuffix = "_CAST_START",
    },
    untrigger = {},
  }
end

local function BuildIcon(id, parent, classToken, entry)
  local data = Icon(id, parent, classToken, entry)
  local trigger
  if entry.mode == "combatlog" then
    trigger = CombatLogTrigger(entry)
  elseif entry.mode == "health" then
    trigger = HealthTrigger(entry)
  elseif entry.mode == "queued" then
    trigger = SpellTrigger(entry, "Queued Action")
  elseif entry.mode == "usable" then
    trigger = SpellTrigger(entry, "Action Usable")
  elseif entry.auras then
    trigger = AuraTrigger(entry)
  else
    trigger = SpellTrigger(entry, "Cooldown Progress (Spell)")
  end
  data.triggers = {[1] = trigger, activeTriggerMode = -10, disjunctive = "any"}
  return data
end

for classToken, entries in pairs(AURAS) do
  local package = PACKAGES[classToken:lower()]
  if package and type(package.Build) == "function" then
    local originalBuild = package.Build
    local displayClass = DisplayClass(classToken)
    local rootId = "RetreatUI TBC — " .. displayClass .. " Aura Bar"

    package.Build = function(self)
      local result = originalBuild(self)
      result.roots = result.roots or {}
      result.displays = result.displays or {}

      local children = {}
      for _, entry in ipairs(entries) do
        local id = rootId .. " — " .. entry.name
        children[#children + 1] = id
        result.displays[#result.displays + 1] = BuildIcon(id, rootId, classToken, entry)
      end
      result.roots[#result.roots + 1] = AuraGroup(rootId, classToken, children)
      return result
    end
  end
end
