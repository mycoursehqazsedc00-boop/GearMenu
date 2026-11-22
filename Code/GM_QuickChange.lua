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
mod.quickChange = me

me.tag = "QuickChange"
local timerSeq = 0

--[[
  Save new quick change rule

  @param (number) changeFromId
    item to switch from
  @param (number) changeToId
    item to switch to
  @param {number} delay
    time to wait before changing an item
  @return (nil)
]]--
function me.AddQuickChangeRule(changeFromId, changeToId, delay)
  local quickChangeRule = {}
  local slotId

  local changeFromName, _, _, _, _, _, _, equipFromSlot = GetItemInfo(changeFromId)
  local changeToName = GetItemInfo(changeToId)

  for _, item in pairs(GM_CONSTANTS.ITEM_CATEGORIES) do
    for i = 1, table.getn(item.type) do
      if equipFromSlot == item.type[i] then
        slotId = item.slotId
      end
    end
  end

  quickChangeRule.slotId = slotId
  quickChangeRule.changeFromName = changeFromName
  quickChangeRule.changeFromId = tonumber(changeFromId)
  quickChangeRule.changeToName = changeToName
  quickChangeRule.changeToId = tonumber(changeToId)
  quickChangeRule.changeDelay = delay

  mod.addonOptions.AddQuickChangeRule(quickChangeRule)
  -- update rule list
  mod.quickChangeMenu.QuickChangeRuleListOnUpdate()
end

--[[
  @param {number} position
]]--
function me.RemoveQuickChangeRule(position)
  mod.addonOptions.RemoveQuickChangeRule(position)
  -- update rule list
  mod.quickChangeMenu.QuickChangeRuleListOnUpdate()
end

--[[
  @param {number} slotId
]]--
function me.UpdateQuickChange(slotId)
  local quickChangeRules = mod.addonOptions.GetQuickChangeRules()

  for i = 1, table.getn(quickChangeRules) do
    if quickChangeRules[i].slotId then
      for it = 1, table.getn(quickChangeRules[i].slotId) do
        if slotId == quickChangeRules[i].slotId[it] then
          local itemId = mod.itemHelper.GetItemIdBySlot(slotId)

          if tonumber(itemId) == quickChangeRules[i].changeFromId then
            -- found a quick change rule that matches - prepare for switching
            me.SwitchItems(quickChangeRules[i], slotId)
          end
        end
      end
    end
  end
end

--[[
  Check if an items was successfully used before kicking off Quick Change

  @param {number} slotId
]]--
function me.CheckItemUse(slotId)
  local timerName = "checkItemUseStatus_" .. slotId
  -- wait a bit then check if there is a startime for the cooldown on the item
  local checkItemUseStatusCallback = function ()
    local start, duration, enable = GetInventoryItemCooldown("player", slotId)
    -- 1 meaning item has an onUse effect
    if enable == 1 and start ~= 0 then
      -- inform quick change about used item
      mod.quickChange.UpdateQuickChange(slotId)
    elseif enable == 0 then
      mod.quickChange.UpdateQuickChange(slotId)
    end

    mod.timer.DestroyTimer(timerName)
  end

  mod.timer.CreateTimer(timerName, checkItemUseStatusCallback, 0.25, false)
  mod.timer.StartTimer(timerName)
end

--[[
  Switch items for a found rule

  @param {table} rule
  @param {number} slotId
]]--
function me.SwitchItems(rule, slotId)
  timerSeq = timerSeq + 1
  local timerName = "QuickChange_" .. timerSeq

  local quickChangeSwitchCallback = function()
    -- generated one-shot timer - remove it from the pool
    mod.timer.DestroyTimer(timerName)
    mod.logger.LogDebug(me.tag, "ChangeToName: " .. tostring(rule.changeToName or "") .. " slotId: " .. slotId)
    mod.combatQueue.AddToQueue(rule.changeToId, slotId)
    -- kick off combat queue
    mod.combatQueue.ProcessQueue()
  end

  if rule.changeDelay ~= 0 then
    mod.timer.CreateTimer(timerName, quickChangeSwitchCallback, rule.changeDelay, false)
    mod.timer.StartTimer(timerName)
  else
    mod.timer.CreateTimer(timerName, quickChangeSwitchCallback, 0.25, false)
    -- start a timer before switching the item. An immediate change is blocked by the ui
    mod.timer.StartTimer(timerName) -- default delay
  end
end
