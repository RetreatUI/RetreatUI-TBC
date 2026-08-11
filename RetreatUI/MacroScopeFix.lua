local RUI = RetreatUITBC
if not RUI or not RUI.modules or not RUI.modules.macros then return end

local Macros = RUI.modules.macros
local MACRO_NAME_LIMIT = 16
local MACRO_BODY_LIMIT = 255

local function Bounds()
  local accountSlots = tonumber(_G.MAX_ACCOUNT_MACROS) or 120
  local characterSlots = tonumber(_G.MAX_CHARACTER_MACROS) or 18
  return 1, accountSlots, accountSlots + 1, accountSlots + characterSlots
end

local function FindMacro(name, first, last)
  if type(GetMacroInfo) ~= "function" then return nil end
  for index = first, last do
    local macroName = GetMacroInfo(index)
    if macroName == name then return index end
  end
  return nil
end

local function FindGeneral(name)
  local gf, gl = Bounds()
  return FindMacro(name, gf, gl)
end

local function FindCharacter(name)
  local _, _, cf, cl = Bounds()
  return FindMacro(name, cf, cl)
end

local function FreeCharacterSlots()
  local _, _, first, last = Bounds()
  local free = 0
  for index = first, last do if not GetMacroInfo(index) then free = free + 1 end end
  return free
end

local function Icon(definition)
  if definition.iconSpellId and GetSpellTexture then
    local texture = GetSpellTexture(definition.iconSpellId)
    if texture then return texture end
  end
  return "INV_MISC_QUESTIONMARK"
end

local function CreateCharacter(name, icon, body)
  local ok, result = pcall(CreateMacro, name, icon, body, true)
  if not ok or not result then return false, "CreateMacro failed for " .. tostring(name) .. ": " .. tostring(result) end
  if not FindCharacter(name) then
    return false, tostring(name) .. " was not created in Character Specific Macros"
  end
  return true
end

local function ValidatePackage(class, package)
  if type(package) ~= "table" or type(package.macros) ~= "table" or #package.macros == 0 then
    return false, "NO " .. tostring(class or "CLASS") .. " MACRO PACKAGE"
  end
  local seen = {}
  for _, definition in ipairs(package.macros) do
    if type(definition.name) ~= "string" or definition.name == "" then return false, "Macro has no name" end
    if #definition.name > MACRO_NAME_LIMIT then return false, definition.name .. " exceeds 16 characters" end
    if seen[definition.name] then return false, "Duplicate macro " .. definition.name end
    seen[definition.name] = true
    if type(definition.body) ~= "string" or definition.body == "" then return false, definition.name .. " has no body" end
    if #definition.body > MACRO_BODY_LIMIT then return false, definition.name .. " exceeds 255 characters" end
  end
  return true
end

function Macros:Import()
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before importing macros." end
  if type(CreateMacro) ~= "function" or type(GetMacroInfo) ~= "function" then return false, "Macro API not available." end

  local class, package = self:GetClassPackage()
  local valid, message = ValidatePackage(class, package)
  if not valid then return false, message end

  local needed = 0
  for _, definition in ipairs(package.macros) do
    if not FindCharacter(definition.name) then needed = needed + 1 end
  end
  local free = FreeCharacterSlots()
  if needed > free then
    return false, string.format("%s needs %d free Character Specific Macro slots, but only %d are available.", package.displayName or class, needed, free)
  end

  local created, preserved, migrated = 0, 0, 0
  for _, definition in ipairs(package.macros) do
    if FindCharacter(definition.name) then
      preserved = preserved + 1
    else
      local generalIndex = FindGeneral(definition.name)
      if generalIndex then
        local oldName, oldIcon, oldBody = GetMacroInfo(generalIndex)
        local ok, err = CreateCharacter(oldName or definition.name, oldIcon or Icon(definition), oldBody or definition.body)
        if not ok then return false, err end
        -- Only delete the account-wide copy after the character copy is verified.
        local deleteOK, deleteErr = pcall(DeleteMacro, generalIndex)
        if not deleteOK then return false, "Character copy created, but could not remove General macro " .. definition.name .. ": " .. tostring(deleteErr) end
        migrated = migrated + 1
      else
        local ok, err = CreateCharacter(definition.name, Icon(definition), definition.body)
        if not ok then return false, err end
        created = created + 1
      end
    end
  end

  -- Remove retired RUI macros only from Character Specific scope.
  if type(package.obsoleteMacros) == "table" and type(DeleteMacro) == "function" then
    for _, name in ipairs(package.obsoleteMacros) do
      local index = FindCharacter(name)
      if index then pcall(DeleteMacro, index) end
    end
  end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.macros = db.integrations.macros or {}
  db.integrations.macros[class] = {
    installed = true, version = RUI.version, count = #package.macros,
    created = created, preserved = preserved, migrated = migrated, characterSpecific = true,
  }

  return true, string.format("%s macros: %d created, %d migrated from General, %d existing Character Specific macros preserved.", package.displayName or class, created, migrated, preserved)
end
