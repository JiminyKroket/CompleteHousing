fx_version 'bodacious'

game 'gta5'

mod 'complete-housing'
version '1.3.0'

server_scripts {
	'@async/async.lua',
	'@mysql-async/lib/MySQL.lua',
	'config.lua',
	'server.lua'
}

client_scripts {
	'@es_extended/locale.lua',
	'config.lua',
	'client.lua'
}

dependencies {
	'es_extended'
}