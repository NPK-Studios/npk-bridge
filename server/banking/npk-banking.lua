if (Config.Banking == 'auto' and not checkResource('npk-banking')) or (Config.Banking ~= 'auto' and Config.Banking ~= 'npk-banking') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Banking] Loaded: npk-banking')
end

Bridge.Banking = {}

local BANK = 'npk-banking'

local function call(name, ...)
    if GetResourceState(BANK) ~= 'started' then return nil end
    local ok, result = pcall(function(...) return exports[BANK][name](exports[BANK], ...) end, ...)
    if not ok then
        if Config.Debug then
            Bridge.libs.print.error(('[Banking] export %s:%s zawiodl: %s'):format(BANK, name, tostring(result)))
        end
        return nil
    end
    return result
end

--@param data: table [{ category, from, fromName, to, toName, amount, reason, job, by, byName }]
--@return boolean [true jesli wpis trafil do historii]
Bridge.Banking.addHistory = function(data)
    if type(data) ~= 'table' then return false end
    return call('addBankHistory', data) == true
end

--@param targets: string[] [numery kont / nazwy society]
--@param limit: number|nil
--@return table[] [{ category, from_account, from_name, to_account, to_name, amount, reason, created_by_name, created_at }]
Bridge.Banking.getHistory = function(targets, limit)
    if type(targets) ~= 'table' or #targets == 0 then return {} end
    return call('getBankHistory', targets, limit or 40) or {}
end

--@param targets: string[] [numery kont / nazwy society]
--@return number [suma wplywow w biezacej dobie]
Bridge.Banking.getIncomeToday = function(targets)
    if type(targets) ~= 'table' or #targets == 0 then return 0 end
    return tonumber(call('getIncomeToday', targets)) or 0
end

--@param targets: string[] [numery kont / nazwy society]
--@return table [{ months = number[12], total = number }]
Bridge.Banking.getIncomeByMonth = function(targets)
    local empty = { months = {}, total = 0 }
    for i = 1, 12 do empty.months[i] = 0 end
    if type(targets) ~= 'table' or #targets == 0 then return empty end
    return call('getIncomeByMonth', targets) or empty
end

--@param data: table [{ target, amount, title, category, issuer, issuerName, dueMinutes?, interestRate?, interestCap? }]
--@return number|boolean [id faktury lub false]
Bridge.Banking.addInvoice = function(data)
    if type(data) ~= 'table' then return false end
    return call('addInvoice', data) or false
end

--@param identifier: string [identyfikator gracza]
--@return table[] [pelna lista faktur w formacie panelu bankowego]
Bridge.Banking.getInvoices = function(identifier)
    if not identifier or identifier == '' then return {} end
    return call('getInvoices', identifier) or {}
end

--@param targets: string | string[] [identyfikator gracza lub numery kont firmy]
--@return table[] [{ id, issuer_name, category, title, amount, overdue, remaining_h }]
Bridge.Banking.getPendingInvoices = function(targets)
    local list = type(targets) == 'table' and targets or { targets }
    if #list == 0 then return {} end
    return call('getPendingInvoices', list) or {}
end

--@param playerId: number [gracz oplacajacy fakture]
--@param invoiceId: number
--@param accountId: string|nil [konto, z ktorego oplacamy; domyslnie osobiste]
--@return boolean, string [sukces, komunikat]
Bridge.Banking.payInvoice = function(playerId, invoiceId, accountId)
    local ok, msg = call('payInvoice', playerId, invoiceId, accountId)
    return ok == true, msg or ''
end

--@param jobName: string [np. 'police']
--@return string|nil [numer konta firmowego]
Bridge.Banking.getSocietyNumber = function(jobName)
    if not jobName or jobName == '' then return nil end
    return call('GetSocietyNumber', jobName)
end

--@param identifier: string [identyfikator gracza]
--@return string|nil [numer konta osobistego]
Bridge.Banking.getPlayerNumber = function(identifier)
    if not identifier or identifier == '' then return nil end
    return call('GetPlayerNumber', identifier)
end

--@param accNumber: string
--@param amount: number
--@param reason: string|nil
--@return boolean
Bridge.Banking.credit = function(accNumber, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if not accNumber or accNumber == '' or amount <= 0 then return false end
    return call('creditAccount', accNumber, amount, reason) == true
end

--@param accNumber: string
--@return number [saldo konta]
Bridge.Banking.getBalance = function(accNumber)
    if not accNumber or accNumber == '' then return 0 end
    return tonumber(call('getAccountBalance', accNumber)) or 0
end

--@param key: string [klucz podatku]
--@param amount: number|nil [gdy podane, zwraca kwote podatku zamiast stawki]
--@return number
Bridge.Banking.getTax = function(key, amount)
    return tonumber(call('GetBankTax', key, amount)) or 0
end
