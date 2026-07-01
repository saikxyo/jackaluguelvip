local QBCore = exports['qb-core']:GetCoreObject()

local function DebugPrint(message)
    if Config.Debug then
        print('^3[VIP CAR RENTAL - SERVER DEBUG]^7 ' .. message)
    end
end

local function DebugError(message)
    if Config.Debug then
        print('^1[VIP CAR RENTAL - SERVER ERROR]^7 ' .. message)
    end
end

local function SendWebhook(title, message, color)
    if not Config.Webhook.enabled or Config.Webhook.url == '' then return end

    local embed = { {
        ['title'] = title,
        ['description'] = message,
        ['color'] = color,
        ['footer'] = { ['text'] = os.date('%d/%m/%Y %H:%M:%S') }
    } }

    PerformHttpRequest(Config.Webhook.url, function(err, text, headers) end, 'POST', json.encode({
        username = 'VIP Car Rental',
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

local function GeneratePlate(attempts)
    attempts = attempts or 0

    -- Limite de tentativas para evitar recursão infinita
    if attempts > 100 then
        DebugError('Limite de tentativas de geração de placa atingido!')
        return 'VIP' .. math.random(10000, 99999) -- Placa de emergência
    end

    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''

    for _ = 1, 8 do
        local randomIndex = math.random(1, #chars)
        plate = plate .. chars:sub(randomIndex, randomIndex)
    end

    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE plate = ?', { plate })
    if exists and exists > 0 then
        return GeneratePlate(attempts + 1)
    end

    return plate
end

local function GetPlayerRentals(citizenid)
    DebugPrint('Buscando aluguéis de: ' .. citizenid)

    local result = MySQL.query.await([[
        SELECT * FROM player_vehicles
        WHERE citizenid = ?
        AND expires_at IS NOT NULL
        AND expires_at > UNIX_TIMESTAMP()
    ]], { citizenid })

    DebugPrint('Aluguéis encontrados: ' .. #result)
    return result or {}
end

local function CreateRental(Player, vehicleData, plate, totalPaid)
    local citizenid = Player.PlayerData.citizenid
    local license = Player.PlayerData.license
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local source = Player.PlayerData.source

    DebugPrint('=== CRIANDO ALUGUEL ===')
    DebugPrint('Citizen: ' .. citizenid)
    DebugPrint('License: ' .. license)
    DebugPrint('Veículo: ' .. vehicleData.name)
    DebugPrint('Plate: ' .. plate)
    DebugPrint('Source: ' .. source)

    local rentalDuration = 30 * 86400
    if Config.TestMode then
        rentalDuration = Config.TestTime
    end
    local expiresAt = os.time() + rentalDuration

    local vehicleId = MySQL.insert.await([[
        INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state, expires_at)
        VALUES (?, ?, ?, ?, '{}', ?, 'pillboxgarage', 0, ?)
    ]], {
        license,
        citizenid,
        vehicleData.model,
        vehicleData.hash,
        plate,
        expiresAt
    })

    if vehicleId then
        DebugPrint('✅ Veículo inserido em player_vehicles com ID: ' .. vehicleId)

        -- Tenta inserir na tabela de controle (opcional)
        local success, err = pcall(function()
            MySQL.insert.await([[
                INSERT INTO vip_car_rentals (citizenid, vehicle_model, vehicle_name, plate, total_paid)
                VALUES (?, ?, ?, ?, ?)
            ]], { citizenid, vehicleData.model, vehicleData.name, plate, totalPaid })
        end)

        if success then
            DebugPrint('✅ Registro criado em vip_car_rentals')
        else
            DebugPrint('⚠️ Tabela vip_car_rentals não existe ou erro: ' .. tostring(err))
        end

        -- SPAWN AUTOMÁTICO DO VEÍCULO COM CHAVES (se habilitado)
        if Config.AutoSpawnEnabled then
            DebugPrint('🚗 Triggering spawn automático do veículo...')
            TriggerClientEvent('vip_car_rental:client:spawnVehicle', source, vehicleData.model, plate, vehicleData.name)
        else
            DebugPrint('⚠️ Spawn automático desabilitado - veículo disponível na garagem')
        end

        local deliveryInfo = Config.AutoSpawnEnabled and '**🚗 Veículo entregue automaticamente!**' or
        '**📦 Veículo disponível na garagem**'

        SendWebhook(
            '🚗 Novo Aluguel VIP',
            '**Jogador:** ' .. playerName .. '\n' ..
            '**Citizen ID:** ' .. citizenid .. '\n' ..
            '**Veículo:** ' .. vehicleData.name .. '\n' ..
            '**Placa:** ' .. plate .. '\n' ..
            '**Período:** 30 dias fixos\n' ..
            '**Valor Pago:** ' .. totalPaid .. ' ' .. Config.PaymentItem .. '\n' ..
            '**Expira em:** ' .. os.date('%d/%m/%Y %H:%M', expiresAt) .. '\n' ..
            deliveryInfo,
            Config.Webhook.colors.rental
        )

        return true
    else
        DebugError('❌ Falha ao inserir veículo em player_vehicles')
        return false
    end
end

local function RemoveExpiredRentals()
    DebugPrint('🔄 Verificando aluguéis expirados...')

    MySQL.query([[
        SELECT id, vehicle, plate, citizenid FROM player_vehicles
        WHERE expires_at IS NOT NULL
        AND expires_at < UNIX_TIMESTAMP()
    ]], {}, function(expired)
        if expired and #expired > 0 then
            DebugPrint('🗑️ Encontrados ' .. #expired .. ' veículos expirados')
            
            local ids = {}
            for _, vehicle in ipairs(expired) do
                table.insert(ids, vehicle.id)
                DebugPrint('Marcado para remoção: ' .. vehicle.vehicle .. ' | Placa: ' .. vehicle.plate)
            end

            -- Deleção em lote (Batch delete)
            MySQL.query('DELETE FROM player_vehicles WHERE id IN (?)', { ids }, function()
                DebugPrint('✅ Remoção concluída com sucesso')
                
                -- Notificar jogadores online
                for _, veh in ipairs(expired) do
                    local Player = QBCore.Functions.GetPlayerByCitizenId(veh.citizenid)
                    if Player then
                        local vehicleName = veh.vehicle -- Poderíamos buscar o nome real se necessário
                        local vehicleData = VehicleData.GetVehicle(veh.vehicle)
                        if vehicleData then vehicleName = vehicleData.name end
                        
                        TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 
                            string.format('O aluguel do seu %s expirou e ele foi removido da garagem!', vehicleName), 
                            'error', 5000)
                    end
                end

                SendWebhook(
                    '⏰ Aluguéis Expirados',
                    'Foram removidos **' .. #expired .. '** veículos cujo período de aluguel expirou.',
                    Config.Webhook.colors.expired
                )
            end)
        else
            DebugPrint('✅ Nenhum aluguel expirado')
        end
    end)
end

local function CalculateDaysRemaining(expiresAt)
    local now = os.time()
    local diff = expiresAt - now
    if Config.TestMode then
        return math.max(0, diff) -- Retorna segundos em modo teste
    end
    return math.max(0, math.floor(diff / 86400))
end

local function FormatDate(timestamp)
    return os.date('%d/%m/%Y', timestamp)
end

-- ========================================
-- RATE LIMITING PARA CALLBACKS
-- ========================================

local playerCooldowns = {}
local COOLDOWN_TIME = 2000 -- 2 segundos entre requests

local function CheckCooldown(source, action)
    local playerId = tostring(source)
    local now = GetGameTimer()

    if not playerCooldowns[playerId] then
        playerCooldowns[playerId] = {}
    end

    local lastRequest = playerCooldowns[playerId][action] or 0
    if (now - lastRequest) < COOLDOWN_TIME then
        DebugPrint('Rate limit atingido para jogador ' .. playerId .. ' na ação ' .. action)
        return false
    end

    playerCooldowns[playerId][action] = now
    return true
end

QBCore.Functions.CreateCallback('vip_car_rental:server:GetRentalData', function(source, cb)
    -- Rate limiting
    if not CheckCooldown(source, 'GetRentalData') then
        cb(nil)
        return
    end

    DebugPrint('=== CALLBACK GetRentalData CHAMADO ===')
    DebugPrint('Source: ' .. tostring(source))

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        DebugError('Jogador não encontrado')
        cb(nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid
    DebugPrint('Citizen ID: ' .. tostring(citizenid))

    -- REMOVIDO: RemoveExpiredRentals() - Não é necessário rodar isso toda vez que um jogador abre o menu.
    -- O thread de 10 minutos e o boot inicial já são suficientes.

    local rentals = GetPlayerRentals(citizenid)
    DebugPrint('Total de aluguéis ativos: ' .. #rentals)

    local availableVehicles = {}
    for model, vehicleData in pairs(VehicleData.Vehicles) do
        local isRented = false

        for _, rental in ipairs(rentals) do
            if rental.vehicle == model then
                isRented = true
                break
            end
        end

        table.insert(availableVehicles, {
            model = vehicleData.model,
            name = vehicleData.name,
            brand = vehicleData.brand,
            price = vehicleData.price,
            stock = vehicleData.stock,
            category = vehicleData.category,
            isRented = isRented
        })
    end

    local rentedVehicles = {}
    for _, rental in ipairs(rentals) do
        local vehicleData = VehicleData.GetVehicle(rental.vehicle)
        if vehicleData then
            local daysRemaining = CalculateDaysRemaining(rental.expires_at)

            table.insert(rentedVehicles, {
                plate = rental.plate,
                model = rental.vehicle,
                name = vehicleData.name,
                brand = vehicleData.brand,
                garage = rental.garage or 'pillboxgarage',
                expiresAt = rental.expires_at,
                daysRemaining = daysRemaining,
                pricePerDay = vehicleData.price,
                rentalDate = FormatDate(rental.expires_at - (30 * 86400)),
                expiryDate = FormatDate(rental.expires_at)
            })
        end
    end

    local playerCoins = 0
    local hasItem = exports.ox_inventory:GetItem(source, Config.PaymentItem, nil, true)

    if hasItem then
        playerCoins = hasItem
        DebugPrint('Player coins: ' .. playerCoins)
    end

    DebugPrint('=== RESPOSTA ===')
    DebugPrint('Disponíveis: ' .. #availableVehicles .. ' | Alugados: ' .. #rentedVehicles .. ' | Coins: ' .. playerCoins)

    -- Debug detalhado dos veículos alugados
    if #rentedVehicles > 0 then
        DebugPrint('=== VEÍCULOS ALUGADOS ===')
        for i, rental in ipairs(rentedVehicles) do
            DebugPrint(i .. '. ' .. rental.name .. ' (' .. rental.model .. ')')
            DebugPrint('   Placa: ' .. rental.plate)
            DebugPrint('   Dias restantes: ' .. rental.daysRemaining)
            DebugPrint('   Alugado em: ' .. rental.rentalDate)
            DebugPrint('   Expira em: ' .. rental.expiryDate)
        end
        DebugPrint('========================')
    else
        DebugPrint('⚠️ Nenhum veículo alugado encontrado')
    end

    cb({
        availableVehicles = availableVehicles,
        rentedVehicles = rentedVehicles,
        playerCoins = playerCoins,
        paymentItem = Config.PaymentItem
    })
end)

QBCore.Functions.CreateCallback('vip_car_rental:server:RentVehicle', function(source, cb, model)
    -- Rate limiting
    if not CheckCooldown(source, 'RentVehicle') then
        cb(false, 'Aguarde antes de tentar novamente!')
        return
    end

    DebugPrint('=== CALLBACK RentVehicle ===')

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Erro ao processar aluguel!')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local vehicleData = VehicleData.GetVehicle(model)

    DebugPrint('Jogador: ' .. citizenid)
    DebugPrint('Veículo: ' .. model)

    if not vehicleData then
        cb(false, Config.Messages.vehicle_not_found)
        return
    end

    local rentals = GetPlayerRentals(citizenid)
    for _, rental in ipairs(rentals) do
        if rental.vehicle == model then
            cb(false, Config.Messages.already_rented)
            return
        end
    end

    local totalPrice = vehicleData.price * 30
    DebugPrint('Preço total (30 dias): ' .. totalPrice)

    local hasCoins = exports.ox_inventory:GetItem(source, Config.PaymentItem, nil, true) or 0

    if not hasCoins or hasCoins < totalPrice then
        DebugError('Coins insuficientes! Tem: ' .. (hasCoins or 0) .. ' | Precisa: ' .. totalPrice)
        cb(false, string.format(Config.Messages.insufficient_funds, Config.PaymentItem, totalPrice))
        return
    end

    local removed = exports.ox_inventory:RemoveItem(source, Config.PaymentItem, totalPrice)

    if not removed then
        DebugError('Erro ao remover coins!')
        cb(false, 'Erro ao processar pagamento!')
        return
    end

    DebugPrint('✅ Pagamento processado: ' .. totalPrice)

    local plate = GeneratePlate()
    DebugPrint('Placa gerada: ' .. plate)

    local success = CreateRental(Player, vehicleData, plate, totalPrice)

    if success then
        DebugPrint('✅ Aluguel criado com sucesso!')
        cb(true, string.format(Config.Messages.rental_success, vehicleData.name))
    else
        DebugError('❌ Falha ao criar aluguel')
        exports.ox_inventory:AddItem(source, Config.PaymentItem, totalPrice)
        cb(false, 'Erro ao processar aluguel!')
    end
end)

QBCore.Functions.CreateCallback('vip_car_rental:server:RenewVehicle', function(source, cb, model, days)
    -- Rate limiting
    if not CheckCooldown(source, 'RenewVehicle') then
        cb(false, 'Aguarde antes de tentar novamente!')
        return
    end

    DebugPrint('=== CALLBACK RenewVehicle ===')

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Erro ao processar renovação!')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local vehicleData = VehicleData.GetVehicle(model)

    DebugPrint('Jogador: ' .. citizenid)
    DebugPrint('Veículo: ' .. model)
    DebugPrint('Dias: ' .. tostring(days))

    if not vehicleData then
        cb(false, Config.Messages.vehicle_not_found)
        return
    end

    -- Verifica se o jogador tem o veículo alugado
    local rental = MySQL.query.await([[
        SELECT * FROM player_vehicles
        WHERE citizenid = ?
        AND vehicle = ?
        AND expires_at IS NOT NULL
        AND expires_at > UNIX_TIMESTAMP()
    ]], { citizenid, model })

    if not rental or #rental == 0 then
        cb(false, 'Você não possui este veículo alugado!')
        return
    end

    -- Calcula o preço (sempre 30 dias fixos)
    local renewalDays = 30
    local totalPrice = vehicleData.price * renewalDays

    -- Aplica desconto se configurado
    if Config.RenewalDiscount > 0 then
        totalPrice = math.floor(totalPrice * (1 - Config.RenewalDiscount / 100))
        DebugPrint('Desconto aplicado: ' .. Config.RenewalDiscount .. '%')
    end

    DebugPrint('Preço total renovação (30 dias): ' .. totalPrice)

    local hasCoins = exports.ox_inventory:GetItem(source, Config.PaymentItem, nil, true) or 0

    if not hasCoins or hasCoins < totalPrice then
        DebugError('Coins insuficientes! Tem: ' .. (hasCoins or 0) .. ' | Precisa: ' .. totalPrice)
        cb(false, string.format(Config.Messages.insufficient_funds, Config.PaymentItem, totalPrice))
        return
    end

    local removed = exports.ox_inventory:RemoveItem(source, Config.PaymentItem, totalPrice)

    if not removed then
        DebugError('Erro ao remover coins!')
        cb(false, 'Erro ao processar pagamento!')
        return
    end

    DebugPrint('✅ Pagamento processado: ' .. totalPrice)

    -- Estende o prazo por mais 30 dias
    local currentExpiry = rental[1].expires_at
    local newExpiry = currentExpiry + (renewalDays * 86400)

    local updated = MySQL.update.await([[
        UPDATE player_vehicles
        SET expires_at = ?
        WHERE citizenid = ? AND vehicle = ? AND expires_at IS NOT NULL
    ]], { newExpiry, citizenid, model })

    if updated then
        DebugPrint('✅ Renovação processada com sucesso!')

        local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

        SendWebhook(
            '🔄 Renovação de Aluguel',
            '**Jogador:** ' .. playerName .. '\n' ..
            '**Citizen ID:** ' .. citizenid .. '\n' ..
            '**Veículo:** ' .. vehicleData.name .. '\n' ..
            '**Período:** ' .. renewalDays .. ' dias\n' ..
            '**Valor Pago:** ' .. totalPrice .. ' ' .. Config.PaymentItem .. '\n' ..
            '**Nova Expiração:** ' .. os.date('%d/%m/%Y %H:%M', newExpiry),
            Config.Webhook.colors.renewal
        )

        cb(true, string.format(Config.Messages.renewal_success, vehicleData.name))
    else
        DebugError('❌ Falha ao renovar aluguel')
        exports.ox_inventory:AddItem(source, Config.PaymentItem, totalPrice)
        cb(false, 'Erro ao processar renovação!')
    end
end)

QBCore.Functions.CreateCallback('vip_car_rental:server:CanSpawnVehicle', function(source, cb, plate)
    DebugPrint('=== CALLBACK CanSpawnVehicle ===')
    DebugPrint('Placa: ' .. tostring(plate))

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    local vehicle = MySQL.query.await([[
        SELECT * FROM player_vehicles
        WHERE citizenid = ?
        AND plate = ?
        AND expires_at IS NOT NULL
        AND expires_at > UNIX_TIMESTAMP()
    ]], { citizenid, plate })

    if not vehicle or #vehicle == 0 then
        cb(false, nil)
        return
    end

    local veh = vehicle[1]
    local vehicleData = VehicleData.GetVehicle(veh.vehicle)

    if not vehicleData then
        cb(false, nil)
        return
    end

    DebugPrint('✅ Veículo válido para spawn')
    cb(true, vehicleData, veh.plate)
end)

CreateThread(function()
    while true do
        local waitTime = 600000 -- 10 minutos padrão
        if Config.TestMode then
            waitTime = 5000 -- 5 segundos em modo teste
        end
        Wait(waitTime)
        RemoveExpiredRentals()
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- AUMENTADO: Delay de 20-40 segundos para não pesar no boot
        local startDelay = math.random(20000, 40000)
        DebugPrint('Startup agendado para daqui a ' .. (startDelay/1000) .. 's')
        
        Wait(startDelay)
        DebugPrint('=================================')
        DebugPrint('VIP CAR RENTAL INICIADO')
        DebugPrint('=================================')
        RemoveExpiredRentals()
    end
end)
