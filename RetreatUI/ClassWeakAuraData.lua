local RUI = RetreatUITBC
if not RUI then return end

RUI.weakAuraPackages = RUI.weakAuraPackages or {}

-- Shared layout contract. Druid keeps its existing package untouched; every
-- other TBC class now uses the same Resource / Main / Utility geometry.
local RESOURCE_X, RESOURCE_Y = 0, -152
local MAIN_X, MAIN_Y = 0, -183
local UTILITY_X, UTILITY_Y = 0, -224
local RESOURCE_WIDTH, RESOURCE_HEIGHT = 360, 16
local MAIN_ICON, UTILITY_ICON = 38, 32
local ICON_SPACING = 1

local POWER_COLORS = {
  [0] = { 0.10, 0.42, 0.95, 1 }, -- Mana
  [1] = { 0.95, 0.20, 0.06, 1 }, -- Rage
  [3] = { 0.95, 0.82, 0.08, 1 }, -- Energy
}

local POWER_NAMES = {
  [0] = "Mana",
  [1] = "Rage",
  [3] = "Energy",
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
    load = ClassLoad(classToken),
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

local function ResourceTrigger(powerType)
  local powerName = POWER_NAMES[powerType] or "Resource"
  local code = string.format([[
function(allstates, event, unit)
  if (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER") and unit and unit ~= "player" then
    return false
  end

  local state = allstates[""] or {}
  allstates[""] = state
  local currentType = UnitPowerType("player")
  if currentType ~= %d then
    state.show = false
    state.changed = true
    return true
  end

  local current = UnitPower("player", currentType) or 0
  local maximum = UnitPowerMax("player", currentType) or 0
  state.show = true
  state.changed = true
  state.progressType = "static"
  state.value = current
  state.total = math.max(1, maximum)
  state.name = %q
  return true
end
]], powerType, powerName)

  return CustomTrigger(code, "PLAYER_ENTERING_WORLD UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER")
end

local function SpecCheckCode(specs)
  if specs == nil then return "" end
  if type(specs) ~= "table" then specs = { specs } end
  local comparisons = {}
  for _, index in ipairs(specs) do
    comparisons[#comparisons + 1] = "bestIndex == " .. tostring(index)
  end
  local allowed = table.concat(comparisons, " or ")
  return string.format([[
  local bestIndex, bestPoints = 1, -1
  if GetTalentTabInfo then
    for talentTab = 1, 3 do
      local _, _, points = GetTalentTabInfo(talentTab)
      points = tonumber(points) or 0
      if points > bestPoints then
        bestIndex = talentTab
        bestPoints = points
      end
    end
  end
  if bestPoints > 0 and not (%s) then
    state.show = false
    state.changed = true
    return true
  end
]], allowed)
end

local function AbilityTrigger(spellId, specs, auraUnit)
  local specCheck = SpecCheckCode(specs)
  local auraCheck = ""
  if auraUnit == "target" or auraUnit == "player" then
    local auraFunction = auraUnit == "target" and "UnitDebuff" or "UnitBuff"
    auraCheck = string.format([[
  if UnitExists("%s") then
    for index = 1, 40 do
      local auraName, _, _, auraCount, _, auraDuration, auraExpiration, auraCaster, _, _, auraSpellId = %s("%s", index)
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
          state.stacks = auraCount and auraCount > 0 and auraCount or nil
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
  state.stacks = nil
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
]], spellId, spellId, specCheck, auraCheck, spellId)

  return CustomTrigger(code, "PLAYER_ENTERING_WORLD SPELLS_CHANGED PLAYER_TALENT_UPDATE CHARACTER_POINTS_CHANGED SPELL_UPDATE_COOLDOWN PLAYER_TARGET_CHANGED UNIT_AURA")
end

local function ResourceBar(id, parent, classToken, powerType)
  local data = Base(id, parent, classToken)
  data.regionType = "aurabar"
  data.width = RESOURCE_WIDTH
  data.height = RESOURCE_HEIGHT
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
  data.barColor = POWER_COLORS[powerType] or { 1, 1, 1, 1 }
  data.backgroundColor = { 0.018, 0.018, 0.022, 0.96 }
  data.spark = false
  data.progressSource = { 1, "" }
  data.triggers = ResourceTrigger(powerType)
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
  return data
end

local function Icon(id, parent, classToken, ability, size)
  local data = Base(id, parent, classToken)
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
  data.displayIcon = GetSpellTexture(ability.spellId) or 134400
  data.progressSource = { 1, "" }
  data.cooldown = true
  data.cooldownSwipe = true
  data.cooldownTextDisabled = false
  data.cooldownEdge = false
  data.zoom = 0.08
  data.triggers = AbilityTrigger(ability.spellId, ability.spec, ability.aura)
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
  }
end

local function DynamicGroup(id, classToken, x, y, children, space)
  local data = Base(id, nil, classToken)
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
  data.space = space or ICON_SPACING
  data.stagger = 0
  data.animate = false
  data.scale = 1
  data.gridType = "RD"
  data.centerType = "LR"
  data.gridWidth = 18
  data.rowSpace = 0
  data.columnSpace = space or ICON_SPACING
  data.useLimit = false
  data.limit = 18
  data.fullCircle = true
  data.rotation = 0
  data.radius = 200
  data.stepAngle = 15
  data.constantFactor = "RADIUS"
  data.subRegions = {}
  data.triggers = GroupTrigger()
  return data
end

local function Ability(label, spellId, spec, aura)
  return { label = label, spellId = spellId, spec = spec, aura = aura }
end

local CLASS_DEFINITIONS = {
  HUNTER = {
    key = "hunter", power = 0,
    main = {
      Ability("BM — Steady Shot", 34120, 1), Ability("BM — Kill Command", 34026, 1),
      Ability("BM — Arcane Shot", 27019, 1), Ability("BM — Multi-Shot", 27021, 1),
      Ability("BM — Serpent Sting", 27016, 1, "target"), Ability("BM — Bestial Wrath", 19574, 1, "player"),
      Ability("MM — Steady Shot", 34120, 2), Ability("MM — Aimed Shot", 27632, 2),
      Ability("MM — Arcane Shot", 27019, 2), Ability("MM — Multi-Shot", 27021, 2),
      Ability("MM — Serpent Sting", 27016, 2, "target"), Ability("MM — Rapid Fire", 3045, 2, "player"),
      Ability("SV — Steady Shot", 34120, 3), Ability("SV — Arcane Shot", 27019, 3),
      Ability("SV — Multi-Shot", 27021, 3), Ability("SV — Serpent Sting", 27016, 3, "target"),
      Ability("SV — Explosive Trap", 27025, 3), Ability("SV — Wyvern Sting", 27068, 3, "target"),
    },
    utility = {
      Ability("Feign Death", 5384), Ability("Misdirection", 34477), Ability("Freezing Trap", 27753),
      Ability("Flare", 1543), Ability("Scatter Shot", 19503), Ability("Silencing Shot", 34490),
      Ability("Deterrence", 19263, nil, "player"), Ability("Readiness", 23989),
    },
  },

  MAGE = {
    key = "mage", power = 0,
    main = {
      Ability("Arcane — Arcane Blast", 30451, 1), Ability("Arcane — Arcane Missiles", 38704, 1),
      Ability("Arcane — Arcane Power", 12042, 1, "player"), Ability("Arcane — Presence of Mind", 12043, 1, "player"),
      Ability("Arcane — Slow", 31589, 1, "target"),
      Ability("Fire — Fireball", 38692, 2), Ability("Fire — Scorch", 27074, 2),
      Ability("Fire — Fire Blast", 27079, 2), Ability("Fire — Combustion", 11129, 2, "player"),
      Ability("Fire — Dragon's Breath", 33043, 2), Ability("Fire — Blast Wave", 33933, 2),
      Ability("Frost — Frostbolt", 38697, 3), Ability("Frost — Ice Lance", 30455, 3),
      Ability("Frost — Cone of Cold", 27087, 3), Ability("Frost — Icy Veins", 12472, 3, "player"),
      Ability("Frost — Water Elemental", 31687, 3), Ability("Frost — Blizzard", 27085, 3),
    },
    utility = {
      Ability("Counterspell", 2139), Ability("Blink", 1953), Ability("Evocation", 12051, nil, "player"),
      Ability("Frost Nova", 27088), Ability("Ice Block", 45438, nil, "player"), Ability("Ice Barrier", 33405, nil, "player"),
      Ability("Cold Snap", 11958),
    },
  },

  PALADIN = {
    key = "paladin", power = 0,
    main = {
      Ability("Holy — Holy Light", 27136, 1), Ability("Holy — Flash of Light", 27137, 1),
      Ability("Holy — Holy Shock", 33072, 1), Ability("Holy — Divine Favor", 20216, 1, "player"),
      Ability("Holy — Divine Illumination", 31842, 1, "player"),
      Ability("Prot — Consecration", 27173, 2), Ability("Prot — Judgement", 20271, 2),
      Ability("Prot — Holy Shield", 27179, 2, "player"), Ability("Prot — Avenger's Shield", 31935, 2),
      Ability("Prot — Righteous Defense", 31789, 2),
      Ability("Ret — Crusader Strike", 35395, 3), Ability("Ret — Judgement", 20271, 3),
      Ability("Ret — Consecration", 27173, 3), Ability("Ret — Hammer of Wrath", 32772, 3),
      Ability("Ret — Seal of Blood", 31892, 3, "player"), Ability("Ret — Seal of Command", 27170, 3, "player"),
      Ability("Ret — Avenging Wrath", 31884, 3, "player"),
    },
    utility = {
      Ability("Hammer of Justice", 10308), Ability("Cleanse", 4987), Ability("Divine Shield", 1020, nil, "player"),
      Ability("Blessing of Protection", 10278), Ability("Blessing of Freedom", 1044), Ability("Lay on Hands", 27154),
      Ability("Repentance", 20066, 3, "target"),
    },
  },

  PRIEST = {
    key = "priest", power = 0,
    main = {
      Ability("Disc — Power Word: Shield", 25218, 1), Ability("Disc — Flash Heal", 25235, 1),
      Ability("Disc — Prayer of Mending", 33076, 1), Ability("Disc — Pain Suppression", 33206, 1),
      Ability("Disc — Power Infusion", 10060, 1), Ability("Disc — Inner Focus", 14751, 1, "player"),
      Ability("Holy — Flash Heal", 25235, 2), Ability("Holy — Greater Heal", 25314, 2),
      Ability("Holy — Prayer of Mending", 33076, 2), Ability("Holy — Renew", 25315, 2),
      Ability("Holy — Circle of Healing", 34866, 2), Ability("Holy — Binding Heal", 32546, 2),
      Ability("Shadow — SW:P", 25368, 3, "target"), Ability("Shadow — Vampiric Touch", 34917, 3, "target"),
      Ability("Shadow — Mind Blast", 25375, 3), Ability("Shadow — Mind Flay", 25387, 3),
      Ability("Shadow — SW:D", 32996, 3), Ability("Shadow — Vampiric Embrace", 15286, 3, "target"),
    },
    utility = {
      Ability("Psychic Scream", 27610), Ability("Shadowfiend", 34433), Ability("Dispel Magic", 988),
      Ability("Fear Ward", 6346), Ability("Fade", 25429, nil, "player"), Ability("Silence", 15487, 3),
    },
  },

  ROGUE = {
    key = "rogue", power = 3,
    main = {
      Ability("Assa — Mutilate", 1329, 1), Ability("Assa — Slice and Dice", 6774, 1, "player"),
      Ability("Assa — Rupture", 26867, 1, "target"), Ability("Assa — Eviscerate", 31016, 1),
      Ability("Assa — Shiv", 5938, 1), Ability("Assa — Cold Blood", 14177, 1, "player"),
      Ability("Combat — Sinister Strike", 26862, 2), Ability("Combat — Slice and Dice", 6774, 2, "player"),
      Ability("Combat — Rupture", 26867, 2, "target"), Ability("Combat — Eviscerate", 31016, 2),
      Ability("Combat — Adrenaline Rush", 13750, 2, "player"), Ability("Combat — Blade Flurry", 13877, 2, "player"),
      Ability("Sub — Hemorrhage", 26864, 3, "target"), Ability("Sub — Backstab", 26863, 3),
      Ability("Sub — Rupture", 26867, 3, "target"), Ability("Sub — Eviscerate", 31016, 3),
      Ability("Sub — Slice and Dice", 6774, 3, "player"), Ability("Sub — Shadowstep", 36554, 3, "player"),
    },
    utility = {
      Ability("Kick", 38768), Ability("Cloak of Shadows", 31224, nil, "player"), Ability("Evasion", 26669, nil, "player"),
      Ability("Vanish", 26889), Ability("Sprint", 11305, nil, "player"), Ability("Blind", 2094, nil, "target"),
      Ability("Preparation", 14185, 3),
    },
  },

  SHAMAN = {
    key = "shaman", power = 0,
    main = {
      Ability("Ele — Lightning Bolt", 25449, 1), Ability("Ele — Chain Lightning", 25442, 1),
      Ability("Ele — Flame Shock", 29228, 1, "target"), Ability("Ele — Earth Shock", 25454, 1),
      Ability("Ele — Elemental Mastery", 16166, 1, "player"), Ability("Ele — Totem of Wrath", 30706, 1),
      Ability("Enh — Stormstrike", 17364, 2, "target"), Ability("Enh — Earth Shock", 25454, 2),
      Ability("Enh — Flame Shock", 29228, 2, "target"), Ability("Enh — Shamanistic Rage", 30823, 2, "player"),
      Ability("Enh — Windfury Weapon", 25505, 2), Ability("Enh — Fire Nova Totem", 25547, 2),
      Ability("Resto — Chain Heal", 25423, 3), Ability("Resto — Healing Wave", 25396, 3),
      Ability("Resto — Lesser Healing Wave", 25420, 3), Ability("Resto — Earth Shield", 32594, 3),
      Ability("Resto — Nature's Swiftness", 16188, 3, "player"), Ability("Resto — Mana Tide", 16190, 3),
    },
    utility = {
      Ability("Heroism", 32182), Ability("Bloodlust", 2825), Ability("Grounding Totem", 8177),
      Ability("Tremor Totem", 8143), Ability("Earth Elemental", 2062), Ability("Fire Elemental", 2894),
      Ability("Purge", 27626),
    },
  },

  WARLOCK = {
    key = "warlock", power = 0,
    main = {
      Ability("Aff — Corruption", 27216, 1, "target"), Ability("Aff — Curse of Agony", 27218, 1, "target"),
      Ability("Aff — Unstable Affliction", 30405, 1, "target"), Ability("Aff — Siphon Life", 30911, 1, "target"),
      Ability("Aff — Seed of Corruption", 27243, 1, "target"), Ability("Aff — Shadow Bolt", 27209, 1),
      Ability("Demo — Shadow Bolt", 27209, 2), Ability("Demo — Corruption", 27216, 2, "target"),
      Ability("Demo — Soul Link", 19028, 2, "player"), Ability("Demo — Fel Domination", 18708, 2, "player"),
      Ability("Demo — Summon Felguard", 30146, 2), Ability("Demo — Demonic Sacrifice", 18788, 2),
      Ability("Destro — Shadow Bolt", 27209, 3), Ability("Destro — Incinerate", 32231, 3),
      Ability("Destro — Immolate", 27215, 3, "target"), Ability("Destro — Conflagrate", 17962, 3),
      Ability("Destro — Shadowburn", 30546, 3), Ability("Destro — Shadowfury", 30414, 3),
    },
    utility = {
      Ability("Death Coil", 27223), Ability("Soulshatter", 29858), Ability("Howl of Terror", 17928),
      Ability("Spell Lock", 19647), Ability("Shadow Ward", 28610, nil, "player"), Ability("Fear", 6215, nil, "target"),
    },
  },

  WARRIOR = {
    key = "warrior", power = 1,
    main = {
      Ability("Arms — Mortal Strike", 30330, 1), Ability("Arms — Overpower", 11585, 1),
      Ability("Arms — Execute", 25236, 1), Ability("Arms — Slam", 25242, 1),
      Ability("Arms — Rend", 25208, 1, "target"), Ability("Arms — Death Wish", 12292, 1, "player"),
      Ability("Fury — Bloodthirst", 30335, 2), Ability("Fury — Whirlwind", 1680, 2),
      Ability("Fury — Execute", 25236, 2), Ability("Fury — Slam", 25242, 2),
      Ability("Fury — Rampage", 30033, 2, "player"), Ability("Fury — Recklessness", 1719, 2, "player"),
      Ability("Prot — Shield Slam", 30356, 3), Ability("Prot — Revenge", 30357, 3),
      Ability("Prot — Devastate", 30022, 3), Ability("Prot — Shield Block", 2565, 3, "player"),
      Ability("Prot — Thunder Clap", 25264, 3), Ability("Prot — Taunt", 355, 3),
    },
    utility = {
      Ability("Pummel", 13491), Ability("Shield Bash", 29704), Ability("Spell Reflection", 23920, nil, "player"),
      Ability("Shield Wall", 871, nil, "player"), Ability("Last Stand", 12976, 3, "player"),
      Ability("Berserker Rage", 18499, nil, "player"), Ability("Intercept", 25275), Ability("Charge", 11578),
    },
  },
}

local function AddAbility(displays, children, rootId, classToken, ability, size)
  local id = rootId .. " — " .. ability.label
  children[#children + 1] = id
  displays[#displays + 1] = Icon(id, rootId, classToken, ability, size)
end

local function RegisterPackage(classToken, definition)
  local PACKAGE = {}
  RUI.weakAuraPackages[definition.key] = PACKAGE

  local displayClass = classToken:sub(1, 1) .. classToken:sub(2):lower()
  local ROOT_RESOURCE = "RetreatUI TBC — " .. displayClass .. " Resource"
  local ROOT_MAIN = "RetreatUI TBC — " .. displayClass .. " Main"
  local ROOT_UTILITY = "RetreatUI TBC — " .. displayClass .. " Utility"

  PACKAGE.rootIds = { ROOT_RESOURCE, ROOT_MAIN, ROOT_UTILITY }

  function PACKAGE:Build()
    RUI:EnsureDB()

    local displays = {}
    local resourceChildren = {}
    local mainChildren = {}
    local utilityChildren = {}

    local resourceId = ROOT_RESOURCE .. " — " .. (POWER_NAMES[definition.power] or "Resource")
    resourceChildren[1] = resourceId
    displays[#displays + 1] = ResourceBar(resourceId, ROOT_RESOURCE, classToken, definition.power)

    for _, ability in ipairs(definition.main or {}) do
      AddAbility(displays, mainChildren, ROOT_MAIN, classToken, ability, MAIN_ICON)
    end
    for _, ability in ipairs(definition.utility or {}) do
      AddAbility(displays, utilityChildren, ROOT_UTILITY, classToken, ability, UTILITY_ICON)
    end

    local roots = {
      DynamicGroup(ROOT_RESOURCE, classToken, RESOURCE_X, RESOURCE_Y, resourceChildren, 0),
      DynamicGroup(ROOT_MAIN, classToken, MAIN_X, MAIN_Y, mainChildren, ICON_SPACING),
      DynamicGroup(ROOT_UTILITY, classToken, UTILITY_X, UTILITY_Y, utilityChildren, ICON_SPACING),
    }

    return {
      roots = roots,
      displays = displays,
      expected = {
        [ROOT_RESOURCE] = { x = RESOURCE_X, y = RESOURCE_Y },
        [ROOT_MAIN] = { x = MAIN_X, y = MAIN_Y },
        [ROOT_UTILITY] = { x = UTILITY_X, y = UTILITY_Y },
      },
    }
  end
end

for classToken, definition in pairs(CLASS_DEFINITIONS) do
  RegisterPackage(classToken, definition)
end
