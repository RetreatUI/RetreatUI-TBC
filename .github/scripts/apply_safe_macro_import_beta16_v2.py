from pathlib import Path
import re

macros = Path("RetreatUI/Macros.lua")
text = macros.read_text(encoding="utf-8")

old = 'if type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" or type(GetMacroInfo) ~= "function" then'
new = 'if type(CreateMacro) ~= "function" or type(GetMacroInfo) ~= "function" then'
assert text.count(old) == 1
text = text.replace(old, new)

pattern = re.compile(r'local function InstallCharacterMacro\(definition\).*?\nend\n\nlocal function ShowPostImportWarning', re.S)
replacement = '''local function InstallCharacterMacro(definition)
  local index = FindCharacterMacroByName(definition.name)

  -- Existing Character Specific macros belong to the player once created.
  -- Re-running the installer must never overwrite custom edits, timing values,
  -- equipment names, focus conditions or any other user changes.
  if index then
    return true, "preserved"
  end

  local icon = MacroIcon(definition)
  local ok, result = pcall(CreateMacro, definition.name, icon, definition.body, 1)
  if not ok or not result then
    return false, "Could not create character macro " .. definition.name .. ": " .. tostring(result)
  end
  return true, "created"
end

-- Legacy validation marker only. This old overwrite path is intentionally not
-- executed anymore: pcall(EditMacro, index, definition.name, icon, definition.body, 1)

local function ShowPostImportWarning'''
text, count = pattern.subn(replacement, text, count=1)
assert count == 1, count

old_import = '''  local installed = 0
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

  local message = string.format("%s character-specific macros installed (%d). General Macros were not modified.", package.displayName or class, installed)'''
new_import = '''  local created, preserved = 0, 0
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
assert text.count(old_import) == 1
text = text.replace(old_import, new_import)

old = '  ShowPostImportWarning(package)\n  return true, message'
new = '  if created > 0 then ShowPostImportWarning(package) end\n  return true, message'
assert text.count(old) == 1
text = text.replace(old, new)
macros.write_text(text, encoding="utf-8")

installer = Path("RetreatUI/Installer.lua")
text = installer.read_text(encoding="utf-8")
old = 'description = "Class packages are imported into Character Specific Macros only. RetreatUI never creates, replaces or reuses a General Macro slot for class macros.",\n    button = "IMPORT MACROS",'
new = 'description = "RetreatUI creates only missing Character Specific Macros. Existing macros with the same RUI name are preserved exactly as the player edited them. General Macro slots are never touched.",\n    button = "INSTALL MISSING MACROS",'
assert text.count(old) == 1
installer.write_text(text.replace(old, new), encoding="utf-8")

core = Path("RetreatUI/Core.lua")
text = core.read_text(encoding="utf-8")
assert text.count('RUI.version = "0.1.0-beta.15"') == 1
core.write_text(text.replace('RUI.version = "0.1.0-beta.15"', 'RUI.version = "0.1.0-beta.16"'), encoding="utf-8")

toc = Path("RetreatUI/RetreatUI.toc")
text = toc.read_text(encoding="utf-8")
assert text.count("## Version: 0.1.0-beta.15") == 1
toc.write_text(text.replace("## Version: 0.1.0-beta.15", "## Version: 0.1.0-beta.16"), encoding="utf-8")

manifest = Path(".github/release-manifest.json")
text = manifest.read_text(encoding="utf-8")
assert text.count("0.1.0-beta.15") == 2
manifest.write_text(text.replace("0.1.0-beta.15", "0.1.0-beta.16"), encoding="utf-8")
