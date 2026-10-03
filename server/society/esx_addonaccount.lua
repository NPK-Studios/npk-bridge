if (Config.Society == 'auto' and not checkResource('esx_addonaccount')) or (Config.Society ~= 'auto' and Config.Society ~= 'esx_addonaccount') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Society] Loaded: esx_addonaccount')
end

Bridge.Society = {}

Bridge.Society.addMoney = function(playerId, jobName, amount)
    local account = exports['esx_addonaccount']:GetSharedAccount(('society_%s'):format(jobName))
    if account then
        account.addMoney(amount)
        return true
    end
    return false
end

Bridge.Society.removeMoney = function(playerId, jobName, amount)
    local account = exports['esx_addonaccount']:GetSharedAccount(('society_%s'):format(jobName))
    if account then
        account.removeMoney(amount)
        return true
    end
    return false
end

Bridge.Society.getMoney = function(playerId, jobName)
    local account = exports['esx_addonaccount']:GetSharedAccount(('society_%s'):format(jobName))
    if account then
        return account.money
    end
    return 0
end
local ensuredAccounts = {}

--@param jobName: string
--@param label: string|nil
--@return boolean [true when the society account exists or was created]
Bridge.Society.ensureAccount = function(jobName, label)
    if type(jobName) ~= 'string' or jobName == '' then return false end
    if ensuredAccounts[jobName] then return true end

    local name = ('society_%s'):format(jobName)
    local ok = pcall(function()
        if not MySQL.scalar.await('SELECT 1 FROM addon_account WHERE name = ?', { name }) then
            exports['esx_addonaccount']:AddSharedAccount({ name = name, label = label or jobName })
        end
    end)
    ensuredAccounts[jobName] = ok or nil
    return ok
end
