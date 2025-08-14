ComputerJobs = ComputerJobs or {}

-- time helpers
local function worldAgeMs()
  local gt = getGameTime()
  if gt.getWorldAgeMs then
    return gt:getWorldAgeMs()
  else
    return math.floor(gt:getWorldAgeHours() * 60 * 60 * 1000)
  end
end

local function hasPowerFor(worldObj)
  if not worldObj or not worldObj.getSquare then return false end
  local sq = worldObj:getSquare(); if not sq then return false end

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
    if gen and gen.isActivated and gen:isActivated() and gen.isConnected and gen:isConnected() and gen.getFuel and gen:getFuel() > 0 then
      genOk = true
    end
  end
  return hydro or sqElec or genOk
end

-- public API
function ComputerJobs.getJob(worldObj)
  if not worldObj or not worldObj.getModData then return nil end
  local md = worldObj:getModData()
  return md.computerJob
end

local function setJob(worldObj, job)
  local md = worldObj:getModData()
  md.computerJob = job
  if worldObj.transmitModData then worldObj:transmitModData() end
end

function ComputerJobs.startInstall(worldObj, diskType, seconds, diskName)
  if ComputerJobs.getJob(worldObj) then return nil end
  local gt = getGameTime()
  local minutesPerDay = gt.getMinutesPerDay and gt:getMinutesPerDay() or 60
  local gameMsPerRealSecond = math.floor((24*60*60*1000) / (minutesPerDay*60))
  local job = {
    type = "install",
    diskType = diskType,
    diskName = diskName,
    startMs = worldAgeMs(),
    durationMs = math.max(1, math.floor((seconds or 6.0) * gameMsPerRealSecond)),
    state = "active"
  }
  setJob(worldObj, job)
  ComputerJobs._track(worldObj)
  return job
end

function ComputerJobs.startUninstall(worldObj, gameId, seconds)
  if ComputerJobs.getJob(worldObj) then return nil end
  local gt = getGameTime()
  local minutesPerDay = gt.getMinutesPerDay and gt:getMinutesPerDay() or 60
  local gameMsPerRealSecond = math.floor((24*60*60*1000) / (minutesPerDay*60))
  local job = {
    type = "uninstall",
    gameId = gameId,
    startMs = worldAgeMs(),
    durationMs = math.max(1, math.floor((seconds or 4.0) * gameMsPerRealSecond)),
    state = "active"
  }
  setJob(worldObj, job)
  ComputerJobs._track(worldObj)
  return job
end

function ComputerJobs.startTray(worldObj, op, seconds)
  if ComputerJobs.getJob(worldObj) then return nil end
  local gt = getGameTime()
  local minutesPerDay = gt.getMinutesPerDay and gt:getMinutesPerDay() or 60
  local gameMsPerRealSecond = math.floor((24*60*60*1000) / (minutesPerDay*60))
  local job = {
    type = "tray",
    op = (op == "open") and "open" or "close",
    startMs = worldAgeMs(),
    durationMs = math.max(1, math.floor((seconds or 2.0) * gameMsPerRealSecond)),
    state = "active"
  }
  setJob(worldObj, job)
  ComputerJobs._track(worldObj)
  return job
end

-- cancel (only install is cancellable here; uninstall/tray complete fast)
function ComputerJobs.cancel(worldObj)
  local job = ComputerJobs.getJob(worldObj)
  if not job then return end
  if job.type ~= "install" then return end
  setJob(worldObj, nil)
  ComputerJobs._untrack(worldObj)
end

function ComputerJobs.getProgress(worldObj)
  local job = ComputerJobs.getJob(worldObj)
  if not job or job.state ~= "active" then return nil end
  if job.type == "tray" then return nil end -- we don't display tray progress
  local now = worldAgeMs()
  local frac = (now - job.startMs) / job.durationMs
  if frac < 0 then frac = 0 end
  if frac > 1 then frac = 1 end
  return frac
end

function ComputerJobs.ensureTracking(worldObj)
  local job = ComputerJobs.getJob(worldObj)
  if job and job.state == "active" then
    ComputerJobs._track(worldObj)
  end
end

-- internal tracking
ComputerJobs._active = ComputerJobs._active or {}
ComputerJobs._tickAdded = ComputerJobs._tickAdded or false

function ComputerJobs._track(worldObj)
  ComputerJobs._active[worldObj] = true
  if not ComputerJobs._tickAdded then
    Events.OnTick.Add(ComputerJobs._updateAll)
    ComputerJobs._tickAdded = true
  end
end

function ComputerJobs._untrack(worldObj)
  ComputerJobs._active[worldObj] = nil
end

function ComputerJobs._updateAll()
  for worldObj,_ in pairs(ComputerJobs._active) do
    ComputerJobs._updateOne(worldObj)
  end
end

function ComputerJobs._updateOne(worldObj)
  local job = ComputerJobs.getJob(worldObj)
  if not job or job.state ~= "active" then
    ComputerJobs._untrack(worldObj)
    return
  end

  -- power loss cancels any job
  if not hasPowerFor(worldObj) then
    setJob(worldObj, nil)
    ComputerJobs._untrack(worldObj)
    return
  end

  local now = worldAgeMs()
  local done = (now - job.startMs) >= job.durationMs
  if not done then return end

  if job.type == "install" and job.diskType then
    ComputerData.install(worldObj, job.diskType, job.diskName)
  elseif job.type == "uninstall" and job.gameId then
    ComputerData.uninstall(worldObj, job.gameId)
  elseif job.type == "tray" then
    local md = worldObj and worldObj.getModData and worldObj:getModData() or nil
    if md then
      md.computerData = md.computerData or {}
      md.computerData.cdOpen = (job.op == "open") and true or false
      if worldObj.transmitModData then worldObj:transmitModData() end
      -- ensure light state matches after tray finishes
      if ComputerLight and ComputerLight.refresh then ComputerLight.refresh(worldObj) end
    end
  end

  setJob(worldObj, nil)
  ComputerJobs._untrack(worldObj)
end
