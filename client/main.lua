local QBCore = exports['qb-core']:GetCoreObject()
local displayVehicles = {}
local isNuiOpen = false
local testDriveVehicle = nil
local isTestDriving = false
local staticInteractionPoints = {}
local currentMode = 'catalog'

-- ========================================
-- FUNÇÕES DE DEBUG
-- ========================================

local function DebugPrint(message)
    if Config.Debug then
        print('^3[VIP CAR RENTAL - CLIENT DEBUG]^7 ' .. message)
    end
end

local function DebugError(message)
    if Config.Debug then
        print('^1[VIP CAR RENTAL - ERROR]^7 ' .. message)
    end
end

-- ========================================
-- FUNÇÕES DE CONTROLE DE NUI
-- ========================================

local isClosingNui = false -- Proteção contra loop

local function CloseMenu()
    if not isNuiOpen then
        DebugPrint('Menu já estava fechado')
        return
    end

    if isClosingNui then
        DebugPrint('Fechamento já em andamento, ignorando...')
        return
    end

    isClosingNui = true
    DebugPrint('Iniciando fechamento do menu...')

    SetNuiFocus(false, false)
    isNuiOpen = false
    SendNUIMessage({
        action = 'closeMenu'
    })
    DebugPrint('Menu fechado!')

    -- Força limpeza de qualquer estado de NUI
    SetNuiFocusKeepInput(false)

    -- Libera o lock após um delay
    CreateThread(function()
        Wait(1000)
        isClosingNui = false
        DebugPrint('Lock de fechamento liberado')
    end)
end

-- Função de emergência para forçar fechamento de qualquer NUI
local function ForceCloseAllNUI()
    if isClosingNui then
        DebugPrint('Force close já em andamento, ignorando...')
        return
    end

    isClosingNui = true
    DebugPrint('🚨 FORÇA FECHAMENTO DE TODAS AS NUIs')

    -- Força fechamento independente do estado
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    isNuiOpen = false

    -- Envia APENAS uma mensagem de force close
    SendNUIMessage({
        action = 'forceClose'
    })

    DebugPrint('✅ Comando de força fechamento enviado')

    -- Libera o lock após um delay maior
    CreateThread(function()
        Wait(2000) -- 2 segundos para garantir que não haja loop
        isClosingNui = false
        DebugPrint('Lock de force close liberado')
    end)
end

-- ========================================
-- CONTROLE DE TECLAS (ESC PARA FECHAR NUI)
-- ========================================

-- ========================================
-- CONTROLE DE TECLAS (ESC PARA FECHAR NUI) - VERSÃO SIMPLIFICADA
-- ========================================

CreateThread(function()
    while true do
        Wait(100) -- Verifica a cada 100ms, mais eficiente

        -- Se a NUI estiver aberta
        if isNuiOpen and not isClosingNui then
            -- Desabilita controles padrão quando NUI está aberta
            DisableControlAction(0, 322, true) -- ESC
            DisableControlAction(0, 200, true) -- ESC alternativo

            -- Verifica se ESC foi pressionado
            if IsDisabledControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 200) then
                DebugPrint('ESC pressionado - Fechando menu normalmente')
                CloseMenu()
            end
        end
    end
end)

-- ========================================
-- FUNÇÕES DE NOTIFICAÇÃO
-- ========================================

local function Notify(message, type)
    if Config.NotificationType == 'qbcore' then
        QBCore.Functions.Notify(message, type)
    elseif Config.NotificationType == 'ox_lib' then
        if lib then
            lib.notify({
                title = 'Aluguel VIP',
                description = message,
                type = type
            })
        else
            -- Fallback para qbcore se ox_lib não estiver disponível
            QBCore.Functions.Notify(message, type)
        end
    end
end

-- ========================================
-- FUNÇÕES AUXILIARES
-- ========================================

-- Função para teleportar jogador de volta à concessionária
local function TeleportPlayerBack()
    if Config.TestDriveTeleportBack then
        local ped = PlayerPedId()
        local returnCoords = Config.TestDriveReturnLocation

        DebugPrint('Teleportando jogador de volta à concessionária...')
        SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, true)

        -- Garante que o jogador está no chão
        Wait(100)
        SetPedToRagdoll(ped, 100, 100, 0, false, false, false)

        DebugPrint('✅ Jogador teleportado para: ' .. returnCoords.x .. ', ' .. returnCoords.y .. ', ' .. returnCoords.z)
    end
end

-- ========================================
-- SPAWN DOS VEÍCULOS DE EXIBIÇÃO
-- ========================================

local function SpawnDisplayVehicles()
    DebugPrint('Iniciando spawn dos veículos de exibição...')

    -- Pega todos os modelos disponíveis
    local availableModels = {}
    for model, data in pairs(VehicleData.Vehicles) do
        table.insert(availableModels, model)
    end

    -- Embaralha a lista
    for i = #availableModels, 2, -1 do
        local j = math.random(i)
        availableModels[i], availableModels[j] = availableModels[j], availableModels[i]
    end

    -- Spawna 4 veículos aleatórios
    for i, spawnData in ipairs(Config.DisplayVehicles) do
        local modelToSpawn = availableModels[i] or spawnData.model
        local vehicleData = VehicleData.GetVehicle(modelToSpawn)

        if vehicleData and vehicleData.hash then
            DebugPrint('Spawnando ' .. vehicleData.name .. ' na posição ' .. i)

            -- CORREÇÃO: Validação e carregamento correto do modelo
            local modelHash = type(vehicleData.hash) == 'number' and vehicleData.hash or GetHashKey(vehicleData.model)

            -- Verifica se o modelo é válido
            if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
                DebugError('Modelo inválido: ' .. vehicleData.model .. ' (hash: ' .. tostring(modelHash) .. ')')
                goto continue
            end

            -- Carrega o modelo com timeout
            RequestModel(modelHash)
            local timeout = GetGameTimer() + 10000
            while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
                Wait(50)
            end

            if not HasModelLoaded(modelHash) then
                DebugError('Timeout ao carregar modelo: ' .. vehicleData.model)
                goto continue
            end

            local vehicle = CreateVehicle(
                modelHash,
                spawnData.coords.x,
                spawnData.coords.y,
                spawnData.coords.z,
                spawnData.coords.w,
                false,
                false
            )

            if not DoesEntityExist(vehicle) then
                DebugError('Falha ao criar veículo: ' .. vehicleData.model)
                SetModelAsNoLongerNeeded(modelHash)
                goto continue
            end

            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleDoorsLocked(vehicle, 2)
            SetVehicleEngineOn(vehicle, false, false, true)
            FreezeEntityPosition(vehicle, true)
            SetEntityInvincible(vehicle, true)
            SetModelAsNoLongerNeeded(modelHash)

            -- Adiciona ox_target
            exports.ox_target:addLocalEntity(vehicle, {
                {
                    name = 'vip_rental_' .. modelToSpawn,
                    label = 'Abrir Catálogo',
                    icon = 'fa-solid fa-car',
                    distance = Config.InteractionDistance,
                    onSelect = function()
                        OpenRentalMenu('mini')
                    end
                }
            })

            table.insert(displayVehicles, {
                vehicle = vehicle,
                model = modelToSpawn,
                coords = spawnData.coords
            })

            DebugPrint('Veículo ' .. vehicleData.name .. ' spawnado com sucesso!')

            ::continue::
        else
            DebugError('Dados do veículo não encontrados: ' .. tostring(modelToSpawn))
        end
    end

    DebugPrint('Spawn de veículos de exibição concluído! Total: ' .. #displayVehicles)
end

-- ========================================
-- REMOVER VEÍCULOS DE EXIBIÇÃO
-- ========================================

local function RemoveDisplayVehicles()
    DebugPrint('Removendo veículos de exibição...')

    for _, data in ipairs(displayVehicles) do
        if DoesEntityExist(data.vehicle) then
            exports.ox_target:removeLocalEntity(data.vehicle)
            DeleteEntity(data.vehicle)
        end
    end

    displayVehicles = {}
    DebugPrint('Veículos de exibição removidos!')
end

-- ========================================
-- CRIAR BLIP
-- ========================================

local function CreateBlip()
    if Config.Blip.enabled then
        local blip = AddBlipForCoord(Config.Blip.coords.x, Config.Blip.coords.y, Config.Blip.coords.z)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Blip.scale)
        SetBlipColour(blip, Config.Blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Blip.name)
        EndTextCommandSetBlipName(blip)

        DebugPrint('Blip criado no mapa!')
    end
end

-- ========================================
-- ABRIR MENU DE ALUGUEL
-- ========================================

function OpenRentalMenu(mode)
    mode = mode or 'catalog'
    if isNuiOpen and currentMode == mode then return end

    DebugPrint('Abrindo menu de aluguel no modo: ' .. mode)

    QBCore.Functions.TriggerCallback('vip_car_rental:server:GetRentalData', function(data)
        if data then
            SetNuiFocus(true, true)
            isNuiOpen = true
            currentMode = mode
            SendNUIMessage({
                action = 'openMenu',
                data = data,
                mode = mode
            })
            DebugPrint('Menu aberto com sucesso!')
        else
            DebugPrint('Erro ao obter dados do servidor!')
            Notify('Erro ao carregar dados!', 'error')
        end
    end)
end

-- ========================================
-- FECHAR MENU
-- ========================================

-- Função já definida acima, removendo duplicata

-- ========================================
-- SISTEMA DE EXIBIÇÃO DE VEÍCULOS
-- ========================================

local previewVehicle = nil
local previewTimer = nil

-- Função para limpar veículo de exibição anterior
local function ClearPreviewVehicle()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DebugPrint('Removendo veículo de exibição anterior')
        DeleteEntity(previewVehicle)
        previewVehicle = nil
    end

    if previewTimer then
        DebugPrint('Cancelando timer de exibição anterior')
        previewTimer = nil
    end
end

RegisterNUICallback('previewVehicle', function(data, cb)
    DebugPrint('Callback: previewVehicle chamado para modelo: ' .. tostring(data.model))

    if not Config.AllowVehiclePreview then
        DebugPrint('Exibição de veículos desabilitada')
        cb({ success = false, message = 'Exibição de veículos desabilitada' })
        return
    end

    local vehicleData = VehicleData.GetVehicle(data.model)
    if not vehicleData then
        DebugError('Veículo não encontrado: ' .. tostring(data.model))
        cb({ success = false, message = 'Veículo não encontrado!' })
        return
    end

    DebugPrint('Exibindo veículo: ' .. vehicleData.name)

    -- Remove veículo de exibição anterior se existir
    ClearPreviewVehicle()

    -- Verifica se o local de spawn está bloqueado
    local coords = Config.PreviewSpawnLocation
    if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.0) then
        DebugPrint('Local de exibição bloqueado')
        Notify('Local de exibição está bloqueado!', 'error')
        cb({ success = false, message = 'Local bloqueado!' })
        return
    end

    -- CORREÇÃO: Carregamento correto do modelo
    local modelHash = type(vehicleData.hash) == 'number' and vehicleData.hash or GetHashKey(vehicleData.model)

    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        DebugError('Modelo inválido: ' .. vehicleData.model)
        cb({ success = false, message = 'Modelo inválido!' })
        return
    end

    RequestModel(modelHash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not HasModelLoaded(modelHash) then
        DebugError('Timeout ao carregar modelo: ' .. vehicleData.model)
        cb({ success = false, message = 'Erro ao carregar veículo' })
        return
    end

    previewVehicle = CreateVehicle(
        modelHash,
        coords.x,
        coords.y,
        coords.z,
        coords.w,
        true,
        false
    )

    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(previewVehicle) then
        DebugError('Falha ao criar veículo de exibição')
        cb({ success = false, message = 'Erro ao criar veículo' })
        return
    end

    -- Configura o veículo de exibição
    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleNumberPlateText(previewVehicle, Config.PreviewPlate)
    SetVehicleDoorsLocked(previewVehicle, 2)   -- Trancado
    SetVehicleEngineOn(previewVehicle, false, false, true)
    FreezeEntityPosition(previewVehicle, true) -- Não pode ser movido
    SetEntityInvincible(previewVehicle, true)  -- Indestrutível

    -- Entrega chaves se configurado
    if Config.PreviewGiveKeys then
        DebugPrint('Entregando chaves do veículo de exibição: ' .. Config.PreviewPlate)
        TriggerEvent('vehiclekeys:client:SetOwner', Config.PreviewPlate)
    end

    -- Notifica o jogador
    Notify('Exibindo: ' .. vehicleData.name .. ' por ' .. Config.PreviewDuration .. ' segundos', 'info')
    DebugPrint('Veículo de exibição criado! ID: ' .. previewVehicle .. ' | Modelo: ' .. data.model)

    -- Inicia timer para remover o veículo
    previewTimer = GetGameTimer() + (Config.PreviewDuration * 1000)

    CreateThread(function()
        while previewTimer and GetGameTimer() < previewTimer do
            Wait(1000)
        end

        if previewVehicle and DoesEntityExist(previewVehicle) then
            DebugPrint('Tempo de exibição expirado, removendo veículo')

            -- Remove chaves se foram entregues
            if Config.PreviewGiveKeys then
                TriggerEvent('vehiclekeys:client:RemoveKeys', Config.PreviewPlate)
            end

            DeleteEntity(previewVehicle)
            previewVehicle = nil
            previewTimer = nil

            Notify('Exibição finalizada!', 'info')
            DebugPrint('Veículo de exibição removido automaticamente')
        end
    end)

    cb({ success = true })
end)

-- ========================================
-- CALLBACKS NUI
-- ========================================

RegisterNUICallback('closeMenu', function(data, cb)
    DebugPrint('Callback: closeMenu chamado')
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('openFullCatalog', function(data, cb)
    DebugPrint('Callback: openFullCatalog chamado')
    OpenRentalMenu('catalog')
    cb('ok')
end)

RegisterNUICallback('testDrive', function(data, cb)
    DebugPrint('Callback: testDrive chamado para modelo: ' .. tostring(data.model))

    if isTestDriving then
        DebugPrint('Já está em test-drive, ignorando...')
        cb({ success = false, message = 'Você já está em um test-drive!' })
        return
    end

    local vehicleData = VehicleData.GetVehicle(data.model)
    if not vehicleData then
        DebugError('Veículo não encontrado: ' .. tostring(data.model))
        cb({ success = false, message = 'Veículo não encontrado!' })
        return
    end

    DebugPrint('Iniciando test-drive do ' .. vehicleData.name)

    -- Fecha o menu
    CloseMenu()

    -- Verifica se o local de spawn está bloqueado
    local coords = Config.TestDriveSpawn
    if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.0) then
        Notify('O local de test-drive está bloqueado!', 'error')
        cb({ success = false, message = 'Local bloqueado!' })
        return
    end

    -- CORREÇÃO: Carregamento correto do modelo
    local modelHash = type(vehicleData.hash) == 'number' and vehicleData.hash or GetHashKey(vehicleData.model)

    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        DebugError('Modelo inválido: ' .. vehicleData.model)
        cb({ success = false, message = 'Modelo inválido!' })
        return
    end

    RequestModel(modelHash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not HasModelLoaded(modelHash) then
        DebugError('Timeout ao carregar modelo: ' .. vehicleData.model)
        cb({ success = false, message = 'Erro ao carregar veículo' })
        return
    end

    testDriveVehicle = CreateVehicle(
        modelHash,
        coords.x,
        coords.y,
        coords.z,
        coords.w,
        true,
        false
    )

    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(testDriveVehicle) then
        DebugError('Falha ao criar veículo de test-drive')
        cb({ success = false, message = 'Erro ao criar veículo' })
        return
    end

    -- Gera placa FIXA para test-drive
    local testPlate = Config.TestDrivePlate
    DebugPrint('Placa de test-drive FIXA: ' .. testPlate)

    SetEntityAsMissionEntity(testDriveVehicle, true, true)
    SetVehicleNumberPlateText(testDriveVehicle, testPlate)
    SetVehicleEngineOn(testDriveVehicle, true, false, true)

    -- ENTREGA AS CHAVES DO TEST-DRIVE (se habilitado)
    if Config.TestDriveGiveKeys then
        DebugPrint('Entregando chaves do test-drive: ' .. testPlate)
        TriggerEvent('vehiclekeys:client:SetOwner', testPlate)
    else
        DebugPrint('Entrega de chaves do test-drive desabilitada')
    end

    -- Coloca o jogador no veículo
    TaskWarpPedIntoVehicle(PlayerPedId(), testDriveVehicle, -1)

    isTestDriving = true

    -- Notifica o jogador
    local teleportMsg = Config.TestDriveTeleportBack and ' Você será teleportado de volta ao sair.' or
        ' O veículo será removido quando você sair.'
    Notify('Test-Drive iniciado! Chaves entregues. Placa: ' .. testPlate .. teleportMsg, 'success')
    DebugPrint('Test-drive iniciado com sucesso! VehicleID: ' .. testDriveVehicle .. ' | Placa: ' .. testPlate)

    -- Inicia thread para monitorar quando o jogador sair do veículo
    CreateThread(function()
        while isTestDriving and testDriveVehicle and DoesEntityExist(testDriveVehicle) do
            Wait(500)

            local ped = PlayerPedId()
            local inVehicle = IsPedInVehicle(ped, testDriveVehicle, false)

            if not inVehicle then
                DebugPrint('Jogador saiu do test-drive, deletando veículo...')

                -- Aguarda um pouco para garantir que o jogador saiu completamente
                Wait(2000)

                -- Verifica novamente se o jogador não voltou pro carro
                if not IsPedInVehicle(ped, testDriveVehicle, false) then
                    if DoesEntityExist(testDriveVehicle) then
                        -- Remove as chaves do test-drive (se habilitado) - PLACA FIXA
                        local testPlate = Config.TestDrivePlate
                        if Config.TestDriveRemoveKeys then
                            DebugPrint('Removendo chaves do test-drive: ' .. testPlate)
                            TriggerEvent('vehiclekeys:client:RemoveKeys', testPlate)
                        else
                            DebugPrint('Remoção de chaves do test-drive desabilitada')
                        end

                        -- TELEPORTA JOGADOR DE VOLTA À CONCESSIONÁRIA
                        TeleportPlayerBack()

                        if Config.TestDriveTeleportBack then
                            Notify('Test-Drive finalizado! Você foi teleportado de volta à concessionária.', 'info')
                        else
                            Notify('Test-Drive finalizado!', 'info')
                        end

                        DeleteEntity(testDriveVehicle)
                        DebugPrint('Veículo de test-drive deletado')
                    end

                    testDriveVehicle = nil
                    isTestDriving = false
                end
            end
        end
    end)

    cb({ success = true })
end)

-- ========================================
-- INTERAÇÕES ESTÁTICAS (PONTOS DE ACESSO)
-- ========================================

function CreateStaticInteractionPoints()
    if not Config.StaticInteractionPoints or #Config.StaticInteractionPoints == 0 then return end

    DebugPrint('Criando pontos de interação estáticos...')

    for i, point in ipairs(Config.StaticInteractionPoints) do
        local zoneId = exports.ox_target:addBoxZone({
            coords = point.coords,
            size = point.size or vector3(2.0, 2.0, 2.0),
            rotation = point.rotation or 0,
            debug = Config.Debug,
            options = {
                {
                    name = 'vip_rental_static_' .. i,
                    label = point.label or 'Abrir Catálogo',
                    icon = point.icon or 'fa-solid fa-tablet-alt',
                    onSelect = function()
                        OpenRentalMenu('catalog')
                    end
                }
            }
        })
        table.insert(staticInteractionPoints, zoneId)
        DebugPrint('Ponto estático ' .. i .. ' criado com ID: ' .. tostring(zoneId))
    end
end

function RemoveStaticInteractionPoints()
    DebugPrint('Removendo pontos de interação estáticos...')
    for _, zoneId in ipairs(staticInteractionPoints) do
        exports.ox_target:removeZone(zoneId)
    end
    staticInteractionPoints = {}
end

-- ========================================
-- CALLBACKS DA NUI
-- ========================================

RegisterNUICallback('rentVehicle', function(data, cb)
    DebugPrint('Callback: rentVehicle chamado - Modelo: ' .. tostring(data.model))
    DebugPrint('PERÍODO FIXO: 30 dias')

    QBCore.Functions.TriggerCallback('vip_car_rental:server:RentVehicle', function(success, message)
        DebugPrint('Resposta do servidor - Success: ' .. tostring(success) .. ' | Message: ' .. tostring(message))

        if success then
            Notify(message, 'success')
            DebugPrint('✅ Aluguel bem-sucedido - NUI será fechada pelo JavaScript')
            cb({ success = true }) -- Não envia dados, deixa o JS fechar a NUI
        else
            Notify(message, 'error')
            cb({ success = false })
        end
    end, data.model) -- Envia apenas o modelo, período é fixo (30 dias)
end)

RegisterNUICallback('renewVehicle', function(data, cb)
    DebugPrint('Callback: renewVehicle chamado - Modelo: ' ..
        tostring(data.model) .. ' | Dias: ' .. tostring(data.days or 30))

    -- Força 30 dias sempre
    local days = 30

    QBCore.Functions.TriggerCallback('vip_car_rental:server:RenewVehicle', function(success, message)
        DebugPrint('Resposta do servidor - Success: ' .. tostring(success) .. ' | Message: ' .. tostring(message))

        if success then
            Notify(message, 'success')
            QBCore.Functions.TriggerCallback('vip_car_rental:server:GetRentalData', function(newData)
                if newData then
                    DebugPrint('Dados atualizados recebidos')
                    cb({ success = true, data = newData })
                else
                    DebugError('Erro ao atualizar dados após renovação')
                    cb({ success = false })
                end
            end)
        else
            Notify(message, 'error')
            cb({ success = false })
        end
    end, data.model, days)
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    DebugPrint('Callback: spawnVehicle chamado - Placa: ' .. tostring(data.plate))

    -- Verifica se o local de spawn está bloqueado
    local coords = Config.SpawnLocation
    local distance = 3.0
    if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, distance) then
        DebugPrint('Local de spawn bloqueado')
        Notify(Config.Messages.spawn_blocked, 'error')
        cb({ success = false })
        return
    end

    QBCore.Functions.TriggerCallback('vip_car_rental:server:CanSpawnVehicle', function(canSpawn, vehicleData, plate)
        DebugPrint('Resposta CanSpawnVehicle - CanSpawn: ' .. tostring(canSpawn))

        if canSpawn and vehicleData and plate then
            -- CORREÇÃO: Carregamento correto do modelo
            local modelHash = type(vehicleData.hash) == 'number' and vehicleData.hash or GetHashKey(vehicleData.model)

            if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
                DebugError('Modelo inválido: ' .. vehicleData.model)
                Notify('Erro: Modelo de veículo inválido!', 'error')
                cb({ success = false })
                return
            end

            RequestModel(modelHash)
            local timeout = GetGameTimer() + 10000
            while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
                Wait(50)
            end

            if not HasModelLoaded(modelHash) then
                DebugError('Timeout ao carregar modelo: ' .. vehicleData.model)
                Notify('Erro ao carregar veículo!', 'error')
                cb({ success = false })
                return
            end

            local vehicle = CreateVehicle(
                modelHash,
                coords.x,
                coords.y,
                coords.z,
                coords.w,
                true,
                false
            )

            SetModelAsNoLongerNeeded(modelHash)

            if not DoesEntityExist(vehicle) then
                DebugError('Falha ao criar veículo')
                Notify('Erro ao criar veículo!', 'error')
                cb({ success = false })
                return
            end

            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleNumberPlateText(vehicle, plate)
            TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
            SetVehicleEngineOn(vehicle, true, false, true)

            -- Dá as chaves (compatível com qb-vehiclekeys)
            TriggerEvent('vehiclekeys:client:SetOwner', plate)

            Notify(Config.Messages.vehicle_spawned, 'success')
            CloseMenu()

            DebugPrint('Veículo ' .. vehicleData.name .. ' spawnado para o jogador!')
            cb({ success = true })
        else
            DebugError('Não pode spawnar veículo')
            Notify(Config.Messages.rental_expired, 'error')
            cb({ success = false })
        end
    end, data.plate)
end)

-- ========================================
-- SPAWN AUTOMÁTICO DE VEÍCULO ALUGADO
-- ========================================

RegisterNetEvent('vip_car_rental:client:spawnVehicle', function(model, plate, vehicleName)
    DebugPrint('=== SPAWN AUTOMÁTICO DE VEÍCULO ===')
    DebugPrint('Modelo: ' .. tostring(model))
    DebugPrint('Placa: ' .. tostring(plate))
    DebugPrint('Nome: ' .. tostring(vehicleName))

    local modelHash = GetHashKey(model)

    -- Verificação de segurança do modelo
    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        DebugError('Erro ao spawnar veículo: modelo inválido - ' .. tostring(model))
        Notify('Erro ao spawnar veículo: modelo inválido', 'error')
        return
    end

    -- Carregamento do modelo com timeout
    DebugPrint('Carregando modelo do veículo...')
    RequestModel(modelHash)
    local timeout = GetGameTimer() + 15000

    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(100)
    end

    if not HasModelLoaded(modelHash) then
        DebugError('Timeout ao carregar modelo: ' .. tostring(model))
        Notify('Erro ao carregar veículo', 'error')
        return
    end

    -- Verifica se o local de spawn está bloqueado
    local coords = Config.AutoSpawnLocation
    if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.0) then
        DebugPrint('Local de spawn automático bloqueado, tentando spawn manual')
        Notify('Local de entrega bloqueado! Use o menu para retirar o veículo.', 'info')
        SetModelAsNoLongerNeeded(modelHash)
        return
    end

    -- Criação do veículo
    DebugPrint('Criando veículo nas coordenadas: ' .. coords.x .. ', ' .. coords.y .. ', ' .. coords.z)
    local vehicle = CreateVehicle(
        modelHash,
        coords.x,
        coords.y,
        coords.z,
        coords.w,
        true,
        false
    )

    if not DoesEntityExist(vehicle) then
        DebugError('Falha ao criar veículo')
        Notify('Erro ao criar veículo', 'error')
        SetModelAsNoLongerNeeded(modelHash)
        return
    end

    -- Configuração do veículo
    SetVehicleNumberPlateText(vehicle, plate)
    SetEntityHeading(vehicle, coords.w)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleEngineOn(vehicle, true, false, true)

    -- Entrega das chaves (compatível com qb-vehiclekeys)
    DebugPrint('Entregando chaves do veículo: ' .. plate)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)

    -- Limpeza da memória
    SetModelAsNoLongerNeeded(modelHash)

    -- Notifica o jogador
    Notify('Seu ' .. vehicleName .. ' foi entregue! Placa: ' .. plate, 'success')
    DebugPrint('✅ Veículo spawnado com sucesso! ID: ' .. vehicle)

    -- Garante que o menu está fechado
    if isNuiOpen then
        DebugPrint('Fechando menu após spawn automático')
        CloseMenu()
    end
end)

-- ========================================
-- EVENTOS
-- ========================================

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    DebugPrint('Jogador carregado, inicializando sistema...')
    Wait(1000)
    SpawnDisplayVehicles()
    CreateStaticInteractionPoints()
    CreateBlip()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    DebugPrint('Jogador descarregado, limpando sistema...')
    RemoveDisplayVehicles()
    RemoveStaticInteractionPoints()
    if isNuiOpen then
        CloseMenu()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DebugPrint('Resource parado, limpando...')
        RemoveDisplayVehicles()
        RemoveStaticInteractionPoints()

        -- Limpa veículo de exibição se estiver ativo
        if previewVehicle and DoesEntityExist(previewVehicle) then
            DebugPrint('Limpando veículo de exibição ao parar resource')
            if Config.PreviewGiveKeys then
                TriggerEvent('vehiclekeys:client:RemoveKeys', Config.PreviewPlate)
            end
            DeleteEntity(previewVehicle)
            previewVehicle = nil
            previewTimer = nil
        end

        -- Limpa test-drive se estiver ativo
        if testDriveVehicle and DoesEntityExist(testDriveVehicle) then
            -- Placa FIXA do test-drive
            local testPlate = Config.TestDrivePlate
            if Config.TestDriveRemoveKeys then
                DebugPrint('Removendo chaves do test-drive ao parar resource: ' .. testPlate)
                TriggerEvent('vehiclekeys:client:RemoveKeys', testPlate)
            end

            -- Teleporta jogador se estava em test-drive
            local ped = PlayerPedId()
            if IsPedInVehicle(ped, testDriveVehicle, false) then
                DebugPrint('Jogador estava em test-drive, teleportando de volta...')
                TeleportPlayerBack()
            end

            DeleteEntity(testDriveVehicle)
            testDriveVehicle = nil
            isTestDriving = false
            DebugPrint('Test-drive limpo')
        end

        if isNuiOpen then
            CloseMenu()
        end
    end
end)

-- ========================================
-- INICIALIZAÇÃO
-- ========================================

CreateThread(function()
    Wait(2000)
    if QBCore.Functions.GetPlayerData().citizenid then
        DebugPrint('Inicializando sistema de aluguel VIP...')
        SpawnDisplayVehicles()
        CreateStaticInteractionPoints()
        CreateBlip()
    end
end)

-- ========================================
-- COMANDO DE DEBUG
-- ========================================

if Config.Debug then
    RegisterCommand('viprentaldebug', function()
        print('^2========== VIP CAR RENTAL DEBUG ==========^7')
        print('^3Veículos spawnados:^7 ' .. #displayVehicles)
        print('^3Menu aberto:^7 ' .. tostring(isNuiOpen))
        print('^3NUI Focused:^7 ' .. tostring(IsNuiFocused()))
        print('^3Test-drive ativo:^7 ' .. tostring(isTestDriving))
        if testDriveVehicle then
            print('^3Test-drive VehicleID:^7 ' .. testDriveVehicle)
        end
        print('^3Veículo de exibição ativo:^7 ' .. tostring(previewVehicle ~= nil))
        if previewVehicle then
            print('^3Preview VehicleID:^7 ' .. previewVehicle)
            if previewTimer then
                local timeLeft = math.max(0, math.floor((previewTimer - GetGameTimer()) / 1000))
                print('^3Tempo restante:^7 ' .. timeLeft .. ' segundos')
            end
        end
        print('^3Total de veículos disponíveis:^7 ' .. QBCore.Shared.TableLength(VehicleData.Vehicles))
        print('^2==========================================^7')
    end)

    -- Comando para forçar abertura do menu (para debug)
    RegisterCommand('viprental', function()
        DebugPrint('Comando /viprental executado')
        OpenRentalMenu()
    end)

    -- COMANDO REMOVIDO - Estava causando problemas
    -- RegisterCommand('closenui', function()
    --     DebugPrint('Comando /closenui executado')
    --     ForceCloseAllNUI()
    -- end)
end
