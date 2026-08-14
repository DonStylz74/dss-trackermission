local ESX = exports['es_extended']:getSharedObject()

local currentNPCPosition = Config.NPC.locations[math.random(1, #Config.NPC.locations)]

local function PrintCurrentNPCLocation()
    local line = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    print('')
    print(line)
    print(('Current tracker mission location: %.2f, %.2f, %.2f'):format(
        currentNPCPosition.x, currentNPCPosition.y, currentNPCPosition.z
    ))
    print(line)
    print('')
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SetTimeout(10000, function()
        PrintCurrentNPCLocation()
    end)
end)

local tracker = {
    state = false,
    lastTruckerEnded = 0,
    thief = nil,
    car = nil,
    choice = nil,
    dropoffIndex = nil,
    pos = {
        area = nil,
        carPosition = nil,
        searchRadius = nil,
        locationBonusEnabled = false
    }
}

local function ClearTrackerState()
    tracker = {
        state = false,
        lastTruckerEnded = os.time(),
        thief = nil,
        car = nil,
        choice = nil,
        dropoffIndex = nil,
        pos = {
            area = nil,
            carPosition = nil,
            searchRadius = nil,
            locationBonusEnabled = false
        }
    }
end

local validPaymentTypes = {
    money = true,
    bank = true,
    black_money = true
}

local function NotifyPlayer(src, message, notificationType, duration)
    TriggerClientEvent('kd_trucker:client:notification', src, message, notificationType or 'info', duration or 5000)
end

local function GetPaymentLabel(paymentType)
    if paymentType == 'money' then
        return 'cash'
    elseif paymentType == 'bank' then
        return 'bank account'
    elseif paymentType == 'black_money' then
        return 'black money'
    end

    return paymentType
end

local function GetPlayerBalance(xPlayer, paymentType)
    if paymentType == 'money' then
        return xPlayer.getMoney()
    end

    local account = xPlayer.getAccount(paymentType)
    return account and account.money or nil
end

local function RemovePlayerMoney(xPlayer, paymentType, amount)
    if paymentType == 'money' then
        xPlayer.removeMoney(amount, 'Tracker mission NPC shop purchase')
    else
        xPlayer.removeAccountMoney(paymentType, amount, 'Tracker mission NPC shop purchase')
    end
end

local function RefundPlayerMoney(xPlayer, paymentType, amount)
    if paymentType == 'money' then
        xPlayer.addMoney(amount, 'Tracker mission NPC shop refund')
    else
        xPlayer.addAccountMoney(paymentType, amount, 'Tracker mission NPC shop refund')
    end
end

local function IsPlayerNearMissionNPC(src, maxDistance)
    local playerPed = GetPlayerPed(src)
    if playerPed == 0 then return false end

    local playerCoords = GetEntityCoords(playerPed)
    local npcCoords = vector3(currentNPCPosition.x, currentNPCPosition.y, currentNPCPosition.z)
    return #(playerCoords - npcCoords) <= (maxDistance or 5.0)
end

local function GetSellDropoff(index)
    local location = Config.trackerHideoutLocations and Config.trackerHideoutLocations[index]
    if not location then return nil end

    -- Sell drop-off format: { vehicle = vec3(...), npc = vec4(...), driveAway = true/false }
    if location.vehicle and location.npc then
        return location
    end

    return nil
end

local function GetDifficultyBonuses()
    local bonusConfig = Config.DifficultyBonus or {}
    local radius = math.max(0, tonumber(tracker.pos.searchRadius) or 0)
    local radiusBonus = 0

    -- 400m and above is always the maximum configured radius bonus.
    if radius >= 400.0 then
        radiusBonus = math.max(0, math.floor(tonumber(bonusConfig.maxRadiusBonus) or 500))
    else
        for _, tier in ipairs(bonusConfig.radius or {}) do
            local maxRadius = tonumber(tier.maxRadius)
            if maxRadius and radius <= maxRadius then
                radiusBonus = math.max(0, math.floor(tonumber(tier.bonus) or 0))
                break
            end
        end
    end

    local locationBonus = 0
    if tracker.pos.locationBonusEnabled == true then
        locationBonus = math.max(0, math.floor(tonumber(bonusConfig.locationBonusAmount) or 0))
    end

    return radiusBonus, locationBonus
end

local function GetMissionReward()
    local baseReward = math.random(Config.money.min, Config.money.max)
    local radiusBonus, locationBonus = GetDifficultyBonuses()
    return baseReward + radiusBonus + locationBonus, baseReward, radiusBonus, locationBonus
end

RegisterNetEvent('kd_trucker:server:endTrucker', function()
    local src = source
    if src ~= tracker.thief or not tracker.state then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local reward = GetMissionReward()
    xPlayer.addAccountMoney(Config.money.type, reward)
    ClearTrackerState()
end)

RegisterNetEvent('kd_trucker:server:endTrucker2', function()
    local src = source
    if src ~= tracker.thief then return end
    ClearTrackerState()
end)

ESX.RegisterServerCallback('kd_trucker:callback:GetNPCPosition', function(src, cb)
    cb(currentNPCPosition)
end)

ESX.RegisterServerCallback('kd_trucker:callback:canStartTracker', function(src, cb)
    print(#ESX.GetExtendedPlayers('job', 'police'))
    cb(os.time() - tracker.lastTruckerEnded >= Config.truckerDelay and not tracker.state and #ESX.GetExtendedPlayers('job', 'police') >= Config.MinPolice)
end)

RegisterNetEvent('kd_trucker:server:startTucker', function()
    local src = source
    if not IsPlayerNearMissionNPC(src, 5.0) then return end

    local canStart = os.time() - tracker.lastTruckerEnded >= Config.truckerDelay
        and not tracker.state
        and #ESX.GetExtendedPlayers('job', 'police') >= Config.MinPolice

    if not canStart then
        NotifyPlayer(src, Config.lang['mission_in_progress'], 'info', 5000)
        return
    end

    -- Mission acceptance is intentionally separate from the NPC shop.
    -- No item is given and no money is removed when starting a mission.
    tracker.state = true
    tracker.thief = src

    local truckerPosInfo = Config.tuckerLocations[math.random(1, #Config.tuckerLocations)]
    local selectedVehicleLocation = truckerPosInfo.vehPositions[math.random(1, #truckerPosInfo.vehPositions)]

    tracker.pos.area = truckerPosInfo.areaPosition
    tracker.pos.searchRadius = tonumber(truckerPosInfo.searchRadius) or 200.0

    -- New format: { coords = vec4(...), bonus = true/false }
    -- Old plain vec4 entries are still supported and simply receive no location bonus.
    if type(selectedVehicleLocation) == 'table' and selectedVehicleLocation.coords then
        tracker.pos.carPosition = selectedVehicleLocation.coords
        tracker.pos.locationBonusEnabled = selectedVehicleLocation.bonus == true
    else
        tracker.pos.carPosition = selectedVehicleLocation
        tracker.pos.locationBonusEnabled = false
    end

    TriggerClientEvent('kd_trucker:client:startTucker', src, {
        area = tracker.pos.area,
        carPosition = tracker.pos.carPosition,
        searchRadius = tracker.pos.searchRadius
    })
end)

local function GetConfiguredShopItem(itemName)
    local shop = Config.NPCShop or {}
    for _, entry in ipairs(shop.items or {}) do
        if entry.item == itemName then
            return entry
        end
    end
end

RegisterNetEvent('kd_trucker:server:purchaseItem', function(itemName)
    local src = source
    if type(itemName) ~= 'string' then return end
    if not IsPlayerNearMissionNPC(src, 5.0) then return end

    local shopItem = GetConfiguredShopItem(itemName)
    if not shopItem then
        NotifyPlayer(src, Config.lang['shop_invalid_item'], 'error', 4000)
        return
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local paymentType = (Config.NPCShop and Config.NPCShop.paymentType) or 'money'
    if not validPaymentTypes[paymentType] then
        print(('[dss-trackermission] Invalid Config.NPCShop.paymentType: %s. Use money, bank or black_money.'):format(tostring(paymentType)))
        NotifyPlayer(src, Config.lang['shop_error'], 'error', 5000)
        return
    end

    local price = math.max(0, tonumber(shopItem.price) or 0)
    local count = math.max(1, math.floor(tonumber(shopItem.count) or 1))
    local label = shopItem.label or shopItem.item

    if not exports.ox_inventory:CanCarryItem(src, shopItem.item, count) then
        NotifyPlayer(src, Config.lang['shop_no_space'], 'error', 5000)
        return
    end

    local balance = GetPlayerBalance(xPlayer, paymentType)
    local paymentLabel = GetPaymentLabel(paymentType)
    if balance == nil then
        print(('[dss-trackermission] Could not find ESX account %s for player %s.'):format(paymentType, src))
        NotifyPlayer(src, Config.lang['shop_error'], 'error', 5000)
        return
    end

    if balance < price then
        NotifyPlayer(src, string.format(Config.lang['shop_no_money'], paymentLabel, price), 'error', 5000)
        return
    end

    if price > 0 then
        RemovePlayerMoney(xPlayer, paymentType, price)
    end

    local added, response = exports.ox_inventory:AddItem(src, shopItem.item, count)
    if not added then
        if price > 0 then RefundPlayerMoney(xPlayer, paymentType, price) end
        print(('[dss-trackermission] Failed NPC shop purchase for %s x%s (player %s): %s'):format(shopItem.item, count, src, tostring(response)))
        NotifyPlayer(src, Config.lang['shop_error'], 'error', 5000)
        return
    end

    NotifyPlayer(src, string.format(Config.lang['shop_purchase_success'], count, label, price), 'success', 5000)
end)

-- The player chooses Sell/Chop in the ox_lib dialog, but the server owns the
-- choice state and randomly selects the destination. The client never selects
-- a drop-off location itself.
RegisterNetEvent('kd_trucker:server:selectMissionRoute', function(choice)
    local src = source
    if src ~= tracker.thief or not tracker.state then return end
    if choice ~= 'sell' and choice ~= 'chop' then return end

    -- Only accept the first route selection for this mission.
    if tracker.choice then
        return
    end

    tracker.choice = choice

    if choice == 'sell' then
        if not Config.trackerHideoutLocations or #Config.trackerHideoutLocations == 0 then
            tracker.choice = nil
            NotifyPlayer(src, Config.lang['no_sell_location'], 'error', 5000)
            return
        end

        local index = math.random(1, #Config.trackerHideoutLocations)
        local dropoff = GetSellDropoff(index)
        if not dropoff then
            tracker.choice = nil
            print(('[dss-trackermission] Invalid sell drop-off config at index %s. Expected vehicle and npc coords.'):format(index))
            NotifyPlayer(src, Config.lang['no_sell_location'], 'error', 5000)
            return
        end

        tracker.dropoffIndex = index
        TriggerClientEvent('kd_trucker:client:routeSelected', src, 'sell', {
            vehicle = dropoff.vehicle,
            npc = dropoff.npc,
            driveAway = dropoff.driveAway ~= false
        })
    else
        if not Config.chopCarLocations or #Config.chopCarLocations == 0 then
            tracker.choice = nil
            NotifyPlayer(src, Config.lang['no_chop_location'], 'error', 5000)
            return
        end

        local index = math.random(1, #Config.chopCarLocations)
        tracker.dropoffIndex = index
        TriggerClientEvent('kd_trucker:client:routeSelected', src, 'chop', Config.chopCarLocations[index])
    end
end)

RegisterNetEvent('kd_trucker:server:collectVehicleCash', function()
    local src = source
    if src ~= tracker.thief or not tracker.state or tracker.choice ~= 'sell' or not tracker.dropoffIndex then
        return
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local dropoff = GetSellDropoff(tracker.dropoffIndex)
    if not dropoff then return end

    -- Server-side proximity checks protect the payout from a manually-triggered event.
    local playerPed = GetPlayerPed(src)
    if playerPed == 0 then return end

    local playerCoords = GetEntityCoords(playerPed)
    local npcCoords = vector3(dropoff.npc.x, dropoff.npc.y, dropoff.npc.z)
    if #(playerCoords - npcCoords) > (Config.SellBuyer.serverCollectDistance or 6.0) then
        return
    end

    if not tracker.car then return end

    local vehicle = NetworkGetEntityFromNetworkId(tracker.car)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local vehicleCoords = GetEntityCoords(vehicle)
    if #(vehicleCoords - dropoff.vehicle) > (Config.SellBuyer.vehicleDeliveryRadius or 20.0) then
        NotifyPlayer(src, Config.lang['park_vehicle'], 'error', 5000)
        return
    end

    local reward, baseReward, radiusBonus, locationBonus = GetMissionReward()
    xPlayer.addAccountMoney(Config.money.type, reward)

    print(('[dss-trackermission] Player %s payout: base $%s + radius bonus $%s + location bonus $%s = $%s'):format(
        src, baseReward, radiusBonus, locationBonus, reward
    ))

    TriggerClientEvent('kd_trucker:client:sellCompleted', src, reward, dropoff.driveAway ~= false)
    ClearTrackerState()
end)

RegisterNetEvent('kd_trucker:server:setTruckerCar', function(netId)
    local src = source
    if src ~= tracker.thief then return end
    tracker.car = netId
end)

RegisterNetEvent('kd_trucker:server:policeGPS', function(coords)
    local src = source
    if src ~= tracker.thief then return end

    local xPlayers = ESX.GetExtendedPlayers('job', 'police')
    for _, xPlayer in pairs(xPlayers) do
        TriggerClientEvent('kd_trucker:client:policeGPS', xPlayer.source, coords, tracker.car)
    end
end)

RegisterNetEvent('kd_trucker:server:truckerDestroy', function()
    local src = source
    if src ~= tracker.thief then return end

    TriggerClientEvent('kd_trucker:client:truckerDestroy', tracker.thief)
    ClearTrackerState()

    local xPlayers = ESX.GetExtendedPlayers('job', 'police')
    for _, xPlayer in pairs(xPlayers) do
        TriggerClientEvent('kd_trucker:client:GPSRemoveForced', xPlayer.source)
    end
end)

RegisterNetEvent('kd_trucker:server:GPSRemoved', function()
    local src = source
    if src ~= tracker.thief then return end

    local xPlayers = ESX.GetExtendedPlayers('job', 'police')
    for _, xPlayer in pairs(xPlayers) do
        TriggerClientEvent('kd_trucker:client:GPSRemoved', xPlayer.source)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if src == tracker.thief then
        ClearTrackerState()
        local xPlayers = ESX.GetExtendedPlayers('job', 'police')
        for _, xPlayer in pairs(xPlayers) do
            TriggerClientEvent('kd_trucker:client:GPSRemoveForced', xPlayer.source)
        end
    end
end)

RegisterNetEvent('kd_trucker:server:removeitem', function(item)
    local src = source
    if src ~= tracker.thief then return end

    -- Only allow this resource's configured tracker removal tool to be removed.
    if item ~= Config.RequireItem then return end
    exports.ox_inventory:RemoveItem(src, item, 1)
end)
