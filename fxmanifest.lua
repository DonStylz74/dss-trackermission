fx_version 'cerulean'
game 'gta5'

version '1.0.0'
author 'DonStylz'
description 'Car Thief Missions'

lua54 'yes'
use_fxv2_oal 'yes'

dependencies {
    'ox_lib',
    'es_extended',
    'qtarget',
    'ox_target',
    'ox_inventory'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared.lua'
}

client_scripts {'client/main.lua'}

server_scripts {'server/main.lua'}