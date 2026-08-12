local RUI = RetreatUITBC
if not RUI then return end

local WeakAurasModule = {}
RUI:RegisterModule("weakauras", WeakAurasModule)

local function Available()
  return WeakAuras and type(WeakAuras.Import) == "function"
end

local function ClassKey()
  local class = RUI:GetPlayerClass()
  return class and class:lower() or nil, class
end

function WeakAurasModule:IsAvailable()
  return Available()
end

function WeakAurasModule:IsClassSupported()
  local key = ClassKey()
  return key ~= nil
    and type(RUI.referenceWeakAuras) == "table"
    and type(RUI.referenceWeakAuras[key]) == "string"
    and RUI.referenceWeakAuras[key] ~= ""
end

function WeakAurasModule:GetStatus()
  local _, class = ClassKey()
  return { available = Available(), class = class, supported = self:IsClassSupported() }
end

local function OpenImport(exportString)
  if not Available() then return false, "WeakAuras is not loaded" end
  if type(exportString) ~= "string" or exportString == "" then return false, "WeakAura export is missing" end

  local ok, result, importError = pcall(WeakAuras.Import, exportString)
  if not ok then return false, "WeakAuras import error: " .. tostring(result) end
  if result == false then return false, tostring(importError or "WeakAuras rejected the import") end
  return true
end

function WeakAurasModule:OpenClassImport()
  local key, class = ClassKey()
  local exportString = key and RUI.referenceWeakAuras and RUI.referenceWeakAuras[key]
  local ok, message = OpenImport(exportString)
  if not ok then return false, message end
  return true, tostring(class or "Class") .. " WeakAura import window opened"
end

-- Compatibility names retained for existing installer/runtime callers. They now
-- open WeakAuras' own import/update window and never write to the WA database.
function WeakAurasModule:InstallClassHUD()
  return self:OpenClassImport()
end

function WeakAurasModule:InstallDruidHUD()
  local key = ClassKey()
  if key ~= "druid" then return false, "Druid package is only available to Druids" end
  return self:OpenClassImport()
end

function WeakAurasModule:InstallSelected()
  local db = RUI:EnsureDB()
  local results = {}
  if db.selected and db.selected.classWA and self:IsClassSupported() then
    local key = ClassKey()
    results[key .. "HUD"] = { self:OpenClassImport() }
  end
  return results
end
