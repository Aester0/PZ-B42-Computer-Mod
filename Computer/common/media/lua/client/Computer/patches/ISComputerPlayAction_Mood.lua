-- media/lua/client/Computer/patches/ISComputerPlayAction_Mood.lua
-- Patch: applies mood deltas while the player is using the computer.
-- Non-invasive: wraps ISComputerPlayAction:update() and reads deltas from ComputerMod.Config.

require "Computer/TA/ISComputerPlayAction"
local ok = pcall(require, "Computer/Options/Computer_ModOptions")

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

-- Read current tunables
local function getCfg()
    local C = (ComputerMod and ComputerMod.Config) or {}
    local bd = (C.boredomDelta or -0.4)
    local uh = (C.unhappinessDelta or -1.0)
    local pa = (C.panicDelta or 0.0)
    local st = (C.stressDelta or -0.004)
    local fa = (C.fatigueDelta or 0.010)
    -- enforce direction: boredom/unhappiness/panic/stress decrease only; fatigue increase only
    bd = math.min(0, bd)
    uh = math.min(0, uh)
    pa = math.min(0, pa)
    st = math.min(0, st)
    fa = math.max(0, fa)
    return {
        TICK_MS         = (C.tickSeconds or 5) * 1000,
        BOREDOM_DELTA   = bd,
        UNHAPPY_DELTA   = uh,
        PANIC_DELTA     = pa,
        STRESS_DELTA    = st,
        FATIGUE_DELTA   = fa,
    }
end

local function applyMood(player, cfg)
    if not player then return end
    local body  = player.getBodyDamage and player:getBodyDamage() or nil
    local stats = player.getStats and player:getStats() or nil

    if body then
        if cfg.BOREDOM_DELTA ~= 0 and body.getBoredomLevel and body.setBoredomLevel then
            local v = body:getBoredomLevel()
            body:setBoredomLevel(clamp(v + cfg.BOREDOM_DELTA, 0, 100))
        end
        if cfg.UNHAPPY_DELTA ~= 0 and body.getUnhappynessLevel and body.setUnhappynessLevel then
            local v = body:getUnhappynessLevel()
            body:setUnhappynessLevel(clamp(v + cfg.UNHAPPY_DELTA, 0, 100))
        end
    end

    if stats then
        if cfg.PANIC_DELTA ~= 0 and stats.getPanic and stats.setPanic then
            local v = stats:getPanic()
            stats:setPanic(clamp(v + cfg.PANIC_DELTA, 0, 100))
        end
        if cfg.STRESS_DELTA ~= 0 and stats.getStress and stats.setStress then
            local v = stats:getStress()
            stats:setStress(clamp(v + cfg.STRESS_DELTA, 0.0, 1.0))
        end
        if cfg.FATIGUE_DELTA ~= 0 and stats.getFatigue and stats.setFatigue then
            local v = stats:getFatigue()
            stats:setFatigue(clamp(v + cfg.FATIGUE_DELTA, 0.0, 1.0))
        end
    end
end

-- Timer helpers
local function _worldAgeMs()
    local gt = getGameTime()
    if gt and gt.getWorldAgeMs then return gt:getWorldAgeMs() end
    return (os.time() or 0) * 1000
end

local _orig_update = ISComputerPlayAction.update
function ISComputerPlayAction:update()
    if _orig_update then _orig_update(self) end

    -- Only when panel is ON & powered (the TA already checks validity)
    if (not self) or (not self.panel) or (not self.panel.isOn) then return end

    -- Lazy init timer
    local now = _worldAgeMs()
    self._mood_next = self._mood_next or now
    if now < self._mood_next then return end

    -- Apply and schedule next
    applyMood(self.character, getCfg())
    local C = getCfg()
    self._mood_next = now + (C.TICK_MS or 5000)
end
