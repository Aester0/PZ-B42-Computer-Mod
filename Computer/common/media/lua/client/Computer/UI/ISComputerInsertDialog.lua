require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISInventoryPaneContextMenu"
require "Computer/Computer_Data"

ISComputerInsertDialog = ISPanel:derive("ISComputerInsertDialog")

function ISComputerInsertDialog:new(x, y, w, h, parentPanel)
  local o = ISPanel:new(x, y, w, h)
  setmetatable(o, self); self.__index = self
  o.parentPanel = parentPanel
  o.moveWithMouse = true
  o.background = true
  o.backgroundColor = {r=0, g=0, b=0, a=0.85}
  o.borderColor = {r=1, g=1, b=1, a=0.9}
  o.title = "Insert Disc"
  o.titlebarH = 30
  return o
end

function ISComputerInsertDialog:initialise()
  ISPanel.initialise(self)

  self.list = ISScrollingListBox:new(10, self.titlebarH + 6, self.width - 20, self.height - self.titlebarH - 54)
  self.list:initialise()
  self.list.itemheight = 26
  self.list.doDrawItem = function(lst, y, item, alt)
    if not item or not item.text then return y end
    local r,g,b = 1,1,1
    if lst.selected == item.index then r,g,b = 1,1,0.5 end
    lst:drawText(item.text, 8, y+6, r,g,b,1, UIFont.Small)
    return y + lst.itemheight
  end
  self:addChild(self.list)

  self.btnCancel = ISButton:new(self.width - 180, self.height - 28, 80, 22, "Cancel", self, ISComputerInsertDialog.onCancel)
  self:addChild(self.btnCancel)
  self.btnOK = ISButton:new(self.width - 90, self.height - 28, 80, 22, "Insert", self, ISComputerInsertDialog.onOK)
  self:addChild(self.btnOK)

  self:refreshInventory()
end

function ISComputerInsertDialog:prerender()
  ISPanel.prerender(self)

  -- Auto-close when player moves too far from the computer (>= 3 tiles, Chebyshev)
  local pp = self.parentPanel
  if pp and pp.playerObj and pp.worldObj and pp.worldObj.getSquare then
    local psq = pp.playerObj:getSquare()
    local csq = pp.worldObj:getSquare()
    if psq and csq then
      local dx = math.abs(psq:getX() - csq:getX())
      local dy = math.abs(psq:getY() - csq:getY())
      if math.max(dx, dy) >= 3 then
        self:removeFromUIManager()
        return
      end
    end
  end
  self:drawRect(0, 0, self.width, self.titlebarH, 1, 0.15, 0.15, 0.15)
  local tm = getTextManager()
  local tw = tm:MeasureStringX(UIFont.Small, self.title)
  local th = tm:getFontHeight(UIFont.Small)
  local tx = math.floor((self.width - tw) / 2)
  local ty = math.floor((self.titlebarH - th) / 2)
  self:drawText(self.title, tx, ty, 1,1,1,1, UIFont.Small)
  self:drawRectBorder(0, 0, self.width, self.height, 1, 1,1,1)
end

function ISComputerInsertDialog:onCancel()
  self:removeFromUIManager()
end

-- Robust removal from any source (inventory / bag / container / floor)
local function removeItemFromSource(container, item)
  if not item then return end

  -- If the item exists as a world object (on the floor), remove that representation first
  if item.getWorldItem then
    local wi = item:getWorldItem()
    if wi then
      if wi.removeFromWorld then wi:removeFromWorld() end
      if wi.removeFromSquare then wi:removeFromSquare() end
    end
  end

  -- Remove from its container (inventory, bag, furniture, corpse, floor container, etc.)
  local src = container or (item.getContainer and item:getContainer()) or nil
  if src then
    if src.Remove then src:Remove(item) end
    if isClient() and sendRemoveItemFromContainer then
      sendRemoveItemFromContainer(src, item)
    elseif src.removeItemOnServer then
      -- Fallback for MP if global isn't present
      src:removeItemOnServer(item)
    end
  end
end

function ISComputerInsertDialog:onOK()
  local sel = self.list.items and self.list.items[self.list.selected] or nil
  if not sel or not sel.item then return end
  local data = sel.item
  local playerObj = self.parentPanel and self.parentPanel.playerObj or nil
  if not playerObj then return end

  -- Remove chosen disc from its original location without cloning
  removeItemFromSource(data.container, data.itemRef)

  -- Persist in panel state (actual computer logic remains in parent panel)
  self.parentPanel.diskInserted = true
  self.parentPanel.insertedDiskType = data.fullType
  self.parentPanel.insertedDiskName = data.displayName or data.fullType
  if self.parentPanel.persistCd then self.parentPanel:persistCd() end
  if self.parentPanel.updateButtons then self.parentPanel:updateButtons() end
  if self.parentPanel.emitSound then self.parentPanel:emitSound("cd_insert") end
  self:removeFromUIManager()
end

function ISComputerInsertDialog:refreshInventory()
  self.list:clear()
  local p = self.parentPanel and self.parentPanel.playerObj or nil
  if not p then return end

  local seen = {}
  local function addIfDisc(it, cont)
    if not it or not it.getFullType then return end
    local ft = it:getFullType()
    if ft == "Computer.Disc_Game" or string.match(ft, "^Computer%.GameCD%d+") then
      local id = (it.getID and tostring(it:getID())) or tostring(it)
      if not seen[id] then
        seen[id] = true
        local label = (it.getDisplayName and it:getDisplayName()) or ft
        if ComputerData and ComputerData.stripCdPrefix then label = ComputerData.stripCdPrefix(label) end
        self.list:addItem(label, { fullType = ft, displayName = label, itemRef = it, container = cont })
      end
    end
  end

  -- All "visible" loot containers + player's own inventories
  local containerList = ISInventoryPaneContextMenu.getContainers(p)
  if containerList then
    for i = 0, containerList:size()-1 do
      local cont = containerList:get(i)
      if cont and cont.getItems then
        local items = cont:getItems()
        for n = 0, items:size()-1 do
          addIfDisc(items:get(n), cont)
        end
      end
    end
  end
end

function ISComputerInsertDialog:onClose()
  if self.parentPanel and self.parentPanel._onInsertDialogClosed then
    self.parentPanel:_onInsertDialogClosed()
  end
  self:removeFromUIManager()
end