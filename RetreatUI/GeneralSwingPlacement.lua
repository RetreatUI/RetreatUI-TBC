local RUI = RetreatUITBC
if not RUI then return end

local PACKAGE = RUI.generalWeakAuraPackage
if not PACKAGE or type(PACKAGE.Build) ~= "function" then return end

local SWING_ROOT = "RetreatUI - General — Swing Timer"

-- RetreatUI vertical HUD lanes:
-- Combo Points: center Y -118, height 8  => bottom edge -122
-- Resource:     center Y -152, height 16 => top edge    -144
-- Swing Timer grows upward from Y -141. Three 5px bars with 1px spacing
-- occupy -141..-124, leaving 3px above Resource and 2px below Combo Points.
-- In normal use only one or two timers are visible, so this is deliberately
-- validated against the worst-case three-bar stack to guarantee no overlap.
local SWING_Y = -141
local RESOURCE_CENTER_Y, RESOURCE_HEIGHT = -152, 16
local COMBO_CENTER_Y, COMBO_HEIGHT = -118, 8
local BAR_HEIGHT, BAR_SPACING, MAX_BARS = 5, 1, 3

local RESOURCE_TOP = RESOURCE_CENTER_Y + (RESOURCE_HEIGHT / 2)
local COMBO_BOTTOM = COMBO_CENTER_Y - (COMBO_HEIGHT / 2)
local STACK_HEIGHT = (BAR_HEIGHT * MAX_BARS) + (BAR_SPACING * (MAX_BARS - 1))
local SWING_BOTTOM = SWING_Y
local SWING_TOP = SWING_BOTTOM + STACK_HEIGHT
local RESOURCE_GAP = SWING_BOTTOM - RESOURCE_TOP
local COMBO_GAP = COMBO_BOTTOM - SWING_TOP

local OriginalBuild = PACKAGE.Build
function PACKAGE:Build()
  local packageData = OriginalBuild(self)
  if type(packageData) ~= "table" or type(packageData.expected) ~= "table" then
    return packageData
  end

  local swingId = packageData.expected.swing or SWING_ROOT
  for _, group in ipairs(packageData.groups or {}) do
    if group.id == swingId then
      group.yOffset = SWING_Y
      break
    end
  end

  packageData.expected.swingY = SWING_Y
  packageData.expected.swingResourceTop = RESOURCE_TOP
  packageData.expected.swingComboBottom = COMBO_BOTTOM
  packageData.expected.swingStackHeight = STACK_HEIGHT
  packageData.expected.swingBottom = SWING_BOTTOM
  packageData.expected.swingTop = SWING_TOP
  packageData.expected.swingResourceGap = RESOURCE_GAP
  packageData.expected.swingComboGap = COMBO_GAP

  return packageData
end
