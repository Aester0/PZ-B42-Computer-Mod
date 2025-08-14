
function load_computer_data(worldObj)
    if not worldObj or not worldObj.getModData then return end
    local mod_data = worldObj:getModData()

    if mod_data and mod_data.computerData then
        set_installed_games(worldObj, mod_data.computerData.installedGames)
        set_inserted_disk(worldObj, mod_data.computerData.insertedDisk)
    end
end
    