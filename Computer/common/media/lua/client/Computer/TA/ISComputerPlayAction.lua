require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

ISComputerPlayAction = ISBaseTimedAction:derive("ISComputerPlayAction")

-- playlist of available tracks (place ogg files under media/sound/)
local MUSIC_LIST = {
    "computergame1","computergame2","computergame3","computergame4","computergame5",
    "computergame6","computergame7","computergame8","computergame9","computergame10",
    "computergame11","computergame12","computergame13","computergame14",
}

local function pickRandomMusic()
    if #MUSIC_LIST == 0 then return nil end
    local idx = ZombRand(#MUSIC_LIST) + 1 -- ZombRand(n) -> [0..n-1]
    return MUSIC_LIST[idx]
end

-- power check (square flag or hydro; b42-safe)
local function hasPowerFor(worldObj)
    if not worldObj or not worldObj.getSquare then return false end
    local sq = worldObj:getSquare(); if not sq then return false end

    local hydro = false
    if getWorld and getWorld().isHydroPowerOn then
        hydro = getWorld():isHydroPowerOn() and true or false
    end

    local sqElec = false
    if sq.haveElectricity then
        sqElec = sq:haveElectricity()
    elseif sq.isPowered then
        sqElec = sq:isPowered()
    end

    return hydro or sqElec
end

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

local function worldAgeMs()
    local gt = getGameTime()
    if gt and gt.getWorldAgeMs then return gt:getWorldAgeMs() end
    return (os.time() or 0) * 1000
end

-- emitter helpers
local function emitterIsPlaying(emitter, name)
    if not emitter or not name then return false end
    if emitter.isPlaying then return emitter:isPlaying(name) end
    return false
end

local function emitterPlay(emitter, name)
    if not emitter or not name then return false end
    if emitter.playSound then
        emitter:playSound(name)
        return true
    end
    return false
end

local function stopByName(emitter, name)
    if emitter and name and emitter.stopSoundByName then
        emitter:stopSoundByName(name)
    end
end

local function cleanup(self)
    if self.emitter then
        stopByName(self.emitter, "keyboard_click")
        stopByName(self.emitter, "mouse_click")
        if self._musicName then stopByName(self.emitter, self._musicName) end
        -- safety: try them all in case _musicName wasn't set
        for _, n in ipairs(MUSIC_LIST) do stopByName(self.emitter, n) end
    end
end

function ISComputerPlayAction:new(character, panel, worldObj, playerNum, gameId)
    local o = ISBaseTimedAction.new(self, character)
    o.panel      = panel
    o.worldObj   = worldObj
    o.playerNum  = playerNum or (character and character:getPlayerNum() or 0)
    o.gameId     = gameId

    o.emitter    = nil
    o._lastMs    = nil
    o._currentName = nil
    o._betweenGapMs = 500 -- ms between click tracks
    o._nextPickAt = 0
    o._musicName = nil

    -- endless action while playing
    o.maxTime        = 2147483647
    o.stopOnWalk     = true
    o.stopOnRun      = true
    o.stopOnAim      = true
    o.useProgressBar = false
    o.jobType        = "Play"
    return o
end

function ISComputerPlayAction:isValid()
    if not self.panel or not self.panel.isOn then return false end
    if not hasPowerFor(self.worldObj) then return false end
    if not isAdjacent(self.character, self.worldObj) then return false end
    return true
end

function ISComputerPlayAction:waitToStart()
    if self.character and self.worldObj and self.character.faceThisObject then
        self.character:faceThisObject(self.worldObj)
    end
    if self.character and self.character.shouldBeTurning and self.character:shouldBeTurning() then
        return true
    end
    return not isAdjacent(self.character, self.worldObj)
end

function ISComputerPlayAction:start()
    -- sit/idle anim fits well for “using PC”
    self:setActionAnim("Read")
    self.character:SetVariable("ReadType", "book")

    self._lastMs = worldAgeMs()

    -- choose a random track each time Play starts
    self._musicName = pickRandomMusic()

    -- use player's emitter and pin to the computer tile (3D sound)
    self.emitter = self.character and self.character:getEmitter() or nil
    if self.emitter and self.worldObj and self.worldObj.getSquare then
        local sq = self.worldObj:getSquare()
        if sq and self.emitter.setPos then
            self.emitter:setPos(sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ() or 0)
        end
        if self.emitter.playSound and self._musicName then
            self.emitter:playSound(self._musicName) -- loops via script def
        end
    end

    if self.panel and self.panel.onActionStarted then
        self.panel:onActionStarted("play", self)
    end
end

function ISComputerPlayAction:update()
    -- stop if any required condition is gone
    if (not self.panel) or (not self.panel.isOn) or (not hasPowerFor(self.worldObj)) or (not isAdjacent(self.character, self.worldObj)) then
        self:stop()
        return
    end

    local now = worldAgeMs()

    -- keep 3D music alive & anchored
    if self.emitter then
        if self.worldObj and self.worldObj.getSquare and self.emitter.setPos then
            local sq = self.worldObj:getSquare()
            if sq then self.emitter:setPos(sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ() or 0) end
        end
        if self._musicName and self.emitter.isPlaying and self.emitter.playSound and (not self.emitter:isPlaying(self._musicName)) then
            -- If current track missing (ogg not provided), try another track
            local tried = 0
            local maxTries = #MUSIC_LIST
            local ok = false
            while (not ok) and tried < maxTries do
                self._musicName = pickRandomMusic()
                ok = emitterPlay(self.emitter, self._musicName)
                tried = tried + 1
            end
        end
    end

    -- play keyboard/mouse clicks alongside the music (non-blocking)
    if self.emitter then
        local anyClick = emitterIsPlaying(self.emitter, "keyboard_click") or emitterIsPlaying(self.emitter, "mouse_click")
        if (not anyClick) and now >= (self._nextPickAt or 0) then
            local pick = (ZombRand(2) == 0) and "keyboard_click" or "mouse_click"
            emitterPlay(self.emitter, pick)
            self._currentName = pick
            self._nextPickAt = now + self._betweenGapMs
        end
    end
end

function ISComputerPlayAction:stop()
    cleanup(self)
    ISBaseTimedAction.stop(self)
    if self.panel and self.panel.onActionStopped then
        self.panel:onActionStopped("play", false)
    end
end

function ISComputerPlayAction:forceStop()
    cleanup(self)
    ISBaseTimedAction.forceStop(self)
    if self.panel and self.panel.onActionStopped then
        self.panel:onActionStopped("play", false)
    end
end

function ISComputerPlayAction:perform()
    cleanup(self)
    if self.panel and self.panel.onActionStopped then
        self.panel:onActionStopped("play", true)
    end
    ISBaseTimedAction.perform(self)
end
