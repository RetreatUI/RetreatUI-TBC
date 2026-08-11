local RUI = RetreatUITBC
if not RUI then return end

local Macros = {}
RUI:RegisterModule("macros", Macros)

local MACRO_NAME_LIMIT = 16
local MACRO_BODY_LIMIT = 255

local function MouseoverSpell(spell)
  return "#showtooltip " .. spell .. "\n/cast [@mouseover,help,nodead][help,nodead][@player] " .. spell
end

local function HostileMouseoverSpell(spell)
  return "#showtooltip " .. spell .. "\n/stopcasting\n/cast [@mouseover,harm,nodead][@focus,harm,nodead][] " .. spell
end

local function Macro(name, iconSpellId, body, options)
  local definition = {
    name = name,
    iconSpellId = iconSpellId,
    body = body,
  }
  for key, value in pairs(options or {}) do definition[key] = value end
  return definition
end

local function MouseoverMacro(name, iconSpellId, spell)
  return Macro(name, iconSpellId, MouseoverSpell(spell))
end

local function HostileMouseoverMacro(name, iconSpellId, spell)
  return Macro(name, iconSpellId, HostileMouseoverSpell(spell))
end

local PACKAGES = {
  DRUID = {
    displayName = "Druid",
    characterSpecific = true,
    recommendedAddon = "DruidMacroHelper",
    recommendation = "Druid Macro Helper (DMH) is recommended for safe powershifting and is required by the Haste/Sapper macros.",
    importNote = "All supplied Druid macros are included. The older RUI CurePoison macro is retired during import because RUI AbolPoison is the end-game poison cleanse.",
    obsoleteMacros = { "RUI CurePoison" },
    macros = {
      Macro("RUI Powershift", 768, "#showtooltip Cat Form\n/cancelaura Cat Form\n/cast !Cat Form"),
      Macro("RUI HasteSapper", 9634, "#showtooltip\n/dmh cd pot supersapper\n/dmh start\n/use Haste Potion\n/use Super Sapper Charge\n/cast !Dire Bear Form\n/dmh end", { requiresAddon = "DruidMacroHelper" }),
      Macro("RUI SuperSapper", 9634, "#showtooltip\n/dmh cd supersapper\n/dmh start\n/use Super Sapper Charge\n/cast !Dire Bear Form\n/dmh end", { requiresAddon = "DruidMacroHelper" }),
      MouseoverMacro("RUI HealingTouch", 26979, "Healing Touch"),
      MouseoverMacro("RUI Regrowth", 26980, "Regrowth"),
      MouseoverMacro("RUI Rejuvenate", 26982, "Rejuvenation"),
      MouseoverMacro("RUI Lifebloom", 33763, "Lifebloom"),
      MouseoverMacro("RUI Swiftmend", 18562, "Swiftmend"),
      MouseoverMacro("RUI RemoveCurse", 2782, "Remove Curse"),
      MouseoverMacro("RUI AbolPoison", 2893, "Abolish Poison"),
      Macro("RUI StarfireCD", 2912, "#showtooltip Starfire\n/use 13\n/use 14\n/use Destruction Potion\n/cast Starfire\n/cqs"),
      Macro("RUI MoonInsect", 8921, "#showtooltip\n/cast [mod:alt]Insect Swarm; Moonfire"),
      Macro("RUI Prowl", 5215, "#showtooltip Prowl\n/cancelaura [stance:1] Bear Form; [stance:2] Aquatic Form\n/cast [nostance:3] Cat Form(Shapeshift); [nostealth,nocombat]\n/cast Prowl"),
      Macro("RUI Dash", 1850, "#showtooltip Dash\n/cancelform [noform:3]\n/cast [noform:3] Cat Form\n/cast Dash"),
      Macro("RUI Hurricane", 16914, "#showtooltip Hurricane\n/cast [@cursor] Hurricane"),
      Macro("RUI FeralCharge", 16979, "#showtooltip Feral Charge\n/cancelform [noform:1]\n/cast [noform:1] Dire Bear Form\n/cast Feral Charge"),
      Macro("RUI NSHeal", 17116, "#showtooltip Healing Touch\n/cast Nature's Swiftness\n/cast [@mouseover,help,nodead][help,nodead][@player] Healing Touch"),
      Macro("RUI Moonkin", 24858, "#showtooltip Moonkin Form\n/cast !Moonkin Form"),
    },
  },
  HUNTER = {
    displayName = "Hunter",
    characterSpecific = true,
    importNote = "RUI FeedPet still uses the <food> placeholder. RUI Steady is a timing template and must be checked against your effective ranged attack speed.",
    postImportWarningTitle = "RETREATUI — HUNTER MACRO SETUP",
    postImportWarning = "RUI Steady was installed with reset=2.52 as a template. That timing is NOT universal. Change 2.52 to match your current effective ranged attack speed before using it. Weapon swaps and haste effects can change the correct timing, so re-check it when your setup changes.\n\nAlso replace <food> in RUI FeedPet with the food you actually use.",
    macros = {
      Macro("RUI RaptorWeave", 2973, "#showtooltip Raptor Strike\n/stopattack\n/cleartarget\n/targetlasttarget\n/cast Raptor Strike\n/startattack"),
      Macro("RUI HunterBurst", 19574, "#showtooltip Bestial Wrath\n/cast Bestial Wrath\n/use Haste Potion\n/cast Rapid Fire\n/cast Blood Fury\n/use 14"),
      Macro("RUI FeedPet", 6991, "#showtooltip <food>\n/cast [pet,nodead] Feed Pet\n/use <food>"),
      Macro("RUI PetCare", 136, "#showtooltip Mend Pet\n/use [@pet,nodead,exists] Mend Pet\n/stopmacro [@pet,nodead,exists]\n/use [@pet,dead,exists] Revive Pet\n/castsequence reset=2 Call Pet, Revive Pet"),
      Macro("RUI Steady", 34120, "#showtooltip Steady Shot\n/run UIErrorsFrame:Hide()\n/castsequence reset=2.52 Steady Shot, !Auto Shot\n/use [exists,target=pettarget] Kill Command\n/run UIErrorsFrame:Clear(); UIErrorsFrame:Show()"),
      Macro("RUI AutoShot", 75, "#showtooltip Auto Shot\n/cleartarget [dead]\n/targetenemy [noharm][dead]\n/stopattack\n/cast !Auto Shot"),
      Macro("RUI Misdirect", 34477, "#showtooltip Misdirection\n/cast [@mouseover,help,nodead][@focus,help,nodead][@pet,exists,nodead][] Misdirection"),
      Macro("RUI PetAttack", 75, "#showtooltip Auto Shot\n/cast !Auto Shot\n/petattack"),
    },
  },
  MAGE = {
    displayName = "Mage",
    characterSpecific = true,
    macros = {
      Macro("RUI Blink", 1953, "#showtooltip\n/stopcasting\n/cast Blink"),
      Macro("RUI Counterspell", 2139, "#showtooltip\n/stopcasting\n/cast [@mouseover,harm,nodead][] Counterspell"),
      Macro("RUI IceBlock", 45438, "#showtooltip\n/stopcasting\n/cast Ice Block\n/cancelaura Ice Block"),
      Macro("RUI ABTrinket1", 30451, "#showtooltip\n/use 13\n/use Arcane Blast\n/cqs"),
      Macro("RUI ABTrinket2", 30451, "#showtooltip\n/use 14\n/use Arcane Blast\n/cqs"),
      Macro("RUI ABManaPot", 30451, "#showtooltip\n/use Mana Potion Injector\n/use Super Mana Potion\n/use Arcane Blast\n/cqs"),
      Macro("RUI ABManaGem", 30451, "#showtooltip\n/use Mana Emerald\n/use Arcane Blast\n/cqs"),
      Macro("RUI ABDestro", 30451, "#showtooltip\n/use Destruction Potion\n/use Arcane Blast\n/cqs"),
      Macro("RUI Blizzard", 10, "#showtooltip Blizzard\n/cast [@cursor] Blizzard"),
      Macro("RUI ArcaneBurst", 12042, "#showtooltip Arcane Power\n/use 13\n/use 14\n/use Berserking\n/use Arcane Power\n/use Icy Veins\n/use Arcane Blast\n/cqs"),
      Macro("RUI ABGrenade", 30451, "#showtooltip Arcane Blast\n/use [@cursor] Adamantite Grenade\n/use Arcane Blast\n/cqs"),
      MouseoverMacro("RUI Decurse", 475, "Remove Lesser Curse"),
      Macro("RUI WaterElem", 31687, "#showtooltip Summon Water Elemental\n/cast Summon Water Elemental\n/petattack"),
      Macro("RUI PetFreeze", 33395, "#showtooltip Freeze\n/cast [@cursor] !Freeze"),
    },
  },
  PALADIN = {
    displayName = "Paladin",
    characterSpecific = true,
    importNote = "The two weapon-swap templates contain name-of-your-... placeholders. Replace them with your actual weapon and shield names or item IDs.",
    macros = {
      MouseoverMacro("RUI HolyLight", 635, "Holy Light"),
      MouseoverMacro("RUI FlashLight", 19750, "Flash of Light"),
      MouseoverMacro("RUI Cleanse", 4987, "Cleanse"),
      MouseoverMacro("RUI BOP", 1022, "Blessing of Protection"),
      MouseoverMacro("RUI Freedom", 1044, "Blessing of Freedom"),
      MouseoverMacro("RUI Sacrifice", 6940, "Blessing of Sacrifice"),
      MouseoverMacro("RUI LayHands", 633, "Lay on Hands"),
      Macro("RUI HolyShock", 20473, "#showtooltip Holy Shock\n/cast [@mouseover,help,nodead][@mouseover,harm,nodead][] Holy Shock"),
      Macro("RUI RDefense", 31789, "#showtooltip Righteous Defense\n/cast [@mouseover,help,nodead][help,nodead][] Righteous Defense"),
      Macro("RUI HoJ", 853, "#showtooltip Hammer of Justice\n/script SpellStopCasting()\n/cast Hammer of Justice"),
      Macro("RUI Shield2H", nil, "#showtooltip\n/stopcasting\n/eq [noworn:shield] name-of-your-Shield\n/equipslot [noworn:shield] 16 name-of-your-MH\n/eq [noworn:two-hand] name-of-your-2H"),
      Macro("RUI ShieldDual", nil, "#showtooltip\n/stopcasting\n/eq [noworn:shield] name-of-your-Shield\n/equipslot [noworn:shield] 16 name-of-your-MH\n/equipslot [worn:shield] 16 name-of-your-MH\n/equipslot [worn:shield] 17 name-of-your-OH"),
    },
  },
  PRIEST = {
    displayName = "Priest",
    characterSpecific = true,
    macros = {
      MouseoverMacro("RUI FlashHeal", 2061, "Flash Heal"),
      MouseoverMacro("RUI GreaterHeal", 2060, "Greater Heal"),
      MouseoverMacro("RUI Renew", 139, "Renew"),
      MouseoverMacro("RUI PWShield", 17, "Power Word: Shield"),
      MouseoverMacro("RUI PrayerMend", 33076, "Prayer of Mending"),
      MouseoverMacro("RUI BindingHeal", 32546, "Binding Heal"),
      MouseoverMacro("RUI CircleHeal", 34861, "Circle of Healing"),
      Macro("RUI DispelMagic", 527, "#showtooltip Dispel Magic\n/cast [@mouseover,help,nodead][@mouseover,harm,nodead][help,nodead][harm,nodead][@player] Dispel Magic"),
      MouseoverMacro("RUI CureDisease", 528, "Cure Disease"),
      MouseoverMacro("RUI AbolDisease", 552, "Abolish Disease"),
      MouseoverMacro("RUI PainSupp", 33206, "Pain Suppression"),
      MouseoverMacro("RUI PowerInfuse", 10060, "Power Infusion"),
      HostileMouseoverMacro("RUI Silence", 15487, "Silence"),
      Macro("RUI PsyScream", 8122, "#showtooltip Psychic Scream\n/stopcasting\n/cast Psychic Scream"),
    },
  },
  ROGUE = {
    displayName = "Rogue",
    characterSpecific = true,
    macros = {
      Macro("RUI Sinister", 1752, "#showtooltip Sinister Strike\n/cast Sinister Strike\n/startattack"),
      Macro("RUI Stealth", 1784, "#showtooltip Stealth\n/cast !Stealth"),
      Macro("RUI Sap", 6770, "#showtooltip Sap\n/stopattack\n/cleartarget\n/targetenemyplayer\n/cast Sap"),
      Macro("RUI RogueBurst", 13750, "#showtooltip\n/cast Adrenaline Rush\n/cast Blade Flurry\n/use 13\n/use 14\n/use Haste Potion\n/use Flame Cap"),
      Macro("RUI Blind", 2094, "#showtooltip Blind\n/cast [mod:shift,@focus,harm,nodead][] Blind"),
      Macro("RUI Kick", 1766, "#showtooltip Kick\n/cast [@mouseover,harm,nodead][@focus,harm,nodead][] Kick\n/startattack"),
      Macro("RUI Vanish", 1856, "#showtooltip Vanish\n/stopattack\n/cast Vanish"),
      Macro("RUI Ranged", 2764, "#showtooltip\n/cast [worn:thrown] Throw; [worn:bow] Shoot; [worn:gun] Shoot; [worn:crossbow] Shoot"),
    },
  },
  SHAMAN = {
    displayName = "Shaman",
    characterSpecific = true,
    macros = {
      MouseoverMacro("RUI HealingWave", 331, "Healing Wave"),
      MouseoverMacro("RUI LesserHeal", 8004, "Lesser Healing Wave"),
      MouseoverMacro("RUI ChainHeal", 1064, "Chain Heal"),
      MouseoverMacro("RUI EarthShield", 974, "Earth Shield"),
      MouseoverMacro("RUI CurePoison", 526, "Cure Poison"),
      MouseoverMacro("RUI CureDisease", 2870, "Cure Disease"),
      Macro("RUI NSHeal", 16188, "#showtooltip Healing Wave\n/cast Nature's Swiftness\n/cast [@mouseover,help,nodead][help,nodead][@player] Healing Wave"),
      Macro("RUI EarthShock", 8042, "#showtooltip Earth Shock\n/stopcasting\n/cast Earth Shock(Rank 1)"),
      Macro("RUI Purge", 370, "#showtooltip Purge\n/cast [@mouseover,harm,nodead][@focus,harm,nodead][] Purge"),
      Macro("RUI TotemTwist", 8512, "#showtooltip Windfury Totem\n/castsequence reset=8 Windfury Totem, Grace of Air Totem"),
      Macro("RUI WeaponSync", 17364, "#showtooltip\n/cleartarget\n/targetlasttarget\n/startattack"),
      Macro("RUI TotemSet", 5675, "#showtooltip Mana Spring Totem\n/castsequence reset=30 Wrath of Air Totem, Mana Spring Totem, Stoneskin Totem, Searing Totem"),
    },
  },
  WARLOCK = {
    displayName = "Warlock",
    characterSpecific = true,
    macros = {
      Macro("RUI ManaBolt", 686, "#showtooltip Shadow Bolt\n/use Super Mana Potion\n/cast Shadow Bolt\n/cqs"),
      Macro("RUI DrainLife", 689, "#showtooltip Drain Life\n/cast Drain Life"),
      Macro("RUI Felhunter", 691, "#showtooltip Summon Felhunter\n/cast Fel Domination\n/cast Summon Felhunter(Summon)"),
      Macro("RUI TotemStomp", 19244, "#showtooltip\n/petattack Searing Totem\n/petattack Tremor Totem\n/petattack Grounding Totem"),
      Macro("RUI Banish", 710, "#showtooltip Banish\n/cast Banish\n/s Banishing %t\n/script SetRaidTarget(\"target\", 8);"),
      Macro("RUI SpellLock", 19244, "#showtooltip Spell Lock\n/cast [@mouseover,harm,nodead][@focus,harm,nodead][] Spell Lock"),
      Macro("RUI Devour", 19505, "#showtooltip Devour Magic\n/cast [@mouseover,help,nodead][@player] Devour Magic"),
      Macro("RUI Fear", 5782, "#showtooltip Fear\n/stopcasting\n/cast [@mouseover,harm,nodead][@focus,harm,nodead][] Fear"),
    },
  },
  WARRIOR = {
    displayName = "Warrior",
    characterSpecific = true,
    importNote = "Weapon-swap, Shield Wall and Spell Reflection templates contain name-of-your-... placeholders. Replace them with your actual weapon and shield names or item IDs.",
    macros = {
      Macro("RUI ShieldDual", nil, "#showtooltip\n/stopcasting\n/eq [noworn:shield] name-of-your-Shield\n/equipslot [noworn:shield] 16 name-of-your-MH\n/equipslot [worn:shield] 16 name-of-your-MH\n/equipslot [worn:shield] 17 name-of-your-OH"),
      Macro("RUI Shield2H", nil, "#showtooltip\n/stopcasting\n/eq [noworn:shield] name-of-your-Shield\n/equipslot [noworn:shield] 16 name-of-your-MH\n/eq [noworn:two-hand] name-of-your-2H"),
      Macro("RUI Charge", 100, "#showtooltip Charge\n/cast [nostance:1] Battle Stance\n/cast Charge"),
      Macro("RUI Overpower", 7384, "#showtooltip Overpower\n/cast [nostance:1] Battle Stance\n/cast Overpower"),
      Macro("RUI Intercept", 20252, "#showtooltip Intercept\n/cast [nostance:3] Berserker Stance\n/cast Intercept"),
      Macro("RUI Pummel", 6552, "#showtooltip Pummel\n/cast [nostance:3] Berserker Stance\n/cast Pummel"),
      Macro("RUI Disarm", 676, "#showtooltip Disarm\n/cast [nostance:2] Defensive Stance\n/cast Disarm"),
      Macro("RUI Intervene", 3411, "#showtooltip Intervene\n/cast [nostance:2] Defensive Stance\n/cast [@mouseover,help][] Intervene"),
      Macro("RUI ShieldWall", 871, "#showtooltip Shield Wall\n/stopcasting\n/eq [noworn:shield] name-of-your-Shield\n/equipslot [noworn:shield] 16 name-of-your-1H\n/cast [nostance:2] Defensive Stance\n/cast Shield Wall"),
      Macro("RUI SpellReflect", 23920, "#showtooltip Spell Reflection\n/stopcasting\n/eq [noworn:shield] name-of-your-Shield\n/equipslot [noworn:shield] 16 name-of-your-1H\n/cast [stance:3] Defensive Stance\n/cast Spell Reflection"),
      Macro("RUI Interrupt", 6552, "#showtooltip [nostance:2]Pummel; Shield Bash\n/use [@mouseover,harm,stance:1/2,worn:shield][stance:1/2,worn:shield]Shield Bash\n/use [noworn:shield,nostance:3]Berserker Stance\n/use [mod,@target,harm][@focus,exists,harm][@mouseover,harm][]Pummel"),
      Macro("RUI Slam", 1464, "#showtooltip Slam\n/startattack\n/stopattack\n/cast Slam\n/startattack"),
      Macro("RUI Retaliation", 20230, "#showtooltip Retaliation\n/cast [nostance:1] Battle Stance\n/cast Retaliation"),
      Macro("RUI Reckless", 1719, "#showtooltip Recklessness\n/cast [nostance:3] Berserker Stance\n/cast Recklessness"),
      Macro("RUI SunderMO", 7386, "#showtooltip Sunder Armor\n/cast [@mouseover,harm,nodead][harm] Sunder Armor"),
      Macro("RUI OverpowerMO", 7384, "#showtooltip Overpower\n/cast [@mouseover,harm,nodead][harm] Overpower"),
      Macro("RUI Ranged", 2764, "#showtooltip\n/cast [worn:thrown] Throw; [worn:bow] Shoot; [worn:gun] Shoot; [worn:crossbow] Shoot"),
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

local function CharacterMacroCapacity()
  local first, last = CharacterMacroBounds()
  return last - first + 1
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

local function DeleteRetiredMacros(package)
  if type(package) ~= "table" or type(package.obsoleteMacros) ~= "table" or type(DeleteMacro) ~= "function" then
    return 0
  end

  local deleted = 0
  for _, name in ipairs(package.obsoleteMacros) do
    local index = FindCharacterMacroByName(name)
    if index then
      local ok = pcall(DeleteMacro, index)
      if ok then deleted = deleted + 1 end
    end
  end
  return deleted
end

local function FreeCharacterMacroSlots()
  if type(GetMacroInfo) ~= "function" then return 0 end
  local first, last = CharacterMacroBounds()
  local free = 0
  for index = first, last do
    if not GetMacroInfo(index) then free = free + 1 end
  end
  return free
end

local function NeededCharacterMacroSlots(package)
  local needed = 0
  for _, definition in ipairs(package.macros or {}) do
    if not FindCharacterMacroByName(definition.name) then needed = needed + 1 end
  end
  return needed
end

local function ValidatePackage(class, package)
  if type(package) ~= "table" or type(package.macros) ~= "table" or #package.macros == 0 then
    return false, "NO " .. tostring(class or "CLASS") .. " MACRO PACKAGE"
  end
  if package.characterSpecific ~= true then
    return false, tostring(class or "Class") .. " macro package is not marked character-specific"
  end

  local capacity = CharacterMacroCapacity()
  if #package.macros > capacity then
    return false, string.format("%s PACKAGE HAS %d MACROS — CHARACTER LIMIT IS %d", tostring(class), #package.macros, capacity)
  end

  local seen = {}
  for _, definition in ipairs(package.macros) do
    if type(definition.name) ~= "string" or definition.name == "" then
      return false, tostring(class) .. " macro has no name"
    end
    if #definition.name > MACRO_NAME_LIMIT then
      return false, definition.name .. " exceeds the 16-character macro-name limit"
    end
    if seen[definition.name] then
      return false, "Duplicate macro name in " .. tostring(class) .. ": " .. definition.name
    end
    seen[definition.name] = true

    if type(definition.body) ~= "string" or definition.body == "" then
      return false, definition.name .. " has no macro body"
    end
    if #definition.body > MACRO_BODY_LIMIT then
      return false, definition.name .. " exceeds the 255-character macro-body limit"
    end
  end
  return true
end

function Macros:IsReady()
  local class, package = GetPackage()
  if not class then return false, "PLAYER CLASS NOT AVAILABLE" end
  if type(CreateMacro) ~= "function" or type(GetMacroInfo) ~= "function" then
    return false, "MACRO API NOT AVAILABLE"
  end

  local valid, validationMessage = ValidatePackage(class, package)
  if not valid then return false, validationMessage end

  local needed = NeededCharacterMacroSlots(package)
  local free = FreeCharacterMacroSlots()
  local reclaimable = 0
  if type(package.obsoleteMacros) == "table" and type(DeleteMacro) == "function" then
    for _, name in ipairs(package.obsoleteMacros) do
      if FindCharacterMacroByName(name) then reclaimable = reclaimable + 1 end
    end
  end

  if needed > (free + reclaimable) then
    return false, string.format("NEEDS %d FREE CHARACTER MACRO SLOTS — %d AVAILABLE", needed, free + reclaimable)
  end

  local message = string.format("READY — %s (%d CHARACTER-SPECIFIC MACROS)", package.displayName or class, #package.macros)
  if package.recommendedAddon and not RUI:IsAddonLoaded(package.recommendedAddon) then
    message = message .. " — DMH RECOMMENDED / NOT LOADED"
  elseif package.recommendedAddon then
    message = message .. " — DMH LOADED"
  end
  if package.postImportWarning then
    message = message .. " — POST-IMPORT EDIT REQUIRED"
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

local function ShowPostImportWarning(package)
  if type(package) ~= "table" or type(package.postImportWarning) ~= "string" or package.postImportWarning == "" then
    return
  end
  if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then return end

  local key = "RETREATUI_TBC_CLASS_MACRO_WARNING"
  StaticPopupDialogs[key] = {
    text = package.postImportWarning,
    button1 = OKAY or "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
  StaticPopup_Show(key)
end

function Macros:Import()
  if InCombatLockdown and InCombatLockdown() then
    return false, "Leave combat before importing macros."
  end

  local class, package = GetPackage()
  local valid, validationMessage = ValidatePackage(class, package)
  if not valid then return false, validationMessage end

  -- Remove only explicitly retired RetreatUI character macros. This migration
  -- never searches or deletes account-wide General Macros.
  local retired = DeleteRetiredMacros(package)

  local needed = NeededCharacterMacroSlots(package)
  local free = FreeCharacterMacroSlots()
  if needed > free then
    return false, string.format("%s needs %d free Character Specific Macro slots, but only %d are available.", package.displayName or class, needed, free)
  end

  local created, preserved = 0, 0
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

  local message = string.format("%s macros checked: %d created, %d existing macros preserved. General Macros were not modified.", package.displayName or class, created, preserved)
  if retired > 0 then
    message = message .. string.format(" Retired RetreatUI macros removed: %d.", retired)
  end
  if package.recommendedAddon and not RUI:IsAddonLoaded(package.recommendedAddon) then
    message = message .. " Install/enable Druid Macro Helper before using the DMH Haste/Sapper macros."
  end
  if package.importNote then
    message = message .. " " .. package.importNote
  end

  if created > 0 then ShowPostImportWarning(package) end
  return true, message
end
