local RUI = RetreatUITBC
if not RUI then return end

local Module = {}
RUI:RegisterModule("druidUtility", Module)

local REMOVE_CURSE = 2782
local ABOLISH_POISON = 2893
local POISON_CLEANSING_TOTEM = 8166

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"

-- Curated encounter whitelist. The point is not to surface every technically
-- dispellable aura; it is to interrupt the Druid only when the mechanic is
-- worth reacting to.
local MECHANICS = {
  -- Dungeons / Karazhan
  [29833] = { name = "Intangible Presence", dispel = "CURSE", action = REMOVE_CURSE, priority = 2, feral = "ALWAYS", totem = "IGNORE" },
  [34694] = { name = "Blind", dispel = "POISON", action = ABOLISH_POISON, priority = 2, feral = "FALLBACK", totem = "SOFT" },
  [30917] = { name = "Poison Bolt", dispel = "POISON", action = ABOLISH_POISON, priority = 2, feral = "FALLBACK", totem = "HARD" },
  [34780] = { name = "Poison Bolt Volley", dispel = "POISON", action = ABOLISH_POISON, priority = 2, feral = "FALLBACK", totem = "HARD" },
  [39340] = { name = "Poison Bolt Volley", dispel = "POISON", action = ABOLISH_POISON, priority = 2, feral = "FALLBACK", totem = "HARD" },
  [34800] = { name = "Impending Coma", dispel = "POISON", action = ABOLISH_POISON, priority = 2, feral = "FALLBACK", totem = "HARD" },
  [40303] = { name = "Spell Bomb", dispel = "CURSE", action = REMOVE_CURSE, priority = 2, feral = "ALWAYS", totem = "IGNORE" },

  -- Raids
  [38655] = { name = "Poison Bolt Volley", dispel = "POISON", action = ABOLISH_POISON, priority = 2, feral = "FALLBACK", totem = "SOFT" },
  [31972] = { name = "Grip of the Legion", dispel = "CURSE", action = REMOVE_CURSE, priority = 3, feral = "ALWAYS", totem = "IGNORE" },
  [41170] = { name = "Curse of the Bleakheart", dispel = "CURSE", action = REMOVE_CURSE, priority = 2, feral = "FALLBACK", totem = "IGNORE" },

  -- Kalecgos: do not encourage an instant dispel. The frame only lights when
  -- the aura reaches the intended late-dispel window.
  [45032] = {
    name = "Curse of Boundless Agony",
    dispel = "CURSE",
    action = REMOVE_CURSE,
    priority = 3,
    feral = "ALWAYS",
    totem = "IGNORE",
    showBelow = 15,
  },
}

-- Water-slot totems. Casting any of these replaces Poison Cleansing Totem.
-- IDs come from the RetreatUI TBC canonical spell database.
local WATER_TOTEMS = {
  [POISON_CLEANSING_TOTEM] = "POISON",
  [8170] = "OTHER", -- Disease Cleansing Totem
  [5394] = "OTHER", [6375] = "OTHER", [6377] = "OTHER",
  [10462] = "OTHER", [10463] = "OTHER", [25567] = "OTHER", -- Healing Stream
  [5675] = "OTHER", [10495] = "OTHER", [10496] = "OTHER",
  [10497] = "OTHER", [25570] = "OTHER", -- Mana Spring
  [8184] = "OTHER", [10537] = "OTHER", [10538] = "OTHER",
  [25563] = "OTHER", -- Fire Resistance
  [16190] = "OTHER", -- Mana Tide
}

local BORDER_COLORS = {
  CURSE = { 0.68, 0.28, 0.95, 1 },
  POISON = { 0.20, 0.88, 0.32, 1 },
  URGENT = { 1.00, 0.20, 0.08, 1 },
}

local enabled = false
local eventFrame
local roster = {}
local framesByGUID = {}
local overlays = {}
local activeWaterTotems = {}
local thresholdTimers = {}
local frameRefreshPending = false
local totemSerial = 0

local function ClearTable(tbl)
  for key in pairs(tbl) do
    tbl[key] = nil
  end
end

local function RaidCount()
  if IsInRaid and IsInRaid() then
    if GetNumGroupMembers then return GetNumGroupMembers() end
    if GetNumRaidMembers then return GetNumRaidMembers() end
  end
  return 0
end

local function PartyCount()
  if IsInRaid and IsInRaid() then return 0 end
  if GetNumSubgroupMembers then return GetNumSubgroupMembers() end
  if GetNumPartyMembers then return GetNumPartyMembers() end
  return 0
end

local function ForEachGroupUnit(callback)
  local raidCount = RaidCount()
  if raidCount > 0 then
    for index = 1, raidCount do
      callback("raid" .. index, index, true)
    end
    return
  end

  callback("player", 0, false)
  for index = 1, PartyCount() do
    callback("party" .. index, index, false)
  end
end

local function RebuildRoster()
  ClearTable(roster)

  ForEachGroupUnit(function(unit, index, inRaid)
    if not UnitExists(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    local _, class = UnitClass(unit)
    local subgroup = 1
    if inRaid and GetRaidRosterInfo then
      subgroup = select(3, GetRaidRosterInfo(index)) or 1
    end

    roster[guid] = {
      unit = unit,
      class = class,
      subgroup = subgroup,
      connected = not UnitIsConnected or UnitIsConnected(unit),
      dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) or false,
    }
  end)

  for ownerGUID in pairs(activeWaterTotems) do
    if not roster[ownerGUID] then
      activeWaterTotems[ownerGUID] = nil
    end
  end
end

local function IsFeral()
  local bestTab, bestPoints = nil, -1
  if GetTalentTabInfo then
    for tab = 1, 3 do
      local _, _, points = GetTalentTabInfo(tab)
      points = tonumber(points) or 0
      if points > bestPoints then
        bestPoints = points
        bestTab = tab
      end
    end
  end

  if bestTab and bestPoints > 0 then
    return bestTab == 2
  end

  local powerType = UnitPowerType and UnitPowerType("player")
  return powerType == 1 or powerType == 3
end

local function HasPreferredCleaner(dispelType)
  local playerGUID = UnitGUID("player")
  for guid, info in pairs(roster) do
    if guid ~= playerGUID and info.connected and not info.dead then
      if dispelType == "POISON" and (info.class == "SHAMAN" or info.class == "PALADIN") then
        return true
      end
      if dispelType == "CURSE" and info.class == "MAGE" then
        return true
      end
    end
  end
  return false
end

local function HasPoisonTotemCoverage(unit)
  local guid = UnitGUID(unit)
  local info = guid and roster[guid]
  if not info then return false end

  local now = GetTime()
  for ownerGUID, totem in pairs(activeWaterTotems) do
    local owner = roster[ownerGUID]
    if owner and owner.subgroup == info.subgroup and totem.kind == "POISON" and totem.expires > now then
      return true
    end
  end

  return false
end

local function ShouldShow(unit, mechanic)
  local feral = IsFeral()

  if mechanic.dispel == "POISON" then
    local covered = HasPoisonTotemCoverage(unit)
    if covered and mechanic.totem == "HARD" then
      return false
    end
    if covered and mechanic.totem == "SOFT" and feral then
      return false
    end
  end

  if not feral then
    return true
  end

  if mechanic.feral == "NEVER" then
    return false
  end

  if mechanic.feral == "FALLBACK" and HasPreferredCleaner(mechanic.dispel) then
    return false
  end

  return true
end

local function SetEdgeThickness(overlay, thickness)
  overlay.top:SetHeight(thickness)
  overlay.bottom:SetHeight(thickness)
  overlay.left:SetWidth(thickness)
  overlay.right:SetWidth(thickness)
end

local function SetEdgeColor(overlay, color)
  overlay.top:SetVertexColor(color[1], color[2], color[3], color[4])
  overlay.bottom:SetVertexColor(color[1], color[2], color[3], color[4])
  overlay.left:SetVertexColor(color[1], color[2], color[3], color[4])
  overlay.right:SetVertexColor(color[1], color[2], color[3], color[4])
end

local function CreateOverlay(parent)
  if InCombatLockdown and InCombatLockdown() then
    frameRefreshPending = true
    return nil
  end

  local overlay = CreateFrame("Frame", nil, parent)
  overlay:SetAllPoints(parent)
  overlay:SetFrameLevel(math.min((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 20, 128))
  overlay:EnableMouse(false)

  overlay.top = overlay:CreateTexture(nil, "OVERLAY")
  overlay.top:SetTexture(WHITE_TEXTURE)
  overlay.top:SetPoint("TOPLEFT", overlay, "TOPLEFT", -1, 1)
  overlay.top:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 1, 1)

  overlay.bottom = overlay:CreateTexture(nil, "OVERLAY")
  overlay.bottom:SetTexture(WHITE_TEXTURE)
  overlay.bottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", -1, -1)
  overlay.bottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 1, -1)

  overlay.left = overlay:CreateTexture(nil, "OVERLAY")
  overlay.left:SetTexture(WHITE_TEXTURE)
  overlay.left:SetPoint("TOPLEFT", overlay, "TOPLEFT", -1, 1)
  overlay.left:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", -1, -1)

  overlay.right = overlay:CreateTexture(nil, "OVERLAY")
  overlay.right:SetTexture(WHITE_TEXTURE)
  overlay.right:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 1, 1)
  overlay.right:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 1, -1)

  overlay.iconBG = overlay:CreateTexture(nil, "OVERLAY")
  overlay.iconBG:SetTexture(WHITE_TEXTURE)
  overlay.iconBG:SetVertexColor(0, 0, 0, 1)
  overlay.iconBG:SetSize(18, 18)
  overlay.iconBG:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 2, 2)

  overlay.icon = overlay:CreateTexture(nil, "OVERLAY")
  overlay.icon:SetSize(16, 16)
  overlay.icon:SetPoint("CENTER", overlay.iconBG, "CENTER", 0, 0)

  SetEdgeThickness(overlay, 2)
  overlay:Hide()
  overlays[parent] = overlay
  return overlay
end

local function EnsureOverlay(parent)
  return overlays[parent] or CreateOverlay(parent)
end

local function IsSupportedGroupFrameName(name)
  if type(name) ~= "string" then return false end
  return name:match("^ElvUF_Party")
    or name:match("^ElvUF_Raid")
    or name:match("^CompactRaidFrame")
    or name:match("^CompactPartyFrame")
    or name:match("^PartyMemberFrame")
end

local function RegisterFrameForUnit(frame, unit)
  if not unit or not UnitExists(unit) then return end
  local guid = UnitGUID(unit)
  if not guid then return end

  local list = framesByGUID[guid]
  if not list then
    list = {}
    framesByGUID[guid] = list
  end

  for index = 1, #list do
    if list[index] == frame then return end
  end
  list[#list + 1] = frame
end

local function ScanGroupFrames()
  if InCombatLockdown and InCombatLockdown() then
    frameRefreshPending = true
    return
  end

  for _, overlay in pairs(overlays) do
    overlay:Hide()
  end
  ClearTable(framesByGUID)

  for name, frame in pairs(_G) do
    if IsSupportedGroupFrameName(name) and frame then
      local unit = frame.unit
      if not unit and frame.GetAttribute then
        local ok, value = pcall(frame.GetAttribute, frame, "unit")
        if ok then unit = value end
      end

      if unit then
        RegisterFrameForUnit(frame, unit)
      end
    end
  end

  frameRefreshPending = false
end

local function HideGUID(guid)
  local frames = framesByGUID[guid]
  if not frames then return end

  for index = 1, #frames do
    local overlay = overlays[frames[index]]
    if overlay then overlay:Hide() end
  end
end

local function ShowGUID(guid, mechanic, urgent)
  local frames = framesByGUID[guid]
  if not frames then return end

  local color = urgent and BORDER_COLORS.URGENT or BORDER_COLORS[mechanic.dispel]
  local thickness = mechanic.priority >= 3 and 3 or 2
  local icon = GetSpellTexture(mechanic.action)

  for index = 1, #frames do
    local frame = frames[index]
    local overlay = EnsureOverlay(frame)
    if overlay then
      SetEdgeThickness(overlay, thickness)
      SetEdgeColor(overlay, color)
      overlay.icon:SetTexture(icon or 134400)
      overlay:Show()
    end
  end
end

local RefreshAllUnits

local function ScheduleThreshold(guid, spellId, expirationTime, delay)
  if not C_Timer or not C_Timer.After or delay <= 0 then return end

  local key = tostring(guid) .. ":" .. tostring(spellId)
  if thresholdTimers[key] == expirationTime then return end
  thresholdTimers[key] = expirationTime

  C_Timer.After(delay + 0.05, function()
    if thresholdTimers[key] == expirationTime then
      thresholdTimers[key] = nil
      if RefreshAllUnits then RefreshAllUnits() end
    end
  end)
end

local function FindBestMechanic(unit)
  local guid = UnitGUID(unit)
  if not guid then return nil, false end

  local best
  local bestUrgent = false
  local now = GetTime()

  for index = 1, 40 do
    local auraName, _, _, _, _, duration, expirationTime, _, _, _, spellId = UnitDebuff(unit, index)
    if not auraName then break end

    local mechanic = spellId and MECHANICS[spellId]
    if mechanic then
      local eligible = true
      local urgent = false

      if mechanic.showBelow and duration and duration > 0 and expirationTime and expirationTime > 0 then
        local remaining = expirationTime - now
        if remaining > mechanic.showBelow then
          ScheduleThreshold(guid, spellId, expirationTime, remaining - mechanic.showBelow)
          eligible = false
        elseif remaining > 0 then
          urgent = true
        end
      end

      if eligible and ShouldShow(unit, mechanic) then
        if not best or mechanic.priority > best.priority then
          best = mechanic
          bestUrgent = urgent
        end
      end
    end
  end

  return best, bestUrgent
end

local function RefreshUnit(unit)
  if not unit or not UnitExists(unit) then return end

  local guid = UnitGUID(unit)
  if not guid then return end

  HideGUID(guid)
  local mechanic, urgent = FindBestMechanic(unit)
  if mechanic then
    ShowGUID(guid, mechanic, urgent)
  end
end

RefreshAllUnits = function()
  if not enabled then return end

  ForEachGroupUnit(function(unit)
    RefreshUnit(unit)
  end)
end

local function RefreshFramesAndUnits()
  RebuildRoster()
  ScanGroupFrames()
  RefreshAllUnits()
end

local function ScheduleFrameRefresh(delay)
  if not C_Timer or not C_Timer.After then
    RefreshFramesAndUnits()
    return
  end

  C_Timer.After(delay or 0, function()
    if enabled then RefreshFramesAndUnits() end
  end)
end

local function TrackWaterTotem(sourceGUID, spellId, destGUID)
  local owner = roster[sourceGUID]
  if not owner or owner.class ~= "SHAMAN" then return end

  local kind = WATER_TOTEMS[spellId]
  if not kind then return end

  if kind ~= "POISON" then
    if activeWaterTotems[sourceGUID] then
      activeWaterTotems[sourceGUID] = nil
      RefreshAllUnits()
    end
    return
  end

  totemSerial = totemSerial + 1
  local serial = totemSerial
  activeWaterTotems[sourceGUID] = {
    kind = "POISON",
    subgroup = owner.subgroup,
    totemGUID = destGUID,
    expires = GetTime() + 120,
    serial = serial,
  }

  RefreshAllUnits()

  if C_Timer and C_Timer.After then
    C_Timer.After(120.2, function()
      local current = activeWaterTotems[sourceGUID]
      if current and current.serial == serial then
        activeWaterTotems[sourceGUID] = nil
        RefreshAllUnits()
      end
    end)
  end
end

local function HandleCombatLog()
  if not CombatLogGetCurrentEventInfo then return end

  local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()

  if (subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_SUMMON") and sourceGUID and spellId and WATER_TOTEMS[spellId] then
    local existing = activeWaterTotems[sourceGUID]
    if subevent == "SPELL_SUMMON"
      and spellId == POISON_CLEANSING_TOTEM
      and existing
      and existing.kind == "POISON" then
      existing.totemGUID = destGUID
      return
    end

    TrackWaterTotem(sourceGUID, spellId, subevent == "SPELL_SUMMON" and destGUID or nil)
    return
  end

  if subevent == "UNIT_DIED" and destGUID then
    for ownerGUID, totem in pairs(activeWaterTotems) do
      if totem.totemGUID and totem.totemGUID == destGUID then
        activeWaterTotems[ownerGUID] = nil
        RefreshAllUnits()
        break
      end
    end
  end
end

local function HandleEvent(_, event, arg1)
  if event == "UNIT_AURA" then
    if arg1 and UnitExists(arg1) then
      local guid = UnitGUID(arg1)
      if guid and roster[guid] then
        RefreshUnit(arg1)
      end
    end
    return
  end

  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    HandleCombatLog()
    return
  end

  if event == "GROUP_ROSTER_UPDATE" then
    RebuildRoster()
    ScheduleFrameRefresh(0.2)
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    ClearTable(activeWaterTotems)
    ClearTable(thresholdTimers)
    RebuildRoster()
    ScheduleFrameRefresh(0.5)
    ScheduleFrameRefresh(2.0)
    return
  end

  if event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" then
    RefreshAllUnits()
    return
  end

  if event == "PLAYER_REGEN_ENABLED" and frameRefreshPending then
    ScheduleFrameRefresh(0)
  end
end

function Module:GetStatus()
  local poisonTotems = 0
  local now = GetTime()
  for _, totem in pairs(activeWaterTotems) do
    if totem.kind == "POISON" and totem.expires > now then
      poisonTotems = poisonTotems + 1
    end
  end

  return {
    enabled = enabled,
    feral = enabled and IsFeral() or false,
    poisonTotems = poisonTotems,
  }
end

function Module:OnLogin()
  local db = RUI:EnsureDB()
  if RUI:GetPlayerClass() ~= "DRUID" or not db.selected.classWA then
    return
  end

  enabled = true
  eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("UNIT_AURA")
  eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
  eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
  eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  eventFrame:SetScript("OnEvent", HandleEvent)

  RebuildRoster()
  ScheduleFrameRefresh(0.5)
  ScheduleFrameRefresh(2.0)
end
