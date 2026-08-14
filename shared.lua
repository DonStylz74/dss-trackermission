Config = {}


Config.NPC = {
    model = 'IG_Hao_02',
    locations = {
        vec4(750.4904, -1836.9042, 29.2916, 69.7643),
        vec4(-77.3786, 364.3845, 112.4416, 159.3492),
        vec4(2483.9451, 3445.9453, 51.0680, 328.9458),
        vec4(1676.5775, 6432.5776, 31.6964, 191.5232),
    }
}

-- Item required when removing the GPS tracker from the stolen vehicle.
-- Starting a mission no longer gives this item or takes any money.
Config.RequireItem = 'traker_remtool'

-- Mission NPC shop. Players can buy useful vehicle-access items here before
-- starting a mission. paymentType options: 'money', 'bank', 'black_money'.
Config.NPCShop = {
    paymentType = 'money',
    items = {
        { item = 'traker_remtool', label = 'GPS Tracker Removal Tool', price = 100 },

        -- Add items from your other vehicle scripts as required, for example:
        -- { item = 'lockpick', label = 'Lockpick', price = 250 },
        -- { item = 'hotwire_kit', label = 'Hotwire Kit', price = 500 },
    }
}

-- GPS tracker removal minigame.
-- minigame options:
--   'mgc'  = use MGC Frequency Jam
--   'none' = skip the minigame and use the existing timed removal action
Config.GPSRemoval = {
    minigame = 'mgc',
    mgcResource = 'mgc',
    game = 'frequency_jam',
    data = {
        dials = 3,
        timer = 150000,
        precision = 3,
    },
    noneDuration = 20000,
    animation = {
        dict = 'amb@prop_human_bum_bin@base',
        clip = 'base',
    }
}

Config.carModels = { -- Cars that can spawn
    'tempesta',
    'vacca',
    'sultanrs',
    't20',
    'shinobi',
    'diablous2',
    'zombiea',
    'avarus',
    'sentinel4',
    'tenf',
    'vectre',
    'calico',
    'ruiner4',
    'gauntlet5',
    'vamos',
    'ellie',
    'hustler',
    'hellion',
    'dubsta3',
    'sandking',
    'firebolt',
    'weevil',
    'club',
    'issi3',
    'kanjo',
    'f620',
    'oracle2',
    'cogcabrio',
    'sentinel',
    'vorschlaghammer',
    'tailgater2',
    'schafter3',
    'rhinehart',
    'coquette2',
    'mamba',
    'infernus2',
    'cheetah2',
    'viseris',
    'zr350',
    'jester4',
    'sultan3',
    'woodlander',
    'astron2',
    'baller7',
    'toros',
    'bison2',
}

Config.MinPolice = 0

Config.truckerDelay = 10 -- in seconds


Config.tuckerLocations = {
    {
        areaPosition = vec3(1130.8340, -552.7366, 57.9936), -- mirror park
        searchRadius = 280.0, -- vehicle search area radius in metres
        vehPositions = {
            { coords = vec4(1358.3177, -541.9930, 73.4445, 154.3497), bonus = false },
            { coords = vec4(1291.3696, -581.4116, 71.4121, 343.3168), bonus = false },
            { coords = vec4(1237.0114, -586.1911, 68.9535, 270.4646), bonus = false },
            { coords = vec4(1255.4456, -491.5256, 69.1148, 253.5636), bonus = false },
            { coords = vec4(1361.7397, -556.9253, 74.0097, 159.0945), bonus = false },
        }
    },
    {
        areaPosition = vec3(85.5339, -1861.5199, 24.1828),  --  grove st  117.7234, -1911.0457, 20.4976, 145.3017
        searchRadius = 200.0, -- vehicle search area radius in metres
        vehPositions = {
            { coords = vec4(41.4605, -1921.3975, 21.3355, 319.8266), bonus = false },
            { coords = vec4(118.4837, -1898.6677, 23.1336, 334.9079), bonus = false },
			{ coords = vec4(49.8283, -1835.6078, 23.9988, 51.5482), bonus = false },
			{ coords = vec4(42.0569, -1852.9773, 22.5033, 134.5865), bonus = false },
        }
    },
    {
        areaPosition = vec3(-508.2698, 576.0620, 119.9732),  --  vinewood hills  --  10 spots
        searchRadius = 300.0, -- vehicle search area radius in metres
        vehPositions = {
            { coords = vec4(-519.0137, 575.1665, 120.9458, 289.3025), bonus = false },
            { coords = vec4(-369.3003, 350.8163, 109.3767, 108.0157), bonus = false },
			{ coords = vec4(-737.3796, 442.6581, 106.8804, 13.9094), bonus = false },
			{ coords = vec4(-343.9401, 634.6530, 172.2878, 46.8640), bonus = false },
			{ coords = vec4(-708.4542, 650.6810, 155.1752, 351.2859), bonus = false },
			{ coords = vec4(-766.7429, 665.6536, 144.7733, 292.6949), bonus = false },
			{ coords = vec4(-575.8799, 398.7216, 100.6647, 18.4012), bonus = false },
			{ coords = vec4(-392.1346, 434.4504, 112.3398, 207.2004), bonus = false },
			{ coords = vec4(-273.9853, 599.4591, 181.6862, 354.1557), bonus = false },
			{ coords = vec4(-454.0941, 371.9135, 104.7791, 8.9987), bonus = false },
        }
    },
}

-- Difficulty bonus payments are added on top of the normal Config.money payout.
-- Radius tiers use the searchRadius configured on the selected mission location.
-- Location bonus is enabled individually on each vehicle spawn inside vehPositions.
Config.DifficultyBonus = {
    locationBonusAmount = 500, -- Standard bonus added when the selected vehicle spawn has bonus = true

    radius = {
        { maxRadius = 100.0, bonus = 0 },   -- 0-100m: no bonus
        { maxRadius = 150.0, bonus = 50 }, -- >100-150m: level 1
        { maxRadius = 200.0, bonus = 100 }, -- >150-200m: level 2
        { maxRadius = 300.0, bonus = 200 }, -- >200-300m: level 3
        { maxRadius = 400.0, bonus = 300 }, -- >300-<400m: level 4 (400m+ is level 5 below)
    },

    maxRadiusBonus = 500, -- 400m and above: level 5
}

Config.destroyGPSTime = 10 --time after you can delete GPS from getting to car


Config.GPSRemove = 10000 -- Police blip time to delete after thief destroys GPS


Config.trackerHideoutLocations = { -- Sell vehicle drop-offs
    {
        vehicle = vec3(1730.334106, 3314.043945, 41.209473), -- Where the stolen vehicle must be delivered
        npc = vec4(1726.9500, 3313.2000, 40.2200, 190.0000), -- Buyer NPC position/heading
        driveAway = true, -- true = buyer drives away after payment, false = buyer/vehicle stay until player is 50m away
    },
    {
        vehicle = vec3(-265.3312, 2191.5974, 129.8181), -- Where the stolen vehicle must be delivered
        npc = vec4(-264.0440, 2196.4866, 129.3988, 243.9777), -- Buyer NPC position/heading
        driveAway = true, -- true = buyer drives away after payment, false = buyer/vehicle stay until player is 50m away
    },
    {
        vehicle = vec3(-677.9016, 902.9932, 230.5754), -- Where the stolen vehicle must be delivered
        npc = vec4(-681.6691, 901.7570, 229.5754, 317.2924), -- Buyer NPC position/heading
        driveAway = false, -- true = buyer drives away after payment, false = buyer/vehicle stay until player leaves area
    },
}

Config.SellBuyer = {
    model = 'g_m_y_mexgoon_02',
    targetDistance = 2.0,
    vehicleDeliveryRadius = 20.0,
    serverCollectDistance = 6.0,
    handoffDistance = 1.50, -- distance between player and buyer during the cash exchange
    handoffWalkSpeed = 1.0, -- player walk speed when stepping into the exchange position
    driveSpeed = 22.0,
    drivingStyle = 786603,
    deleteDelay = 30000, -- driveAway = true: delete only the mission buyer NPC + mission vehicle after driving away
    stayDeleteRadius = 50.0, -- driveAway = false: delete buyer + vehicle once the mission player is outside this radius
    cashProp = 'prop_anim_cash_pile_01', -- prop starts in the buyer's hand and is handed to the player
    cashPropBone = 57005, -- right hand
}

Config.chopCarLocations = { -- Locations to chop vehicle
    { x = 480.8271, y = -1317.6116, z = 29.2029 },
    { x = 1563.7638, y = -2169.2393, z = 77.5270 },
	{ x = 1204.6665, y = -3117.0439, z = 5.5403 },
	{ x = 2488.3872, y = 4961.5010, z = 44.7983 },
	{ x = 430.2763, y = 6468.0605, z = 28.7730 },
}

Config.chopBlipSprite = 380
Config.chopBlipScale  = 0.7
Config.chopBlipColour = 73

Config.lang = {
    ['talk_to_npc'] = "Talk to the Car theft.",
    ['mission_in_progress'] = "I don't have anything for you now.",
    ['car_location'] = "I marked the position on the GPS. The car to steal is an %s with license plate number %s",
    ['right_spot'] = "You're at the right spot, now find the car!",
    ['afk'] = "Job cancelled due to AFK",
    ['rid_of_gps'] = "You need to get rid of the GPS in the car, use a tracker removal tool, you will receive further instructions after doing this!",
    ['good_job'] = "Good job! Keep in touch!",
    ['stolen_vehicle'] = "Stolen Vehicle!",
    ['drop'] = "Drop site",
    ['taking_off_gps'] = "Removing GPS tracker..",
    ['tow_the_vehicle'] = "Tow the vehicle",
    ['towing'] = "Towing the vehicle...",
    ['required_items'] = "You don't have required items!",
    ['gps_take_off'] = "Remove GPS tracker",
    ['gps_off'] = "GPS removed. Follow the route for the option you selected.",
	['gps_chop'] = 'Set a location marker on the chop shop with your GPS, you can chop the vehicle at that location.',
	['gps_sell'] = 'I have marked the buyer location on your GPS. Get the car there and sell it.',
	['choice_title'] = 'Stolen Vehicle',
	['choice_message'] = 'What do you want to do with the stolen vehicle?',
	['sell'] = 'Sell',
	['sell_selected'] = 'Sell selected. Remove the GPS tracker before taking the vehicle to the buyer.',
	['chop_selected'] = 'Chop selected. Remove the GPS tracker before taking the vehicle to the chop shop.',
	['choice_required'] = 'You must choose Sell or Chop before continuing.',
	['chop']   = 'Chop Area',
	['drop']   = 'Drop-off',
    ['collect_cash'] = 'Collect cash for vehicle',
    ['park_vehicle'] = 'Bring the stolen vehicle closer to the buyer before collecting payment.',
    ['exit_vehicle_for_cash'] = 'Exit the vehicle and speak to the buyer to collect your cash.',
    ['vehicle_sold'] = 'Vehicle sold. You received $%s.',
    ['buyer_spawn_error'] = 'The buyer could not be spawned. Please contact an administrator.',
    ['no_sell_location'] = 'No valid sell drop-off location is configured.',
    ['no_chop_location'] = 'No valid chop location is configured.',
    ['npc_menu_title'] = 'Vehicle Theft Contact',
    ['purchase_items'] = 'Purchase Items',
    ['purchase_items_desc'] = 'Buy tools that may help you access and prepare the target vehicle.',
    ['start_mission'] = 'Start Mission',
    ['start_mission_desc'] = 'Accept a vehicle theft mission.',
    ['shop_title'] = 'Purchase Items',
    ['shop_empty'] = 'No items are currently configured for sale.',
    ['shop_invalid_item'] = 'This item is not available for purchase.',
    ['shop_no_money'] = 'You do not have enough %s. You need $%s.',
    ['shop_no_space'] = 'You do not have enough inventory space for this item.',
    ['shop_purchase_success'] = 'You purchased %sx %s for $%s.',
    ['shop_error'] = 'The purchase could not be completed. Please try again.',
    ['gps_minigame_failed'] = 'You failed to jam the tracker frequency. Try again.',
    ['gps_minigame_missing'] = 'MGC is not running. Contact an administrator or set Config.GPSRemoval.minigame to none.'
}

Config.AFKProtect = 10 --- AFK time in minutes

Config.money = {
    type = "black_money", ---- 'black_money', 'bank', 'money'
    min = 2000, ---- min money
    max = 5000, ---- max money
}
