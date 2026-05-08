Config = {}

-- ========================================
-- CONFIGURAÇÕES GERAIS
-- ========================================

-- Debug mode (imprime mensagens no console F8)
Config.Debug = true

-- Modo de Teste (Reduz tempo de aluguel para 50 segundos)
Config.TestMode = false
Config.TestTime = 50 -- Segundos

-- Item usado para pagar o aluguel
Config.PaymentItem = 'zncoin'

-- Dias FIXOS de aluguel (não pode ser alterado pelo jogador)
Config.RentalDays = 30

-- Preço FIXO por aluguel de 30 dias
Config.RentalPrice = {
    multiplier = 30,      -- 30 dias fixos
    showDailyPrice = true -- Mostra preço por dia na interface, mas cobra pelos 30 dias
}

-- Desconto por renovação (em %)
Config.RenewalDiscount = 10

-- ========================================
-- CONFIGURAÇÕES DE SPAWN
-- ========================================

-- Locais onde os carros VIP ficam expostos (4 spawns aleatórios)
Config.DisplayVehicles = {
    {
        coords = vector4(-1270.27, -359.38, 36.18, 254.87),
        model = 'aleutian', -- modelo padrão, será substituído aleatoriamente
    },
    {
        coords = vector4(-1268.1, -364.76, 36.18, 297.95),
        model = 'elegy',
    },
    {
        coords = vector4(-1265.94, -355.76, 36.18, 205.82),
        model = 'sultan2',
    },
    {
        coords = vector4(-1262.91, -354.03, 36.18, 207.04),
        model = 'banshee',
    }
}

-- Distância para interação com os carros (ox_target)
Config.InteractionDistance = 3.5

-- ========================================
-- CONFIGURAÇÕES DE SPAWN DE VEÍCULOS ALUGADOS
-- ========================================

-- Local onde o carro alugado irá spawnar quando o jogador pegar
Config.SpawnLocation = vector4(-1235.86, -350.38, 37.33, 19.63)

-- Local onde o carro será spawnado automaticamente após o aluguel
Config.AutoSpawnLocation = vector4(-1241.53, -343.95, 37.33, 274.21)

-- Habilitar spawn automático após aluguel?
Config.AutoSpawnEnabled = true

-- ========================================
-- LOCAIS DE INTERAÇÃO ESTÁTICOS (PONTOS DE ACESSO)
-- ========================================
-- Locais onde o jogador pode abrir o menu sem que haja um carro de exibição
Config.StaticInteractionPoints = {
    {
        coords = vector3(-1252.46, -349.0, 36.91),
        size = vector3(2.0, 2.0, 2.0),
        rotation = 0,
        label = 'Acessar Catálogo',
        icon = 'fas fa-tablet-alt'
    }
}

-- ========================================
-- CONFIGURAÇÕES DE TEST-DRIVE
-- ========================================

-- Permitir test-drive?
Config.AllowTestDrive = true

-- Local onde o carro de test-drive irá spawnar
Config.TestDriveSpawn = vector4(-3503.0, 7681.71, 44.83, 184.51)

-- Placa FIXA para test-drive
Config.TestDrivePlate = 'TESTE009'

-- Entregar chaves no test-drive?
Config.TestDriveGiveKeys = true

-- Remover chaves ao finalizar test-drive?
Config.TestDriveRemoveKeys = true

-- Teleportar jogador de volta à concessionária ao sair do test-drive?
Config.TestDriveTeleportBack = true

-- Local para onde teleportar o jogador após test-drive (concessionária)
Config.TestDriveReturnLocation = vector3(-1259.8, -360.4, 36.91)

-- ========================================
-- CONFIGURAÇÕES DE EXIBIÇÃO DE VEÍCULOS
-- ========================================

-- Permitir exibição de veículos?
Config.AllowVehiclePreview = true

-- Local onde o veículo de exibição será spawnado (próximo aos carros de exibição)
Config.PreviewSpawnLocation = vector4(-1256.47, -366.88, 37.17, 113.12)

-- Placa para veículos de exibição
Config.PreviewPlate = 'PREVIEW1'

-- Tempo que o veículo de exibição fica no local (em segundos)
Config.PreviewDuration = 30

-- Entregar chaves do veículo de exibição?
Config.PreviewGiveKeys = false

-- ========================================
-- CONFIGURAÇÕES DE RENOVAÇÃO
-- ========================================

-- Permitir renovação antes do vencimento?
Config.AllowEarlyRenewal = true

-- Dias mínimos restantes para permitir renovação antecipada
Config.MinDaysForRenewal = 3

-- ========================================
-- MENSAGENS DO SISTEMA
-- ========================================

Config.Messages = {
    -- Sucesso
    rental_success = 'Você alugou um %s por 30 dias! O veículo será entregue automaticamente.',
    renewal_success = 'Você renovou o aluguel do %s por mais 30 dias!',
    vehicle_spawned = 'Seu veículo foi entregue!',
    vehicle_displayed = 'Agora exibindo: %s no local que você clicou!',

    -- Erros
    insufficient_funds = 'Você não tem %s suficientes! Necessário: %s',
    no_stock = 'Este veículo está sem estoque no momento!',
    already_rented = 'Você já tem este veículo alugado!',
    vehicle_not_found = 'Veículo não encontrado!',
    no_rentals = 'Você não possui veículos alugados!',
    rental_expired = 'O aluguel deste veículo expirou e foi removido do seu inventário!',
    spawn_blocked = 'O local de entrega está bloqueado!',
    slot_not_identified = 'Erro: Não foi possível identificar o veículo clicado!',

    -- Informações
    days_remaining = 'Dias restantes: %s',
    rental_info = 'Alugado em: %s | Expira em: %s',
    fixed_rental_period = 'Todos os aluguéis são de 30 dias fixos',
    auto_delivery_info = 'ENTREGA AUTOMÁTICA: Seu veículo será entregue imediatamente após o aluguel!',
    auto_removal_warning = 'ATENÇÃO: Veículos alugados são automaticamente removidos após 30 dias!',
}

-- ========================================
-- CONFIGURAÇÕES DE NOTIFICAÇÃO
-- ========================================

-- Tipo de notificação (qbcore, ox_lib, custom)
Config.NotificationType = 'qbcore'

-- ========================================
-- CONFIGURAÇÕES DE BLIP
-- ========================================

-- Blip no mapa para a concessionária
Config.Blip = {
    enabled = true,
    coords = vector3(-1255.9, -366.22, 37.17),
    sprite = 326, -- Ícone do blip
    color = 5,    -- Cor amarela
    scale = 0.8,
    name = 'Aluguel de Carros'
}

-- ========================================
-- CONFIGURAÇÕES DE PERMISSÃO
-- ========================================

-- Grupos com permissão para acessar (deixe vazio para todos)
Config.AllowedJobs = {}
-- Exemplo: Config.AllowedJobs = {'police', 'ambulance'}

-- VIP necessário? (true/false)
Config.RequireVIP = false

-- ========================================
-- CONFIGURAÇÕES DE WEBHOOK (LOGS)
-- ========================================

Config.Webhook = {
    enabled = true,
    url =
    'https://discord.com/api/webhooks/1468116768143839242/u5tlKPBGSfMhlts3AFxWcX7M45ed3rKfAgoPk8DATv-iK2ips64iXus-TjfMozR2j8hQ',

    -- Cores para diferentes ações
    colors = {
        rental = 3066993,   -- Azul para novos aluguéis
        expired = 15158332, -- Vermelho para expirados
        renewal = 15844367, -- Dourado para renovações
    }
}

-- ========================================
-- CONFIGURAÇÕES DE NUI
-- ========================================

Config.NUI = {
    -- Título da interface
    title = 'Concessionária de LUXO',

    -- Texto do botão de fechar
    closeButton = '✕',
}
