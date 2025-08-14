-- media/lua/shared/Computer/Computer_Item_OnCreate.lua
-- Sets a readable custom name for spawned game discs.
-- Expanded pool to 40 era-appropriate titles (1989–1998).
-- Note: setCustomName expects a boolean; set the actual text via setName().

local TITLES = {
  "Nightfall: Noir City", "Steel Tempest 3D", "Starbound Trader", "Pixel Rally '90", "Crimson Outpost", "Delta Skies", "Turbo Street Racers 2", "Shadowgrid", "Ashland Courier", "Underdeep", "NeoKart '96", "Cold Front Tactics", "Phantom DOS", "Bioframe Protocol", "Shogun's Blade", "Solar Dominion", "Zero Hour: Terminal", "Quantum Ranger", "Riverside Tycoon", "Rosewood Detective", "West Point Siege", "Crypt Runner", "Mega Rally '94", "Dungeon Delver II", "Neon Strike", "Circuit Breakpoint", "Starbase 12", "Fatal Express", "Courier Quest", "Suburban Outlaws", "Arcadia '93", "Midnight Pharaoh", "Shadow Operative", "Mech Frontier 95", "Highway Havoc", "Orbital Miner", "Vampire Manor", "Pixel Pirates", "Cyberion Run", "Helix Assault"
}

function ComputerMod_OnGameDiscCreated(item)
  if item and item.isCustomName and item:isCustomName() then return end
  if not item or not item.setName then return end
  local count = #TITLES
  local idx = 0
  if ZombRand then idx = ZombRand(count) else idx = (math.random(count) - 1) end
  if idx < 0 or idx >= count then idx = 0 end
  local name = "Game CD: " .. TITLES[idx + 1]
  pcall(function() item:setName(name) end)
  pcall(function() if item.setCustomName then item:setCustomName(true) end end)
end
