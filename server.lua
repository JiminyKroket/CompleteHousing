ESX = nil
curHouse = 0

Webhook = ''

TriggerEvent(Config.Strings.trigEv, function(obj) ESX = obj end)
local spawnedHouseSpots, playersRequested = {}, {}
houseCache, vehicleCache, PlayerJobs = {}, {}, {}

for k,v in pairs(Config.Raids.Jobs) do PlayerJobs[k] = {} end

Notify = function(src, text, timer)
	if timer == nil then
		timer = 5000
	end
	-- TriggerClientEvent('mythic_notify:client:SendAlert', src, { type = 'inform', text = text, length = timer, style = { ['background-color'] = '#ffffff', ['color'] = '#000000' } })
	-- TriggerClientEvent('pNotify:SendNotification', src, {text = text, type = 'error', queue = GetCurrentResourceName(), timeout = timer, layout = 'bottomCenter'})
  TriggerClientEvent('esx:showNotification', src, text)
end

doRound = function(value, numDecimalPlaces)
	if numDecimalPlaces then
		local power = 10^numDecimalPlaces
		return math.floor((value * power) + 0.5) / (power)
	else
		return math.floor(value + 0.5)
	end
end

CheckPlayerJob = function(src)
  local attempts = 0
  repeat
    Wait(5000)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer ~= nil and type(xPlayer) == 'table' then
      print(string.format("Checking player job: %s", xPlayer.identifier))
      if PlayerJobs[xPlayer.job.name] ~= nil then
        print(string.format("Adding player %s to job table: %s", xPlayer.identifier, xPlayer.job.name))
        table.insert(PlayerJobs[xPlayer.job.name], xPlayer.source)
      end
      playersRequested[src] = false
    end
    attempts = attempts + 1
    if attempts == 12 then
      print(string.format("Could not find xPlayer table for source ID: %d", src))
      playersRequested[src] = false
    end
  until playersRequested[src] == false
end

HasJob = function(player)
	local hasJob = false
	if player ~= nil and type(player) == 'table' then
		for i = 1,#Config.Creation.Jobs do
			if player.job.name == Config.Creation.Jobs[i] then
				hasJob = true
			end
		end
		for i = 1,#Config.Creation.IDs do
			if player.identifier == Config.Creation.IDs[i] then
				hasJob = true
			end
		end
		return hasJob
	else
		print('error for xPlayer')
	end
end

HasMoneyInAccount = function(xPlayer, price)
	local hasMoney, account = false, nil
	local accounts = xPlayer.getAccounts()
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		for k,v in ipairs(accounts) do
			if not string.find(v.name, 'money') and not string.find(v.name, 'black_money') then
				if v.money >= price then
					hasMoney = true
					account = v.name
					break
				end
			end
		end
		return hasMoney, account
	else
		print('error for xPlayer')
	end
end

HasKeys = function(keys, id)
	local hasKey = false
	for i = 1,#keys do
		if keys[i] == id then
			hasKey = true
		end
	end
	return hasKey
end

GetHouseCache = function(address)
  for i = 1,#houseCache do
    if houseCache[i].id == address then
      return i
    end
  end
end

IsInInv = function(inv, item)
	if item ~= nil then
		if inv ~= nil then
			if inv.items ~= nil then
				for k,v in pairs(inv.items) do
					if item == k then
						return true
					end
				end
			end
			if inv.weapons ~= nil then
				for k,v in pairs(inv.weapons) do
					if item == k then
						return true
					end
				end
			end
		end
	end
	return false
end

SaveHouses = function()
  local asyncTasks = {}
  for i = 1,#houseCache do
    if i%50==0 then Wait(0) end -- anti hitch
    if houseCache[i].hasBeenUpdated then
      table.insert(asyncTasks, function(cb2)
        MySQL.Async.execute('UPDATE `houses` SET `owner` = @owner, `ownerName` = @ownerName, `prevowner` = @prevowner, `price` = @price, `locked` = @locked, `draw` = @draw, `failBuy` = @failBuy, `purDate` = @purDate, `keys` = @keys, `furniture` = @furniture, `parkings` = @parkings, `doors` = @doors, `garages` = @garages, `storage` = @storage, `wardrobe` = @wardrobe WHERE `id` = @id', {
          ['@id'] = houseCache[i].id,
          ['@owner'] = houseCache[i].owner,
          ['@ownerName'] = houseCache[i].ownerName,
          ['@prevowner'] = houseCache[i].prevowner,
          ['@price'] = houseCache[i].price,
          ['@locked'] = houseCache[i].locked,
          ['@draw'] = houseCache[i].draw,
          ['@failBuy'] = houseCache[i].failBuy,
          ['@purDate'] = houseCache[i].purDate,
          ['@keys'] = houseCache[i].keys,
          ['@furniture'] = houseCache[i].furniture,
          ['@parkings'] = houseCache[i].parkings,
          ['@doors'] = houseCache[i].doors,
          ['@garages'] = houseCache[i].garages,
          ['@storage'] = houseCache[i].storage,
          ['@wardrobe'] = houseCache[i].wardrobe
        }, function(rowsChanged)
          cb2()
        end)
      end)
      houseCache[i].hasBeenUpdated = false
    end
  end
  if #asyncTasks > 0 then
    Async.parallel(asyncTasks, function(results)
      print(('[CompleteHousing] [^2INFO^7] Saved %s houses(s)'):format(#asyncTasks))
      if cb then
        cb()
      end
    end)
  end
end

ESX.RegisterServerCallback('CompleteHousing:canBreakIn', function(source, cb, owner)
	local xPlayer = ESX.GetPlayerFromId(source)
	local xOwner = ESX.GetPlayerFromIdentifier(owner)
	if Config then
		if Config.BandE then
			if xPlayer ~= nil and type(xPlayer) == 'table' then
				for k,v in pairs(Config.BandE.ReqItems) do
					local xItem = xPlayer.getInventoryItem(k)
					if xItem then
						if xItem.count and type(xItem.count) == 'number' then
							if xItem.count < v then
								cb(false)
							end
						else
							print('count error')
							cb(false)
						end
					else
						print('item error')
            cb(false)
					end
				end
				if Config.BandE.Allow then
					if Config.BandE.AllowOffline then
						cb(true)
					else
						if xOwner ~= nil and type(xOwner) == 'table' then
							cb(true)
						else
							cb(false)
						end
					end
				else
					cb(false)
				end
			else
				print('error for xPlayer')
        cb(false)
			end
		else
			print('bande error')
      cb(false)
		end
	else
		print('config error')
    cb(false)
	end
end)

ESX.RegisterServerCallback('CompleteHousing:getHasItem', function(source, cb, item)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		local xItem = xPlayer.getInventoryItem(item)
		if xItem then
			if xItem.count and type(xItem.count) == 'number' then
				if xItem.count > 0 then
					cb(true)
				else
					cb(false)
				end
			else
				print('count error')
			end
		else
			print('item error')
		end
	else
		print('error for xPlayer')
	end
end)

ESX.RegisterServerCallback('CompleteHousing:canCreate', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		if HasJob(xPlayer) then
			cb(true)
		else
			cb(false)
		end
	else
		print('error for xPlayer')
	end
end)

ESX.RegisterServerCallback('CompleteHousing:getOwnerOnline', function(source, cb, owner)
	local xOwner = ESX.GetPlayerFromIdentifier(owner)
	if xOwner ~= nil and type(xOwner) == 'table' then
		cb(true)
	else
		cb(false)
	end
end)

ESX.RegisterServerCallback('CompleteHousing:getSpots', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		cb(spawnedHouseSpots)
	else
		print('error for xPlayer')
	end
end)

ESX.RegisterServerCallback('CompleteHousing:getGaragedCars', function(source, cb, id)
	local xPlayer = ESX.GetPlayerFromId(source)
	MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @id AND `'..Config.OwnedVehicleTable.name..'` = @stored AND `type` = @type', {['@id'] = xPlayer.identifier, ['@stored'] = 5, ['@type'] = 'car'}, function(cars)
		if cars and #cars > 0 then
			cb(cars)
		else
			cb({})
		end
	end)
end)

ESX.RegisterServerCallback('CompleteHousing:isCarOwned', function(source, cb, plate)
	MySQL.Async.fetchAll('SELECT 1 FROM owned_vehicles WHERE plate = @plate', {
		['@plate'] = plate
	}, function(result)
		cb(result[1] ~= nil)
	end)
end)

ESX.RegisterServerCallback('CompleteHousing:getHouseIn', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	MySQL.Async.fetchAll('SELECT homeIn FROM users WHERE identifier = @identifier', {['@identifier'] = xPlayer.identifier}, function(result)
		if result and result[1] then
			cb(result[1].homeIn)
		end
	end)
end)

ESX.RegisterServerCallback('CompleteHousing:getBoughtFurniture', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	MySQL.Async.fetchAll('SELECT furniture FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(ownedFurn)
		if ownedFurn and ownedFurn[1] and ownedFurn[1].furniture then
			cb(json.decode(ownedFurn[1].furniture))
		else
      cb({})
			print('player furniture is fucked up follow the readme properly')
		end
	end)
end)

ESX.RegisterServerCallback('CompleteHousing:getClothes', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	MySQL.Async.fetchAll('SELECT wardrobe FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(ownedFurn)
		if ownedFurn and ownedFurn[1] and ownedFurn[1].wardrobe then
			cb(json.decode(ownedFurn[1].wardrobe))
		else
      cb({})
			print('player wardrobe is fucked up follow the readme properly')
		end
	end)
end)

RegisterServerEvent('CompleteHousing:updateHomes')
AddEventHandler('CompleteHousing:updateHomes', function()
  local target = (type(source)=='string' and -1) or source
  if #houseCache < 1 then
    MySQL.Async.fetchAll('SELECT * FROM houses', {}, function(result)
      if result then
        houseCache = result
        TriggerClientEvent('CompleteHousing:updateHomes', target, houseCache)
      end
    end)
  else
    if target == -1 then
      for i = 1,#houseCache do
        if curHouse == houseCache[i].id then
          TriggerClientEvent('CompleteHousing:updateHomes', target, houseCache[i])
          break
        end
      end
    else
      TriggerClientEvent('CompleteHousing:updateHomes', target, houseCache)
    end
  end
end)

RegisterServerEvent('CompleteHousing:parkUnpark')
AddEventHandler('CompleteHousing:parkUnpark', function(vehicleData, isGarage, store)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
  local plate
	if isGarage == nil then
		plate = vehicleData.props.plate
		MySQL.Async.fetchAll('SELECT * FROM house_parking WHERE plate = @plate', {
			['@plate'] = plate
		}, function(result)
			if type(result) == 'table' and #result > 0 then
				MySQL.Async.execute('DELETE FROM house_parking WHERE plate = @plate', {
					['@plate']      = plate
				})
				MySQL.Async.execute('UPDATE owned_vehicles SET `'..Config.OwnedVehicleTable.name..'` = @state WHERE `plate` = @plate', {
					['@plate'] = plate,
					['@state'] = Config.OwnedVehicleTable.notParked
				})
				Citizen.Wait(500)
        TriggerClientEvent('CompleteHousing:removeVehicle', -1, vehicleData)
				TriggerClientEvent('CompleteHousing:driveCar', xPlayer.source, vehicleData)
			else
				MySQL.Async.execute('INSERT INTO house_parking (plate, data) VALUES (@plate, @data)', {
					['@plate']   = plate,
					['@data']    = json.encode(vehicleData)
				})
				MySQL.Async.execute('UPDATE owned_vehicles SET `'..Config.OwnedVehicleTable.name..'` = @state WHERE `plate` = @plate', {
					['@plate'] = plate,
					['@state'] = 5
				})
				Citizen.Wait(500)
        TriggerClientEvent('CompleteHousing:addVehicle', -1, vehicleData, xPlayer.source)
			end
		end)
	else
		plate = vehicleData.vehicle.plate
		if store == 'leave' then
			MySQL.Async.execute('UPDATE owned_vehicles SET `'..Config.OwnedVehicleTable.name..'` = @state WHERE `plate` = @plate', {
				['@plate'] = plate,
				['@state'] = Config.OwnedVehicleTable.notParked
			})
		else
			MySQL.Async.execute('UPDATE owned_vehicles SET `'..Config.OwnedVehicleTable.name..'` = @state WHERE `plate` = @plate', {
				['@plate'] = plate,
				['@state'] = 5
			})
		end
	end
end)

RegisterServerEvent('CompleteHousing:alertOwner')
AddEventHandler('CompleteHousing:alertOwner', function(home, tellCops)
  local src = source
  local owner = ESX.GetPlayerFromIdentifier(home.owner)
  if owner ~= nil and type(owner) == 'table' then
    TriggerClientEvent('CompleteHousing:alertBreakIn', owner.source, src, home)
  end
  if tellCops then
    for k,v in pairs(PlayerJobs) do
      for i = 1,#v do
        TriggerClientEvent('CompleteHousing:alertBreakIn', v[i], src, home)
      end
    end
  end
end)

RegisterServerEvent('CompleteHousing:buyBackFail')
AddEventHandler('CompleteHousing:buyBackFail', function(house)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
  local curHouseCacheID = GetHouseCache(house.id)
  houseCache[curHouseCacheID].failBuy = 'true'
  houseCache[curHouseCacheID].hasBeenUpdated = true
	TriggerEvent('CompleteHousing:updateHomes')
end)

RegisterServerEvent('CompleteHousing:lockHouse')
AddEventHandler('CompleteHousing:lockHouse', function(home)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
  local msg = (home.locked and Config.Strings.lockDor:format(home.id)) or Config.Strings.unlkDor:format(home.id)
  local curHouseCacheID = GetHouseCache(home.id)
  print(home.locked)
  houseCache[curHouseCacheID].locked = home.locked
  houseCache[curHouseCacheID].hasBeenUpdated = true
  Notify(xPlayer.source, msg)
  print(houseCache[curHouseCacheID].locked)
  TriggerEvent('CompleteHousing:updateHomes')
end)

RegisterServerEvent('CompleteHousing:takeKey')
AddEventHandler('CompleteHousing:takeKey', function(house, id)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local xTarget = ESX.GetPlayerFromId(id)
  local curHouseCacheID = GetHouseCache(house.id)
	local keys = json.decode(houseCache[curHouseCacheID].keys)
	for k,v in pairs(keys) do
		if v == xTarget.identifier then
			table.remove(keys, k)
		end
	end
  houseCache[curHouseCacheID].keys = json.encode(keys)
  houseCache[curHouseCacheID].hasBeenUpdated = true
	Notify(xPlayer.source, Config.Strings.tookKey:format(id, house.id))
  if xTarget ~= nil then
    Notify(xTarget.source, Config.Strings.lostKeys:format(house.id, xPlayer.identifier))
  end
  TriggerEvent('CompleteHousing:updateHomes')
end)

RegisterServerEvent('CompleteHousing:giveKey')
AddEventHandler('CompleteHousing:giveKey', function(target, house)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local xTarget = ESX.GetPlayerFromId(target)
  local curHouseCacheID = GetHouseCache(house.id)
	local keys = json.decode(houseCache[curHouseCacheID].keys)
	if not HasKeys(keys, xTarget.identifier) then
		table.insert(keys, xTarget.identifier)
	end
  houseCache[curHouseCacheID].keys = json.encode(keys)
  houseCache[curHouseCacheID].hasBeenUpdated = true
	Notify(xPlayer.source, Config.Strings.gaveKey:format(xTarget.identifier, house.id))
	Notify(xTarget.source, Config.Strings.gotKeys:format(house.id, xPlayer.identifier))
  TriggerEvent('CompleteHousing:updateHomes')
end)


RegisterServerEvent('CompleteHousing:createParking')
AddEventHandler('CompleteHousing:createParking', function(address, x, y, z)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
  local curHouseCacheID = GetHouseCache(address)
  if HasJob(xPlayer) or (Config.Creation.AllowOwner and xPlayer.identifier == houseCache[curHouseCacheID].owner) then
    local setSpots = json.decode(houseCache[curHouseCacheID].parkings)
    table.insert(setSpots, {x = x, y = y, z = z})
    houseCache[curHouseCacheID].parkings = json.encode(setSpots)
    houseCache[curHouseCacheID].hasBeenUpdated = true
    Notify(src, Config.Strings.pspCrea:format(address,x,y,z))
    TriggerEvent('CompleteHousing:updateHomes')
  else
    Notify(xPlayer.source, Config.Strings.noPerms)
  end
end)

RegisterServerEvent('CompleteHousing:deleteParking')
AddEventHandler('CompleteHousing:deleteParking', function(address, x, y, z)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	x = doRound(x, 2)
	y = doRound(y, 2)
	z = doRound(z, 2)
  local curHouseCacheID = GetHouseCache(address)
  if HasJob(xPlayer) or (Config.Creation.AllowOwner and xPlayer.identifier == houseCache[curHouseCacheID].owner) then
    local setSpots = json.decode(houseCache[curHouseCacheID].parkings)
    for k,v in ipairs(setSpots) do
      if v.x == x and v.y == y and v.z == z then
        table.remove(setSpots, k)
      end
    end
    houseCache[curHouseCacheID].parkings = json.encode(setSpots)
    houseCache[curHouseCacheID].hasBeenUpdated = true
    Notify(src, Config.Strings.pspCrea:format(address,x,y,z))
    TriggerEvent('CompleteHousing:updateHomes')
  else
    Notify(xPlayer.source, Config.Strings.noPerms)
  end
end)

RegisterServerEvent('CompleteHousing:setHomeStorage')
AddEventHandler('CompleteHousing:setHomeStorage', function(address, x, y, z, isStor)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local spot = {x = x, y = y, z = z}
  local curHouseCacheID = GetHouseCache(address)
  if HasJob(xPlayer) or (Config.Creation.AllowOwner and xPlayer.identifier == houseCache[curHouseCacheID].owner) then
    if isStor ~= nil then
      houseCache[curHouseCacheID].storage = json.encode({x = x, y = y, z = z})
      houseCache[curHouseCacheID].hasBeenUpdated = true
      Notify(src, Config.Strings.strCrea:format(address))
      TriggerEvent('CompleteHousing:updateHomes')
    else
      houseCache[curHouseCacheID].wardrobe = json.encode({x = x, y = y, z = z})
      houseCache[curHouseCacheID].hasBeenUpdated = true
      Notify(src, Config.Strings.warCrea:format(address))
      TriggerEvent('CompleteHousing:updateHomes')
    end
  else
    Notify(xPlayer.source, Config.Strings.noPerms)
  end
end)

RegisterServerEvent('CompleteHousing:updateLandSize')
AddEventHandler('CompleteHousing:updateLandSize', function(address, range)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
  local curHouseCacheID = GetHouseCache(address)
	if HasJob(xPlayer) then
    houseCache[curHouseCacheID].draw = range
    houseCache[curHouseCacheID].hasBeenUpdated = true
		TriggerEvent('CompleteHousing:updateHomes')
	else
		Notify(xPlayer.source, Config.Strings.noPerms)
	end
end)

RegisterServerEvent('CompleteHousing:addDoorToHome')
AddEventHandler('CompleteHousing:addDoorToHome', function(address, x, y, z, heading, hash)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local pos = {x = doRound(x, 2), y = doRound(y, 2), z = doRound(z, 2)}
  local curHouseCacheID = GetHouseCache(address)
  if HasJob(xPlayer) or (Config.Creation.AllowOwner and xPlayer.identifier == houseCache[curHouseCacheID].owner) then
    local houseDoors = json.decode(houseCache[curHouseCacheID].doors)
    table.insert(houseDoors, {prop = hash, locked = true, pos = pos, head = heading})
    houseCache[curHouseCacheID].doors = json.encode(houseDoors)
    houseCache[curHouseCacheID].hasBeenUpdated = true
    TriggerEvent('CompleteHousing:updateHomes')
  else
    Notify(xPlayer.source, Config.Strings.noPerms)
  end
end)

RegisterServerEvent('CompleteHousing:addGarageToHome')
AddEventHandler('CompleteHousing:addGarageToHome', function(address, x, y, z, hash, draw)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local pos = {x = doRound(x, 2), y = doRound(y, 2), z = doRound(z, 2)}
  local curHouseCacheID = GetHouseCache(address)
  if HasJob(xPlayer) or (Config.Creation.AllowOwner and xPlayer.identifier == houseCache[curHouseCacheID].owner) then
    local houseDoors = json.decode(houseCache[curHouseCacheID].garages)
    table.insert(houseDoors, {prop = hash, locked = true, pos = pos, draw = draw})
    houseCache[curHouseCacheID].garages = json.encode(houseDoors)
    houseCache[curHouseCacheID].hasBeenUpdated = true
    TriggerEvent('CompleteHousing:updateHomes')
  else
    Notify(xPlayer.source, Config.Strings.noPerms)
  end
end)

RegisterServerEvent('CompleteHousing:removeDoorFromHome')
AddEventHandler('CompleteHousing:removeDoorFromHome', function(address, x, y, z, hash)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local pos = {x = doRound(x, 2), y = doRound(y, 2), z = doRound(z, 2)}
  local curHouseCacheID = GetHouseCache(address)
  if HasJob(xPlayer) or (Config.Creation.AllowOwner and xPlayer.identifier == houseCache[curHouseCacheID].owner) then
    local houseDoors = json.decode(houseCache[curHouseCacheID].doors)
    local houseGarages = json.decode(houseCache[curHouseCacheID].garages)
    for k,v in ipairs(houseDoors) do
      if v.prop == hash and math.abs(v.pos.x - pos.x) <= 0.25 and math.abs(v.pos.y - pos.y) <= 0.25 and math.abs(v.pos.z - pos.z) <= 0.25 then
        table.remove(houseDoors, k)
      end
    end
    for k,v in ipairs(houseGarages) do
      if v.prop == hash and math.abs(v.pos.x - pos.x) <= 0.25 and math.abs(v.pos.y - pos.y) <= 0.25 and math.abs(v.pos.z - pos.z) <= 0.25 then
        table.remove(houseGarages, k)
      end
    end
    houseCache[curHouseCacheID].doors = json.encode(houseDoors)
    houseCache[curHouseCacheID].garages = json.encode(houseGarages)
    houseCache[curHouseCacheID].hasBeenUpdated = true
    TriggerEvent('CompleteHousing:updateHomes')
  else
    Notify(xPlayer.source, Config.Strings.noPerms)
  end
end)

RegisterServerEvent('CompleteHousing:updateDoor')
AddEventHandler('CompleteHousing:updateDoor', function(houseTable, door)
  local doors = houseTable.doors
  local garages = houseTable.garages
  local curHouseCacheID = GetHouseCache(houseTable.id)
  for i = 1,#doors do
    if (doRound(door.pos.x, 2) == doRound(doors[i].pos.x, 2)) and (doRound(door.pos.y, 2) == doRound(doors[i].pos.y, 2)) and (doRound(door.pos.z, 2) == doRound(doors[i].pos.z, 2)) then
      doors[i].locked = not doors[i].locked
    end
    doors[i].pos = {x = doors[i].pos.x, y = doors[i].pos.y, z = doors[i].pos.z}
  end
  for i = 1,#garages do
    if (doRound(door.pos.x, 2) == doRound(garages[i].pos.x, 2)) and (doRound(door.pos.y, 2) == doRound(garages[i].pos.y, 2)) and (doRound(door.pos.z, 2) == doRound(garages[i].pos.z, 2)) then
      garages[i].locked = not garages[i].locked
    end
    garages[i].pos = {x = garages[i].pos.x, y = garages[i].pos.y, z = garages[i].pos.z}
  end
  houseCache[curHouseCacheID].doors = json.encode(doors)
  houseCache[curHouseCacheID].garages = json.encode(garages)
  houseCache[curHouseCacheID].hasBeenUpdated = true
  TriggerEvent('CompleteHousing:updateHomes')
end)

RegisterServerEvent('CompleteHousing:addGuest')
AddEventHandler('CompleteHousing:addGuest', function(house)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		if spawnedHouseSpots[house.id] then
			table.insert(spawnedHouseSpots[house.id].guests, xPlayer.identifier)
		end
	else
		print('error for xPlayer')
	end
end)

RegisterServerEvent('CompleteHousing:removeGuest')
AddEventHandler('CompleteHousing:removeGuest', function(id)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		for k,v in pairs(spawnedHouseSpots[id].guests) do
			if v == xPlayer.identifier then
				table.remove(spawnedHouseSpots[id].guests, f)
				spawnedHouseSpots = spawnedHouseSpots
			end
		end
	else
		print('error for xPlayer')
	end
end)

RegisterServerEvent('CompleteHousing:removeGuests')
AddEventHandler('CompleteHousing:removeGuests', function(id)
	local src = source
	for i = 1,#spawnedHouseSpots[id].guests do
		local xPlayer = ESX.GetPlayerFromIdentifier(spawnedHouseSpots[id].guests[i])
		if xPlayer ~= nil and type(xPlayer) == 'table' then
			if xPlayer.source ~= src then
				TriggerClientEvent('CompleteHousing:ownerLeft', xPlayer.source)
			end
		else
			print('error for xPlayer')
		end
	end
	spawnedHouseSpots[id] = nil
end)

RegisterServerEvent('CompleteHousing:regSpot')
AddEventHandler('CompleteHousing:regSpot', function(whatDo, spot, id, size)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		if whatDo == 'insert' then
			if not spawnedHouseSpots[id] then
				spawnedHouseSpots[id] = {spot = spot, owner = xPlayer.source, guests = {xPlayer.identifier}, size = size}
			else
				table.insert(spawnedHouseSpots[id].guests, xPlayer.identifier)
			end
		else
			if spawnedHouseSpots[id] then
				if #spawnedHouseSpots[id].guests > 1 then
					for k,v in pairs(spawnedHouseSpots[id].guests) do
						if xPlayer.identifier == v then
							table.remove(spawnedHouseSpots[id].guests, k)
						end
					end
				else
					spawnedHouseSpots[id] = nil
				end
			end
		end
	else
		print('error for xPlayer')
	end
end)

RegisterServerEvent('CompleteHousing:knockFail')
AddEventHandler('CompleteHousing:knockFail', function(knocker)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local xKnocker = ESX.GetPlayerFromId(knocker)
	
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		if xKnocker ~= nil and type(xKnocker) == 'table' then
			TriggerClientEvent('CompleteHousing:doorKnock', xKnocker.source)
		else
			print('error for xKnocker')
		end
	else
		print('error for xPlayer')
	end
end)

RegisterServerEvent('CompleteHousing:knockAccept')
AddEventHandler('CompleteHousing:knockAccept', function(knocker, pos, house)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local xKnocker = ESX.GetPlayerFromId(knocker)
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		if xKnocker ~= nil and type(xKnocker) == 'table' then
			TriggerClientEvent('CompleteHousing:spawnHome', xKnocker.source, house, 'guest', pos)
		else
			print('error for xKnocker')
		end
	else
		print('error for xPlayer')
	end
end)

RegisterServerEvent('CompleteHousing:breakIn')
AddEventHandler('CompleteHousing:breakIn', function(house)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local xOwner, pos
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		if spawnedHouseSpots[house.id] then
			xOwner = ESX.GetPlayerFromIdentifier(v.owner)
			pos = spawnedHouseSpots[house.id].spot
		end
		if xOwner ~= nil and type(xOwner) == 'table' then
			TriggerClientEvent('CompleteHousing:spawnHome', xPlayer.source, house, 'owned', pos, 'true')
		else
			TriggerClientEvent('CompleteHousing:spawnHome', xPlayer.source, house, 'owned')
		end
	else
		print('error for xPlayer')
	end
end)

RegisterServerEvent('CompleteHousing:breakInFail')
AddEventHandler('CompleteHousing:breakInFail', function(house)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		math.randomseed(os.time())
		for k,v in pairs(Config.BandE.ReqItems) do
			local xItem = xPlayer.getInventoryItem(k)
			local roll = math.random(100)
			if roll%2 == 0 then
				xPlayer.removeInventoryItem(k, 1)
				Notify(xPlayer.source, 'You broke your '..xItem.name)
			end
		end
	else
		print('error for xPlayer')
	end
end)

RegisterServerEvent('CompleteHousing:doorKnock')
AddEventHandler('CompleteHousing:doorKnock', function(house, isRaid)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local xOwner, pos
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		if spawnedHouseSpots[house.id] then
			xOwner = ESX.GetPlayerFromIdentifier(house.owner)
			pos = spawnedHouseSpots[house.id].spot
		end
		if isRaid ~= nil then
			if isRaid == 'true' then
				if xOwner ~= nil and type(xOwner) == 'table' then
					TriggerClientEvent('CompleteHousing:spawnHome', xPlayer.source, house, 'owned', pos, 'true')
				else
					if Config then
						if Config.Raids then
							if Config.Raids.Offline then
								TriggerClientEvent('CompleteHousing:spawnHome', xPlayer.source, house, 'owned')
							else
								if Config.Strings then
									if Config.Strings.notHome then
										if Notify ~= nil then Notify(xPlayer.source, Config.Strings.notHome) end
									else
										print('not home string error')
									end
								else
									print('string error')
								end
							end
						else
							print('raid error')
						end
					else
						print('config error')
					end
				end
			elseif isRaid == 'false' then
				if xOwner ~= nil and type(xOwner) == 'table' then
					TriggerClientEvent('CompleteHousing:spawnHome', xPlayer.source, house, 'owned', pos, 'false')
				else
					TriggerClientEvent('CompleteHousing:spawnHome', xPlayer.source, house, 'owned')
				end
			end
		else
			if xOwner ~= nil and type(xOwner) == 'table' then
				TriggerClientEvent('CompleteHousing:doorKnock', xOwner.source, src)
			else
				if Config then
					if Config.Strings then
						if Config.Strings.notHome then
							if Notify ~= nil then Notify(xPlayer.source, Config.Strings.notHome) end
						else
							print('not home string error')
						end
					else
						print('string error')
					end
				else
					print('config error')
				end
			end
		end
	else
		print('error for xPlayer')
	end
end)

RegisterServerEvent('CompleteHousing:declineAuction')
AddEventHandler('CompleteHousing:declineAuction', function()
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if xPlayer ~= nil and type(xPlayer) == 'table' then
		if Config then
			if Config.Auction then
				if Config.Auction.DeclineFee then
					xPlayer.removeAccountMoney('bank', Config.Auction.DeclineFee)
					if Config.Strings.aucCanc then
						if Notify ~= nil then Notify(xPlayer.source, Config.Strings.aucCanc:format(Config.Auction.DeclineFee)) end
					else
						print('auction cancel string error')
					end
				else
					print('auction decline fee error')
				end
			else
				print('auction error')
			end
		else
			print('config error')
		end
	else
		print('error for xPlayer')
	end
end)

RegisterServerEvent('CompleteHousing:playerEnteredExitedHome')
AddEventHandler('CompleteHousing:playerEnteredExitedHome', function(address, enter)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if enter then
		MySQL.Async.execute('UPDATE users SET homeIn = @homeIn WHERE identifier = @identifier', {['@homeIn'] = address, ['@identifier'] = xPlayer.identifier})
	else
		MySQL.Async.execute('UPDATE users SET homeIn = @homeIn WHERE identifier = @identifier', {['@homeIn'] = 'none', ['@identifier'] = xPlayer.identifier})
	end
end)

RegisterServerEvent('CompleteHousing:saveOutfit')
AddEventHandler('CompleteHousing:saveOutfit', function(name, skin, value)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if value == 'add' then
		MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(res)
			local wardrobe = json.decode(res[1].wardrobe)
			table.insert(wardrobe, {label = name, value = skin})
			MySQL.Async.execute('UPDATE users SET wardrobe = @wardrobe WHERE identifier = @id', {['@id'] = xPlayer.identifier, ['@wardrobe'] = json.encode(wardrobe)})
		end)
	elseif value == 'rem' then
		MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(res)
			local wardrobe = json.decode(res[1].wardrobe)
			for k,v in pairs(wardrobe) do
				if name == v.label then
					table.remove(wardrobe, k)
					MySQL.Async.execute('UPDATE users SET wardrobe = @wardrobe WHERE identifier = @id', {['@id'] = xPlayer.identifier, ['@wardrobe'] = json.encode(wardrobe)})
				end
			end
		end)
	end
end)

RegisterServerEvent('CompleteHousing:placeOutFurniture')
AddEventHandler('CompleteHousing:placeOutFurniture', function(house, x, y, z, rotation, item, name)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
  local curHouseCacheID = GetHouseCache(house.id)
	MySQL.Async.fetchAll('SELECT furniture FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(result)
		local ownedFurn
		if not result[1].furniture then
			ownedFurn = {}
		else
			ownedFurn = json.decode(result[1].furniture)
		end
		for k,v in pairs(ownedFurn) do
			if name == v.label then
				v.count = v.count - 1
			end
			if v.count <= 0 then
				ownedFurn[k] = nil
			end
		end
		MySQL.Async.execute('UPDATE users SET furniture = @furn WHERE identifier = @id', {
			['@id'] = xPlayer.identifier, 
			['@furn'] = json.encode(ownedFurn)
		})
	end)
  local furn = json.decode(houseCache[curHouseCacheID].furniture)
  table.insert(furn.outside, {x = doRound(x, 2), y = doRound(y, 2), z = doRound(z, 2), rotation = rotation, prop = item, label = name})
  houseCache[curHouseCacheID].furniture = json.encode(furn)
  houseCache[curHouseCacheID].hasBeenUpdated = true
  curHouse = curHouseCacheID
  TriggerEvent('CompleteHousing:updateHomes')
end)

RegisterServerEvent('CompleteHousing:placeFurniture')
AddEventHandler('CompleteHousing:placeFurniture', function(house, x, y, z, rotation, item, name, isMLO)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
  local curHouseCacheID = GetHouseCache(house.id)
	MySQL.Async.fetchAll('SELECT furniture FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(result)
		local ownedFurn
		if not result[1].furniture then
			ownedFurn = {}
		else
			ownedFurn = json.decode(result[1].furniture)
		end
		for k,v in pairs(ownedFurn) do
			if name == v.label then
				v.count = v.count - 1
			end
			if v.count <= 0 then
				ownedFurn[k] = nil
			end
		end
		MySQL.Async.execute('UPDATE users SET furniture = @furn WHERE identifier = @id', {
			['@id'] = xPlayer.identifier, 
			['@furn'] = json.encode(ownedFurn)
		})
	end)
  local furn = json.decode(houseCache[curHouseCacheID].furniture)
  if not isMLO then
    table.insert(furn.inside, {x = doRound(x, 2), y = doRound(y, 2), z = doRound(z, 2), rotation = rotation, prop = item, label = name})
  else
    table.insert(furn.outside, {x = doRound(x, 2), y = doRound(y, 2), z = doRound(z, 2), rotation = rotation, prop = item, label = name})
  end
  houseCache[curHouseCacheID].furniture = json.encode(furn)
  houseCache[curHouseCacheID].hasBeenUpdated = true
  curHouse = curHouseCacheID
  TriggerEvent('CompleteHousing:updateHomes')
end)

RegisterServerEvent('CompleteHousing:removeFurniture')
AddEventHandler('CompleteHousing:removeFurniture', function(house, pos, model, name, isMLO)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
  local curHouseCacheID = GetHouseCache(house.id)
  local furn = json.decode(houseCache[curHouseCacheID].furniture)
  if not isMLO then
    for k,v in pairs(furn.inside) do
      if doRound(v.x, 2) == doRound(pos.x, 2) and doRound(v.y, 2) == doRound(pos.y, 2) and doRound(v.z, 2) == doRound(pos.z, 2) then
        table.remove(furn.inside, k)
      end
    end
  else
    for k,v in pairs(furn.outside) do
      if doRound(v.x, 2) == doRound(pos.x, 2) and doRound(v.y, 2) == doRound(pos.y, 2) and doRound(v.z, 2) == doRound(pos.z, 2) then
        table.remove(furn.outside, k)
      end
    end
  end
  houseCache[curHouseCacheID].furniture = json.encode(furn)
  houseCache[curHouseCacheID].hasBeenUpdated = true
	MySQL.Async.fetchAll('SELECT furniture FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(result)
		local ownedFurn
		if not result[1].furniture then
			ownedFurn = {}
		else
			ownedFurn = json.decode(result[1].furniture)
		end
		local item = {label = name, prop = model}
		if not ownedFurn[item.label] then
			table.insert(item, count)
			item.count = 1
			ownedFurn[item.label] = item
		else
			ownedFurn[item.label].count = ownedFurn[item.label].count + 1
		end
		MySQL.Async.execute('UPDATE users SET furniture = @furn WHERE identifier = @id', {
			['@id'] = xPlayer.identifier,
			['@furn'] = json.encode(ownedFurn)
		},function(change)
      if change then
        Citizen.Wait(100)
        curHouse = curHouseCacheID
        TriggerEvent('CompleteHousing:updateHomes')
      end
    end)
	end)
end)

RegisterServerEvent('CompleteHousing:removeOutFurniture')
AddEventHandler('CompleteHousing:removeOutFurniture', function(house, pos, model, name)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
  local curHouseCacheID = GetHouseCache(house.id)
  local furn = json.decode(houseCache[curHouseCacheID].furniture)
  for k,v in pairs(furn.outside) do
    if doRound(v.x, 2) == doRound(pos.x, 2) and doRound(v.y, 2) == doRound(pos.y, 2) and doRound(v.z, 2) == doRound(pos.z, 2) then
      table.remove(furn.outside, k)
    end
  end
  houseCache[curHouseCacheID].furniture = json.encode(furn)
  houseCache[curHouseCacheID].hasBeenUpdated = true
	MySQL.Async.fetchAll('SELECT furniture FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(result)
		local ownedFurn
		if not result[1].furniture then
			ownedFurn = {}
		else
			ownedFurn = json.decode(result[1].furniture)
		end
		local item = {label = name, prop = model}
		if not ownedFurn[item.label] then
			table.insert(item, count)
			item.count = 1
			ownedFurn[item.label] = item
		else
			ownedFurn[item.label].count = ownedFurn[item.label].count + 1
		end
		MySQL.Async.execute('UPDATE users SET furniture = @furn WHERE identifier = @id', {
			['@id'] = xPlayer.identifier,
			['@furn'] = json.encode(ownedFurn)
		},function(change)
      if change then
        Citizen.Wait(100)
        curHouse = curHouseCacheID
        TriggerEvent('CompleteHousing:updateHomes')
      end
    end)
	end)
end)

RegisterServerEvent('CompleteHousing:createHouse')
AddEventHandler('CompleteHousing:createHouse', function(address, x, y, z, shell, price, draw, garageType, isSpec)
  SaveHouses()
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local door = {x = x, y = y, z = z}
	local que = 'INSERT INTO houses (id, door, shell, price, draw, furniture, parkings, purDate, `keys`, doors, garages, storage, wardrobe, garageType) VALUES (@id, @door, @shell, @price, @draw, @furniture, @parkings, @purDate, @keys, @doors, @garages, @storage, @wardrobe, @garageType)'
	local queTab = {
		['@id'] = address,
		['@door'] = json.encode(door),
		['@shell'] = shell,
		['@draw'] = draw,
		['@price'] = price,
		['@furniture'] = json.encode({inside = {}, outside = {}}),
		['@parkings'] = json.encode({}),
		['@purDate'] = json.encode({}),
		['@keys'] = json.encode({}),
		['@doors'] = json.encode({}),
		['@garages'] = json.encode({}),
		['@storage'] = json.encode({x = 0.00, y = 0.00, z = 0.00}),
		['@wardrobe'] = json.encode({x = 0.00, y = 0.00, z = 0.00}),
		['@garageType'] = garageType
	}
	if isSpec ~= nil then
		if Config.Creation.Payout then
			que = 'INSERT INTO houses (id, prevowner, door, shell, price, isSpec, draw, furniture, parkings, purDate, `keys`, doors, garages, storage, wardrobe, garageType) VALUES (@id, @prevowner, @door, @shell, @price, @isSpec, @draw, @furniture, @parkings, @purDate, @keys, @doors, @garages, @storage, @wardrobe, @garageType)'
		else
			que = 'INSERT INTO houses (id, door, shell, price, isSpec, draw, furniture, parkings, purDate, `keys`, doors, garages, storage, wardrobe, garageType) VALUES (@id, @door, @shell, @price, @isSpec, @draw, @furniture, @parkings, @purDate, @keys, @doors, @garages, @storage, @wardrobe, @garageType)'
		end
	elseif Config.Creation.Payout then
		que = 'INSERT INTO houses (id, prevowner, door, shell, price, draw, furniture, parkings, purDate, `keys`, doors, garages, storage, wardrobe, garageType) VALUES (@id, @prevowner, @door, @shell, @price, @draw, @furniture, @parkings, @purDate, @keys, @doors, @garages, @storage, @wardrobe, @garageType)'
	end
	if isSpec == 'yes' then
		queTab['@isSpec'] = 1
	elseif isSpec == 'no' then
		queTab['@isSpec'] = 0
	elseif isSpec == 'spec' then
		queTab['@isSpec'] = 2
	end
	if Config.Creation.Payout then
		queTab['@prevowner'] = 'society_'..xPlayer.job.name
	end
	MySQL.Async.execute(que, queTab, function(rowsChanged)
		if rowsChanged then
			Notify(src, Config.Strings.houCrea:format(address,x,y,z,shell,price))
			if Config.Creation.Payout then
				xPlayer.addAccountMoney('bank', (price*(Config.Creation.Percent/100)))
			end
			Citizen.Wait(100)
      curHouse = address
      houseCache[#houseCache+1] = {
        id = curHouse,
        owner = 'nil',
        prevowner = 'nil',
        ownerDiscord = 'nil',
        door = queTab['@door'],
        shell = queTab['@shell'],
        draw = queTab['@draw'],
        price = queTab['@price'],
        isSpec = queTab['@isSpec'],
        furniture = queTab['@furniture'],
        parkings = queTab['@parkings'],
        purDate = queTab['@purDate'],
        locked = 1,
        keys = queTab['@keys'],
        doors = queTab['@doors'],
        garages = queTab['@garages'],
        storage = queTab['@storage'],
        wardrobe = queTab['@wardrobe'],
        garageType = queTab['@garageType']
      }
			TriggerEvent('CompleteHousing:updateHomes', true)
		end
	end)
end)

RegisterServerEvent('CompleteHousing:deleteHome')
AddEventHandler('CompleteHousing:deleteHome', function(address)
  SaveHouses()
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if HasJob(xPlayer) then
		MySQL.Async.execute('DELETE FROM houses WHERE id = @id', {['@id'] = address}, function(change)
			if change then
				Citizen.Wait(100)
				TriggerClientEvent('CompleteHousing:updateHomes', -1, address)
			end
		end)
	else
		Notify(xPlayer.source, Config.Strings.noPerms)
	end
end)

RegisterServerEvent('CompleteHousing:purchaseFurn')
AddEventHandler('CompleteHousing:purchaseFurn', function(item, amount)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local account = 'cash'
	local cash = xPlayer.getMoney()
	item.price = doRound(item.price)*amount
	if cash >= item.price then
		xPlayer.removeMoney(item.price)
		MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(result)
			if result and result[1] then
				local ownedFurn
				if not result[1].furniture then
					ownedFurn = {}
				else
					ownedFurn = json.decode(result[1].furniture)
				end
				if not ownedFurn[item.label] then
					table.insert(item, count)
					item.count = 1
					ownedFurn[item.label] = item
				else
					ownedFurn[item.label].count = ownedFurn[item.label].count + 1
				end
				MySQL.Async.execute('UPDATE users SET furniture = @furn WHERE identifier = @id', {
					['@id'] = xPlayer.identifier,
					['@furn'] = json.encode(ownedFurn)
				})
			end
		end)
		Notify(src, Config.Strings.furPrch:format(item.label,item.price,account))
	else
		local inAccount, accountIn = HasMoneyInAccount(xPlayer, item.price)
		if inAccount then
			account = accountIn
			xPlayer.removeAccountMoney(accountIn, item.price)
			MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @id', {['@id'] = xPlayer.identifier}, function(result)
				if result and result[1] then
					local ownedFurn
					if not result[1].furniture then
						ownedFurn = {}
					else
						ownedFurn = json.decode(result[1].furniture)
					end
					if not ownedFurn[item.label] then
						table.insert(item, count)
						item.count = 1
						ownedFurn[item.label] = item
					else
						ownedFurn[item.label].count = ownedFurn[item.label].count + 1
					end
					MySQL.Async.execute('UPDATE users SET furniture = @furn WHERE identifier = @id', {
						['@id'] = xPlayer.identifier,
						['@furn'] = json.encode(ownedFurn)
					})
				end
			end)
			Notify(src, Config.Strings.furPrch:format(item.label,item.price,account))
		else
			Notify(src, Config.Strings.noMoney)
		end
	end
end)

RegisterServerEvent('CompleteHousing:purchaseHome')
AddEventHandler('CompleteHousing:purchaseHome', function(home, furn, spec)
  SaveHouses()
	local src = source
	local xPlayer, xTarget = ESX.GetPlayerFromId(src)
	local limit = Config.BoughtHouseLimit
	MySQL.Async.fetchAll('SELECT * FROM houses WHERE owner = @owner', {['@owner'] = xPlayer.identifier}, function(res)
		if res then
			if limit ~= 0 and #res >= limit then
				Notify(xPlayer.source, Config.Strings.tooMany)
			else
				local purDate = os.date("*t", os.time())
				if home.prevowner ~= 'nil' then
					xTarget = ESX.GetPlayerFromIdentifier(home.prevowner)
					if xPlayer.identifier == home.prevowner then
						-- MySQL.Async.execute('UPDATE houses SET owner = @owner, ownerName = @ownerName WHERE id = @id', {['@owner'] = xPlayer.identifier, ['@ownerName'] = GetPlayerName(xPlayer.source), ['@id'] = home.id}, function(rowsChanged)
							-- if rowsChanged then
								-- Notify(xPlayer.source, Config.Strings.offMark:format(home.id))
								-- Citizen.Wait(100)
                -- curHouse = home.id
								-- TriggerEvent('CompleteHousing:updateHomes', true)
							-- end
						-- end)
						return
					end
				end
				if spec == nil then
					local cash = xPlayer.getMoney()
					local price = home.price
					if furn ~= nil and furn == true then
						price = price + 50000
					end
					price = doRound(price)
					if cash >= price then
						xPlayer.removeMoney(price)
						if xTarget ~= nil then
							xTarget.addAccountMoney('bank', home.price)
							Notify(xTarget.source, Config.Strings.houSold:format(home.id,home.price))
						else
							if home.prevowner ~= 'nil' then
								if string.find(home.prevowner, 'society') then
									if Config.Creation.Payout then
										TriggerEvent('esx_addonaccount:getSharedAccount', home.prevowner, function(account)
                      if account ~= nil then
                        account.addMoney(home.price)
                      else
                        print('No account for society: '..home.prevowner)
                      end
										end)
									end
								else
									if Config.ESXLevel >= 3 then
										MySQL.Async.fetchAll('SELECT accounts FROM users WHERE identifier = @id', {['@id'] = home.prevowner}, function(accounts)
											for k,v in pairs(accounts[1]) do
												local monies = json.decode(v)
												monies.bank = monies.bank + home.price
												MySQL.Async.execute('UPDATE users SET accounts = @accounts WHERE identifier = @id', {
													['@id'] = home.prevowner,
													['@accounts'] = json.encode(monies)
												})
											end
										end)
									elseif Config.ESXLevel == 2 then
										MySQL.Async.execute('UPDATE user_accounts SET money = money + @bank WHERE identifier = @identifier AND name = @name',{
											['@identifier'] = home.prevowner,
											['@bank'] = home.price,
											['@name'] = 'bank'
										})
									elseif Config.ESXLevel == 1 then
										MySQL.Async.execute("UPDATE users SET bank = bank + @bank WHERE identifier = @identifier",{
											['@identifier'] = home.prevowner,
											['@bank'] = home.price
										})
									end
								end
							end
						end
            local logitem = {color = 0, title = 'Purchase Log', description = 'Home %s purchased by (Name: %s, ID: %s, Discord: <@%s>) from (Name: %s, ID: %s, Discord: <@%s>) for $%s at %s'}
            local d1 = GetPlayerIdentifiers(xPlayer.source)
            for i = 1,#d1 do
              if d1[i] and d1[i]:find('discord') then d1 = d1[i]; break; end
            end
            local d2, sellerName = home.ownerDiscord, 'Bank'
            if home.ownerName ~= 'nil' then
              sellerName = home.ownerName
            end
            if type(d1) ~= 'string' then d1 = ':Unavailable' end
            if d2 == 'nil' then d2 = ':Unavailable' end
            local dateStr = os.date('%d/%m/%y %H:%M:%S %p'):upper()
            logitem.description = logitem.description:format(home.id, GetPlayerName(xPlayer.source), xPlayer.identifier, d1:sub(d1:find(':')+1), sellerName, home.prevowner, d2:sub(d2:find(':')+1), tostring(home.price), dateStr)
            PerformHttpRequest(Webhook, function(err, text, headers) end, 
              'POST', json.encode({username = 'House Purchase Logs', content = '', embeds = {logitem}}), { ['Content-Type'] = 'application/json' }
            )
						MySQL.Async.execute('UPDATE houses SET failBuy = @fail, purDate = @purDate, owner = @owner, ownerName = @ownerName, ownerDiscord = @ownerDiscord WHERE id = @id', {
							['@fail'] = 'false',
							['@purDate'] = json.encode(purDate),
							['@owner'] = xPlayer.identifier,
							['@ownerName'] = GetPlayerName(xPlayer.source),
							['@ownerDiscord'] = d1,
							['@id'] = home.id
						}, function(rowsChanged)
							if rowsChanged then
								Notify(xPlayer.source, Config.Strings.houBawt:format(price,home.id))
								Citizen.Wait(100)
                curHouse = home.id
                for i = 1,#houseCache do
                  if houseCache[i].id == curHouse then
                    houseCache[i].owner = xPlayer.identifier
                    houseCache[i].ownerName = GetPlayerName(xPlayer.source)
                    break
                  end
                end
								TriggerEvent('CompleteHousing:updateHomes', true)
							end
						end)
						if furn ~= nil and furn == true then
							MySQL.Async.fetchAll('SELECT * FROM houses WHERE id = @id', {['@id'] = home.id}, function(result)
								if result and result[1] then
									local furniture = json.decode(result[1].furniture)
									furniture.inside = {}
									for i = 1,#Config.FurnishedHouses[home.shell] do
										table.insert(furniture.inside, {label = Config.FurnishedHouses[home.shell][i].label, prop = Config.FurnishedHouses[home.shell][i].prop, x = doRound(Config.FurnishedHouses[home.shell][i].pos.x, 2), y = doRound(Config.FurnishedHouses[home.shell][i].pos.y, 2), z = doRound(Config.FurnishedHouses[home.shell][i].pos.z, 2), heading = Config.FurnishedHouses[home.shell][i].heading})
									end
									MySQL.Async.execute('UPDATE houses SET furniture = @furn WHERE id = @id', {['@id'] = home.id, ['@furn'] = json.encode(furniture)})
								end
							end)
						end
						if furn ~= nil and furn == false then
							local furniture = {}
							furniture.inside = {}
							furniture.outside = {}
							MySQL.Async.execute('UPDATE houses SET furniture = @furn WHERE id = @id', {['@id'] = home.id, ['@furn'] = json.encode(furniture)})
						end
					else
						local bank = xPlayer.getAccount('bank')
						if bank.money >= price then
							xPlayer.removeAccountMoney('bank', price)
							if xTarget ~= nil then
								xTarget.addAccountMoney('bank', home.price)
								Notify(xTarget.source, Config.Strings.houSold:format(home.id,home.price))
							else
								if home.prevowner ~= 'nil' then
									if string.find(home.prevowner, 'society') then
										if Config.Creation.Payout then
											TriggerEvent('esx_addonaccount:getSharedAccount', home.prevowner, function(account)
                        if account ~= nil then
                          account.addMoney(home.price)
												else
													print('No account for society: '..home.prevowner)
												end
											end)
										end
									else
										if Config.ESXLevel >= 3 then
											MySQL.Async.fetchAll('SELECT accounts FROM users WHERE identifier = @id', {['@id'] = home.prevowner}, function(accounts)
												for k,v in pairs(accounts[1]) do
													local monies = json.decode(v)
													monies.bank = monies.bank + home.price
													MySQL.Async.execute('UPDATE users SET accounts = @accounts WHERE identifier = @id', {
														['@id'] = home.prevowner,
														['@accounts'] = json.encode(monies)
													})
												end
											end)
										elseif Config.ESXLevel == 2 then
											MySQL.Async.execute('UPDATE user_accounts SET money = money + @bank WHERE identifier = @identifier AND name = @name',{
												['@identifier'] = home.prevowner,
												['@bank'] = home.price,
												['@name'] = 'bank'
											})
										elseif Config.ESXLevel == 1 then
											MySQL.Async.execute("UPDATE users SET bank = bank + @bank WHERE identifier = @identifier",{
												['@identifier'] = home.prevowner,
												['@bank'] = home.price
											})
										end
									end
								end
							end
              local logitem = {color = 0, title = 'Purchase Log', description = 'Home %s purchased by (Name: %s, ID: %s, Discord: <@%s>) from (Name: %s, ID: %s, Discord: <@%s>) for $%s at %s'}
              local d1 = GetPlayerIdentifiers(xPlayer.source)
              for i = 1,#d1 do
                if d1[i] and d1[i]:find('discord') then d1 = d1[i]; break; end
              end
              local d2, sellerName = home.ownerDiscord, 'Bank'
              if home.ownerName ~= 'nil' then
                sellerName = home.ownerName
              end
              if type(d1) ~= 'string' then d1 = ':Unavailable' end
              if d2 == 'nil' then d2 = ':Unavailable' end
              local dateStr = os.date('%d/%m/%y %H:%M:%S %p'):upper()
              logitem.description = logitem.description:format(home.id, GetPlayerName(xPlayer.source), xPlayer.identifier, d1:sub(d1:find(':')+1), sellerName, home.prevowner, d2:sub(d2:find(':')+1), tostring(home.price), dateStr)
              PerformHttpRequest(Webhook, function(err, text, headers) end, 
                'POST', json.encode({username = 'House Purchase Logs', content = '', embeds = {logitem}}), { ['Content-Type'] = 'application/json' }
              )
              MySQL.Async.execute('UPDATE houses SET failBuy = @fail, purDate = @purDate, owner = @owner, ownerName = @ownerName, ownerDiscord = @ownerDiscord WHERE id = @id', {
                ['@fail'] = 'false',
                ['@purDate'] = json.encode(purDate),
                ['@owner'] = xPlayer.identifier,
                ['@ownerName'] = GetPlayerName(xPlayer.source),
                ['@ownerDiscord'] = d1,
                ['@id'] = home.id
              }, function(rowsChanged)
                if rowsChanged then
                  Notify(xPlayer.source, Config.Strings.houBawt:format(price,home.id))
                  Citizen.Wait(100)
                  curHouse = home.id
                  for i = 1,#houseCache do
                    if houseCache[i].id == curHouse then
                      houseCache[i].owner = xPlayer.identifier
                      houseCache[i].ownerName = GetPlayerName(xPlayer.source)
                      break
                    end
                  end
                  TriggerEvent('CompleteHousing:updateHomes', true)
                end
              end)
							if furn == true then
								MySQL.Async.fetchAll('SELECT * FROM houses WHERE id = @id', {['@id'] = home.id}, function(result)
									if result and result[1] then
										local furniture = json.decode(result[1].furniture)
										furniture.inside = {}
										for i = 1,#Config.FurnishedHouses[home.shell] do
											table.insert(furniture.inside, {label = Config.FurnishedHouses[home.shell][i].label, prop = Config.FurnishedHouses[home.shell][i].prop, x = doRound(Config.FurnishedHouses[home.shell][i].pos.x, 2), y = doRound(Config.FurnishedHouses[home.shell][i].pos.y, 2), z = doRound(Config.FurnishedHouses[home.shell][i].pos.z, 2), heading = Config.FurnishedHouses[home.shell][i].heading})
										end
										MySQL.Async.execute('UPDATE houses SET furniture = @furn WHERE id = @id', {['@id'] = home.id, ['@furn'] = json.encode(furniture)})
									end
								end)
							end
							if furn == false then
								local furniture = {}
								furniture.inside = {}
								furniture.outside = {}
								MySQL.Async.execute('UPDATE houses SET furniture = @furn WHERE id = @id', {['@id'] = home.id, ['@furn'] = json.encode(furniture)})
							end
						else
							Notify(src, Config.Strings.noMoney)
						end
					end
				else
					local specialMun = xPlayer.getAccount(Config.SpecialProperties.Account)
					local price = home.price*(Config.SpecialProperties.Percentage/100)
					price = doRound(price)
					if specialMun ~= nil and type(specialMun) == 'table' then
						if specialMun.money >= price then
							xPlayer.removeAccountMoney(Config.SpecialProperties.Account, price)
							if xTarget ~= nil then
								xTarget.addAccountMoney(Config.SpecialProperties.Account, price)
								Notify(xTarget.source, Config.Strings.houSold:format(home.id,price))
							else
								if home.prevowner ~= 'nil' then
									if string.find(home.prevowner, 'society') then
										if Config.Creation.Payout then
											TriggerEvent('esx_addonaccount:getSharedAccount', home.prevowner, function(account)
												if account ~= nil then
													account.addMoney(home.price)
												else
													print('No account for society: '..home.prevowner)
												end
											end)
										end
									else
										if Config.ESXLevel >= 3 then
											MySQL.Async.fetchAll('SELECT accounts FROM users WHERE identifier = @id', {['@id'] = home.prevowner}, function(accounts)
												for k,v in pairs(accounts[1]) do
													local monies = json.decode(v)
													monies[Config.SpecialProperties.Account] = monies[Config.SpecialProperties.Account] + price
													MySQL.Async.execute('UPDATE users SET accounts = @accounts WHERE identifier = @id', {
														['@id'] = home.prevowner,
														['@accounts'] = json.encode(monies)
													})
												end
											end)
										elseif Config.ESXLevel == 2 then
											MySQL.Async.execute('UPDATE user_accounts SET money = money + @bank WHERE identifier = @identifier AND name = @name',{
												['@identifier'] = home.prevowner,
												['@bank'] = price,
												['@name'] = Config.SpecialProperties.Account
											})
										elseif Config.ESXLevel == 1 then
											MySQL.Async.execute('UPDATE users SET '..Config.SpecialProperties.Account..' = '..Config.SpecialProperties.Account..' + @bank WHERE identifier = @identifier',{
												['@identifier'] = home.prevowner,
												['@bank'] = price
											})
										end
									end
								end
							end
              local logitem = {color = 0, title = 'Purchase Log', description = 'Home %s purchased by (Name: %s, ID: %s, Discord: <@%s>) from (Name: %s, ID: %s, Discord: <@%s>) for $%s at %s'}
              local d1 = GetPlayerIdentifiers(xPlayer.source)
              for i = 1,#d1 do
                if d1[i] and d1[i]:find('discord') then d1 = d1[i]; break; end
              end
              local d2, sellerName = home.ownerDiscord, 'Bank'
              if home.ownerName ~= 'nil' then
                sellerName = home.ownerName
              end
              if type(d1) ~= 'string' then d1 = ':Unavailable' end
              if d2 == 'nil' then d2 = ':Unavailable' end
              local dateStr = os.date('%d/%m/%y %H:%M:%S %p'):upper()
              logitem.description = logitem.description:format(home.id, GetPlayerName(xPlayer.source), xPlayer.identifier, d1:sub(d1:find(':')+1), sellerName, home.prevowner, d2:sub(d2:find(':')+1), tostring(home.price), dateStr)
              PerformHttpRequest(Webhook, function(err, text, headers) end, 
                'POST', json.encode({username = 'House Purchase Logs', content = '', embeds = {logitem}}), { ['Content-Type'] = 'application/json' }
              )
              MySQL.Async.execute('UPDATE houses SET failBuy = @fail, purDate = @purDate, owner = @owner, ownerName = @ownerName, ownerDiscord = @ownerDiscord WHERE id = @id', {
                ['@fail'] = 'false',
                ['@purDate'] = json.encode(purDate),
                ['@owner'] = xPlayer.identifier,
                ['@ownerName'] = GetPlayerName(xPlayer.source),
                ['@ownerDiscord'] = d1,
                ['@id'] = home.id
              }, function(rowsChanged)
                if rowsChanged then
                  Notify(xPlayer.source, Config.Strings.houBawt:format(price,home.id))
                  Citizen.Wait(100)
                  curHouse = home.id
                  for i = 1,#houseCache do
                    if houseCache[i].id == curHouse then
                      houseCache[i].owner = xPlayer.identifier
                      houseCache[i].ownerName = GetPlayerName(xPlayer.source)
                      break
                    end
                  end
                  TriggerEvent('CompleteHousing:updateHomes', true)
                end
              end)
							if furn == true then
								MySQL.Async.fetchAll('SELECT * FROM houses WHERE id = @id', {['@id'] = home.id}, function(result)
									if result and result[1] then
										local furniture = json.decode(result[1].furniture)
										furniture.inside = {}
										for i = 1,#Config.FurnishedHouses[home.shell] do
											table.insert(furniture.inside, {label = Config.FurnishedHouses[home.shell][i].label, prop = Config.FurnishedHouses[home.shell][i].prop, x = doRound(Config.FurnishedHouses[home.shell][i].pos.x, 2), y = doRound(Config.FurnishedHouses[home.shell][i].pos.y, 2), z = doRound(Config.FurnishedHouses[home.shell][i].pos.z, 2), heading = Config.FurnishedHouses[home.shell][i].heading})
										end
										MySQL.Async.execute('UPDATE houses SET furniture = @furn WHERE id = @id', {['@id'] = home.id, ['@furn'] = json.encode(furniture)})
									end
								end)
							end
							if furn == false then
								local furniture = {}
								furniture.inside = {}
								furniture.outside = {}
								MySQL.Async.execute('UPDATE houses SET furniture = @furn WHERE id = @id', {['@id'] = home.id, ['@furn'] = json.encode(furniture)})
							end
						else
							Notify(src, Config.Strings.noMoney)
						end
					else
						print('No account found for '..Config.SpecialProperties.Account)
					end
				end
			end
		end
	end)
end)

RegisterServerEvent('CompleteHousing:checkOwnedDates')
AddEventHandler('CompleteHousing:checkOwnedDates', function()
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local toDate = os.date("*t", os.time())
	MySQL.Async.fetchAll('SELECT * FROM houses WHERE owner = @owner', {['@owner'] = xPlayer.identifier}, function(result)
		for i = 1,#result do
			local purDate = json.decode(result[i].purDate)
			if purDate.month ~= toDate.month then
				if purDate.day > 30 then purDate.day = 30 end
				if toDate.day >= purDate.day then
					local bank = xPlayer.getAccount('bank')
					if bank ~= nil and type(bank) == 'table' then
						if bank.money >= result[i].price*(Config.MonthlyContracts.Percent/100) then
              local newDate = os.date("*t", os.time())
              MySQL.Async.execute('UPDATE houses SET purDate = @purDate WHERE id = @id', {['@purDate'] = json.encode(newDate), ['@id'] = result[i].id}, function(changed)
                if changed then
                  xPlayer.removeAccountMoney('bank', result[i].price*(Config.MonthlyContracts.Percent/100))
                  Notify(src, Config.Strings.payLeas:format(result[i].id))
                end
              end)
						else
							MySQL.Async.execute('UPDATE houses SET owner = @owner, prevowner = @owner WHERE id = @id', {['@owner'] = 'nil', ['@id'] = result[i].id}, function(changed)
                if changed then
                  Notify(src, Config.Strings.leaseUp:format(result[i].id))
                  Citizen.Wait(100)
                  curHouse = result[i].id
                  for i = 1,#houseCache do
                    if houseCache[i].id == curHouse then
                      houseCache[i].owner = 'nil'
                      break
                    end
                  end
                  TriggerEvent('CompleteHousing:updateHomes')
                end
              end)
						end
					else
						print('bank error')
					end
				end
			end
		end
	end)
end)

RegisterServerEvent('CompleteHousing:sellHouse')
AddEventHandler('CompleteHousing:sellHouse', function(house, price, market)
  SaveHouses()
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if market == 'market' then
		MySQL.Async.execute('UPDATE houses SET owner = @owner, prevowner = @prevowner, price = @price, `keys` = @keys WHERE id = @id', {
			['@owner'] = 'nil',
			['@prevowner'] = xPlayer.identifier,
			['@price'] = price,
			['@id'] = house.id,
      ['@keys'] = json.encode({})
		}, function(changed)
      if changed then
        Citizen.Wait(100)
        curHouse = house.id
        for i = 1,#houseCache do
          if houseCache[i].id == curHouse then
            houseCache[i].owner = 'nil'
            houseCache[i].prevowner = xPlayer.identifier
            houseCache[i].price = price
            houseCache[i].keys = json.encode({})
            break
          end
        end
        TriggerEvent('CompleteHousing:updateHomes', true)
      end
    end)
	elseif market == 'byback' then
		MySQL.Async.execute('UPDATE houses SET owner = @owner, prevowner = @owner, `keys` = @keys WHERE id = @id', {['@owner'] = 'nil', ['@id'] = house.id, ['@keys'] = json.encode({})}, function(changed)
      if changed then
        Citizen.Wait(100)
        curHouse = house.id
        for i = 1,#houseCache do
          if houseCache[i].id == curHouse then
            houseCache[i].owner = 'nil'
            houseCache[i].prevowner = 'nil'
            houseCache[i].keys = json.encode({})
            break
          end
        end
        TriggerEvent('CompleteHousing:updateHomes', true)
        xPlayer.addAccountMoney('bank', price/(100/Config.BuyBack.Percent))
      end
    end)
	elseif market == 'auction' then
		MySQL.Async.execute('UPDATE houses SET owner = @owner, prevowner = @owner, price = @price, `keys` = @keys WHERE id = @id', {['@owner'] = 'nil', ['@price'] = price, ['@id'] = house.id, ['@keys'] = json.encode({})}, function(changed)
      if changed then
        Citizen.Wait(100)
        curHouse = house.id
        for i = 1,#houseCache do
          if houseCache[i].id == curHouse then
            houseCache[i].owner = 'nil'
            houseCache[i].prevowner = 'nil'
            houseCache[i].keys = json.encode({})
            break
          end
        end
        TriggerEvent('CompleteHousing:updateHomes', true)
        xPlayer.addAccountMoney('bank', price)
      end
    end)
	end
end)

RegisterServerEvent('CompleteHousing:refreshVehicles')
AddEventHandler('CompleteHousing:refreshVehicles', function(isFirst)
	local src = source
	local vehicles = {}
	MySQL.Async.fetchAll('SELECT * FROM house_parking', {}, function(result) 
		if result then
			for k,v in pairs(result) do
				local vehicle = json.decode(v.data)
				local plate   = v.plate
				table.insert(vehicles, {vehicle = vehicle, plate = plate})
			end
			if isFirst then
				Citizen.Wait(15000)
				TriggerClientEvent('CompleteHousing:refreshVehicles', src, vehicles)
			else
				TriggerClientEvent('CompleteHousing:refreshVehicles', -1, vehicles)
			end
		end
	end)
end)

RegisterServerEvent('CompleteHousing:playerLogin')
AddEventHandler('CompleteHousing:playerLogin', function()
  local src = source
  if not playersRequested[src] then
    playersRequested[src] = true
    CheckPlayerJob(src)
  end
end)

AddEventHandler('esx:setJob', function(pSrc, pJob, last)
  if PlayerJobs[last.name] ~= nil then
    for k,v in pairs(PlayerJobs[last.name]) do
      if v == pSrc then
        table.remove(PlayerJobs[last.name], k)
      end
    end
  end
  if PlayerJobs[pJob.name] ~= nil then
    local xPlayer = ESX.GetPlayerFromId(pSrc)
    print(string.format("Adding player %s to job table: %s", xPlayer.identifier, xPlayer.job.name))
    table.insert(PlayerJobs[xPlayer.job.name], xPlayer.source)
  end
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
  for k,v in pairs(PlayerJobs) do
    for i = 1,#v do
      if v[i] == playerId then
        v[i] = nil
      end
    end
  end
end)

AddEventHandler('onResourceStop', function(mod)
  if mod == GetCurrentResourceName() then
    SaveHouses()
  end
end)

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(60000)
    SaveHouses()
  end
end)


-- REG INVHUD STUFF

ESX.RegisterServerCallback('CompleteHousing:getInv', function(source, cb, invType, id)
	local xPlayer = ESX.GetPlayerFromId(source)
	MySQL.Async.fetchAll('SELECT * FROM inventories WHERE owner = @owner AND type = @type', {['@owner'] = id, ['@type'] = invType}, function(result)
		if result[1] then
			cb(json.decode(result[1].data))
		else
			MySQL.Async.execute('INSERT INTO `inventories` (owner, type, data) VALUES (@id, @type, @data)', {
				['@id'] = id,
				['@type'] = invType,
				['@data'] = json.encode({items = {}, weapons = {}, blackMoney = 0, cash = 0})
			}, function(rowsChanged)
				if rowsChanged then
					-- print('Inventory created for: '..id..' with type: '..type)
				end
			end)
			cb({items = {}, weapons = {}, blackMoney = 0, cash = 0})
		end
	end)
end)

RegisterServerEvent('CompleteHousing:putItem')
AddEventHandler('CompleteHousing:putItem', function(invType, owner, data, count)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if data.item.type == 'item_money' then
		data.item.type = 'item_account'
		data.item.name = 'money'
	end
	if data.item.type == 'item_standard' then
		local xItem = xPlayer.getInventoryItem(data.item.name)
		if xItem.count >= count then
			local inventory = {}
			MySQL.Async.fetchAll('SELECT * FROM inventories WHERE owner = @owner AND type = @type', {['@owner'] = owner, ['@type'] = invType}, function(result)
				if result[1] then
					inventory = json.decode(result[1].data)
					if IsInInv(inventory, data.item.name) then
						xPlayer.removeInventoryItem(data.item.name, count)
						inventory.items[data.item.name][1].count = inventory.items[data.item.name][1].count + count
						MySQL.Async.execute('UPDATE inventories SET data = @data WHERE owner = @owner AND type = @type', {
							['@owner'] = owner,
							['@type'] = invType,
							['@data'] = json.encode(inventory)
						}, function(rowsChanged)
							if rowsChanged then
								-- print('Inventory updated for: '..owner..' with type: '..invType)
							end
						end)
					else
						xPlayer.removeInventoryItem(data.item.name, count)
						inventory.items[data.item.name] = {}
						table.insert(inventory.items[data.item.name], {count = count, label = data.item.label})
						MySQL.Async.execute('UPDATE inventories SET data = @data WHERE owner = @owner AND type = @type', {
							['@owner'] = owner,
							['@type'] = invType,
							['@data'] = json.encode(inventory)
						}, function(rowsChanged)
							if rowsChanged then
								-- print('Inventory updated for: '..owner..' with type: '..invType)
							end
						end)
					end
				end
			end)
		else
			Notify(src, Config.Strings.uNtEnuf:format(data.item.name))
		end
	elseif data.item.type == 'item_weapon' then
		if xPlayer.hasWeapon(data.item.name) then
			local inventory = {}
			MySQL.Async.fetchAll('SELECT * FROM inventories WHERE owner = @owner AND type = @type', {['@owner'] = owner, ['@type'] = invType}, function(result)
				if result[1] then
					inventory = json.decode(result[1].data)
					if IsInInv(inventory, data.item.name) then
						xPlayer.removeWeapon(data.item.name)
						table.insert(inventory.weapons[data.item.name], {count = count, label = data.item.label})
						MySQL.Async.execute('UPDATE inventories SET data = @data WHERE owner = @owner AND type = @type', {
							['@owner'] = owner,
							['@type'] = invType,
							['@data'] = json.encode(inventory)
						}, function(rowsChanged)
							if rowsChanged then
								-- print('Inventory updated for: '..owner..' with type: '..invType)
							end
						end)
					else
						xPlayer.removeWeapon(data.item.name)
						inventory.weapons[data.item.name] = {}
						table.insert(inventory.weapons[data.item.name], {count = count, label = data.item.label})
						MySQL.Async.execute('UPDATE inventories SET data = @data WHERE owner = @owner AND type = @type', {
							['@owner'] = owner,
							['@type'] = invType,
							['@data'] = json.encode(inventory)
						}, function(rowsChanged)
							if rowsChanged then
								-- print('Inventory updated for: '..owner..' with type: '..invType)
							end
						end)
					end
				end
			end)
		else
			Notify(src, Config.Strings.noWeapo)
		end
	elseif data.item.type == 'item_account' then
		local accountName, money
		if data.item.name == 'money' then
			accountName = 'cash'
			money = xPlayer.getMoney()
		elseif data.item.name == 'black_money' then
			accountName = 'blackMoney'
			money = xPlayer.getAccount(data.item.name).money
		end
		if money >= count then
			local inventory = {}
			MySQL.Async.fetchAll('SELECT * FROM inventories WHERE owner = @owner AND type = @type', {['@owner'] = owner, ['@type'] = invType}, function(result)
				if result[1] then
					inventory = json.decode(result[1].data)
					if data.item.name == 'money' then
						xPlayer.removeMoney(count)
					else
						xPlayer.removeAccountMoney(data.item.name, count)
					end
					inventory[accountName] = inventory[accountName] + count
					MySQL.Async.execute('UPDATE inventories SET data = @data WHERE owner = @owner AND type = @type', {
						['@owner'] = owner,
						['@type'] = invType,
						['@data'] = json.encode(inventory)
					}, function(rowsChanged)
						if rowsChanged then
							-- print('Inventory updated for: '..owner..' with type: '..invType)
						end
					end)
				end
			end)
		else
			Notify(src, Config.Strings.misCash)
		end
	end
end)

RegisterServerEvent('CompleteHousing:getItem')
AddEventHandler('CompleteHousing:getItem', function(invType, owner, data, count)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	if data.item.type == 'item_money' then
		data.item.type = 'item_account'
		data.item.name = 'money'
	end
	if data.item.type == 'item_standard' then
		local xItem = xPlayer.getInventoryItem(data.item.name)
		if xPlayer.canCarryItem ~= nil then
			if xPlayer.canCarryItem(data.item.name, count) then
				local inventory = {}
				MySQL.Async.fetchAll('SELECT * FROM inventories WHERE owner = @owner AND type = @type', {['@owner'] = owner, ['@type'] = invType}, function(result)
					if result[1] then
						inventory = json.decode(result[1].data)
						if IsInInv(inventory, data.item.name) then
							if inventory.items[data.item.name][1].count >= count then
								xPlayer.addInventoryItem(data.item.name, count)
								inventory.items[data.item.name][1].count = inventory.items[data.item.name][1].count - count
								if inventory.items[data.item.name][1].count <= 0 then
									inventory.items[data.item.name] = nil
								end
								MySQL.Async.execute('UPDATE inventories SET data = @data WHERE owner = @owner AND type = @type', {
									['@owner'] = owner,
									['@type'] = invType,
									['@data'] = json.encode(inventory)
								}, function(rowsChanged)
									if rowsChanged then
										-- print('Inventory updated for: '..owner..' with type: '..invType)
									end
								end)
							else
								Notify(src, Config.Strings.inNtNuf)
							end
						else
							Notify(src, Config.Strings.inNtNuf)
						end
					end
				end)
			else
				Notify(src, Config.Strings.notRoom:format(data.item.name))
			end
		else
			if xItem.count + count <= xItem.limit or xItem.limit == -1 then
				local inventory = {}
				MySQL.Async.fetchAll('SELECT * FROM inventories WHERE owner = @owner AND type = @type', {['@owner'] = owner, ['@type'] = invType}, function(result)
					if result[1] then
						inventory = json.decode(result[1].data)
						if IsInInv(inventory, data.item.name) then
							if inventory.items[data.item.name][1].count >= count then
								xPlayer.addInventoryItem(data.item.name, count)
								inventory.items[data.item.name][1].count = inventory.items[data.item.name][1].count - count
								if inventory.items[data.item.name][1].count <= 0 then
									inventory.items[data.item.name] = nil
								end
								MySQL.Async.execute('UPDATE inventories SET data = @data WHERE owner = @owner AND type = @type', {
									['@owner'] = owner,
									['@type'] = invType,
									['@data'] = json.encode(inventory)
								}, function(rowsChanged)
									if rowsChanged then
										-- print('Inventory updated for: '..owner..' with type: '..invType)
									end
								end)
							else
								Notify(src, Config.Strings.inNtNuf)
							end
						else
							Notify(src, Config.Strings.inNtNuf)
						end
					end
				end)
			else
				Notify(src, Config.Strings.notRoom:format(data.item.name))
			end
		end
	elseif data.item.type == 'item_weapon' then
		if not xPlayer.hasWeapon(data.item.name) then
			local inventory = {}
			MySQL.Async.fetchAll('SELECT * FROM inventories WHERE owner = @owner AND type = @type', {['@owner'] = owner, ['@type'] = invType}, function(result)
				if result[1] then
					inventory = json.decode(result[1].data)
					if IsInInv(inventory, data.item.name) then
						for i = 1,#inventory.weapons[data.item.name] do
							if inventory.weapons[data.item.name][i].count == data.item.count then
								xPlayer.addWeapon(data.item.name, inventory.weapons[data.item.name][i].count)
								table.remove(inventory.weapons[data.item.name], i)
								MySQL.Async.execute('UPDATE inventories SET data = @data WHERE owner = @owner AND type = @type', {
									['@owner'] = owner,
									['@type'] = invType,
									['@data'] = json.encode(inventory)
								}, function(rowsChanged)
									if rowsChanged then
										-- print('Inventory updated for: '..owner..' with type: '..invType)
									end
								end)
								break
							end
						end
					else
						Notify(src, Config.Strings.inNtNuf)
					end
				end
			end)
		else
			Notify(src, Config.Strings.hasWeap)
		end
	elseif data.item.type == 'item_account' then
		local accountName
		if data.item.name == 'money' then
			accountName = 'cash'
		elseif data.item.name == 'black_money' then
			accountName = 'blackMoney'
		end
		local inventory = {}
		MySQL.Async.fetchAll('SELECT * FROM inventories WHERE owner = @owner AND type = @type', {['@owner'] = owner, ['@type'] = invType}, function(result)
			if result[1] then
				inventory = json.decode(result[1].data)
				if inventory[accountName] >= count then
					if data.item.name == 'money' then
						xPlayer.addMoney(count)
					else
						xPlayer.addAccountMoney(data.item.name, count)
					end
					inventory[accountName] = inventory[accountName] - count
					MySQL.Async.execute('UPDATE inventories SET data = @data WHERE owner = @owner AND type = @type', {
						['@owner'] = owner,
						['@type'] = invType,
						['@data'] = json.encode(inventory)
					}, function(rowsChanged)
						if rowsChanged then
							-- print('Inventory updated for: '..owner..' with type: '..invType)
						end
					end)
				else
					Notify(src, Config.Strings.inNtNuf)
				end
			end
		end)
	end
end)