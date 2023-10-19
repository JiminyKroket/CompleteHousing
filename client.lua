ESX	= nil
local timer, drawRange, timeInd, keyRequests, keyChanges, activeKey = 0, 0, -1, 0, 0, 51
local HasAlreadyEnteredMarker, isDead, isInMarker, canUpdate, atShop, inShop, inAuction, shouldDelete, inHome, isUnfurnishing, isRemoving, blinking = false, false, false, false, false, false, false, false, false, false, false, false
local LastZone, CurrentAction, currentZone, spawnedFurn, homeID, dor2Update, returnPos
local CurrentActionMsg, currentHouseID = '', ''
local CurrentActionData, PlayerData, Houses, ParkedCars, SpawnedHome, FrontDoor, spawnedHouseSpots, scriptBlips, validObjects, spawnedProps, persFurn, ticks, totalKeys = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local Blips, Markers = Config.Blips, Config.Markers
local camInfo = {['Brand'] = {}, ['Generic'] = {}}

for i = 1,#Config.Furnishing.Props.Security.items do
  if Config.Furnishing.Props.Security.items[i].label:find('Branded') then
    camInfo['Brand'][Config.Furnishing.Props.Security.items[i].prop] = true
  else
    camInfo['Generic'][Config.Furnishing.Props.Security.items[i].prop] = true
  end
end

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent(Config.Strings.trigEv, function(obj) ESX = obj end)
	end
	while not ESX.IsPlayerLoaded() do
		Citizen.Wait(10)
	end
  TriggerServerEvent('CompleteHousing:playerLogin')
	PlayerData = ESX.GetPlayerData()
	while not HasCollisionLoadedAroundEntity(PlayerPedId()) do Wait(500) end
  TriggerServerEvent('CompleteHousing:updateHomes')
	if Config.MonthlyContracts.Use then
		TriggerServerEvent('CompleteHousing:checkOwnedDates')
	end
	if Blips.Furniture.Use then
		local blip = AddBlipForCoord(Config.Furnishing.Store.enter)

		SetBlipSprite (blip, Blips.Furniture.Sprite)
		SetBlipScale  (blip, Blips.Furniture.Scale)
		SetBlipAsShortRange(blip, true)
		SetBlipColour (blip, Blips.Furniture.Color)
		SetBlipDisplay(blip, Blips.Furniture.Display)

		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString(Blips.Furniture.Text)
		EndTextCommandSetBlipName(blip)
	end
  local readyHomes = {}
	while #readyHomes < 1 do
    print('getting homes ready')
    Citizen.Wait(100)
    for k,v in pairs(Houses) do
      table.insert(readyHomes, k)
    end
  end
  ESX.TriggerServerCallback('CompleteHousing:getHouseIn', function(address)
    if Houses[address] then
      if Config.ReconnectInside then
        if PlayerData.identifier == Houses[address].owner or HasKeys(Houses[address]) or CanRaid() then
          TriggerEvent('CompleteHousing:spawnHome', Houses[address], 'owned')
        else
          local pos = GetEntityCoords(PlayerPedId())
          TriggerEvent('CompleteHousing:spawnHome', Houses[address], 'owned', {x = pos.x, y = pos.y, z = pos.z}, 'false')
        end
      else
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local house = Houses[address]
        ClearAreaOfEverything(pos, Config.Shells[house.shell].shellsize, false, false, false, false)
        TriggerServerEvent('CompleteHousing:playerEnteredExitedHome', address, false)
        SetEntityCoords(ped, house.door)
      end
    end
  end)
	TriggerServerEvent('CompleteHousing:refreshVehicles')
	local sleep
	while true do
		sleep = 500
		local ped = PlayerPedId()
		local pos = GetEntityCoords(ped)
		local storedDis = 100
		isInMarker, canUpdate = false, false
		while inAuction do
			Citizen.Wait(0)
			DisableControlAction(0, 51)
			if IsDisabledControlJustPressed(0, 51) then
				timer = timer + Config.Auction.MaxTime
			end
		end
		for k,v in pairs(Houses) do
			local dis = #(pos - v.door)
			if dis <= v.draw then
				sleep = 0
				if dis <= 1.25 then
					isInMarker  = true
					currentZone = v
					if IsControlJustReleased(0, 51) then
						HouseMenu()
					end
				end
				if PlayerData.identifier == v.owner then
					if Markers.OwnedMarkers then
						DrawMarker(1, v.door, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 100, false, false, 2, false, false, false, false)
					end
				elseif v.owner == 'nil' then
					if Markers.UnOwnedMarks then
						DrawMarker(1, v.door, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 255, 255, 100, false, false, 2, false, false, false, false)
					end
				else
					if Markers.OtherMarkers then
						DrawMarker(1, v.door, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 0, 0, 100, false, false, 2, false, false, false, false)
					end
				end
				if Config.DisableMLOMarkersUntilUnlocked then
					if IsHouseUnlocked(v) then
						if Markers.IntMarkers then
							DrawMarker(1, v.storage, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 255, false, true, 2, 0, 0, 0, 0)
						end
						if type(v.storage) == 'vector3' then
							dis = #(pos - v.storage)
							if dis <= 1.25 then
								if IsControlJustReleased(0, 51) then
									local dict = 'amb@prop_human_bum_bin@base'
									RequestAnimDict(dict)
									while not HasAnimDictLoaded(dict) do Citizen.Wait(1) end
									TaskPlayAnim(ped, dict, 'base', 8.0, -8.0, 10000, 1, 0.0, false, false, false)
									TriggerEvent(Config.InventoryHudEvent, v.id, v.shell)
								end
							end
						end
					end
					if Markers.IntMarkers then
						DrawMarker(1, v.wardrobe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 255, false, true, 2, 0, 0, 0, 0)
					end
					if type(v.wardrobe) == 'vector3' then
						dis = #(pos - v.wardrobe)
						if dis <= 1.25 then
							if IsControlJustReleased(0, 51) then
								Config.WardrobeEvent()
							end
						end
					end
				else
					if Markers.IntMarkers then
						DrawMarker(1, v.storage, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 255, false, true, 2, 0, 0, 0, 0)
						DrawMarker(1, v.wardrobe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 255, false, true, 2, 0, 0, 0, 0)
					end
					dis = #(pos - v.storage)
					if dis <= 1.25 then
						if IsControlJustReleased(0, 51) then
							local dict = 'amb@prop_human_bum_bin@base'
							RequestAnimDict(dict)
							while not HasAnimDictLoaded(dict) do Citizen.Wait(1) end
							TaskPlayAnim(ped, dict, 'base', 8.0, -8.0, 10000, 1, 0.0, false, false, false)
							TriggerEvent(Config.InventoryHudEvent, v.id, v.shell)
						end
					end
					dis = #(pos - v.wardrobe)
					if dis <= 1.25 then
						if IsControlJustReleased(0, 51) then
							Config.WardrobeEvent()
						end
					end
				end
				for i = 1,#v.doors do
					if v.doors[i] ~= nil then
						if type(v.doors[i].pos) ~= 'vector3' then
							v.doors[i].pos = vector3(doRound(v.doors[i].pos.x, 2), doRound(v.doors[i].pos.y, 2), doRound(v.doors[i].pos.z, 2))
						end
						if not v.doors[i].object then
							v.doors[i].object = GetClosestObjectOfType(v.doors[i].pos, 2.0, v.doors[i].prop, false, false, false)
						end
						if not DoesEntityExist(v.doors[i].object) then
							v.doors[i].object = GetClosestObjectOfType(v.doors[i].pos, 2.0, v.doors[i].prop, false, false, false)
						end
						if v.owner == 'nil' then
							v.doors[i].locked = false
						end
						local dis = #(pos - v.doors[i].pos)
						if dis <= 2.5 then
							FreezeEntityPosition(v.doors[i].object, v.doors[i].locked)
							DrawDoorText(v.doors[i].pos, v.doors[i].locked)
							if v.owner == PlayerData.identifier or HasKeys(v) then
								storedDis = dis
								canUpdate = true
								dor2Update = v.doors[i]
								currentZone = v
								if Markers.OwnedMarkers then
									DrawMarker(1, v.door, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 100, false, false, 2, false, false, false, false)
								end
							else
								if v.owner == 'nil' then
									if Markers.UnOwnedMarks then
										DrawMarker(1, v.door, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 255, 255, 100, false, false, 2, false, false, false, false)
									end
								else
									if Markers.OtherMarkers then
										DrawMarker(1, v.door, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 0, 0, 100, false, false, 2, false, false, false, false)
									end
								end
							end
						end
						if v.doors[i].locked == true then
							SetEntityHeading(v.doors[i].object, v.doors[i].head)
						end
					end
				end
				for i = 1,#v.garages do
					if v.garages[i] ~= nil then
						if type(v.garages[i].pos) ~= 'vector3' then
							v.garages[i].pos = vector3(doRound(v.garages[i].pos.x, 2), doRound(v.garages[i].pos.y, 2), doRound(v.garages[i].pos.z, 2))
						end
						if not v.garages[i].object then
							v.garages[i].object = GetClosestObjectOfType(v.garages[i].pos, 2.0, v.garages[i].prop, false, false, false)
						end
						if not DoesEntityExist(v.garages[i].object) then
							v.garages[i].object = GetClosestObjectOfType(v.garages[i].pos, 2.0, v.garages[i].prop, false, false, false)
						end
						if v.owner == 'nil' then
							v.garages[i].locked = false
						end
						local dis = #(pos - v.garages[i].pos)
						if dis <= v.garages[i].draw * 2.0 then
							FreezeEntityPosition(v.garages[i].object, v.garages[i].locked)
							if dis <= v.garages[i].draw then
								DrawDoorText(v.garages[i].pos, v.garages[i].locked)
								if dis < storedDis then
									if v.owner == PlayerData.identifier or HasKeys(v) then
										canUpdate = true
										dor2Update = v.garages[i]
										currentZone = v
									end
								end
							end
						end
					end
				end
				if Config.Parking.ScriptParking ~= false then
					if v.owner ~= 'nil' or Config.Parking.AllowNil then
						if Config.Parking.AllowAll or v.owner == PlayerData.identifier or HasKeys(v) then
							if v.garageType == 'persistent' then
								if IsPedInAnyVehicle(ped, true) then
									for i = 1,#v.parkings do
										vec = vector3(v.parkings[i].x, v.parkings[i].y, v.parkings[i].z)
										dis = #(pos - vec)
										if PlayerData.identifier == v.owner then
											if Markers.OwnedMarkers then
												DrawMarker(1, vec, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 255, 100, false, false, 2, false, false, false, false)
											end
										else
											if Markers.OtherMarkers then
												DrawMarker(1, vec, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 255, 0, 100, false, false, 2, false, false, false, false)
											end
										end
										if dis <= 1.5 then
											DrawPrompt(vec, Config.Strings.parkCar)
											if IsControlJustReleased(0, 51) then
												local veh = GetVehiclePedIsIn(ped, false)
												if not IsParkingTaken(vec, GetVehicleNumberPlateText(veh)) then
													if DoesEntityExist(veh) then
														if GetPedInVehicleSeat(veh, -1) == ped then
                              FreezeEntityPosition(veh, true)
                              FreezeEntityPosition(ped, true)
                              SetEntityVisible(ped, false)
															local vehProps  = ESX.Game.GetVehicleProperties(veh)
															local livery = GetVehicleLivery(veh)
															local damages	= {
																eng = GetVehicleEngineHealth(veh),
																bod = GetVehicleBodyHealth(veh),
																tnk = GetVehiclePetrolTankHealth(veh),
																drt = GetVehicleDirtLevel(veh),
																oil = GetVehicleOilLevel(veh),
																lok = GetVehicleDoorLockStatus(veh),
																drvlyt = GetIsLeftVehicleHeadlightDamaged(veh),
																paslyt = GetIsRightVehicleHeadlightDamaged(veh),
																dor = {},
																win = {},
																tyr = {}
															}
															local vehPos    = GetEntityCoords(veh)
															local vehHead   = GetEntityHeading(veh)
															for i = 0,5 do
																damages.dor[i] = not DoesVehicleHaveDoor(veh, i)
															end
															for i = 0,3 do
																damages.win[i] = not IsVehicleWindowIntact(veh, i)
															end
															damages.win[6] = not IsVehicleWindowIntact(veh, 6)
															damages.win[7] = not IsVehicleWindowIntact(veh, 7)
															for i = 0,7 do
																damages.tyr[i] = false
																if IsVehicleTyreBurst(veh, i, false) then
																	damages.tyr[i] = 'popped'
																elseif IsVehicleTyreBurst(veh, i, true) then
																	damages.tyr[i] = 'gone'
																end
															end
															LastPlate = vehProps.plate
															if Config.BlinkOnRefresh then
																if not blinking then
																	blinking = true
																	if timeInd ~= 270 then
																		timeInd = GetTimecycleModifierIndex()
																		SetTimecycleModifier('Glasses_BlackOut')
																	end
																end
															end
															TriggerServerEvent('CompleteHousing:parkUnpark', {
																location = {x = vehPos.x, y = vehPos.y, z = vehPos.z, h = vehHead},
																props    = vehProps,
																livery   = livery,
																damages   = damages
															})
														else
															Notify('You must be driving to do this')
														end
													else
														Notify(Config.Strings.mstBNCr)
													end
												else
													Notify('You are too close to another parked vehicle, move elsewhere')
												end
											end
										end
									end
								end
							elseif v.garageType == 'garage' then
								for i = 1,#v.parkings do
									vec = vector3(v.parkings[i].x, v.parkings[i].y, v.parkings[i].z)
									dis = #(pos - vec)
									if PlayerData.identifier == v.owner then
										if Markers.OwnedMarkers then
											DrawMarker(1, vec, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 255, 100, false, false, 2, false, false, false, false)
										end
									else
										if Markers.OtherMarkers then
											DrawMarker(1, vec, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 255, 0, 100, false, false, 2, false, false, false, false)
										end
									end
									if dis <= 1.25 then
										DrawPrompt(vec, Config.Strings.parkCar)
										if IsControlJustReleased(0, 51) then
											local veh = GetVehiclePedIsIn(ped, false)
											if DoesEntityExist(veh) then
												if GetPedInVehicleSeat(veh, -1) == ped then
													Config.Parking.GarageStoreEvent(ped, veh)
												end
											else
												Config.Parking.GarageOpenEvent(v)
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
		local dis = #(pos - Config.Furnishing.Store.enter)
		if dis <= Config.Furnishing.Store.range then
			if not Config.Furnishing.Store.isMLO then
				sleep = 0
				if Markers.FurnMarkers then
					DrawMarker(1, Config.Furnishing.Store.enter, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 255, 255, 100, false, false, 2, false, false, false, false)
				end
				if dis < 1.25 then
					DrawPrompt(Config.Furnishing.Store.enter, Config.Strings.ntrFurn)
					if IsControlJustReleased(0, 51) then
						OpenFurnStore()
					end
				end
			else
				if not atShop then
					atShop = true
					for k,v in pairs(Config.Furnishing.Props) do
						validObjects[k] = {}
						validObjects[k].pos = v.pos
						validObjects[k].hed = v.hed
						validObjects[k].items = {}
						for i = 1,#v.items do
							if IsModelInCdimage(GetHashKey(v.items[i].prop)) then
								table.insert(validObjects[k].items, v.items[i])
							end
						end
					end
					local ped = PlayerPedId()
					for k,v in pairs(validObjects) do
						local prop = CreateObjectNoOffset(v.items[1].prop, v.pos, false, false, false)
						SetEntityAsMissionEntity(prop, true, true)
						SetEntityHeading(prop, v.hed)
            SetModelAsNoLongerNeeded(v.items[1].prop)
						PlaceObjectOnGroundProperly(prop)
						FreezeEntityPosition(prop, true)
						spawnedProps[k] = prop
					end
					Citizen.CreateThread(function()
						while atShop do
							local pos = GetEntityCoords(ped)
							local dis
							for k,v in pairs(Config.Furnishing.Props) do
								DrawShopText(v.pos.x, v.pos.y, v.pos.z+1.5, k)
								dis = #(pos - v.pos)
								if dis <= 2.5 then
									DrawShopText(v.pos.x, v.pos.y, v.pos.z+1.0, Config.Strings.mnuScll)
									if IsControlJustReleased(0, 51) then
										OpenFurnMenu(k,v)
										Citizen.CreateThread(function()
											while spawnedProps[k] ~= nil do
												Citizen.Wait(10)
												local pos = GetEntityCoords(PlayerPedId())
												local distance = #(pos - v.pos)
												if distance > 2.5 then
													break
												end
												DisableControlAction(0, 174)
												DisableControlAction(0, 175)
												if IsDisabledControlPressed(0, 174) then
													SetEntityHeading(spawnedProps[k], GetEntityHeading(spawnedProps[k]) - 0.5)
												end
												if IsDisabledControlPressed(0, 175) then
													SetEntityHeading(spawnedProps[k], GetEntityHeading(spawnedProps[k]) + 0.5)
												end
											end
										end)
									end
								end
							end
							Citizen.Wait(5)
						end
					end)
				end
			end
		elseif atShop then
			if Config.Furnishing.Store.isMLO then
				atShop = false
				for k,v in pairs(spawnedProps) do
					DeleteEntity(v)
				end
			end
		end
		if not Config.Furnishing.Store.isMLO then
			dis = #(pos - Config.Furnishing.Store.exitt)
			if Markers.FurnMarkers then
				if dis <= Config.Furnishing.Store.range then
					sleep = 0
					DrawMarker(1, Config.Furnishing.Store.exitt.x, Config.Furnishing.Store.exitt.y, Config.Furnishing.Store.exitt.z-1.5, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 255, 255, 100, false, false, 2, false, false, false, false)
				end
			end
			if dis <= 1.25 then
				DrawPrompt(Config.Furnishing.Store.exitt, Config.Strings.xitFurn)
				if IsControlJustReleased(0, 51) then
					for k,v in pairs(spawnedProps) do
						DeleteEntity(v)
					end
					SetEntityCoords(ped, Config.Furnishing.Store.enter)
					SetEntityHeading(ped, Config.Furnishing.Store.exthead)
					atShop = false
					inShop = false
				end
			end
		end
		if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
			HasAlreadyEnteredMarker = true
			LastZone = currentZone
			TriggerEvent('CompleteHousing:hasEnteredMarker', currentZone)
			Notify(CurrentActionMsg)
		end
		if not isInMarker and HasAlreadyEnteredMarker then
			HasAlreadyEnteredMarker = false
			TriggerEvent('CompleteHousing:hasExitedMarker', LastZone)
		end
		Citizen.Wait(sleep)
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(500)
		local pos = GetEntityCoords(PlayerPedId())
		if not isUnfurnishing then
			for k,v in pairs(persFurn) do
        Citizen.Wait(1)
				local dis = #(pos - v.pos)
				if dis < 100.0 then
					if not persFurn[k].entity then
            Citizen.CreateThread(function()
              local model = GetHashKey(v.model)
              ticks[model] = 0
              while not HasModelLoaded(model) do
                Citizen.Wait(10)
                RequestModel(model)
                ticks[model] = ticks[model] + 1
                if ticks[model] >= Config.ModelWaitTicks then
                  ticks[model] = 0
                  ESX.ShowHelpNotification('Model '..v.model..' failed to load, make sure all streamed files are running(I ran into issues with mythic_interiors), please attempt re-logging to solve')
                  return
                end
              end
              persFurn[k].entity = CreateObjectNoOffset(model, v.pos.x, v.pos.y, v.pos.z, false, false, false)
              while not DoesEntityExist(persFurn[k].entity) do Citizen.Wait(10) end
              SetEntityAsMissionEntity(persFurn[k].entity, true, true)
              SetEntityRotation(persFurn[k].entity, v.rotation[1], v.rotation[2], v.rotation[3], 2)
              SetModelAsNoLongerNeeded(model)
              SetEntityInvincible(persFurn[k].entity, true)
              FreezeEntityPosition(persFurn[k].entity, true)
            end)
					end
				elseif persFurn[k].entity ~= nil then
					DeleteEntity(persFurn[k].entity)
					persFurn[k].entity = nil
				end
			end
		end
    if not isRemoving then
      for k,v in pairs(ParkedCars) do
        Citizen.Wait(1)
        local dis = #(pos - v.pos)
        if dis < 100.0 then
          if not ParkedCars[k].entity or not DoesEntityExist(ParkedCars[k].entity) then
            local model = v.props.model
            if not HasModelLoaded(model) then
              ticks[model] = 0
              while not HasModelLoaded(model) do
                Citizen.Wait(10)
                RequestModel(model)
                ticks[model] = ticks[model] + 1
                if ticks[model] >= Config.ModelWaitTicks then
                  ticks[model] = 0
                  ESX.ShowHelpNotification('Model '..v.props.model..' failed to load, make sure all streamed files are running(I ran into issues with mythic_interiors), please attempt re-logging to solve')
                  return
                end
              end
            end
            if HasModelLoaded(model) then
              ParkedCars[k].entity = CreateVehicle(v.props.model, v.pos.x, v.pos.y, v.pos.z, v.location.h, false, false)
              while not DoesEntityExist(ParkedCars[k].entity) do Citizen.Wait(10); print('waiting for game to create')end
              ESX.Game.SetVehicleProperties(ParkedCars[k].entity, v.props)
              SetVehicleOnGroundProperly(ParkedCars[k].entity)
              SetEntityAsMissionEntity(ParkedCars[k].entity, true, true)
              SetModelAsNoLongerNeeded(v.props.model)
              SetEntityInvincible(ParkedCars[k].entity, true)
              SetVehicleLivery(ParkedCars[k].entity, v.livery)
              SetVehicleEngineHealth(ParkedCars[k].entity, v.damages.eng)
              SetVehicleOilLevel(ParkedCars[k].entity, v.damages.oil)
              SetVehicleBodyHealth(ParkedCars[k].entity, v.damages.bod)
              SetVehicleDoorsLocked(ParkedCars[k].entity, v.damages.lok)
              SetVehiclePetrolTankHealth(ParkedCars[k].entity, v.damages.tnk)
              for g,f in pairs(v.damages.dor) do
                if v.damages.dor[g] then
                  SetVehicleDoorBroken(ParkedCars[k].entity, tonumber(g), true)
                end
              end
              for g,f in pairs(v.damages.win) do
                if v.damages.win[g] then
                  SmashVehicleWindow(ParkedCars[k].entity, tonumber(g))
                end
              end
              for g,f in pairs(v.damages.tyr) do
                if v.damages.tyr[g] == 'popped' then
                  SetVehicleTyreBurst(ParkedCars[k].entity, tonumber(g), false, 850.0)
                elseif v.damages.tyr[g] == 'gone' then
                  SetVehicleTyreBurst(ParkedCars[k].entity, tonumber(g), true, 1000.0)
                end
              end
              while not HasCollisionLoadedAroundEntity(ParkedCars[k].entity) do
                Citizen.Wait(10)
              end
              SetVehicleOnGroundProperly(ParkedCars[k].entity)
              FreezeEntityPosition(ParkedCars[k].entity, true)
            end
            Citizen.Wait(100)
          end
        else
          if ParkedCars[k]~= nil then
            DeleteEntity(ParkedCars[k].entity)
            ParkedCars[k].entity = nil
          end
        end
      end
    end
	end
end)

doTrim = function(value)
	return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end

doRound = function(value, numDecimalPlaces)
	if numDecimalPlaces then
		local power = 10^numDecimalPlaces
		return math.floor((value * power) + 0.5) / (power)
	else
		return math.floor(value + 0.5)
	end
end

IsParkingTaken = function(pos, plate)
	plate = doTrim(plate)
	local taken = false
	for k,v in pairs(ParkedCars) do
		local dis = #(pos - v.pos)
		if dis < 2.0 then
			if not doTrim(GetVehicleNumberPlateText(v.entity)) == plate then
				taken = true
			end
		end
	end
	return taken
end

IsAddressHidden = function(address)
	local blacklisted = false
	for i = 1,#Config.HiddenProperty do
		if address == Config.HiddenProperty[i] then
			blacklisted = true
		end
	end
	return blacklisted
end

IsParkingTooClose = function(pos)
	local tooClose = false
	for k,v in pairs(Houses) do
		for i = 1,#v.parkings do
			local vec = vector3(v.parkings[i].x, v.parkings[i].y, v.parkings[i].z)
			local dis = #(vec - pos)
			if dis <= 2.5 then
				tooClose = true
			end
		end
	end
	return tooClose
end

GetSafeSpot = function()
	for i = 1,#Config.Defaults.SpawnSpots do
		if not IsHomeTouchingHome(Config.Defaults.SpawnSpots[i].x, Config.Defaults.SpawnSpots[i].y, Config.Defaults.SpawnSpots[i].z) then
			return Config.Defaults.SpawnSpots[i]
		end
	end
	return vector3(0.0, 0.0, 0.0)
end

CreateRandomAddress = function()
	math.randomseed(GetGameTimer())
	local streetName, streetNum = '', math.random(1000, 99999)
	for i = 1, 5 do
		streetName = streetName..string.char(math.random(97,122))
	end
	streetName = streetName..' '
	for i = 1, 10 do
		streetName = streetName..string.char(math.random(97,122))
	end
	return streetNum..' '..streetName..' Drive'
end

IsHouseUnlocked = function(home)
	unLocked = false
	if PlayerData.identifier == home.owner then
		unLocked = true
	end
	for i = 1,#home.doors do
		if home.doors[i] ~= nil then
			if home.doors[i].locked == false then
				unLocked = true
			end
		end
	end
	for i = 1,#home.garages do
		if home.garages[i] ~= nil then
			if home.garages[i].locked == false then
				unLocked = true
			end
		end
	end
	return unLocked
end

Notify = function(text, timer)
	if timer == nil then
		timer = 5000
	end
	-- exports['mythic_notify']:DoCustomHudText('inform', text, timer)
	-- exports.pNotify:SendNotification({layout = 'centerLeft', text = text, type = 'error', timeout = timer})
	ESX.ShowNotification(text)
end

HelpText1 = function(msg, beep)
	SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(0.5, 0.5)
    SetTextColour(255, 255, 255, 200)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextEdge(2, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(msg)
    DrawText(Config.HelpText.X, Config.HelpText.Y)
end

HelpText2 = function(msg, beep)
	SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(0.5, 0.5)
    SetTextColour(255, 255, 255, 200)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextEdge(2, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(msg)
    DrawText(Config.HelpText.X, Config.HelpText.Y + 0.09)
end

CanRaid = function()
	local hasJob = false
	for k,v in pairs(Config.Raids.Jobs) do
		if PlayerData.job.name == k then
			if PlayerData.job.grade >= v then
				hasJob = true
			end
		end
	end
	return hasJob
end

HasKeys = function(house)
	local hasKey = false
	if house.keys and type(house.keys) == 'table' then
		for i = 1,#house.keys do
			if PlayerData.identifier == house.keys[i] then
				hasKey = true
			end
		end
	else
		print('Someone fucked up this houses keys table good job')
	end
	return hasKey
end

IsUnlocked = function(house)
	if house.locked then
		return house.locked == 'false'
	else
		print('Someone fucked up this house table it lost its lock good job')
	end
end

IsHouseSpawned = function(house)
	local isSpawned, owner, spot = false
	for k,v in pairs(spawnedHouseSpots) do
		if k == house.id then
			isSpawned = true
			owner = v.owner
			spot = v.spot
		end
	end
	return isSpawned, owner, spot
end

DrawDoorText = function(pos, text)
	if text == true then
		text = Config.Strings.l0ckTxt
	else
		text = Config.Strings.unlkTxt
	end
	local onScreen,_x,_y=World3dToScreen2d(pos.x, pos.y, pos.z)
	local px,py,pz=table.unpack(GetGameplayCamCoords())
	local scale = 0.5
	local text = text
	
	if onScreen then
		SetTextScale(scale, scale)
		SetTextFont(0)
		SetTextProportional(1)
		SetTextColour(255, 255, 255, 255)
		SetTextDropshadow(1, 1, 0, 0, 255)
		SetTextEdge(0, 0, 0, 0, 150)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		SetTextCentre(2)
		AddTextComponentString(text)
		DrawText(_x,_y)
	end
end

DrawPrompt = function(pos, text)
	local onScreen,_x,_y=World3dToScreen2d(pos.x, pos.y, pos.z+1.0)
	local px,py,pz=table.unpack(GetGameplayCamCoords())
	local scale = 0.5
	local text = text
	
	if onScreen then
		SetTextScale(scale, scale)
		SetTextFont(0)
		SetTextProportional(1)
		SetTextColour(255, 255, 255, 255)
		SetTextDropshadow(1, 1, 0, 0, 255)
		SetTextEdge(0, 0, 0, 0, 150)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		SetTextCentre(2)
		AddTextComponentString(text)
		DrawText(_x,_y)
	end
end

HouseMenu = function()
	local ped = PlayerPedId()
	local elements = {}
	local house = CurrentActionData
	local isMLO = house.shell == 'mlo'
	if house.owner == 'nil' then
		if house.isSpec < 2 then
			table.insert(elements, {label = Config.Strings.buyText:format(house.price), value = 'buy'})
		end
		if house.isSpec > 0 then
			table.insert(elements, {label = Config.Strings.buySpec:format(house.price*(Config.SpecialProperties.Percentage/100),Config.SpecialProperties.AccountLabel), value = 'buySpec'})
		end
		if not isMLO then
			table.insert(elements, {label = Config.Strings.viewTxt, value = 'view'})
		end
	elseif PlayerData.identifier == house.owner then
		if not isMLO then
			table.insert(elements, {label = Config.Strings.entrTxt, value = 'enter'})
		end
		table.insert(elements, {label = Config.Strings.furnTxt, value = 'furnish'})
		table.insert(elements, {label = Config.Strings.unfnTxt, value = 'unfurnish'})
		table.insert(elements, {label = Config.Strings.sellTxt, value = 'sell'})
		table.insert(elements, {label = Config.Strings.gvKyTxt, value = 'givekey'})
		table.insert(elements, {label = Config.Strings.tkKyTxt, value = 'takekey'})
    if Config.Mailboxes.Use then
      table.insert(elements, {label = Config.Strings.chkMail, value = 'mailbox'})
    end
	elseif HasKeys(house) then
		if not isMLO then
			table.insert(elements, {label = Config.Strings.entrTxt, value = 'usekey'})
		end
		table.insert(elements, {label = Config.Strings.nokText, value = 'knock'})
    if Config.Mailboxes.Use then
      table.insert(elements, {label = Config.Strings.chkMail, value = 'mailbox'})
    end
	elseif IsUnlocked(house) then
		if not isMLO then
			table.insert(elements, {label = Config.Strings.entrTxt, value = 'usekey'})
		end
		table.insert(elements, {label = Config.Strings.nokText, value = 'knock'})
    if Config.Mailboxes.Use then
      table.insert(elements, {label = Config.Strings.chkMail, value = 'mailbox'})
    end
	elseif CanRaid() then
		table.insert(elements, {label = Config.Strings.nokText, value = 'knock'})
		if not isMLO then
			table.insert(elements, {label = Config.Strings.raidTxt, value = 'raid'})
		end
    if Config.Mailboxes.Use then
      table.insert(elements, {label = Config.Strings.chkMail, value = 'mailbox'})
    end
	else
		if not isMLO and Config.BandE.Allow then
			table.insert(elements, {label = Config.Strings.bneText, value = 'breakin'})
		end
		table.insert(elements, {label = Config.Strings.nokText, value = 'knock'})
    if Config.Mailboxes.Use then
      table.insert(elements, {label = Config.Strings.chkMail, value = 'mailbox'})
    end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'front_door',
	{
		title    = house.id,
		align    = Config.MenuAlign,
		elements = elements
	}, function(data, menu)
		local action = data.current.value
		if action == 'buy' then
			if  PlayerData.identifier == house.prevowner then
				ESX.UI.Menu.CloseAll()
        Notify('You can purchase your old home')
				-- TriggerServerEvent('CompleteHousing:purchaseHome', house)
			else
				local elements2 = {{label = Config.Strings.confTxt, value = 'yes'},{label = Config.Strings.decText, value = 'no'}}
				if Config.FurnishedHouses[house.shell] ~= nil then
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'buy_full',
					{
						title = Config.Strings.autoFrn,
						align = Config.MenuAlign,
						elements = elements2
					}, function(data2, menu2)
						if data2.current.value == 'yes' then
							ESX.UI.Menu.CloseAll()
							TriggerServerEvent('CompleteHousing:purchaseHome', house, true)
						else
							ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'buy_furnd',
							{
								title = Config.Strings.prevFrn,
								align = Config.MenuAlign,
								elements = elements2
							}, function(data3, menu3)
								if data3.current.value == 'yes' then
									ESX.UI.Menu.CloseAll()
									TriggerServerEvent('CompleteHousing:purchaseHome', house)
								else
									ESX.UI.Menu.CloseAll()
									TriggerServerEvent('CompleteHousing:purchaseHome', house, false)
								end
							end, function(data3, menu3)
								menu3.close()
							end)
						end
					end, function(data2, menu2)
						menu2.close()
					end)
				else
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'buy_furnd',
					{
						title = Config.Strings.prevFrn,
						align = Config.MenuAlign,
						elements = elements2
					}, function(data3, menu3)
						if data3.current.value == 'yes' then
							ESX.UI.Menu.CloseAll()
							TriggerServerEvent('CompleteHousing:purchaseHome', house)
						else
							ESX.UI.Menu.CloseAll()
							TriggerServerEvent('CompleteHousing:purchaseHome', house, false)
						end
					end, function(data3, menu3)
						menu3.close()
					end)
				end
			end
		elseif action == 'buySpec' then
			if  PlayerData.identifier == house.prevowner then
				ESX.UI.Menu.CloseAll()
				TriggerServerEvent('CompleteHousing:purchaseHome', house)
			else
				local elements2 = {{label = Config.Strings.confTxt, value = 'yes'},{label = Config.Strings.decText, value = 'no'}}
				if Config.FurnishedHouses[house.shell] ~= nil then
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'buy_full',
					{
						title = Config.Strings.autoFrn,
						align = Config.MenuAlign,
						elements = elements2
					}, function(data2, menu2)
						if data2.current.value == 'yes' then
							ESX.UI.Menu.CloseAll()
							TriggerServerEvent('CompleteHousing:purchaseHome', house, true, true)
						else
							ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'buy_furnd',
							{
								title = Config.Strings.prevFrn,
								align = Config.MenuAlign,
								elements = elements2
							}, function(data3, menu3)
								if data3.current.value == 'yes' then
									ESX.UI.Menu.CloseAll()
									TriggerServerEvent('CompleteHousing:purchaseHome', house, 'nil', true)
								else
									ESX.UI.Menu.CloseAll()
									TriggerServerEvent('CompleteHousing:purchaseHome', house, false, true)
								end
							end, function(data3, menu3)
								menu3.close()
							end)
						end
					end, function(data2, menu2)
						menu2.close()
					end)
				else
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'buy_furnd',
					{
						title = Config.Strings.prevFrn,
						align = Config.MenuAlign,
						elements = elements2
					}, function(data3, menu3)
						if data3.current.value == 'yes' then
							ESX.UI.Menu.CloseAll()
							TriggerServerEvent('CompleteHousing:purchaseHome', house, 'nil', true)
						else
							ESX.UI.Menu.CloseAll()
							TriggerServerEvent('CompleteHousing:purchaseHome', house, false, true)
						end
					end, function(data3, menu3)
						menu3.close()
					end)
				end
			end
		elseif action == 'view' then
			ESX.TriggerServerCallback('CompleteHousing:getSpots', function(spots)
				spawnedHouseSpots = spots
				ESX.UI.Menu.CloseAll()
				TriggerEvent('CompleteHousing:spawnHome', house, 'visit')
			end)
		elseif action == 'enter' then
			ESX.TriggerServerCallback('CompleteHousing:getSpots', function(spots)
				spawnedHouseSpots = spots
				local houseSpawned, houseOwner, spawnSpot = IsHouseSpawned(house)
				if not houseSpawned then
					ESX.UI.Menu.CloseAll()
					TriggerEvent('CompleteHousing:spawnHome', house, 'owned')
				else
					ESX.UI.Menu.CloseAll()
					TriggerServerEvent('CompleteHousing:doorKnock', house, 'false')
				end
			end)
		elseif action == 'furnish' then
			ESX.UI.Menu.CloseAll()
			FurnishOutHome(house)
		elseif action == 'unfurnish' then
			ESX.UI.Menu.CloseAll()
			UnFurnishOutHome(house)
		elseif action == 'sell' then
			ESX.UI.Menu.CloseAll()
			VerifySell(house)
		elseif action == 'knock' then
			ESX.TriggerServerCallback('CompleteHousing:getSpots', function(spots)
				spawnedHouseSpots = spots
				ESX.UI.Menu.CloseAll()
				TriggerServerEvent('CompleteHousing:doorKnock', house)
			end)
		elseif action == 'raid' then
			ESX.TriggerServerCallback('CompleteHousing:getSpots', function(spots)
				spawnedHouseSpots = spots
				ESX.UI.Menu.CloseAll()
				TriggerServerEvent('CompleteHousing:doorKnock', house, 'true')
			end)
		elseif action == 'breakin' then
			ESX.TriggerServerCallback('CompleteHousing:canBreakIn', function(hasItems)
				if hasItems then
					StartBreakIn(house)
				else
					Notify(Config.Strings.noBreak)
				end
			end, house.owner)
		elseif action == 'givekey' then
			local elements = {{label = Config.Strings.cancTxt, value = 'exit'}}
			local player, distance = ESX.Game.GetClosestPlayer()
			if distance <= 1.5 and distance > 0 then
				table.insert(elements, {label = GetPlayerName(player), value = 'givekey'})
			end
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'give_key',
			{
				title = Config.Strings.giveKey,
				align = Config.MenuAlign,
				elements = elements
			}, function(data2, menu2)
				if data2.current.value == 'givekey' then
					TriggerServerEvent('CompleteHousing:giveKey', GetPlayerServerId(player), house)
					menu2.close()
				else
					menu2.close()
				end
			end, function(data2, menu2)
				menu2.close()
			end)
		elseif action == 'takekey' then
			local elements = {{label = Config.Strings.cancTxt, value = 'exit'}}
			local player, distance = ESX.Game.GetClosestPlayer()
			if distance <= 1.5 and distance > 0 then
				table.insert(elements, {label = GetPlayerName(player), value = 'takekey'})
			end
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'fuck_me',
			{ title = 'Take Keys', align = Config.MenuAlign, elements = elements}, function(data, menu)
				if data.current.value == 'exit' then
					menu.close()
				else
					TriggerServerEvent('CompleteHousing:takeKey', house, GetPlayerServerId(player))
				end
			end, function(data, menu)
				menu.close()
			end)
		elseif action == 'usekey' then
			ESX.TriggerServerCallback('CompleteHousing:getSpots', function(spots)
				spawnedHouseSpots = spots
				local houseSpawned, houseOwner, spawnSpot = IsHouseSpawned(house)
				if not houseSpawned then
					ESX.UI.Menu.CloseAll()
					TriggerEvent('CompleteHousing:spawnHome', house, 'owned')
				else
					ESX.UI.Menu.CloseAll()
					TriggerServerEvent('CompleteHousing:doorKnock', house, 'false')
				end
			end)
    elseif action == 'mailbox' then
      TriggerEvent(Config.InventoryHudEvent, house.id..' Mail', 'mailbox')
		elseif action == 'exit' then
			ESX.UI.Menu.CloseAll()
		end
	end, function(data, menu)
		menu.close()
	end)
end

ExitMenu = function(house)
	local ped = PlayerPedId()
	local elements = {{label = Config.Strings.leavTxt, value = 'exit'}}
	local lockText = Config.Strings.l0ckTxt
	local door = house.door
	local vec = vector3(door.x, door.y, door.z)
	local keyOptions = Config.KeyOptions.CanDo
	if IsUnlocked(house) then
		lockText = Config.Strings.unlkTxt
	end
	if PlayerData.identifier == house.owner then
		table.insert(elements, {label = Config.Strings.letNTxt, value = 'letin'})
		if Config.KeyOptions.Item.Require and Config.KeyOptions.Item.Name ~= '' then
			ESX.TriggerServerCallback('CompleteHousing:getHasItem', function(hasIt)
				if hasIt then
					table.insert(elements, {label = lockText, value = 'lock'})
				end
			end, Config.KeyOptions.Item.Name)
		else
			table.insert(elements, {label = lockText, value = 'lock'})
		end
		table.insert(elements, {label = Config.Strings.furnTxt, value = 'furnish'})
		table.insert(elements, {label = Config.Strings.unfnTxt, value = 'unfurnish'})
		table.insert(elements, {label = Config.Strings.gvKyTxt, value = 'givekey'})
	elseif HasKeys(house) then
		if keyOptions.LetIn then
			table.insert(elements, {label = Config.Strings.letNTxt, value = 'letin'})
		end
		if keyOptions.SetLock then
			if Config.KeyOptions.Item.Require and Config.KeyOptions.Item.Name ~= '' then
				ESX.TriggerServerCallback('CompleteHousing:getHasItem', function(hasIt)
					if hasIt then
						table.insert(elements, {label = lockText, value = 'lock'})
					end
				end, Config.KeyOptions.Item.Name)
			else
				table.insert(elements, {label = lockText, value = 'lock'})
			end
		end
		if keyOptions.GiveKeys then
			table.insert(elements, {label = Config.Strings.gvKyTxt, value = 'givekey'})
		end
		if keyOptions.Furnish then
			table.insert(elements, {label = Config.Strings.furnTxt, value = 'furnish'})
		end
		if keyOptions.Unfurnish then
			table.insert(elements, {label = Config.Strings.unfnTxt, value = 'unfurnish'})
		end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'front_door',
	{
		title    = house.id,
		align    = Config.MenuAlign,
		elements = elements
	}, function(data, menu)
		local action = data.current.value
		if action == 'furnish' then
			ESX.UI.Menu.CloseAll()
			FurnishHome(house)
		elseif action == 'unfurnish' then
			ESX.UI.Menu.CloseAll()
			UnFurnishHome(house)
		elseif action == 'lock' then
			ESX.UI.Menu.CloseAll()
			if house.locked == 'false' then
				house.locked = 'true'
			else
				house.locked = 'false'
			end
			TriggerServerEvent('CompleteHousing:lockHouse', house)
		elseif action == 'letin' then
			local elements = {{label = Config.Strings.cancTxt, value = 'exit'}}
			local player, distance = ESX.Game.GetClosestPlayer(vec)
			if distance <= 1.5 and distance > 0 then
				table.insert(elements, {label = GetPlayerName(player), value = 'letin'})
			end
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'let_in',
			{
				title = 'Let In',
				align = Config.MenuAlign,
				elements = elements
			}, function(data2, menu2)
				if data2.current.value == 'letin' then
					TriggerServerEvent('CompleteHousing:knockAccept', GetPlayerServerId(player), GetEntityCoords(SpawnedHome[1]), house)
					menu2.close()
				else
					menu2.close()
				end
			end, function(data2, menu2)
				menu2.close()
			end)
		elseif action == 'givekey' then
			local elements = {{label = Config.Strings.cancTxt, value = 'exit'}}
			local player, distance = ESX.Game.GetClosestPlayer()
			if distance <= 1.5 and distance > 0 then
				table.insert(elements, {label = GetPlayerName(player), value = 'givekey'})
			end
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'give_key',
			{
				title = Config.Strings.giveKey,
				align = Config.MenuAlign,
				elements = elements
			}, function(data2, menu2)
				if data2.current.value == 'givekey' then
					TriggerServerEvent('CompleteHousing:giveKey', GetPlayerServerId(player), house)
					menu2.close()
				else
					menu2.close()
				end
			end, function(data2, menu2)
				menu2.close()
			end)
		elseif action == 'exit' then
			print('ignore the next error, it does not affect anything, if you find the issue then relay it otherwise leave me alone about it')
			ESX.UI.Menu.CloseAll()
			if Config.BlinkOnRefresh then
				if not blinking then
					blinking = true
					if timeInd ~= 270 then
						timeInd = GetTimecycleModifierIndex()
						SetTimecycleModifier('Glasses_BlackOut')
					end
				end
			end
			Notify(Config.Strings.amExitt)
			SetEntityCoords(ped, vec.x, vec.y, vec.z)
			FreezeEntityPosition(ped, true)
			while not HasCollisionLoadedAroundEntity(ped) do
				Citizen.Wait(1)
				SetEntityCoords(ped, vec.x, vec.y, vec.z)
				DisableAllControlActions(0)
			end
			Notify(Config.Strings.amClose)
			Citizen.Wait(1000)
			if Config.BlinkOnRefresh then
				if timeInd ~= -1 then
					SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
				else
					timeInd = -1
					ClearTimecycleModifier()
				end
				blinking = false
			end
			FreezeEntityPosition(ped, false)
			TriggerServerEvent('CompleteHousing:regSpot', 'remove', vec, house.id)
			TriggerServerEvent('CompleteHousing:playerEnteredExitedHome', house.id, false)
			for i = 1,#SpawnedHome do
				DeleteEntity(SpawnedHome[i])
			end
			spawnedFurn = nil
			inHome = false
      TriggerEvent('CompleteHousing:setPlayerInHome', inHome)
			FrontDoor = {}
			SpawnedHome = {}
		end
	end, function(data, menu)
		menu.close()
	end)
end

GetKey = function()
	keyRequests = keyRequests + 1
	if keyRequests == 100 then
		for k,v in pairs(Config.BandE.EventKeys) do
			table.insert(totalKeys, v)
		end
		math.randomseed(GetGameTimer())
    activeKey = totalKeys[math.random(#totalKeys)]
		keyRequests = 0
		keyChanges = keyChanges + 1
	end
end

StartBreakIn = function(house)
	local hTab = Config.BandE
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local hed = GetEntityHeading(ped)
	local offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.5)
	local amountHit = 0
	while not HasAnimDictLoaded(hTab.AnimDict) do
		RequestAnimDict(hTab.AnimDict)
		Citizen.Wait(10)
	end
	TaskPlayAnimAdvanced(ped, hTab.AnimDict, hTab.AnimName, pos.x, pos.y, pos.z, 0.0, 0.0, hed, hTab.BlendIn, hTab.BlendOut, -1, hTab.AnimFlag, hTab.AnimTime, 0, 0)
	local furni = house.furniture
	if furni ~= nil then
		for k,v in ipairs(furni.outside) do
      if camInfo['Brand'][v.prop] then
        TriggerServerEvent('CompleteHousing:alertOwner', house, true)
      elseif camInfo['Generic'][v.prop] then
        TriggerServerEvent('CompleteHousing:alertOwner', house, false)
      end
    end
  end
  while true do
		if not IsEntityPlayingAnim(ped, hTab.AnimDict, hTab.AnimName, 3) then
			TaskPlayAnimAdvanced(ped, hTab.AnimDict, hTab.AnimName, pos.x, pos.y, pos.z, 0.0, 0.0, hed, hTab.BlendIn, hTab.BlendOut, -1, hTab.AnimFlag, hTab.AnimTime, 0, 0)
		end
		Citizen.Wait(5)
		DisableAllControlActions(0)
		for i = 0,6 do
			EnableControlAction(0, i)
		end
		GetKey()
		for k,v in pairs(hTab.EventKeys) do
			if v == activeKey then
				DrawShopText(offset.x, offset.y, offset.z, 'Press '..k)
			end
		end
		if IsDisabledControlJustPressed(0, activeKey) then
			amountHit = amountHit + 1
			GetKey()
			if amountHit == hTab.WinAmount then
				ClearPedTasks(ped)
				Notify('You have broken into the home')
				if house.shell == 'mlo' then
					for i = 1,#house.doors do
						if house.doors[i] ~= nil then
							local dis = #(pos - house.doors[i].pos)
							if dis <= 2.5 then
								dor2Update = house.doors[i]
							end
						end
					end
					for i = 1,#house.garages do
						if house.garages[i] ~= nil then
							local dis = #(pos - house.garages[i].pos)
							if dis <= house.garages[i].draw then
								dor2Update = house.garages[i]
							end
						end
					end
					TriggerServerEvent('CompleteHousing:updateDoor', house, dor2Update)
					keyRequests = 0
					keyChanges = 0
					break
				else
					TriggerServerEvent('CompleteHousing:breakIn', house)
					keyRequests = 0
					keyChanges = 0
					break
				end
			end
		end
		if keyChanges == hTab.Revolutions then
			ClearPedTasks(PlayerPedId())
			Notify('You failed to break the lock')
			TriggerServerEvent('CompleteHousing:breakInFail')
			keyRequests = 0
			keyChanges = 0
			break
		end
	end
end

DrawShopText = function(x, y, z, text)
	local onScreen,_x,_y=World3dToScreen2d(x, y, z)
  local pos = vector3(x,y,z)
  local lngth = #(pos-GetGameplayCamCoords())
	local scale = 5/lngth
	local text = text
	
	if onScreen then
		SetTextScale(scale, scale)
		SetTextFont(0)
		SetTextProportional(1)
		SetTextColour(255, 255, 255, 255)
		SetTextDropshadow(1, 1, 0, 0, 255)
		SetTextEdge(0, 0, 0, 0, 150)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		SetTextCentre(2)
		AddTextComponentString(text)
		DrawText(_x,_y)
	end
end

OpenFurnMenu = function(k,v) -- ADD AMOUNT TO BUY
	local elements = {}
	for g,f in pairs(validObjects[k].items) do
		table.insert(elements, {label = f.label..':'..Config.CurrencyIcon..f.price, value = f, prop = f.prop})
	end
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'select_item',
	{
		title    = Config.Strings.frnMenu,
		align    = Config.MenuAlign,
		elements = elements
	}, function(data, menu)
		if GetEntityModel(spawnedProps[k]) == GetHashKey(data.current.prop) then
      ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'furn_buy_amount',
			{
				title    = Config.Strings.frnMenu,
				align    = Config.MenuAlign,
				elements = {{label = 'Choose Amount', type = 'slider', value = 1, min = 1, max = Config.Furnishing.Store.maxPurchaseAmount}}
			}, function(data2, menu2)
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'confirm_furn_buy',
        {
          title    = Config.Strings.frnMenu,
          align    = Config.MenuAlign,
          elements = {{label = Config.Strings.prchTxt:format(data2.current.value), value = 'yes'}, {label = Config.Strings.decText, value = 'no'}}
        }, function(data3, menu3)
          if data3.current.value == 'yes' then
            TriggerServerEvent('CompleteHousing:purchaseFurn', data.current.value, data2.current.value)
            menu3.close()
            menu2.close()
          else
            menu3.close()
          end
        end, function(data3, menu3)
          menu3.close()
        end)
			end, function(data2, menu2)
				menu2.close()
			end)
		end
	end, function(data, menu)
		menu.close()
	end, function(data, menu)
		Citizen.CreateThread(function()
			while atShop do
				local ped = PlayerPedId()
				local pos = GetEntityCoords(ped)
				local spot = GetEntityCoords(spawnedProps[k])
				local dis = #(pos - spot)
				if dis > 2.5 then
					ESX.UI.Menu.CloseAll()
					break
				end
				Citizen.Wait(10)
			end
		end)
		local oldProp = spawnedProps[k]
		local model = data.current.prop
		if not HasModelLoaded(model) then
			ticks[model] = 0
			while not HasModelLoaded(model) do
				ESX.ShowHelpNotification('Requesting model, please wait')
				DisableAllControlActions(0)
				Citizen.Wait(10)
				RequestModel(model)
				ticks[model] = ticks[model] + 1
				if ticks[model] >= Config.ModelWaitTicks then
					ticks[model] = 0
          ESX.ShowHelpNotification('Model '..data.current.value..' failed to load, make sure all streamed files are running(I ran into issues with mythic_interiors), please attempt re-logging to solve')
          return
				end
			end
		end
		if HasModelLoaded(model) then
			local prop = CreateObjectNoOffset(model, v.pos, false, false, false)
			spawnedProps[k] = prop
			DeleteEntity(oldProp)
			SetEntityAsMissionEntity(prop, true, true)
      SetModelAsNoLongerNeeded(model)
			PlaceObjectOnGroundProperly(prop)
			FreezeEntityPosition(prop, true)
		end
	end)
end

OpenFurnStore = function()
	for k,v in pairs(Config.Furnishing.Props) do
		validObjects[k] = {}
		validObjects[k].pos = v.pos
		validObjects[k].hed = v.hed
		validObjects[k].items = {}
		for i = 1,#v.items do
			if IsModelInCdimage(GetHashKey(v.items[i].prop)) then
				table.insert(validObjects[k].items, v.items[i])
			end
		end
	end
	local ped = PlayerPedId()
	atShop = true
	inShop = true
	if Config.BlinkOnRefresh then
		if not blinking then
			blinking = true
			if timeInd ~= 270 then
				timeInd = GetTimecycleModifierIndex()
				SetTimecycleModifier('Glasses_BlackOut')
			end
		end
	end
	SetEntityCoords(ped, Config.Furnishing.Store.exitt)
	FreezeEntityPosition(ped, true)
	SetEntityHeading(ped, Config.Furnishing.Store.enthead)
	while not HasCollisionLoadedAroundEntity(ped) do Citizen.Wait(1) end
	for k,v in pairs(validObjects) do
		local prop = CreateObjectNoOffset(v.items[1].prop, v.pos, false, false, false)
		SetEntityAsMissionEntity(prop, true, true)
		SetEntityHeading(prop, v.hed)
		PlaceObjectOnGroundProperly(prop)
		FreezeEntityPosition(prop, true)
		spawnedProps[k] = prop
	end
	FreezeEntityPosition(ped, false)
	Citizen.Wait(500)
	if Config.BlinkOnRefresh then
		if timeInd ~= -1 then
			SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
		else
			timeInd = -1
			ClearTimecycleModifier()
		end
		blinking = false
	end
	Citizen.CreateThread(function()
		while atShop do
			local pos = GetEntityCoords(ped)
			local dis
			for k,v in pairs(Config.Furnishing.Props) do
				dis = #(pos - v.pos)
				if dis <= 10.0 then
					DrawShopText(v.pos.x, v.pos.y, v.pos.z+1.5, k)
				end
				if dis <= 2.5 then
					DrawShopText(v.pos.x, v.pos.y, v.pos.z+1.0, Config.Strings.mnuScll)
					if IsControlJustReleased(0, 51) then
						OpenFurnMenu(k,v)
						Citizen.CreateThread(function()
							while spawnedProps[k] ~= nil do
								Citizen.Wait(10)
								DisableControlAction(0, 174)
								DisableControlAction(0, 175)
								if IsDisabledControlPressed(0, 174) then
									SetEntityHeading(spawnedProps[k], GetEntityHeading(spawnedProps[k]) - 0.5)
								end
								if IsDisabledControlPressed(0, 175) then
									SetEntityHeading(spawnedProps[k], GetEntityHeading(spawnedProps[k]) + 0.5)
								end
							end
						end)
					end
				end
			end
			Citizen.Wait(5)
		end
	end)
end

SetHomeWeather = function()
	if Config.Weather.ClockTime.x == 24 then
		Config.Weather.ClockTime.x = 0
	end
	SetRainFxIntensity(Config.Weather.RainIntensity) -- May not be needed, just doing it in-case
	SetWeatherTypeNowPersist(Config.Weather.WeatherType) -- initial set weather
	NetworkOverrideClockTime(math.floor(Config.Weather.ClockTime.x), math.floor(Config.Weather.ClockTime.y), math.floor(Config.Weather.ClockTime.z))
end

VerifySell = function(house)
	local elements = {
		{label = Config.Strings.sellMrk, value = 'market'},
		{label = Config.Strings.sellBnk..' Refund: $'..house.price/(100/Config.BuyBack.Percent), value = 'byback'},
		{label = Config.Strings.sellAuc, value = 'auction'},
		{label = Config.Strings.decText, value = 'no'}
	}
	if house.failBuy == 'true' then
		for k,v in pairs(elements) do
			if v.value == 'byback' then
				table.remove(elements, k)
			end
		end
	end
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'sell',
	{
		title    = Config.Strings.sellTtl,
		align    = Config.MenuAlign,
		elements = elements
	}, function(data, menu)
		local action = data.current.value
		if action == 'market' then
			ESX.UI.Menu.CloseAll()
			SelectPrice(house)
		elseif action == 'byback' then
			ESX.UI.Menu.CloseAll()
			AttemptBuyBack(house)
		elseif action == 'auction' then
			ESX.UI.Menu.CloseAll()
			RunAuction(house)
		elseif action == 'no' then
			ESX.UI.Menu.CloseAll()
		end
	end, function(data, menu)
		menu.close()
	end)
end

SelectPrice = function(house)
	local ped = PlayerPedId()
	TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', 0, false)
	local chosePrice = nil
	ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'set_price',
		{
			title = Config.Strings.setPryc
		},
	function(data, menu)
		local price = tonumber(data.value)
		if price == nil then
			Notify(Config.Strings.needNum)
		elseif price > Config.MaxSellPrice then
			Notify(Config.Strings.lowPryc:format(Config.MaxSellPrice))
		else
			chosePrice = price
			menu.close()
		end
	end, function(data, menu)
		menu.close()
	end)
	while true do
		Citizen.Wait(5)
		if chosePrice ~= nil then
			break
		end
	end
	if chosePrice ~= nil then
		TriggerServerEvent('CompleteHousing:sellHouse', house, chosePrice, 'market')
	else
		Notify(Config.Strings.noPrice)
	end
	Citizen.Wait(1500)
	ClearPedTasks(ped)
	Notify(Config.Strings.onMarkt:format(house.id,chosePrice))
end

RollCheck = function(roll, market)
	local didWin = false
	if market == 'byback' then
		for i = 1,#Config.BuyBack.Win do
			if roll == Config.BuyBack.Win[i] then
				didWin = true
			end
		end
	else
		for i = 1,#Config.Auction.Win do
			if roll == Config.Auction.Win[i] then
				didWin = true
			end
		end
	end
	return didWin
end

AttemptBuyBack = function(house)
	local ped = PlayerPedId()
	Notify(Config.Strings.buyBack:format(house.id))
	TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', 0, false)
	math.randomseed(GetGameTimer())
	local roll = math.random(Config.BuyBack.Roll)
	Citizen.Wait(2500)
	local didWin = RollCheck(roll, 'byback')
	if didWin then
		TriggerServerEvent('CompleteHousing:sellHouse', house, house.price, 'byback')
		Notify(Config.Strings.bawtBck:format(house.id,house.price))
	else
		Notify(Config.Strings.dntWant)
		TriggerServerEvent('CompleteHousing:buyBackFail', house)
	end
	ClearPedTasks(ped)
end

GetNames = function()
	local names, configFirsts, configLasts = {}, Config.Auction.FirstNames, Config.Auction.LastNames
	math.randomseed(GetGameTimer())
	for i = 1,#configLasts do
		local firstName = math.random(#configFirsts)
		local lastName = math.random(#configLasts)
		table.insert(names, configFirsts[firstName]..' '..configLasts[lastName])
		table.remove(configFirsts, firstName)
		table.remove(configLasts, lastName)
	end
	return names
end

DoesNPCWantHome = function(price)
	local doesWant, newPrice, buyer = false, price
	local fullNames = GetNames()
	math.randomseed(GetGameTimer())
	for i = 1,#fullNames do
		local roll = math.random(Config.Auction.Roll)
		local didWin = RollCheck(roll, 'auction')
		if didWin then
			doesWant = true
			newPrice = price + math.random(doRound(price/25), doRound(price/10))
			buyer = fullNames[math.random(#fullNames)]
			return doesWant, newPrice, buyer
		end
	end
	return doesWant, newPrice, buyer
end

CheckAcceptsOffer = function(house, price, buyer)
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'accept_offer',
	{
		title    = Config.Strings.acptTtl:format(price,Config.Auction.DeclineFee),
		align    = Config.MenuAlign,
		elements = {{label = Config.Strings.confTxt, value = 'yes'}, {label = Config.Strings.decText, value = 'no'}}
	}, function(data2, menu2)
		if data2.current.value == 'yes' then
			ESX.UI.Menu.CloseAll()
			Notify(Config.Strings.npcBawt:format(buyer,house.id,price))
			TriggerServerEvent('CompleteHousing:sellHouse', house, price, 'auction')
		else
			ESX.UI.Menu.CloseAll()
			TriggerServerEvent('CompleteHousing:declineAuction')
		end
	end, function(data2, menu2)
		ESX.UI.Menu.CloseAll()
		TriggerServerEvent('CompleteHousing:declineAuction')
	end)
end

RunAuction = function(house)
	local ped, purchaser = PlayerPedId()
	local price = house.price/(100/Config.Auction.StartPercent)
	local wantsIt, newPrice, buyer = DoesNPCWantHome(price)
	math.randomseed(GetGameTimer())
	local wait = math.random(5000, 10000)
	inAuction = true
	Notify(Config.Strings.strtAuc:format(house.id,price), wait)
	Notify(Config.Strings.cancAuc)
	TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', 0, false)
	Citizen.Wait(wait)
	timer = timer + wait
	if wantsIt then
		if (timer < Config.Auction.MaxTime) and (newPrice < house.price/(100/Config.Auction.MaxPercent)) then
			repeat
				price = newPrice
				purchaser = buyer
				Notify(Config.Strings.newOffr:format(buyer,newPrice,house.id), wait)
				wantsIt, newPrice, buyer = DoesNPCWantHome(price)
				wait = math.random(5000, 10000)
				Citizen.Wait(wait)
				timer = timer + wait
			until (newPrice >= house.price/(100/Config.Auction.MaxPercent)) or (timer >= Config.Auction.MaxTime) or (not wantsIt)
			if wantsIt then
				Notify(Config.Strings.newOffr:format(buyer,newPrice,house.id), wait)
			end
		else
			Notify(Config.Strings.newOffr:format(buyer,newPrice,house.id), wait)
		end
		if purchaser ~= nil then
			CheckAcceptsOffer(house, newPrice, purchaser)
		else
			CheckAcceptsOffer(house, newPrice, buyer)
		end
	else
		Notify(Config.Strings.notWant)
	end
	timer = 0
	inAuction = false
	ClearPedTasks(ped)
end

FurnishHome = function(house)
	spawnedFurn = nil
	local ped = PlayerPedId()
	local elements = {}
	ESX.TriggerServerCallback('CompleteHousing:getBoughtFurniture', function(ownedFurn)
    if type(ownedFurn) ~= 'table' then ownedFurn = {} end
		for k,v in pairs(ownedFurn) do
			table.insert(elements, {label = k, value = v.prop})
		end
		ESX.UI.Menu.CloseAll()
		if #elements > 0 then
			local model = elements[1].value
			local offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
			local prop = CreateObjectNoOffset(model, offset, false, false, false)
			local moveSpeed = 0.001
			PlaceObjectOnGroundProperly(prop)
      SetModelAsNoLongerNeeded(model)
			FreezeEntityPosition(prop, true)
			spawnedFurn = prop
			Citizen.CreateThread(function()
				while spawnedFurn ~= nil do
					Citizen.Wait(1)
					HelpText1(Config.Strings.frnHelp1)
					HelpText2(Config.Strings.frnHelp2)
					DisableControlAction(0, 51)
					DisableControlAction(0, 96)
					DisableControlAction(0, 97)
					for i = 108, 112 do
						DisableControlAction(0, i)
					end
					DisableControlAction(0, 117)
					DisableControlAction(0, 118)
					DisableControlAction(0, 171)
					DisableControlAction(0, 254)
					if IsDisabledControlPressed(0, 171) then
						moveSpeed = moveSpeed + 0.001
					end
					if IsDisabledControlPressed(0, 254) then
						moveSpeed = moveSpeed - 0.001
					end
					if moveSpeed > 1.0 or moveSpeed < 0.001 then
						moveSpeed = 0.001
					end
					HudWeaponWheelIgnoreSelection()
					for i = 123, 128 do
						DisableControlAction(0, i)
					end
					if IsDisabledControlJustPressed(0, 51) then
						PlaceObjectOnGroundProperly(spawnedFurn)
					end
					if IsDisabledControlPressed(0, 108) then -- NUMPAD 4
            local startRot = GetEntityRotation(spawnedFurn, 2)
            SetEntityRotation(spawnedFurn, startRot[1], startRot[2], startRot[3]+moveSpeed, 2)
					end
					if IsDisabledControlPressed(0, 109) then -- NUMPAD 6
            local startRot = GetEntityRotation(spawnedFurn, 2)
            SetEntityRotation(spawnedFurn, startRot[1], startRot[2], startRot[3]-moveSpeed, 2)
					end
					if IsDisabledControlPressed(0, 110) then -- NUMPAD 5
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, 0.0, moveSpeed, 0.0))
					end
					if IsDisabledControlPressed(0, 111) then -- NUMPAD 8
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, 0.0, -moveSpeed, 0.0))
					end
					if IsDisabledControlPressed(0, 117) then -- NUMPAD 7
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, moveSpeed, 0.0, 0.0))
					end
					if IsDisabledControlPressed(0, 118) then -- NUMPAD 9
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, -moveSpeed, 0.0, 0.0))
					end
          if IsDisabledControlPressed(0, 241) then -- SCROLL UP
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, 0.0, 0.0, moveSpeed))
          end
          if IsDisabledControlPressed(0, 242) then -- SCROLL DOWN
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, 0.0, 0.0, -moveSpeed))
          end
          if IsDisabledControlPressed(0, 314) then -- NUMPAD +
            local startRot = GetEntityRotation(spawnedFurn, 2)
            SetEntityRotation(spawnedFurn, startRot[1], startRot[2]+moveSpeed, startRot[3], 2)
          end
          if IsDisabledControlPressed(0, 315) then -- NUMPAD -
            local startRot = GetEntityRotation(spawnedFurn, 2)
            SetEntityRotation(spawnedFurn, startRot[1]+(moveSpeed+0.01), startRot[2], startRot[3], 2)
            local endRot = GetEntityRotation(spawnedFurn, 2)
            if endRot[1] - startRot[1] <= moveSpeed then
              SetEntityRotation(spawnedFurn, -90.0, endRot[2], endRot[3], 2)
            end
          end
				end
			end)
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_item',
			{
				title = Config.Strings.frnMenu,
				align = 'bottom-left',
				elements = elements
			}, function(data, menu)
				model = data.current.value
				if spawnedFurn ~= nil then
					if GetEntityModel(spawnedFurn) == GetHashKey(model) then
						ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'confirm_furn_place',
						{
							title    = Config.Strings.confPlc,
							align    = Config.MenuAlign,
							elements = {{label = Config.Strings.confTxt, value = 'yes'}, {label = Config.Strings.decText, value = 'no'}}
						}, function(data2, menu2)
							if data2.current.value == 'yes' then
								local itemSpot = GetEntityCoords(spawnedFurn)
								offset = GetOffsetFromEntityGivenWorldCoords(SpawnedHome[1], itemSpot)
                local iRot = GetEntityRotation(spawnedFurn, 2)
								local itemRot = {[1] = iRot[1], [2] = iRot[2], [3] = iRot[3]}
								local furn = house.furniture
								table.insert(furn.inside, {x = doRound(offset.x, 2), y = doRound(offset.y, 2), z = doRound(offset.z, 2), rotation = itemRot, prop = model, label = data.current.label})
								table.insert(SpawnedHome, spawnedFurn)
								local mLo = house.shell == 'mlo'
								TriggerServerEvent('CompleteHousing:placeFurniture', house, offset.x, offset.y, offset.z, itemRot, data.current.value, data.current.label, mLo)
								ESX.UI.Menu.CloseAll()
								house.furniture = furn
								Citizen.Wait(500)
								FurnishHome(house)
							else
								menu2.close()
							end
						end, function(data2, menu2)
							menu2.close()
						end)
					end
				end
				local testMod = GetHashKey(data.current.value)
				if GetEntityModel(spawnedFurn) ~= testMod then
					ticks[testMod] = 0
          while not HasModelLoaded(testMod) do
            Notify('Requesting model, please wait')
            DisableAllControlActions(0)
            Citizen.Wait(10)
            RequestModel(testMod)
            ticks[testMod] = ticks[testMod] + 1
            if ticks[testMod] >= Config.ModelWaitTicks then
              ticks[testMod] = 0
              Notify('Model '..data.current.value..' failed to load')
              return
            end
          end
          if spawnedFurn ~= nil then
            DeleteEntity(spawnedFurn)
          end
          offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
          prop = CreateObjectNoOffset(testMod, offset, false, false, false)
          moveSpeed = 0.001
          PlaceObjectOnGroundProperly(prop)
          SetModelAsNoLongerNeeded(testMod)
          FreezeEntityPosition(prop, true)
          spawnedFurn = prop
				end
			end, function(data, menu)
				DeleteEntity(spawnedFurn)
				spawnedFurn = nil
				menu.close()
			end, function(data, menu)
				local testMod = GetHashKey(data.current.value)
				if GetEntityModel(spawnedFurn) ~= testMod then
					ticks[testMod] = 0
          while not HasModelLoaded(testMod) do
            Notify('Requesting model, please wait')
            DisableAllControlActions(0)
            Citizen.Wait(0)
            RequestModel(testMod)
            ticks[testMod] = ticks[testMod] + 1
            if ticks[testMod] >= Config.ModelWaitTicks then
              ticks[testMod] = 0
              Notify('Model '..data.current.value..' failed to load')
              return
            end
          end
          if spawnedFurn ~= nil then
            DeleteEntity(spawnedFurn)
          end
          offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
          prop = CreateObjectNoOffset(testMod, offset, false, false, false)
          moveSpeed = 0.001
          PlaceObjectOnGroundProperly(prop)
          SetModelAsNoLongerNeeded(testMod)
          FreezeEntityPosition(prop, true)
          spawnedFurn = prop
				end
			end)
		else
			Notify(Config.Strings.failFnd)
		end
	end)
end

UnFurnishHome = function(house)
	local elements, spawnedCams = {}, {}
	local selFurn, selLabel
	local furni = house.furniture
	if furni ~= nil then
		FreezeEntityPosition(PlayerPedId(), true)
		for k,v in ipairs(furni.inside) do
			table.insert(elements, {label = v.label, value = v.prop, pos = {x = v.x, y = v.y, z = v.z}})
		end
		if #elements > 0 then
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_item',
			{
				title = Config.Strings.frnMenu,
				align = Config.MenuAlign,
				elements = elements
			}, function(data, menu)
				local model = data.current.value
				if selFurn ~= nil then
					if data.current.label == selLabel then
						ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'confirm_furn_place',
						{
							title    = Config.Strings.confRem,
							align    = Config.MenuAlign,
							elements = {{label = Config.Strings.confTxt, value = 'yes'}, {label = Config.Strings.decText, value = 'no'}}
						}, function(data2, menu2)
							if data2.current.value == 'yes' then
								for k,v in pairs(SpawnedHome) do
									if v == selFurn then
										DeleteEntity(v)
										table.remove(SpawnedHome, k)
										local mLo = house.shell == 'mlo'
										TriggerServerEvent('CompleteHousing:removeFurniture', house, data.current.pos, model, data.current.label, mLo)
										RenderScriptCams(false, false, 0, false, false)
										for i = 1,#spawnedCams do
											DestroyCam(spawnedCams[i], false)
										end
										ESX.UI.Menu.CloseAll()
									end
								end
								for k,v in ipairs(furni.inside) do
									if v.x == data.current.pos.x and v.y == data.current.pos.y and v.z == data.current.pos.z then
										table.remove(furni.inside, k)
									end
								end
								house.furniture = furni
								ESX.UI.Menu.CloseAll()
								UnFurnishHome(house)
							else
								menu2.close()
							end
						end, function(data2, menu2)
							menu2.close()
						end)
					end
				end
				local testMod = GetHashKey(model)
				if (GetEntityModel(selFurn) ~= testMod) or (selLabel ~= data.current.label) then
					local offSet = GetOffsetFromEntityInWorldCoords(SpawnedHome[1], data.current.pos.x, data.current.pos.y, data.current.pos.z)
					local prop = GetClosestObjectOfType(offSet, 1.0, testMod, false, false, false)
					if prop == 0 then
						prop = GetClosestObjectOfType(offSet, 5.0, testMod, false, false, false)
					end
					offSet = GetOffsetFromEntityInWorldCoords(prop, 0.0, 1.0, 1.0)
					local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
					table.insert(spawnedCams, cam)
					SetCamCoord(cam, offSet.x, offSet.y, offSet.z)
					PointCamAtEntity(cam, prop)
					RenderScriptCams(true, false, 0, 0, 0)
					selFurn = prop
					selLabel = data.current.label
				end
			end, function(data, menu)
				RenderScriptCams(false, false, 0, false, false)
				for i = 1,#spawnedCams do
					DestroyCam(spawnedCams[i], false)
				end
				menu.close()
				FreezeEntityPosition(PlayerPedId(), false)
			end)
		else
			Notify(Config.Strings.failFnd)
			FreezeEntityPosition(PlayerPedId(), false)
		end
	else
		print('furni table did not exist for home')
	end
end

FurnishOutHome = function(house)
	spawnedFurn = nil
	local ped = PlayerPedId()
	local elements = {}
	ESX.TriggerServerCallback('CompleteHousing:getBoughtFurniture', function(ownedFurn)
    if type(ownedFurn) ~= 'table' then ownedFurn = {} end
		for k,v in pairs(ownedFurn) do
      table.insert(elements, {label = k, value = v.prop})
		end
		ESX.UI.Menu.CloseAll()
		if #elements > 0 then
			local model = elements[1].value
			local offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
			local prop = CreateObjectNoOffset(GetHashKey(model), offset, false, false, false)
			local moveSpeed = 0.001
			PlaceObjectOnGroundProperly(prop)
			FreezeEntityPosition(prop, true)
      SetModelAsNoLongerNeeded(model)
			spawnedFurn = prop
			Citizen.CreateThread(function()
				while spawnedFurn ~= nil do
					Citizen.Wait(1)
					HelpText1(Config.Strings.frnHelp1)
					HelpText2(Config.Strings.frnHelp2)
					DisableControlAction(0, 51)
					DisableControlAction(0, 96)
					DisableControlAction(0, 97)
					for i = 108, 112 do
						DisableControlAction(0, i)
					end
					DisableControlAction(0, 117)
					DisableControlAction(0, 118)
					DisableControlAction(0, 171)
					DisableControlAction(0, 254)
					if IsDisabledControlPressed(0, 171) then
						moveSpeed = moveSpeed + 0.001
					end
					if IsDisabledControlPressed(0, 254) then
						moveSpeed = moveSpeed - 0.001
					end
					if moveSpeed > 1.0 or moveSpeed < 0.001 then
						moveSpeed = 0.001
					end
					HudWeaponWheelIgnoreSelection()
					for i = 123, 128 do
						DisableControlAction(0, i)
					end
					if IsDisabledControlJustPressed(0, 51) then
						PlaceObjectOnGroundProperly(spawnedFurn)
					end
					if IsDisabledControlPressed(0, 108) then -- NUMPAD 4
            local startRot = GetEntityRotation(spawnedFurn, 2)
            SetEntityRotation(spawnedFurn, startRot[1], startRot[2], startRot[3]+moveSpeed, 2)
					end
					if IsDisabledControlPressed(0, 109) then -- NUMPAD 6
            local startRot = GetEntityRotation(spawnedFurn, 2)
            SetEntityRotation(spawnedFurn, startRot[1], startRot[2], startRot[3]-moveSpeed, 2)
					end
					if IsDisabledControlPressed(0, 110) then -- NUMPAD 5
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, 0.0, moveSpeed, 0.0))
					end
					if IsDisabledControlPressed(0, 111) then -- NUMPAD 8
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, 0.0, -moveSpeed, 0.0))
					end
					if IsDisabledControlPressed(0, 117) then -- NUMPAD 7
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, moveSpeed, 0.0, 0.0))
					end
					if IsDisabledControlPressed(0, 118) then -- NUMPAD 9
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, -moveSpeed, 0.0, 0.0))
					end
          if IsDisabledControlPressed(0, 241) then -- SCROLL UP
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, 0.0, 0.0, moveSpeed))
          end
          if IsDisabledControlPressed(0, 242) then -- SCROLL DOWN
						SetEntityCoords(spawnedFurn, GetOffsetFromEntityInWorldCoords(spawnedFurn, 0.0, 0.0, -moveSpeed))
          end
          if IsDisabledControlPressed(0, 314) then -- NUMPAD +
            local startRot = GetEntityRotation(spawnedFurn, 2)
            SetEntityRotation(spawnedFurn, startRot[1], startRot[2]+moveSpeed, startRot[3], 2)
          end
          if IsDisabledControlPressed(0, 315) then -- NUMPAD -
            local startRot = GetEntityRotation(spawnedFurn, 2)
            SetEntityRotation(spawnedFurn, startRot[1]+(moveSpeed+0.01), startRot[2], startRot[3], 2)
            local endRot = GetEntityRotation(spawnedFurn, 2)
            if endRot[1] - startRot[1] <= moveSpeed then
              SetEntityRotation(spawnedFurn, -90.0, endRot[2], endRot[3], 2)
            end
          end
				end
			end)
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_item',
			{
				title = Config.Strings.frnMenu,
				align = 'bottom-left',
				elements = elements
			}, function(data, menu)
				model = data.current.value
				if spawnedFurn ~= nil then
					if GetEntityModel(spawnedFurn) == GetHashKey(model) then
						ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'confirm_furn_place',
						{
							title    = Config.Strings.confPlc,
							align    = Config.MenuAlign,
							elements = {{label = Config.Strings.confTxt, value = 'yes'}, {label = Config.Strings.decText, value = 'no'}}
						}, function(data2, menu2)
							if data2.current.value == 'yes' then
								local itemSpot = GetEntityCoords(spawnedFurn)
								local dis = #(itemSpot - house.door)
								if dis > house.draw then
									Notify(Config.Strings.uTooFar)
								else
                  local iRot = GetEntityRotation(spawnedFurn, 2)
                  local itemRot = {[1] = iRot[1], [2] = iRot[2], [3] = iRot[3]}
									local furn = house.furniture
									table.insert(furn.outside, {x = doRound(itemSpot.x, 2), y = doRound(itemSpot.y, 2), z = doRound(itemSpot.z, 2), rotation = itemRot, prop = model, label = data.current.label})
									TriggerServerEvent('CompleteHousing:placeOutFurniture', house, itemSpot.x, itemSpot.y, itemSpot.z, itemRot, data.current.value, data.current.label)
									ESX.UI.Menu.CloseAll()
									house.furniture = furn
									Citizen.Wait(500)
									FurnishOutHome(house)
								end
							else
								menu2.close()
							end
						end, function(data2, menu2)
							menu2.close()
						end)
					end
				end
				local testMod = GetHashKey(data.current.value)
				if GetEntityModel(spawnedFurn) ~= testMod then
					ticks[testMod] = 0
          while not HasModelLoaded(testMod) do
            ESX.ShowHelpNotification('Requesting model, please wait')
            DisableAllControlActions(0)
            Citizen.Wait(0)
            RequestModel(testMod)
            ticks[testMod] = ticks[testMod] + 1
            if ticks[testMod] >= Config.ModelWaitTicks then
              ticks[testMod] = 0
              ESX.ShowHelpNotification('Model '..data.current.value..' failed to load, make sure all streamed files are running(I ran into issues with mythic_interiors), please attempt re-logging to solve')
              return
            end
          end
          if spawnedFurn ~= nil then
            DeleteEntity(spawnedFurn)
          end
          offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
          prop = CreateObjectNoOffset(testMod, offset, false, false, false)
          moveSpeed = 0.001
          PlaceObjectOnGroundProperly(prop)
          SetModelAsNoLongerNeeded(testMod)
          FreezeEntityPosition(prop, true)
          spawnedFurn = prop
				end
			end, function(data, menu)
				DeleteEntity(spawnedFurn)
				spawnedFurn = nil
				menu.close()
			end, function(data, menu)
				local testMod = GetHashKey(data.current.value)
				if GetEntityModel(spawnedFurn) ~= testMod then
					ticks[testMod] = 0
          while not HasModelLoaded(testMod) do
            Notify('Requesting model, please wait')
            DisableAllControlActions(0)
            Citizen.Wait(0)
            RequestModel(testMod)
            ticks[testMod] = ticks[testMod] + 1
            if ticks[testMod] >= 1000 then
              ticks[testMod] = 0
              Notify('Model '..data.current.value..' failed to load')
              return
            end
          end
          if spawnedFurn ~= nil then
            DeleteEntity(spawnedFurn)
          end
          offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
          prop = CreateObjectNoOffset(testMod, offset, false, false, false)
          moveSpeed = 0.001
          PlaceObjectOnGroundProperly(prop)
          SetModelAsNoLongerNeeded(testMod)
          FreezeEntityPosition(prop, true)
          spawnedFurn = prop
				end
			end)
		else
			Notify(Config.Strings.failFnd)
		end
	end)
end

UnFurnishOutHome = function(house)
	isUnfurnishing = true
	local elements, spawnedCams = {}, {}
	FreezeEntityPosition(PlayerPedId(), true)
	local selFurn, selLabel
	local furni = house.furniture
	if furni ~= nil then
		for k,v in ipairs(furni.outside) do
			table.insert(elements, {label = v.label, value = v.prop, pos = {x = v.x, y = v.y, z = v.z}})
		end
		if #elements > 0 then
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_item',
			{
				title = Config.Strings.frnMenu,
				align = Config.MenuAlign,
				elements = elements
			}, function(data, menu)
				local model = data.current.value
				local testMod = GetHashKey(model)
				if selFurn ~= nil then
					if data.current.label == selLabel then
						ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'confirm_furn_place',
						{
							title    = Config.Strings.confRem,
							align    = Config.MenuAlign,
							elements = {{label = Config.Strings.confTxt, value = 'yes'}, {label = Config.Strings.decText, value = 'no'}}
						}, function(data2, menu2)
							if data2.current.value == 'yes' then
								for k,v in pairs(persFurn) do
									if v.entity == selFurn then
										Citizen.CreateThread(function()
											repeat
												Citizen.Wait(100)
												local prop = GetClosestObjectOfType(data.current.pos.x, data.current.pos.y, data.current.pos.z, 1.0, testMod, false, false, false)
												DeleteEntity(prop)
												prop = GetClosestObjectOfType(data.current.pos.x, data.current.pos.y, data.current.pos.z, 1.0, testMod, false, false, false)
											until not DoesEntityExist(prop)
										end)
										TriggerServerEvent('CompleteHousing:removeOutFurniture', house, data.current.pos, model, data.current.label)
										RenderScriptCams(false, false, 0, false, false)
										for i = 1,#spawnedCams do
											DestroyCam(spawnedCams[i], false)
										end
										ESX.UI.Menu.CloseAll()
									end
								end
								for k,v in ipairs(furni.outside) do
									if v.x == data.current.pos.x and v.y == data.current.pos.y and v.z == data.current.pos.z then
										table.remove(furni.outside, k)
									end
								end
								house.furniture = furni
								ESX.UI.Menu.CloseAll()
								UnFurnishOutHome(house)
							else
								menu2.close()
							end
						end, function(data2, menu2)
							menu2.close()
						end)
					end
				end
				local testMod = GetHashKey(data.current.value)
				if (GetEntityModel(selFurn) ~= testMod) or (selLabel ~= data.current.label) then
					local prop = GetClosestObjectOfType(data.current.pos.x, data.current.pos.y, data.current.pos.z, 1.0, testMod, false, false, false)
					if DoesEntityExist(prop) then
						offSet = GetOffsetFromEntityInWorldCoords(prop, 0.0, 1.0, 1.0)
						local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
						table.insert(spawnedCams, cam)
						SetCamCoord(cam, offSet.x, offSet.y, offSet.z)
						PointCamAtEntity(cam, prop)
						RenderScriptCams(true, false, 0, 0, 0)
						selFurn = prop
						selLabel = data.current.label
					end
				end
			end, function(data, menu)
				RenderScriptCams(false, false, 0, false, false)
				for i = 1,#spawnedCams do
					DestroyCam(spawnedCams[i], false)
				end
				menu.close()
				FreezeEntityPosition(PlayerPedId(), false)
				isUnfurnishing = false
			end)
		else
			Notify(Config.Strings.failFnd)
			FreezeEntityPosition(PlayerPedId(), false)
			isUnfurnishing = false
		end
	else
		print('furni table did not exist for home')
	end
end

IsHomeTouchingHome = function(x, y, z)
	local touching = false
	local pos = vector3(x, y, z)
  for k,v in pairs(spawnedHouseSpots) do
		local dis = #(pos - v.spot)
		if dis <= v.size then
			touching = true
		end
	end
	return touching
end

WardrobeMenu = function()
	ESX.UI.Menu.CloseAll()
	Citizen.Wait(500)
	local elements = {{label = Config.Strings.storOut, value = 'store'}}
	ESX.TriggerServerCallback('CompleteHousing:getClothes', function(clothing)
    if type(clothing) ~= 'table' then clothing = {} end
    for k,v in pairs(clothing) do
      table.insert(elements, {label = v.label, value = v.value})
    end
    ESX.UI.Menu.CloseAll()
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'wardrobe',
    {
      title = Config.Strings.warMenu,
      align = Config.MenuAlign,
      elements = elements
    }, function(data, menu)
      if data.current.value == 'store' then
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
          TriggerEvent('CompleteHousing:createName', skin)
        end)
      else
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'war_remove',
        {
          title = Config.Strings.wearRem,
          align = Config.MenuAlign,
          elements = {{label = Config.Strings.wearTxt, value = 'wear'},{label = Config.Strings.remText, value = 'remove'}}
        }, function(data2, menu2)
          if data2.current.value == 'wear' then
            TriggerEvent('skinchanger:loadSkin', data.current.value)
            TriggerEvent('skinchanger:getSkin', function(skin)
              TriggerServerEvent('esx_skin:save', skin)
            end)
            WardrobeMenu()
          else
            TriggerServerEvent('CompleteHousing:saveOutfit', data.current.label, data.current.value, 'rem')
            WardrobeMenu()
          end
        end, function(data2, menu2)
          menu2.close()
        end)
      end
    end, function(data, menu)
      menu.close()
    end)
	end)
end

IsHomeTouchingWater = function(x, y, z, model)
	local minDim, maxDim = GetModelDimensions(model)
	if GetWaterHeight(x, y, z) then
		return true
	end
	for x2 = math.floor(x-minDim.x),math.floor(x+maxDim.x) do
		for y2 = math.floor(y-minDim.y),math.floor(y+maxDim.y) do
			for z2 = math.floor(z-minDim.z),math.floor(z+maxDim.z) do
				if GetWaterHeight(x2,y2,z2) then
					return true
				end
			end
		end
	end
	return false
end

CollectMugshot = function(ped)
	if DoesEntityExist(ped) then
		local mugshot = RegisterPedheadshot(ped)

		while not IsPedheadshotReady(mugshot) do
			Citizen.Wait(0)
		end

		return mugshot, GetPedheadshotTxdString(mugshot)
	else
		return
	end
end

RegisterNetEvent('CompleteHousing:getIsInHouse')
AddEventHandler('CompleteHousing:getIsInHouse', function(cb)
	cb(inHome)
end)

RegisterNetEvent('CompleteHousing:getCurrentHouse')
AddEventHandler('CompleteHousing:getCurrentHouse', function(cb)
	cb(CurrentActionData)
end)

RegisterNetEvent('CompleteHousing:spawnHome')
AddEventHandler('CompleteHousing:spawnHome', function(house, spawnType, givenPos, isRaid)
	local ped = PlayerPedId()
	local pos = (givenPos ~= nil and givenPos) or GetEntityCoords(ped)
	local model = house.shell
	if not HasModelLoaded(model) then
		ticks[model] = 0
		while not HasModelLoaded(model) do
			ESX.ShowHelpNotification('Requesting model, please wait')
			DisableAllControlActions(0)
			Citizen.Wait(10)
			RequestModel(model)
			ticks[model] = ticks[model] + 1
			if ticks[model] >= Config.ModelWaitTicks then
				ticks[model] = 0
        ESX.ShowHelpNotification('Model '..model..' failed to load, make sure all streamed files are running(I ran into issues with mythic_interiors), please attempt re-logging to solve')
        return
			end
			ped = PlayerPedId()
		end
	end
	if HasModelLoaded(model) then
		ped = PlayerPedId()
		local x, y, z, spot
		if givenPos == nil then
			x, y, z = pos.x, pos.y, pos.z - Config.Shells[house.shell].shellsize
			local tooClose = IsHomeTouchingHome(x, y, z)
			if tooClose then
				z = z - 10.0
			end
			local inWater = IsHomeTouchingWater(x, y, z, house.shell)
			if inWater then
				spot = GetSafeSpot()
			else
				spot = vector3(x, y, z)
			end
		else
			spot = vector3(pos.x, pos.y, pos.z)
		end
		local home = CreateObjectNoOffset(house.shell, spot, false, false, false)
		if DoesEntityExist(home) then
			ped = PlayerPedId()
			SetEntityHeading(home, 0.0)
			FreezeEntityPosition(home, true)
			SetEntityDynamic(home, false)
			TriggerServerEvent('CompleteHousing:regSpot', 'insert', spot, house.id, Config.Shells[house.shell].shellsize)
			if isRaid ~= nil and isRaid == 'false' then
				local keyOptions = Config.KeyOptions.CanDo
				table.insert(SpawnedHome, home)
				local furni = house.furniture
				if furni ~= nil then
					for k,v in pairs(furni.inside) do
						local spawnSpot = GetOffsetFromEntityInWorldCoords(home, v.x, v.y, v.z)
						local model = GetHashKey(v.prop)
						if IsModelInCdimage(model) then
							if not HasModelLoaded(model) then
								ticks[model] = 0
								while not HasModelLoaded(model) do
									Citizen.Wait(10)
									RequestModel(model)
									ticks[model] = ticks[model] + 10
									if ticks[model] >= Config.ModelWaitTicks then
										ticks[model] = 0
										ESX.ShowHelpNotification('Model '..model..' failed to load, found in server image, please attempt re-logging to solve')
										return
									end
								end
							end
						else
							Notify(Config.Strings.modNtFd)
						end
						if HasModelLoaded(model) then
							local prop = CreateObjectNoOffset(model, spawnSpot, false, false, false)
							if v.rotation ~= nil then
								SetEntityRotation(prop, v.rotation[1], v.rotation[2], v.rotation[3], 2)
							end
							FreezeEntityPosition(prop, true)
							table.insert(SpawnedHome, prop)
						end
					end
				end
				FrontDoor = vector3(house.door.x, house.door.y, house.door.z)
				if Config.BlinkOnRefresh then
					if not blinking then
						blinking = true
						if timeInd ~= 270 then
							timeInd = GetTimecycleModifierIndex()
							SetTimecycleModifier('Glasses_BlackOut')
						end
					end
				end
				Notify(Config.Strings.amEnter)
				local doorPos = GetOffsetFromEntityInWorldCoords(home, Config.Shells[house.shell].door)
				ped = PlayerPedId()
				SetEntityCoords(ped, doorPos.x, doorPos.y, doorPos.z + 1.0)
				Citizen.Wait(1000)
				FreezeEntityPosition(ped, true)
				while not HasCollisionLoadedAroundEntity(ped) do
					Citizen.Wait(1)
					SetEntityCoords(ped, doorPos.x, doorPos.y, doorPos.z + 1.0)
					DisableAllControlActions(0)
				end
				Notify(Config.Strings.amClose)
				Citizen.Wait(1000)
				if Config.BlinkOnRefresh then
					if timeInd ~= -1 then
						SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
					else
						timeInd = -1
						ClearTimecycleModifier()
					end
					blinking = false
				end
				FreezeEntityPosition(ped, false)
				inHome = true
        TriggerEvent('CompleteHousing:setPlayerInHome', inHome)
				TriggerServerEvent('CompleteHousing:playerEnteredExitedHome', house.id, true)
				while inHome do
					Citizen.Wait(0)
					local pos = GetEntityCoords(ped)
					if Config.Weather.SetHouseWeather then
						SetHomeWeather()
					end
					local helth = GetEntityHealth(ped)
					local offset = GetEntityCoords(home)
					local dis = #(pos - offset)
					if dis > Config.Shells[house.shell].shellsize or helth <= 100 then
						ESX.UI.Menu.CloseAll()
						if Config.BlinkOnRefresh then
							if not blinking then
								blinking = true
								if timeInd ~= 270 then
									timeInd = GetTimecycleModifierIndex()
									SetTimecycleModifier('Glasses_BlackOut')
								end
							end
						end
						Notify(Config.Strings.amExitt)
						SetEntityCoords(ped, FrontDoor)
						FreezeEntityPosition(ped, true)
						while not HasCollisionLoadedAroundEntity(ped) do
							Citizen.Wait(1)
							SetEntityCoords(ped, FrontDoor)
							DisableAllControlActions(0)
						end
						Notify(Config.Strings.amClose)
						Citizen.Wait(1000)
						if Config.BlinkOnRefresh then
							if timeInd ~= -1 then
								SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
							else
								timeInd = -1
								ClearTimecycleModifier()
							end
							blinking = false
						end
						FreezeEntityPosition(ped, false)
						for i = 1,#SpawnedHome do
							DeleteEntity(SpawnedHome[i])
						end
						TriggerServerEvent('CompleteHousing:regSpot', 'remove', pos, house.id)
						TriggerServerEvent('CompleteHousing:playerEnteredExitedHome', house.id, false)
						spawnedFurn = nil
						inHome = false
            TriggerEvent('CompleteHousing:setPlayerInHome', inHome)
						FrontDoor = {}
						SpawnedHome = {}
					end
					local offset = GetOffsetFromEntityInWorldCoords(home, Config.Shells[house.shell].door)
					local dis = #(pos - offset)
					if Markers.ExitMarkers then
						DrawMarker(1, offset, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 100, false, false, 2, false, false, false, false)
					end
					if dis <= 1.25 then
						if IsControlJustReleased(0, 51) then
							ExitMenu(house)
						end
					end
					if keyOptions.Inventory then
						offset = GetOffsetFromEntityInWorldCoords(home, house.storage)
						dis = #(pos - offset)
						if Markers.IntMarkers then
							DrawMarker(1, offset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.5, 0, 255, 0, 255, false, true, 2, 0, 0, 0, 0)
						end
						if dis <= 1.25 then
							if IsControlJustReleased(0, 51) then
								local dict = 'amb@prop_human_bum_bin@base'
								RequestAnimDict(dict)
								while not HasAnimDictLoaded(dict) do Citizen.Wait(1) end
								TaskPlayAnim(ped, dict, 'base', 8.0, -8.0, 10000, 1, 0.0, false, false, false)
								TriggerEvent(Config.InventoryHudEvent, house.id, house.shell)
							end
						end
					end
				end
			elseif givenPos ~= nil then
				local title = Config.Strings.nokAcpt
				if isRaid ~= nil then
					title = Config.Strings.conRaid
				end
				ESX.UI.Menu.CloseAll()
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'knock_accept',
				{
					title = title,
					align = Config.MenuAlign,
					elements = {{label = Config.Strings.confTxt, value = 'yes'},{label = Config.Strings.decText, value = 'no'}}
				}, function(data, menu)
					if data.current.value == 'yes' then
						table.insert(SpawnedHome, home)
						local furni = house.furniture
						if furni ~= nil then
							for k,v in pairs(furni.inside) do
                if camInfo['Brand'][v.prop] then
                  TriggerServerEvent('CompleteHousing:alertOwner', house, true)
                elseif camInfo['Generic'][v.prop] then
                  TriggerServerEvent('CompleteHousing:alertOwner', house, false)
                end
								local spawnSpot = GetOffsetFromEntityInWorldCoords(home, v.x, v.y, v.z)
								local model = GetHashKey(v.prop)
								if IsModelInCdimage(model) then
									if not HasModelLoaded(model) then
										ticks[model] = 0
										while not HasModelLoaded(model) do
											Citizen.Wait(10)
											RequestModel(model)
											ticks[model] = ticks[model] + 10
											if ticks[model] >= Config.ModelWaitTicks then
												ticks[model] = 0
												ESX.ShowHelpNotification('Model '..model..' failed to load, found in server image, please attempt re-logging to solve')
												return
											end
										end
									end
								else
									Notify(Config.Strings.modNtFd)
								end
								if HasModelLoaded(model) then
									local prop = CreateObjectNoOffset(model, spawnSpot, false, false, false)
                  if v.rotation ~= nil then
                    SetEntityRotation(prop, v.rot[1], v.rot[2], v.rot[3], 2)
                  end
									FreezeEntityPosition(prop, true)
									table.insert(SpawnedHome, prop)
								end
							end
						end
						FrontDoor = vector3(house.door.x, house.door.y, house.door.z)
						if Config.BlinkOnRefresh then
							if not blinking then
								blinking = true
								if timeInd ~= 270 then
									timeInd = GetTimecycleModifierIndex()
									SetTimecycleModifier('Glasses_BlackOut')
								end
							end
						end
						local doorPos = GetOffsetFromEntityInWorldCoords(home, Config.Shells[house.shell].door)
						Notify(Config.Strings.amEnter)
						ped = PlayerPedId()
						SetEntityCoords(ped, doorPos.x, doorPos.y, doorPos.z + 1.0)
						Citizen.Wait(1000)
						FreezeEntityPosition(ped, true)
						while not HasCollisionLoadedAroundEntity(ped) do
							Citizen.Wait(1)
							SetEntityCoords(ped, doorPos.x, doorPos.y, doorPos.z + 1.0)
							DisableAllControlActions(0)
						end
						Notify(Config.Strings.amClose)
						Citizen.Wait(1000)
						if Config.BlinkOnRefresh then
							if timeInd ~= -1 then
								SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
							else
								timeInd = -1
								ClearTimecycleModifier()
							end
							blinking = false
						end
						FreezeEntityPosition(ped, false)
						inHome = true
            TriggerEvent('CompleteHousing:setPlayerInHome', inHome)
						TriggerServerEvent('CompleteHousing:playerEnteredExitedHome', house.id, true)
						while inHome do
							Citizen.Wait(0)
							local pos = GetEntityCoords(ped)
							if Config.Weather.SetHouseWeather then
								SetHomeWeather()
							end
							local helth = GetEntityHealth(ped)
							local offset = GetEntityCoords(home)
							local dis = #(pos - offset)
							if dis > Config.Shells[house.shell].shellsize or helth <= 100 then
								ESX.UI.Menu.CloseAll()
								if Config.BlinkOnRefresh then
									if not blinking then
										blinking = true
										if timeInd ~= 270 then
											timeInd = GetTimecycleModifierIndex()
											SetTimecycleModifier('Glasses_BlackOut')
										end
									end
								end
								Notify(Config.Strings.amExitt)
								SetEntityCoords(ped, FrontDoor)
								FreezeEntityPosition(ped, true)
								while not HasCollisionLoadedAroundEntity(ped) do
									Citizen.Wait(1)
									SetEntityCoords(ped, FrontDoor)
									DisableAllControlActions(0)
								end
								Notify(Config.Strings.amClose)
								Citizen.Wait(1000)
								if Config.BlinkOnRefresh then
									if timeInd ~= -1 then
										SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
									else
										timeInd = -1
										ClearTimecycleModifier()
									end
									blinking = false
								end
								FreezeEntityPosition(ped, false)
								for i = 1,#SpawnedHome do
									DeleteEntity(SpawnedHome[i])
								end
								TriggerServerEvent('CompleteHousing:regSpot', 'remove', pos, house.id)
								TriggerServerEvent('CompleteHousing:playerEnteredExitedHome', house.id, false)
								spawnedFurn = nil
								inHome = false
                TriggerEvent('CompleteHousing:setPlayerInHome', inHome)
								FrontDoor = {}
								SpawnedHome = {}
							end
							local offset = GetOffsetFromEntityInWorldCoords(home, Config.Shells[house.shell].door)
							local dis = #(pos - offset)
							if Markers.ExitMarkers then
								DrawMarker(1, offset, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 100, false, false, 2, false, false, false, false)
							end
							if dis <= 1.25 then
								if IsControlJustReleased(0, 51) then
									ExitMenu(house)
								end
							end
							local offset = GetOffsetFromEntityInWorldCoords(home, house.storage)
							dis = #(pos - offset)
							if Markers.IntMarkers then
								DrawMarker(1, offset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.5, 0, 255, 0, 255, false, true, 2, 0, 0, 0, 0)
							end
							if dis <= 1.25 then
								if IsControlJustReleased(0, 51) then
									local dict = 'amb@prop_human_bum_bin@base'
									RequestAnimDict(dict)
									while not HasAnimDictLoaded(dict) do Citizen.Wait(1) end
									TaskPlayAnim(ped, dict, 'base', 8.0, -8.0, 10000, 1, 0.0, false, false, false)
									TriggerEvent(Config.InventoryHudEvent, house.id, house.shell)
								end
							end
						end
					else
						ESX.UI.Menu.CloseAll()
					end
				end, function(data, menu)
					menu.close()
				end)
			else
				ped = PlayerPedId()
				pos = GetEntityCoords(ped)
				currentHouseID = house.id
				inHome = true
        TriggerEvent('CompleteHousing:setPlayerInHome', inHome)
				FrontDoor = vector3(house.door.x, house.door.y, house.door.z)
				table.insert(SpawnedHome, home)
				local furni = house.furniture
				if furni ~= nil then
					for k,v in pairs(furni.inside) do
            if PlayerData.identifier ~= house.owner then
              if camInfo['Brand'][v.prop] then
                TriggerServerEvent('CompleteHousing:alertOwner', house, true)
              elseif camInfo['Generic'][v.prop] then
                TriggerServerEvent('CompleteHousing:alertOwner', house, false)
              end
            end
						local spawnSpot = GetOffsetFromEntityInWorldCoords(home, v.x, v.y, v.z)
						local model = GetHashKey(v.prop)
						if IsModelInCdimage(model) then
							if not HasModelLoaded(model) then
								ticks[model] = 0
								while not HasModelLoaded(model) do
									Citizen.Wait(10)
									RequestModel(model)
									ticks[model] = ticks[model] + 10
									if ticks[model] >= Config.ModelWaitTicks then
										ticks[model] = 0
										ESX.ShowHelpNotification('Model '..model..' failed to load, found in server image, please attempt re-logging to solve')
										return
									end
								end
							end
						else
							Notify(Config.Strings.modNtFd)
						end
						if HasModelLoaded(model) then
							local prop = CreateObjectNoOffset(model, spawnSpot, false, false, false)
							if v.rotation ~= nil then
								SetEntityRotation(prop, v.rotation[1], v.rotation[2], v.rotation[3], 2)
							end
							FreezeEntityPosition(prop, true)
							table.insert(SpawnedHome, prop)
						end
					end
				else
					print('The house furniture table did not exist?')
				end
				if Config.BlinkOnRefresh then
					if not blinking then
						blinking = true
						if timeInd ~= 270 then
							timeInd = GetTimecycleModifierIndex()
							SetTimecycleModifier('Glasses_BlackOut')
						end
					end
				end
				Notify(Config.Strings.amEnter)
				local offset = GetOffsetFromEntityInWorldCoords(home, Config.Shells[house.shell].door)
				ped = PlayerPedId()
				SetEntityCoords(ped, offset.x, offset.y, offset.z + 1.0)
				TaskTurnPedToFaceEntity(ped, home, 1000)
				Citizen.Wait(1000)
				FreezeEntityPosition(ped, true)
				while not HasCollisionLoadedAroundEntity(ped) do
					Citizen.Wait(1)
					SetEntityCoords(ped, offset.x, offset.y, offset.z + 1.0)
					DisableAllControlActions(0)
				end
				Notify(Config.Strings.amClose)
				Citizen.Wait(1000)
				if Config.BlinkOnRefresh then
					if timeInd ~= -1 then
						SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
					else
						timeInd = -1
						ClearTimecycleModifier()
					end
					blinking = false
				end
				FreezeEntityPosition(ped, false)
				inHome = true
        TriggerEvent('CompleteHousing:setPlayerInHome', inHome)
				TriggerServerEvent('CompleteHousing:playerEnteredExitedHome', house.id, true)
				while inHome do
					Citizen.Wait(5)
					pos = GetEntityCoords(ped)
					if Config.Weather.SetHouseWeather then
						SetHomeWeather()
					end
					local helth = GetEntityHealth(ped)
					local offset = GetEntityCoords(home)
					local dis = #(pos - offset)
					if dis > Config.Shells[house.shell].shellsize or helth <= 100 then
						ESX.UI.Menu.CloseAll()
						if Config.BlinkOnRefresh then
							if not blinking then
								blinking = true
								if timeInd ~= 270 then
									timeInd = GetTimecycleModifierIndex()
									SetTimecycleModifier('Glasses_BlackOut')
								end
							end
						end
						Notify(Config.Strings.amExitt)
						SetEntityCoords(ped, FrontDoor)
						FreezeEntityPosition(ped, true)
						while not HasCollisionLoadedAroundEntity(ped) do
							Citizen.Wait(1)
							SetEntityCoords(ped, FrontDoor)
							DisableAllControlActions(0)
						end
						Notify(Config.Strings.amClose)
						Citizen.Wait(1000)
						if Config.BlinkOnRefresh then
							if timeInd ~= -1 then
								SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
							else
								timeInd = -1
								ClearTimecycleModifier()
							end
							blinking = false
						end
						FreezeEntityPosition(ped, false)
						for i = 1,#SpawnedHome do
							DeleteEntity(SpawnedHome[i])
						end
						TriggerServerEvent('CompleteHousing:regSpot', 'remove', pos, house.id)
						TriggerServerEvent('CompleteHousing:playerEnteredExitedHome', house.id, false)
						spawnedFurn = nil
						inHome = false
            TriggerEvent('CompleteHousing:setPlayerInHome', inHome)
						FrontDoor = {}
						SpawnedHome = {}
					end
					offset = GetOffsetFromEntityInWorldCoords(home, Config.Shells[house.shell].door)
					dis = #(pos - offset)
					if Markers.ExitMarkers then
						DrawMarker(1, offset, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 100, false, false, 2, false, false, false, false)
					end
					if dis <= 1.25 then
						if IsControlJustReleased(0, 51) then
							ExitMenu(house)
						end
					end
					if spawnType == 'owned' then
						offset = GetOffsetFromEntityInWorldCoords(home, house.storage)
						if Markers.IntMarkers then
							DrawMarker(1, offset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.5, 0, 255, 0, 255, false, true, 2, 0, 0, 0, 0)
						end
						dis = #(pos - offset)
						if dis <= 1.25 then
							if IsControlJustReleased(0, 51) then
								local dict = 'amb@prop_human_bum_bin@base'
								RequestAnimDict(dict)
								while not HasAnimDictLoaded(dict) do Citizen.Wait(1) end
								TaskPlayAnim(ped, dict, 'base', 8.0, -8.0, 10000, 1, 0.0, false, false, false)
								TriggerEvent(Config.InventoryHudEvent, house.id, house.shell)
							end
						end
						offset = GetOffsetFromEntityInWorldCoords(home, house.wardrobe)
						if Markers.IntMarkers then
							DrawMarker(1, offset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.5, 0, 255, 0, 255, false, true, 2, 0, 0, 0, 0)
						end
						dis = #(pos - offset)
						if dis <= 1.25 then
							if IsControlJustReleased(0, 51) then
								Config.WardrobeEvent()
							end
						end
					end
				end
			end
		else
			Notify(Config.Strings.wntRong)
		end
	end
end)

RegisterNetEvent('CompleteHousing:createName')
AddEventHandler('CompleteHousing:createName', function(skin)
	local genName = nil
	local doBreak = false
	ESX.UI.Menu.Open(
		'dialog', GetCurrentResourceName(), 'choose_name_text',
		{
			title = Config.Strings.nameSel
		},
	function(data, menu)
		local name = tostring(data.value)
		local length = string.len(name)
		if length == nil then
			Notify(Config.Strings.needNam)
		elseif length > 55 then
			Notify(Config.Strings.nameLng:format('1','55'))
		else
			genName = name
			menu.close()
		end
	end, function(data, menu)
	end)
	while true do
		Citizen.Wait(2)
		if genName ~= nil then
			doBreak = true
			if doBreak then
				break
			end
		end
	end
	TriggerServerEvent('CompleteHousing:saveOutfit', genName, skin, 'add')
	WardrobeMenu()
end)

RegisterNetEvent('CompleteHousing:doorKnock')
AddEventHandler('CompleteHousing:doorKnock', function(knocker)
	if knocker ~= nil then
		if inHome then
			Notify(Config.Strings.dorKnok)
		else
			TriggerServerEvent('CompleteHousing:knockFail', knocker)
		end
	else
		Notify(Config.Strings.notHome)
	end
end)

RegisterNetEvent('CompleteHousing:updateHomes')
AddEventHandler('CompleteHousing:updateHomes', function(houses)
  if not houses then return end
	while ESX == nil do Citizen.Wait(10); print('waiting'); end
	if Config.BlinkOnRefresh then
		if not blinking then
			blinking = true
			if timeInd ~= 270 then
				Notify(Config.Strings.amBlink)
				timeInd = GetTimecycleModifierIndex()
				SetTimecycleModifier('Glasses_BlackOut')
			end
		end
	end
  if type(houses) == 'table' then
    print(houses[1])
    if houses[1] then
      for i = 1,#scriptBlips do
        RemoveBlip(scriptBlips[i])
      end
      Houses = {}
      for k,v in pairs(houses) do
        Citizen.Wait(5)
        local door = json.decode(v.door)
        local storage = json.decode(v.storage)
        local wardrobe = json.decode(v.wardrobe)
        v.door = vector3(door.x, door.y, door.z)
        v.storage = vector3(storage.x, storage.y, storage.z)
        v.wardrobe = vector3(wardrobe.x, wardrobe.y, wardrobe.z)
        v.doors = json.decode(v.doors)
        v.garages = json.decode(v.garages)
        v.furniture = json.decode(v.furniture)
        v.parkings = json.decode(v.parkings)
        v.keys = json.decode(v.keys)
        Houses[v.id] = v
      end
      for k,v in pairs(Houses) do
        Citizen.Wait(5)
        local IsHidden = IsAddressHidden(v.id)
        if not IsHidden then
          if PlayerData.identifier == v.owner then
            local blips = Blips.OwnedHome
            if blips.Use then
              local blip = AddBlipForCoord(v.door)
              SetBlipScale  (blip, 1.0)
              SetBlipAsShortRange(blip, true)
              SetBlipSprite (blip, blips.Sprite)
              SetBlipColour (blip, blips.Color)
              SetBlipScale  (blip, blips.Scale)
              SetBlipDisplay(blip, blips.Display)
              BeginTextCommandSetBlipName("STRING")
              AddTextComponentString(blips.Text:gsub('useaddress', k))
              EndTextCommandSetBlipName(blip)
              table.insert(scriptBlips, blip)
            end
          elseif v.owner == 'nil' then
            local blips = Blips.UnOwnedHome
            if blips.Use then
              local blip = AddBlipForCoord(v.door)
              SetBlipScale  (blip, 1.0)
              SetBlipAsShortRange(blip, true)
              SetBlipSprite (blip, blips.Sprite)
              SetBlipColour (blip, blips.Color)
              SetBlipScale  (blip, blips.Scale)
              SetBlipDisplay(blip, blips.Display)
              BeginTextCommandSetBlipName("STRING")
              AddTextComponentString(blips.Text:gsub('useaddress', k))
              EndTextCommandSetBlipName(blip)
              table.insert(scriptBlips, blip)
            end
          else
            local blips = Blips.OtherOwnedHome
            if blips.Use then
              local blip = AddBlipForCoord(v.door)
              SetBlipScale  (blip, 1.0)
              SetBlipAsShortRange(blip, true)
              SetBlipSprite (blip, blips.Sprite)
              SetBlipColour (blip, blips.Color)
              SetBlipScale  (blip, blips.Scale)
              SetBlipDisplay(blip, blips.Display)
              BeginTextCommandSetBlipName("STRING")
              AddTextComponentString(blips.Text:gsub('useaddress', k))
              EndTextCommandSetBlipName(blip)
              table.insert(scriptBlips, blip)
            end
          end
        end
        if v.furniture then
          for g,f in pairs(v.furniture.outside) do
            Citizen.Wait(50)
            table.insert(persFurn, {model = f.prop, pos = vector3(f.x, f.y, f.z), rotation = f.rotation})
          end
        end
      end
    else
      local door = json.decode(houses.door)
      local storage = json.decode(houses.storage)
      local wardrobe = json.decode(houses.wardrobe)
      houses.door = vector3(door.x, door.y, door.z)
      houses.storage = vector3(storage.x, storage.y, storage.z)
      houses.wardrobe = vector3(wardrobe.x, wardrobe.y, wardrobe.z)
      houses.doors = json.decode(houses.doors)
      houses.garages = json.decode(houses.garages)
      houses.furniture = json.decode(houses.furniture)
      houses.parkings = json.decode(houses.parkings)
      houses.keys = json.decode(houses.keys)
      Houses[houses.id] = houses
      local IsHidden = IsAddressHidden(houses.id)
      if not IsHidden then
        if PlayerData.identifier == houses.owner then
          local blips = Blips.OwnedHome
          if blips.Use then
            local blip = AddBlipForCoord(houses.door)
            SetBlipScale  (blip, 1.0)
            SetBlipAsShortRange(blip, true)
            SetBlipSprite (blip, blips.Sprite)
            SetBlipColour (blip, blips.Color)
            SetBlipScale  (blip, blips.Scale)
            SetBlipDisplay(blip, blips.Display)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(blips.Text:gsub('useaddress', houses.id))
            EndTextCommandSetBlipName(blip)
            table.insert(scriptBlips, blip)
          end
        elseif houses.owner == 'nil' then
          local blips = Blips.UnOwnedHome
          if blips.Use then
            local blip = AddBlipForCoord(houses.door)
            SetBlipScale  (blip, 1.0)
            SetBlipAsShortRange(blip, true)
            SetBlipSprite (blip, blips.Sprite)
            SetBlipColour (blip, blips.Color)
            SetBlipScale  (blip, blips.Scale)
            SetBlipDisplay(blip, blips.Display)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(blips.Text:gsub('useaddress', houses.id))
            EndTextCommandSetBlipName(blip)
            table.insert(scriptBlips, blip)
          end
        else
          local blips = Blips.OtherOwnedHome
          if blips.Use then
            local blip = AddBlipForCoord(houses.door)
            SetBlipScale  (blip, 1.0)
            SetBlipAsShortRange(blip, true)
            SetBlipSprite (blip, blips.Sprite)
            SetBlipColour (blip, blips.Color)
            SetBlipScale  (blip, blips.Scale)
            SetBlipDisplay(blip, blips.Display)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(blips.Text:gsub('useaddress', houses.id))
            EndTextCommandSetBlipName(blip)
            table.insert(scriptBlips, blip)
          end
        end
      end
      if houses.furniture then
        for g,f in pairs(houses.furniture.outside) do
          Citizen.Wait(50)
          table.insert(persFurn, {model = f.prop, pos = vector3(f.x, f.y, f.z), rotation = f.rotation})
        end
      end
    end
  else
    Houses[houses] = nil
  end
	Citizen.Wait(500)
	if Config.BlinkOnRefresh then
		if timeInd ~= -1 then
			SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
		else
			timeInd = -1
			ClearTimecycleModifier()
		end
		blinking = false
	end
end)

RegisterNetEvent('CompleteHousing:garageCarEvent')
AddEventHandler('CompleteHousing:garageCarEvent', function(ped, veh)
	local vehProps  = ESX.Game.GetVehicleProperties(veh)
	ESX.TriggerServerCallback('CompleteHousing:isCarOwned', function(owner)
		if owner then
			local livery = GetVehicleLivery(veh)
			local damages	= {
				eng = GetVehicleEngineHealth(veh),
				bod = GetVehicleBodyHealth(veh),
				tnk = GetVehiclePetrolTankHealth(veh),
				drt = GetVehicleDirtLevel(veh),
				oil = GetVehicleOilLevel(veh),
				lok = GetVehicleDoorLockStatus(veh),
				drvlyt = GetIsLeftVehicleHeadlightDamaged(veh),
				paslyt = GetIsRightVehicleHeadlightDamaged(veh),
				dor = {},
				win = {},
				tyr = {}
			}
			local vehPos    = GetEntityCoords(veh)
			local vehHead   = GetEntityHeading(veh)
			for i = 0,5 do
				damages.dor[i] = not DoesVehicleHaveDoor(veh, i)
			end
			for i = 0,3 do
				damages.win[i] = not IsVehicleWindowIntact(veh, i)
			end
			damages.win[6] = not IsVehicleWindowIntact(veh, 6)
			damages.win[7] = not IsVehicleWindowIntact(veh, 7)
			for i = 0,7 do
				damages.tyr[i] = false
				if IsVehicleTyreBurst(veh, i, false) then
					damages.tyr[i] = 'popped'
				elseif IsVehicleTyreBurst(veh, i, true) then
					damages.tyr[i] = 'gone'
				end
			end
			LastPlate = vehProps.plate
			if Config.BlinkOnRefresh then
				if not blinking then
					blinking = true
					if timeInd ~= 270 then
						timeInd = GetTimecycleModifierIndex()
						SetTimecycleModifier('Glasses_BlackOut')
					end
				end
			end
			DeleteEntity(veh)
			SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(ped, -1.0, 0.0, 0.0))
			TriggerServerEvent('CompleteHousing:parkUnpark', {
				location = {x = vehPos.x, y = vehPos.y, z = vehPos.z},
				vehicle    = vehProps,
				livery   = livery,
				damages   = damages
			}, true, 'enter')
		else
			Notify(Config.Strings.mstBOwn)
		end
	end, vehProps.plate)
end)

RegisterNetEvent('CompleteHousing:openGarageEvent')
AddEventHandler('CompleteHousing:openGarageEvent', function(house)
	ESX.TriggerServerCallback('CompleteHousing:getGaragedCars', function(vehicles)
		if #vehicles > 0 then
			local elements = {}
			for k,v in pairs(vehicles) do
				v.vehicle = json.decode(v.vehicle)
				table.insert(elements, {label = GetLabelText(GetDisplayNameFromVehicleModel(v.vehicle.model)) .. " - " .. v.vehicle.plate, value = v
				})
			end
			ESX.UI.Menu.CloseAll()
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'garage',
			{
				title = 'Valet Car',
				align = Config.MenuAlign,
				elements = elements
			}, function(data, menu)
				menu.close()
				TriggerServerEvent('CompleteHousing:parkUnpark', data.current.value, true, 'leave')
				ESX.Game.SpawnVehicle(data.current.value.vehicle.model, GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId()), function(yourVehicle)
					ESX.Game.SetVehicleProperties(yourVehicle, data.current.value.vehicle)
					SetModelAsNoLongerNeeded(data.current.value.vehicle.model)
					TaskWarpPedIntoVehicle(PlayerPedId(), yourVehicle, -1)
					SetEntityAsMissionEntity(yourVehicle, true, true)
					Notify('Your vehicle was pulled to this home')
				end)
			end, function(data, menu)
				menu.close()
			end)
		else
			Notify('You have no garaged cars')
		end
	end, house.id)
end)

RegisterNetEvent("CompleteHousing:refreshVehicles")
AddEventHandler("CompleteHousing:refreshVehicles", function(vehicles)
	while ESX == nil do Citizen.Wait(10) end
	for k,v in pairs(ParkedCars) do
		Citizen.CreateThread(function()
			while not ESX.Game.IsSpawnPointClear(v.pos, 1.0) do
				Citizen.Wait(5)
				local veh = ESX.Game.GetClosestVehicle(v.pos)
				if DoesEntityExist(veh) then
					if string.match(doTrim(GetVehicleNumberPlateText(veh)), doTrim(v.props.plate)) then
						DeleteEntity(veh)
					end
				end
			end
		end)
	end
	ParkedCars = {}
	for k,v in ipairs(vehicles) do
		ParkedCars[v.plate] = v.vehicle
		ParkedCars[v.plate].pos = vector3(v.vehicle.location.x, v.vehicle.location.y, v.vehicle.location.z)
	end
	if Config.BlinkOnRefresh then
		if timeInd ~= -1 then
			SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
		else
			timeInd = -1
			ClearTimecycleModifier()
		end
		blinking = false
	end
end)

RegisterNetEvent('CompleteHousing:removeVehicle')
AddEventHandler('CompleteHousing:removeVehicle', function(vehicle)
  isRemoving = true
  for k,v in pairs(ParkedCars) do
    if doTrim(v.props.plate) == doTrim(vehicle.props.plate) then
      DeleteEntity(v.entity)
      ParkedCars[k] = nil
    end
  end
  isRemoving = false
end)

RegisterNetEvent('CompleteHousing:addVehicle')
AddEventHandler('CompleteHousing:addVehicle', function(vehicle, oldDriver)
  local plyID = GetPlayerServerId(PlayerId())
  if oldDriver == plyID then
    local plyPed = PlayerPedId()
    DeleteEntity(GetVehiclePedIsIn(plyPed, true))
    Citizen.CreateThread(function()
      Citizen.Wait(1000)
      TaskWarpPedIntoVehicle(plyPed, ParkedCars[vehicle.props.plate].entity, -1)
      FreezeEntityPosition(plyPed, false)
      SetEntityVisible(plyPed, true)
    end)
  end
  ParkedCars[vehicle.props.plate] = vehicle
  ParkedCars[vehicle.props.plate].pos = vector3(vehicle.location.x, vehicle.location.y, vehicle.location.z)
end)

RegisterNetEvent('CompleteHousing:driveCar')
AddEventHandler('CompleteHousing:driveCar', function(vehicle)
	Citizen.Wait(1000)
	while not HasModelLoaded(vehicle.props.model) do
		Citizen.Wait(10)
		RequestModel(vehicle.props.model)
	end
	ClearAreaOfEverything(vehicle.location.x, vehicle.location.y, vehicle.location.z, 1.0, false, false, false, false)
  Citizen.Wait(1000) -- IF CARS DISAPPEAR AFTER SPAWNING INCREASE THIS TIMER
	local spawnedCar = CreateVehicle(vehicle.props.model, vehicle.location.x, vehicle.location.y, vehicle.location.z, vehicle.location.h, true, true)
	while not DoesEntityExist(spawnedCar) do 
		Citizen.Wait(10)
	end
	ESX.Game.SetVehicleProperties(spawnedCar, vehicle.props)
	SetVehicleOnGroundProperly(spawnedCar)
	SetEntityAsMissionEntity(spawnedCar, true, true)
	SetModelAsNoLongerNeeded(vehicle.props.model)
	SetVehicleLivery(spawnedCar, vehicle.livery)
	SetVehicleEngineHealth(spawnedCar, vehicle.damages.eng)
	SetVehicleOilLevel(spawnedCar, vehicle.damages.oil)
	SetVehicleBodyHealth(spawnedCar, vehicle.damages.bod)
	SetVehicleDoorsLocked(spawnedCar, vehicle.damages.lok)
	SetVehiclePetrolTankHealth(spawnedCar, vehicle.damages.tnk)
	for k,v in pairs(vehicle.damages.dor) do
		if vehicle.damages.dor[k] then
			SetVehicleDoorBroken(spawnedCar, tonumber(k), true)
		end
	end
	for k,v in pairs(vehicle.damages.win) do
		if vehicle.damages.win[k] then
			SmashVehicleWindow(spawnedCar, tonumber(k))
		end
	end
	for k,v in pairs(vehicle.damages.tyr) do
		if vehicle.damages.tyr[k] == 'popped' then
			SetVehicleTyreBurst(spawnedCar, tonumber(k), false, 850.0)
		elseif vehicle.damages.tyr[k] == 'gone' then
			SetVehicleTyreBurst(spawnedCar, tonumber(k), true, 1000.0)
		end
	end
	while not HasCollisionLoadedAroundEntity(spawnedCar) do
		Citizen.Wait(10)
	end
	SetVehicleOnGroundProperly(spawnedCar)
  local plyPed = PlayerPedId()
	TaskWarpPedIntoVehicle(plyPed, spawnedCar, -1)
  FreezeEntityPosition(plyPed, false)
  SetEntityVisible(plyPed, true)
end)

RegisterNetEvent('CompleteHousing:alertBreakIn')
AddEventHandler('CompleteHousing:alertBreakIn', function(target, house)
  local targetPlayer = GetPlayerPed(GetPlayerFromServerId(target))
	local mugshot, mugstring = CollectMugshot(targetPlayer)
	ESX.ShowAdvancedNotification('Possible Break In At '..house.id, 'Surveillance cam photo recieved', '', mugstring, 1)
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
	while ESX == nil do Citizen.Wait(10) end
  Citizen.Wait(200)
  PlayerData = ESX.GetPlayerData()
end)

AddEventHandler('CompleteHousing:hasEnteredMarker', function(house)
	CurrentAction     = 'front_door'
	CurrentActionMsg  = Config.Strings.dorOptn
	CurrentActionData = house
end)

AddEventHandler('CompleteHousing:hasExitedMarker', function()
	if not ESX.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'choose_item') then
		if not ESX.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'confirm_furn_place') then
			ESX.UI.Menu.CloseAll()
		end
	end
	CurrentAction = nil
	CurrentActionMsg = ''
	CurrentActionData = {}
end)

AddEventHandler('playerSpawned', function()
	isDead = false
end)

AddEventHandler('esx:onPlayerDeath', function()
	isDead = true
end)
	
AddEventHandler('onResourceStop', function(resource)
	local ped = PlayerPedId()
	if resource == GetCurrentResourceName() then
		ESX.UI.Menu.CloseAll()
		if atShop then
			local ped = PlayerPedId()
			for k,v in pairs(spawnedProps) do
				DeleteEntity(v)
			end
			if inShop then
				SetEntityCoords(ped, Config.Furnishing.Store.enter)
				SetEntityHeading(ped, Config.Furnishing.Store.exthead)
			end
		end
		for k,v in pairs(persFurn) do
			DeleteEntity(v.entity)
		end
		if inHome then
			if Config.BlinkOnRefresh then
				if not blinking then
					blinking = true
					if timeInd ~= 270 then
						timeInd = GetTimecycleModifierIndex()
						SetTimecycleModifier('Glasses_BlackOut')
					end
				end
			end
			SetEntityCoords(ped, FrontDoor)
			FreezeEntityPosition(ped, true)
			while not HasCollisionLoadedAroundEntity(ped) do
				Citizen.Wait(1)
			end
			FreezeEntityPosition(ped, false)
			if Config.BlinkOnRefresh then
				if timeInd ~= -1 then
					SetTimecycleModifier(Config.TimeCycleMods[tostring(timeInd)])
				else
					timeInd = -1
					ClearTimecycleModifier()
				end
				blinking = false
			end
			for i = 1,#SpawnedHome do
				DeleteEntity(SpawnedHome[i])
			end
			SpawnedHome = {}
		end
	end
end)

RegisterCommand(Config.Creation.Commands.AddHouse, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local shell, price, draw = Config.Defaults.Shell, Config.Defaults.Price, Config.Defaults.Draw
	ESX.TriggerServerCallback('CompleteHousing:canCreate', function(canCreate)
		if canCreate then
			local ped = PlayerPedId()
			local pos = GetEntityCoords(ped)
			ESX.UI.Menu.CloseAll()
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'name_house',
			{
				title = Config.Strings.addAdrs
			},
			function(data, menu)
				local address = data.value
				
				if address == nil or address == '' then
					Notify(Config.Strings.noAddrs)
					address = CreateRandomAddress()
				end
				if string.len(address) > 55 then
					Notify(Config.Strings.add2Sht:format(string.len(address)))
				else
					menu.close()
					local elements = {}
					table.insert(elements, {label = 'MLO', value = 'mlo'})
					for k,v in pairs(Config.Shells) do
						table.insert(elements, {label = k, value = k})
					end
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_shell',
						{
							title = Config.Strings.chsShll,
							align = Config.MenuAlign,
							elements = elements
						}, function(data2, menu2)
							shell = data2.current.value
							menu2.close()
							ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'set_price',
								{
									title = Config.Strings.setPryc
								}, function(data3, menu3)
									if data3.value ~= nil and tonumber(data3.value) > Config.MaxSellPrice then
										Notify(Config.Strings.lowPryc:format(Config.MaxSellPrice))
									else
										if data3.value == nil then
											Notify(Config.Strings.noPrice)
										else
											price = tonumber(data3.value)
										end
										menu3.close()
										local elms = {}
										for i = 1,#Config.LandSize do
											table.insert(elms, {label = Config.LandSize[i], value = Config.LandSize[i]})
										end
										drawRange = 5
										Citizen.CreateThread(function()
											while drawRange > 0 do
												Citizen.Wait(5)
												DrawMarker(2, GetOffsetFromEntityInWorldCoords(ped, 0.0, (drawRange * 1.0), 0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 3.0, 255, 0, 0, 255, true, true, 2, 0, 0, 0, 0)
											end
										end)
										ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'set_draw',
											{
												title = Config.Strings.lndSize,
												align = Config.MenuAlign,
												elements = elms
											}, function(data4, menu4)
												draw = data4.current.value * 1.0
												drawRange = 0
												menu4.close()
												ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'garage_type',
												{
													title = 'Choose Garage Type',
													align = Config.MenuAlign,
													elements = {{label = 'Persistent', value = 'persistent'}, {label = 'Garage', value = 'garage'}}
												}, function(data5, menu5)
													if Config.SpecialProperties.Use then
														menu5.close()
														local yesno = {{label = Config.Strings.confTxt, value = 'yes'},{label = Config.Strings.decText, value = 'no'},{label = 'Only Special Pricing', value = 'spec'}}
														ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_is_special',
														{
															title = Config.Strings.isPecil,
															align = Config.MenuAlign,
															elements = yesno
														}, function(data6, menu6)
															TriggerServerEvent('CompleteHousing:createHouse', address, doRound(pos.x, 2), doRound(pos.y, 2), doRound(pos.z, 2) - 1.0, shell, price, draw, data5.current.value, data6.current.value)
															menu6.close()
														end, function(data6, menu6)
															menu6.close()
														end)
													else
														TriggerServerEvent('CompleteHousing:createHouse', address, doRound(pos.x, 2), doRound(pos.y, 2), doRound(pos.z, 2) - 1.0, shell, price, draw, data5.current.value)
														menu5.close()
													end
												end, function(data5, menu5)
													menu5.close()
												end)
											end, function(data4, menu4)
											menu4.close()
											drawRange = 0
											end, function(data4, menu4)
											drawRange = data4.current.value
										end)
									end
								end, function(data3, menu3)
								menu3.close()
							end)
						end, function(data2, menu2)
						menu2.close()
					end)
				end
			end, function(data, menu)
			menu.close()
			end)
		else
			Notify(Config.Strings.noPerms)
		end
	end)
end, false)

RegisterCommand(Config.Creation.Commands.ChangeRange, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local draw = Config.Defaults.Draw
	ESX.TriggerServerCallback('CompleteHousing:canCreate', function(canCreate)
		if canCreate then
			local ped = PlayerPedId()
			local pos = GetEntityCoords(ped)
			ESX.UI.Menu.CloseAll()
			local elements = {}
			for k,v in pairs(Houses) do
				dis = #(pos - v.door)
				if dis <= v.draw then
					table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
				end
			end
			ESX.UI.Menu.CloseAll()
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_address',
			{
				title = Config.Strings.clstAdd,
				align = Config.MenuAlign,
				elements = elements
			},function(data, menu)
				local elms = {}
				for i = 1,#Config.LandSize do
					table.insert(elms, {label = Config.LandSize[i], value = Config.LandSize[i]})
				end
				drawRange = 5
				Citizen.CreateThread(function()
					while drawRange > 0 do
						Citizen.Wait(5)
						DrawMarker(2, GetOffsetFromEntityInWorldCoords(ped, 0.0, (drawRange * 1.0), 0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 3.0, 255, 0, 0, 255, true, true, 2, 0, 0, 0, 0)
					end
				end)
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'set_draw',
				{
					title = Config.Strings.lndSize,
					align = Config.MenuAlign,
					elements = elms
				}, function(data4, menu4)
					draw = data4.current.value * 1.0
					drawRange = 0
					menu4.close()
					TriggerServerEvent('CompleteHousing:updateLandSize', data.current.value, draw)
				end, function(data4, menu4)
				menu4.close()
				drawRange = 0
				end, function(data4, menu4)
					drawRange = data4.current.value
				end)
			end, function(data, menu)
				menu.close()
			end)
		else
			Notify(Config.Strings.noPerms)
		end
	end)
end, false)

RegisterCommand(Config.Creation.Commands.AddParking, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local head = GetEntityHeading(ped)
	local dis = 1000
	local elements = {}
	for k,v in pairs(Houses) do
		dis = #(pos - v.door)
		if dis <= v.draw then
			table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
		end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_address',
		{
			title = Config.Strings.clstAdd,
			align = Config.MenuAlign,
			elements = elements
		},function(data, menu)
			pos = GetEntityCoords(ped)
			vec = vector3(data.current.pos.x, data.current.pos.y, data.current.pos.z)
			dis = #(pos - vec)
			if dis > data.current.draw then
				Notify(Config.Strings.uTooFar)
			else
				if Config.Parking.ScriptParking ~= false then
					local tooClose = IsParkingTooClose(pos)
					if not tooClose then
						TriggerServerEvent('CompleteHousing:createParking', data.current.value, doRound(pos.x, 2), doRound(pos.y, 2), doRound(pos.z, 2) - 1.0)
					else
						Notify(Config.Strings.prk2Cls)
					end
				end
			end
		end, function(data, menu)
		menu.close()
	end)
end)

RegisterCommand(Config.Creation.Commands.DeleteHouse, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local dis = 1000
	local elements = {}
	for k,v in pairs(Houses) do
		dis = #(pos - v.door)
		if dis <= v.draw then
			table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
		end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_address',
	{
		title = Config.Strings.clstAdd,
		align = Config.MenuAlign,
		elements = elements
	},function(data, menu)
		local elements2 = {{label = Config.Strings.confTxt, value = 'yes'},{label = Config.Strings.decText, value = 'no'}}
		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'confirm_delete',
		{
			title = 'Delete '..data.current.value,
			align = Config.MenuAlign,
			elements = elements2
		}, function(data2, menu2)
			if data2.current.value == 'yes' then
				ESX.UI.Menu.CloseAll()
				TriggerServerEvent('CompleteHousing:deleteHome', data.current.value)
			else
				menu2.close()
			end
		end, function(data2, menu2)
			menu2.close()
		end)
	end, function(data, menu)
		menu.close()
	end)
end)

RegisterCommand(Config.Creation.Commands.DeleteParking, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local house, parkingSpot
	local elements = {{label = Config.Strings.confTxt, value = 'yes'},{label = Config.Strings.decText, value = 'no'}}
	for k,v in pairs(Houses) do
		for i = 1,#v.parkings do
			local vec = vector3(v.parkings[i].x, v.parkings[i].y, v.parkings[i].z)
			local dis = #(vec - pos)
			if dis <= 2.5 then
				house = v.id
				parkingSpot = vec
			end
		end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'confirm_delete',
	{
		title = Config.Strings.delPark,
		align = Config.MenuAlign,
		elements = elements
	}, function(data, menu)
		if data.current.value == 'yes' then
			ESX.UI.Menu.CloseAll()
			if house ~= nil then
				TriggerServerEvent('CompleteHousing:deleteParking', house, parkingSpot.x, parkingSpot.y, parkingSpot.z)
			end
		else
			menu.close()
		end
	end, function(data, menu)
		menu.close()
	end)
end)

RegisterCommand(Config.Creation.Commands.AddDoor, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local dis = 1000
	local elements = {}
	for k,v in pairs(Houses) do
		dis = #(pos - v.door)
		if dis <= v.draw then
			table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
		end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_address',
	{
		title = Config.Strings.clstAdd,
		align = Config.MenuAlign,
		elements = elements
	},function(data, menu)
		pos = GetEntityCoords(ped)
		vec = vector3(data.current.pos.x, data.current.pos.y, data.current.pos.z)
		dis = #(pos - vec)
		if dis > data.current.draw then
			Notify(Config.Strings.uTooFar)
		else
			local door, doorDis
			if Config.ESXLevel ~= 3 then
				door, doorDis = ESX.Game.GetClosestObject(nil, pos)
			else
				door, doorDis = ESX.Game.GetClosestObject(pos)
			end
			if doorDis > 1.0 then
				Notify(Config.Strings.getClsr)
			elseif doorDis < 0.5 then
				Notify('Too close, may touch door, no no square zone')
			else
				if DoesEntityExist(door) then
					local velo = GetEntityVelocity(door)
					if velo.x == 0.0 and velo.y == 0.0 and velo.z == 0.0 then
						local doorPos, rotation, propHash = GetEntityCoords(door), GetEntityHeading(door), GetEntityModel(door)
						TriggerServerEvent('CompleteHousing:addDoorToHome', data.current.value, doorPos.x, doorPos.y, doorPos.z, rotation, propHash)
					else
						Notify('The door must stop swingin itself before adding')
					end
				else
					Notify(Config.Strings.dorNtFd)
				end
			end
		end
	end, function(data, menu)
		menu.close()
	end)
end)

RegisterCommand(Config.Creation.Commands.AddGarage, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local dis = 1000
	local elements = {}
	for k,v in pairs(Houses) do
		dis = #(pos - v.door)
		if dis <= v.draw then
			table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
		end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_address',
	{
		title = Config.Strings.clstAdd,
		align = Config.MenuAlign,
		elements = elements
	},function(data, menu)
		pos = GetEntityCoords(ped)
		vec = vector3(data.current.pos.x, data.current.pos.y, data.current.pos.z)
		dis = #(pos - vec)
		if dis > data.current.draw then
			Notify(Config.Strings.uTooFar)
		else
			local door, doorDis
			if Config.ESXLevel ~= 3 then
				door, doorDis = ESX.Game.GetClosestObject(nil, pos)
			else
				door, doorDis = ESX.Game.GetClosestObject(pos)
			end
			if doorDis > 2.5 then
				Notify(Config.Strings.getClsr)
			else
				if DoesEntityExist(door) then
					local doorPos, rotation, propHash, draw = GetEntityCoords(door), GetEntityHeading(door), GetEntityModel(door)
					menu.close()
					local elms = {}
					for i = 1,#Config.LandSize do
						table.insert(elms, {label = Config.LandSize[i], value = Config.LandSize[i]})
					end
					drawRange = 5
					Citizen.CreateThread(function()
						while drawRange > 0 do
							Citizen.Wait(5)
							DrawMarker(2, GetOffsetFromEntityInWorldCoords(ped, 0.0, (drawRange * 1.0), 0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 3.0, 255, 0, 0, 255, true, true, 2, 0, 0, 0, 0)
						end
					end)
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'set_draw',
					{
						title = Config.Strings.grgODis,
						align = Config.MenuAlign,
						elements = elms
					}, function(data2, menu2)
						draw = data2.current.value * 1.0
						drawRange = 0
						menu2.close()
						TriggerServerEvent('CompleteHousing:addGarageToHome', data.current.value, doorPos.x, doorPos.y, doorPos.z, propHash, draw)
					end, function(data2, menu2)
						menu2.close()
						drawRange = 0
					end, function(data2, menu2)
						drawRange = data2.current.value
					end)
				else
					Notify(Config.Strings.dorNtFd)
				end
			end
		end
	end, function(data, menu)
		menu.close()
	end)
end)

RegisterCommand(Config.Creation.Commands.DeleteDoor, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local dis = 1000
	local elements = {}
	for k,v in pairs(Houses) do
		dis = #(pos - v.door)
		if dis <= v.draw then
			table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
		end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_address',
	{
		title = Config.Strings.clstAdd,
		align = Config.MenuAlign,
		elements = elements
	},function(data, menu)
		pos = GetEntityCoords(ped)
		vec = vector3(data.current.pos.x, data.current.pos.y, data.current.pos.z)
		dis = #(pos - vec)
		if dis > data.current.draw then
			Notify(Config.Strings.uTooFar)
		else
			local door, doorDis
			if Config.ESXLevel ~= 3 then
				door, doorDis = ESX.Game.GetClosestObject(nil, pos)
			else
				door, doorDis = ESX.Game.GetClosestObject(pos)
			end
			if doorDis > 2.5 then
				Notify(Config.Strings.getClsr)
			else
				if DoesEntityExist(door) then
					local doorPos, propHash = GetEntityCoords(door), GetEntityModel(door)
					TriggerServerEvent('CompleteHousing:removeDoorFromHome', data.current.value, doorPos.x, doorPos.y, doorPos.z, propHash)
				else
					Notify(Config.Strings.dorNtFd)
				end
			end
		end
	end, function(data, menu)
		menu.close()
	end)
end)

RegisterCommand(Config.Creation.Commands.SetStorage, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local dis = 1000
	local elements = {}
	for k,v in pairs(Houses) do
		if SpawnedHome[1] == nil then
			dis = #(pos - v.door)
			if dis <= v.draw then
				table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
			end
		end
		if SpawnedHome[1] ~= nil then
			if v.id == currentHouseID then
				table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
			end
		end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_address',
		{
			title = Config.Strings.clstAdd,
			align = Config.MenuAlign,
			elements = elements
		},function(data, menu)
			pos = GetEntityCoords(ped)
			vec = vector3(data.current.pos.x, data.current.pos.y, data.current.pos.z)
			dis = #(pos - vec)
			if SpawnedHome[1] == nil and dis > data.current.draw then
				Notify(Config.Strings.uTooFar)
			else
				if SpawnedHome[1] ~= nil then
					local home = SpawnedHome[1]
					local offset = GetOffsetFromEntityGivenWorldCoords(home, pos)
					pos = vector3(offset.x, offset.y, offset.z)
					TriggerServerEvent('CompleteHousing:setHomeStorage', data.current.value, doRound(pos.x, 2), doRound(pos.y, 2), doRound(pos.z, 2) - 1.0, true)
				else
					TriggerServerEvent('CompleteHousing:setHomeStorage', data.current.value, doRound(pos.x, 2), doRound(pos.y, 2), doRound(pos.z, 2) - 1.0, true)
				end
			end
		end, function(data, menu)
		menu.close()
	end)
end)

RegisterCommand(Config.Creation.Commands.SetWardrobe, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local dis = 1000
	local elements = {}
	for k,v in pairs(Houses) do
		if SpawnedHome[1] == nil then
			dis = #(pos - v.door)
			if dis <= v.draw then
				table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
			end
		end
		if SpawnedHome[1] ~= nil then
			if v.id == currentHouseID then
				table.insert(elements, {label = k, value = k, pos = {x = v.door.x, y = v.door.y, z = v.door.z}, draw = v.draw})
			end
		end
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'choose_address',
		{
			title = Config.Strings.clstAdd,
			align = Config.MenuAlign,
			elements = elements
		},function(data, menu)
			pos = GetEntityCoords(ped)
			vec = vector3(data.current.pos.x, data.current.pos.y, data.current.pos.z)
			dis = #(pos - vec)
			if SpawnedHome[1] == nil and dis > data.current.draw then
				Notify(Config.Strings.uTooFar)
			else
				if SpawnedHome[1] ~= nil then
					local home = SpawnedHome[1]
					local offset = GetOffsetFromEntityGivenWorldCoords(home, pos)
					pos = vector3(offset.x, offset.y, offset.z)
					TriggerServerEvent('CompleteHousing:setHomeStorage', data.current.value, doRound(pos.x, 2), doRound(pos.y, 2), doRound(pos.z, 2) - 1.0)
				else
					TriggerServerEvent('CompleteHousing:setHomeStorage', data.current.value, doRound(pos.x, 2), doRound(pos.y, 2), doRound(pos.z, 2) - 1.0)
				end
			end
		end, function(data, menu)
		menu.close()
	end)
end)

RegisterCommand(Config.Strings.doorLockCom, function(raw)
	while ESX == nil do Citizen.Wait(10) end
	if canUpdate then
		if Config.KeyOptions.Item.Require and Config.KeyOptions.Item.Name ~= '' then
			ESX.TriggerServerCallback('CompleteHousing:getHasItem', function(hasIt)
				if hasIt then
					TriggerServerEvent('CompleteHousing:updateDoor', currentZone, dor2Update)
				else
					Notify(Config.Strings.uNoKeys)
				end
			end, Config.KeyOptions.Item.Name)
		else
			TriggerServerEvent('CompleteHousing:updateDoor', currentZone, dor2Update)
		end
	else
		local pos = GetEntityCoords(PlayerPedId())
		for k,v in pairs(Houses) do
			for i = 1,#v.doors do
				if v.doors[i] ~= nil then
					if type(v.doors[i].pos) ~= 'vector3' then
						v.doors[i].pos = vector3(v.doors[i].pos.x, v.doors[i].pos.y, v.doors[i].pos.z)
					end
					local dis = #(pos - v.doors[i].pos)
					if dis <= 2.5 then
						ESX.TriggerServerCallback('CompleteHousing:canBreakIn', function(hasItems)
							if hasItems then
								StartBreakIn(v)
							else
								Notify(Config.Strings.noBreak)
							end
						end, v.owner)
					end
				end
			end
			for i = 1,#v.garages do
				if v.garages[i] ~= nil then
					if type(v.garages[i].pos) ~= 'vector3' then
						v.garages[i].pos = vector3(v.garages[i].pos.x, v.garages[i].pos.y, v.garages[i].pos.z)
					end
					local dis = #(pos - v.garages[i].pos)
					if dis <= v.garages[i].draw then
						ESX.TriggerServerCallback('CompleteHousing:canBreakIn', function(hasItems)
							if hasItems then
								StartBreakIn(v)
							else
								Notify(Config.Strings.noBreak)
							end
						end, v.owner)
					end
				end
			end
		end
	end
end)

RegisterKeyMapping(Config.Strings.doorLockCom, Config.Strings.keyHelp, 'keyboard', Config.Keys.UnLock)

-- FOLLOWING COMMANDS FOR DEVELOPMENT ONLY (SETTING NEW SHELL DOOR LOCATIONS AND PRE-FURNISHED HOME FURNITURE) --

RegisterCommand(Config.Creation.Commands.TestShell, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	ESX.TriggerServerCallback('CompleteHousing:canCreate', function(canCreate)
		if canCreate then
			local ped = PlayerPedId()
			local pos = GetEntityCoords(ped)
			returnPos = pos
			local model = GetHashKey(args[1])
			if IsModelInCdimage(model) then
				if not HasModelLoaded(model) then
					ticks[model] = 0
					while not HasModelLoaded(model) do
						ESX.ShowHelpNotification('Requesting model, please wait')
						DisableAllControlActions(0)
						Citizen.Wait(10)
						RequestModel(model)
						ticks[model] = ticks[model] + 1
						if ticks[model] >= Config.ModelWaitTicks then
							ticks[model] = 0
							ESX.ShowHelpNotification('Model '..args[1]..' failed to load, found in server image, please attempt re-logging to solve')
							return
						end
					end
				end
				if HasModelLoaded(model) then
					local x, y, z = pos.x, pos.y, pos.z - 20
					local height = GetWaterHeight(x,y,z)
					local spot
					if height == false then
						spot = vector3(x, y, z)
					else
						spot = GetSafeSpot()
					end
					local spot = vector3(x, y, z)
					local home = CreateObjectNoOffset(model, spot, true, false, false)
					if DoesEntityExist(home) then
						FreezeEntityPosition(home, true)
						SpawnedHome = {}
						table.insert(SpawnedHome, home)
						DoScreenFadeOut(100)
						while not IsScreenFadedOut() do
							Citizen.Wait(1)
						end
						SetEntityCoords(ped, spot)
						Citizen.Wait(1000)
						FreezeEntityPosition(ped, true)
						while not HasCollisionLoadedAroundEntity(ped) do
							Citizen.Wait(1)
						end
						DoScreenFadeIn(100)
						FreezeEntityPosition(ped, false)
					else
						Notify(Config.Strings.wntRong)
					end
				end
			else
				Notify(Config.Strings.modNtFd)
			end
		else
			Notify(Config.Strings.noPerms)
		end
	end)
end, false)

RegisterCommand(Config.Creation.Commands.ClearShell, function(raw)
	while ESX == nil do Citizen.Wait(10) end
	if returnPos ~= nil then
		ESX.TriggerServerCallback('CompleteHousing:canCreate', function(canCreate)
			if canCreate then
				local ped = PlayerPedId()
				local pos = GetEntityCoords(ped)
				SetEntityCoords(ped, returnPos)
				for i = 1,#SpawnedHome do
					DeleteEntity(SpawnedHome[i])
				end
				SpawnedHome = {}
				returnPos = nil
			else
				Notify(Config.Strings.noPerms)
			end
		end)
	else
		Notify(Config.Strings.aftrTst)
	end
end, false)

RegisterCommand(Config.Creation.Commands.Offset, function(raw)
	while ESX == nil do Citizen.Wait(10) end
	if SpawnedHome[1] ~= nil then
		ESX.TriggerServerCallback('CompleteHousing:canCreate', function(canCreate)
			if canCreate then
				local ped = PlayerPedId()
				local pos = GetEntityCoords(ped)
				local home = SpawnedHome[1]
				local offset = GetOffsetFromEntityGivenWorldCoords(home, pos)
				local vec = vector3(offset.x, offset.y, offset.z - 1.0)
				print(vec)
			else
				Notify(Config.Strings.noPerms)
			end
		end)
	else
		Notify(Config.Strings.noShell)
	end
end)

RegisterCommand(Config.Creation.Commands.SpawnProp, function(raw, args)
	while ESX == nil do Citizen.Wait(10) end
	ESX.TriggerServerCallback('CompleteHousing:canCreate', function(canCreate)
		if canCreate then
			local ped = PlayerPedId()
			local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
			local model = tonumber(args[1]) == nil and GetHashKey(args[1]) or tonumber(args[1])
			if IsModelInCdimage(model) then
				if not HasModelLoaded(model) then
					ticks[model] = 0
					while not HasModelLoaded(model) do
						ESX.ShowHelpNotification('Requesting model, please wait')
						DisableAllControlActions(0)
						Citizen.Wait(10)
						RequestModel(model)
						ticks[model] = ticks[model] + 1
						if ticks[model] >= Config.ModelWaitTicks then
							ticks[model] = 0
							ESX.ShowHelpNotification('Model '..data.current.value..' failed to load, found in server image, please attempt re-logging to solve')
							return
						end
					end
				end
				if HasModelLoaded(model) then
					local prop = CreateObjectNoOffset(model, pos, false, false, false)
					SetEntityHeading(prop, 0.0)
					Citizen.Wait(10000)
					DeleteEntity(prop)
					SetModelAsNoLongerNeeded(model)
				end
			else
				Notify(Config.Strings.modNtFd)
			end
		else
			Notify(Config.Strings.noPerms)
		end
	end)
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function()
	while ESX == nil do Citizen.Wait(10) end
	PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('CompleteHousing:setPlayerInHome')