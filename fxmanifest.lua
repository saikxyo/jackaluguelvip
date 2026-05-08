fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'JackRutz'
description 'Sistema de Aluguel de Carros VIP para QBCore'
version '1.0.0'

shared_scripts {
    'config.lua',
    'data/vehicles.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'nui/index.html'

files {
    'nui/**/*'
}

dependencies {
    'qb-core',
    'ox_inventory',
    'ox_target',
    'oxmysql'
}