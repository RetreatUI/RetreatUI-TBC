local RUI = RetreatUITBC
if not RUI then return end

local WeakAurasModule = RUI.modules and RUI.modules.weakauras
if not WeakAurasModule then return end

function WeakAurasModule:IsGeneralSupported()
  return type(RUI.referenceWeakAuras) == "table"
    and type(RUI.referenceWeakAuras.core) == "string"
    and RUI.referenceWeakAuras.core ~= ""
end

function WeakAurasModule:OpenGeneralImport()
  if not WeakAuras or type(WeakAuras.Import) ~= "function" then return false, "WeakAuras is not loaded" end
  local exportString = RUI.referenceWeakAuras and RUI.referenceWeakAuras.core
  if type(exportString) ~= "string" or exportString == "" then return false, "General WeakAura export is missing" end

  local ok, result, importError = pcall(WeakAuras.Import, exportString)
  if not ok then return false, "WeakAuras import error: " .. tostring(result) end
  if result == false then return false, tostring(importError or "WeakAuras rejected the import") end
  return true, "General WeakAuras import window opened"
end

function WeakAurasModule:InstallGeneral()
  return self:OpenGeneralImport()
end
