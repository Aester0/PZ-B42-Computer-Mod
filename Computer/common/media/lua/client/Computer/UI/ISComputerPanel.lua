require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "Computer/UI/ISComputerInsertDialog"
require "Computer/Computer_Data"
require "Computer/Jobs/Computer_Jobs"
require "Computer/Computer_Light"
require "luautils"
require "Computer/TA/ISComputerPlayAction"
require "Computer/TA/ISComputerActivateAction"

ISComputerPanel = ISPanel:derive("ISComputerPanel")

-- power check (hydro, square flag, or generator)
function ISComputerPanel:hasPower()
  local obj = self.worldObj
  if not obj or not obj.getSquare then return false end
  local sq = obj:getSquare()
  if not sq then return false end

  local hydro = false
  if getWorld and getWorld().isHydroPowerOn then
    hydro = getWorld():isHydroPowerOn() and true or false
  end

  local sqElec = false
  if sq.haveElectricity then
    local ok = sq:haveElectricity()
    sqElec = (ok == true)
  end

  local genOk = false
  if sq.getGenerator then
    local gen = sq:getGenerator()
    if gen and gen.isActivated and gen:isActivated()
      and gen.isConnected and gen:isConnected()
      and gen.getFuel and gen:getFuel() > 0 then
      genOk = true
    end
  end

  return hydro or sqElec or genOk
end

-- 3D sound helper (from computer, fallback player)
function ISComputerPanel:emitSound(name)
  if not name then return end
  local obj = self.worldObj
  if obj and obj.playSound then
    obj:playSound(name)
  elseif self.playerObj and self.playerObj.playSound then
    self.playerObj:playSound(name)
  end
end

-- small helper to queue proximity activation and run a callback when adjacent
function ISComputerPanel:queueActivate(fn)
  if not (self.worldObj and self.worldObj.getSquare) then return end
  local sq = self.worldObj:getSquare()
  if not sq then return end
  if luautils and luautils.walkAdj then luautils.walkAdj(self.playerObj, sq) end
  local action = ISComputerActivateAction:new(self.playerObj, self, self.worldObj, fn)
  ISTimedActionQueue.add(action)
end

-- Persist CD state for dialog
function ISComputerPanel:persistCd()
  if not self.worldObj or not self.worldObj.getModData then return end

function ISComputerPanel:_syncCdFromMd()
  if not self.worldObj or not self.worldObj.getModData then return false end
  local md = self.worldObj:getModData()
  md.computerData = md.computerData or {}
  local t = md.computerData.cdDiskType
  local n = md.computerData.cdDiskName
  local open = md.computerData.cdOpen and true or false
  local changed = false
  if self.insertedDiskType ~= t then self.insertedDiskType = t; changed = true end
  if self.insertedDiskName ~= n then self.insertedDiskName = n; changed = true end
  if self.cdOpen ~= open then self.cdOpen = open; changed = true end
  local hasDisk = (self.insertedDiskType ~= nil)
  if (self.diskInserted and (not hasDisk)) or ((not self.diskInserted) and hasDisk) then
    self.diskInserted = hasDisk; changed = true
  end
  return changed
end

  local md = self.worldObj:getModData()
  md.computerData = md.computerData or {}
  md.computerData.cdOpen = self.cdOpen and true or false
  md.computerData.cdDiskType = self.insertedDiskType
  md.computerData.cdDiskName = self.insertedDiskName
  if self.worldObj.transmitModData then self.worldObj:transmitModData() end
end

function ISComputerPanel:forcePowerOff()
  if not self.isOn then if self.closeBtn and self.closeBtn.setEnable then self.closeBtn:setEnable(true) end
    return end
  self.isOn = false
  if ComputerMod and ComputerMod.setComputerOn then
    ComputerMod.setComputerOn(self.worldObj, false)
  else
    local md = self.worldObj and self.worldObj:getModData() or nil
    if md then
      md.Computer_On = false
      if self.worldObj.transmitModData then self.worldObj:transmitModData() end
    end
  end
  self:updateButtons()
end

function ISComputerPanel:new(x, y, w, h, playerObj, worldObj)
  local o = ISPanel:new(x, y, w, h)
  setmetatable(o, self)
  self.__index = self
  o.playerObj = playerObj
  o.playerIndex = playerObj and playerObj:getPlayerNum() or 0
  o.worldObj  = worldObj
  o.moveWithMouse = true
  o.background = true
  o.backgroundColor = { r=0, g=0, b=0, a=0.85 }
  o.borderColor = { r=1, g=1, b=1, a=1 }
  o.title = "Computer"
  o.rightTitle = "Installed Games:"
  o.titlebarH = 30
  o.isOn = false
  o.cdOpen = false
  o.diskInserted = false
  o.insertedDiskType = nil
  o.insertedDiskName = nil
  -- cache
  o._lastPower = nil
  o._lastSelected = -1
  o._hadJob = false
  o._dotT = 0
  o._dotN = 0
  -- TA state
  o.activeAction = nil
  o.activeActionType = nil
  return o
end

function ISComputerPanel:initialise()
  ISPanel.initialise(self)

  local margin, gap, btnH = 10, 12, 28
  local leftW = 160
  local rightHeaderH = 28
  self._layout = {
    leftX = margin,
    leftY = self.titlebarH + margin,
    leftW = leftW,
    btnH = btnH,
    gap = gap,
    rightX = margin + leftW + margin,
    rightY = self.titlebarH + margin,
    rightW = self.width - (margin + leftW + margin*2),
    rightH = self.height - (self.titlebarH + margin*2),
    rightHeaderH = rightHeaderH,
  }

  if not self.closeBtn then
    self.closeBtn = ISButton:new(6, 6, 24, 24, "X", self, function() self:onClose() end)
    self.closeBtn.borderColor = {r=1, g=1, b=1, a=0.6}
    self.closeBtn:initialise()
    self:addChild(self.closeBtn)
  end

  local x, y = self._layout.leftX, self._layout.leftY
  self.btnPower = ISButton:new(x, y, leftW, btnH, "On", self, function() self:onTogglePower() end)
  self.btnPower:initialise(); self:addChild(self.btnPower); y = y + btnH + gap

  self.btnCd = ISButton:new(x, y, leftW, btnH, "Open CD-Rom", self, function() self:onToggleCD() end)
  self.btnCd:initialise(); self:addChild(self.btnCd); y = y + btnH + gap

  self.btnInsert = ISButton:new(x, y, leftW, btnH, "Insert Disc", self, function() self:onInsertDisk() end)
  self.btnInsert:initialise(); self:addChild(self.btnInsert); y = y + btnH + gap

  self.btnEject = ISButton:new(x, y, leftW, btnH, "Eject Disc", self, function() self:onEjectDisk() end)
  self.btnEject:initialise(); self:addChild(self.btnEject); y = y + btnH + gap

  self.btnInstall = ISButton:new(x, y, leftW, btnH, "Install", self, function() self:onInstallFromDisk() end)
  self.btnInstall:initialise(); self:addChild(self.btnInstall); y = y + btnH + gap

  self.btnUninstall = ISButton:new(x, y, leftW, btnH, "Uninstall", self, function() self:onRemoveSelected() end)
  self.btnUninstall:initialise(); self:addChild(self.btnUninstall); y = y + btnH + gap

  self.btnPlay = ISButton:new(x, y, leftW, btnH, "Play", self, function() self:onPlay() end)
  self.btnPlay:initialise(); self:addChild(self.btnPlay)

  -- Status (top) and Memory (bottom) bars under Play button
  do
    local x2 = self._layout.leftX
    local gap2 = self._layout.gap or 12
    local leftW2 = self._layout.leftW or 160
    local y2 = self.btnPlay.y + self.btnPlay.height + gap2 * 3

    self._ui = self._ui or {}
    -- STATUS first (taller for text)
    self._ui.status = { x = x2, y = y2, w = leftW2, h = 24 }
    -- tight spacing between bars
    y2 = y2 + 24 + 4
    -- MEMORY second (a bit taller too)
    self._ui.memory = { x = x2, y = y2, w = leftW2, h = 22 }
  end

  -- Right list (with header)
  self.list = ISScrollingListBox:new(
    self._layout.rightX, self._layout.rightY + self._layout.rightHeaderH,
    self._layout.rightW, self._layout.rightH - self._layout.rightHeaderH
  )
  self.list:initialise()
  self.list.itemheight = 24
  self.list.doDrawItem = function(lst, y3, item, alt)
    if not item or not item.text then return y3 end
    local r, g, b = 1, 1, 1
    if lst.selected == item.index then r, g, b = 1, 1, 0.5 end
    lst:drawText(item.text, 8, y3+6, r, g, b, 1, UIFont.Small)
    return y3 + lst.itemheight
  end
  self:addChild(self.list)

  -- restore states
  local md = self.worldObj and self.worldObj:getModData() or nil
  if md and md.Computer_On ~= nil then self.isOn = md.Computer_On and true or false end
  if md then
    md.computerData = md.computerData or {}
    if md.computerData.cdOpen ~= nil then self.cdOpen = md.computerData.cdOpen and true or false end
    if md.computerData.cdDiskType then
      self.diskInserted = true
      self.insertedDiskType = md.computerData.cdDiskType
      self.insertedDiskName = md.computerData.cdDiskName or "Game Disc"
    end
  end

  if not self:hasPower() and self.isOn then self:forcePowerOff() end

  ComputerJobs.ensureTracking(self.worldObj)
  ComputerData.populateListUI(self.worldObj, self.list)
  ComputerLight.refresh(self.worldObj)
  self:updateButtons()
end

-- is installed helper (distinct by fullType + name)
function ISComputerPanel:isInstalled(fullType, name)
  if not (fullType and self.list and self.list.items) then return false end
  for i=1, #self.list.items do
    local it = self.list.items[i]
    if it and it.item and it.item.id == fullType then
      if (not name) or (it.item.name == name) then return true end
    end
  end
  return false
end

function ISComputerPanel:updateButtons()
  if self._syncCdFromMd and self:_syncCdFromMd() then end
  local powerOK = self:hasPower()
  local job = ComputerJobs.getJob(self.worldObj)
  local _capMax = (ComputerData and ComputerData.MAX_GAMES) and ComputerData.MAX_GAMES or 20
  local _capCnt = (ComputerData and ComputerData.countInstalled and ComputerData.countInstalled(self.worldObj)) or ((self.list and self.list.items) and #self.list.items or 0)
  local _atCap = _capCnt >= _capMax

  -- selection present?
  local hasSelection = false
  if self.list and self.list.selected ~= nil and self.list.selected ~= -1 and self.list.items then
    local sel = self.list.items[self.list.selected]
    hasSelection = (sel ~= nil and sel.item ~= nil)
  end

  -- lock all during uninstall/tray
  if job and (job.type == "uninstall" or job.type == "tray") then
    local all = { self.btnPower, self.btnCd, self.btnInsert, self.btnEject, self.btnInstall, self.btnUninstall, self.btnPlay }
    for _, b in ipairs(all) do
      if b and b.setEnable then b:setEnable(false) end
    end
    if self.closeBtn and self.closeBtn.setEnable then self.closeBtn:setEnable(true) end
    return
  end
if not powerOK then
    self.btnPower:setTitle(self.isOn and "Off" or "On")
    if self.btnPower and self.btnPower.setEnable then self.btnPower:setEnable(false) end
    if self.btnCd and self.btnCd.setEnable then self.btnCd:setEnable(false) end
    if self.btnInsert and self.btnInsert.setEnable then self.btnInsert:setEnable(false) end
    if self.btnEject and self.btnEject.setEnable then self.btnEject:setEnable(false) end
    if self.btnInstall and self.btnInstall.setEnable then self.btnInstall:setEnable(false) end
    if self.btnUninstall and self.btnUninstall.setEnable then self.btnUninstall:setEnable(false) end
    if self.btnPlay and self.btnPlay.setEnable then self.btnPlay:setEnable(false) end
    if self.closeBtn and self.closeBtn.setEnable then self.closeBtn:setEnable(true) end
    if self.closeBtn and self.closeBtn.setEnable then self.closeBtn:setEnable(true) end
    return
  end

  self.btnPower:setTitle(self.isOn and "Off" or "On")
  self.btnCd:setTitle(self.cdOpen and "Close CD-Rom" or "Open CD-Rom")

  if not self.isOn then
    self.btnPower:setEnable(true)
    self.btnCd:setEnable(false)
    self.btnInsert:setEnable(false)
    self.btnEject:setEnable(false)
    self.btnInstall:setEnable(false)
    self.btnUninstall:setEnable(false)
    self.btnPlay:setEnable(false)
    if self.closeBtn and self.closeBtn.setEnable then self.closeBtn:setEnable(true) end
    return
  end

  -- powered & on
  self.btnPower:setEnable(true)
  self.btnCd:setEnable(true)
  local j = job

  if j and j.type == "install" then
    self.btnInstall:setTitle("Cancel")
    self.btnInstall.onclick = function() self:onCancelInstall() end
    self.btnInstall:setEnable(true)
    self.btnCd:setEnable(false)
    self.btnInsert:setEnable(false)
    self.btnEject:setEnable(false)
    self.btnUninstall:setEnable(false)
    self.btnPlay:setEnable(false)
  elseif self.activeActionType == "play" then
    self.btnInstall:setTitle("Install")
    self.btnInstall.onclick = function() self:onInstallFromDisk() end
    self.btnInstall:setEnable(false)
    self.btnCd:setEnable(false)
    self.btnInsert:setEnable(false)
    self.btnEject:setEnable(false)
    self.btnUninstall:setEnable(false)
    self.btnPlay:setTitle("Cancel")
    self.btnPlay.onclick = function() self:onCancelPlay() end
    self.btnPlay:setEnable(true)
  else
    self.btnInstall:setTitle("Install")
    self.btnInstall.onclick = function() self:onInstallFromDisk() end
    local allowInstall = (not self.cdOpen) and self.diskInserted and (not self:isInstalled(self.insertedDiskType, self.insertedDiskName)) and (j == nil)
    self.btnInsert:setEnable(self.cdOpen and (not self.diskInserted))
    self.btnEject:setEnable(self.cdOpen and self.diskInserted)
    if _atCap then
      allowInstall = false
    end
    self.btnInstall:setEnable(allowInstall)
    self.btnUninstall:setEnable(hasSelection and (j == nil))
    self.btnPlay:setTitle("Play")
    self.btnPlay.onclick = function() self:onPlay() end
    self.btnPlay:setEnable(hasSelection and (j == nil))
  end
end

-- Internal do-ops (what actually happens once adjacent)
function ISComputerPanel:_doTogglePower()
  if not self:hasPower() then return end
  local wasOn = self.isOn and true or false
  self.isOn = not self.isOn
  if ComputerMod and ComputerMod.setComputerOn then
    ComputerMod.setComputerOn(self.worldObj, self.isOn)
  else
    local md = self.worldObj and self.worldObj:getModData() or nil
    if md then
      md.Computer_On = self.isOn
      if self.worldObj.transmitModData then self.worldObj:transmitModData() end
    end
  end
  self:emitSound("pc_power_button_click")
  if self.isOn then
    self:emitSound("pc_power_on")
    self:emitSound("computeron")
  else
    self:emitSound("computeroff")
  end
  ComputerLight.refresh(self.worldObj)
  self:updateButtons()
end

function ISComputerPanel:_doToggleCD()
  if not (self.isOn and self:hasPower()) then return end
  local job = ComputerJobs.getJob(self.worldObj)
  if job then return end
  local desired = self.cdOpen and "close" or "open"
  if desired == "open" then self:emitSound("cd_tray_open") else self:emitSound("cd_tray_close") end
  ComputerJobs.startTray(self.worldObj, desired, 2.0)
  self:updateButtons()
  ComputerLight.refresh(self.worldObj)
end

function ISComputerPanel:_doInsertDisk()
  if not (self.isOn and self.cdOpen and self:hasPower() and (not self.diskInserted)) then return end
  local dlg = ISComputerInsertDialog:new(self.x + 30, self.y + 60, 360, 300, self)
  dlg:initialise()
  dlg:addToUIManager()
end

function ISComputerPanel:_doEjectDisk()
  if not (self.cdOpen and self.diskInserted) then return end
  local p = self.playerObj
  if p and self.insertedDiskType then
    local inv = p:getInventory()
    if inv then
      local newItem = inv:AddItem(self.insertedDiskType)
      if newItem and self.insertedDiskName then
        pcall(function() if newItem.setName then newItem:setName(self.insertedDiskName) end end)
        pcall(function() if newItem.setCustomName then newItem:setCustomName(true) end end)
      end
    end
  end
  self.diskInserted = false
  self.insertedDiskType = nil
  self.insertedDiskName = nil
  self:persistCd()
  self:updateButtons()
end

function ISComputerPanel:_doCancelInstall()
  ComputerJobs.cancel(self.worldObj)
  self:updateButtons()
end

function ISComputerPanel:_doInstallFromDisk()
  local capMax = (ComputerData and ComputerData.MAX_GAMES) and ComputerData.MAX_GAMES or 20
  local capCnt = 0
  if ComputerData and ComputerData.countInstalled then
    capCnt = ComputerData.countInstalled(self.worldObj) or 0
  elseif self.list and self.list.items then
    capCnt = #self.list.items
  end
  if capCnt >= capMax then
    self:updateButtons()
    return
  end
  if not (self.isOn and self:hasPower() and (not self.cdOpen) and self.diskInserted and self.insertedDiskType) then return end
  if self:isInstalled(self.insertedDiskType, self.insertedDiskName) then return end
  self:emitSound("install_start")
  ComputerJobs.startInstall(self.worldObj, self.insertedDiskType, 6.0, self.insertedDiskName)
  self:updateButtons()
end

function ISComputerPanel:_doRemoveSelected()
  local id, sel = nil, nil
  if self.list and self.list.selected ~= nil and self.list.selected ~= -1 and self.list.items then
    sel = self.list.items[self.list.selected]
    if sel and sel.item and sel.item.id then id = sel.item.id end
  end
  if not id then return end
  -- Store pending uninstall name so completion can target correct record
  do
    local md = self.worldObj and self.worldObj.getModData and self.worldObj:getModData() or nil
    if md then
      md.computerData = md.computerData or {}
      md.computerData.pendingUninstallName = (sel and sel.item and sel.item.name) or nil
      if self.worldObj.transmitModData then self.worldObj:transmitModData() end
    end
  end
  ComputerJobs.startUninstall(self.worldObj, id, 4.0)
  self:updateButtons()
end

-- Public button handlers now queue proximity activation
function ISComputerPanel:onTogglePower()
  self:queueActivate(function(p) p:_doTogglePower() end)
end

function ISComputerPanel:onToggleCD()
  self:queueActivate(function(p) p:_doToggleCD() end)
end

function ISComputerPanel:onInsertDisk()
  self:queueActivate(function(p) p:_doInsertDisk() end)
end

function ISComputerPanel:onEjectDisk()
  self:emitSound("cd_eject")
  self:queueActivate(function(p) p:_doEjectDisk() end)
end

function ISComputerPanel:onCancelInstall()
  self:queueActivate(function(p) p:_doCancelInstall() end)
end

function ISComputerPanel:onInstallFromDisk()
  self:queueActivate(function(p) p:_doInstallFromDisk() end)
end

function ISComputerPanel:onRemoveSelected()
  self:queueActivate(function(p) p:_doRemoveSelected() end)
end

-- Play TA handlers
function ISComputerPanel:onCancelPlay()
  if self.activeActionType ~= "play" or not self.activeAction then return end
  if self.activeAction.forceStop then self.activeAction:forceStop() else self.activeAction:stop() end
end

function ISComputerPanel:onPlay()
  local job = ComputerJobs.getJob(self.worldObj)
  if job then return end
  if not (self.worldObj and self.worldObj.getSquare) then return end
  -- require selection
  local id = nil
  if self.list and self.list.selected ~= nil and self.list.selected ~= -1 and self.list.items then
    local sel = self.list.items[self.list.selected]
    if sel and sel.item and sel.item.id then id = sel.item.id end
  end
  if not id then return end
  -- walk adjacent then start TA
  local sq = self.worldObj:getSquare(); if not sq then return end
  if luautils and luautils.walkAdj then luautils.walkAdj(self.playerObj, sq) end
  local action = ISComputerPlayAction:new(self.playerObj, self, self.worldObj, self.playerIndex, id)
  ISTimedActionQueue.add(action)
  self:updateButtons()
end

-- TA lifecycle for Play
function ISComputerPanel:onActionStarted(kind, actionRef)
  self.activeActionType = kind
  self.activeAction = actionRef
  self:updateButtons()
end

function ISComputerPanel:onActionStopped(kind, completed)
  if self.activeActionType ~= kind then return end
  self.activeActionType = nil
  self.activeAction = nil
  self:updateButtons()
end

function ISComputerPanel:prerender()
  ISPanel.prerender(self)

  local p = self:hasPower()
  if self._lastPower ~= p then
    self._lastPower = p
    if not p and self.isOn then self:forcePowerOff() end
    ComputerLight.refresh(self.worldObj)
    self:updateButtons()
  end
  if self._lastSelected ~= self.list.selected then
    self._lastSelected = self.list.selected
    self:updateButtons()
  end

  -- sync cdOpen from modData (tray completion)
  local md2 = self.worldObj and self.worldObj.getModData and self.worldObj:getModData() or nil
  if md2 and md2.computerData and md2.computerData.cdOpen ~= nil then
    local mdOpen = md2.computerData.cdOpen and true or false
    if self.cdOpen ~= mdOpen then
      self.cdOpen = mdOpen
      ComputerLight.refresh(self.worldObj)
      self:updateButtons()
    end
  end

  -- title bar
  self:drawRect(0, 0, self.width, self.titlebarH, 1, 0.15, 0.15, 0.15)
  local tm = getTextManager()
  local tw = tm:MeasureStringX(UIFont.Small, self.title)
  local th = tm:getFontHeight(UIFont.Small)
  local tx = math.floor((self.width - tw) / 2)
  local ty = math.floor((self.titlebarH - th) / 2)
  self:drawText(self.title, tx, ty, 1, 1, 1, 1, UIFont.Small)
  -- right header
  local rx = self._layout.rightX
  local ry = self._layout.rightY
  self:drawText(self.rightTitle, rx + 2, ry, 1, 1, 1, 1, UIFont.Small)

  self:drawRectBorder(0, 0, self.width, self.height, 1, 0.15, 0.15, 0.15)
end

function ISComputerPanel:render()
  ISPanel.render(self)

  local powered = (self.isOn and self:hasPower()) and true or false

  -- memory capacity (games installed / cap)
  local capMax = (ComputerData and ComputerData.MAX_GAMES) and ComputerData.MAX_GAMES or 20
  local capCnt = 0
  if ComputerData and ComputerData.countInstalled then
    capCnt = ComputerData.countInstalled(self.worldObj) or 0
  elseif self.list and self.list.items then
    capCnt = #self.list.items
  end
  if capCnt < 0 then capCnt = 0 end
  if capCnt > capMax then capCnt = capMax end
  local ratio = (capMax > 0) and (capCnt / capMax) or 0

  local tm = getTextManager()
  local font = UIFont.Small

  -- border and fill colors
  local borderOnR, borderOnG, borderOnB, borderOnA = 0.6, 0.6, 0.6, 1.0
  -- disabled buttons in ISButton use red-ish border (0.7, 0.1, 0.1, 0.7)
  local borderOffR, borderOffG, borderOffB, borderOffA = 0.7, 0.1, 0.1, 0.7
  local fillOnR, fillOnG, fillOnB = 0.35, 0.75, 0.35
  local fillOffR, fillOffG, fillOffB = 0.3, 0.3, 0.3


-- Right list frame + geometry clamp aligned with MEMORY bar; uses same border colors
do
  local rx = self._layout.rightX
  local ry = self._layout.rightY + self._layout.rightHeaderH
  local rw = self._layout.rightW
  local baselineBottom
  if self._ui and self._ui.memory then
    baselineBottom = self._ui.memory.y + self._ui.memory.h
  else
    baselineBottom = self._layout.rightY + self._layout.rightH
  end
  local rh = baselineBottom - ry
  if rh < 0 then rh = 0 end
  local bottomPad = 8
  if self.list then
    if self.list.x ~= rx or self.list.y ~= ry or self.list.width ~= rw or self.list.height ~= (rh - bottomPad) then
      self.list:setX(rx); self.list:setY(ry); self.list:setWidth(rw); self.list:setHeight(math.max(0, rh - bottomPad))
    end
  end
  local powered2 = (self.isOn and self:hasPower()) and true or false
  local bR = powered2 and borderOnR or borderOffR
  local bG = powered2 and borderOnG or borderOffG
  local bB = powered2 and borderOnB or borderOffB
  local bA = powered2 and borderOnA or borderOffA
  self:drawRectBorder(rx, ry, rw, rh, bA, bR, bG, bB)
end

  -- STATUS bar (on top): text inside; when power is OFF -> no text and NO fill
  do
    local r = self._ui and self._ui.status or nil
    if r then
      local job = powered and ComputerJobs.getJob(self.worldObj) or nil
      local isActive = job and job.type ~= "tray"
      local playing = (self.activeActionType == "play")
      local busy = (isActive or playing)
      local progress = isActive and (ComputerJobs.getProgress(self.worldObj) or 0.0) or 0.0

      local fillW = 0
      local showIdle = false
      local baseWord = nil
      local dots = ""

      if powered then
        if busy then
          -- animated dots without shifting center: base word centered, dots drawn to the right
          local ms = (UIManager and UIManager.getMillisSinceLastRender and UIManager.getMillisSinceLastRender()) or 0
          self._dotT = (self._dotT or 0) + ms
          if self._dotT > 300 then
            self._dotT = self._dotT % 300
            self._dotN = ((self._dotN or 0) + 1) % 4
          end
          local n = self._dotN or 0
          if n == 1 then dots = "." elseif n == 2 then dots = ".." elseif n == 3 then dots = "..." else dots = "" end

          if isActive then fillW = math.floor(r.w * progress) end
          baseWord = (isActive and ((job.type == "install") and "Installing" or "Uninstalling")) or (playing and "Playing" or nil)
        else
          showIdle = true
        end
      end

      -- draw fill behind border
      if fillW > 0 then
        self:drawRect(r.x, r.y, fillW, r.h, 1, fillOnR, fillOnG, fillOnB)
      end
      -- draw border on top with on/off style
      local bR = powered and borderOnR or borderOffR
      local bG = powered and borderOnG or borderOffG
      local bB = powered and borderOnB or borderOffB
      local bA = powered and borderOnA or borderOffA
      self:drawRectBorder(r.x, r.y, r.w, r.h, bA, bR, bG, bB)

      -- draw text
      if powered then
        if showIdle then
          local txt = "Idle"
          local tw = tm:MeasureStringX(font, txt)
          local th = tm:getFontHeight(font)
          local tx = r.x + math.floor((r.w - tw)/2)
          local ty = r.y + math.floor((r.h - th)/2)
          self:drawText(txt, tx, ty, 1, 1, 1, 1, font)
        elseif baseWord then
          -- center base word, then append dots on the right without shifting the center anchor
          local baseW = tm:MeasureStringX(font, baseWord)
          local baseH = tm:getFontHeight(font)
          local baseX = r.x + math.floor((r.w - baseW)/2)
          local baseY = r.y + math.floor((r.h - baseH)/2)
          self:drawText(baseWord, baseX, baseY, 1, 1, 1, 1, font)
          if dots ~= "" then
            local dotsX = baseX + baseW
            self:drawText(dots, dotsX, baseY, 1, 1, 1, 1, font)
          end
        end
      end
    end
  end

  -- MEMORY bar (bottom): just bar; grey tint when power OFF. Draw fill first, then border.
  do
    local r = self._ui and self._ui.memory or nil
    if r then
      local fillW = math.floor(r.w * ratio)
      if fillW > 0 then
        local rr = powered and fillOnR or fillOffR
        local gg = powered and fillOnG or fillOffG
        local bb = powered and fillOnB or fillOffB
        self:drawRect(r.x, r.y, fillW, r.h, 1, rr, gg, bb)
      end
      local bR = powered and borderOnR or borderOffR
      local bG = powered and borderOnG or borderOffG
      local bB = powered and borderOnB or borderOffB
      local bA = powered and borderOnA or borderOffA
      self:drawRectBorder(r.x, r.y, r.w, r.h, bA, bR, bG, bB)
    end
  end

  -- refresh list+buttons when a job just finished
  local jobNow = ComputerJobs.getJob(self.worldObj)
  local hadJob = self._hadJob
  local hasJob = (jobNow ~= nil)
  if hadJob and (not hasJob) then
    ComputerData.populateListUI(self.worldObj, self.list)
    ComputerLight.refresh(self.worldObj)
    self:updateButtons()
  end
  self._hadJob = hasJob
end

function ISComputerPanel:onMouseUpOutside(x, y) end

function ISComputerPanel:onClose()
  local job = ComputerJobs.getJob(self.worldObj)
  if job and job.type == "uninstall" then return end
  self:removeFromUIManager()
  if ComputerMod and ComputerMod.windows then
    ComputerMod.windows[self.playerIndex] = nil
  end
end
