-- media/lua/client/Computer/Computer_Light.lua
-- Adds/removes a light source on the computer's tile when the PC is ON and powered.
-- Based on the classic approach (IsoLightSource + addLamppost/removeLamppost).

ComputerLight = ComputerLight or {}
ComputerLight._lights = ComputerLight._lights or {}

-- Helper: check if IsoObject is one of our computers (by sprite name)
function ComputerLight.isComputer(obj)
  if not (obj and obj.getSprite) then return false end
  local spr = obj:getSprite(); if not spr or not spr.getName then return false end
  local n = spr:getName(); if not n then return false end
  return (ComputerMod and ComputerMod._rev and ComputerMod._rev[n] ~= nil) or false
end

local function _key(obj)
  if not (obj and obj.getX) then return nil end
  return tostring(obj:getX()) .. "|" .. tostring(obj:getY()) .. "|" .. tostring(obj:getZ())
end

local function _cell()
  return getCell and getCell() or nil
end

function ComputerLight.isPowered(obj)
  local sq = obj and obj.getSquare and obj:getSquare() or nil
  if not sq then return false end
  local hydro = false
  if getWorld and getWorld().isHydroPowerOn then
    hydro = getWorld():isHydroPowerOn() and true or false
  end
  local sqElec = false
  if sq.haveElectricity then
    sqElec = (sq:haveElectricity() == true)
  end
  local genOk = false
  if sq.getGenerator then
    local gen = sq:getGenerator()
    if gen and gen.isActivated and gen:isActivated() and gen.isConnected and gen:isConnected() and gen.getFuel and gen:getFuel() > 0 then
      genOk = true
    end
  end
  return hydro or sqElec or genOk
end

function ComputerLight.add(obj, r, g, b, radius)
  local c = _cell(); if not c then return end
  local k = _key(obj); if not k then return end
  if ComputerLight._lights[k] then return end
  local x,y,z = obj:getX(), obj:getY(), obj:getZ()
  -- Default to a cool bluish monitor glow if not provided.
  r = r or 0.4; g = g or 0.4; b = b or 0.3; radius = radius or 6
  local lamp = IsoLightSource.new(x, y, z, r, g, b, radius)
  ComputerLight._lights[k] = lamp
  c:addLamppost(lamp)
end

function ComputerLight.remove(obj)
  local c = _cell(); if not c then return end
  local k = _key(obj); if not k then return end
  local lamp = ComputerLight._lights[k]
  if lamp then
    c:removeLamppost(lamp)
    ComputerLight._lights[k] = nil
  end
end

function ComputerLight.refresh(obj)
  if not obj then return end
  local md = obj.getModData and obj:getModData() or nil
  local isOn = md and md.Computer_On and true or false
  if isOn and ComputerLight.isPowered(obj) then
    ComputerLight.add(obj)
  else
    ComputerLight.remove(obj)
  end
end

-- When a square loads in an ON computer, restore its light (and drop it if not powered).
function ComputerLight.onLoadGridsquare(square)
  if not square then return end
  local objs = square:getObjects()
  for i=0, objs:size()-1 do
    local o = objs:get(i)
    if o and o.getModData then
      local md = o:getModData()
      if md and md.Computer_On then
        ComputerLight.refresh(o)
      end
    end
  end
end

Events.LoadGridsquare.Add(ComputerLight.onLoadGridsquare)

function ComputerLight.refreshAll()
  if not ComputerLight._lights then return end
  local cell = getCell and getCell() or nil
  if not cell then return end
  for k, lamp in pairs(ComputerLight._lights) do
    -- key format: 'x|y|z'
    local x, y, z = string.match(k or "", "^(%-?%d+)|(%-?%d+)|(%-?%d+)$")
    x = tonumber(x); y = tonumber(y); z = tonumber(z)
    if x and y and z then
      local sq = cell:getGridSquare(x, y, z)
      if sq then
        local objs = sq:getObjects()
        local found = nil
        for i=0, objs:size()-1 do
          local o = objs:get(i)
          if ComputerLight.isComputer(o) then found = o; break end
        end
        if found then
          local md = found:getModData()
          local logicalOn = md and md.Computer_On and true or false
          local powered = ComputerLight.isPowered(found)
          if (not powered) and logicalOn then
            if ComputerMod and ComputerMod.setComputerOn then
              ComputerMod.setComputerOn(found, false)
              if found.transmitModData then found:transmitModData() end
            end
          else
            ComputerLight.refresh(found)
            if ComputerMod and ComputerMod.setComputerSprite then
              ComputerMod.setComputerSprite(found, logicalOn and powered)
            end
          end
        end
      end
    end
  end
end



Events.OnPlayerUpdate.Add(function(_)
  ComputerLight.refreshAll()
end)

Events.EveryOneMinute.Add(function()
  ComputerLight.refreshAll()
end)
