local RUI = RetreatUITBC
if not RUI then return end

local frame
local OPTIONS = {
  { key = "elvui", label = "ElvUI Layout", addon = "ElvUI" },
  { key = "plater", label = "Plater Profile", addon = "Plater" },
  { key = "details", label = "Details Profile", addon = "Details" },
  { key = "classWA", label = "Druid WeakAuras HUD", addon = "WeakAuras" },
}

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
  button:SetSize(width or 130, 28)
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

local function OptionReady(option)
  if not RUI:IsAddonLoaded(option.addon) then return false, option.addon .. " NOT LOADED" end
  if option.key == "plater" then
    local ready = type(RUI.profilePayloads.plater) == "string" and RUI.profilePayloads.plater ~= ""
    return ready, ready and "READY" or "PROFILE NOT EMBEDDED"
  end
  if option.key == "classWA" then
    if RUI:GetPlayerClass() ~= "DRUID" then return false, "DRUID PACKAGE ONLY" end
    local wa = RUI.modules.weakauras
    local ready = wa and wa.IsAvailable and wa:IsAvailable() and wa.IsClassSupported and wa:IsClassSupported()
    return ready, ready and "READY — INSTALL + VERIFY" or "WEAKAURAS PACKAGE NOT READY"
  end
  return true, "READY"
end

local function SetResult(text, success)
  if not frame or not frame.result then return end
  frame.result:SetText(text or "")
  if success == true then
    frame.result:SetTextColor(0.35, 0.9, 0.45)
  elseif success == false then
    frame.result:SetTextColor(0.95, 0.35, 0.2)
  else
    frame.result:SetTextColor(0.7, 0.75, 0.8)
  end
end

local function RefreshRows()
  if not frame or not frame.rows then return end
  local db = RUI:EnsureDB()
  for _, option in ipairs(OPTIONS) do
    local row = frame.rows[option.key]
    local ready, status = OptionReady(option)
    row.available = ready
    row.status:SetText(status)
    row.status:SetTextColor(ready and 0.25 or 0.9, ready and 0.8 or 0.25, ready and 0.35 or 0.2)

    if not ready then
      db.selected[option.key] = false
      row.toggle:Disable()
      row.toggle.label:SetText("N/A")
      row.toggle:SetAlpha(0.55)
      row:SetAlpha(0.72)
    else
      row.toggle:Enable()
      local enabled = db.selected[option.key] ~= false
      db.selected[option.key] = enabled
      row.toggle.label:SetText(enabled and "ON" or "OFF")
      row.toggle:SetAlpha(1)
      row:SetAlpha(enabled and 1 or 0.55)
    end
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
  SetBackdrop(frame, { 0.018, 0.025, 0.032, 0.98 }, { 0.55, 0.34, 0.08, 1 })

  local title = Font(frame, "RETREATUI — THE BURNING CRUSADE", 20)
  title:SetPoint("TOPLEFT", 28, -26)
  title:SetTextColor(0.95, 0.58, 0.12)
  local subtitle = Font(frame, "Install the RetreatUI layout, profiles and WeakAuras class HUD.", 11)
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -9)
  subtitle:SetTextColor(0.72, 0.76, 0.82)
  local classText = Font(frame, "Detected class: " .. (UnitClass("player") or "Unknown"), 12)
  classText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -23)

  frame.rows = {}
  for index, option in ipairs(OPTIONS) do
    local row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    row:SetSize(700, 48)
    row:SetPoint("TOPLEFT", 28, -125 - ((index - 1) * 56))
    SetBackdrop(row, { 0.03, 0.04, 0.05, 0.92 }, { 0.12, 0.15, 0.18, 1 })
    row.title = Font(row, option.label, 12)
    row.title:SetPoint("LEFT", 16, 8)
    row.status = Font(row, "Checking...", 9)
    row.status:SetPoint("LEFT", 16, -10)
    row.toggle = Button(row, "ON", 64, function(self)
      if not row.available then return end
      local db = RUI:EnsureDB()
      db.selected[option.key] = not db.selected[option.key]
      self.label:SetText(db.selected[option.key] and "ON" or "OFF")
      row:SetAlpha(db.selected[option.key] and 1 or 0.55)
    end)
    row.toggle:SetPoint("RIGHT", -12, 0)
    frame.rows[option.key] = row
  end

  local resultPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  resultPanel:SetPoint("BOTTOMLEFT", 28, 18)
  resultPanel:SetPoint("BOTTOMRIGHT", -390, 18)
  resultPanel:SetHeight(54)
  SetBackdrop(resultPanel, { 0.02, 0.027, 0.034, 0.92 }, { 0.12, 0.15, 0.18, 1 })

  frame.result = Font(resultPanel, "Ready.", 9)
  frame.result:SetPoint("TOPLEFT", 10, -8)
  frame.result:SetPoint("BOTTOMRIGHT", -10, 8)
  frame.result:SetJustifyH("LEFT")
  frame.result:SetJustifyV("TOP")
  frame.result:SetWordWrap(true)
  frame.result:SetNonSpaceWrap(true)
  frame.result:SetTextColor(0.7, 0.75, 0.8)

  frame.install = Button(frame, "INSTALL SELECTED", 165, function()
    if InCombatLockdown and InCombatLockdown() then
      SetResult("Leave combat before installing.", false)
      return
    end

    RefreshRows()
    local messages, allSucceeded, attempted = {}, true, 0
    local profiles = RUI.modules.profiles
    if profiles and profiles.InstallSelected then
      for key, result in pairs(profiles:InstallSelected()) do
        attempted = attempted + 1
        local ok, message = result[1], result[2]
        messages[#messages + 1] = key .. ": " .. (ok and "installed" or tostring(message or "failed"))
        if not ok then allSucceeded = false end
      end
    end

    local wa = RUI.modules.weakauras
    if wa and wa.InstallSelected then
      for key, result in pairs(wa:InstallSelected()) do
        attempted = attempted + 1
        local ok, message = result[1], result[2]
        messages[#messages + 1] = key .. ": " .. (ok and tostring(message or "installed") or tostring(message or "failed"))
        if not ok then allSucceeded = false end
      end
    end

    local db = RUI:EnsureDB()
    db.installerCompleted = attempted > 0 and allSucceeded

    if attempted == 0 then
      SetResult("Nothing available is selected for installation.", false)
    else
      SetResult(table.concat(messages, "\n"), allSucceeded)
    end
  end)
  frame.install:SetPoint("BOTTOMRIGHT", -28, 18)

  frame.reload = Button(frame, "RELOAD UI", 110, function() ReloadUI() end)
  frame.reload:SetPoint("RIGHT", frame.install, "LEFT", -10, 0)
  frame.close = Button(frame, "X", 32, function() frame:Hide() end)
  frame.close:SetPoint("TOPRIGHT", -10, -10)

  RefreshRows()
  return frame
end

function RUI:OpenInstaller()
  local installer = BuildInstaller()
  RefreshRows()
  SetResult("Ready. Install the available RetreatUI components, then reload UI.", nil)
  installer:Show()
end
