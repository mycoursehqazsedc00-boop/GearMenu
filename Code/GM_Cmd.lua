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
mod.cmd = me

me.tag = "Cmd"

--[[
  Keys of the localized command descriptions, in the order they are printed
]]--
local INFO_LINES = {
  "show", "hide", "toggle", "opt", "lock", "unlock", "use", "scale",
  "sort", "reset", "status", "debug", "trace", "reload"
}

--[[
  Print cmd options for addon
]]--
local function ShowInfoMessage()
  DEFAULT_CHAT_FRAME:AddMessage(gm.L["info_title"])

  for i = 1, table.getn(INFO_LINES) do
    DEFAULT_CHAT_FRAME:AddMessage(gm.L[INFO_LINES[i]])
  end
end

--[[
  Setup slash command handler

  /gm is intentionally NOT registered. It belongs to the game (Blizzard GM ticket) and
  registering it here hijacked that command.
]]--
function me.SetupSlashCmdList()
  SLASH_GEARMENU1 = "/gmenu"
  SLASH_GEARMENU2 = "/gearmenu"

  SlashCmdList["GEARMENU"] = function(msg)
    me.HandleCommand(msg)
  end
end

--[[
  Dispatch a slash command

  @param {string} msg
    everything that was typed after the slash command
]]--
function me.HandleCommand(msg)
  msg = msg or ""
  mod.logger.LogDebug(me.tag, "/gmenu passed argument: " .. msg)

  local _, _, cmd, arg = strfind(msg, "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  arg = string.lower(arg or "")

  if cmd == "" or cmd == "info" or cmd == "help" then
    ShowInfoMessage()
  elseif cmd == "opt" or cmd == "options" then
    mod.opt.InitOptionsMenu()
  elseif cmd == "show" then
    mod.gui.ShowMainFrame()
  elseif cmd == "hide" then
    mod.gui.HideMainFrame()
  elseif cmd == "toggle" then
    mod.extras.ToggleMainFrame()
  elseif cmd == "lock" then
    mod.addonOptions.EnableWindowLocked()
  elseif cmd == "unlock" then
    mod.addonOptions.DisableWindowLocked()
  elseif cmd == "use" then
    mod.extras.UseSlot(arg)
  elseif cmd == "scale" then
    mod.extras.SetScale(arg)
  elseif cmd == "sort" then
    mod.extras.SetSort(arg)
  elseif cmd == "reset" then
    mod.extras.ResetPosition()
  elseif cmd == "status" then
    mod.extras.PrintStatus()
  elseif cmd == "debug" then
    mod.extras.SetDebug(arg)
  elseif cmd == "trace" then
    mod.extras.SetTrace(arg)
  elseif cmd == "rl" or cmd == "reload" then
    ReloadUI()
  else
    ShowInfoMessage()
  end
end
