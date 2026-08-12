local RUI = RetreatUITBC
if not RUI then return end

local WeakAurasModule = {}
RUI:RegisterModule("weakauras", WeakAurasModule)

local function Available()
  return WeakAuras
    and type(WeakAuras.Import) == "function"
    and type(WeakAuras.GetData) == "function"
end

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

local function CurrentPackage()
  local class = RUI:GetPlayerClass()
  local key = class and class:lower()
  local package = key and RUI.weakAuraPackages and RUI.weakAuraPackages[key] or nil
  return class, package
end

local function BuildWrapper(class, packageData)
  local firstRoot = packageData.roots and packageData.roots[1]
  if type(firstRoot) ~= "table" then return nil, "Class WeakAuras package has no root groups" end

  local wrapper = DeepCopy(firstRoot)
  wrapper.id = "RetreatUI TBC — " .. tostring(class)
  wrapper.parent = nil
  wrapper.regionType = "group"
  wrapper.controlledChildren = {}
  wrapper.anchorFrameType = "SCREEN"
  wrapper.anchorPoint = "CENTER"
  wrapper.selfPoint = "CENTER"
  wrapper.xOffset = 0
  wrapper.yOffset = 0

  local children = {}
  for _, root in ipairs(packageData.roots or {}) do
    local child = DeepCopy(root)
    child.parent = wrapper.id
    wrapper.controlledChildren[#wrapper.controlledChildren + 1] = child.id
    children[#children + 1] = child
  end
  for _, display in ipairs(packageData.displays or {}) do
    children[#children + 1] = DeepCopy(display)
  end

  return { m = "d", d = wrapper, c = children, v = 2000 }
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

function WeakAurasModule:BuildClassImport()
  local class, package = CurrentPackage()
  if not package or type(package.Build) ~= "function" then
    return nil, "No RetreatUI WeakAuras package exists for " .. tostring(class or "this class") .. "."
  end

  local packageData = package:Build()
  if type(packageData) ~= "table" or type(packageData.roots) ~= "table" or type(packageData.displays) ~= "table" then
    return nil, tostring(class or "Class") .. " WeakAuras package returned invalid data"
  end

  return BuildWrapper(class, packageData)
end

function WeakAurasModule:OpenClassImport()
  if not Available() then return false, "WeakAuras is not loaded" end
  local class = RUI:GetPlayerClass()
  local bundle, message = self:BuildClassImport()
  if not bundle then return false, message end

  local ok, result, importError = pcall(WeakAuras.Import, bundle)
  if not ok then return false, "WeakAuras import error: " .. tostring(result) end
  if result == false then return false, tostring(importError or "WeakAuras rejected the import") end
  return true, tostring(class or "Class") .. " WeakAuras import window opened"
end

function WeakAurasModule:VerifyClassHUD(packageData)
  if not WeakAuras or type(WeakAuras.GetData) ~= "function" then return false, "WeakAuras is not loaded" end
  local class, package = CurrentPackage()
  if not package then return false, "No WeakAuras package is available for " .. tostring(class or "this class") end

  packageData = packageData or package:Build()
  if type(packageData) ~= "table" or type(packageData.expected) ~= "table" then
    return false, tostring(class or "Class") .. " WeakAuras package returned invalid data"
  end

  for rootId, geometry in pairs(packageData.expected) do
    if type(geometry) == "table" and geometry.x ~= nil and geometry.y ~= nil then
      local data = WeakAuras.GetData(rootId)
      if not data then return false, rootId .. " is missing" end
      if math.abs((tonumber(data.xOffset) or 0) - geometry.x) > 0.01
        or math.abs((tonumber(data.yOffset) or 0) - geometry.y) > 0.01 then
        return false, rootId .. " has the wrong HUD position"
      end
    end
  end

  for _, data in ipairs(packageData.displays or {}) do
    local installed = WeakAuras.GetData(data.id)
    if not installed then return false, data.id .. " is missing" end
    if installed.parent ~= data.parent then return false, data.id .. " has the wrong parent" end
  end

  return true, tostring(class or "Class") .. " HUD verified"
end

-- Compatibility aliases now open WeakAuras' native import/update UI instead of
-- writing displays directly into WeakAuras' database.
function WeakAurasModule:InstallClassHUD()
  return self:OpenClassImport()
end

function WeakAurasModule:VerifyDruidHUD(packageData)
  return self:VerifyClassHUD(packageData)
end

function WeakAurasModule:InstallDruidHUD()
  if RUI:GetPlayerClass() ~= "DRUID" then return false, "Druid package is only available to Druids" end
  return self:OpenClassImport()
end

function WeakAurasModule:InstallSelected()
  local db = RUI:EnsureDB()
  local results = {}
  if db.selected.classWA and self:IsClassSupported() then
    local class = RUI:GetPlayerClass() or "class"
    results[class:lower() .. "HUD"] = { self:OpenClassImport() }
  end
  return results
end
