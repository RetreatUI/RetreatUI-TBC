local RUI = RetreatUITBC
if not RUI then return end

local Profiles = {}
RUI:RegisterModule("profiles", Profiles)

local PROFILE_NAME = "RetreatUI"
local RETREAT_FONT = "Fira Sans Heavy"
local RETREAT_TEXTURE = "ElvUI Norm"

local function DeepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, child in pairs(value) do copy[DeepCopy(key, seen)] = DeepCopy(child, seen) end
  return copy
end

local function Merge(target, source)
  for key, value in pairs(source) do
    if type(value) == "table" then
      target[key] = type(target[key]) == "table" and target[key] or {}
      Merge(target[key], value)
    else
      target[key] = value
    end
  end
end

local function CharacterKey()
  local name = UnitName and UnitName("player")
  local realm = GetRealmName and GetRealmName()
  if name and realm and realm ~= "" then return name .. " - " .. realm end
  return name
end

local function PlayerClassColor()
  local _, class = UnitClass("player")
  local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if color then
    return class, tonumber(color.r) or 1, tonumber(color.g) or 1, tonumber(color.b) or 1
  end
  return class or "UNKNOWN", 1, 0.49, 0.04
end

local function ApplyPlayerClassColor(profile)
  local class, r, g, b = PlayerClassColor()

  profile.general = type(profile.general) == "table" and profile.general or {}
  profile.general.valuecolor = { r = r, g = g, b = b, a = 1 }

  profile.unitframe = type(profile.unitframe) == "table" and profile.unitframe or {}
  profile.unitframe.colors = type(profile.unitframe.colors) == "table" and profile.unitframe.colors or {}
  profile.unitframe.colors.colorhealthbyvalue = false
  profile.unitframe.colors.healthclass = true
  profile.unitframe.colors.healthReaction = true
  profile.unitframe.colors.health = { r = r, g = g, b = b }

  local units = profile.unitframe.units
  if type(units) == "table" then
    if type(units.player) == "table" then
      if type(units.player.name) == "table" then units.player.name.text_format = "[namecolor][name:medium]" end
      if type(units.player.health) == "table" then units.player.health.text_format = "[namecolor][health:current]" end
    end
    if type(units.target) == "table" then
      if type(units.target.name) == "table" then units.target.name.text_format = "[namecolor][name:medium]" end
      if type(units.target.health) == "table" then units.target.health.text_format = "[namecolor][health:current]" end
    end
    if type(units.targettarget) == "table" and type(units.targettarget.name) == "table" then
      units.targettarget.name.text_format = "[namecolor][name:short]"
    end
  end

  return class
end

-- Profile exports can contain the same font setting in many nested tables.
-- Only string-valued font fields are normalized, so sizes, anchors, scripts,
-- colors and gameplay logic from the supplied profile remain untouched.
local function ForceRetreatUIFontFields(value, seen)
  if type(value) ~= "table" then return 0 end
  seen = seen or {}
  if seen[value] then return 0 end
  seen[value] = true

  local changed = 0
  for key, child in pairs(value) do
    if type(child) == "table" then
      changed = changed + ForceRetreatUIFontFields(child, seen)
    elseif type(key) == "string" and type(child) == "string" then
      local lowerKey = key:lower()
      local isFontFace = lowerKey == "font"
        or lowerKey == "font_face"
        or lowerKey == "fontface"
        or lowerKey:match("_font$") ~= nil
      if isFontFace and child ~= RETREAT_FONT then
        value[key] = RETREAT_FONT
        changed = changed + 1
      end
    end
  end
  return changed
end

local DETAILS_FALLBACK_STYLE = {
  skin = "ElvUI",
  row_height = 18,
  row_show_animation = { anim = "Fade", options = {} },
  bars_sort_direction = 1,
  toolbar_icon_file = "Interface\\AddOns\\Details\\images\\toolbar_icons",
  window_scale = 1,
  desaturated_menu = false,
  hide_in_combat_alpha = 0,
  bg_r = 0.012,
  bg_g = 0.012,
  bg_b = 0.018,
  bg_alpha = 0.88,
  row_info = {
    height = 18,
    space = 1,
    texture = RETREAT_TEXTURE,
    font_face = RETREAT_FONT,
    font_size = 11,
    font_outline = "OUTLINE",
  },
  window_info = {
    font_face = RETREAT_FONT,
    font_size = 11,
    font_outline = "OUTLINE",
  },
}

function Profiles:ApplyElvUI()
  local E = ElvUI and unpack and unpack(ElvUI)
  if not E then return false, "ElvUI is not loaded" end
  if type(RUI.ElvUIProfile) ~= "table" then return false, "RetreatUI ElvUI profile baseline is missing" end

  local profile = DeepCopy(RUI.ElvUIProfile)
  local class = ApplyPlayerClassColor(profile)

  ElvDB = type(ElvDB) == "table" and ElvDB or {}
  ElvDB.profiles = type(ElvDB.profiles) == "table" and ElvDB.profiles or {}
  ElvDB.profileKeys = type(ElvDB.profileKeys) == "table" and ElvDB.profileKeys or {}
  ElvDB.profiles[PROFILE_NAME] = DeepCopy(profile)

  local characterKey = CharacterKey()
  if characterKey then ElvDB.profileKeys[characterKey] = PROFILE_NAME end

  local activated = false
  if E.data and type(E.data.SetProfile) == "function" then
    local ok = pcall(E.data.SetProfile, E.data, PROFILE_NAME)
    activated = ok
  end

  if type(E.db) == "table" then
    Merge(E.db, profile)
    activated = true
  end

  if not activated then return false, "ElvUI profile could not be activated on this client build" end

  if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  if E.StaggeredUpdateAll then pcall(E.StaggeredUpdateAll, E) end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.elvui = {
    profile = PROFILE_NAME,
    installed = true,
    version = RUI.version,
    class = class,
    classColor = true,
  }
  return true, "RetreatUI ElvUI profile installed with class colors"
end

local function GetDetails()
  return _G.Details or _G._detalhes
end

local function ThemeDetailsProfile(profile)
  if type(profile) ~= "table" then return 0 end
  local changed = ForceRetreatUIFontFields(profile)
  Merge(profile, DETAILS_FALLBACK_STYLE)
  return changed
end

function Profiles:ApplyDetailsTheme()
  local details = GetDetails()
  if type(details) ~= "table" then return false, "Details is not loaded" end

  local changed = 0
  local profile
  if type(details.GetProfile) == "function" then
    local ok, value = pcall(details.GetProfile, details, PROFILE_NAME)
    if ok and type(value) == "table" then profile = value end
  end
  if not profile and type(details.GetCurrentProfile) == "function" then
    local ok, value = pcall(details.GetCurrentProfile, details)
    if ok and type(value) == "table" then profile = value end
  end
  if profile then changed = changed + ThemeDetailsProfile(profile) end

  if type(_G._detalhes_global) == "table" then
    changed = changed + ForceRetreatUIFontFields(_G._detalhes_global)
  end

  if type(details.GetInstance) == "function" then
    for index = 1, 20 do
      local ok, instance = pcall(details.GetInstance, details, index)
      if ok and type(instance) == "table" then
        changed = changed + ForceRetreatUIFontFields(instance)
        instance.row_info = instance.row_info or {}
        instance.row_info.height = 18
        instance.row_info.space = 1
        instance.row_info.texture = RETREAT_TEXTURE
        instance.row_info.font_face = RETREAT_FONT
        instance.row_info.font_size = 11
        instance.row_info.font_outline = "OUTLINE"
        instance.window_info = instance.window_info or {}
        instance.window_info.font_face = RETREAT_FONT
        instance.window_info.font_size = 11
        instance.window_info.font_outline = "OUTLINE"
      end
    end
  end

  if details.RefreshMainWindow then pcall(details.RefreshMainWindow, details, -1, true) end
  return true, "RetreatUI typography and textures applied to Details"
end

function Profiles:ApplyDetails()
  local details = GetDetails()
  if type(details) ~= "table" then return false, "Details is not loaded" end

  local payload = RUI.profilePayloads and RUI.profilePayloads.details
  if type(payload) ~= "string" or payload == "" then
    return false, "RetreatUI Details profile payload is missing"
  end
  if type(details.ImportProfile) ~= "function" then
    return false, "This Details build does not expose ImportProfile"
  end

  local ok, imported, importError = pcall(details.ImportProfile, details, payload, PROFILE_NAME, false, false, true)
  if not ok then return false, "Details import error: " .. tostring(imported) end
  if imported == false then return false, tostring(importError or "Details rejected the RetreatUI profile") end

  if type(details.ApplyProfile) == "function" then
    local applyOK, applyResult = pcall(details.ApplyProfile, details, PROFILE_NAME)
    if not applyOK or applyResult == false then
      return false, "Details profile imported, but activation failed: " .. tostring(applyResult)
    end
  end

  local themed, themeMessage = self:ApplyDetailsTheme()
  if not themed then return false, themeMessage end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.details = {
    profile = PROFILE_NAME,
    installed = true,
    imported = true,
    universal = true,
    themed = true,
    version = RUI.version,
  }
  return true, "RetreatUI Details profile imported and themed"
end

function Profiles:ApplyPlaterTheme()
  if not Plater then return false, "Plater is not loaded" end
  local profile = Plater.db and Plater.db.profile
  if type(profile) ~= "table" then return false, "Plater profile database is unavailable" end

  local changed = ForceRetreatUIFontFields(profile)

  -- These are Plater's shared statusbar media fields. Normalizing only these
  -- keeps the supplied profile's sizing, colors, scripts, mods and tracking
  -- behavior intact while making it visually consistent with RetreatUI.
  profile.health_statusbar_texture = RETREAT_TEXTURE
  profile.health_statusbar_bgtexture = RETREAT_TEXTURE
  profile.cast_statusbar_texture = RETREAT_TEXTURE
  profile.cast_statusbar_bgtexture = RETREAT_TEXTURE

  if type(Plater.RefreshDBUpvalues) == "function" then pcall(Plater.RefreshDBUpvalues) end
  if type(Plater.RefreshDBLists) == "function" then pcall(Plater.RefreshDBLists) end
  if type(Plater.UpdateAllPlates) == "function" then pcall(Plater.UpdateAllPlates) end

  return true, string.format("RetreatUI font and textures applied to Plater (%d font fields)", changed)
end

function Profiles:ApplyPlater()
  if not Plater then return false, "Plater is not loaded" end
  local payload = RUI.profilePayloads and RUI.profilePayloads.plater
  if type(payload) ~= "string" or payload == "" then
    return false, "RetreatUI Plater profile payload is missing"
  end
  if type(Plater.ImportProfile) ~= "function" then
    return false, "This Plater build does not expose ImportProfile"
  end

  local ok, result = pcall(Plater.ImportProfile, payload, true, true)
  if not ok then return false, "Plater import error: " .. tostring(result) end
  if result == false then return false, "Plater rejected the RetreatUI profile" end

  local themed, themeMessage = self:ApplyPlaterTheme()
  if not themed then return false, themeMessage end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.plater = {
    installed = true,
    imported = true,
    universal = true,
    themed = true,
    version = RUI.version,
  }
  return true, "RetreatUI Plater profile imported and themed"
end

function Profiles:InstallSelected()
  local db = RUI:EnsureDB()
  local results = {}
  if db.selected.elvui then results.elvui = { self:ApplyElvUI() } end
  if db.selected.plater then results.plater = { self:ApplyPlater() } end
  if db.selected.details then results.details = { self:ApplyDetails() } end
  return results
end
