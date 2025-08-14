-- media/lua/client/Computer/Computer_Sound.lua
-- Lite version: no polling, no loops, no ON/OFF tracking.
-- Purpose: expose safe helpers to play/stop one-shot sounds from a computer object.
-- Usage example from your UI code:
--   ComputerSound.play("pc_power_button_click", worldObj, playerObj)
--   ComputerSound.play("pc_power_on", worldObj, playerObj)
--   ComputerSound.play("computeron", worldObj, playerObj)
-- This file does NOT auto-play anything by itself.

ComputerSound = ComputerSound or {}

local function _freeEmitterAt(obj)
    if not (obj and obj.getSquare) then return nil end
    local sq = obj:getSquare()
    if sq and getWorld and getWorld().getFreeEmitter then
        return getWorld():getFreeEmitter(sq:getX(), sq:getY(), sq:getZ())
    end
    return nil
end

-- Play a sound with fallbacks: object 3D -> free emitter 3D -> player 2D
function ComputerSound.play(name, obj, player)
    if not name or name == "" then return end

    -- 1) Try as object-attached 3D sound
    if obj and obj.playSound then
        local ok = pcall(function() obj:playSound(name) end)
        if ok == true then return end
    end

    -- 2) Try a free world emitter at the object's tile
    local em = _freeEmitterAt(obj)
    if em and em.playSound then
        local ok2 = pcall(function() em:playSound(name) end)
        if ok2 == true then return end
    end

    -- 3) Fallback to player's 2D sound (always audible)
    if not player and getSpecificPlayer then
        player = getSpecificPlayer(0)
    end
    if player and player.playSound then
        pcall(function() player:playSound(name) end)
    end
end

-- Attempt to stop a named sound at the object/emitter (best effort)
function ComputerSound.stop(name, obj)
    if not name or name == "" then return end

    if obj and obj.stopSound then
        pcall(function() obj:stopSound(name) end)
        return
    end

    local em = _freeEmitterAt(obj)
    if em and em.stopSoundByName then
        pcall(function() em:stopSoundByName(name) end)
    end
end

return ComputerSound
