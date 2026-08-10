local RUI = RetreatUITBC
if not RUI then return end

local WeakAurasModule = {}
RUI:RegisterModule("weakauras", WeakAurasModule)

local function Available()
  return WeakAuras
    and type(WeakAuras.Add) == "function"
    and type(WeakAuras.GetData) == "function"
end

local function PreserveUID(data)
  local existing = WeakAuras.GetData(data.id)
  if existing and existing.uid then
    data.uid = existing.uid
  end
  return data
end

local function AddDisplay(data)
  local ok, err = pcall(WeakAuras.Add, PreserveUID(data))
  if not ok then
    return false, tostring(err)
  end
  local installed = WeakAuras.GetData(data.id)
  if not installed then
    return false, data.id .. " was not present after WeakAuras.Add"
  end
  return true
end

function WeakAurasModule:IsAvailable()
  return Available()
end

function WeakAurasModule:IsClassSupported()
  return RUI:GetPlayerClass() == "DRUID"
    and RUI.weakAuraPackages
    and type(RUI.weakAuraPackages.druid) == "table"
    and type(RUI.weakAuraPackages.druid.Build) == "function"
end

function WeakAurasModule:GetStatus()
  return {
    available = Available(),
    druid = self:IsClassSupported(),
  }
end

function WeakAurasModule:VerifyDruidHUD(packageData)
  if not Available() then return false, "WeakAuras is not loaded" end
  local package = RUI.weakAuraPackages and RUI.weakAuraPackages.druid
  if not package then return false, "Druid WeakAuras package is missing" end

  packageData = packageData or package:Build()
  if type(packageData) ~= "table" or type(packageData.expected) ~= "table" then
    return false, "Druid WeakAuras package returned invalid data"
  end

  for rootId, geometry in pairs(packageData.expected) do
    local data = WeakAuras.GetData(rootId)
    if not data then return false, rootId .. " is missing" end
    if data.regionType ~= "dynamicgroup" then
      return false, rootId .. " is not a dynamic group"
    end
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
    if installed.parent ~= data.parent then
      return false, data.id .. " has the wrong parent"
    end
  end

  return true, "Druid HUD verified"
end

function WeakAurasModule:InstallDruidHUD()
  if not Available() then return false, "WeakAuras is not loaded" end
  if not self:IsClassSupported() then return false, "No Druid WeakAuras package is available" end

  local package = RUI.weakAuraPackages.druid
  local packageData = package:Build()
  if not packageData or type(packageData.roots) ~= "table" or type(packageData.displays) ~= "table" then
    return false, "Druid WeakAuras package returned invalid data"
  end

  -- Add roots once so every child has a valid parent, then add the children and
  -- finally re-add the roots with their complete controlledChildren ordering.
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

  if type(WeakAuras.ScanForLoads) == "function" then
    pcall(WeakAuras.ScanForLoads)
  end

  local verified, message = self:VerifyDruidHUD(packageData)
  if not verified then return false, message end
  return true, "installed and verified"
end

function WeakAurasModule:InstallSelected()
  local db = RUI:EnsureDB()
  local results = {}
  if db.selected.classWA and RUI:GetPlayerClass() == "DRUID" then
    results.druidHUD = { self:InstallDruidHUD() }
  end
  return results
end
