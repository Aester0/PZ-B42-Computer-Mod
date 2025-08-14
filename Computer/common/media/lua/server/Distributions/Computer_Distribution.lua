-- media/lua/server/Distributions/Computer_Distribution.lua
-- Spawns the single disc item everywhere we want.

pcall(function() require "Items/ProceduralDistributions" end)
pcall(function() require "Items/SuburbsDistributions" end)

local ITEM = "Computer.Disc_Game"

local function addItemPair(t, item, weight)
    if not (t and t.items) then return end
    table.insert(t.items, item); table.insert(t.items, weight)
end

local function addToProcedural(key, weight)
    if not (ProceduralDistributions and ProceduralDistributions.list) then return end
    local node = ProceduralDistributions.list[key]
    if not node then return end
    addItemPair(node, ITEM, weight)
end

local function findSuburbsLeaf(path)
    if not SuburbsDistributions then return nil end
    local node = SuburbsDistributions
    for i=1,#path-1 do
        node = node[path[i]]
        if not node then return nil end
    end
    return node[path[#path]]
end

local function addToSuburbs(path, weight)
    local leaf = findSuburbsLeaf(path)
    if not leaf then return end
    if leaf.items then
        addItemPair(leaf, ITEM, weight); return
    end
    if leaf.junk and leaf.junk.items then
        table.insert(leaf.junk.items, ITEM); table.insert(leaf.junk.items, weight)
    end
end

-- Procedural
addToProcedural("CrateCompactDiscs", 18)
addToProcedural("DeskGeneric", 12)
addToProcedural("LivingRoomShelf", 10)
addToProcedural("LivingRoomShelfNoTapes", 10)
addToProcedural("ShelfGeneric", 9)

-- Suburbs
addToSuburbs({"all","livingroom","shelves"}, 6)