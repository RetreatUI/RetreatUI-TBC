local RUI = RetreatUITBC
if not RUI then return end

local frame
local TOTAL_PAGES = 7

local function SetBackdrop(widget, color, border)
  widget:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  widget:SetBackdropColor(unpack(color))
  widget:SetBackdropBorderColor(unpack(border))
end

local function Font(parent, text, size)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetFont(STANDARD_TEXT_FONT, size or 12, "OUTLINE")
  fs:SetText(text or "")
  return fs
end

local function Button(parent, text, width, callback)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width or 130, 30)
  SetBackdrop(button, { 0.035, 0.045, 0.055, 0.98 }, { 0.58, 0.36, 0.08, 1 })
  button.label = Font(button, text, 11)
  button.label:SetPoint("CENTER")
  button:SetScript("OnClick", callback)
  button:SetScript("OnEnter", function(self)
    if self:IsEnabled() then self:SetBackdropBorderColor(0.95, 0.58, 0.12, 1) end
  end)
  button:SetScript("OnLeave", function(self)
    if self:IsEnabled() then self:SetBackdropBorderColor(0.58, 0.36, 0.08, 1) end
  end)
  return button
end

local function SetButtonEnabled(button, enabled)
  if enabled then
    button:Enable()
    button:SetAlpha(1)
    button.label:SetTextColor(1, 1, 1)
  else
    button:Disable()
    button:SetAlpha(0.45)
    button.label:SetTextColor(0.55, 0.58, 0.62)
  end
end

local function PageResult(pageId, text, success)
  if not frame then return end
  frame.pageResults = frame.pageResults or {}
  frame.pageResults[pageId] = { text = text, success = success }
end

local function MacroReady()
  local module = RUI.modules.macros
  if module and type(module.IsReady) == "function" then
    local ok, ready, message = pcall(module.IsReady, module)
    if ok and ready then return true, message or "READY" end
    if ok then return false, message or "MACRO PACKAGE NOT READY" end
  end
  if module and type(module.Import) == "function" then return true, "READY" end
  return false, "MACRO PACKAGE NOT EMBEDDED YET"
end

local function ImportMacros()
  local module = RUI.modules.macros
  if not module or type(module.Import) ~= "function" then
    return false, "Macro package is not embedded in this beta yet."
  end
  return module:Import()
end

local function ElvUIReady()
  if not RUI:IsAddonLoaded("ElvUI") then return false, "ELVUI NOT LOADED" end
  local profiles = RUI.modules.profiles
  if not profiles or type(profiles.ApplyElvUI) ~= "function" then return false, "ELVUI PROFILE MODULE MISSING" end
  if type(RUI.ElvUIProfile) ~= "table" then return false, "ELVUI PROFILE NOT EMBEDDED" end
  return true, "READY"
end

local function ImportElvUI()
  local profiles = RUI.modules.profiles
  if not profiles or type(profiles.ApplyElvUI) ~= "function" then return false, "ElvUI profile module is missing." end
  return profiles:ApplyElvUI()
end

local function WeakAurasReady()
  if not RUI:IsAddonLoaded("WeakAuras") then return false, "WEAKAURAS NOT LOADED" end
  if RUI:GetPlayerClass() ~= "DRUID" then return false, "DRUID PACKAGE ONLY" end
  local wa = RUI.modules.weakauras
  local ready = wa and wa.IsAvailable and wa:IsAvailable() and wa.IsClassSupported and wa:IsClassSupported()
  return ready == true, ready and "READY — INSTALL + VERIFY" or "WEAKAURAS PACKAGE NOT READY"
end

local function ImportWeakAuras()
  local wa = RUI.modules.weakauras
  if not wa or type(wa.InstallDruidHUD) ~= "function" then return false, "WeakAuras package module is missing." end
  return wa:InstallDruidHUD()
end

local function DetailsReady()
  if not RUI:IsAddonLoaded("Details") and not _G.Details and not _G._detalhes then
    return false, "DETAILS NOT LOADED"
  end
  local profiles = RUI.modules.profiles
  if not profiles or type(profiles.ApplyDetails) ~= "function" then return false, "DETAILS PROFILE MODULE MISSING" end
  return true, "READY"
end

local function ImportDetails()
  local profiles = RUI.modules.profiles
  if not profiles or type(profiles.ApplyDetails) ~= "function" then return false, "Details profile module is missing." end
  return profiles:ApplyDetails()
end

local function DBMReady()
  if not _G.DBM and not RUI:IsAddonLoaded("DBM-Core") then return false, "DBM NOT LOADED" end
  local module = RUI.modules.dbm
  if module and type(module.IsReady) == "function" then
    local ok, ready, message = pcall(module.IsReady, module)
    if ok and ready then return true, message or "READY" end
    if ok then return false, message or "DBM PROFILE NOT READY" end
  end
  if module and type(module.Apply) == "function" then return true, "READY" end
  return false, "DBM PROFILE NOT EMBEDDED YET"
end

local function ImportDBM()
  local module = RUI.modules.dbm
  if not module or type(module.Apply) ~= "function" then
    return false, "DBM profile is not embedded in this beta yet."
  end
  return module:Apply()
end

local PAGES = {
  {
    id = "welcome",
    title = "WELCOME",
    subtitle = "Welcome to RetreatUI for The Burning Crusade.",
    description = "This installer will guide you through each part of the setup one page at a time. You can import the components you use and skip anything that is not available on this client.",
  },
  {
    id = "macros",
    title = "IMPORT MACROS",
    subtitle = "Install the RetreatUI macro package.",
    description = "This page imports the class and utility macros included with RetreatUI. Existing macros should only be changed by the macro package itself.",
    button = "IMPORT MACROS",
    ready = MacroReady,
    action = ImportMacros,
  },
  {
    id = "elvui",
    title = "IMPORT ELVUI",
    subtitle = "Install the RetreatUI ElvUI layout.",
    description = "Creates and activates the RetreatUI ElvUI profile, including the player and target frame layout used by the central WeakAuras HUD.",
    button = "IMPORT ELVUI",
    ready = ElvUIReady,
    action = ImportElvUI,
  },
  {
    id = "weakauras",
    title = "IMPORT WEAKAURAS",
    subtitle = "Install and verify the RetreatUI class HUD.",
    description = "Creates the RetreatUI Druid WeakAuras package and verifies the full hierarchy and HUD positions after installation.",
    button = "IMPORT WEAKAURAS",
    ready = WeakAurasReady,
    action = ImportWeakAuras,
  },
  {
    id = "details",
    title = "IMPORT DETAILS",
    subtitle = "Install the RetreatUI Details profile.",
    description = "Applies the RetreatUI Details appearance and typography so the meter matches the rest of the UI.",
    button = "IMPORT DETAILS",
    ready = DetailsReady,
    action = ImportDetails,
  },
  {
    id = "dbm",
    title = "IMPORT DBM",
    subtitle = "Install the RetreatUI DBM profile.",
    description = "Applies the RetreatUI DBM profile when the DBM package is available and loaded.",
    button = "IMPORT DBM",
    ready = DBMReady,
    action = ImportDBM,
  },
  {
    id = "reload",
    title = "RELOAD",
    subtitle = "RetreatUI setup is ready to finish.",
    description = "Reload the UI to apply all imported profiles and refresh WeakAuras. You can reopen this installer at any time with /ruitbc.",
    button = "RELOAD UI",
    reload = true,
  },
}

local function SetStatus(text, success)
  if not frame or not frame.status then return end
  frame.status:SetText(text or "")
  if success == true then
    frame.status:SetTextColor(0.35, 0.9, 0.45)
  elseif success == false then
    frame.status:SetTextColor(0.95, 0.35, 0.2)
  else
    frame.status:SetTextColor(0.68, 0.73, 0.79)
  end
end

local function RefreshPage()
  if not frame then return end
  local index = math.max(1, math.min(TOTAL_PAGES, frame.currentPage or 1))
  frame.currentPage = index
  local page = PAGES[index]

  frame.progress:SetText(string.format("STEP %d OF %d", index, TOTAL_PAGES))
  frame.pageTitle:SetText(page.title)
  frame.pageSubtitle:SetText(page.subtitle)
  frame.description:SetText(page.description)

  frame.back:SetShown(index > 1)
  frame.next:SetShown(index < TOTAL_PAGES)
  frame.next.label:SetText(index == 1 and "GET STARTED" or "NEXT")

  if page.button then
    frame.action:Show()
    frame.action.label:SetText(page.button)
  else
    frame.action:Hide()
  end

  local saved = frame.pageResults and frame.pageResults[page.id]
  if saved then
    SetStatus(saved.text, saved.success)
    SetButtonEnabled(frame.action, true)
    if page.ready then
      local ready = page.ready()
      SetButtonEnabled(frame.action, ready == true)
    end
  elseif page.reload then
    SetStatus("Ready to reload.", true)
    SetButtonEnabled(frame.action, true)
  elseif page.ready then
    local ready, message = page.ready()
    SetStatus(message or (ready and "READY" or "NOT AVAILABLE"), ready and nil or false)
    SetButtonEnabled(frame.action, ready == true)
  else
    SetStatus("Follow the steps to build your RetreatUI setup.", nil)
  end
end

local function RunCurrentAction()
  if not frame then return end
  local page = PAGES[frame.currentPage or 1]
  if not page then return end

  if page.reload then
    local db = RUI:EnsureDB()
    db.installerCompleted = true
    ReloadUI()
    return
  end

  if not page.action then return end
  if InCombatLockdown and InCombatLockdown() then
    PageResult(page.id, "Leave combat before importing this component.", false)
    RefreshPage()
    return
  end

  local ready, readyMessage = true, nil
  if page.ready then ready, readyMessage = page.ready() end
  if not ready then
    PageResult(page.id, readyMessage or "This component is not available.", false)
    RefreshPage()
    return
  end

  local ok, success, message = pcall(page.action)
  if not ok then
    PageResult(page.id, tostring(success), false)
  elseif success then
    PageResult(page.id, message or "Imported successfully.", true)
  else
    PageResult(page.id, message or "Import failed.", false)
  end
  RefreshPage()
end

local function BuildInstaller()
  if frame then return frame end

  frame = CreateFrame("Frame", "RetreatUITBCInstaller", UIParent, "BackdropTemplate")
  frame:SetSize(760, 470)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  SetBackdrop(frame, { 0.018, 0.025, 0.032, 0.985 }, { 0.55, 0.34, 0.08, 1 })

  frame.brand = Font(frame, "RETREATUI — THE BURNING CRUSADE", 18)
  frame.brand:SetPoint("TOPLEFT", 28, -26)
  frame.brand:SetTextColor(0.95, 0.58, 0.12)

  frame.progress = Font(frame, "STEP 1 OF 7", 10)
  frame.progress:SetPoint("TOPRIGHT", -52, -30)
  frame.progress:SetTextColor(0.58, 0.62, 0.68)

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(0.16, 0.18, 0.21, 1)
  divider:SetPoint("TOPLEFT", 28, -62)
  divider:SetPoint("TOPRIGHT", -28, -62)
  divider:SetHeight(1)

  frame.pageTitle = Font(frame, "", 24)
  frame.pageTitle:SetPoint("TOPLEFT", 42, -105)
  frame.pageTitle:SetTextColor(1, 1, 1)

  frame.pageSubtitle = Font(frame, "", 12)
  frame.pageSubtitle:SetPoint("TOPLEFT", frame.pageTitle, "BOTTOMLEFT", 0, -12)
  frame.pageSubtitle:SetTextColor(0.95, 0.58, 0.12)

  frame.description = Font(frame, "", 11)
  frame.description:SetPoint("TOPLEFT", frame.pageSubtitle, "BOTTOMLEFT", 0, -24)
  frame.description:SetWidth(660)
  frame.description:SetJustifyH("LEFT")
  frame.description:SetJustifyV("TOP")
  frame.description:SetWordWrap(true)
  frame.description:SetTextColor(0.72, 0.76, 0.82)

  local statusPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  statusPanel:SetSize(660, 62)
  statusPanel:SetPoint("CENTER", 0, -28)
  SetBackdrop(statusPanel, { 0.025, 0.033, 0.041, 0.94 }, { 0.12, 0.15, 0.18, 1 })

  local statusLabel = Font(statusPanel, "STATUS", 9)
  statusLabel:SetPoint("TOPLEFT", 14, -11)
  statusLabel:SetTextColor(0.48, 0.52, 0.58)

  frame.status = Font(statusPanel, "", 10)
  frame.status:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", 0, -8)
  frame.status:SetPoint("RIGHT", statusPanel, "RIGHT", -14, 0)
  frame.status:SetJustifyH("LEFT")
  frame.status:SetWordWrap(true)

  frame.action = Button(frame, "IMPORT", 190, RunCurrentAction)
  frame.action:SetPoint("CENTER", 0, -108)

  frame.back = Button(frame, "BACK", 100, function()
    frame.currentPage = math.max(1, (frame.currentPage or 1) - 1)
    RefreshPage()
  end)
  frame.back:SetPoint("BOTTOMLEFT", 28, 22)

  frame.next = Button(frame, "NEXT", 120, function()
    frame.currentPage = math.min(TOTAL_PAGES, (frame.currentPage or 1) + 1)
    RefreshPage()
  end)
  frame.next:SetPoint("BOTTOMRIGHT", -28, 22)

  frame.close = Button(frame, "X", 32, function() frame:Hide() end)
  frame.close:SetPoint("TOPRIGHT", -10, -10)

  frame.currentPage = 1
  frame.pageResults = {}
  RefreshPage()
  return frame
end

function RUI:OpenInstaller()
  local installer = BuildInstaller()
  installer.currentPage = 1
  installer.pageResults = installer.pageResults or {}
  RefreshPage()
  installer:Show()
end
