if (Config.Banking == 'auto' and checkResource('npk-banking')) or (Config.Banking ~= 'auto' and Config.Banking ~= 'standalone') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    Bridge.libs.print.info('[Banking] Loaded: standalone (bezposrednio na tabelach bankowych)')
end

Bridge.Banking = {}

local function clip(value, len)
    if value == nil then return nil end
    return tostring(value):sub(1, len)
end

local function placeholders(n)
    local out = {}
    for i = 1, n do out[i] = '?' end
    return table.concat(out, ', ')
end

Bridge.Banking.addHistory = function(data)
    if type(data) ~= 'table' then return false end

    return pcall(function()
        MySQL.insert.await([[
            INSERT INTO `transactions_history`
                (category, from_account, from_name, to_account, to_name, amount, reason, job, created_by, created_by_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            clip(data.category or 'transfer', 40),
            clip(data.from, 80), clip(data.fromName, 120),
            clip(data.to, 80), clip(data.toName, 120),
            math.floor(tonumber(data.amount) or 0),
            clip(data.reason, 255), clip(data.job, 60),
            clip(data.by, 60), clip(data.byName, 120),
        })
    end)
end

Bridge.Banking.getHistory = function(targets, limit)
    if type(targets) ~= 'table' or #targets == 0 then return {} end

    local params = {}
    for _, t in ipairs(targets) do params[#params + 1] = t end
    for _, t in ipairs(targets) do params[#params + 1] = t end
    params[#params + 1] = tonumber(limit) or 40

    local ph = placeholders(#targets)
    local ok, rows = pcall(function()
        return MySQL.query.await(
            "SELECT category, from_account, from_name, to_account, to_name, amount, reason, created_by_name, "
            .. "DATE_FORMAT(created_at, '%d.%m.%Y %H:%i') AS created_at FROM `transactions_history` "
            .. "WHERE from_account IN (" .. ph .. ") OR to_account IN (" .. ph .. ") ORDER BY id DESC LIMIT ?",
            params)
    end)

    return (ok and type(rows) == 'table') and rows or {}
end

Bridge.Banking.getIncomeToday = function(targets)
    if type(targets) ~= 'table' or #targets == 0 then return 0 end

    local ok, sum = pcall(function()
        return MySQL.scalar.await(
            'SELECT COALESCE(SUM(amount), 0) FROM `transactions_history` WHERE to_account IN ('
            .. placeholders(#targets) .. ') AND DATE(created_at) = CURDATE()', targets)
    end)

    return (ok and tonumber(sum)) or 0
end

Bridge.Banking.getIncomeByMonth = function(targets)
    local months = {}
    for i = 1, 12 do months[i] = 0 end
    if type(targets) ~= 'table' or #targets == 0 then return { months = months, total = 0 } end

    local ok, rows = pcall(function()
        return MySQL.query.await(
            'SELECT MONTH(created_at) AS m, COALESCE(SUM(amount), 0) AS total FROM `transactions_history` '
            .. 'WHERE to_account IN (' .. placeholders(#targets)
            .. ') AND YEAR(created_at) = YEAR(CURDATE()) GROUP BY MONTH(created_at)', targets)
    end)

    local total = 0
    if ok and type(rows) == 'table' then
        for _, r in ipairs(rows) do
            local m = tonumber(r.m) or 0
            if m >= 1 and m <= 12 then
                months[m] = tonumber(r.total) or 0
                total = total + months[m]
            end
        end
    end

    return { months = months, total = total }
end

Bridge.Banking.addInvoice = function(data)
    if type(data) ~= 'table' then return false end

    local target = data.target
    if type(target) == 'number' then
        target = Bridge.Framework and Bridge.Framework.getUniqueId(target)
    end
    if not target or target == '' then return false end

    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 then return false end

    local dueMinutes = tonumber(data.dueMinutes)
    local ok, id = pcall(function()
        if dueMinutes and dueMinutes > 0 then
            return MySQL.insert.await(
                'INSERT INTO `bank_invoices` (issuer_account, issuer_name, target, category, title, amount, due_at) '
                .. 'VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))',
                { clip(data.issuer, 80), clip(data.issuerName or 'System', 120), target,
                  clip(data.category or 'faktura', 40), clip(data.title or '', 255), amount, math.floor(dueMinutes) })
        end
        return MySQL.insert.await(
            'INSERT INTO `bank_invoices` (issuer_account, issuer_name, target, category, title, amount) VALUES (?, ?, ?, ?, ?, ?)',
            { clip(data.issuer, 80), clip(data.issuerName or 'System', 120), target,
              clip(data.category or 'faktura', 40), clip(data.title or '', 255), amount })
    end)

    return ok and id or false
end

Bridge.Banking.getInvoices = function(identifier)
    if not identifier or identifier == '' then return {} end

    local ok, rows = pcall(function()
        return MySQL.query.await(
            "SELECT id, issuer_account, issuer_name, category, title, amount, status, "
            .. "(status = 'pending' AND due_at IS NOT NULL AND due_at < NOW()) AS overdue "
            .. "FROM `bank_invoices` WHERE target = ? ORDER BY (status = 'pending') DESC, created_at DESC LIMIT 200",
            { identifier })
    end)

    return (ok and type(rows) == 'table') and rows or {}
end

Bridge.Banking.getPendingInvoices = function(targets)
    local list = type(targets) == 'table' and targets or { targets }
    if #list == 0 then return {} end

    local ok, rows = pcall(function()
        return MySQL.query.await(([[
            SELECT id, issuer_account, issuer_name, category, title, amount,
                   (due_at IS NOT NULL AND due_at < NOW()) AS overdue,
                   CASE WHEN due_at IS NULL THEN -1 ELSE TIMESTAMPDIFF(HOUR, NOW(), due_at) END AS remaining_h
            FROM `bank_invoices`
            WHERE status = 'pending' AND target IN (%s)
            ORDER BY (due_at IS NOT NULL AND due_at < NOW()) DESC, created_at ASC
            LIMIT 30
        ]]):format(placeholders(#list)), list)
    end)

    return (ok and type(rows) == 'table') and rows or {}
end

Bridge.Banking.payInvoice = function(playerId, invoiceId, accountId)
    local id = tonumber(invoiceId)
    if not id then return false, 'Brak faktury' end

    local inv = MySQL.single.await('SELECT * FROM `bank_invoices` WHERE id = ?', { id })
    if not inv then return false, 'Nie znaleziono faktury' end
    if inv.status == 'paid' then return false, 'Faktura juz oplacona' end

    local amount = tonumber(inv.amount) or 0
    if amount <= 0 then return false, 'Nieprawidlowa kwota' end

    local identifier = Bridge.Framework and Bridge.Framework.getUniqueId(playerId)
    if not identifier then return false, 'Gracz niedostepny' end
    if inv.target ~= identifier then return false, 'To nie Twoja platnosc' end

    local money = Bridge.Framework.getMoney(playerId)
    if not money or (tonumber(money.bank) or 0) < amount then return false, 'Brak srodkow na koncie' end

    Bridge.Framework.removeMoney(playerId, 'bank', amount)
    MySQL.update.await("UPDATE `bank_invoices` SET status = 'paid', paid_at = NOW() WHERE id = ?", { id })
    Bridge.Banking.credit(inv.issuer_account, amount, inv.title)
    Bridge.Banking.addHistory({
        category = inv.category or 'faktura',
        from = accountId or Bridge.Banking.getPlayerNumber(identifier),
        to = inv.issuer_account, toName = inv.issuer_name,
        amount = amount, reason = (inv.title ~= '' and inv.title) or 'Faktura',
    })

    return true, 'Oplacono fakture'
end

Bridge.Banking.getSocietyNumber = function(jobName)
    if not jobName or jobName == '' then return nil end
    local ok, number = pcall(function()
        return MySQL.scalar.await('SELECT acc_number FROM addon_account WHERE name = ? AND owner IS NULL',
            { 'society_' .. jobName })
    end)
    return (ok and number ~= '') and number or nil
end

Bridge.Banking.getPlayerNumber = function(identifier)
    if not identifier or identifier == '' then return nil end
    local ok, number = pcall(function()
        return MySQL.scalar.await('SELECT acc_number FROM users WHERE identifier = ?', { identifier })
    end)
    return (ok and number ~= '') and number or nil
end

Bridge.Banking.credit = function(accNumber, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if not accNumber or accNumber == '' or amount <= 0 then return false end

    if accNumber:sub(1, 8) == 'society_' then
        return Bridge.Society ~= nil
            and Bridge.Society.addMoney(nil, accNumber:sub(9), amount) == true
    end

    local addon = MySQL.single.await('SELECT name FROM addon_account WHERE acc_number = ? AND owner IS NULL', { accNumber })
    if addon and addon.name and addon.name:sub(1, 8) == 'society_' then
        return Bridge.Society ~= nil
            and Bridge.Society.addMoney(nil, addon.name:sub(9), amount) == true
    end

    local user = MySQL.single.await('SELECT identifier FROM users WHERE acc_number = ?', { accNumber })
    if user and user.identifier then
        local playerId = Bridge.Framework.getPlayerId(user.identifier)
        if playerId then
            return Bridge.Framework.addMoney(playerId, 'bank', amount)
        end

        local accounts = MySQL.scalar.await('SELECT accounts FROM users WHERE identifier = ?', { user.identifier })
        local decoded = {}
        if accounts and accounts ~= '' then
            local ok, parsed = pcall(json.decode, accounts)
            if ok and type(parsed) == 'table' then decoded = parsed end
        end
        decoded.bank = (tonumber(decoded.bank) or 0) + amount
        MySQL.update.await('UPDATE users SET accounts = ? WHERE identifier = ?', { json.encode(decoded), user.identifier })
        return true
    end

    local affected = MySQL.update.await('UPDATE `bank_accounts` SET balance = balance + ? WHERE acc_number = ?',
        { amount, accNumber })
    return (tonumber(affected) or 0) > 0
end

Bridge.Banking.getBalance = function(accNumber)
    if not accNumber or accNumber == '' then return 0 end

    if accNumber:sub(1, 8) == 'society_' then
        return (Bridge.Society and Bridge.Society.getMoney(nil, accNumber:sub(9))) or 0
    end

    local user = MySQL.single.await('SELECT accounts FROM users WHERE acc_number = ?', { accNumber })
    if user then
        local ok, parsed = pcall(json.decode, user.accounts or '{}')
        return (ok and type(parsed) == 'table' and tonumber(parsed.bank)) or 0
    end

    return tonumber(MySQL.scalar.await('SELECT balance FROM `bank_accounts` WHERE acc_number = ?', { accNumber })) or 0
end

Bridge.Banking.getTax = function()
    return 0
end
