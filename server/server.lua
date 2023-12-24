local RSGCore = exports['rsg-core']:GetCoreObject()
local PropsLoaded = false
local CollectedPoop = {}

-----------------------------------------------------------------------

local function versionCheckPrint(_type, log)
    local color = _type == 'success' and '^2' or '^1'

    print(('^5['..GetCurrentResourceName()..']%s %s^7'):format(color, log))
end

local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/Rexshack-RedM/rsg-gangcamp/main/version.txt', function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

        if not text then 
            versionCheckPrint('error', 'Currently unable to run a version check.')
            return 
        end

        --versionCheckPrint('success', ('Current Version: %s'):format(currentVersion))
        --versionCheckPrint('success', ('Latest Version: %s'):format(text))
        
        if text == currentVersion then
            versionCheckPrint('success', 'You are running the latest version.')
        else
            versionCheckPrint('error', ('You are currently running an outdated version, please update to version %s'):format(text))
        end
    end)
end

-----------------------------------------------------------------------

-- use gangtent
RSGCore.Functions.CreateUseableItem("gangtent", function(source)
    local src = source
    TriggerClientEvent('rsg-gangcamp:client:placeNewProp', src, 'gangtent', `mp005_s_posse_tent_bountyhunter07x`, 'gangtent')
end)

-- use ganghitchpost
RSGCore.Functions.CreateUseableItem("ganghitchpost", function(source)
    local src = source
    TriggerClientEvent('rsg-gangcamp:client:placeNewProp', src, 'ganghitchpost', `p_hitchingpost01x`, 'ganghitchpost')
end)

-- use gangcookstation
RSGCore.Functions.CreateUseableItem("gangcookstation", function(source)
    local src = source
    TriggerClientEvent('rsg-gangcamp:client:placeNewProp', src, 'gangcookstation', `p_campfirecombined03x`, 'gangcookstation')
end)

-- use gangtorch
RSGCore.Functions.CreateUseableItem("gangtorch", function(source)
    local src = source
    TriggerClientEvent('rsg-gangcamp:client:placeNewProp', src, 'gangtorch', `p_torchpost01x`, 'gangtorch')
end)

-- get all prop data
RSGCore.Functions.CreateCallback('rsg-gangcamp:server:getallpropdata', function(source, cb, propid)
    MySQL.query('SELECT * FROM player_props WHERE propid = ?', {propid}, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

-----------------------------------------------------------------------

-- update prop data
CreateThread(function()
    while true do
        Wait(5000)

        if PropsLoaded then
            TriggerClientEvent('rsg-gangcamp:client:updatePropData', -1, Config.PlayerProps)
        end
    end
end)

CreateThread(function()
    TriggerEvent('rsg-gangcamp:server:getProps')
    PropsLoaded = true
end)

RegisterServerEvent('rsg-gangcamp:server:saveProp')
AddEventHandler('rsg-gangcamp:server:saveProp', function(data, propId, citizenid, gang, proptype)
    local datas = json.encode(data)

    MySQL.Async.execute('INSERT INTO player_props (properties, propid, citizenid, gang, proptype) VALUES (@properties, @propid, @citizenid, @gang, @proptype)',
    {
        ['@properties'] = datas,
        ['@propid'] = propId,
        ['@citizenid'] = citizenid,
        ['@gang'] = gang,
        ['@proptype'] = proptype
    })
end)

-- new prop
RegisterServerEvent('rsg-gangcamp:server:newProp')
AddEventHandler('rsg-gangcamp:server:newProp', function(proptype, location, heading, hash, gang)
    local src = source
    local propId = math.random(111111, 999999)
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid

    local PropData =
    {
        id = propId,
        proptype = proptype,
        x = location.x,
        y = location.y,
        z = location.z,
        h = heading,
        hash = hash,
        builder = Player.PlayerData.citizenid,
        gang = gang,
        buildttime = os.time()
    }

    local PropCount = 0

    for _, v in pairs(Config.PlayerProps) do
        if v.builder == Player.PlayerData.citizenid then
            PropCount = PropCount + 1
        end
    end

    if PropCount >= Config.MaxPropCount then
        TriggerClientEvent('RSGCore:Notify', src, 'you have deployed the max amount!', 'error')
    else
        table.insert(Config.PlayerProps, PropData)
        Player.Functions.RemoveItem(proptype, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[proptype], "remove")
        TriggerEvent('rsg-gangcamp:server:saveProp', PropData, propId, citizenid, gang, proptype)
        TriggerEvent('rsg-gangcamp:server:updateProps')
    end
end)

-- distory prop
RegisterServerEvent('rsg-gangcamp:server:destroyProp')
AddEventHandler('rsg-gangcamp:server:destroyProp', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    for k, v in pairs(Config.PlayerProps) do
        if v.id == data.propid then
            table.remove(Config.PlayerProps, k)
        end
    end

    TriggerClientEvent('rsg-gangcamp:client:removePropObject', src, data.propid)
    TriggerEvent('rsg-gangcamp:server:PropRemoved', data.propid)
    TriggerEvent('rsg-gangcamp:server:updateProps')
    Player.Functions.AddItem(data.item, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[data.item], "add")
end)

RegisterServerEvent('rsg-gangcamp:server:updateProps')
AddEventHandler('rsg-gangcamp:server:updateProps', function()
    local src = source

    TriggerClientEvent('rsg-gangcamp:client:updatePropData', src, Config.PlayerProps)
end)

-- update props
RegisterServerEvent('rsg-gangcamp:server:updateCampProps')
AddEventHandler('rsg-gangcamp:server:updateCampProps', function(id, data)
    local result = MySQL.query.await('SELECT * FROM player_props WHERE propid = @propid',
    {
        ['@propid'] = id
    })

    if not result[1] then return end

    local newData = json.encode(data)

    MySQL.Async.execute('UPDATE player_props SET properties = @properties WHERE propid = @id',
    {
        ['@properties'] = newData,
        ['@id'] = id
    })
end)

-- remove props
RegisterServerEvent('rsg-gangcamp:server:PropRemoved')
AddEventHandler('rsg-gangcamp:server:PropRemoved', function(propId)
    local result = MySQL.query.await('SELECT * FROM player_props')

    if not result then return end

    for i = 1, #result do
        local propData = json.decode(result[i].properties)

        if propData.id == propId then
            MySQL.Async.execute('DELETE FROM player_props WHERE id = @id',
            {
                ['@id'] = result[i].id
            })

            for k, v in pairs(Config.PlayerProps) do
                if v.id == propId then
                    table.remove(Config.PlayerProps, k)
                end
            end
        end
    end
end)

-- get props
RegisterServerEvent('rsg-gangcamp:server:getProps')
AddEventHandler('rsg-gangcamp:server:getProps', function()
    local result = MySQL.query.await('SELECT * FROM player_props')

    if not result[1] then return end

    for i = 1, #result do
        local propData = json.decode(result[i].properties)
        print('loading '..propData.proptype..' prop with ID: '..propData.id)
        table.insert(Config.PlayerProps, propData)
    end
end)

-- add credit
RegisterNetEvent('rsg-gangcamp:server:addcredit', function(newcredit, removemoney, propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    -- remove money
    Player.Functions.RemoveMoney("cash", removemoney, "gangcamp-credit")
    -- sql update
    MySQL.update('UPDATE player_props SET credit = ? WHERE propid = ?', {newcredit, propid})
    -- notify
    RSGCore.Functions.Notify(src, 'credit added', 'success')
    Wait(5000)
    RSGCore.Functions.Notify(src, 'credit is now $'..newcredit, 'primary')
end)

-- remove credit
RegisterNetEvent('rsg-gangcamp:server:removecredit', function(newcredit, addmoney, propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    -- remove money
    Player.Functions.AddMoney("cash", addmoney, "gangcamp-credit")
    -- sql update
    MySQL.update('UPDATE player_props SET credit = ? WHERE propid = ?', {newcredit, propid})
    -- notify
    RSGCore.Functions.Notify(src, 'credit removed', 'success')
    Wait(5000)
    RSGCore.Functions.Notify(src, 'credit is now $'..newcredit, 'primary')
end)

-- remove item
RegisterServerEvent('rsg-gangcamp:server:removeitem')
AddEventHandler('rsg-gangcamp:server:removeitem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    Player.Functions.RemoveItem(item, amount)

    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[item], "remove")
end)

--------------------------------------------------------------------------------------------------
-- gangcamp upkeep system
--------------------------------------------------------------------------------------------------
UpkeepInterval = function()
    local result = MySQL.query.await('SELECT * FROM player_props')

    if not result then goto continue end

    for i = 1, #result do
        local row = result[i]

        if row.credit >= Config.MaintenancePerCycle then
            local creditadjust = (row.credit - Config.MaintenancePerCycle)

            MySQL.update('UPDATE player_props SET credit = ? WHERE propid = ?',
            {
                creditadjust,
                row.propid
            })
        else
            MySQL.update('DELETE FROM player_props WHERE propid = ?', {row.propid})

            if Config.PurgeStorage then
                MySQL.update('DELETE FROM stashitems WHERE stash = ?', { 'gang_'..row.gang })
            end
            
            if Config.ServerNotify == true then
                print('object with the id of '..row.propid..' owned by the gang '..row.gang.. ' was deleted')
            end

            TriggerEvent('rsg-log:server:CreateLog', 'gangmenu', 'Gang Object Lost', 'red', row.gang..' prop with ID: '..row.propid..' has been lost due to non maintenance!')
        end
    end

    ::continue::

    print('gangcamp upkeep cycle complete')

    SetTimeout(Config.BillingCycle * (60 * 60 * 1000), UpkeepInterval) -- hours
    --SetTimeout(Config.BillingCycle * (60 * 1000), UpkeepInterval) -- mins (for testing)
end

SetTimeout(Config.BillingCycle * (60 * 60 * 1000), UpkeepInterval) -- hours
--SetTimeout(Config.BillingCycle * (60 * 1000), UpkeepInterval) -- mins (for testing)

--------------------------------------------------------------------------------------------------
-- version check
--------------------------------------------------------------------------------------------------
CheckVersion()
