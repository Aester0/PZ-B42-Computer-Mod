--=== Computer Mod – Device Options + ISPanel window (power check: grid OR generator OR hydro) ===--

if ComputerMod == nil then ComputerMod = {} end

-- Sprite tables (unchanged)
ComputerMod.SpriteComputerOff = ComputerMod.SpriteComputerOff or {
  S = "appliances_com_01_72",
  E = "appliances_com_01_73",
  N = "appliances_com_01_74",
  W = "appliances_com_01_75",
}
ComputerMod.SpriteComputerOn = ComputerMod.SpriteComputerOn or {
  S = "appliances_com_01_76",
  E = "appliances_com_01_77",
  N = "appliances_com_01_78",
  W = "appliances_com_01_79",
}

-- reverse lookup: sprite name -> {state, dir}
ComputerMod._rev = {}
for dir,name in pairs(ComputerMod.SpriteComputerOff) do ComputerMod._rev[name] = { state = "off", dir = dir } end
for dir,name in pairs(ComputerMod.SpriteComputerOn) do ComputerMod._rev[name] = { state = "on", dir = dir } end

local function isComputerObject(obj)
  if not obj then return false end
  local spr = obj.getSprite and obj:getSprite() or nil
  if not spr then return false end
  local n = spr.getName and spr:getName() or nil
  if not n then return false end
  return ComputerMod._rev[n] ~= nil
end

local function within2(playerObj, square)
  if not playerObj or not square then return false end
  local ps = playerObj:getCurrentSquare(); if not ps then return false end
  local dx = math.abs(ps:getX() - square:getX())
  local dy = math.abs(ps:getY() - square:getY())
  return math.max(dx, dy) <= 1
end

-- Robust power check following base-game rules:
-- 1) Global hydro on? (world:isHydroPowerOn) -> power.
-- 2) Square flagged as powered? (square:haveElectricity) -> power.
-- 3) Generator powering this square? (square:getGenerator() and gen:isActivated() and gen:isConnected() and gen:fuel>0) -> power.
function ComputerMod.hasPower(worldObj)
  if not worldObj or not worldObj.getSquare then return false end
  local sq = worldObj:getSquare(); if not sq then return false end

  -- (1) global grid
  if getWorld and getWorld().isHydroPowerOn and getWorld():isHydroPowerOn() then
    return true
  end

  -- (2) square electricity flag (covers generator radius in most cases)
  if sq.haveElectricity and sq:haveElectricity() then
    return true
  end

  -- (3) explicit generator on this square
  if sq.getGenerator then
    local gen = sq:getGenerator()
    if gen and gen.isActivated and gen:isActivated() and gen.isConnected and gen:isConnected() and gen.getFuel and gen:getFuel() > 0 then
      return true
    end
  end

  return false
end

function ComputerMod.setComputerSprite(worldObj, on)
  if not worldObj then return end
  local spr = worldObj:getSprite()
  local cur = spr and spr:getName() or nil
  local dir = "S"
  if cur and ComputerMod._rev[cur] then dir = ComputerMod._rev[cur].dir end
  local target = (on and ComputerMod.SpriteComputerOn[dir]) or ComputerMod.SpriteComputerOff[dir]
  if cur ~= target then
    local newSpr = getSprite(target)
    if newSpr then
      worldObj:setSprite(newSpr)
      local sq = worldObj:getSquare()
      if sq then sq:RecalcAllWithNeighbours(true) end
      worldObj:transmitUpdatedSpriteToClients()
    end
  end
end

function ComputerMod.setComputerOn(worldObj, on)
  if not worldObj then return end
  local spr = worldObj:getSprite()
  local cur = spr and spr:getName() or nil
  local dir = "S"
  if cur and ComputerMod._rev[cur] then dir = ComputerMod._rev[cur].dir end
  local target = (on and ComputerMod.SpriteComputerOn[dir]) or ComputerMod.SpriteComputerOff[dir]
  if cur ~= target then
    local newSpr = getSprite(target)
    if newSpr then
      worldObj:setSprite(newSpr)
      local sq = worldObj:getSquare()
      if sq then sq:RecalcAllWithNeighbours(true) end
      worldObj:transmitUpdatedSpriteToClients()
    end
  end
  local md = worldObj:getModData()
  md.Computer_On = on and true or false
  worldObj:transmitModData()
end

ComputerMod.windows = ComputerMod.windows or {}

function ComputerMod.closeWindowFor(playerObj)
  if not playerObj then return end
  local idx = playerObj:getPlayerNum()
  local win = ComputerMod.windows[idx]
  if win and win.removeFromUIManager then win:removeFromUIManager() end
  ComputerMod.windows[idx] = nil
end

local function ensureWindow(playerObj, worldObj)
  if not playerObj or not worldObj then return end
  local idx = playerObj:getPlayerNum()
  local win = ComputerMod.windows[idx]
  if win and win.isVisible and win:isVisible() then win:bringToTop(); return end

  require "Computer/UI/ISComputerPanel"
  win = ISComputerPanel:new(100, 100, 720, 440, playerObj, worldObj)
  if not win then return end
  win:initialise()
  win:addToUIManager()
  win:bringToTop()
  ComputerMod.windows[idx] = win
end

local function findComputer(worldobjects)
  if not worldobjects then return nil end
  for _,o in ipairs(worldobjects) do
    if instanceof(o, "IsoObject") and isComputerObject(o) then return o end
    if o.getSquare then
      local sq = o:getSquare()
      if sq then
        local list = sq:getObjects()
        for i=0, list:size()-1 do
          local io = list:get(i)
          if isComputerObject(io) then return io end
        end
      end
    end
  end
  return nil
end

local function onFill(playerNum, context, worldobjects, test)
  if test then return true end
  local playerObj = getSpecificPlayer(playerNum); if not playerObj then return true end
  local comp = findComputer(worldobjects); if not comp then return true end
  if not within2(playerObj, comp:getSquare()) then return true end

  local label = getTextOrNull and getTextOrNull("ContextMenu_DeviceOptions") or "Device Options"
  context:addOption(label or "Device Options", nil, function() ensureWindow(playerObj, comp) end)
  return true
end
Events.OnFillWorldObjectContextMenu.Add(onFill)

-- Keep window alive only while in range
local function onPlayerUpdate(playerObj)
  if not playerObj then return end
  local idx = playerObj:getPlayerNum()
  local win = ComputerMod.windows[idx]; if not win then return end
  local comp = win.worldObj
  if not comp or not comp.getSquare or not comp:getSquare() then ComputerMod.closeWindowFor(playerObj); return end
  if not within2(playerObj, comp:getSquare()) then ComputerMod.closeWindowFor(playerObj); return end
end
Events.OnPlayerUpdate.Add(onPlayerUpdate)
