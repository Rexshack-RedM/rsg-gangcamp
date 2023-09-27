local RSGCore = exports['rsg-core']:GetCoreObject()

local PropsLoaded = false
local CollectedPoop = {}

-----------------------------------------------------------------------

-- use tent
RSGCore.Functions.CreateUseableItem("tent", function(source)
    local src = source
    TriggerClientEvent('rsg-gangcamp:client:placeNewProp', src, 'tent', `mp005_s_posse_tent_bountyhunter07x`, 'tent')
end)

-- use hitch post
RSGCore.Functions.CreateUseableItem("hitchpost", function(source)
    local src = source
    TriggerClientEvent('rsg-gangcamp:client:placeNewProp', src, 'hitchpost', `p_hitchingpost01x`, 'hitchpost')
end)

-----------------------------------------------------------------------

-- remove item
RegisterServerEvent('rsg-gangcamp:server:removeitem')
AddEventHandler('rsg-gangcamp:server:removeitem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    Player.Functions.RemoveItem(item, amount)

    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[item], "remove")
end)

-----------------------------------------------------------------------

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
AddEventHandler('rsg-gangcamp:server:newProp', function(proptype, location, hash, gang)
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
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('you_already_have_objects_down',{MaxPropCount = Config.MaxPropCount}), 'error')
    else
        table.insert(Config.PlayerProps, PropData)
        TriggerEvent('rsg-gangcamp:server:saveProp', PropData, propId, citizenid, gang, proptype)
        TriggerEvent('rsg-gangcamp:server:updateProps')
    end
end)

--[[
-- check prop
RegisterServerEvent('rsg-gangcamp:server:propHasBeenHarvested')
AddEventHandler('rsg-gangcamp:server:propHasBeenHarvested', function(propId)
    for _, v in pairs(Config.PlayerProps) do
        if v.id == propId then
            v.beingHarvested = true
        end
    end

    TriggerEvent('rsg-gangcamp:server:updateProps')
end)
--]]

-- distory prop
RegisterServerEvent('rsg-gangcamp:server:destroyProp')
AddEventHandler('rsg-gangcamp:server:destroyProp', function(propId)
    local src = source

    for k, v in pairs(Config.PlayerProps) do
        if v.id == propId then
            table.remove(Config.PlayerProps, k)
        end
    end

    TriggerClientEvent('rsg-gangcamp:client:removePropObject', -1, propId)
    TriggerEvent('rsg-gangcamp:server:PropRemoved', propId)
    TriggerEvent('rsg-gangcamp:server:updateProps')
    TriggerClientEvent('RSGCore:Notify', src, 'distroyed', 'success')
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

--------------------------------------------------------------------------------------------------

-- gangcamp upkeep system
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

            TriggerEvent('rsg-log:server:CreateLog', 'gangmenu', 'Gang Object Lost', 'red', row.gang..' prop with ID: '..row.propid..' has been lost due to non maintenance!')
        end
    end

    ::continue::

    print('Gangcamp Upkeep Cycle Complete')

    SetTimeout(Config.BillingCycle * (60 * 60 * 1000), UpkeepInterval) -- hours
    --SetTimeout(Config.BillingCycle * (60 * 1000), UpkeepInterval) -- mins (for testing)
end

SetTimeout(Config.BillingCycle * (60 * 60 * 1000), UpkeepInterval) -- hours
--SetTimeout(Config.BillingCycle * (60 * 1000), UpkeepInterval) -- mins (for testing)

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
