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
    characterSpecific = true,
    recommendedAddon = "DruidMacroHelper",
    recommendation = "Druid Macro Helper (DMH) is recommended for safe powershifting and is required by the Haste/Sapper macros.",
    macros = {
      {
        name = "RUI Powershift",
        iconSpellId = 768,
        body = "#showtooltip Cat Form\n/cancelaura Cat Form\n/cast !Cat Form",
      },
      {
        name = "RUI HasteSapper",
        iconSpellId = 9634,
        requiresAddon = "DruidMacroHelper",
        body = "#showtooltip\n/dmh cd pot supersapper\n/dmh start\n/use Haste Potion\n/use Super Sapper Charge\n/cast !Dire Bear Form\n/dmh end",
      },
      {
        name = "RUI SuperSapper",
        iconSpellId = 9634,
        requiresAddon = "DruidMacroHelper",
        body = "#showtooltip\n/dmh cd supersapper\n/dmh start\n/use Super Sapper Charge\n/cast !Dire Bear Form\n/dmh end",
      },
      {
        name = "RUI HealingTouch",
        iconSpellId = 26979,
        body = MouseoverSpell("Healing Touch"),
      },
      {
        name = "RUI Regrowth",
        iconSpellId = 26980,
        body = MouseoverSpell("Regrowth"),
      },
      {
        name = "RUI Rejuvenate",
        iconSpellId = 26982,
        body = MouseoverSpell("Rejuvenation"),
      },
      {
        name = "RUI Lifebloom",
        iconSpellId = 33763,
        body = MouseoverSpell("Lifebloom"),
      },
      {
        name = "RUI Swiftmend",
        iconSpellId = 18562,
        body = MouseoverSpell("Swiftmend"),
      },
      {
        name = "RUI RemoveCurse",
        iconSpellId = 2782,
        body = MouseoverSpell("Remove Curse"),
      },
      {
        name = "RUI CurePoison",
        iconSpellId = 8946,
        body = MouseoverSpell("Cure Poison"),
      },
      {
        name = "RUI AbolPoison",
        iconSpellId = 2893,
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

local function CharacterMacroBounds()
  local accountSlots = tonumber(_G.MAX_ACCOUNT_MACROS) or 120
  local characterSlots = tonumber(_G.MAX_CHARACTER_MACROS) or 18
  return accountSlots + 1, accountSlots + characterSlots
end

local function FindCharacterMacroByName(name)
  if type(GetMacroInfo) ~= "function" then return nil end
  local first, last = CharacterMacroBounds()
  for index = first, last do
    local macroName = GetMacroInfo(index)
    if macroName == name then return index end
  end
  return nil
end

function Macros:IsReady()
  local class, package = GetPackage()
  if not class then return false, "PLAYER CLASS NOT AVAILABLE" end
  if not package or type(package.macros) ~= "table" or #package.macros == 0 then
    return false, "NO " .. class .. " MACRO PACKAGE"
  end
  if type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" or type(GetMacroInfo) ~= "function" then
    return false, "MACRO API NOT AVAILABLE"
  end

  local message = string.format("READY — %s (%d CHARACTER-SPECIFIC MACROS)", package.displayName or class, #package.macros)
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

local function InstallCharacterMacro(definition)
  local index = FindCharacterMacroByName(definition.name)
  local icon = MacroIcon(definition)

  -- Class packages are always character-specific. Never search, edit or reuse
  -- an account-wide General Macro slot with the same name.
  if index then
    local ok, result = pcall(EditMacro, index, definition.name, icon, definition.body, 1)
    if not ok or not result then
      return false, "Could not update character macro " .. definition.name .. ": " .. tostring(result)
    end
    return true, "updated"
  end

  local ok, result = pcall(CreateMacro, definition.name, icon, definition.body, 1)
  if not ok or not result then
    return false, "Could not create character macro " .. definition.name .. ": " .. tostring(result)
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
  if package.characterSpecific ~= true then
    return false, tostring(class or "Class") .. " macro package is not marked character-specific"
  end

  local installed = 0
  for _, definition in ipairs(package.macros) do
    local ok, message = InstallCharacterMacro(definition)
    if not ok then return false, message end
    installed = installed + 1
  end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.macros = db.integrations.macros or {}
  db.integrations.macros[class] = {
    installed = true,
    version = RUI.version,
    count = installed,
    characterSpecific = true,
  }

  local message = string.format("%s character-specific macros installed (%d). General Macros were not modified.", package.displayName or class, installed)
  if package.recommendedAddon and not RUI:IsAddonLoaded(package.recommendedAddon) then
    message = message .. " Install/enable Druid Macro Helper before using the DMH Haste/Sapper macros."
  end
  return true, message
end
