local RUI = RetreatUITBC
if not RUI then return end

local Macros = {}
RUI:RegisterModule("macros", Macros)

local PACKAGES = {
  DRUID = {
    displayName = "Druid",
    macros = {
      {
        name = "RUI Powershift",
        iconSpellId = 768,
        perCharacter = true,
        body = "#showtooltip\n/cancelaura Cat Form\n/cast !Cat Form",
      },
    },
  },
}

local function CurrentClass()
  return RUI:GetPlayerClass()
end

local function GetPackage()
  local class = CurrentClass()
  return class, class and PACKAGES[class] or nil
end

function Macros:GetClassPackage()
  return GetPackage()
end

function Macros:IsReady()
  local class, package = GetPackage()
  if not class then return false, "PLAYER CLASS NOT AVAILABLE" end
  if not package or type(package.macros) ~= "table" or #package.macros == 0 then
    return false, "NO " .. class .. " MACRO PACKAGE"
  end
  if type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" or type(GetMacroIndexByName) ~= "function" then
    return false, "MACRO API NOT AVAILABLE"
  end
  return true, string.format("READY — %s (%d MACRO%s)", package.displayName or class, #package.macros, #package.macros == 1 and "" or "S")
end

local function MacroIcon(definition)
  if definition.iconSpellId and GetSpellTexture then
    local texture = GetSpellTexture(definition.iconSpellId)
    if texture then return texture end
  end
  return "INV_MISC_QUESTIONMARK"
end

local function InstallMacro(definition)
  local index = GetMacroIndexByName(definition.name)
  local icon = MacroIcon(definition)
  local perCharacter = definition.perCharacter and 1 or nil

  if index and index > 0 then
    local ok, result = pcall(EditMacro, index, definition.name, icon, definition.body, perCharacter)
    if not ok or not result then
      return false, "Could not update " .. definition.name .. ": " .. tostring(result)
    end
    return true, "updated"
  end

  local ok, result = pcall(CreateMacro, definition.name, icon, definition.body, perCharacter)
  if not ok or not result then
    return false, "Could not create " .. definition.name .. ": " .. tostring(result)
  end
  return true, "created"
end

function Macros:Import()
  if InCombatLockdown and InCombatLockdown() then
    return false, "Leave combat before importing macros."
  end

  local class, package = GetPackage()
  if not package then
    return false, "No RetreatUI macro package exists for " .. tostring(class or "this class") .. "."
  end

  local installed = 0
  for _, definition in ipairs(package.macros) do
    local ok, message = InstallMacro(definition)
    if not ok then return false, message end
    installed = installed + 1
  end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.macros = db.integrations.macros or {}
  db.integrations.macros[class] = { installed = true, version = RUI.version, count = installed }

  return true, string.format("%s macros installed (%d).", package.displayName or class, installed)
end
