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
  if type(details) ~= "table" then return end
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

local function EnsureLocalConfig(details, index, skin, instance)
  details.local_instances_config = type(details.local_instances_config) == "table"
    and details.local_instances_config or {}

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

  if not config.pos and type(skin) == "table" and type(skin.__pos) == "table" then
    config.pos = CopyTable(details, skin.__pos)
  end
  if config.attribute == nil then config.attribute = 1 end
  if config.sub_attribute == nil then config.sub_attribute = 1 end
  if config.mode == nil then config.mode = 2 end
  if config.modo == nil then config.modo = config.mode end
  if config.segment == nil then config.segment = 0 end
  if config.snap == nil then config.snap = {} end
  if config.isLocked == nil then config.isLocked = false end

  details.local_instances_config[index] = config
  return config
end

local function GetOrCreateInstance(details, index, skin)
  local instance
  if type(details.GetInstance) == "function" then
    local ok, value = pcall(details.GetInstance, details, index)
    if ok and type(value) == "table" then instance = value end
  end
  if not instance and type(details.CreateDisabledInstance) == "function" then
    local ok, value = pcall(details.CreateDisabledInstance, details, index, skin)
    if ok and type(value) == "table" then instance = value end
  end
  return instance
end

local function ActivateInstance(details, instance)
  if type(instance) ~= "table" then return false end
  instance.ativa = true

  local enabled = true
  if type(instance.IsEnabled) == "function" then
    local ok, value = pcall(instance.IsEnabled, instance)
    enabled = ok and (value == true or value == 1)
  end

  if not enabled then instance.ativa = true end

  local needsFrame = not instance.baseframe
  local started = false
  if type(instance.IsStarted) == "function" then
    local ok, value = pcall(instance.IsStarted, instance)
    started = ok and (value == true or value == 1)
  end

  if needsFrame or not started then
    if type(instance.AtivarInstancia) == "function" then
      pcall(instance.AtivarInstancia, instance, nil, true)
    elseif type(details.AtivarInstancia) == "function" then
      pcall(details.AtivarInstancia, instance, nil, true)
    end
  end

  instance.ativa = true
  if instance.baseframe and type(instance.baseframe.Show) == "function" then pcall(instance.baseframe.Show, instance.baseframe) end
  if type(instance.RestoreMainWindowPosition) == "function" then pcall(instance.RestoreMainWindowPosition, instance) end
  if type(instance.ReajustaGump) == "function" then pcall(instance.ReajustaGump, instance) end
  if type(instance.ChangeSkin) == "function" then pcall(instance.ChangeSkin, instance) end
  return true
end

local function MirrorSavedVariables(details)
  if type(_G._detalhes_database) == "table" then
    _G._detalhes_database.local_instances_config = CopyTable(details, details.local_instances_config or {})
    _G._detalhes_database.active_profile = PROFILE_NAME
  end
  SetProfileSelectors(details)
end

local function ForceDetailsWindowsOpen(details, saveProfile)
  if type(details) ~= "table" then return false, "Details is not loaded" end
  local profile = GetProfile(details)
  if not profile or type(profile.instances) ~= "table" or #profile.instances == 0 then
    return false, "RetreatUI Details profile has no saved windows"
  end

  SetProfileSelectors(details)

  local opened = 0
  for index, skin in ipairs(profile.instances) do
    skin.__was_opened = true
    local instance = GetOrCreateInstance(details, index, skin)
    EnsureLocalConfig(details, index, skin, instance)
    if instance and ActivateInstance(details, instance) then opened = opened + 1 end
    EnsureLocalConfig(details, index, skin, instance)
  end

  details.opened_windows = math.max(tonumber(details.opened_windows) or 0, opened)

  if saveProfile and type(details.SaveProfile) == "function" then
    -- All live instances have already been marked enabled. SaveProfile can now
    -- export __was_opened=true and SaveLocalInstanceConfig can only write true.
    local ok, saved = pcall(details.SaveProfile, details, PROFILE_NAME)
    if not ok or saved == false then
      return false, "Details could not save the open RetreatUI windows: " .. tostring(saved)
    end
    profile = GetProfile(details) or profile
    for index, skin in ipairs(profile.instances or {}) do
      skin.__was_opened = true
      local instance = GetOrCreateInstance(details, index, skin)
      EnsureLocalConfig(details, index, skin, instance)
    end
  end

  MirrorSavedVariables(details)

  if type(details.RefreshMainWindow) == "function" then pcall(details.RefreshMainWindow, details, -1, true) end
  return opened > 0, string.format("Details window state synchronized for %d RetreatUI windows", opened)
end

function Profiles:PrepareDetailsForReload()
  local details = GetDetails()
  local db = RUI:EnsureDB()
  local marker = db.integrations and db.integrations.details
  if type(marker) ~= "table" or marker.installed ~= true then return true end

  marker.forceOpenOnNextLogin = true
  marker.preparedForReload = false
  local ok, message = ForceDetailsWindowsOpen(details, true)
  if ok then marker.preparedForReload = true end
  return ok, message
end

local OriginalApplyDetails = Profiles.ApplyDetails
function Profiles:ApplyDetails()
  local ok, message = OriginalApplyDetails(self)
  if not ok then return ok, message end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.details = db.integrations.details or {}
  local marker = db.integrations.details
  marker.forceOpenOnNextLogin = true
  marker.characterLocalWindows = true
  marker.noLoginReapply = true

  local persisted, persistMessage = ForceDetailsWindowsOpen(GetDetails(), true)
  if not persisted then return false, persistMessage end
  return true, tostring(message or "RetreatUI Details profile imported") .. " — " .. persistMessage
end

-- beta.9 called Details:ApplyProfile() again after PLAYER_LOGIN. Details itself
-- begins ApplyProfile() by saving local window state, then loads that local state
-- twice while applying the profile. If startup had not restored the windows yet,
-- that call could persist is_open=false and immediately close the imported
-- windows again. beta.10 deliberately never reapplies the profile on login.
function Profiles:OnLogin()
  local db = RUI:EnsureDB()
  local marker = db.integrations and db.integrations.details
  if type(marker) ~= "table" or marker.forceOpenOnNextLogin ~= true then return end

  local function Repair(finalPass)
    local details = GetDetails()
    if type(details) ~= "table" then return end
    SetProfileSelectors(details)
    local restored = ForceDetailsWindowsOpen(details, finalPass == true)
    if finalPass and restored then
      marker.forceOpenOnNextLogin = false
      marker.restoredAfterReload = true
      marker.preparedForReload = nil
      marker.version = RUI.version
    end
  end

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0.35, function() Repair(false) end)
    C_Timer.After(1.10, function() Repair(false) end)
    C_Timer.After(2.25, function() Repair(true) end)
  else
    Repair(true)
  end
end

-- Make every ReloadUI while a freshly imported Details profile is pending go
-- through one final synchronous save. This also covers the installer's Reload
-- button without depending on Details' PLAYER_LOGOUT handler ordering.
if not RUI._detailsReloadWrapped and type(ReloadUI) == "function" then
  RUI._detailsReloadWrapped = true
  local OriginalReloadUI = ReloadUI
  ReloadUI = function(...)
    local db = RUI:EnsureDB()
    local marker = db.integrations and db.integrations.details
    if type(marker) == "table" and marker.forceOpenOnNextLogin == true then
      pcall(Profiles.PrepareDetailsForReload, Profiles)
    end
    return OriginalReloadUI(...)
  end
end
