
function save_computer_data(worldObj)
    if not worldObj or not worldObj.getModData then return end
    local mod_data = worldObj:getModData()
    mod_data.computerData = mod_data.computerData or {}

    -- Сохраняем нужные данные
    mod_data.computerData.installedGames = get_installed_games(worldObj)
    mod_data.computerData.insertedDisk = get_inserted_disk(worldObj)
    worldObj:transmitModData()  -- Отправляем данные на сервер
end
    