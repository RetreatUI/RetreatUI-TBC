local RUI = RetreatUITBC
if not RUI then return end

local WeakAurasModule = {}
RUI:RegisterModule("weakauras", WeakAurasModule)

local function Available()
  return WeakAuras
    and type(WeakAuras.Add) == "function"
    and type(WeakAuras.GetData) == "function"
end

local function CurrentPackage()
  local class = RUI:GetPlayerClass()
  local key = class and class:lower()
  local package = key and RUI.weakAuraPackages and RUI.weakAuraPackages[key] or nil
  return class, package
end

local function PreserveUID(data)
  local existing = WeakAuras.GetData(data.id)
  if existing and existing.uid then data.uid = existing.uid end
  return data
end

local function AddDisplay(data)
  local ok, err = pcall(WeakAuras.Add, PreserveUID(data))
  if not ok then return false, tostring(err) end
  local installed = WeakAuras.GetData(data.id)
  if not installed then return false, data.id .. " was not present after WeakAuras.Add" end
  return true
end

function WeakAurasModule:IsAvailable()
  return Available()
end

function WeakAurasModule:GetClassPackage()
  return CurrentPackage()
end

function WeakAurasModule:IsClassSupported()
  local class, package = CurrentPackage()
  return class ~= nil and type(package) == "table" and type(package.Build) == "function"
end

function WeakAurasModule:GetStatus()
  local class = RUI:GetPlayerClass()
  return {
    available = Available(),
    class = class,
    supported = self:IsClassSupported(),
  }
end

function WeakAurasModule:VerifyClassHUD(packageData)
  if not Available() then return false, "WeakAuras is not loaded" end
  local class, package = CurrentPackage()
  if not package then return false, "No WeakAuras package is available for " .. tostring(class or "this class") end

  packageData = packageData or package:Build()
  if type(packageData) ~= "table" or type(packageData.expected) ~= "table" then
    return false, tostring(class or "Class") .. " WeakAuras package returned invalid data"
  end

  for rootId, geometry in pairs(packageData.expected) do
    local data = WeakAuras.GetData(rootId)
    if not data then return false, rootId .. " is missing" end
    if data.regionType ~= "dynamicgroup" then return false, rootId .. " is not a dynamic group" end
    if data.anchorFrameType ~= "SCREEN" or data.anchorPoint ~= "CENTER" or data.selfPoint ~= "CENTER" then
      return false, rootId .. " is not anchored to screen center"
    end
    if math.abs((tonumber(data.xOffset) or 0) - geometry.x) > 0.01
      or math.abs((tonumber(data.yOffset) or 0) - geometry.y) > 0.01 then
      return false, rootId .. " has the wrong HUD position"
    end
  end

  for _, data in ipairs(packageData.displays or {}) do
    local installed = WeakAuras.GetData(data.id)
    if not installed then return false, data.id .. " is missing" end
    if installed.parent ~= data.parent then return false, data.id .. " has the wrong parent" end
  end

  return true, tostring(class or "Class") .. " HUD verified"
end

function WeakAurasModule:InstallClassHUD()
  if not Available() then return false, "WeakAuras is not loaded" end
  local class, package = CurrentPackage()
  if not package or type(package.Build) ~= "function" then
    return false, "No RetreatUI WeakAuras package exists for " .. tostring(class or "this class") .. "."
  end

  local packageData = package:Build()
  if not packageData or type(packageData.roots) ~= "table" or type(packageData.displays) ~= "table" then
    return false, tostring(class or "Class") .. " WeakAuras package returned invalid data"
  end

  -- Seed parents first, then children, then restore final child ordering.
  for _, root in ipairs(packageData.roots) do
    local seed = {}
    for key, value in pairs(root) do seed[key] = value end
    seed.controlledChildren = {}
    local ok, err = AddDisplay(seed)
    if not ok then return false, err end
  end

  for _, data in ipairs(packageData.displays) do
    local ok, err = AddDisplay(data)
    if not ok then return false, err end
  end

  for _, root in ipairs(packageData.roots) do
    local ok, err = AddDisplay(root)
    if not ok then return false, err end
  end

  if type(WeakAuras.ScanForLoads) == "function" then pcall(WeakAuras.ScanForLoads) end

  local verified, message = self:VerifyClassHUD(packageData)
  if not verified then return false, message end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.weakauras = db.integrations.weakauras or {}
  db.integrations.weakauras[class] = { installed = true, version = RUI.version }

  return true, tostring(class) .. " WeakAuras installed and verified"
end

-- Compatibility aliases for beta.4/beta.5 callers.
function WeakAurasModule:VerifyDruidHUD(packageData)
  return self:VerifyClassHUD(packageData)
end

function WeakAurasModule:InstallDruidHUD()
  if RUI:GetPlayerClass() ~= "DRUID" then return false, "Druid package is only available to Druids" end
  return self:InstallClassHUD()
end

function WeakAurasModule:InstallSelected()
  local db = RUI:EnsureDB()
  local results = {}
  if db.selected.classWA and self:IsClassSupported() then
    local class = RUI:GetPlayerClass() or "class"
    results[class:lower() .. "HUD"] = { self:InstallClassHUD() }
  end
  return results
end
