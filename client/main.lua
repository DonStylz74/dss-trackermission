local ESX = exports['es_extended']:getSharedObject()

local trackerBlip = nil
local trackerState = nil
local trackerCar = nil
local trackerLocation = nil
local startedGPS = 0
local trackerPoliceBlip = nil
local trackerPoliceCar = nil
local playerTrackerSignalBlip = nil
local missionChoice = nil
local selectedRouteData = nil
local routeStarted = false
local buyerPed = nil
local buyerTargetName = 'dss_tracker_collect_vehicle_cash'
local handoffInProgress = false
local missionNPC = nil
local missionNPCTargetName = 'dss_tracker_mission_npc'
local gpsTargetName = 'dss_tracker_remove_gps'
local gpsFallbackTargetName = 'dss_tracker_remove_gps_front'

RegisterNetEvent('kd_trucker:client:notification', function(message, notificationType, duration)
    ESX.ShowNotification(message, notificationType or 'info', duration or 5000)
end)

local function RemoveTrackerBlip()
    if trackerBlip and DoesBlipExist(trackerBlip) then
        RemoveBlip(trackerBlip)
    end
    trackerBlip = nil
end

-- Local-only signal indicator for the mission thief. This is separate from
-- the police GPS blip and remains attached to the stolen vehicle until the
-- tracker has actually been removed.
local function RemovePlayerTrackerSignalBlip()
    if playerTrackerSignalBlip and DoesBlipExist(playerTrackerSignalBlip) then
        RemoveBlip(playerTrackerSignalBlip)
    end
    playerTrackerSignalBlip = nil
end

local function CreatePlayerTrackerSignalBlip()
    RemovePlayerTrackerSignalBlip()

    if not trackerCar or not DoesEntityExist(trackerCar) then return end

    playerTrackerSignalBlip = AddBlipForEntity(trackerCar)
    SetBlipSprite(playerTrackerSignalBlip, 161)
    SetBlipScale(playerTrackerSignalBlip, 1.0)
    SetBlipDisplay(playerTrackerSignalBlip, 2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Tracker Signal Active')
    EndTextCommandSetBlipName(playerTrackerSignalBlip)
end

local function RemoveBuyerTarget()
    if buyerPed and DoesEntityExist(buyerPed) then
        exports.ox_target:removeLocalEntity(buyerPed, buyerTargetName)
    end
end

local function ResetMissionVariables()
    RemoveTrackerBlip()
    RemovePlayerTrackerSignalBlip()
    trackerState = nil
    trackerCar = nil
    trackerLocation = nil
    startedGPS = 0
    missionChoice = nil
    selectedRouteData = nil
    routeStarted = false
    handoffInProgress = false
    buyerPed = nil
end

local function RequestEntityControl(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local endTime = GetGameTimer() + (timeout or 2000)

    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < endTime do
        Wait(50)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

local function StartMissionFromNPC()
    ESX.TriggerServerCallback('kd_trucker:callback:canStartTracker', function(canStart)
        if not canStart then
            ESX.ShowNotification(Config.lang['mission_in_progress'], 'info', 5000)
            return
        end

        TriggerServerEvent('kd_trucker:server:startTucker')
    end)
end

local function RegisterNPCMenus()
    local shopOptions = {}
    for _, entry in ipairs((Config.NPCShop and Config.NPCShop.items) or {}) do
        local itemName = entry.item
        local itemLabel = entry.label or itemName
        local price = math.max(0, tonumber(entry.price) or 0)
        local count = math.max(1, math.floor(tonumber(entry.count) or 1))

        shopOptions[#shopOptions + 1] = {
            title = itemLabel,
            description = ('$%s%s'):format(price, count > 1 and (' • x' .. count) or ''),
            icon = 'basket-shopping',
            onSelect = function()
                TriggerServerEvent('kd_trucker:server:purchaseItem', itemName)
            end
        }
    end

    if #shopOptions == 0 then
        shopOptions[1] = {
            title = Config.lang['shop_empty'],
            icon = 'ban',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'dss_tracker_shop_menu',
        title = Config.lang['shop_title'],
        menu = 'dss_tracker_npc_menu',
        options = shopOptions
    })

    lib.registerContext({
        id = 'dss_tracker_npc_menu',
        title = Config.lang['npc_menu_title'],
        options = {
            {
                title = Config.lang['purchase_items'],
                description = Config.lang['purchase_items_desc'],
                icon = 'basket-shopping',
                menu = 'dss_tracker_shop_menu'
            },
            {
                title = Config.lang['start_mission'],
                description = Config.lang['start_mission_desc'],
                icon = 'car-side',
                onSelect = StartMissionFromNPC
            }
        }
    })
end

Citizen.CreateThread(function()
    Wait(1000)
    RegisterNPCMenus()

    ESX.TriggerServerCallback('kd_trucker:callback:GetNPCPosition', function(currentNPCPosition)
        local model = joaat(Config.NPC.model)

        if not IsModelInCdimage(model) or not IsModelValid(model) then
            print(('[dss-trackermission] Invalid NPC model: %s'):format(Config.NPC.model))
            return
        end

        lib.requestModel(model, 15000)
        missionNPC = CreatePed(4, model, currentNPCPosition.x, currentNPCPosition.y,
            currentNPCPosition.z, currentNPCPosition.w, false, true)
        SetEntityCoordsNoOffset(missionNPC, currentNPCPosition.x, currentNPCPosition.y, currentNPCPosition.z, true, false, false)
        FreezeEntityPosition(missionNPC, true)
        SetEntityInvincible(missionNPC, true)
        SetBlockingOfNonTemporaryEvents(missionNPC, true)
        SetModelAsNoLongerNeeded(model)

        exports.ox_target:addLocalEntity(missionNPC, {{
            name = missionNPCTargetName,
            icon = 'fa-regular fa-circle-check',
            label = Config.lang['talk_to_npc'],
            distance = 2.0,
            onSelect = function()
                lib.showContext('dss_tracker_npc_menu')
            end
        }})
    end)
end)

local function GetDistanceBetweenTwoCoords(coords1, coords2)
    return math.ceil(math.sqrt((coords2.x - coords1.x) ^ 2 + (coords2.y - coords1.y) ^ 2))
end

RegisterNetEvent('kd_trucker:client:truckerDestroy', function()
    RemoveBuyerTarget()
    if buyerPed and DoesEntityExist(buyerPed) then
        DeleteEntity(buyerPed)
    end
    if trackerCar and DoesEntityExist(trackerCar) then
        DeleteEntity(trackerCar)
    end
    ResetMissionVariables()
end)

RegisterNetEvent('kd_trucker:client:startTucker', function(data)
    local carModelName = Config.carModels[math.random(1, #Config.carModels)]
    local carModel = joaat(carModelName)

    if not IsModelInCdimage(carModel) or not IsModelAVehicle(carModel) then
        print(('[dss-trackermission] Invalid vehicle model: %s'):format(carModelName))
        TriggerServerEvent('kd_trucker:server:truckerDestroy')
        return
    end

    SetNewWaypoint(data.area.x, data.area.y)
    local radius = tonumber(data.searchRadius) or 200.0
    trackerBlip = AddBlipForRadius(data.area, radius)
    SetBlipAlpha(trackerBlip, 150)
    SetBlipColour(trackerBlip, 49)
    trackerState = 1
    missionChoice = nil
    selectedRouteData = nil
    routeStarted = false
    handoffInProgress = false

    lib.requestModel(carModel, 15000)
    trackerCar = CreateVehicle(carModel, data.carPosition.x, data.carPosition.y, data.carPosition.z, data.carPosition.w, true, true)
    SetEntityCoordsNoOffset(trackerCar, data.carPosition, false, false, false)
    SetEntityHeading(trackerCar, data.carPosition.w)
    SetModelAsNoLongerNeeded(carModel)

    -- Use the vehicle's proper GTA display label in the mission notification.
    -- Add-on vehicles without a valid GXT label fall back to their display/model name.
    local vehicleDisplayName = GetDisplayNameFromVehicleModel(carModel)
    local vehicleLabel = GetLabelText(vehicleDisplayName)

    if not vehicleLabel or vehicleLabel == '' or vehicleLabel == 'NULL' then
        if vehicleDisplayName and vehicleDisplayName ~= '' and vehicleDisplayName ~= 'CARNOTFOUND' then
            vehicleLabel = vehicleDisplayName
        else
            vehicleLabel = carModelName
        end
    end

    ESX.ShowNotification(string.format(Config.lang['car_location'], vehicleLabel, GetVehicleNumberPlateText(trackerCar)), 'info', 13000)
    TriggerServerEvent('kd_trucker:server:setTruckerCar', NetworkGetNetworkIdFromEntity(trackerCar))

    Citizen.CreateThread(function()
        local playerPed = PlayerPedId()
        while trackerState == 1 do
            if #(GetEntityCoords(playerPed) - vector3(data.area.x, data.area.y, data.area.z)) <= radius then
                ESX.ShowNotification(Config.lang['right_spot'], 'info', 7000)
                trackerState = 2
            end
            Wait(1000)
        end
    end)

    Citizen.SetTimeout(Config.AFKProtect * 1000 * 60, function()
        if trackerState == 1 then
            ESX.ShowNotification(Config.lang['afk'], 'error', 5000)
            TriggerServerEvent('kd_trucker:server:truckerDestroy')
        end
    end)
end)

local function SubmitMissionChoice(choice)
    if choice ~= 'sell' and choice ~= 'chop' then return end
    missionChoice = choice
    TriggerServerEvent('kd_trucker:server:selectMissionRoute', choice)
end

AddEventHandler('esx:enteredVehicle', function(vehicle, plate)
    if trackerState ~= 2 then return end

    if vehicle == trackerCar or GetVehicleNumberPlateText(trackerCar) == plate then
        RemoveTrackerBlip()
        trackerState = 3
        startedGPS = GetGameTimer()

        ESX.ShowNotification(Config.lang['rid_of_gps'], 'success', 13000)

        -- Player-only tracker signal indicator. Show sprite 161 only while
        -- the stolen vehicle's engine is running and the tracker is still fitted.
        Citizen.CreateThread(function()
            while trackerState == 3 do
                local engineRunning = trackerCar and DoesEntityExist(trackerCar)
                    and GetIsVehicleEngineRunning(trackerCar)

                if engineRunning then
                    if not playerTrackerSignalBlip or not DoesBlipExist(playerTrackerSignalBlip) then
                        CreatePlayerTrackerSignalBlip()
                    end
                else
                    RemovePlayerTrackerSignalBlip()
                end

                Wait(250)
            end

            RemovePlayerTrackerSignalBlip()
        end)

        Citizen.CreateThread(function()
            while trackerState == 3 do
                TriggerServerEvent('kd_trucker:server:policeGPS', GetEntityCoords(trackerCar))
                Wait(500)
            end
        end)

    end
end)

-- Exiting the stolen vehicle no longer completes a Sell mission. The player
-- must deliver it, walk to the buyer NPC and collect the payment via ox_target.
AddEventHandler('esx:exitedVehicle', function()
end)

RegisterNetEvent('kd_trucker:client:GPSRemoved', function()
    Citizen.SetTimeout(Config.GPSRemove, function()
        if trackerPoliceBlip ~= nil then
            RemoveBlip(trackerPoliceBlip)
            trackerPoliceBlip = nil
        end
    end)
end)

RegisterNetEvent('kd_trucker:client:GPSRemoveForced', function()
    if trackerPoliceBlip ~= nil then
        RemoveBlip(trackerPoliceBlip)
        trackerPoliceBlip = nil
    end
end)

RegisterNetEvent('kd_trucker:client:policeGPS', function(coords, vehicleNetID)
    if vehicleNetID ~= trackerPoliceCar then
        trackerPoliceCar = vehicleNetID
    end

    if trackerPoliceBlip and DoesBlipExist(trackerPoliceBlip) then
        RemoveBlip(trackerPoliceBlip)
    end

    trackerPoliceBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(trackerPoliceBlip, 227)
    SetBlipScale(trackerPoliceBlip, 1.5)
    SetBlipDisplay(trackerPoliceBlip, 2)
    SetBlipColour(trackerPoliceBlip, 49)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.lang['stolen_vehicle'])
    EndTextCommandSetBlipName(trackerPoliceBlip)
end)

local inAction = false
local StartSelectedRoute

local function MovePlayerToBuyerHandoffPosition(playerPed, targetPed)
    local buyerCoords = GetEntityCoords(targetPed)
    local playerCoords = GetEntityCoords(playerPed)
    local desiredDistance = Config.SellBuyer.handoffDistance or 0.75
    local dx = playerCoords.x - buyerCoords.x
    local dy = playerCoords.y - buyerCoords.y
    local length = math.sqrt((dx * dx) + (dy * dy))

    -- Keep the approach on the side the player is already standing on, but
    -- bring them close enough for the give/take animation to look connected.
    if length < 0.01 then
        local fallback = GetOffsetFromEntityInWorldCoords(targetPed, 0.0, desiredDistance, 0.0)
        dx = fallback.x - buyerCoords.x
        dy = fallback.y - buyerCoords.y
        length = math.sqrt((dx * dx) + (dy * dy))
    end

    if length > 0.01 then
        local targetCoords = vector3(
            buyerCoords.x + ((dx / length) * desiredDistance),
            buyerCoords.y + ((dy / length) * desiredDistance),
            playerCoords.z
        )

        if #(playerCoords - targetCoords) > 0.08 then
            local faceHeading = GetHeadingFromVector_2d(buyerCoords.x - targetCoords.x, buyerCoords.y - targetCoords.y)
            TaskGoStraightToCoord(playerPed, targetCoords.x, targetCoords.y, targetCoords.z,
                Config.SellBuyer.handoffWalkSpeed or 1.0, 2500, faceHeading, 0.05)

            local timeout = GetGameTimer() + 2500
            while GetGameTimer() < timeout and #(GetEntityCoords(playerPed) - targetCoords) > 0.12 do
                Wait(50)
            end

            ClearPedTasks(playerPed)
        end
    end
end

local function CollectVehicleCash()
    if handoffInProgress or trackerState ~= 4 or missionChoice ~= 'sell' then return end
    if not buyerPed or not DoesEntityExist(buyerPed) or not trackerCar or not DoesEntityExist(trackerCar) then return end

    if IsPedInAnyVehicle(PlayerPedId(), false) then
        ESX.ShowNotification(Config.lang['exit_vehicle_for_cash'], 'error', 4000)
        return
    end

    if #(GetEntityCoords(trackerCar) - trackerLocation) > (Config.SellBuyer.vehicleDeliveryRadius or 20.0) then
        ESX.ShowNotification(Config.lang['park_vehicle'], 'error', 5000)
        return
    end

    handoffInProgress = true
    local playerPed = PlayerPedId()

    MovePlayerToBuyerHandoffPosition(playerPed, buyerPed)

    -- Temporarily unfreeze the buyer so both peds can be aligned reliably
    -- for the cash handoff animation. The buyer is frozen again once the
    -- handoff animation is complete.
    FreezeEntityPosition(buyerPed, false)
    ClearPedTasks(buyerPed)

    local playerCoords = GetEntityCoords(playerPed)
    local buyerCoords = GetEntityCoords(buyerPed)

    local playerHeading = GetHeadingFromVector_2d(
        buyerCoords.x - playerCoords.x,
        buyerCoords.y - playerCoords.y
    )

    local buyerHeading = GetHeadingFromVector_2d(
        playerCoords.x - buyerCoords.x,
        playerCoords.y - buyerCoords.y
    )

    SetEntityHeading(playerPed, playerHeading)
    SetEntityHeading(buyerPed, buyerHeading)
    Wait(250)

    local cashProp = nil
    local cashModel = joaat(Config.SellBuyer.cashProp or 'prop_anim_cash_pile_01')
    if IsModelInCdimage(cashModel) and IsModelValid(cashModel) then
        lib.requestModel(cashModel, 10000)
        local buyerCoords = GetEntityCoords(buyerPed)
        cashProp = CreateObject(cashModel, buyerCoords.x, buyerCoords.y, buyerCoords.z + 0.2, true, true, false)
        if cashProp and DoesEntityExist(cashProp) then
            AttachEntityToEntity(cashProp, buyerPed, GetPedBoneIndex(buyerPed, Config.SellBuyer.cashPropBone or 57005),
                0.124, 0.029, -0.011, 25.716, 12.586, -3.299, true, true, false, true, 1, true)
        end
        SetModelAsNoLongerNeeded(cashModel)
    end

    lib.requestAnimDict('mp_common')
    TaskPlayAnim(playerPed, 'mp_common', 'givetake1_a', 8.0, -8.0, 1800, 0, 0.0, false, false, false)
    TaskPlayAnim(buyerPed, 'mp_common', 'givetake1_b', 8.0, -8.0, 1800, 0, 0.0, false, false, false)

    Wait(800)
    if cashProp and DoesEntityExist(cashProp) then
        DetachEntity(cashProp, true, true)
        AttachEntityToEntity(cashProp, playerPed, GetPedBoneIndex(playerPed, Config.SellBuyer.cashPropBone or 57005),
            0.124, 0.029, -0.011, 25.716, 12.586, -3.299, true, true, false, true, 1, true)
    end

    Wait(1000)
    if cashProp and DoesEntityExist(cashProp) then
        DeleteEntity(cashProp)
    end
    RemoveAnimDict('mp_common')

    -- Return the buyer to the stationary waiting state until the server
    -- confirms the sale and the configured post-sale behaviour begins.
    if buyerPed and DoesEntityExist(buyerPed) then
        FreezeEntityPosition(buyerPed, true)
    end

    TriggerServerEvent('kd_trucker:server:collectVehicleCash')
end

local function SpawnSellBuyer(npcCoords)
    if buyerPed and DoesEntityExist(buyerPed) then return end

    local model = joaat(Config.SellBuyer.model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        print(('[dss-trackermission] Invalid SellBuyer model: %s'):format(Config.SellBuyer.model))
        ESX.ShowNotification(Config.lang['buyer_spawn_error'], 'error', 5000)
        return
    end

    lib.requestModel(model, 15000)
    buyerPed = CreatePed(4, model, npcCoords.x, npcCoords.y, npcCoords.z, npcCoords.w, false, true)
    SetEntityHeading(buyerPed, npcCoords.w)
    FreezeEntityPosition(buyerPed, true)
    SetEntityInvincible(buyerPed, true)
    SetBlockingOfNonTemporaryEvents(buyerPed, true)
    SetModelAsNoLongerNeeded(model)

    exports.ox_target:addLocalEntity(buyerPed, {{
        name = buyerTargetName,
        icon = 'fa-solid fa-money-bill-wave',
        label = Config.lang['collect_cash'],
        distance = Config.SellBuyer.targetDistance or 2.0,
        canInteract = function(entity)
            if entity ~= buyerPed or handoffInProgress or trackerState ~= 4 or missionChoice ~= 'sell' then
                return false
            end
            if not trackerCar or not DoesEntityExist(trackerCar) then return false end
            return #(GetEntityCoords(trackerCar) - trackerLocation) <= (Config.SellBuyer.vehicleDeliveryRadius or 20.0)
        end,
        onSelect = function()
            CollectVehicleCash()
        end
    }})
end

StartSelectedRoute = function()
    if routeStarted or trackerState ~= 4 or not missionChoice or not selectedRouteData then return end
    routeStarted = true

    if missionChoice == 'chop' then
        local chopLoc = selectedRouteData
        ESX.ShowNotification(Config.lang['gps_chop'], 'info', 15000)

        RemoveTrackerBlip()
        trackerBlip = AddBlipForCoord(chopLoc.x, chopLoc.y, chopLoc.z)
        SetBlipSprite(trackerBlip, Config.chopBlipSprite or 271)
        SetBlipScale(trackerBlip, Config.chopBlipScale or 1.0)
        SetBlipDisplay(trackerBlip, 2)
        SetBlipColour(trackerBlip, Config.chopBlipColour or 73)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.lang['chop'])
        EndTextCommandSetBlipName(trackerBlip)
        SetBlipRoute(trackerBlip, true)

        Citizen.CreateThread(function()
            Wait(60000)
            RemoveTrackerBlip()
        end)

        TriggerServerEvent('kd_trucker:server:endTrucker2')
    elseif missionChoice == 'sell' then
        trackerLocation = vector3(selectedRouteData.vehicle.x, selectedRouteData.vehicle.y, selectedRouteData.vehicle.z)
        ESX.ShowNotification(Config.lang['gps_sell'], 'info', 10000)

        RemoveTrackerBlip()
        trackerBlip = AddBlipForCoord(trackerLocation.x, trackerLocation.y, trackerLocation.z)
        SetBlipSprite(trackerBlip, 271)
        SetBlipScale(trackerBlip, 1.0)
        SetBlipDisplay(trackerBlip, 2)
        SetBlipColour(trackerBlip, 73)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.lang['drop'])
        EndTextCommandSetBlipName(trackerBlip)
        SetBlipRoute(trackerBlip, true)

        SpawnSellBuyer(selectedRouteData.npc)
    end
end

RegisterNetEvent('kd_trucker:client:routeSelected', function(choice, routeData)
    missionChoice = choice
    selectedRouteData = routeData

    if choice == 'sell' then
        ESX.ShowNotification(Config.lang['sell_selected'], 'info', 5000)
    else
        ESX.ShowNotification(Config.lang['chop_selected'], 'info', 5000)
    end

    if trackerState == 4 then
        StartSelectedRoute()
    end
end)

local function GPSDestroyed()
    trackerState = 4
    RemovePlayerTrackerSignalBlip()
    TriggerServerEvent('kd_trucker:server:GPSRemoved')
    ESX.ShowNotification(Config.lang['gps_off'], 'info', 10000)

    if not missionChoice then
        local result = lib.alertDialog({
            header = Config.lang['choice_title'],
            content = Config.lang['choice_message'],
            centered = true,
            cancel = true,
            labels = {
                confirm = Config.lang['sell'],
                cancel = Config.lang['chop']
            }
        })

        if result == 'confirm' then
            SubmitMissionChoice('sell')
        elseif result == 'cancel' then
            SubmitMissionChoice('chop')
        else
            ESX.ShowNotification(Config.lang['choice_required'], 'error', 5000)
            trackerState = 3
            return
        end
    end

    StartSelectedRoute()
end

local function GetTrackerRemovalPosition(vehicle)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))

    -- Centre the player directly in front of the vehicle and keep them close
    -- enough to naturally reach into the engine bay once the bonnet opens.
    local front = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, maxDim.y + 0.20, 0.0)
    local foundGround, groundZ = GetGroundZFor_3dCoord(front.x, front.y, front.z + 2.0, false)
    if foundGround then
        front = vector3(front.x, front.y, groundZ)
    else
        front = vector3(front.x, front.y, GetEntityCoords(PlayerPedId()).z)
    end
    return front
end

local function GetTrackerRemovalFacingPoint(vehicle)
    local bonnetBone = GetEntityBoneIndexByName(vehicle, 'bonnet')
    if bonnetBone ~= -1 then
        return GetWorldPositionOfEntityBone(vehicle, bonnetBone)
    end

    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    -- Fallback point just inside the front/engine area for vehicles without
    -- a usable bonnet bone.
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, maxDim.y * 0.55, maxDim.z * 0.35)
end

local function MovePlayerToVehicleFront(vehicle)
    local playerPed = PlayerPedId()
    local target = GetTrackerRemovalPosition(vehicle)
    local facePoint = GetTrackerRemovalFacingPoint(vehicle)
    local targetHeading = GetHeadingFromVector_2d(
        facePoint.x - target.x,
        facePoint.y - target.y
    )

    -- Give the movement task the correct final heading immediately rather
    -- than walking to the point at heading 0.0 and rotating afterwards.
    if #(GetEntityCoords(playerPed) - target) > 0.45 then
        TaskGoStraightToCoord(playerPed, target.x, target.y, target.z, 1.0, 2200, targetHeading, 0.10)
        local timeout = GetGameTimer() + 2200
        while #(GetEntityCoords(playerPed) - target) > 0.45 and GetGameTimer() < timeout do
            Wait(50)
        end
        ClearPedTasks(playerPed)
    end

    -- Snap only the heading, not the position, so the final pose is square
    -- to the centre of the bonnet/engine bay on sedans and larger vehicles.
    local currentPos = GetEntityCoords(playerPed)
    facePoint = GetTrackerRemovalFacingPoint(vehicle)
    local finalHeading = GetHeadingFromVector_2d(
        facePoint.x - currentPos.x,
        facePoint.y - currentPos.y
    )
    SetEntityHeading(playerPed, finalHeading)
    Wait(200)
end

local function FinishTrackerRemoval(success, vehicle)
    local playerPed = PlayerPedId()
    StopAnimTask(playerPed, (Config.GPSRemoval.animation or {}).dict or 'amb@prop_human_bum_bin@base',
        (Config.GPSRemoval.animation or {}).clip or 'base', 2.0)
    ClearPedSecondaryTask(playerPed)

    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleDoorShut(vehicle, 4, false)
    end

    inAction = false

    if not success then
        ESX.ShowNotification(Config.lang['gps_minigame_failed'], 'error', 5000)
        return
    end

    GPSDestroyed()
    TriggerServerEvent('kd_trucker:server:removeitem', Config.RequireItem)
end

local function StartRemovalAnimation(playerPed)
    local anim = Config.GPSRemoval.animation or {}
    local dict = anim.dict or 'amb@prop_human_bum_bin@base'
    local clip = anim.clip or 'base'
    lib.requestAnimDict(dict)
    TaskPlayAnim(playerPed, dict, clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
end

local function hackSuccess(vehicle)
    if inAction or not vehicle or not DoesEntityExist(vehicle) then return end
    inAction = true

    local playerPed = PlayerPedId()
    MovePlayerToVehicleFront(vehicle)

    RequestEntityControl(vehicle, 2000)
    SetVehicleDoorOpen(vehicle, 4, false, false)
    Wait(500)

    StartRemovalAnimation(playerPed)

    local removalConfig = Config.GPSRemoval or {}
    local minigame = string.lower(removalConfig.minigame or 'none')

    if minigame == 'none' then
        local completed = lib.progressBar({
            duration = tonumber(removalConfig.noneDuration) or 20000,
            label = Config.lang['taking_off_gps'],
            useWhileDead = false,
            canCancel = false,
            disable = {
                move = true,
                car = true,
                combat = true
            }
        })
        FinishTrackerRemoval(completed == true, vehicle)
        return
    end

    if minigame ~= 'mgc' then
        print(('[dss-trackermission] Invalid Config.GPSRemoval.minigame: %s. Use mgc or none.'):format(tostring(minigame)))
        FinishTrackerRemoval(false, vehicle)
        return
    end

    local resourceName = removalConfig.mgcResource or 'mgc'
    if GetResourceState(resourceName) ~= 'started' then
        StopAnimTask(playerPed, (removalConfig.animation or {}).dict or 'amb@prop_human_bum_bin@base',
            (removalConfig.animation or {}).clip or 'base', 2.0)
        SetVehicleDoorShut(vehicle, 4, false)
        inAction = false
        ESX.ShowNotification(Config.lang['gps_minigame_missing'], 'error', 7000)
        return
    end

    exports[resourceName]:start_game({
        game = removalConfig.game or 'frequency_jam',
        data = removalConfig.data or { dials = 3, timer = 150000, precision = 3 }
    }, function(result)
        FinishTrackerRemoval(result and result.success == true, vehicle)
    end)
end

RegisterNetEvent('kd_trucker:client:sellCompleted', function(reward, driveAway)
    if not buyerPed or not DoesEntityExist(buyerPed) or not trackerCar or not DoesEntityExist(trackerCar) then
        ESX.ShowNotification(string.format(Config.lang['vehicle_sold'], reward), 'success', 6000)
        ResetMissionVariables()
        return
    end

    local missionBuyer = buyerPed
    local missionVehicle = trackerCar
    local shouldDriveAway = driveAway ~= false

    RemoveTrackerBlip()
    RemoveBuyerTarget()
    ESX.ShowNotification(string.format(Config.lang['vehicle_sold'], reward), 'success', 6000)

    trackerState = nil
    missionChoice = nil
    selectedRouteData = nil
    routeStarted = false

    SetBlockingOfNonTemporaryEvents(missionBuyer, true)

    Citizen.CreateThread(function()
        if shouldDriveAway then
            -- Existing behaviour: buyer walks to the sold vehicle, enters it and drives away.
            FreezeEntityPosition(missionBuyer, false)
            SetVehicleDoorsLocked(missionVehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(missionVehicle, false)
            SetVehicleUndriveable(missionVehicle, false)

            TaskGoToEntity(missionBuyer, missionVehicle, -1, 2.0, 1.5, 0.0, 0)

            local approachTimeout = GetGameTimer() + 12000
            while DoesEntityExist(missionBuyer) and DoesEntityExist(missionVehicle)
                and #(GetEntityCoords(missionBuyer) - GetEntityCoords(missionVehicle)) > 4.0
                and GetGameTimer() < approachTimeout do
                Wait(250)
            end

            if DoesEntityExist(missionBuyer) and DoesEntityExist(missionVehicle) then
                TaskEnterVehicle(missionBuyer, missionVehicle, 10000, -1, 1.5, 1, 0)

                local enterTimeout = GetGameTimer() + 10000
                while DoesEntityExist(missionBuyer) and DoesEntityExist(missionVehicle)
                    and not IsPedInVehicle(missionBuyer, missionVehicle, false)
                    and GetGameTimer() < enterTimeout do
                    Wait(250)
                end

                -- Fallback only if pathing cannot find the driver's door.
                if DoesEntityExist(missionBuyer) and DoesEntityExist(missionVehicle)
                    and not IsPedInVehicle(missionBuyer, missionVehicle, false) then
                    TaskWarpPedIntoVehicle(missionBuyer, missionVehicle, -1)
                    Wait(250)
                end

                if DoesEntityExist(missionBuyer) and DoesEntityExist(missionVehicle) then
                    SetVehicleEngineOn(missionVehicle, true, true, false)
                    TaskVehicleDriveWander(missionBuyer, missionVehicle, Config.SellBuyer.driveSpeed or 22.0, Config.SellBuyer.drivingStyle or 786603)
                end
            end

            Wait(Config.SellBuyer.deleteDelay or 30000)
        else
            -- Stay behaviour: leave the buyer and sold vehicle at the drop-off.
            -- The sold vehicle remains locked/unusable until the mission player is 50m away.
            FreezeEntityPosition(missionBuyer, true)
            ClearPedTasksImmediately(missionBuyer)
            SetVehicleEngineOn(missionVehicle, false, true, true)
            SetVehicleDoorsLocked(missionVehicle, 2)
            SetVehicleDoorsLockedForAllPlayers(missionVehicle, true)
            SetVehicleUndriveable(missionVehicle, true)

            local deleteRadius = Config.SellBuyer.stayDeleteRadius or 50.0
            local playerPed = PlayerPedId()

            while DoesEntityExist(missionBuyer) or DoesEntityExist(missionVehicle) do
                if not DoesEntityExist(playerPed) then
                    playerPed = PlayerPedId()
                end

                local referenceCoords
                if DoesEntityExist(missionVehicle) then
                    referenceCoords = GetEntityCoords(missionVehicle)
                elseif DoesEntityExist(missionBuyer) then
                    referenceCoords = GetEntityCoords(missionBuyer)
                else
                    break
                end

                if #(GetEntityCoords(playerPed) - referenceCoords) > deleteRadius then
                    break
                end

                Wait(1000)
            end
        end

        -- Delete only the exact mission buyer and exact stolen mission vehicle.
        -- No radius/closest-vehicle/entity cleanup natives are used here.
        if DoesEntityExist(missionBuyer) then
            RequestEntityControl(missionBuyer, 2000)
            DeleteEntity(missionBuyer)
        end

        if DoesEntityExist(missionVehicle) then
            RequestEntityControl(missionVehicle, 2000)
            DeleteEntity(missionVehicle)
        end

        if buyerPed == missionBuyer then buyerPed = nil end
        if trackerCar == missionVehicle then trackerCar = nil end
        trackerLocation = nil
        startedGPS = 0
            handoffInProgress = false
    end)
end)

-- Police tow interaction remains unchanged.
exports.qtarget:Vehicle({
    options = {{
        icon = 'fa-regular fa-circle-check',
        label = Config.lang['tow_the_vehicle'],
        canInteract = function(entity)
            if trackerPoliceCar == nil then return false end
            return entity == NetworkGetEntityFromNetworkId(trackerPoliceCar)
        end,
        action = function()
            if not inAction then
                inAction = true
                if lib.progressBar({
                    duration = 6000,
                    label = Config.lang['towing'],
                    useWhileDead = false,
                    canCancel = false,
                    disable = { car = true }
                }) then
                    inAction = false
                    TriggerServerEvent('kd_trucker:server:truckerDestroy')
                    trackerPoliceCar = nil
                else
                    inAction = false
                end
            end
        end,
        job = { ['police'] = 0 }
    }},
    distance = 2
})

local function CanRemoveTracker(entity)
    if inAction or trackerState ~= 3 or entity ~= trackerCar then return false end
    return (GetGameTimer() - startedGPS) / 1000 >= Config.destroyGPSTime
end

local function SelectRemoveTracker(data)
    local vehicle = data and data.entity or trackerCar
    if not vehicle or vehicle ~= trackerCar then return end

    if exports.ox_inventory:Search('count', Config.RequireItem) < 1 then
        ESX.ShowNotification(Config.lang['required_items'], 'error', 3000)
        return
    end

    hackSuccess(vehicle)
end

-- Bonnet-specific target for cars and other vehicles with a bonnet bone.
exports.ox_target:addGlobalVehicle({{
    name = gpsTargetName,
    icon = 'fa-solid fa-screwdriver-wrench',
    label = Config.lang['gps_take_off'],
    bones = { 'bonnet' },
    distance = 1.4,
    canInteract = function(entity)
        if GetEntityBoneIndexByName(entity, 'bonnet') == -1 then return false end
        return CanRemoveTracker(entity)
    end,
    onSelect = SelectRemoveTracker
}, {
    -- Motorcycles and unusual mission vehicles without a bonnet bone get a
    -- small interaction point at the front instead of the whole vehicle.
    name = gpsFallbackTargetName,
    icon = 'fa-solid fa-screwdriver-wrench',
    label = Config.lang['gps_take_off'],
    offset = vec3(0.5, 1.0, 0.5),
    offsetSize = 0.55,
    distance = 1.4,
    canInteract = function(entity)
        if GetEntityBoneIndexByName(entity, 'bonnet') ~= -1 then return false end
        return CanRemoveTracker(entity)
    end,
    onSelect = SelectRemoveTracker
}})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    RemoveTrackerBlip()
    RemovePlayerTrackerSignalBlip()
    RemoveBuyerTarget()

    exports.ox_target:removeGlobalVehicle({ gpsTargetName, gpsFallbackTargetName })
    if missionNPC and DoesEntityExist(missionNPC) then
        exports.ox_target:removeLocalEntity(missionNPC, missionNPCTargetName)
        DeleteEntity(missionNPC)
        missionNPC = nil
    end

    if buyerPed and DoesEntityExist(buyerPed) then
        DeleteEntity(buyerPed)
    end
end)
