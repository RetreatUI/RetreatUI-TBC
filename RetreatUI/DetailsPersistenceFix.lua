local RUI = RetreatUITBC
if not RUI then return end

local Profiles = RUI.modules and RUI.modules.profiles
if not Profiles then return end

local PROFILE_NAME = "RetreatUI"

local function DeepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, child in pairs(value) do
    copy[DeepCopy(key, seen)] = DeepCopy(child, seen)
  end
  return copy
end

local function CopyTable(details, value)
  if type(details) == "table" and type(details.CopyTable) == "function" then
    local ok, copy = pcall(details.CopyTable, value)
    if ok and type(copy) == "table" then return copy end
  end
  return DeepCopy(value)
end

local function CharacterKey()
  local name = UnitName and UnitName("player")
  local realm = GetRealmName and GetRealmName()
  if name and realm and realm ~= "" then return name .. "-" .. realm end
  return name
end

local function GetDetails()
  return _G.Details or _G._detalhes
end

local function GetProfile(details)
  if type(details) ~= "table" or type(details.GetProfile) ~= "function" then return nil end
  local ok, profile = pcall(details.GetProfile, details, PROFILE_NAME, false)
  if ok and type(profile) == "table" then return profile end
  return nil
end

local function SetProfileSelectors(details)
  details.active_profile = PROFILE_NAME

  if type(_G._detalhes_database) == "table" then
    _G._detalhes_database.active_profile = PROFILE_NAME
  end

  if type(_G._detalhes_global) == "table" then
    _G._detalhes_global.__char_profiles = type(_G._detalhes_global.__char_profiles) == "table"
      and _G._detalhes_global.__char_profiles or {}
    local key = CharacterKey()
    if key then _G._detalhes_global.__char_profiles[key] = PROFILE_NAME end
  end
end

local function ForceDetailsWindowsOpen(details)
  if type(details) ~= "table" then return false, "Details is not loaded" end
  local profile = GetProfile(details)
  if not profile or type(profile.instances) ~= "table" or #profile.instances == 0 then
    return false, "RetreatUI Details profile has no saved windows"
  end

  SetProfileSelectors(details)

  -- Details has two sources of truth for whether a window survives reload:
  -- profile.instances[index].__was_opened and the per-character
  -- Details.local_instances_config[index].is_open. LoadLocalInstanceConfig()
  -- explicitly overwrites instance.ativa from is_open, so both must agree.
  details.local_instances_config = type(details.local_instances_config) == "table"
    and details.local_instances_config or {}

  for index, skin in ipairs(profile.instances) do
    skin.__was_opened = true

    local instance
    if type(details.GetInstance) == "function" then
      local ok, value = pcall(details.GetInstance, details, index)
      if ok and type(value) == "table" then instance = value end
    end

    if instance then
      if type(instance.IsEnabled) == "function" then
        local ok, enabled = pcall(instance.IsEnabled, instance)
        if ok and not enabled and type(details.AtivarInstancia) == "function" then
          pcall(details.AtivarInstancia, instance, nil, true)
        end
      end
      instance.ativa = true
    end

    local config = details.local_instances_config[index]
    if type(config) ~= "table" then config = {} end
    config.is_open = true

    if instance then
      if type(instance.GetDisplay) == "function" then
        local ok, attribute, subAttribute = pcall(instance.GetDisplay, instance)
        if ok then
          config.attribute = attribute or config.attribute or 1
          config.sub_attribute = subAttribute or config.sub_attribute or 1
        end
      end
      if type(instance.GetMode) == "function" then
        local ok, mode = pcall(instance.GetMode, instance)
        if ok then
          config.mode = mode or config.mode or 2
          config.modo = mode or config.modo or 2
        end
      end
      if type(instance.GetSegment) == "function" then
        local ok, segment = pcall(instance.GetSegment, instance)
        if ok then config.segment = segment or config.segment or 0 end
      end
      if type(instance.GetPosition) == "function" then
        local ok, position = pcall(instance.GetPosition, instance)
        if ok and type(position) == "table" then config.pos = CopyTable(details, position) end
      end
      if instance.snap then config.snap = CopyTable(details, instance.snap) end
      if instance.horizontalSnap ~= nil then config.horizontalSnap = instance.horizontalSnap end
      if instance.verticalSnap ~= nil then config.verticalSnap = instance.verticalSnap end
      if instance.isLocked ~= nil then config.isLocked = instance.isLocked end
    end

    details.local_instances_config[index] = config
  end

  -- SaveProfile regenerates profile.instances from the live windows. Call it
  -- after forcing the instances open, then reassert __was_opened because that is
  -- what SaveLocalInstanceConfig reads when profile_save_pos is enabled.
  if type(details.SaveProfile) == "function" then
    local ok, saved = pcall(details.SaveProfile, details, PROFILE_NAME)
    if not ok or saved == false then
      return false, "Details could not save the forced-open window state: " .. tostring(saved)
    end
    profile = GetProfile(details) or profile
    for _, skin in ipairs(profile.instances or {}) do skin.__was_opened = true end
  end

  -- SaveLocalInstanceConfig normally lives only in Details' runtime table until
  -- its logout saver runs. The installer calls ReloadUI immediately, so mirror
  -- the character-local table directly into SavedVariables as well.
  if type(_G._detalhes_database) == "table" then
    _G._detalhes_database.local_instances_config = CopyTable(details, details.local_instances_config)
    _G._detalhes_database.active_profile = PROFILE_NAME
  end

  SetProfileSelectors(details)

  if type(details.RefreshMainWindow) == "function" then
    pcall(details.RefreshMainWindow, details, -1, true)
  end

  return true, string.format("Details window state persisted for %d RetreatUI windows", #profile.instances)
end

local OriginalApplyDetails = Profiles.ApplyDetails
function Profiles:ApplyDetails()
  local ok, message = OriginalApplyDetails(self)
  if not ok then return ok, message end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.details = db.integrations.details or {}
  db.integrations.details.forceOpenOnNextLogin = true
  db.integrations.details.characterLocalWindows = true

  local persisted, persistMessage = ForceDetailsWindowsOpen(GetDetails())
  if not persisted then return false, persistMessage end
  return true, tostring(message or "RetreatUI Details profile imported") .. " — " .. persistMessage
end

local OriginalOnLogin = Profiles.OnLogin
function Profiles:OnLogin(...)
  if type(OriginalOnLogin) == "function" then pcall(OriginalOnLogin, self, ...) end

  local db = RUI:EnsureDB()
  local marker = db.integrations and db.integrations.details
  if type(marker) ~= "table" or marker.forceOpenOnNextLogin ~= true then return end

  local function RestoreAfterReload()
    local details = GetDetails()
    if type(details) ~= "table" then return end

    SetProfileSelectors(details)
    if type(details.ApplyProfile) == "function" then
      -- bNoSave=true prevents the pre-reload/default live state from replacing
      -- the imported RetreatUI profile before it is applied.
      pcall(details.ApplyProfile, details, PROFILE_NAME, true)
    end

    local restored = ForceDetailsWindowsOpen(details)
    if restored then
      marker.forceOpenOnNextLogin = false
      marker.restoredAfterReload = true
      marker.version = RUI.version
    end
  end

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0.75, RestoreAfterReload)
  else
    RestoreAfterReload()
  end
end
