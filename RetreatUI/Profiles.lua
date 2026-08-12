local RUI = RetreatUITBC
if not RUI then return end

local Profiles = {}
RUI:RegisterModule("profiles", Profiles)

local PROFILE_NAME = "RetreatUI"

local function Record(key, resolution)
  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations[key] = {
    installed = true,
    profile = PROFILE_NAME,
    resolution = resolution,
    version = RUI.version,
  }
end

local function ProfileKey(base, resolution)
  return base .. ((resolution == "1080p") and "1080p" or "")
end

function Profiles:ApplyElvUI(resolution)
  if not ElvUI or type(unpack) ~= "function" then return false, "ElvUI is not loaded" end
  local E = unpack(ElvUI)
  if not E or type(E.GetModule) ~= "function" then return false, "ElvUI API is unavailable" end

  local key = ProfileKey("elvui", resolution)
  local profile = RUI.referenceProfiles and RUI.referenceProfiles[key]
  if type(profile) ~= "table" or type(profile[1]) ~= "string" then
    return false, "ElvUI profile payload is missing"
  end

  local DI = E:GetModule("Distributor")
  if not DI or type(DI.Decode) ~= "function" or type(DI.SetImportedProfile) ~= "function" then
    return false, "ElvUI Distributor API is unavailable"
  end

  local ok, profileType, _, data = pcall(DI.Decode, DI, profile[1])
  if not ok or not profileType or type(data) ~= "table" then
    return false, "ElvUI rejected the profile payload"
  end

  local imported, err = pcall(DI.SetImportedProfile, DI, profileType, PROFILE_NAME, data, true)
  if not imported then return false, "ElvUI import failed: " .. tostring(err) end

  if type(E.SetupCVars) == "function" then pcall(E.SetupCVars, E, true) end
  if E.data and E.data.global and E.data.global.general then
    E.data.global.general.mapAlphaWhenMoving = 0.4
    E.data.global.general.UIScale = profile[2]
    E.data.global.general.WorldMapCoordinates = E.data.global.general.WorldMapCoordinates or {}
    E.data.global.general.WorldMapCoordinates.position = "BOTTOM"
  end

  if E.private and E.private.general then
    E.private.general.chatBubbleFont = "Naowh"
    E.private.general.chatBubbleFontOutline = "OUTLINE"
    E.private.general.chatBubbleFontSize = 10
    E.private.general.chatBubbles = "backdrop_noborder"
    E.private.general.dmgfont = "GothamNarrowUltra"
    E.private.general.glossTex = "NaowhLeft"
    E.private.general.minimap = E.private.general.minimap or {}
    E.private.general.minimap.hideTracking = true
    E.private.general.namefont = "Naowh"
    E.private.general.normTex = "NaowhLeft"
  end
  if E.private and E.private.nameplates then E.private.nameplates.enable = false end

  Record("elvui", resolution or "1440p")
  return true, "ElvUI profile imported"
end

local function RefreshPlaterAfterImport()
  if not Plater then return end
  if type(Plater.ImportScriptsFromLibrary) == "function" then Plater.ImportScriptsFromLibrary() end
  if type(Plater.ApplyPatches) == "function" then Plater.ApplyPatches() end
  if type(Plater.CompileAllScripts) == "function" then
    Plater.CompileAllScripts("script")
    Plater.CompileAllScripts("hook")
  end

  if Plater.db and Plater.db.profile and (not Plater.db.profile.use_ui_parent or Plater.db.profile.ui_parent_scale_tune == 0) then
    Plater.db.profile.use_ui_parent = true
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    Plater.db.profile.ui_parent_scale_tune = 1 / scale
    if type(Plater.RefreshDBUpvalues) == "function" then Plater.RefreshDBUpvalues() end
    if type(Plater.UpdateAllPlates) == "function" then Plater.UpdateAllPlates() end
  end

  if type(Plater.RefreshConfig) == "function" then Plater:RefreshConfig() end
  if type(Plater.UpdatePlateClickSpace) == "function" then Plater.UpdatePlateClickSpace() end
end

local function EnsurePlaterHooks()
  if RUI._platerReferenceHooks then return end
  if type(hooksecurefunc) == "function" and Plater and type(Plater.OnProfileCreated) == "function" then
    hooksecurefunc(Plater, "OnProfileCreated", function()
      if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.5, RefreshPlaterAfterImport) end
    end)
  end
  if type(hooksecurefunc) == "function" and Plater and type(Plater.RefreshConfigProfileChanged) == "function" then
    hooksecurefunc(Plater, "RefreshConfigProfileChanged", function()
      if type(Plater.RefreshConfig) == "function" then Plater:RefreshConfig() end
    end)
  end
  RUI._platerReferenceHooks = true
end

function Profiles:ApplyPlater(resolution)
  if not Plater or not PlaterAPI or type(PlaterAPI.ImportProfile) ~= "function" then
    return false, "Plater is not loaded"
  end
  local key = ProfileKey("plater", resolution)
  local profile = RUI.referenceProfiles and RUI.referenceProfiles[key]
  if type(profile) ~= "string" or profile == "" then return false, "Plater profile payload is missing" end

  EnsurePlaterHooks()
  local ok, err = pcall(PlaterAPI.ImportProfile, profile, PROFILE_NAME)
  if not ok then return false, "Plater import failed: " .. tostring(err) end

  Record("plater", resolution or "1440p")
  return true, "Plater profile imported"
end

function Profiles:ApplyDetails()
  if not DetailsAPI or type(DetailsAPI.ImportProfile) ~= "function" then return false, "Details is not loaded" end
  local profile = RUI.referenceProfiles and RUI.referenceProfiles.details
  if type(profile) ~= "string" or profile == "" then return false, "Details profile payload is missing" end

  local ok, err = pcall(DetailsAPI.ImportProfile, profile, PROFILE_NAME)
  if not ok then return false, "Details import failed: " .. tostring(err) end

  Record("details")
  return true, "Details profile imported"
end

function Profiles:ApplyBigWigs(resolution)
  if not BigWigsAPI or type(BigWigsAPI.RegisterProfile) ~= "function" then return false, "BigWigs is not loaded" end
  local key = ProfileKey("bigwigs", resolution)
  local profile = RUI.referenceProfiles and RUI.referenceProfiles[key]
  if type(profile) ~= "table" or type(profile[1]) ~= "string" then return false, "BigWigs profile payload is missing" end

  local callbackFinished = false
  local callbackSuccess = false
  local ok, err = pcall(BigWigsAPI.RegisterProfile, "RetreatUI", profile[1], PROFILE_NAME, function(success)
    callbackFinished = true
    callbackSuccess = success == true
    if callbackSuccess then Record("bigwigs", resolution or "1440p") end
  end)
  if not ok then return false, "BigWigs import failed: " .. tostring(err) end
  if callbackFinished and not callbackSuccess then return false, "BigWigs rejected the profile" end
  return true, "BigWigs profile import started"
end

return Profiles
