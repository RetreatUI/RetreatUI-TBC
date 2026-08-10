local RUI = RetreatUITBC
if not RUI then return end

local PACKAGE = RUI.generalWeakAuraPackage
if not PACKAGE or type(PACKAGE.Build) ~= "function" then return end

-- Supplied CoA WeakAura coordinates from the live profile:
-- Anchor: BOTTOMRIGHT
-- To ElvUF_Player: TOPRIGHT
-- X Offset: -17
-- Y Offset: 1
local TRINKET_FRAME = "ElvUF_Player"
local TRINKET_ANCHOR = "TOPRIGHT"
local TRINKET_SELF = "BOTTOMRIGHT"
local TRINKET_X = -17
local TRINKET_Y = 1

local OriginalBuild = PACKAGE.Build
function PACKAGE:Build()
  local packageData = OriginalBuild(self)
  if type(packageData) ~= "table" or type(packageData.expected) ~= "table" then
    return packageData
  end

  local trinketId = packageData.expected.trinkets
  for _, group in ipairs(packageData.groups or {}) do
    if group.id == trinketId then
      group.anchorFrameType = "SELECTFRAME"
      group.anchorFrameFrame = TRINKET_FRAME
      group.anchorPoint = TRINKET_ANCHOR
      group.selfPoint = TRINKET_SELF
      group.xOffset = TRINKET_X
      group.yOffset = TRINKET_Y
      break
    end
  end

  packageData.expected.trinketAnchorFrame = TRINKET_FRAME
  packageData.expected.trinketAnchorPoint = TRINKET_ANCHOR
  packageData.expected.trinketSelfPoint = TRINKET_SELF
  packageData.expected.trinketX = TRINKET_X
  packageData.expected.trinketY = TRINKET_Y

  return packageData
end
