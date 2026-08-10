local RUI = RetreatUITBC
if not RUI then return end

local Profiles = RUI.modules and RUI.modules.profiles
if not Profiles then return end

local PROFILE_NAME = "RetreatUI"

-- Details is intentionally simple here. The supplied profile is already the
-- source of truth, so RetreatUI must not reapply it, resave it, force windows
-- open, rewrite character mappings, or mutate Details SavedVariables after the
-- import. Let Details own everything after its normal ImportProfile call.
function Profiles:ApplyDetails()
  local details = _G.Details or _G._detalhes
  if type(details) ~= "table" then return false, "Details is not loaded" end

  local payload = RUI.profilePayloads and RUI.profilePayloads.details
  if type(payload) ~= "string" or payload == "" then
    return false, "RetreatUI Details profile payload is missing"
  end
  if type(details.ImportProfile) ~= "function" then
    return false, "This Details build does not expose ImportProfile"
  end

  -- Details Classic signature:
  -- profileString, newProfileName, importAutoRunCode, fromImportPrompt,
  -- overwriteExisting.
  local ok, imported, importError = pcall(
    details.ImportProfile,
    details,
    payload,
    PROFILE_NAME,
    false,
    false,
    true
  )

  if not ok then return false, "Details import error: " .. tostring(imported) end
  if imported == false then
    return false, tostring(importError or "Details rejected the RetreatUI profile")
  end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.details = {
    profile = PROFILE_NAME,
    installed = true,
    imported = true,
    importOnly = true,
    version = RUI.version,
  }

  return true, "RetreatUI Details profile imported"
end

-- beta.8-beta.10 carried a post-login Details persistence workaround. Do not
-- run any of it anymore. ImportProfile is the entire Details integration.
Profiles.OnLogin = nil
