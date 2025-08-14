-- media/lua/client/Computer/Options/Computer_ModOptions.lua
-- SAFE variant (no custom buttons) for b42 Mod Options.

ComputerMod = ComputerMod or {}
ComputerMod.Config = ComputerMod.Config or {}

local DEFAULTS = {
    tickSeconds    = 5,
    boredomDelta   = -0.4,
    unhappinessDelta = -1.0,
    panicDelta     =  0.0,
    stressDelta    = -0.004,
    fatigueDelta   =  0.010,
}

for k,v in pairs(DEFAULTS) do
    if ComputerMod.Config[k] == nil then ComputerMod.Config[k] = v end
end

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end

local function setupOptions_PZAPI()
    local PZAPI = rawget(_G, "PZAPI")
    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.create) then return false end

    local options = PZAPI.ModOptions:create("ComputerMod_Options", "Computer Mod")
    local controls = {}

    options:addDescription("Configure mood effects while using the computer. Each value applies once per tick interval.")

    controls.tickSeconds      = options:addSlider("tickSeconds", "Tick interval (seconds)", 1, 10, 1, DEFAULTS.tickSeconds,
                                    "How often to apply the changes below (lower = stronger overall effect).")
    controls.boredomDelta     = options:addSlider("boredomDelta", "Boredom", -15.0, 0.0, 0.1, DEFAULTS.boredomDelta,
                                    "Reduces boredom (0..100). Only negative values allowed.")
    controls.unhappinessDelta = options:addSlider("unhappinessDelta", "Unhappiness", -15.0, 0.0, 0.1, DEFAULTS.unhappinessDelta,
                                    "Reduces unhappiness (0..100). Only negative values allowed.")
    controls.panicDelta       = options:addSlider("panicDelta", "Panic", -30.0, 0.0, 0.5, DEFAULTS.panicDelta,
                                    "Reduces panic (0..100). Only negative values allowed.")
    controls.stressDelta      = options:addSlider("stressDelta", "Stress", -0.15, 0.0, 0.001, DEFAULTS.stressDelta,
                                    "Reduces stress (0..1). Only negative values allowed.")
    controls.fatigueDelta     = options:addSlider("fatigueDelta", "Fatigue", 0.0, 0.15, 0.001, DEFAULTS.fatigueDelta,
                                    "Increases fatigue (0..1). Only positive values allowed.")

    options.apply = function(self)
        local r = {
            tickSeconds      = clamp(controls.tickSeconds:getValue(),      1, 10),
            boredomDelta     = clamp(controls.boredomDelta:getValue(),     -15.0, 0.0),
            unhappinessDelta = clamp(controls.unhappinessDelta:getValue(), -15.0, 0.0),
            panicDelta       = clamp(controls.panicDelta:getValue(),       -30.0, 0.0),
            stressDelta      = clamp(controls.stressDelta:getValue(),      -0.15, 0.0),
            fatigueDelta     = clamp(controls.fatigueDelta:getValue(),     0.0, 0.15),
        }
        for k,v in pairs(r) do ComputerMod.Config[k] = v end
    end

    options:apply()
    return true
end

Events.OnGameBoot.Add(function()
    setupOptions_PZAPI()
end)

Events.OnGameStart.Add(function()
    setupOptions_PZAPI()
end)
