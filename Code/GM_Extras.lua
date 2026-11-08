--[[
  MIT License

  Copyright (c) 2019 Michael Wiesendanger

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local mod = gm
local me = {}
mod.extras = me

me.tag = "Extras"

local DEFAULT_POINT_X = 200
local DEFAULT_POINT_Y = 400
local MIN_SCALE = 0.5
local MAX_SCALE = 2

--[[
  Apply persisted window settings (scale) and keep the window on screen
]]--
function me.ApplyWindowSettings()
  local frame = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME)

  frame:SetScale(mod.addonOptions.GetScale())
  frame:SetClampedToScreen(1)
end

--[[
  Show the window if it is hidden and hide it if it is shown
]]--
function me.ToggleMainFrame()
  if getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME):IsVisible() then
    mod.gui.HideMainFrame()
  else
    mod.gui.ShowMainFrame()
  end
end

--[[
  Use the item in a GearMenu slot. Meant to be used from macros: /gmenu use 1

  @param {string} arg
    slot position 1 - GM_CONSTANTS.ADDON_SLOTS
]]--
function me.UseSlot(arg)
  local position = tonumber(arg)

  if position == nil or position ~= math.floor(position)
    or position < 1 or position > GM_CONSTANTS.ADDON_SLOTS then
    mod.logger.Print(gm.L["name"], string.format(gm.L["use_usage"], GM_CONSTANTS.ADDON_SLOTS))
    return
  end

  if mod.itemManager.FindItemForSlotPosition(position) == nil then
    mod.logger.Print(gm.L["name"], string.format(gm.L["use_slot_inactive"], position))
    return
  end

  mod.gui.UseInventoryItem(position)
end

--[[
  Set the scale of the window

  @param {string} arg
    number between MIN_SCALE and MAX_SCALE. Without a valid number the current scale is printed
]]--
function me.SetScale(arg)
  local scale = tonumber(arg)

  if scale == nil then
    mod.logger.Print(gm.L["name"], string.format(gm.L["scale_current"], mod.addonOptions.GetScale(), MIN_SCALE, MAX_SCALE))
    return
  end

  if scale < MIN_SCALE then
    scale = MIN_SCALE
  elseif scale > MAX_SCALE then
    scale = MAX_SCALE
  end

  mod.addonOptions.SetScale(scale)
  getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME):SetScale(scale)
  mod.logger.Print(gm.L["name"], string.format(gm.L["scale_set"], scale))
end

--[[
  Enable or disable sorting of the item menu. Without argument the current state is toggled

  @param {string} arg
    on | off | nil
]]--
function me.SetSort(arg)
  local enabled

  if arg == "on" then
    enabled = true
  elseif arg == "off" then
    enabled = false
  else
    enabled = not mod.addonOptions.IsSortMenuEnabled()
  end

  mod.addonOptions.SetSortMenu(enabled)
  mod.logger.Print(gm.L["name"], string.format(gm.L["sort_state"], me.OnOff(enabled)))
end

--[[
  Move the window back to its default position (useful when it got lost)
]]--
function me.ResetPosition()
  local frame = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME)

  frame:StopMovingOrSizing()
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DEFAULT_POINT_X, DEFAULT_POINT_Y)
  frame:SetUserPlaced(true)
  mod.gui.ShowMainFrame()
  mod.logger.Print(gm.L["name"], gm.L["reset_done"])
end

--[[
  Enable or disable debug output. Only valid for the current session

  @param {string} arg
    on | off | nil (toggle)
]]--
function me.SetDebug(arg)
  local enabled

  if arg == "on" then
    enabled = true
  elseif arg == "off" then
    enabled = false
  else
    enabled = mod.logger.logLevel ~= mod.logger.debug
  end

  if enabled then
    mod.logger.logLevel = mod.logger.debug
  else
    mod.logger.logLevel = GM_ENVIRONMENT.LOG_LEVEL
  end

  mod.logger.Print(gm.L["name"], string.format(gm.L["debug_state"], me.OnOff(enabled)))
end

--[[
  Enable or disable event tracing. Only valid for the current session

  @param {string} arg
    on | off | nil (toggle)
]]--
function me.SetTrace(arg)
  local enabled

  if arg == "on" then
    enabled = true
  elseif arg == "off" then
    enabled = false
  else
    enabled = not mod.logger.logEvent
  end

  mod.logger.logEvent = enabled
  mod.logger.Print(gm.L["name"], string.format(gm.L["trace_state"], me.OnOff(enabled)))
end

--[[
  Print the current settings
]]--
function me.PrintStatus()
  local frame = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME)
  local classicApi = type(C_Item) == "table"

  DEFAULT_CHAT_FRAME:AddMessage(gm.L["info_title"] .. " " .. GM_ENVIRONMENT.ADDON_VERSION)
  DEFAULT_CHAT_FRAME:AddMessage(string.format(gm.L["status_window"],
    frame:IsVisible() and gm.L["yes"] or gm.L["no"],
    mod.addonOptions.IsWindowLocked() and gm.L["yes"] or gm.L["no"],
    mod.addonOptions.GetScale()))
  DEFAULT_CHAT_FRAME:AddMessage(string.format(gm.L["status_menu"],
    me.OnOff(mod.addonOptions.IsSortMenuEnabled()),
    mod.addonOptions.GetFilterItemQuality()))
  DEFAULT_CHAT_FRAME:AddMessage(string.format(gm.L["status_debug"],
    me.OnOff(mod.logger.logLevel == mod.logger.debug),
    me.OnOff(mod.logger.logEvent == true)))
  DEFAULT_CHAT_FRAME:AddMessage(string.format(gm.L["status_classicapi"],
    classicApi and gm.L["yes"] or gm.L["no"]))
end

--[[
  @param {boolean} value
  @return {string}
]]--
function me.OnOff(value)
  if value then
    return gm.L["enabled"]
  end

  return gm.L["disabled"]
end
