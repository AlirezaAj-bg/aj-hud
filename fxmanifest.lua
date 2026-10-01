fx_version 'cerulean'
game 'gta5'
lua54 'yes'
description 'Aj Hud V'
version '1.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua'
}

escrow_ignore {
    'config.lua',
}

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/*',
    'html/index.html',
    'html/theme.css',
    'html/styles.css',
    'html/responsive.css',
    'html/app.js',
    'html/fonts/Kanit-ExtraBoldItalic.woff2',
}
