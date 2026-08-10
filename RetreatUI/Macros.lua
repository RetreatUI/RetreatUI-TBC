local RUI = RetreatUITBC
if not RUI then return end

local Macros = {}
RUI:RegisterModule("macros", Macros)

local function MouseoverSpell(spell)
  return "#showtooltip " .. spell .. "\n/cast [@mouseover,help,nodead][help,nodead][@player] " .. spell
end

local PACKAGES = {
  DRUID = {
    displayName = "Druid",
    recommendedAddon = "DruidMacroHelper",
    recommendation = "Druid Macro Helper (DMH) is recommended for safe powershifting and is required by the Haste/Sapper macros.",
    macros = {
      {
        name = "RUI Powershift",
        iconSpellId = 768,
        perCharacter = true,
        body = "#showtooltip Cat Form\n/cancelaura Cat Form\n/cast !Cat Form",
      },
      {
        name = "RUI HasteSapper",
        iconSpellId = 9634,
        perCharacter = true,
        requiresAddon = "DruidMacroHelper",
        body = "#showtooltip\n/dmh cd pot supersapper\n/dmh start\n/use Haste Potion\n/use Super Sapper Charge\n/cast !Dire Bear Form\n/dmh end",
      },
      {
        name = "RUI SuperSapper",
        iconSpellId = 9634,
        perCharacter = true,
        requiresAddon = "DruidMacroHelper",
        body = "#showtooltip\n/dmh cd supersapper\n/dmh start\n/use Super Sapper Charge\n/cast !Dire Bear Form\n/dmh end",
      },
      {
        name = "RUI HealingTouch",
        iconSpellId = 26979,
        perCharacter = true,
        body = MouseoverSpell("Healing Touch"),
      },
      {
        name = "RUI Regrowth",
        iconSpellId = 26980,
        perCharacter = true,
        body = MouseoverSpell("Regrowth"),
      },
      {
        name = "RUI Rejuvenate",
        iconSpellId = 26982,
        perCharacter = true,
        body = MouseoverSpell("Rejuvenation"),
      },
      {
        name = "RUI Lifebloom",
        iconSpellId = 33763,
        perCharacter = true,
        body = MouseoverSpell("Lifebloom"),
      },
      {
        name = "RUI Swiftmend",
        iconSpellId = 18562,
        perCharacter = true,
        body = MouseoverSpell("Swiftmend"),
      },
      {
        name = "RUI RemoveCurse",
        iconSpellId = 2782,
        perCharacter = true,
        body = MouseoverSpell("Remove Curse"),
      },
      {
        name = "RUI CurePoison",
        iconSpellId = 8946,
        perCharacter = true,
        body = MouseoverSpell("Cure Poison"),
      },
      {
        name = "RUI AbolPoison",
        iconSpellId = 2893,
        perCharacter = true,
        body = MouseoverSpell("Abolish Poison"),
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

function Macros:GetRecommendation()
  local _, package = GetPackage()
  if not package or not package.recommendedAddon then return nil end
  return package.recommendedAddon, package.recommendation
end

function Macros:IsRecommendedAddonLoaded()
  local addon = self:GetRecommendation()
  if not addon then return true end
  return RUI:IsAddonLoaded(addon)
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

  local message = string.format("READY — %s (%d MACROS)", package.displayName or class, #package.macros)
  if package.recommendedAddon and not RUI:IsAddonLoaded(package.recommendedAddon) then
    message = message .. " — DMH RECOMMENDED / NOT LOADED"
  elseif package.recommendedAddon then
    message = message .. " — DMH LOADED"
  end
  return true, message
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

  local message = string.format("%s macros installed (%d).", package.displayName or class, installed)
  if package.recommendedAddon and not RUI:IsAddonLoaded(package.recommendedAddon) then
    message = message .. " Install/enable Druid Macro Helper before using the DMH Haste/Sapper macros."
  end
  return true, message
end
