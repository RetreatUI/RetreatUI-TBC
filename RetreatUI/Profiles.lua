local RUI = RetreatUITBC
if not RUI then return end

local Profiles = {}
RUI:RegisterModule("profiles", Profiles)

local PROFILE_NAME = "RetreatUI"

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

local DETAILS_PROFILE = {
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
    texture = "ElvUI Norm",
    font_face = "Fira Sans Heavy",
    font_size = 11,
    font_outline = "OUTLINE",
  },
  window_info = {
    font_face = "Fira Sans Heavy",
    font_size = 11,
    font_outline = "OUTLINE",
  },
}

function Profiles:ApplyElvUI()
  local E = ElvUI and unpack and unpack(ElvUI)
  if not E then return false, "ElvUI is not loaded" end
  if type(RUI.ElvUIProfile) ~= "table" then return false, "RetreatUI ElvUI profile baseline is missing" end

  ElvDB = type(ElvDB) == "table" and ElvDB or {}
  ElvDB.profiles = type(ElvDB.profiles) == "table" and ElvDB.profiles or {}
  ElvDB.profileKeys = type(ElvDB.profileKeys) == "table" and ElvDB.profileKeys or {}
  ElvDB.profiles[PROFILE_NAME] = DeepCopy(RUI.ElvUIProfile)

  local characterKey = CharacterKey()
  if characterKey then ElvDB.profileKeys[characterKey] = PROFILE_NAME end

  local activated = false
  if E.data and type(E.data.SetProfile) == "function" then
    local ok = pcall(E.data.SetProfile, E.data, PROFILE_NAME)
    activated = ok
  end

  -- Older TBC ElvUI builds can expose a live database without the newer
  -- SetProfile path. Keep the persisted named profile as the source of truth,
  -- then mirror it into the live table so the installer works on those builds.
  if type(E.db) == "table" then
    Merge(E.db, RUI.ElvUIProfile)
    activated = true
  end

  if not activated then return false, "ElvUI profile could not be activated on this client build" end

  if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  if E.StaggeredUpdateAll then pcall(E.StaggeredUpdateAll, E) end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.elvui = { profile = PROFILE_NAME, installed = true, version = RUI.version }
  return true, "RetreatUI ElvUI profile installed"
end

local function GetDetails()
  return _G.Details or _G._detalhes
end

function Profiles:ApplyDetails()
  local details = GetDetails()
  if type(details) ~= "table" then return false, "Details is not loaded" end

  local profile
  if type(details.GetProfile) == "function" then
    local ok, value = pcall(details.GetProfile, details, PROFILE_NAME)
    if ok and type(value) == "table" then profile = value end
  end

  if not profile and type(details.CreateProfile) == "function" then
    pcall(details.CreateProfile, details, PROFILE_NAME)
    if type(details.GetProfile) == "function" then
      local ok, value = pcall(details.GetProfile, details, PROFILE_NAME)
      if ok and type(value) == "table" then profile = value end
    end
  end

  -- Details versions in TBC differ quite a bit. If the named-profile API is
  -- unavailable, style the current profile rather than claiming success with
  -- no visible change.
  if not profile and type(details.GetCurrentProfile) == "function" then
    local ok, value = pcall(details.GetCurrentProfile, details)
    if ok and type(value) == "table" then profile = value end
  end

  if type(profile) ~= "table" then return false, "Details profile API is unavailable" end
  Merge(profile, DETAILS_PROFILE)

  if type(details.ApplyProfile) == "function" then
    local ok, result = pcall(details.ApplyProfile, details, PROFILE_NAME)
    if not ok or result == false then
      -- The profile table is still installed/styled; some classic builds only
      -- expose the current profile and reject ApplyProfile by name.
    end
  end

  if type(details.GetInstance) == "function" then
    for index = 1, 20 do
      local ok, instance = pcall(details.GetInstance, details, index)
      if ok and type(instance) == "table" then
        instance.row_info = instance.row_info or {}
        instance.row_info.font_face = "Fira Sans Heavy"
        instance.row_info.font_size = 11
        instance.row_info.font_outline = "OUTLINE"
        instance.window_info = instance.window_info or {}
        instance.window_info.font_face = "Fira Sans Heavy"
        instance.window_info.font_size = 11
        instance.window_info.font_outline = "OUTLINE"
      end
    end
  end

  if details.RefreshMainWindow then pcall(details.RefreshMainWindow, details, -1, true) end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.details = { profile = PROFILE_NAME, installed = true, version = RUI.version }
  return true, "RetreatUI Details profile installed"
end

function Profiles:ApplyPlater()
  if not Plater then return false, "Plater is not loaded" end
  if type(RUI.profilePayloads.plater) ~= "string" or RUI.profilePayloads.plater == "" then
    return false, "Plater profile is not embedded in this beta"
  end
  if type(Plater.ImportProfile) == "function" then
    local ok, result = pcall(Plater.ImportProfile, RUI.profilePayloads.plater, true, true)
    if not ok then return false, tostring(result) end
    return true, "RetreatUI Plater profile imported"
  end
  return false, "This Plater build does not expose ImportProfile"
end

function Profiles:InstallSelected()
  local db = RUI:EnsureDB()
  local results = {}
  if db.selected.elvui then results.elvui = { self:ApplyElvUI() } end
  if db.selected.plater then results.plater = { self:ApplyPlater() } end
  if db.selected.details then results.details = { self:ApplyDetails() } end
  return results
end
