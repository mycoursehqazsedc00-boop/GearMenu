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
mod.gui = me

me.tag = "Gui"
me.currentSlot = 0
me.currentPosition = 0
-- collection of gathered bagged items
me.baggedItems = {}
local reflectTimerSeq = 0

--[[
  Show gearmenu mainframe
]]--
function me.ShowMainFrame()
  getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME):Show()
  if mod.addonOptions.IsSecondDockEnabled() then
    local dock2 = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME2)
    if dock2 then dock2:Show() end
  end
end

--[[
  Hide gearmenu mainframe
]]--
function me.HideMainFrame()
  getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME):Hide()
  local dock2 = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME2)
  if dock2 then dock2:Hide() end
end

--[[
  OnMouseDown callback - start dragging gearmenu mainframe
]]--
function me.DragButtonOnMouseDown()
  if mod.addonOptions.IsWindowLocked() then return end

  this:GetParent():StartMoving()
end

--[[
  OnMouseUp callback - stop dragging gearmenu mainframe
]]--
function me.DragButtonOnMouseUp()
  if mod.addonOptions.IsWindowLocked() then return end

  this:GetParent():StopMovingOrSizing()
end

--[[
  OnEnter callback - hovering itemslot
]]--
function me.ItemButtonOnEnter()
  GameTooltip_SetDefaultAnchor(getglobal(GM_CONSTANTS.ELEMENT_TOOLTIP), this)

  local position = (this and this.GetName) and mod.common.ExtractPositionFromName(this:GetName()) or nil
  local item = mod.itemManager.FindItemForSlotPosition(position)

  -- abort if no item could be found
  if item == nil then return end

  me.currentSlot = item.slotId
  me.currentPosition = position
  mod.tooltip.BuildTooltipForWornItem(item.slotId)
  me.BuildMenu()
end

--[[
  OnLeave callback - hover leave event on itemslot
]]--
function me.ItemButtonOnLeave()
  mod.tooltip.TooltipClear()
end

--[[
  Manual click on an itemslot

  @param {string} button
    clicked button RightButton | LeftButton
]]--
function me.ItemButtonOnClick(button)
  local name = this:GetName()
  local item = mod.itemManager.FindItemForSlotPosition(mod.common.ExtractPositionFromName(name))

  -- abort if no item could be found
  if item == nil then return end

  if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
    this:SetChecked(0)
    local link = GetInventoryItemLink("player", item.slotId)
    if link then
      ChatFrameEditBox:Insert(link)
    end
    return
  end

  if button == "RightButton" then
    -- rightclick
    mod.combatQueue.RemoveFromQueue(item.slotId)
    -- reflect item not in use
    this:SetChecked(0)
  else
    -- leftclick
    UseInventoryItem(item.slotId)
    mod.quickChange.CheckItemUse(item.slotId)
    me.ReflectItemUse(mod.common.ExtractPositionFromName(name))
  end
end

--[[
  Allow for drag an drop on itemslots

  Normal item switches work on a stock client. The edge case where an offhand item is
  dropped while a twohanded weapon is equiped needs GetCursorInfo() which only exists with
  ClassicAPI. Without it the drop behaves exactly like upstream.

  Another reason a switch will not work is because it is not possible to unequip
  the current item without overwriting the cursor. That is why the item is put back
  into the bags first and then switched with the regular (unequip aware) code path.
]]--
function me.ItemButtonOnReceiveDrag()
  -- abort if drag and drop is disabled
  if mod.addonOptions.IsDragAndDropDisabled() then return end

  local position = (this and this.GetName) and mod.common.ExtractPositionFromName(this:GetName()) or nil
  local item = mod.itemManager.FindItemForSlotPosition(position)

  -- abort if no item could be found
  if item == nil then return end

  if me.HandleTwoHandOffhandDrop(item.slotId) then return end

  local validItemForSlot = CursorCanGoInSlot(item.slotId)

  if validItemForSlot == nil then
    mod.logger.LogInfo(me.tag, "Invalid item for slotId - " .. item.slotId)
    ClearCursor() -- clear cursor from item
  else
    EquipCursorItem(item.slotId)
  end
end

--[[
  Optional ClassicAPI path: an offhand capable item from the bags is dropped on the offhand
  slot while a twohanded weapon is equiped. Returns true when the drop was handled.

  GetCursorInfo() returns "item", itemID, itemLink for an item on the cursor.

  @param {number} slotId
  @return {boolean}
]]--
function me.HandleTwoHandOffhandDrop(slotId)
  if slotId ~= GM_CONSTANTS.ITEMS.OFFHAND.slotId or GetCursorInfo == nil then
    return false
  end

  local kind, itemId = GetCursorInfo()

  if kind ~= "item" or itemId == nil then return false end

  local _, _, wornType = mod.itemHelper.RetrieveItemInfo(GM_CONSTANTS.ITEMS.MAINHAND.slotId)

  if wornType ~= "INVTYPE_2HWEAPON" then return false end

  local _, _, _, _, _, _, _, equipSlot = GetItemInfo(itemId)

  if equipSlot ~= "INVTYPE_SHIELD" and equipSlot ~= "INVTYPE_WEAPON"
    and equipSlot ~= "INVTYPE_WEAPONOFFHAND" and equipSlot ~= "INVTYPE_HOLDABLE" then
    return false
  end

  -- only handle items that are in the bags, they are returned to their place by ClearCursor
  local _, bagNumber = mod.itemHelper.FindItemById(itemId, true)

  if bagNumber == nil then return false end

  ClearCursor()
  mod.itemHelper.EquipItemById(itemId, slotId, equipSlot)

  return true
end

--[[
  Allow drag and drop from one itemslot to another
  (only useful for fast trinketswitch or putting an item in the bag)
]]--
function me.ItemButtonOnDragStart()
  -- abort if drag and drop is disabled
  if mod.addonOptions.IsDragAndDropDisabled() then return end

  local position = (this and this.GetName) and mod.common.ExtractPositionFromName(this:GetName()) or nil
  local item = mod.itemManager.FindItemForSlotPosition(position)

  -- abort if no item could be found
  if item == nil then return end

  PickupInventoryItem(item.slotId)
end

--[[
  OnEnter callback - hovering itemslot for bagged items
]]--
function me.MenuItemOnEnter()
  GameTooltip_SetDefaultAnchor(getglobal(GM_CONSTANTS.ELEMENT_TOOLTIP), this)

  mod.tooltip.BuildTooltipForBaggedItem(this:GetID(), me.baggedItems)
end

--[[
  OnLeave callback - hover leave event on itemslot for bagged items
]]--
function me.MenuItemOnLeave()
  mod.tooltip.TooltipClear()
end

--[[
  Choosing an item in slotframe
]]--
function me.MenuItemOnClick()
  local entry = me.baggedItems[this:GetID()]
  if not entry then return end

  if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
    this:SetChecked(0)
    local link = GetContainerItemLink(entry.bag, entry.slot)
    if link then
      ChatFrameEditBox:Insert(link)
    end
    return
  end

  mod.itemHelper.EquipItemById(
    entry.id,
    me.currentSlot,
    entry.equipSlot
  )
  getglobal(GM_CONSTANTS.ELEMENT_SLOT_FRAME):Hide()
end

--[[
  Callback for keybindings

  @param {number} position
]]
function me.UseInventoryItem(position)
  local item = mod.itemManager.FindItemForSlotPosition(position)

  -- abort if no item could be found
  if item == nil then
    mod.logger.LogInfo(me.tag, "Unable to use item - item is deactivated")
    return
  end

  -- check if slot has an equiped item
  local _, id, _ = mod.itemHelper.RetrieveItemInfo(item.slotId)

  if not id then
    me.ReflectItemUse(position)
    return
  end

  mod.logger.LogDebug(me.tag, "Using item: " .. item.slotId)

  UseInventoryItem(item.slotId) -- use item
  mod.quickChange.CheckItemUse(item.slotId)
  me.ReflectItemUse(position)
end

--[[
  Reflect the item use on a specific slot by its position

  @param {number} position
]]--
function me.ReflectItemUse(position)
  -- reflect item use
  getglobal(GM_CONSTANTS.ELEMENT_SLOT .. position):SetChecked(1)
  --[[
    Remove checked status from all buttons
  ]]
  reflectTimerSeq = reflectTimerSeq + 1
  local timerName = "ReflectItemUse_" .. reflectTimerSeq

  local reflectItemUseCallback = function()
    getglobal(GM_CONSTANTS.ELEMENT_SLOT .. position):SetChecked(0)
    -- generated one-shot timer - remove it from the pool
    mod.timer.DestroyTimer(timerName)
  end

  mod.timer.CreateTimer(timerName, reflectItemUseCallback, .25, false)
  mod.timer.StartTimer(timerName)
end

--[[
  Build menu for item selection
]]--
function me.BuildMenu()
  -- clear out all item buttons
  for i = 1, 30 do
    getglobal(GM_CONSTANTS.ELEMENT_MENU_ITEM .. i):Hide()
  end

  me.baggedItems = {}

  local position = (this and this.GetName) and mod.common.ExtractPositionFromName(this:GetName()) or nil

  -- if buildmenu is called manualy position is retrieved from cached position
  if position == nil then
    if me.currentPosition == 0 then
      return
    else
      position = me.currentPosition
    end
  end

  local item = mod.itemManager.FindItemForSlotPosition(tonumber(position))

  -- abort if no item could be found
  if item == nil then return end

  mod.logger.LogDebug(me.tag, "Building menu for slotId: " .. item.slotId)
  me.baggedItems, _ = mod.itemManager.GetItemsForSlotId(item.slotId)

  if table.getn(me.baggedItems) < 1 then
    -- user has no bagged item of this specific type
    getglobal(GM_CONSTANTS.ELEMENT_SLOT_FRAME):Hide()
  else
    local row = 0
    local maxRows = 2 -- width of 2 items
    local col = 0
    local xPos = 8
    local yPos = 8

    local count = math.min(table.getn(me.baggedItems), 30)
    for i = 1, count do
      local item = getglobal(GM_CONSTANTS.ELEMENT_MENU_ITEM .. i)
      item:SetChecked(0)
      getglobal(GM_CONSTANTS.ELEMENT_MENU_ITEM .. i .. "Icon"):SetTexture(me.baggedItems[i].texture)

      if math.mod(i, 2) ~= 0 then
        row = 0 -- left row
        if (mod.addonOptions.IsWindowLocked()) then
          yPos = col * GM_CONSTANTS.INTERFACE_SLOT_SPACE + GM_CONSTANTS.INTERFACE_ZERO_MARGIN
        else
          yPos = col * GM_CONSTANTS.INTERFACE_SLOT_SPACE + GM_CONSTANTS.INTERFACE_DEFAULT_MARGIN
        end
        xPos = row * GM_CONSTANTS.INTERFACE_SLOT_SPACE + GM_CONSTANTS.INTERFACE_DEFAULT_MARGIN
        -- special case for uneven numberOfItems, add 1 col
        if i == count then
          col = col + 1
        end
      else
        row = 1 -- right row
        if (mod.addonOptions.IsWindowLocked()) then
          yPos = col * GM_CONSTANTS.INTERFACE_SLOT_SPACE + GM_CONSTANTS.INTERFACE_ZERO_MARGIN
        else
          yPos = col * GM_CONSTANTS.INTERFACE_SLOT_SPACE + GM_CONSTANTS.INTERFACE_DEFAULT_MARGIN
        end
        xPos = row * GM_CONSTANTS.INTERFACE_SLOT_SPACE + GM_CONSTANTS.INTERFACE_DEFAULT_MARGIN
        col = col + 1
      end

      item:SetPoint("BOTTOMLEFT", GM_CONSTANTS.ELEMENT_SLOT_FRAME, xPos, yPos)
      item:Show()
    end

    local frame = getglobal(GM_CONSTANTS.ELEMENT_SLOT_FRAME)
    frame:ClearAllPoints()

    -- anchor swap menu based on configured direction for this slot's dock
    local slotAnchor = GM_CONSTANTS.ELEMENT_SLOT .. position
    local slotObj = getglobal(slotAnchor)
    local dock2 = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME2)
    local dockAnchor = (slotObj and slotObj:GetParent()) or getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME)
    local menuPos = (dock2 and dockAnchor == dock2) and mod.addonOptions.GetMenuPosition2() or mod.addonOptions.GetMenuPosition()
    if menuPos == "BOTTOM" then
      frame:SetPoint("TOPLEFT", slotAnchor, "BOTTOMLEFT", GM_CONSTANTS.INTERFACE_DEFAULT_NEGATIVE_MARGIN, -10)
    elseif menuPos == "LEFT" then
      frame:SetPoint("BOTTOMRIGHT", dockAnchor, "BOTTOMLEFT", 0, 0)
    elseif menuPos == "RIGHT" then
      frame:SetPoint("BOTTOMLEFT", dockAnchor, "BOTTOMRIGHT", 0, 0)
    else
      frame:SetPoint("BOTTOMLEFT", slotAnchor,
        GM_CONSTANTS.INTERFACE_DEFAULT_NEGATIVE_MARGIN, GM_CONSTANTS.INTERFACE_SLOT_SPACE)
    end

    if col == 0 then
      col = 1
    end

    getglobal(GM_CONSTANTS.ELEMENT_SLOT_FRAME):SetWidth(12 + (maxRows * GM_CONSTANTS.INTERFACE_SLOT_SPACE))
    getglobal(GM_CONSTANTS.ELEMENT_SLOT_FRAME):SetHeight(12 + ((col) * GM_CONSTANTS.INTERFACE_SLOT_SPACE))
    getglobal(GM_CONSTANTS.ELEMENT_SLOT_FRAME):Show()

    local callback = function()
      mod.cooldown.UpdateCooldownForBaggedItems(me.baggedItems)
    end

    -- initial manual setting of cooldown timer
    mod.cooldown.UpdateCooldownForBaggedItems(me.baggedItems)

    mod.timer.CreateTimer("BaggedItemCooldownUpdate", callback, .25, true)
    mod.timer.StartTimer("BaggedItemCooldownUpdate")
    mod.timer.StartTimer("MenuMouseover")
  end
end

--[[
  Close slot frame after a delay
]]--
function me.SlotFrameMouseOver()
  local dock2 = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME2)
  local overDock2 = dock2 and dock2:IsVisible() and MouseIsOver(dock2)
  if (not MouseIsOver(getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME))) and (not overDock2) and (not MouseIsOver(getglobal(GM_CONSTANTS.ELEMENT_SLOT_FRAME))) then
    mod.timer.StopTimer("BaggedItemCooldownUpdate")
    mod.timer.StopTimer("MenuMouseover")
    getglobal(GM_CONSTANTS.ELEMENT_SLOT_FRAME):Hide()
  end
end

--[[
  Load slotpositions on addon load
]]--
function me.LoadSlotPositions()
  for _, item in pairs(GM_CONSTANTS.ITEMS) do
    if mod.addonOptions.IsItemDisabled(item.name) then
      -- If the item has no position disable it
      mod.itemManager.DisableItem(item.slotId)
    else
      -- Overwrite initial registered position with actual position
      mod.itemManager.EnableItem(item.slotId, mod.addonOptions.GetItemSlotPosition(item.name))
    end
  end

  for i = 1, GM_CONSTANTS.ADDON_SLOTS do
    local item = mod.itemManager.FindItemForSlotPosition(i)

    if item == nil then
      mod.logger.LogDebug(me.tag, "Itemslot" .. i .. " is inactive")
      me.HideSlot(i)
    else
      me.ShowSlot(i)
    end
  end

  -- reflect items that are worn
  mod.itemManager.UpdateWornItems()
end

--[[
  Rearrange slotpositions after activating or deactivating a slot
]]--
function me.RearrangeSlotPositions()
  local mainFrame = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME)
  local dock2 = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME2)
  local secondDockEnabled = mod.addonOptions.IsSecondDockEnabled()

  local count1 = 0
  local count2 = 0

  for index = 1, GM_CONSTANTS.ADDON_SLOTS do
    local slotFrame = getglobal(GM_CONSTANTS.ELEMENT_SLOT .. index)
    if slotFrame and slotFrame:IsShown() then
      local useDock2 = secondDockEnabled and dock2 and (mod.addonOptions.GetSlotDock(index) == 2)
      local parentDock = useDock2 and dock2 or mainFrame
      local posIdx = useDock2 and count2 or count1

      slotFrame:SetParent(parentDock)
      slotFrame:ClearAllPoints()
      slotFrame:SetPoint("TOPLEFT", parentDock, "TOPLEFT",
        GM_CONSTANTS.INTERFACE_DEFAULT_MARGIN + (GM_CONSTANTS.INTERFACE_SLOT_SPACE * posIdx),
        GM_CONSTANTS.INTERFACE_DEFAULT_NEGATIVE_MARGIN)

      if useDock2 then
        count2 = count2 + 1
      else
        count1 = count1 + 1
      end
    end
  end

  if count1 == 0 then count1 = 1 end
  mainFrame:SetWidth(GM_CONSTANTS.INTERFACE_DEFAULT_MARGIN
    + (GM_CONSTANTS.INTERFACE_SLOT_SPACE * count1) + 4)

  if dock2 then
    if secondDockEnabled then
      if count2 == 0 then count2 = 1 end
      dock2:SetWidth(GM_CONSTANTS.INTERFACE_DEFAULT_MARGIN
        + (GM_CONSTANTS.INTERFACE_SLOT_SPACE * count2) + 4)
      if mainFrame:IsVisible() then
        dock2:Show()
      else
        dock2:Hide()
      end
    else
      dock2:Hide()
    end
  end
end

--[[
  Show slot

  @param {number} position
]]--
function me.ShowSlot(position)
  local frame = getglobal(GM_CONSTANTS.ELEMENT_SLOT .. position)
  frame:Show()

  -- recalculate slot positioning
  me.RearrangeSlotPositions()
end

--[[
  Hide slot

  @param {number} position
]]--
function me.HideSlot(position)
  local frame = getglobal(GM_CONSTANTS.ELEMENT_SLOT .. position)
  frame:Hide()
  -- recalculate slot positioning
  me.RearrangeSlotPositions()
end

--[[
  Show keybindings for all registered items
]]--
function me.ShowKeyBindings()
  for i = 1, GM_CONSTANTS.ADDON_SLOTS do
    if mod.addonOptions.IsShowKeyBindingsEnabled() then
      local binding = getglobal(GM_CONSTANTS.ELEMENT_SLOT .. i .. "HotKey")
      binding:SetText(GetBindingText(GetBindingKey("Slot " .. i), "KEY_", 1))
    end
  end
end

--[[
  Hide keybindings for all registered items
]]--
function me.HideKeyBindings()
  for i = 1, GM_CONSTANTS.ADDON_SLOTS do
    local binding = getglobal(GM_CONSTANTS.ELEMENT_SLOT .. i .. "HotKey")
    binding:SetText("")
  end
end

--[[
  Hide cooldowns for both bagged and worn items
]]--
function me.HideCooldowns()
  -- hide slot cooldowns
  for i = 1, GM_CONSTANTS.ADDON_SLOTS do
    local frame = getglobal(GM_CONSTANTS.ELEMENT_SLOT .. i .. "Time")
    frame:Hide()
  end

  -- hide bagged items cooldown
  for i = 1, 30 do
    local frame = getglobal(GM_CONSTANTS.ELEMENT_MENU_ITEM .. i .. "Time")
    frame:Hide()
  end
end

--[[
  Show cooldowns for both bagged and worn items
]]--
function me.ShowCooldowns()
  -- show slot cooldowns
  for i = 1, GM_CONSTANTS.ADDON_SLOTS do
    local frame = getglobal(GM_CONSTANTS.ELEMENT_SLOT .. i .. "Time")
    frame:Show()
  end

  -- show bagged items cooldown
  for i = 1, 30 do
    local frame = getglobal(GM_CONSTANTS.ELEMENT_MENU_ITEM .. i .. "Time")
    frame:Show()
  end
end
