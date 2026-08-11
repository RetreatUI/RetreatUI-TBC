RetreatUITBC = { weakAuraPackages = {} }
WeakAuras = { InternalVersion = function() return 90 end }
function GetBuildInfo() return "2.5.5", "", "", 20506 end
function GetSpellInfo(id) return "Spell" .. tostring(id), nil, "Icon" .. tostring(id) end
function GetSpellTexture(id) return "Icon" .. tostring(id) end
function GetItemIcon(id) return "ItemIcon" .. tostring(id) end

dofile("RetreatUI/TBCClassData.lua")
dofile("RetreatUI/TBCClassHUD.lua")
dofile("RetreatUI/TBCClassMechanics.lua")

local classes = { "druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior" }
local totalDisplays = 0

for _, key in ipairs(classes) do
  local package = RetreatUITBC.weakAuraPackages[key]
  assert(package and type(package.Build) == "function", "missing class package: " .. key)
  local built = package:Build()
  assert(type(built) == "table", "invalid build: " .. key)
  assert(type(built.roots) == "table" and type(built.displays) == "table" and type(built.expected) == "table", "invalid package tables: " .. key)

  local roots, displays = {}, {}
  for _, root in ipairs(built.roots) do
    assert(type(root.id) == "string" and root.id ~= "", "root without id: " .. key)
    assert(not roots[root.id], "duplicate root: " .. root.id)
    roots[root.id] = root
    assert(root.anchorFrameType == "SCREEN", "class root must be screen anchored: " .. root.id)
    local expected = built.expected[root.id]
    assert(expected and root.xOffset == expected.x and root.yOffset == expected.y, "root position mismatch: " .. root.id)
  end

  for _, display in ipairs(built.displays) do
    assert(type(display.id) == "string" and display.id ~= "", "display without id: " .. key)
    assert(not displays[display.id], "duplicate display: " .. display.id)
    displays[display.id] = display
    assert(roots[display.parent], "missing parent for " .. display.id .. ": " .. tostring(display.parent))
  end

  for _, root in ipairs(built.roots) do
    for _, child in ipairs(root.controlledChildren or {}) do
      assert(displays[child], "missing controlled child: " .. child)
    end
  end

  if key == "druid" or key == "rogue" then
    local nativeCombo = false
    for _, display in ipairs(built.displays) do
      if display.id:find("Combo Points", 1, true) and display.regionType == "aurabar" then
        local trigger = display.triggers and display.triggers[1] and display.triggers[1].trigger
        if trigger and trigger.type == "unit" and trigger.event == "Power" and trigger.powertype == 4 then nativeCombo = true end
      end
    end
    assert(nativeCombo, "native combo-point trigger missing: " .. key)
  end

  if key == "warrior" then
    local gated = false
    for _, display in ipairs(built.displays) do
      if display.id:find("Shield Wall", 1, true) then
        local trigger = display.triggers and display.triggers[2] and display.triggers[2].trigger
        gated = trigger and trigger.event == "Stance/Form/Aura" and trigger.form and trigger.form.single == 2
      end
    end
    assert(gated, "Warrior stance gating missing")
  end

  if key == "warlock" then
    local correctPetLoad = false
    for _, display in ipairs(built.displays) do
      if display.id:find("Pets • Spell Lock", 1, true) then
        correctPetLoad = display.load and display.load.use_spellknown == true and display.load.spellknown == 691
      end
    end
    assert(correctPetLoad, "Warlock pet load rule missing")
  end

  totalDisplays = totalDisplays + #built.displays
end

assert(totalDisplays >= 230, "unexpectedly small class HUD inventory")
print("Class-native TBC HUD validation passed:", totalDisplays, "displays")
