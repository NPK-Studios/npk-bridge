fx_version 'cerulean'
game 'gta5'
author 'NPKStudios [www.npkstudios.pl]'
lua54 'yes'
description 'NPKStudios - Official Bridge'
version '1.0.0'

client_scripts {
    'client/main.lua',
    'client/utils.lua',
    'client/libs.lua',
    'client/cache.lua',
    'client/marker.lua',
    'client/setup.lua',
    'client/appearance/*.lua',
    'client/carkeys/*.lua',
    'client/framework/*.lua',
    'client/inventory/*.lua',
    'client/notify/*.lua',
    'client/progress/*.lua',
    'client/target/*.lua',
    'client/bossmenu/*.lua',
    'client/fuel/*.lua',
    'client/dispatch/*.lua',
    'client/textui/*.lua',
    'client/anim/*.lua',
    'client/zones/*.lua',
    'client/gizmo/*.lua',
    'client/locale/*.lua',
    'client/radial/*.lua',
    'client/log.lua',
    'client/modules.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/debug.lua',
    'server/logs.lua',
    'server/framework/*.lua',
    'server/inventory/*.lua',
    'server/dispatch/*.lua',
    'server/notify/*.lua',
    'server/society/*.lua',
    'server/banking/*.lua',
    'server/metadata/*.lua',
    'server/jobs/*.lua',
    'server/vehicles/*.lua',
    'server/locale/*.lua',
    'server/groups.lua',
    'server/log.lua',
    'server/modules.lua'
}

shared_scripts {
    'config.lua',
    '@ox_lib/init.lua',
    'shared/libs.lua',
}

files {
    'imports.lua'
}