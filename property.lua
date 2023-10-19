local currentHouse, currentExdt

local MailboxOptions = {
  AllowTheft = false,
}

RegisterNetEvent("esx_inventoryhud:openPropertyInventory")
AddEventHandler("esx_inventoryhud:openPropertyInventory", function(id, exdt)
	currentHouse = id
	currentExdt = exdt
	ESX.TriggerServerCallback('SSCompleteHousing:getInv', function(data)
		setPropertyInventory(data)
		openPropertyInventory()
	end, 'property', id, exdt)
end)

function setPropertyInventory(data)
	SendNUIMessage(
        {
            action = 'setInfoText',
            text = currentHouse
        }
    )
    items = {}

    if data.blackMoney ~= nil and data.blackMoney > 0 then
        blackData = {
            label = _U('black_money'),
            count = data.blackMoney,
            type = 'item_account',
            name = 'black_money',
            usable = false,
            rare = false,
            limit = -1,
            canRemove = false
        }
        table.insert(items, blackData)
    end
	
	if data.cash ~= nil and data.cash > 0 then
        cashData = {
            label = 'cash',
            count = data.cash,
            type = 'item_account',
            name = 'money',
            usable = false,
            rare = false,
            limit = -1,
            canRemove = false
        }
        table.insert(items, cashData)
    end

    if data.items ~= nil then
      for key, value in pairs(data.items) do
        data.items[key][1].name = key
        data.items[key][1].label = value[1].label
        data.items[key][1].type = 'item_standard'
        data.items[key][1].usable = false
        data.items[key][1].rare = false
        data.items[key][1].limit = -1
        data.items[key][1].canRemove = false
        table.insert(items, data.items[key][1])
      end
    end

    if data.weapons ~= nil then
      for key, value in pairs(data.weapons) do
        for i = 1,#data.weapons[key] do
          if data.weapons[key][i] ~= 'WEAPON_UNARMED' then
            table.insert(
              items,
              {
                label = data.weapons[key][i].label,
                count = data.weapons[key][i].count,
                limit = -1,
                type = 'item_weapon',
                name = key,
                usable = false,
                rare = false,
                canRemove = false
              }
            )
          end
        end
      end
    end

    SendNUIMessage(
        {
            action = 'setSecondInventoryItems',
            itemList = items
        }
    )
end

function openPropertyInventory()
    loadPlayerInventory()
    isInInventory = true
	
    SendNUIMessage(
        {
            action = "display",
            type = "property"
        }
    )

    SetNuiFocus(true, true)
end

RegisterNUICallback('PutIntoProperty', function(data, cb)
	if IsPedSittingInAnyVehicle(PlayerPedId()) then
		return
	end
	if type(data.number) == 'number' and math.floor(data.number) == data.number then
		local count = tonumber(data.number)

		if data.item.type == 'item_weapon' then
			count = GetAmmoInPedWeapon(PlayerPedId(), GetHashKey(data.item.name))
		end
		if count == 0 then
			count = 1
		end
		TriggerServerEvent('SSCompleteHousing:putItem', 'property', currentHouse, data, count)
	end
	Wait(250)
	loadPlayerInventory()
	ESX.TriggerServerCallback('SSCompleteHousing:getInv', function(data)
		setPropertyInventory(data)
		openPropertyInventory()
	end, 'property', currentHouse)

	cb('ok')
end)

RegisterNUICallback('TakeFromProperty', function(data, cb)
  TriggerEvent('SSCompleteHousing:getCurrentHouse', function(house)
    if (currentExdt == 'mailbox' and not MailboxOptions.AllowTheft and house.owner ~= ESX.GetPlayerData().identifier) then
      ESX.ShowNotification('It is illegal to steal from mailboxes')
      cb('ok')
    else
      if IsPedSittingInAnyVehicle(PlayerPedId()) then
        return
      end
      
      if type(data.number) == 'number' and math.floor(data.number) == data.number then
        TriggerServerEvent('SSCompleteHousing:getItem', 'property', currentHouse, data, tonumber(data.number))
      end
      Wait(250)
      loadPlayerInventory()
      ESX.TriggerServerCallback('SSCompleteHousing:getInv', function(data)
        setPropertyInventory(data)
        openPropertyInventory()
      end, 'property', currentHouse)

      cb('ok')
    end
  end)
end)