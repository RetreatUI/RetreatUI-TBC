local RUI = RetreatUITBC
if not RUI then return end

local WeakAurasModule = RUI.modules and RUI.modules.weakauras
if not WeakAurasModule then return end

local function Available()
  return WeakAuras
    and type(WeakAuras.Add) == "function"
    and type(WeakAuras.GetData) == "function"
end

local function PreserveUID(data)
  local existing = WeakAuras.GetData(data.id)
  if existing and existing.uid then data.uid = existing.uid end
  return data
end

local function AddDisplay(data)
  local ok, err = pcall(WeakAuras.Add, PreserveUID(data))
  if not ok then return false, tostring(err) end
  if not WeakAuras.GetData(data.id) then
    return false, data.id .. " was not present after WeakAuras.Add"
  end
  return true
end

function WeakAurasModule:HasClassPackage()
  local class = RUI:GetPlayerClass()
  local key = class and class:lower()
  local package = key and RUI.weakAuraPackages and RUI.weakAuraPackages[key] or nil
  return type(package) == "table" and type(package.Build) == "function"
end

function WeakAurasModule:IsGeneralSupported()
  local package = RUI.generalWeakAuraPackage
  return type(package) == "table" and type(package.Build) == "function"
end

function WeakAurasModule:VerifyGeneral(packageData)
  if not Available() then return false, "WeakAuras is not loaded" end
  local package = RUI.generalWeakAuraPackage
  if not package or type(package.Build) ~= "function" then
    return false, "RetreatUI - General package is missing"
  end

  packageData = packageData or package:Build()
  local expected = packageData and packageData.expected
  if type(expected) ~= "table" then return false, "RetreatUI - General returned invalid data" end

  local root = WeakAuras.GetData(expected.root)
  if not root or root.regionType ~= "group" then
    return false, "RetreatUI - General root group is missing"
  end

  local trinkets = WeakAuras.GetData(expected.trinkets)
  if not trinkets or trinkets.regionType ~= "dynamicgroup" then
    return false, "RetreatUI - General trinket group is missing"
  end
  if trinkets.anchorFrameType ~= "SELECTFRAME"
    or trinkets.anchorFrameFrame ~= expected.trinketAnchorFrame
    or trinkets.anchorPoint ~= expected.trinketAnchorPoint
    or trinkets.selfPoint ~= expected.trinketSelfPoint
    or math.abs((tonumber(trinkets.xOffset) or 0) - expected.trinketX) > 0.01
    or math.abs((tonumber(trinkets.yOffset) or 0) - expected.trinketY) > 0.01 then
    return false, "RetreatUI - General trinkets are not at the CoA player-frame position"
  end

  local procs = WeakAuras.GetData(expected.procs)
  if not procs or procs.regionType ~= "dynamicgroup" then
    return false, "RetreatUI - General Buffs & Procs group is missing"
  end
  if procs.anchorFrameType ~= "SCREEN"
    or procs.anchorPoint ~= "CENTER"
    or procs.selfPoint ~= "CENTER"
    or math.abs((tonumber(procs.xOffset) or 0) - expected.procX) > 0.01
    or math.abs((tonumber(procs.yOffset) or 0) - expected.procY) > 0.01 then
    return false, "RetreatUI - General Buffs & Procs is not at the CoA aura-tracker position"
  end

  if expected.swing then
    local swing = WeakAuras.GetData(expected.swing)
    if not swing or swing.regionType ~= "dynamicgroup" then
      return false, "RetreatUI - General Swing Timer group is missing"
    end
    if swing.anchorFrameType ~= "SCREEN"
      or swing.anchorPoint ~= "CENTER"
      or swing.selfPoint ~= "BOTTOM"
      or swing.grow ~= "UP"
      or math.abs((tonumber(swing.xOffset) or 0) - expected.swingX) > 0.01
      or math.abs((tonumber(swing.yOffset) or 0) - expected.swingY) > 0.01
      or math.abs((tonumber(swing.space) or 0) - expected.swingSpacing) > 0.01 then
      return false, "RetreatUI - General Swing Timer is not in the resource-adjacent lane"
    end

    local load = swing.load or {}
    local selected = load.class_and_spec and load.class_and_spec.multi or {}
    if load.use_class_and_spec ~= false then
      return false, "RetreatUI - General Swing Timer is not using multi-spec Load checks"
    end
    for specID, enabled in pairs(expected.swingSpecs or {}) do
      if enabled and selected[specID] ~= true then
        return false, "RetreatUI - General Swing Timer is missing spec " .. tostring(specID)
      end
    end
    for _, excluded in ipairs({ 65, 102, 105, 262, 264, 256, 257, 258, 62, 63, 64, 265, 266, 267 }) do
      if selected[excluded] then
        return false, "RetreatUI - General Swing Timer includes non-melee spec " .. tostring(excluded)
      end
    end
  end

  for _, data in ipairs(packageData.displays or {}) do
    local installed = WeakAuras.GetData(data.id)
    if not installed then return false, data.id .. " is missing" end
    if installed.parent ~= data.parent then return false, data.id .. " has the wrong parent" end
  end

  return true, "RetreatUI - General verified"
end

function WeakAurasModule:InstallGeneral()
  if not Available() then return false, "WeakAuras is not loaded" end
  local package = RUI.generalWeakAuraPackage
  if not package or type(package.Build) ~= "function" then
    return false, "RetreatUI - General package is missing"
  end

  local packageData = package:Build()
  if type(packageData) ~= "table" or type(packageData.root) ~= "table"
    or type(packageData.groups) ~= "table" or type(packageData.displays) ~= "table" then
    return false, "RetreatUI - General returned invalid data"
  end

  -- Seed the static category first, then nested dynamic groups, then their
  -- displays. Finally restore controlledChildren on each group.
  local rootSeed = {}
  for key, value in pairs(packageData.root) do rootSeed[key] = value end
  rootSeed.controlledChildren = {}
  local ok, err = AddDisplay(rootSeed)
  if not ok then return false, err end

  for _, group in ipairs(packageData.groups) do
    local seed = {}
    for key, value in pairs(group) do seed[key] = value end
    seed.controlledChildren = {}
    ok, err = AddDisplay(seed)
    if not ok then return false, err end
  end

  for _, data in ipairs(packageData.displays) do
    ok, err = AddDisplay(data)
    if not ok then return false, err end
  end

  for _, group in ipairs(packageData.groups) do
    ok, err = AddDisplay(group)
    if not ok then return false, err end
  end

  ok, err = AddDisplay(packageData.root)
  if not ok then return false, err end

  if type(WeakAuras.ScanForLoads) == "function" then pcall(WeakAuras.ScanForLoads) end

  local verified, message = self:VerifyGeneral(packageData)
  if not verified then return false, message end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.weakauras = db.integrations.weakauras or {}
  db.integrations.weakauras.general = {
    installed = true,
    version = RUI.version,
    trinkets = true,
    buffsAndProcs = true,
    weaponProcs = true,
    swingTimer = true,
  }

  return true, "RetreatUI - General installed and verified"
end

local OriginalIsClassSupported = WeakAurasModule.IsClassSupported
local OriginalInstallClassHUD = WeakAurasModule.InstallClassHUD

-- The installer has historically treated IsClassSupported as its WeakAuras
-- readiness check. General is universal, so every class now has a valid WA
-- package even before its class-specific HUD has been authored.
function WeakAurasModule:IsClassSupported()
  if self:IsGeneralSupported() then return true end
  return OriginalIsClassSupported and OriginalIsClassSupported(self) or false
end

-- Keep the existing installer/API entry point. It now installs General first,
-- then only the current class HUD when one exists. No other class package is
-- ever imported.
function WeakAurasModule:InstallClassHUD()
  local generalOK, generalMessage = self:InstallGeneral()
  if not generalOK then return false, generalMessage end

  if self:HasClassPackage() then
    local classOK, classMessage = OriginalInstallClassHUD(self)
    if not classOK then return false, classMessage end
    return true, generalMessage .. " + " .. tostring(classMessage)
  end

  local class = RUI:GetPlayerClass() or "this class"
  return true, generalMessage .. "; no class HUD package exists for " .. tostring(class) .. " yet"
end
