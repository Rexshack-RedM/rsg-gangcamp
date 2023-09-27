local RSGCore = exports['rsg-core']:GetCoreObject()
local GangCampGroup = GetRandomIntInRange(0, 0xffffff)
local CoolDown = 0
local SpawnedProps = {}
local isBusy = false
local isLoggedIn = false
local PlayerGang = {}

--------------------------------------------------------------------------------------

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        PlayerGang = RSGCore.Functions.GetPlayerData().gang
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    PlayerGang = RSGCore.Functions.GetPlayerData().gang
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(JobInfo)
    PlayerGang = InfoGang
end)

--------------------------------------------------------------------------------------

-- set camp menu
function CampMenuPrompt()
    Citizen.CreateThread(function()
        local str ="Open Camp Menu"
        local wait = 0
        CampMenuPrompt = Citizen.InvokeNative(0x04F97DE45A519419)
        PromptSetControlAction(CampMenuPrompt, RSGCore.Shared.Keybinds['J'])
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(CampMenuPrompt, str)
        PromptSetEnabled(CampMenuPrompt, true)
        PromptSetVisible(CampMenuPrompt, true)
        PromptSetHoldMode(CampMenuPrompt, true)
        PromptSetGroup(CampMenuPrompt, GangCampGroup)
        PromptRegisterEnd(CampMenuPrompt)
    end)
end

--------------------------------------------------------------------------------------

-- spawn props
Citizen.CreateThread(function()
    while true do
        Wait(150)

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local InRange = false

        for i = 1, #Config.PlayerProps do
            local dist = GetDistanceBetweenCoords(pos.x, pos.y, pos.z, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z, true)
            if dist >= 50.0 then goto continue end

            local hasSpawned = false
            InRange = true

            for z = 1, #SpawnedProps do
                local p = SpawnedProps[z]

                if p.id == Config.PlayerProps[i].id then
                    hasSpawned = true
                end
            end

            if hasSpawned then goto continue end

            local modelHash = Config.PlayerProps[i].hash
            local data = {}
            
            if not HasModelLoaded(modelHash) then
                RequestModel(modelHash)
                while not HasModelLoaded(modelHash) do
                    Wait(1)
                end
            end
            
            data.id = Config.PlayerProps[i].id
            data.obj = CreateObject(modelHash, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z -1.2, false, false, false)
            SetEntityAsMissionEntity(data.obj, true)
            PlaceObjectOnGroundProperly(data.obj)
            Wait(1000)
            FreezeEntityPosition(data.obj, true)
            SetModelAsNoLongerNeeded(data.obj)

            SpawnedProps[#SpawnedProps + 1] = data
            hasSpawned = false

            ::continue::
        end

        if not InRange then
            Wait(5000)
        end
    end
end)

-- get closest prop
function GetClosestProp()
    local dist = 1000
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local prop = {}

    for i = 1, #Config.PlayerProps do
        local xd = GetDistanceBetweenCoords(pos.x, pos.y, pos.z, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z, true)

        if xd < dist then
            dist = xd
            prop = Config.PlayerProps[i]
        end
    end

    return prop
end

-- trigger promps
Citizen.CreateThread(function()
    CampMenuPrompt()
    while true do
        local t = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        t = 4
        for k, v in pairs(Config.PlayerProps) do
            if GetDistanceBetweenCoords(pos.x, pos.y, pos.z, v.x, v.y, v.z, true) < 1.3 and not IsPedInAnyVehicle(PlayerPedId(), false) then
                local proptype = v.proptype
                local gang = v.gang
                if proptype == 'tent' then
                
                    local label = CreateVarString(10, 'LITERAL_STRING', 'Gang Camp')
                    
                    PromptSetActiveGroupThisFrame(GangCampGroup, label)
                    
                    if PromptHasHoldModeCompleted(CampMenuPrompt) and CoolDown < 1 then
                        CoolDown = 1000
                        TriggerEvent('rsg-gangcamp:client:mainmenu', gang)
                    end
                end
            end
        end
        if CoolDown > 0 then
            CoolDown = CoolDown - 1
        end
        Wait(t)
    end
end)

-- camp menu
RegisterNetEvent('rsg-gangcamp:client:mainmenu', function(gang)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playergang = PlayerData.gang.name
    if playergang == gang then
        lib.registerContext({
            id = 'gangcamp_mainmenu',
            title = 'Gang Camp Menu',
            options = {
                {
                    title = 'Gang Menu',
                    description = 'boss can access the gang menu',
                    icon = 'fa-solid fa-user-tie',
                    event = 'rsg-gangmenu:client:mainmenu',
                    arrow = true
                },
                {
                    title = 'Gang Camp Items',
                    description = 'gang camp items',
                    icon = 'fa-solid fa-user-tie',
                    event = 'rsg-gangmenu:client:campitemsmenu',
                    args = { gang = playergang },
                    arrow = true
                },
            }
        })
        lib.showContext("gangcamp_mainmenu")
    else
        RSGCore.Functions.Notify('unauthorised access!', 'error', 3000)
    end
end)

-- camp deployed menu
RegisterNetEvent('rsg-gangmenu:client:campitemsmenu')
AddEventHandler('rsg-gangmenu:client:campitemsmenu', function(data)
    local options = {}
    for k, v in pairs(Config.PlayerProps) do
        if v.gang == data.gang then
            options[#options + 1] = {
                title = RSGCore.Shared.Items[v.proptype].label,
                description = 'description',
                icon = 'fa-solid fa-box',
                event = '',
                args = { },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'gangcamp_deployed',
            title = 'Deployed Items',
            menu = 'gangcamp_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('gangcamp_deployed')        
    end
end)

-- remove prop object
RegisterNetEvent('rsg-gangcamp:client:removePropObject')
AddEventHandler('rsg-gangcamp:client:removePropObject', function(prop)
    for i = 1, #SpawnedProps do
        local o = SpawnedProps[i]

        if o.id == prop then
            SetEntityAsMissionEntity(o.obj, false)
            FreezeEntityPosition(o.obj, false)
            DeleteObject(o.obj)
        end
    end
end)

-- update props
RegisterNetEvent('rsg-gangcamp:client:updatePropData')
AddEventHandler('rsg-gangcamp:client:updatePropData', function(data)
    Config.PlayerProps = data
end)

-- place prop
RegisterNetEvent('rsg-gangcamp:client:placeNewProp')
AddEventHandler('rsg-gangcamp:client:placeNewProp', function(proptype, pHash, item)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playergang = PlayerData.gang.name
    
    if playergang == 'none' then
        RSGCore.Functions.Notify('you are not in a gang!', 'error', 3000)
        return
    end

    local pos = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 3.0, 0.0)
    local ped = PlayerPedId()

    if CanPlacePropHere(pos) and not IsPedInAnyVehicle(PlayerPedId(), false) and not isBusy then
        isBusy = true
        local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
        FreezeEntityPosition(ped, true)
        TaskStartScenarioInPlace(ped, anim1, 0, true)
        Wait(10000)
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        TriggerServerEvent('rsg-gangcamp:server:removeitem', item, 1)
        TriggerServerEvent('rsg-gangcamp:server:newProp', proptype, pos, pHash, playergang)
        isBusy = false

        return
    end

    RSGCore.Functions.Notify('Too close to another campsite object!', 'error', 3000)

    Wait(3000)
end)

-- check to see if prop can be place here
function CanPlacePropHere(pos)
    local canPlace = true

    local ZoneTypeId = 1
    local x,y,z =  table.unpack(GetEntityCoords(PlayerPedId()))
    local town = Citizen.InvokeNative(0x43AD8FC02B429D33, x,y,z, ZoneTypeId)
    if town ~= false then
        canPlace = false
    end

    for i = 1, #Config.PlayerProps do
        if GetDistanceBetweenCoords(pos.x, pos.y, pos.z, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z, true) < 1.3 then
            canPlace = false
        end
    end
    
    return canPlace
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #SpawnedProps do
        local props = SpawnedProps[i].obj

        SetEntityAsMissionEntity(props, false)
        FreezeEntityPosition(props, false)
        DeleteObject(props)
    end
end)
