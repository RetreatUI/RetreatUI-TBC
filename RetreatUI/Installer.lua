local RUI = RetreatUITBC
if not RUI then return end

local frame
local TOTAL_PAGES = 8

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
  SetBackdrop(button, {0.035,0.045,0.055,0.98}, {0.58,0.36,0.08,1})
  button.label = Font(button, text, 11)
  button.label:SetPoint("CENTER")
  button:SetScript("OnClick", callback)
  button:SetScript("OnEnter", function(self)
    if self:IsEnabled() then self:SetBackdropBorderColor(0.95,0.58,0.12,1) end
  end)
  button:SetScript("OnLeave", function(self)
    if self:IsEnabled() then self:SetBackdropBorderColor(0.58,0.36,0.08,1) end
  end)
  return button
end

local function SetButtonEnabled(button, enabled)
  if enabled then
    button:Enable()
    button:SetAlpha(1)
    button.label:SetTextColor(1,1,1)
  else
    button:Disable()
    button:SetAlpha(0.45)
    button.label:SetTextColor(0.55,0.58,0.62)
  end
end

local function IsLoaded(name)
  if type(RUI.IsAddonLoaded) == "function" and RUI:IsAddonLoaded(name) then return true end
  if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then return C_AddOns.IsAddOnLoaded(name) end
  if type(IsAddOnLoaded) == "function" then return IsAddOnLoaded(name) end
  return false
end

local function Profiles()
  return RUI.modules and RUI.modules.profiles
end

local function WeakAurasModule()
  return RUI.modules and RUI.modules.weakauras
end

local function PlayerClass()
  local localized, token = UnitClass("player")
  return localized or token or "Class", token
end

local function HasElvUI(res)
  local profiles = RUI.profilePayloads and RUI.profilePayloads.elvui
  local entry = profiles and profiles[res]
  return type(entry) == "table" and type(entry.export) == "string" and entry.export ~= ""
end

local function HasBigWigs(res)
  local profiles = RUI.profilePayloads and RUI.profilePayloads.bigwigs
  return profiles and type(profiles[res]) == "string" and profiles[res] ~= ""
end

local function HasDetails()
  return RUI.profilePayloads and type(RUI.profilePayloads.details) == "string" and RUI.profilePayloads.details ~= ""
end

local function HasPlater(res)
  if not RUI.profilePayloads then return false end
  if res == "1080p" then
    return type(RUI.profilePayloads.plater1080p) == "string" and RUI.profilePayloads.plater1080p ~= ""
  end
  return type(RUI.profilePayloads.plater) == "string" and RUI.profilePayloads.plater ~= ""
end

local function ElvUIReady(res)
  local p = Profiles()
  return IsLoaded("ElvUI") and p and type(p.ApplyElvUI) == "function" and HasElvUI(res)
end

local function BigWigsReady(res)
  local p = Profiles()
  return (IsLoaded("BigWigs") or _G.BigWigsAPI ~= nil) and p and type(p.ApplyBigWigs) == "function" and HasBigWigs(res)
end

local function DetailsReady()
  local p = Profiles()
  return (IsLoaded("Details") or _G.DetailsAPI ~= nil) and p and type(p.ApplyDetails) == "function" and HasDetails()
end

local function PlaterReady(res)
  local p = Profiles()
  return (IsLoaded("Plater") or _G.PlaterAPI ~= nil) and p and type(p.ApplyPlater) == "function" and HasPlater(res)
end

local function GeneralWAReady()
  local wa = WeakAurasModule()
  return IsLoaded("WeakAuras") and wa and type(wa.OpenGeneralImport) == "function" and wa:IsGeneralSupported()
end

local function ClassWAReady()
  local wa = WeakAurasModule()
  return IsLoaded("WeakAuras") and wa and type(wa.OpenClassImport) == "function" and wa:IsClassSupported()
end

local PAGES = {
  {
    id = "welcome",
    title = "WELCOME TO RETREATUI",
    description = "To start the installation process, click Continue.",
  },
  {
    id = "elvui",
    title = "ELVUI",
    description = "Click the button representing your resolution to setup ElvUI.",
    label1 = "1440p", label2 = "1080p",
    ready1 = function() return ElvUIReady("1440p") end,
    ready2 = function() return ElvUIReady("1080p") end,
    action1 = function() return Profiles():ApplyElvUI("1440p") end,
    action2 = function() return Profiles():ApplyElvUI("1080p") end,
  },
  {
    id = "bigwigs",
    title = "BIGWIGS",
    description = "Click the button representing your resolution to setup BigWigs.",
    label1 = "1440p", label2 = "1080p",
    ready1 = function() return BigWigsReady("1440p") end,
    ready2 = function() return BigWigsReady("1080p") end,
    action1 = function() return Profiles():ApplyBigWigs("1440p") end,
    action2 = function() return Profiles():ApplyBigWigs("1080p") end,
  },
  {
    id = "details",
    title = "DETAILS",
    description = "Click the button below to setup Details.",
    label1 = "SETUP DETAILS",
    ready1 = DetailsReady,
    action1 = function() return Profiles():ApplyDetails() end,
  },
  {
    id = "plater",
    title = "PLATER",
    description = "Click the button representing your resolution to setup Plater.",
    label1 = "1440p", label2 = "1080p",
    ready1 = function() return PlaterReady("1440p") end,
    ready2 = function() return PlaterReady("1080p") end,
    action1 = function() return Profiles():ApplyPlater("1440p") end,
    action2 = function() return Profiles():ApplyPlater("1080p") end,
  },
  {
    id = "generalwa",
    title = "GENERAL WEAKAURAS",
    description = "Click the button below to import the General WeakAuras.",
    label1 = "CORE",
    ready1 = GeneralWAReady,
    action1 = function()
      if frame then frame:SetFrameStrata("HIGH") end
      return WeakAurasModule():OpenGeneralImport()
    end,
  },
  {
    id = "classwa",
    title = "CLASS WEAKAURA",
    description = function()
      local localized = PlayerClass()
      return "Click the button below to import your Class WeakAura.\n\nYour class: " .. tostring(localized)
    end,
    label1 = "IMPORT CLASS WA",
    ready1 = ClassWAReady,
    action1 = function()
      if frame then frame:SetFrameStrata("HIGH") end
      return WeakAurasModule():OpenClassImport()
    end,
  },
  {
    id = "complete",
    title = "INSTALLATION COMPLETE",
    description = "You have completed the installation process. Click Reload to save your settings and reload your UI.",
    label1 = "RELOAD",
    reload = true,
  },
}

local function Resolve(value)
  return type(value) == "function" and value() or (value or "")
end

local function SetStatus(text, success)
  if not frame then return end
  frame.status:SetText(text or "")
  if success == true then frame.status:SetTextColor(0.35,0.9,0.45)
  elseif success == false then frame.status:SetTextColor(0.95,0.35,0.2)
  else frame.status:SetTextColor(0.68,0.73,0.79) end
end

local function ReadyFor(page, slot)
  local fn = slot == 2 and page.ready2 or page.ready1
  if type(fn) ~= "function" then return slot == 1 and (page.reload == true or page.action1 == nil) end
  local ok, value = pcall(fn)
  return ok and value == true
end

local function RefreshPage()
  if not frame then return end
  local index = math.max(1, math.min(TOTAL_PAGES, frame.currentPage or 1))
  frame.currentPage = index
  local page = PAGES[index]

  frame.progress:SetText(string.format("STEP %d OF %d", index, TOTAL_PAGES))
  frame.pageTitle:SetText(Resolve(page.title))
  frame.description:SetText(Resolve(page.description))

  if index > 1 then frame.back:Show() else frame.back:Hide() end
  if index < TOTAL_PAGES then frame.next:Show() else frame.next:Hide() end
  frame.next.label:SetText(index == 1 and "CONTINUE" or "NEXT")

  frame.option1:Hide()
  frame.option2:Hide()

  local ready1, ready2 = true, true
  if page.action1 or page.reload then
    ready1 = page.reload or ReadyFor(page, 1)
    frame.option1:Show()
    frame.option1.label:SetText(page.label1 or "SETUP")
    SetButtonEnabled(frame.option1, ready1)
  end
  if page.action2 then
    ready2 = ReadyFor(page, 2)
    frame.option2:Show()
    frame.option2.label:SetText(page.label2 or "1080p")
    SetButtonEnabled(frame.option2, ready2)
  end

  if page.reload then
    SetStatus("Ready to reload.", true)
  elseif (page.action1 and not ready1) and (not page.action2 or not ready2) then
    SetStatus("Required addon or profile data is not available for this step.", false)
  else
    SetStatus("READY", true)
  end
end

local function RunAction(slot)
  local page = PAGES[frame and frame.currentPage or 1]
  if not page then return end

  if InCombatLockdown and InCombatLockdown() then
    SetStatus("Leave combat before importing this component.", false)
    return
  end

  if page.reload then
    local db = RUI:EnsureDB()
    db.installerCompleted = true
    ReloadUI()
    return
  end

  if not ReadyFor(page, slot) then
    SetStatus("This option is not available.", false)
    return
  end

  local action = slot == 2 and page.action2 or page.action1
  if type(action) ~= "function" then return end

  local ok, success, message = pcall(action)
  if not ok then
    SetStatus(tostring(success), false)
  elseif success then
    SetStatus(message or "Imported successfully.", true)
  else
    SetStatus(message or "Import failed.", false)
  end
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
  SetBackdrop(frame, {0.018,0.025,0.032,0.985}, {0.55,0.34,0.08,1})

  frame.brand = Font(frame, "RETREATUI — THE BURNING CRUSADE", 18)
  frame.brand:SetPoint("TOPLEFT", 28, -26)
  frame.brand:SetTextColor(0.95,0.58,0.12)

  frame.progress = Font(frame, "STEP 1 OF 8", 10)
  frame.progress:SetPoint("TOPRIGHT", -52, -30)
  frame.progress:SetTextColor(0.58,0.62,0.68)

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(0.16,0.18,0.21,1)
  divider:SetPoint("TOPLEFT",28,-62)
  divider:SetPoint("TOPRIGHT",-28,-62)
  divider:SetHeight(1)

  frame.pageTitle = Font(frame, "", 24)
  frame.pageTitle:SetPoint("TOPLEFT", 42, -105)
  frame.pageTitle:SetTextColor(1,1,1)

  frame.description = Font(frame, "", 11)
  frame.description:SetPoint("TOPLEFT", 42, -160)
  frame.description:SetWidth(660)
  frame.description:SetJustifyH("LEFT")
  frame.description:SetJustifyV("TOP")
  frame.description:SetWordWrap(true)
  frame.description:SetTextColor(0.72,0.76,0.82)

  local statusPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  statusPanel:SetSize(660,62)
  statusPanel:SetPoint("CENTER",0,-28)
  SetBackdrop(statusPanel,{0.025,0.033,0.041,0.94},{0.12,0.15,0.18,1})

  local statusLabel = Font(statusPanel,"STATUS",9)
  statusLabel:SetPoint("TOPLEFT",14,-11)
  statusLabel:SetTextColor(0.48,0.52,0.58)

  frame.status = Font(statusPanel,"",10)
  frame.status:SetPoint("TOPLEFT",statusLabel,"BOTTOMLEFT",0,-8)
  frame.status:SetPoint("RIGHT",statusPanel,"RIGHT",-14,0)
  frame.status:SetJustifyH("LEFT")

  frame.option1 = Button(frame,"SETUP",150,function() RunAction(1) end)
  frame.option2 = Button(frame,"1080p",150,function() RunAction(2) end)
  frame.option1:SetPoint("CENTER",-82,-108)
  frame.option2:SetPoint("CENTER",82,-108)

  frame.back = Button(frame,"BACK",100,function()
    frame.currentPage = math.max(1,(frame.currentPage or 1)-1)
    RefreshPage()
  end)
  frame.back:SetPoint("BOTTOMLEFT",28,22)

  frame.next = Button(frame,"NEXT",120,function()
    frame.currentPage = math.min(TOTAL_PAGES,(frame.currentPage or 1)+1)
    RefreshPage()
  end)
  frame.next:SetPoint("BOTTOMRIGHT",-28,22)

  frame.close = Button(frame,"X",32,function() frame:Hide() end)
  frame.close:SetPoint("TOPRIGHT",-10,-10)

  frame.currentPage = 1
  RefreshPage()
  return frame
end

function RUI:OpenInstaller()
  local installer = BuildInstaller()
  installer.currentPage = 1
  installer:SetFrameStrata("DIALOG")
  RefreshPage()
  installer:Show()
end
