local RUI = RetreatUITBC
if not RUI then return end

local WeakAurasModule = RUI.modules and RUI.modules.weakauras
if not WeakAurasModule then return end

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

function WeakAurasModule:IsGeneralSupported()
  local package = RUI.generalWeakAuraPackage
  return type(package) == "table" and type(package.Build) == "function"
end

function WeakAurasModule:BuildGeneralImport()
  local package = RUI.generalWeakAuraPackage
  if not package or type(package.Build) ~= "function" then
    return nil, "RetreatUI - General package is missing"
  end

  local packageData = package:Build()
  if type(packageData) ~= "table" or type(packageData.root) ~= "table"
    or type(packageData.groups) ~= "table" or type(packageData.displays) ~= "table" then
    return nil, "RetreatUI - General returned invalid data"
  end

  local root = DeepCopy(packageData.root)
  local children = {}
  for _, group in ipairs(packageData.groups) do children[#children + 1] = DeepCopy(group) end
  for _, display in ipairs(packageData.displays) do children[#children + 1] = DeepCopy(display) end
  return { m = "d", d = root, c = children, v = 2000 }
end

function WeakAurasModule:OpenGeneralImport()
  if not WeakAuras or type(WeakAuras.Import) ~= "function" then return false, "WeakAuras is not loaded" end
  local bundle, message = self:BuildGeneralImport()
  if not bundle then return false, message end

  local ok, result, importError = pcall(WeakAuras.Import, bundle)
  if not ok then return false, "WeakAuras import error: " .. tostring(result) end
  if result == false then return false, tostring(importError or "WeakAuras rejected the import") end
  return true, "General WeakAuras import window opened"
end

function WeakAurasModule:VerifyGeneral(packageData)
  if not WeakAuras or type(WeakAuras.GetData) ~= "function" then return false, "WeakAuras is not loaded" end
  local package = RUI.generalWeakAuraPackage
  if not package or type(package.Build) ~= "function" then return false, "RetreatUI - General package is missing" end

  packageData = packageData or package:Build()
  local expected = packageData and packageData.expected
  if type(expected) ~= "table" then return false, "RetreatUI - General returned invalid data" end

  local root = WeakAuras.GetData(expected.root)
  if not root or root.regionType ~= "group" then return false, "RetreatUI - General root group is missing" end

  for _, data in ipairs(packageData.displays or {}) do
    local installed = WeakAuras.GetData(data.id)
    if not installed then return false, data.id .. " is missing" end
    if installed.parent ~= data.parent then return false, data.id .. " has the wrong parent" end
  end

  return true, "RetreatUI - General verified"
end

-- Compatibility name retained for older callers. The native WeakAuras import
-- window is now the only installation path.
function WeakAurasModule:InstallGeneral()
  return self:OpenGeneralImport()
end
