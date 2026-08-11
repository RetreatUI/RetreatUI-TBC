local RUI = RetreatUITBC
if not RUI or type(RUI.OpenInstaller) ~= "function" then return end

local OriginalOpenInstaller = RUI.OpenInstaller
local function RefreshClassNativeCopy()
  local frame = _G.RetreatUITBCInstaller
  if not frame or not frame.description then return end
  local page = tonumber(frame.currentPage) or 1
  if page == 1 then
    frame.description:SetText("This installer builds the RetreatUI TBC setup one component at a time. WeakAuras and macros are matched to the current class; the class HUD now uses dedicated Resources, Main, Utility, Systems and reminder tracking instead of one generic template.")
  elseif page == 2 then
    frame.description:SetText("RetreatUI creates missing Character Specific Macros and preserves existing character-specific RUI macros exactly as edited. Legacy RUI macros previously placed in General are safely migrated with their current body and icon preserved, then the old General copy is removed.")
  elseif page == 5 then
    frame.description:SetText("RetreatUI installs only the current class package. The class-native HUD includes resources, cooldowns, utility, cast/tick systems and class mechanics; Druid and Rogue use native combo-point tracking, Shaman tracks active totems, and Warlock tracks Soul Shards.")
  end
end

function RUI:OpenInstaller(...)
  local result = OriginalOpenInstaller(self, ...)
  local frame = _G.RetreatUITBCInstaller
  if frame and not frame.__retreatClassNativeCopyHooked then
    frame.__retreatClassNativeCopyHooked = true
    if frame.next and frame.next.HookScript then frame.next:HookScript("OnClick", RefreshClassNativeCopy) end
    if frame.back and frame.back.HookScript then frame.back:HookScript("OnClick", RefreshClassNativeCopy) end
  end
  RefreshClassNativeCopy()
  return result
end
