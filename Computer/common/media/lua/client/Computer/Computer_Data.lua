-- media/lua/client/Computer/Computer_Data.lua
-- Installed games are stored as array of { id=fullType, name=text }.
-- Uninstall targets by (id,name). A pending name can be stored in modData during timed uninstall.

ComputerData = ComputerData or {}
ComputerData.MAX_GAMES = 20

local function _ensure(obj)
  if not (obj and obj.getModData) then return nil end
  local md = obj:getModData()
  md.computerData = md.computerData or {}
  local cd = md.computerData
  cd.installed = cd.installed or {} -- array of { id=string, name=string }
  return cd, md
end

local function _indexOfPair(t, id, name)
  for i=1,#t do
    local it = t[i]
    if it and it.id == id and it.name == name then return i end
  end
  return nil
end

function ComputerData.install(obj, id, name)
  if not (obj and id) then return end
  local cd, md = _ensure(obj); if not cd then return end
  local nm = name or "Game CD"
  if not _indexOfPair(cd.installed, id, nm) then
    table.insert(cd.installed, { id = id, name = nm })
    if obj.transmitModData then obj:transmitModData() end
  end
end

-- If 'name' is nil, try to use pendingUninstallName from modData to disambiguate
function ComputerData.uninstall(obj, id, name)
  if not (obj and id) then return end
  local cd, md = _ensure(obj); if not cd then return end

  local targetName = name
  if not targetName and md and md.computerData then
    targetName = md.computerData.pendingUninstallName
  end

  -- Prefer exact (id,name)
  if targetName then
    local idx = _indexOfPair(cd.installed, id, targetName)
    if idx then
      table.remove(cd.installed, idx)
      md.computerData.pendingUninstallName = nil
      if obj.transmitModData then obj:transmitModData() end
      return
    end
  end

  -- Fallback: remove first by id
  for i=1,#cd.installed do
    if cd.installed[i] and cd.installed[i].id == id then
      table.remove(cd.installed, i)
      md.computerData.pendingUninstallName = nil
      if obj.transmitModData then obj:transmitModData() end
      return
    end
  end
end

function ComputerData.populateListUI(obj, list)
  if not (list and list.clear and list.addItem) then return end
  list:clear()
  local cd = _ensure(obj)
  if not cd then return end
  cd = select(1, _ensure(obj))
  for i=1,#cd.installed do
    local rec = cd.installed[i]
    if rec and rec.id then
      local label = rec.name or rec.id or "Game CD"
      if ComputerData and ComputerData.stripCdPrefix then label = ComputerData.stripCdPrefix(label) end
      list:addItem(label, { id = rec.id, name = rec.name })
    end
  end
end


-- Count installed games for a given object
function ComputerData.countInstalled(obj)
  local cd = select(1, (obj and obj.getModData) and (function() local a,b=_ensure(obj); return a end)() or nil)
  if not cd then return 0 end
  return #cd.installed
end


-- UI helper: show only game title in lists
function ComputerData.stripCdPrefix(name)
  if not name then return name end
  local s = tostring(name)
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("^Game%s*CD:%s*", "")
  s = s:gsub("^Game%s*Disc:%s*", "")
  s = s:gsub("^CD:%s*", "")
  s = s:gsub("^Disc:%s*", "")
  if s == "" then return name end
  return s
end
