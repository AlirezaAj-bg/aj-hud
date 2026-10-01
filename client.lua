local QBCore = exports['qb-core']:GetCoreObject({ 'Functions' })
local PlayerData = QBCore.Functions.GetPlayerData()
local config = Config
local speedMultiplier = config.UseMPH and 2.23694 or 3.6
local seatbeltOn = false
local cruiseOn = false
local hudCursorActive = false -- see the 'ajhud_togglecursor' keybind below
local showAltitude = false
local showSeatbelt = false
local nos = 0
local stress = 0
local hunger = 100
local thirst = 100
local cashAmount = 0
local bankAmount = 0
local nitroActive = 0
local harness = 0
local hp = 100
local armed = 0
local parachute = -1
local oxygen = 100
local dev = false
local playerDead = false
local showMenu = false
local showCircleB = false
local showSquareB = false
local Menu = config.Menu
local CinematicHeight = 0.2
local w = 0
local radioActive = false

DisplayRadar(false)

local function CinematicShow(bool)
    SetBigmapActive(true, false)
    Wait(0)
    SetBigmapActive(false, false)
    if bool then
        for i = CinematicHeight, 0, -1.0 do
            Wait(10)
            w = i
        end
    else
        for i = 0, CinematicHeight, 1.0 do
            Wait(10)
            w = i
        end
    end
end

local function loadSettings(settings)
    for k, v in pairs(settings) do
        if k == 'isToggleMapShapeChecked' then
            Menu.isToggleMapShapeChecked = v
            SendNUIMessage({ test = true, event = k, toggle = v })
        elseif k == 'isCinematicModeChecked' then
            Menu.isCinematicModeChecked = v
            CinematicShow(v)
            SendNUIMessage({ test = true, event = k, toggle = v })
        elseif k == 'isChangeFPSChecked' then
            Menu[k] = v
            local val = v and 'Optimized' or 'Synced'
            SendNUIMessage({ test = true, event = k, toggle = val })
        else
            Menu[k] = v
            SendNUIMessage({ test = true, event = k, toggle = v })
        end
    end
    QBCore.Functions.Notify(Lang:t('notify.hud_settings_loaded'), 'success')
    Wait(1000)
    TriggerEvent('hud:client:LoadMap')
end

-- Set whenever a menu toggle changes so the compass/street loop re-sends
-- its state even while the heading hasn't moved (otherwise a toggle only
-- showed up after turning the camera).
local menuDirty = true

local function saveSettings()
    SetResourceKvp('hudSettings', json.encode(Menu))
    menuDirty = true
end

-- Pushes every Menu value to the settings menu checkboxes, so the menu
-- always reflects the real Lua state (not just when a KVP save exists).
local function syncMenuToNui()
    for k, v in pairs(Menu) do
        local val = v
        if k == 'isChangeFPSChecked' then val = v and 'Optimized' or 'Synced' end
        SendNUIMessage({ test = true, event = k, toggle = val })
    end
end

-- NoPixel layout (2026-10-01): round minimap and always-visible
-- HEALTH/ARMOR pills. Saves made before it are migrated once so existing
-- players get the new defaults; after that their own toggles stick.
local SETTINGS_VERSION = 2
local function loadSavedSettings()
    local hudSettings = GetResourceKvpString('hudSettings')
    local saved = hudSettings and json.decode(hudSettings) or nil
    if saved and (GetResourceKvpInt('hudSettingsVersion') or 0) < SETTINGS_VERSION then
        saved.isToggleMapShapeChecked = 'circle'
        saved.isDynamicHealthChecked = false
        saved.isDynamicArmorChecked = false
        SetResourceKvp('hudSettings', json.encode(saved))
    end
    SetResourceKvpInt('hudSettingsVersion', SETTINGS_VERSION)
    if saved then
        loadSettings(saved)
    else
        syncMenuToNui()
        TriggerEvent('hud:client:LoadMap')
    end
    menuDirty = true
end

local function hasHarness(items)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end

    local _harness = false
    if items then
        for _, v in pairs(items) do
            if v.name == 'harness' then
                _harness = true
            end
        end
    end

    harness = _harness
end

-- Pushed once per (re)load rather than baked into the NUI's own JS, so a
-- server owner can retune the whole look from config.lua alone -- see
-- html/theme.css for the full token list these fill in / override.
local function sendTheme()
    SendNUIMessage({
        action = 'theme',
        theme = config.Theme,
        unit = config.UseMPH and 'MPH' or 'KPH',
        openKey = config.OpenMenu,
    })
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    loadSavedSettings()
    PlayerData = QBCore.Functions.GetPlayerData()
    sendTheme()
    Wait(3000)
    SetEntityHealth(PlayerPedId(), 200)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Client:OnPlayerUpdated', function(key, val)
    if key ~= 'all' then return end
    PlayerData = val
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(2000)
    loadSavedSettings()
    sendTheme()
end)

AddEventHandler('pma-voice:radioActive', function(data)
    radioActive = data
end)

-- Callbacks & Events
RegisterCommand('hudmenu', function()
    Wait(50)
    if showMenu then return end
    TriggerEvent('hud:client:playOpenMenuSounds')
    SetNuiFocus(true, true)
    syncMenuToNui()
    SendNUIMessage({ action = 'open' })
    showMenu = true
end)

RegisterNUICallback('closeMenu', function(_, cb)
    Wait(50)
    TriggerEvent('hud:client:playCloseMenuSounds')
    showMenu = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterKeyMapping('hudmenu', 'Open Menu', 'keyboard', config.OpenMenu)

-- The icon-stack buttons (headlights/seatbelt/lock) need real mouse clicks
-- to reach the NUI, but the game owns the mouse for camera/steering while
-- driving -- NUI doesn't get input at all until SetNuiFocus is on. This key
-- toggles a cursor WITHOUT taking away movement/steering (SetNuiFocusKeepInput),
-- so you can click an icon mid-drive and toggle it off again after. Also
-- force-cleared on exiting the vehicle (see the `wasInVehicle` block below).
RegisterKeyMapping('ajhud_togglecursor', 'Toggle HUD Icon Cursor', 'keyboard', 'LALT')
RegisterCommand('ajhud_togglecursor', function()
    if not hudCursorActive and not IsPedInAnyVehicle(PlayerPedId(), false) then return end
    hudCursorActive = not hudCursorActive
    SetNuiFocus(hudCursorActive, hudCursorActive)
    SetNuiFocusKeepInput(hudCursorActive)
end, false)

-- Reset hud
local function restartHud()
    TriggerEvent('hud:client:playResetHudSounds')
    QBCore.Functions.Notify(Lang:t('notify.hud_restart'), 'error')
    if IsPedInAnyVehicle(PlayerPedId()) then
        Wait(2600)
        SendNUIMessage({ action = 'car', show = false })
        SendNUIMessage({ action = 'car', show = true })
    end
    Wait(2600)
    SendNUIMessage({ action = 'hudtick', show = false })
    SendNUIMessage({ action = 'hudtick', show = true })
    Wait(2600)
    QBCore.Functions.Notify(Lang:t('notify.hud_start'), 'success')
end

RegisterNUICallback('restartHud', function(_, cb)
    Wait(50)
    restartHud()
    cb('ok')
end)

RegisterCommand('resethud', function()
    Wait(50)
    restartHud()
end)

RegisterNUICallback('resetStorage', function(_, cb)
    Wait(50)
    TriggerEvent('hud:client:resetStorage')
    cb('ok')
end)

RegisterNetEvent('hud:client:resetStorage', function()
    Wait(50)
    if Menu.isResetSoundsChecked then
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'airwrench', 0.1)
    end
    QBCore.Functions.TriggerCallback('hud:server:getMenu', function(menu)
        loadSettings(menu); SetResourceKvp('hudSettings', json.encode(menu))
    end)
end)

-- Notifications
RegisterNUICallback('openMenuSounds', function(_, cb)
    Wait(50)
    Menu.isOpenMenuSoundsChecked = not Menu.isOpenMenuSoundsChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNetEvent('hud:client:playOpenMenuSounds', function()
    Wait(50)
    if not Menu.isOpenMenuSoundsChecked then return end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'monkeyopening', 0.5)
end)

RegisterNetEvent('hud:client:playCloseMenuSounds', function()
    Wait(50)
    if not Menu.isOpenMenuSoundsChecked then return end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'catclosing', 0.05)
end)

RegisterNUICallback('resetHudSounds', function(_, cb)
    Wait(50)
    Menu.isResetSoundsChecked = not Menu.isResetSoundsChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNetEvent('hud:client:playResetHudSounds', function()
    Wait(50)
    if not Menu.isResetSoundsChecked then return end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'airwrench', 0.1)
end)

RegisterNUICallback('checklistSounds', function(_, cb)
    Wait(50)
    TriggerEvent('hud:client:checklistSounds')
    cb('ok')
end)

RegisterNetEvent('hud:client:checklistSounds', function()
    Wait(50)
    Menu.isListSoundsChecked = not Menu.isListSoundsChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
end)

RegisterNetEvent('hud:client:playHudChecklistSound', function()
    Wait(50)
    if not Menu.isListSoundsChecked then return end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'shiftyclick', 0.5)
end)

RegisterNUICallback('showOutMap', function(_, cb)
    Wait(50)
    Menu.isOutMapChecked = not Menu.isOutMapChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('showOutCompass', function(_, cb)
    Wait(50)
    Menu.isOutCompassChecked = not Menu.isOutCompassChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('showFollowCompass', function(_, cb)
    Wait(50)
    Menu.isCompassFollowChecked = not Menu.isCompassFollowChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('showMapNotif', function(_, cb)
    Wait(50)
    Menu.isMapNotifChecked = not Menu.isMapNotifChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('showFuelAlert', function(_, cb)
    Wait(50)
    Menu.isLowFuelChecked = not Menu.isLowFuelChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('showCinematicNotif', function(_, cb)
    Wait(50)
    Menu.isCinematicNotifChecked = not Menu.isCinematicNotifChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

-- Status
RegisterNUICallback('dynamicHealth', function(_, cb)
    Wait(50)
    TriggerEvent('hud:client:ToggleHealth')
    cb('ok')
end)

RegisterNetEvent('hud:client:ToggleHealth', function()
    Wait(50)
    Menu.isDynamicHealthChecked = not Menu.isDynamicHealthChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
end)

RegisterNUICallback('dynamicArmor', function(_, cb)
    Wait(50)
    Menu.isDynamicArmorChecked = not Menu.isDynamicArmorChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('dynamicHunger', function(_, cb)
    Wait(50)
    Menu.isDynamicHungerChecked = not Menu.isDynamicHungerChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('dynamicThirst', function(_, cb)
    Wait(50)
    Menu.isDynamicThirstChecked = not Menu.isDynamicThirstChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('dynamicStress', function(_, cb)
    Wait(50)
    Menu.isDynamicStressChecked = not Menu.isDynamicStressChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('dynamicOxygen', function(_, cb)
    Wait(50)
    Menu.isDynamicOxygenChecked = not Menu.isDynamicOxygenChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

-- Vehicle
RegisterNUICallback('changeFPS', function(_, cb)
    Wait(50)
    Menu.isChangeFPSChecked = not Menu.isChangeFPSChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('HideMap', function(_, cb)
    Wait(50)
    Menu.isHideMapChecked = not Menu.isHideMapChecked
    local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
    DisplayRadar(not Menu.isHideMapChecked and (inVehicle or Menu.isOutMapChecked))
    if not Menu.isHideMapChecked then TriggerEvent('hud:client:LoadMap') end
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

-- Icon-stack buttons (headlights/seatbelt/lock) -- these used to be
-- read-only status dots. Lock and seatbelt already have their own
-- RegisterCommand'd keybinds in qb-vehiclekeys/qb-smallresources, so
-- clicking those just replays the same command the L/B keys run (same
-- driver/key/proximity checks apply). Headlights never had a toggle
-- command anywhere in the base, so it's implemented here directly.
RegisterNUICallback('toggleHeadlights', function(_, cb)
    local player = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(player, false)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == player then
        local _, lightsOn = GetVehicleLightsState(vehicle)
        SetVehicleLights(vehicle, lightsOn == 1 and 2 or 1)
    end
    cb('ok')
end)

RegisterNUICallback('toggleSeatbelt', function(_, cb)
    ExecuteCommand('toggleseatbelt')
    cb('ok')
end)

RegisterNUICallback('toggleLock', function(_, cb)
    ExecuteCommand('togglelocks')
    cb('ok')
end)

-- Requested 2026-09-21: the minimap should sit top-left while driving
-- (clear of the restyled bottom-left stat pills/hint bar) but stay in its
-- normal bottom-left spot on foot. `inVehicle` picks the anchor; the actual
-- offset numbers below are a best-effort starting point -- GTA's minimap
-- natives are notoriously fiddly to place pixel-perfectly and there is no
-- way to render the real minimap texture outside a live client to tune
-- these against, so expect this to need one round of in-game adjustment.
--
-- Tried anchoring to 'R' (top-right) the same day, reusing the same offsetX
-- numbers -- in-game this rendered the native minimap huge/malformed
-- instead of just shifted, so SetMinimapComponentPosition's offsetX is NOT
-- a simple mirror across anchors. Reverted to 'L' (top-left) until someone
-- can iterate against a live client with real numbers; don't re-attempt the
-- 'R' anchor without in-game verification of each offset change.
--
-- 2026-09-22: moved to top-right per request. Anchor stays 'L' (see the
-- 'R' warning above) -- instead every inVehicle offsetX below is translated
-- right by the same constant (rightOffsetX), which keeps the minimap/mask/
-- blur components' relative spacing identical to the working top-left
-- values and just slides the whole group over. This still needs an
-- in-game look to confirm the right-edge margin/vertical position land
-- right, same as the original top-left placement did.
local function ApplyMinimapPosition(inVehicle)
    -- Credit to Dalrae for the solve.
    local defaultAspectRatio = 1920 / 1080 -- Don't change this.
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    local minimapOffset = 0
    if aspectRatio > defaultAspectRatio then
        minimapOffset = ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008
    end
    local anchorY = inVehicle and 'T' or 'B'
    if Menu.isToggleMapShapeChecked == 'square' then
        RequestStreamedTextureDict('squaremap', false)
        if not HasStreamedTextureDictLoaded('squaremap') then
            Wait(150)
        end
        if Menu.isMapNotifChecked then
            QBCore.Functions.Notify(Lang:t('notify.load_square_map'))
        end
        SetMinimapClipType(0)
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'squaremap', 'radarmasksm')
        AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'squaremap', 'radarmasksm')
        if inVehicle then
            -- Slid right from the top-left values (rightOffsetX added to each
            -- offsetX, nothing else changed) to land top-right instead.
            local rightOffsetX = 0.758
            SetMinimapComponentPosition('minimap', 'L', anchorY, rightOffsetX + 0.0 + minimapOffset, 0.03, 0.1638, 0.213)
            SetMinimapComponentPosition('minimap_mask', 'L', anchorY, rightOffsetX + 0.0 + minimapOffset, 0.078, 0.128, 0.50)
            SetMinimapComponentPosition('minimap_blur', 'L', anchorY, rightOffsetX - 0.01 + minimapOffset, 0.008, 0.262, 0.300)
        else
            -- 0.0 = nav symbol and icons left
            -- 0.1638 = nav symbol and icons stretched
            -- 0.216 = nav symbol and icons raised up
            SetMinimapComponentPosition('minimap', 'L', anchorY, 0.0 + minimapOffset, -0.047, 0.1638, 0.183)

            -- icons within map
            SetMinimapComponentPosition('minimap_mask', 'L', anchorY, 0.0 + minimapOffset, 0.0, 0.128, 0.20)

            -- -0.01 = map pulled left
            -- 0.025 = map raised up
            -- 0.262 = map stretched
            -- 0.315 = map shorten
            SetMinimapComponentPosition('minimap_blur', 'L', anchorY, -0.01 + minimapOffset, 0.025, 0.262, 0.300)
        end
        SetBlipAlpha(GetNorthRadarBlip(), 0)
        SetBigmapActive(true, false)
        SetMinimapClipType(0)
        Wait(50)
        SetBigmapActive(false, false)
        if Menu.isToggleMapBordersChecked then
            showCircleB = false
            showSquareB = true
        end
        Wait(1200)
        if Menu.isMapNotifChecked then
            QBCore.Functions.Notify(Lang:t('notify.loaded_square_map'))
        end
    elseif Menu.isToggleMapShapeChecked == 'circle' then
        RequestStreamedTextureDict('circlemap', false)
        if not HasStreamedTextureDictLoaded('circlemap') then
            Wait(150)
        end
        if Menu.isMapNotifChecked then
            QBCore.Functions.Notify(Lang:t('notify.load_circle_map'))
        end
        SetMinimapClipType(1)
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'circlemap', 'radarmasksm')
        AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'circlemap', 'radarmasksm')
        if inVehicle then
            -- Same right-shift approach as the square-map branch above.
            local rightOffsetX = 0.74
            SetMinimapComponentPosition('minimap', 'L', anchorY, rightOffsetX - 0.0100 + minimapOffset, 0.04, 0.180, 0.258)
            SetMinimapComponentPosition('minimap_mask', 'L', anchorY, rightOffsetX + 0.200 + minimapOffset, 0.04, 0.065, 0.20)
            SetMinimapComponentPosition('minimap_blur', 'L', anchorY, rightOffsetX - 0.00 + minimapOffset, 0.005, 0.252, 0.338)
        else
            -- -0.0100 = nav symbol and icons left
            -- 0.180 = nav symbol and icons stretched
            -- 0.258 = nav symbol and icons raised up
            SetMinimapComponentPosition('minimap', 'L', anchorY, -0.0100 + minimapOffset, -0.030, 0.180, 0.258)

            -- icons within map
            SetMinimapComponentPosition('minimap_mask', 'L', anchorY, 0.200 + minimapOffset, 0.0, 0.065, 0.20)

            -- -0.00 = map pulled left
            -- 0.015 = map raised up
            -- 0.252 = map stretched
            -- 0.338 = map shorten
            SetMinimapComponentPosition('minimap_blur', 'L', anchorY, -0.00 + minimapOffset, 0.015, 0.252, 0.338)
        end
        SetBlipAlpha(GetNorthRadarBlip(), 0)
        SetMinimapClipType(1)
        SetBigmapActive(true, false)
        Wait(50)
        SetBigmapActive(false, false)
        if Menu.isToggleMapBordersChecked then
            showSquareB = false
            showCircleB = true
        end
        Wait(1200)
        if Menu.isMapNotifChecked then
            QBCore.Functions.Notify(Lang:t('notify.loaded_circle_map'))
        end
    end
end

RegisterNetEvent('hud:client:LoadMap', function()
    Wait(50)
    ApplyMinimapPosition(IsPedInAnyVehicle(PlayerPedId(), false))
end)

RegisterNUICallback('ToggleMapShape', function(_, cb)
    Wait(50)
    Menu.isToggleMapShapeChecked = Menu.isToggleMapShapeChecked == 'circle' and 'square' or 'circle'
    Wait(50)
    TriggerEvent('hud:client:LoadMap')
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('ToggleMapBorders', function(_, cb)
    Wait(50)
    Menu.isToggleMapBordersChecked = not Menu.isToggleMapBordersChecked
    if Menu.isToggleMapBordersChecked then
        if Menu.isToggleMapShapeChecked == 'square' then
            showSquareB = true
        else
            showCircleB = true
        end
    else
        showSquareB = false
        showCircleB = false
    end
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('dynamicEngine', function(_, cb)
    Wait(50)
    Menu.isDynamicEngineChecked = not Menu.isDynamicEngineChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('dynamicNitro', function(_, cb)
    Wait(50)
    Menu.isDynamicNitroChecked = not Menu.isDynamicNitroChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

-- Compass
RegisterNUICallback('showCompassBase', function(_, cb)
    Wait(50)
    Menu.isShowCompassChecked = not Menu.isShowCompassChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('showStreetsNames', function(_, cb)
    Wait(50)
    Menu.isShowStreetsChecked = not Menu.isShowStreetsChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('showPointerIndex', function(_, cb)
    Wait(50)
    Menu.isPointerShowChecked = not Menu.isPointerShowChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('showDegreesNum', function(_, cb)
    Wait(50)
    Menu.isDegreesShowChecked = not Menu.isDegreesShowChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('changeCompassFPS', function(_, cb)
    Wait(50)
    Menu.isChangeCompassFPSChecked = not Menu.isChangeCompassFPSChecked
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNUICallback('cinematicMode', function(_, cb)
    Wait(50)
    if Menu.isCinematicModeChecked then
        CinematicShow(false)
        Menu.isCinematicModeChecked = false
        if Menu.isCinematicNotifChecked then
            QBCore.Functions.Notify(Lang:t('notify.cinematic_off'), 'error')
        end
        DisplayRadar(not Menu.isHideMapChecked)
    else
        CinematicShow(true)
        Menu.isCinematicModeChecked = true
        if Menu.isCinematicNotifChecked then
            QBCore.Functions.Notify(Lang:t('notify.cinematic_on'))
        end
    end
    TriggerEvent('hud:client:playHudChecklistSound')
    saveSettings()
    cb('ok')
end)

RegisterNetEvent('hud:client:ToggleAirHud', function()
    showAltitude = not showAltitude
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst) -- Triggered in qb-core
    hunger = newHunger
    thirst = newThirst
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress) -- Add this event with adding stress elsewhere
    stress = newStress
end)

RegisterNetEvent('hud:client:ToggleShowSeatbelt', function()
    showSeatbelt = not showSeatbelt
end)

RegisterNetEvent('seatbelt:client:ToggleSeatbelt', function() -- Triggered in smallresources
    seatbeltOn = not seatbeltOn
end)

RegisterNetEvent('seatbelt:client:ToggleCruise', function() -- Triggered in smallresources
    cruiseOn = not cruiseOn
end)

RegisterNetEvent('hud:client:UpdateNitrous', function(nitroLevel, bool)
    nos = nitroLevel
    nitroActive = bool
end)

RegisterNetEvent('hud:client:UpdateHarness', function(harnessHp)
    hp = harnessHp
end)

RegisterNetEvent('aj-admin:client:ToggleDevmode', function()
    dev = not dev
end)

local prevPlayerStats = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil }

local function updatePlayerHud(data)
    local shouldUpdate = false
    for k, v in pairs(data) do
        if prevPlayerStats[k] ~= v then
            shouldUpdate = true
            break
        end
    end
    prevPlayerStats = data
    if shouldUpdate then
        SendNUIMessage({
            action = 'hudtick',
            show = data[1],
            dynamicHealth = data[2],
            dynamicArmor = data[3],
            dynamicHunger = data[4],
            dynamicThirst = data[5],
            dynamicStress = data[6],
            dynamicOxygen = data[7],
            dynamicEngine = data[8],
            dynamicNitro = data[9],
            health = data[10],
            playerDead = data[11],
            armor = data[12],
            thirst = data[13],
            hunger = data[14],
            stress = data[15],
            voice = data[16],
            radio = data[17],
            talking = data[18],
            armed = data[19],
            oxygen = data[20],
            parachute = data[21],
            nos = data[22],
            cruise = data[23],
            nitroActive = data[24],
            harness = data[25],
            hp = data[26],
            speed = data[27],
            engine = data[28],
            cinematic = data[29],
            dev = data[30],
            radioActive = data[31],
        })
    end
end

local prevVehicleStats = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil }

local function updateVehicleHud(data)
    local shouldUpdate = false
    for k, v in pairs(data) do
        if prevVehicleStats[k] ~= v then
            shouldUpdate = true
            break
        end
    end
    prevVehicleStats = data
    if shouldUpdate then
        SendNUIMessage({
            action = 'car',
            show = data[1],
            isPaused = data[2],
            seatbelt = data[3],
            speed = data[4],
            fuel = data[5],
            altitude = data[6],
            showAltitude = data[7],
            showSeatbelt = data[8],
            showSquareB = data[9],
            showCircleB = data[10],
            gear = data[11],
            lightsOn = data[12],
            locked = data[13],
            engineOn = data[14],
            showHints = data[15],
            canLock = data[16],
            mapShape = data[17],
            mapBorder = data[18],
            mapVisible = data[19],
            mapLetters = data[20],
        })
    end
end

-- Only meaningful while the driver seat is occupied by the local player --
-- the contextual key-hint bar (STOP ENGINE / VEHICLE LOCK / HEADLIGHTS /
-- HORN / EXIT) is driver-only, matching who those controls actually affect.
local function isDriverSeat(vehicle, player)
    return GetPedInVehicleSeat(vehicle, -1) == player
end

-- Approximate on purpose: qb-vehiclekeys only exports the plain `HasKeys`
-- lookup, not its fuller job-shared/blacklist gating (that logic is local to
-- that resource) -- this can occasionally show the hint for an edge case
-- HasKeys alone doesn't capture. See aj-hud's README/plan notes if you want
-- to tighten this further by also exporting from qb-vehiclekeys itself.
local function canLockVehicle(plate)
    if GetResourceState('qb-vehiclekeys') ~= 'started' then return false end
    local ok, result = pcall(function()
        return exports['qb-vehiclekeys']:HasKeys(plate)
    end)
    return ok and result == true
end

local lastFuelUpdate = 0
local lastFuelVehicle = 0
local lastFuelCheck = 0

-- Never lets a fuel-resource error escape: qb-fuel `provide`s LegacyFuel,
-- but if it is stopped/restarting the export throws, which used to kill
-- the HUD tick thread outright.
local function readFuel(vehicle)
    local ok, fuel = pcall(function() return exports['LegacyFuel']:GetFuel(vehicle) end)
    if not ok or type(fuel) ~= 'number' then fuel = GetVehicleFuelLevel(vehicle) end
    return math.floor(math.max(0, math.min(100, fuel or 0)))
end

local function getFuelLevel(vehicle)
    local updateTick = GetGameTimer()
    if vehicle ~= lastFuelVehicle or (updateTick - lastFuelUpdate) > 2000 then
        lastFuelUpdate = updateTick
        lastFuelVehicle = vehicle
        lastFuelCheck = readFuel(vehicle)
    end
    return lastFuelCheck
end

-- HUD Update loop

CreateThread(function()
    local wasInVehicle = false
    while true do
        if Menu.isChangeFPSChecked then
            Wait(500)
        else
            Wait(50)
        end
        if LocalPlayer.state.isLoggedIn then
            local show = true
            local player = PlayerPedId()
            local playerId = PlayerId()
            local weapon = GetSelectedPedWeapon(player)
            -- Player hud
            if not config.WhitelistedWeaponArmed[weapon] then
                if weapon ~= `WEAPON_UNARMED` then
                    armed = true
                else
                    armed = false
                end
            end
            local metadata = PlayerData and PlayerData.metadata or {}
            playerDead = IsEntityDead(player) or metadata['inlaststand'] or metadata['isdead'] or false
            parachute = GetPedParachuteState(player)
            -- Stamina
            if not IsEntityInWater(player) then
                oxygen = 100 - GetPlayerSprintStaminaRemaining(playerId)
            end
            -- Oxygen
            if IsEntityInWater(player) then
                oxygen = GetPlayerUnderwaterTimeRemaining(playerId) * 10
            end
            -- Player hud
            local talking = NetworkIsPlayerTalking(playerId)
            local voice = 0
            if LocalPlayer.state['proximity'] then
                voice = LocalPlayer.state['proximity'].distance
            end
            if IsPauseMenuActive() then
                show = false
            end
            local vehicle = GetVehiclePedIsIn(player)
            if not (IsPedInAnyVehicle(player) and not IsThisModelABicycle(vehicle)) then
                updatePlayerHud({
                    show,
                    Menu.isDynamicHealthChecked,
                    Menu.isDynamicArmorChecked,
                    Menu.isDynamicHungerChecked,
                    Menu.isDynamicThirstChecked,
                    Menu.isDynamicStressChecked,
                    Menu.isDynamicOxygenChecked,
                    Menu.isDynamicEngineChecked,
                    Menu.isDynamicNitroChecked,
                    GetEntityHealth(player) - 100,
                    playerDead,
                    GetPedArmour(player),
                    thirst,
                    hunger,
                    stress,
                    voice,
                    LocalPlayer.state['radioChannel'],
                    talking,
                    armed,
                    oxygen,
                    parachute,
                    -1,
                    cruiseOn,
                    nitroActive,
                    harness,
                    hp,
                    math.ceil(GetEntitySpeed(vehicle) * speedMultiplier),
                    -1,
                    Menu.isCinematicModeChecked,
                    dev,
                    radioActive,
                })
            end
            -- Vehicle hud
            if IsPedInAnyHeli(player) or IsPedInAnyPlane(player) then
                showAltitude = true
                showSeatbelt = false
            end
            if IsPedInAnyVehicle(player) and not IsThisModelABicycle(vehicle) then
                if not wasInVehicle then
                    DisplayRadar(not Menu.isHideMapChecked)
                    menuDirty = true
                    -- Spawned on its own thread: ApplyMinimapPosition has several
                    -- Wait()s inside it (streamed-texture load, notify timing) that
                    -- would otherwise stall this tick loop's HUD updates for over
                    -- a second on every vehicle enter/exit.
                    CreateThread(function() ApplyMinimapPosition(true) end)
                end
                wasInVehicle = true
                local engineHealth = GetVehicleEngineHealth(vehicle)
                if engineHealth ~= engineHealth then -- This checks for NaN, as any NaN value is not equal to itself
                    engineHealth = 0
                end
                updatePlayerHud({
                    show,
                    Menu.isDynamicHealthChecked,
                    Menu.isDynamicArmorChecked,
                    Menu.isDynamicHungerChecked,
                    Menu.isDynamicThirstChecked,
                    Menu.isDynamicStressChecked,
                    Menu.isDynamicOxygenChecked,
                    Menu.isDynamicEngineChecked,
                    Menu.isDynamicNitroChecked,
                    GetEntityHealth(player) - 100,
                    playerDead,
                    GetPedArmour(player),
                    thirst,
                    hunger,
                    stress,
                    voice,
                    LocalPlayer.state['radioChannel'],
                    talking,
                    armed,
                    oxygen,
                    GetPedParachuteState(player),
                    nos,
                    cruiseOn,
                    nitroActive,
                    harness,
                    hp,
                    math.ceil(GetEntitySpeed(vehicle) * speedMultiplier),
                    (engineHealth / 10),
                    Menu.isCinematicModeChecked,
                    dev,
                    radioActive,
                })
                local _, lightsOn = GetVehicleLightsState(vehicle)
                local isDriver = isDriverSeat(vehicle, player)
                updateVehicleHud({
                    show,
                    IsPauseMenuActive(),
                    seatbeltOn,
                    math.ceil(GetEntitySpeed(vehicle) * speedMultiplier),
                    getFuelLevel(vehicle),
                    math.ceil(GetEntityCoords(player).z * 0.5),
                    showAltitude,
                    showSeatbelt,
                    showSquareB,
                    showCircleB,
                    GetVehicleCurrentGear(vehicle),
                    lightsOn,
                    GetVehicleDoorLockStatus(vehicle) >= 2,
                    GetIsVehicleEngineRunning(vehicle),
                    isDriver,
                    isDriver and canLockVehicle(GetVehicleNumberPlateText(vehicle)) or false,
                    Menu.isToggleMapShapeChecked,
                    Menu.isToggleMapBordersChecked,
                    not Menu.isHideMapChecked,
                    Menu.isPointerShowChecked,
                })
                showAltitude = false
                showSeatbelt = true
            else
                if wasInVehicle then
                    wasInVehicle = false
                    SendNUIMessage({
                        action = 'car',
                        show = false,
                        seatbelt = false,
                        cruise = false,
                    })
                    seatbeltOn = false
                    cruiseOn = false
                    harness = false
                    menuDirty = true
                    if hudCursorActive then
                        hudCursorActive = false
                        SetNuiFocus(false, false)
                        SetNuiFocusKeepInput(false)
                    end
                    CreateThread(function() ApplyMinimapPosition(false) end)
                end
                DisplayRadar(Menu.isOutMapChecked and not Menu.isHideMapChecked)
            end
        else
            SendNUIMessage({
                action = 'hudtick',
                show = false
            })
        end
    end
end)

-- Low fuel
CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) and not IsThisModelABicycle(GetEntityModel(GetVehiclePedIsIn(ped, false))) then
                if Menu.isLowFuelChecked and readFuel(GetVehiclePedIsIn(ped, false)) <= 20 then -- At 20% Fuel Left
                    do
                        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'pager', 0.10)
                        QBCore.Functions.Notify(Lang:t('notify.low_fuel'), 'error')
                        Wait(60000) -- repeats every 1 min until empty
                    end
                end
            end
        end
        Wait(10000)
    end
end)

-- Money HUD

local Round = math.floor
local function RoundNearest(value) return math.floor(value + 0.5) end

RegisterNetEvent('hud:client:ShowAccounts', function(type, amount)
    if type == 'cash' then
        SendNUIMessage({
            action = 'show',
            type = 'cash',
            cash = Round(amount)
        })
    else
        SendNUIMessage({
            action = 'show',
            type = 'bank',
            bank = Round(amount)
        })
    end
end)

RegisterNetEvent('hud:client:OnMoneyChange', function(type, amount, isMinus)
    cashAmount = PlayerData.money['cash']
    bankAmount = PlayerData.money['bank']
    SendNUIMessage({
        action = 'updatemoney',
        cash = Round(cashAmount),
        bank = Round(bankAmount),
        amount = Round(amount),
        minus = isMinus,
        type = type
    })
end)

-- Harness Check

CreateThread(function()
    while true do
        Wait(1000)

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            hasHarness(PlayerData.items)
        end
    end
end)

-- Stress Gain

if not config.DisableStress then
    CreateThread(function() -- Speeding
        while true do
            if LocalPlayer.state.isLoggedIn then
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                    local veh = GetVehiclePedIsIn(ped, false)
                    local vehClass = GetVehicleClass(veh)
                    local speed = GetEntitySpeed(veh) * speedMultiplier
                    local vehHash = GetEntityModel(veh)
                    if config.VehClassStress[tostring(vehClass)] and not config.WhitelistedVehicles[vehHash] then
                        local stressSpeed
                        if vehClass == 8 then -- Motorcycle exception for seatbelt
                            stressSpeed = config.MinimumSpeed
                        else
                            stressSpeed = seatbeltOn and config.MinimumSpeed or config.MinimumSpeedUnbuckled
                        end
                        if speed >= stressSpeed then
                            TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                        end
                    end
                end
            end
            Wait(10000)
        end
    end)

    CreateThread(function() -- Shooting
        while true do
            if LocalPlayer.state.isLoggedIn then
                local ped = PlayerPedId()
                local weapon = GetSelectedPedWeapon(ped)
                if weapon ~= `WEAPON_UNARMED` then
                    if IsPedShooting(ped) and not config.WhitelistedWeaponStress[weapon] then
                        if math.random() < config.StressChance then
                            TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                        end
                    end
                else
                    Wait(1000)
                end
            end
            Wait(0)
        end
    end)
end

-- Stress Screen Effects

local function GetBlurIntensity(stresslevel)
    for _, v in pairs(config.Intensity['blur']) do
        if stresslevel >= v.min and stresslevel <= v.max then
            return v.intensity
        end
    end
    return 1500
end

local function GetEffectInterval(stresslevel)
    for _, v in pairs(config.EffectInterval) do
        if stresslevel >= v.min and stresslevel <= v.max then
            return v.timeout
        end
    end
    return 60000
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local effectInterval = GetEffectInterval(stress)
        if stress >= 100 then
            local BlurIntensity = GetBlurIntensity(stress)
            local FallRepeat = math.random(2, 4)
            local RagdollTimeout = FallRepeat * 1750
            TriggerScreenblurFadeIn(1000.0)
            Wait(BlurIntensity)
            TriggerScreenblurFadeOut(1000.0)

            if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                SetPedToRagdollWithFall(ped, RagdollTimeout, RagdollTimeout, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            end

            Wait(1000)
            for _ = 1, FallRepeat, 1 do
                Wait(750)
                DoScreenFadeOut(200)
                Wait(1000)
                DoScreenFadeIn(200)
                TriggerScreenblurFadeIn(1000.0)
                Wait(BlurIntensity)
                TriggerScreenblurFadeOut(1000.0)
            end
        elseif stress >= config.MinimumStress then
            local BlurIntensity = GetBlurIntensity(stress)
            TriggerScreenblurFadeIn(1000.0)
            Wait(BlurIntensity)
            TriggerScreenblurFadeOut(1000.0)
        end
        Wait(effectInterval)
    end
end)

-- Minimap update
CreateThread(function()
    while true do
        SetBigmapActive(false, false)
        SetRadarZoom(1000)
        Wait(500)
    end
end)

local function BlackBars()
    DrawRect(0.0, 0.0, 2.0, w, 0, 0, 0, 255)
    DrawRect(0.0, 1.0, 2.0, w, 0, 0, 0, 255)
end

CreateThread(function()
    local minimap = RequestScaleformMovie('minimap')
    if not HasScaleformMovieLoaded(minimap) then
        RequestScaleformMovie(minimap)
        while not HasScaleformMovieLoaded(minimap) do
            Wait(1)
        end
    end
    while true do
        if w > 0 then
            BlackBars()
            DisplayRadar(0)
            SendNUIMessage({
                action = 'hudtick',
                show = false,
            })
            SendNUIMessage({
                action = 'car',
                show = false,
            })
        end
        Wait(0)
    end
end)

local prevBaseplateStats = { nil, nil, nil, nil, nil, nil, nil, nil }

local function updateBaseplateHud(data)
    local shouldUpdate = false
    for k, v in pairs(data) do
        if prevBaseplateStats[k] ~= v then
            shouldUpdate = true
            break
        end
    end
    prevBaseplateStats = data
    if shouldUpdate then
        SendNUIMessage({
            action = 'baseplate',
            show = data[1],
            street1 = data[2],
            street2 = data[3],
            showCompass = data[4],
            showStreets = data[5],
            showPointer = data[6],
            showDegrees = data[7],
            zone = data[8],
        })
    end
end

local lastCrossroadUpdate = 0
local lastCrossroadCheck = {}

local function getCrossroads(player)
    local updateTick = GetGameTimer()
    if updateTick - lastCrossroadUpdate > 1500 then
        local pos = GetEntityCoords(player)
        local street1, street2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
        lastCrossroadUpdate = updateTick
        -- Zone label ("ALTA", "VINEWOOD HILLS") shown above the street, NP-style.
        lastCrossroadCheck = { GetStreetNameFromHashKey(street1), GetStreetNameFromHashKey(street2), GetLabelText(GetNameOfZone(pos.x, pos.y, pos.z)) }
    end
    return lastCrossroadCheck
end

-- Compass Update loop

CreateThread(function()
    local lastHeading = 1
    local heading
    while true do
        if Menu.isChangeCompassFPSChecked then
            Wait(50)
        else
            Wait(0)
        end
        local show = true
        local player = PlayerPedId()
        local camRot = GetGameplayCamRot(0)
        if Menu.isCompassFollowChecked then
            heading = tostring(RoundNearest(360.0 - ((camRot.z + 360.0) % 360.0)))
        else
            heading = tostring(RoundNearest(360.0 - GetEntityHeading(player)))
        end
        if heading == '360' then heading = '0' end
        if heading ~= lastHeading or menuDirty then
            menuDirty = false
            if IsPedInAnyVehicle(player) then
                local crossroads = getCrossroads(player)
                SendNUIMessage({
                    action = 'update',
                    value = heading
                })
                updateBaseplateHud({
                    show,
                    crossroads[1],
                    crossroads[2],
                    Menu.isShowCompassChecked,
                    Menu.isShowStreetsChecked,
                    Menu.isPointerShowChecked,
                    Menu.isDegreesShowChecked,
                    crossroads[3],
                })
            else
                if Menu.isOutCompassChecked then
                    local crossroads = getCrossroads(player)
                    SendNUIMessage({
                        action = 'update',
                        value = heading
                    })
                    updateBaseplateHud({
                        show,
                        crossroads[1],
                        crossroads[2],
                        Menu.isShowCompassChecked,
                        Menu.isShowStreetsChecked,
                        Menu.isPointerShowChecked,
                        Menu.isDegreesShowChecked,
                        crossroads[3],
                    })
                else
                    prevBaseplateStats = {}
                    SendNUIMessage({
                        action = 'baseplate',
                        show = false,
                    })
                end
            end
        end
        lastHeading = heading
    end
end)
