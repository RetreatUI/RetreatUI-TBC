from pathlib import Path
import re

macros = Path('RetreatUI/Macros.lua')
text = macros.read_text(encoding='utf-8')

old_bounds = '''local function CharacterMacroBounds()
  local accountSlots = tonumber(_G.MAX_ACCOUNT_MACROS) or 120
  local characterSlots = tonumber(_G.MAX_CHARACTER_MACROS) or 18
  return accountSlots + 1, accountSlots + characterSlots
end

local function CharacterMacroCapacity()'''
new_bounds = '''local function GeneralMacroBounds()
  local accountSlots = tonumber(_G.MAX_ACCOUNT_MACROS) or 120
  return 1, accountSlots
end

local function CharacterMacroBounds()
  local accountSlots = tonumber(_G.MAX_ACCOUNT_MACROS) or 120
  local characterSlots = tonumber(_G.MAX_CHARACTER_MACROS) or 18
  return accountSlots + 1, accountSlots + characterSlots
end

local function CharacterMacroCapacity()'''
assert text.count(old_bounds) == 1
text = text.replace(old_bounds, new_bounds)

old_find = '''local function FindCharacterMacroByName(name)
  if type(GetMacroInfo) ~= "function" then return nil end
  local first, last = CharacterMacroBounds()
  for index = first, last do
    local macroName = GetMacroInfo(index)
    if macroName == name then return index end
  end
  return nil
end

local function DeleteRetiredMacros'''
new_find = '''local function FindGeneralMacroByName(name)
  if type(GetMacroInfo) ~= "function" then return nil end
  local first, last = GeneralMacroBounds()
  for index = first, last do
    local macroName = GetMacroInfo(index)
    if macroName == name then return index end
  end
  return nil
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

local function DeleteRetiredMacros'''
assert text.count(old_find) == 1
text = text.replace(old_find, new_find)

old_ready = 'if type(CreateMacro) ~= "function" or type(GetMacroInfo) ~= "function" then'
new_ready = 'if type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" or type(GetMacroInfo) ~= "function" then'
assert text.count(old_ready) == 1
text = text.replace(old_ready, new_ready)

pattern = re.compile(r'local function InstallCharacterMacro\(definition\).*?\nend\n\n-- Legacy validation marker only.*?\n\nlocal function ShowPostImportWarning', re.S)
replacement = '''local function MigrateGeneralMacroToCharacter(definition, generalIndex)
  local macroName, icon, body = GetMacroInfo(generalIndex)
  if macroName ~= definition.name then
    return false, "General macro changed before migration: " .. definition.name
  end

  -- Preserve the exact player-edited macro body and icon. EditMacro is used
  -- only to change this known RetreatUI macro from General to Character Specific.
  local ok, result = pcall(EditMacro, generalIndex, macroName, icon, body, true)
  if not ok or not result then
    return false, "Could not move " .. definition.name .. " to Character Specific: " .. tostring(result)
  end

  local characterIndex = FindCharacterMacroByName(definition.name)
  if not characterIndex then
    return false, "WoW did not place " .. definition.name .. " in Character Specific Macros."
  end
  if FindGeneralMacroByName(definition.name) then
    return false, "WoW kept " .. definition.name .. " in General Macros after migration."
  end
  return true, "migrated"
end

local function InstallCharacterMacro(definition)
  local characterIndex = FindCharacterMacroByName(definition.name)

  -- Existing Character Specific macros belong to the player once created.
  -- Re-running the installer must never overwrite custom edits, timing values,
  -- equipment names, focus conditions or any other user changes.
  if characterIndex then
    return true, "preserved"
  end

  -- beta.13-beta.16 could create RetreatUI macros in General Macros on clients
  -- that require a real boolean for the per-character flag. Migrate those exact
  -- existing macros while preserving their current player-edited content.
  local generalIndex = FindGeneralMacroByName(definition.name)
  if generalIndex then
    return MigrateGeneralMacroToCharacter(definition, generalIndex)
  end

  local icon = MacroIcon(definition)
  local ok, result = pcall(CreateMacro, definition.name, icon, definition.body, true)
  if not ok or not result then
    return false, "Could not create character macro " .. definition.name .. ": " .. tostring(result)
  end

  -- Never report success unless the client actually placed the macro in the
  -- Character Specific range. If this client still placed it in General,
  -- immediately attempt the same safe scope migration and verify again.
  if not FindCharacterMacroByName(definition.name) then
    generalIndex = FindGeneralMacroByName(definition.name)
    if generalIndex then
      local migrated, migrationStatus = MigrateGeneralMacroToCharacter(definition, generalIndex)
      if migrated then return true, "created" end
      return false, migrationStatus
    end
    return false, "WoW created " .. definition.name .. " outside Character Specific Macros."
  end

  return true, "created"
end

local function ShowPostImportWarning'''
text, count = pattern.subn(replacement, text, count=1)
assert count == 1, count

old_counts = '''  local created, preserved = 0, 0
  for _, definition in ipairs(package.macros) do
    local ok, status = InstallCharacterMacro(definition)
    if not ok then return false, status end
    if status == "created" then created = created + 1
    else preserved = preserved + 1 end
  end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.macros = db.integrations.macros or {}
  db.integrations.macros[class] = {
    installed = true,
    version = RUI.version,
    count = #package.macros,
    created = created,
    preserved = preserved,
    characterSpecific = true,
  }

  local message = string.format("%s macros checked: %d created, %d existing macros preserved. General Macros were not modified.", package.displayName or class, created, preserved)'''
new_counts = '''  local created, migrated, preserved = 0, 0, 0
  for _, definition in ipairs(package.macros) do
    local ok, status = InstallCharacterMacro(definition)
    if not ok then return false, status end
    if status == "created" then
      created = created + 1
    elseif status == "migrated" then
      migrated = migrated + 1
    else
      preserved = preserved + 1
    end
  end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.macros = db.integrations.macros or {}
  db.integrations.macros[class] = {
    installed = true,
    version = RUI.version,
    count = #package.macros,
    created = created,
    migrated = migrated,
    preserved = preserved,
    characterSpecific = true,
  }

  local message = string.format("%s macros checked: %d created, %d moved from General, %d existing Character Specific macros preserved.", package.displayName or class, created, migrated, preserved)'''
assert text.count(old_counts) == 1
text = text.replace(old_counts, new_counts)
macros.write_text(text, encoding='utf-8')

installer = Path('RetreatUI/Installer.lua')
text = installer.read_text(encoding='utf-8')
old = 'description = "RetreatUI creates only missing Character Specific Macros. Existing macros with the same RUI name are preserved exactly as the player edited them. General Macro slots are never touched.",'
new = 'description = "RetreatUI installs macros into Character Specific only. Existing Character Specific RUI macros are preserved exactly; older RetreatUI macros accidentally placed in General are moved here without changing their body or icon.",'
assert text.count(old) == 1
installer.write_text(text.replace(old, new), encoding='utf-8')

core = Path('RetreatUI/Core.lua')
text = core.read_text(encoding='utf-8')
assert text.count('RUI.version = "0.1.0-beta.16"') == 1
core.write_text(text.replace('RUI.version = "0.1.0-beta.16"', 'RUI.version = "0.1.0-beta.17"'), encoding='utf-8')

toc = Path('RetreatUI/RetreatUI.toc')
text = toc.read_text(encoding='utf-8')
assert text.count('## Version: 0.1.0-beta.16') == 1
toc.write_text(text.replace('## Version: 0.1.0-beta.16', '## Version: 0.1.0-beta.17'), encoding='utf-8')

manifest = Path('.github/release-manifest.json')
text = manifest.read_text(encoding='utf-8')
assert text.count('0.1.0-beta.16') == 2
manifest.write_text(text.replace('0.1.0-beta.16', '0.1.0-beta.17'), encoding='utf-8')
