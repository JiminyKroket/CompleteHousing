DEPRECATED SYSTEMS USED, SCRIPT FOR DEVELOPMENT PURPOSES ONLY, NO SUPPORT GIVEN FOR INSTALLATION OR USE

Development: DEPRECATED SYSTEMS USED, SCRIPT FOR DEVELOPMENT PURPOSES ONLY, NO SUPPORT GIVEN FOR INSTALLATION OR USE
	SpindleScripts
	Major debug assistance from MLGCrisis Community
	Garage system implementation assisted by MLGCrisis Reuben
	Home spawning system reworked assisted by Yhtrae & Squad

Name: DEPRECATED SYSTEMS USED, SCRIPT FOR DEVELOPMENT PURPOSES ONLY, NO SUPPORT GIVEN FOR INSTALLATION OR USE
	CompleteHousing

Title: DEPRECATED SYSTEMS USED, SCRIPT FOR DEVELOPMENT PURPOSES ONLY, NO SUPPORT GIVEN FOR INSTALLATION OR USE
	Housing Scipt(Pre-Furnished/Furnishable)

Description: DEPRECATED SYSTEMS USED, SCRIPT FOR DEVELOPMENT PURPOSES ONLY, NO SUPPORT GIVEN FOR INSTALLATION OR USE
	CompleteHousing is a mod dedicated to creating an in depth housing system. Commands allow easy home/parking creation as well as offset printing
	for adding new shells. Players must purchase a home, purchase furniture, then furnish their home. There is options for allowing pre furnished
	homes as well. Players may then put their house on the market, choosing the sell price. Parking is persistant world vehicles, spots are set per
	house and are created through the commands. House options include storage (default support: inventoryhud), as well as a wardrobe (requires ESX_skin).
	Visiting and police-raiding systems implemented.

Installation: DEPRECATED SYSTEMS USED, SCRIPT FOR DEVELOPMENT PURPOSES ONLY, NO SUPPORT GIVEN FOR INSTALLATION OR USE
	Download .zip package.

	Extract the CompleteHousing folder.

	Place the CompleteHousing folder into your server resource folder.

	If using any weather sync system follow instructions on inserting home checking code.

	If wishing to use InvHud download from https://github.com/JiminyKroket/Invhud/tree/master and place invhud folder into your server resource folder, 
		otherwise replace current property.lua file in your inventoryhud with the one inside the CompleteHousing folder, uncomment the final SQL queries,
		copy your 'cash' image and rename it to 'money', add the new image to your __resource/fxmanifest.lua, and change "} else if (type === "property") {
            	$(".info-div").hide();" to "} else if (type === "property") {
            	$(".info-div").show();" in your esx_inventoryhud/js/inventory.js file.

	Add 'ensure CompleteHousing' to your 'server.cfg' file after es_extended

	If wishing to use InvHud add 'ensure invhud' to your 'server.cfg' file after es_extended.

	----https://stackoverflow.com/questions/3466872/why-cant-a-text-column-have-a-default-value-in-mysql----
	Import the CompleteHousing.sql file into your database. -- ENSURE THAT ALL SQL PARTS HAVE RUN, UPDATE USERS IS 'UNSAFE', IT MAY AUTO-REFUSE
	If you receive an error "TEXT/BLOB column can not have DEFAULT value" go to the following website and follow instructions to remove safemode from your database
	----https://stackoverflow.com/questions/3466872/why-cant-a-text-column-have-a-default-value-in-mysql----
  
  MYSQL VERSION 10.3.25 AND ABOVE ALLOW DEFAULT LONGTEXT VALUES
  
  IF YOU ABSOLUTELY HAVE NO POSSIBLE WAY TO ALLOW DEFAULT VALUES FOR LONGTEXT DATA TYPES IN YOUR DATABASE THEN KEEP ALL DATA TYPES AS
  THEIR ORIGINAL, REMOVE THE DEFAULT VALUE FOR LONGTEXT DATA TYPES ONLY, AND FOLLOW THE NEXT STEPS TO ADD FURNITURE AND WARDROBE DEFAULTS
  
  Add furniture and wardrobe to your user creation query in es_extended/server/main.lua like the one provided below.
  -- USER CREATION QUERY -- FOR ESX VERSION ABOVE 1.1
  MySQL.Async.execute('INSERT INTO users (accounts, identifier, weight, furniture, wardrobe) VALUES (@accounts, @identifier, @weight, @fu, @wa)', {
      ['@accounts'] = json.encode(accounts),
      ['@identifier'] = identifier,
      ['@weight'] = 1.0,
      ['@wa'] = json.encode({}),
      ['@fu'] = json.encode({})
  }, function(rowsChanged)
      loadESXPlayer(identifier, playerId)
  end)

  -- USER CREATION QUERY -- FOR ESX VERSION 1.1
  FOUND IN ESSENTIALMODE/SERVER/DB.LUA LINE 193
  createDocument({ identifier = identifier, license = license, money = tonumber(settings.defaultSettings.startingCash) or 0, bank = tonumber(settings.defaultSettings.startingBank) or 0, group = "user", permission_level = 0, wardrobe = {}, furniture = {} }, function(returned, document)
      if callback then
          callback(returned, document)
      end
  end)

  UPDATE users SET furniture = '[]', wardrobe = '[]';
  
  END OF SECTION TO USE IF NOT ABLE TO SET DEFAULTS FOR LONGTEXT DATA TYPES IN YOUR DATABASE

	If wishing to use InvHud import the invhud.sql file into your database.

	Thoroughly read and adjust the config.lua file(s).

	-- Home Checking Code insertion for Weather Sync scripts --
	Open the client file for your weather/time sync.
	Copy the following snippet and place it in your client file, at the top.
	```lua
	local inHome = false
  AddEventHandler('CompleteHousing:setPlayerInHome', function(isHome)
    inHome = isHome
  end)
	```

	After inserting the thread, find your sync script's loop for updating weather/time (example follows), and insert the line ```if not inHome then``` right after the
	Citizen.Wait(time), then close that if then statement with ```end```
	```lua
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(100) -- Wait 0 seconds to prevent crashing.
			if not inHome then -- <<<< THIS IS THE FIRST LINE ADDED TO SYNC LOOP
				if lastWeather ~= CurrentWeather then
					lastWeather = CurrentWeather
					SetWeatherTypeOverTime(CurrentWeather, 15.0)
					Citizen.Wait(15000)
				end
				SetBlackout(blackout)
				ClearOverrideWeather()
				ClearWeatherTypePersist()
				SetWeatherTypePersist(lastWeather)
				SetWeatherTypeNow(lastWeather)
				SetWeatherTypeNowPersist(lastWeather)
				if lastWeather == 'rain' then
					SetRainFxIntensity(0.35)
				end
				if lastWeather == 'thunder' then
					SetRainFxIntensity(0.65)
				end
				if lastWeather == 'XMAS' then
					SetForceVehicleTrails(true)
					SetForcePedFootstepsTracks(true)
				else
					SetForceVehicleTrails(false)
					SetForcePedFootstepsTracks(false)
				end
			end -- <<<< THIS IS THE SECOND LINE ADDED TO SYNC LOOP
		end
	end)
	```

Requirements: DEPRECATED SYSTEMS USED, SCRIPT FOR DEVELOPMENT PURPOSES ONLY, NO SUPPORT GIVEN FOR INSTALLATION OR USE
	ESX (V1-Final or lower) or EXM,
	esx_skin (For base wardrobe functions)
	
Usage: DEPRECATED SYSTEMS USED, SCRIPT FOR DEVELOPMENT PURPOSES ONLY, NO SUPPORT GIVEN FOR INSTALLATION OR USE
	/doorlock
		registered to allow key-mapping of locking/unlocking MLO houses
		default key is l(L), adjustable in Config.lua (also literally key mapped so players can adjust themselves in pause menu if they wish)
	/addHome 
		stand in location for home entry and add it to database(walk-through in game, PERSISTENT PARKING KEEPS CAR IN WORLD AT PARKING SPOT, GARAGE PARKING CREATES GARAGE ZONE AT ALL PARKING SPOTS)
	YOU MUST BE WITHIN THE LAND SIZE OF THE HOME TO USE ANY FURTHER COMMANDS
	/removeHome
		delete selected house from database(walk-through in game)
	/updateLand
		re-pick land size for home(walk-through in game)
	/addParking
		stand in location for home parking and add it to database(walk-through in game)
	/removeParking
		delete closest parking from database(walk-through in game)
	/addDoor
		stand next to a door(swinging entry point) and add it to selected home
	/addGarage
		stand next to a garage(raising entry point) and add it to selected home
	/moveStorage
		stand in location for home storage and change it for selected home(SHELL HOMES MUST BE EXITED AND RE-ENTERED FOR ZONE TO MOVE)
	/moveWardrobe
		stand in location for home wardrobe and change it for selected home(SHELL HOMES MUST BE EXITED AND RE-ENTERED FOR ZONE TO MOVE)

	-- FOLLOWING COMMANDS FOR DEVELOPMENT ONLY (SETTING NEW SHELL DOOR LOCATIONS AND PRE-FURNISHED HOME FURNITURE) --
	/testShell shell_name
		spawns shell under creator, and spawns creator inside shell to allow using /offset
	/clearShell
		clear and delete current testshell prop
	/houseOffset
		get player offset from testshell prop and print to f8 console
	/spawnProp "propname"
		spawns prop for 10 seconds in front of creator