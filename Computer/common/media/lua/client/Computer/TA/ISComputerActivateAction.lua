require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

ISComputerActivateAction = ISBaseTimedAction:derive("ISComputerActivateAction")

local function isAdjacent(character, worldObj)
  if not character or not worldObj or not worldObj.getSquare then return false end
  local cs = character:getSquare()
  local os = worldObj:getSquare()
  if not cs or not os then return false end
  if cs:getZ() ~= os:getZ() then return false end
  local dx = math.abs(cs:getX() - os:getX())
  local dy = math.abs(cs:getY() - os:getY())
  return dx <= 1 and dy <= 1
end

function ISComputerActivateAction:new(character, panel, worldObj, fn)
  local o = ISBaseTimedAction.new(self, character)
  o.panel = panel
  o.worldObj = worldObj
  o._fn = fn
  o.maxTime = 1              -- near-instant once adjacent
  o.stopOnWalk = false       -- pathing happens before TA starts
  o.stopOnRun  = false
  o.stopOnAim  = false
  o.useProgressBar = false
  return o
end

function ISComputerActivateAction:isValid()
  if not self.panel or not self.panel.worldObj then return false end
  return true
end

function ISComputerActivateAction:waitToStart()
  if self.character and self.worldObj and self.character.faceThisObject then
    self.character:faceThisObject(self.worldObj)
  end
  if self.character and self.character.shouldBeTurning and self.character:shouldBeTurning() then
    return true
  end
  if not isAdjacent(self.character, self.worldObj) then
    return true
  end
  return false
end

function ISComputerActivateAction:start()
  -- no animation; immediate
end

function ISComputerActivateAction:perform()
  if self._fn then pcall(self._fn, self.panel) end
  ISBaseTimedAction.perform(self)
end
