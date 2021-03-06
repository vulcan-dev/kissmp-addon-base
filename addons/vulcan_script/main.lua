--[[
    Created by Daniel W (Vitex#1248)
]]

require('addons.vulcan_script.globals')

local modules = {
    utilities = require('addons.vulcan_script.utilities'),
    timed_events = require('addons.vulcan_script.timed_events'),
    server = require('addons.vulcan_script.server')
}

local extensions = {}
local prefix = '/'

-- [[ ==================== Hooking Start ==================== ]] --
hooks.register('OnPlayerConnected', 'VK_PLAYER_CONNECT', function(client_id)
    --[[ Add Client to Table ]]--
    modules.server.AddClient(client_id)
    local client = G_Clients[client_id]

    --[[ Load Extension Hook VK_PlayerConnect ]]--
    for _, extension in pairs(extensions) do
        if extension.callbacks.VK_PlayerConnect then
            extension.callbacks.VK_PlayerConnect(client_id)
        end
    end
end)

hooks.register('OnPlayerDisconnected', 'VK_PLAYER_DISCONNECT', function(client_id)
    local oldClient = G_Clients[client_id]
    G_Clients[client_id].connected = false
    modules.server.RemoveClient(client_id)

    modules.utilities.Log({level=G_LevelInfo}, string.format("%s has Disconnected [ %s ]", oldClient.user:getName(), oldClient.user:getSecret()))

    --[[ Load Extension Hook VK_PlayerDisconnect ]]--
    for _, extension in pairs(extensions) do
        if extension.callbacks.VK_PlayerDisconnect then
            extension.callbacks.VK_PlayerDisconnect(oldClient)
        end
    end

    oldClient = nil
end)

hooks.register('OnVehicleSpawned', 'VK_PLAYER_VEHICLE_SPAWN', function(vehicle_id, client_id)
    --[[ Load Extension Hook VK_VehicleSpawn ]]--
    for _, extension in pairs(extensions) do
        if extension.callbacks.VK_VehicleSpawn then
            extension.callbacks.VK_VehicleSpawn(vehicle_id, client_id)
        end
    end

    modules.utilities.Log({level=G_LevelDebug}, string.format('%s vehicle count: %d', G_Clients[client_id].user:getName(), G_Clients[client_id].vehicleCount))
end) -- Vehicle Spawned

hooks.register('OnVehicleRemoved', 'VK_PLAYER_VEHICLE_REMOVED', function(vehicle_id, client_id)
    --[[ Load Extension Hook VK_VehicleRemoved ]]--
    for _, extension in pairs(extensions) do
        if extension.callbacks.VK_VehicleRemoved then
            extension.callbacks.VK_VehicleRemoved(vehicle_id, client_id)
        end
    end
end)

hooks.register('OnVehicleResetted', 'VK_PLAYER_VEHICLE_RESET', function(vehicle_id, client_id)
    --[[ Load Extension Hook VK_VehicleReset ]]--
    for _, extension in pairs(extensions) do
        if extension.callbacks.VK_VehicleReset then
            extension.callbacks.VK_VehicleReset(vehicle_id, client_id)
        end
    end
end)

hooks.register('OnChat', 'VK_PLAYER_CHAT', function(client_id, message)
    local executor = G_Clients[client_id]

    --[[ Check if the Client is Muted ]]--
    if extensions['vulcan_moderation'] then
        local mute_time = modules.utilities.GetKey(G_PlayersLocation, executor.user:getSecret(), 'mute_time')
        if mute_time ~= nil and mute_time > 0 then
            if mute_time <= os.time() then
                modules.utilities.Log({level=G_LevelDebug}, 'You have been unmuted')
                modules.utilities.EditKey(G_PlayersLocation, executor.user:getSecret(), 'mute_time', 0)
            else
                modules.server.SendChatMessage(executor.user:getID(), 'You are muted', modules.server.ColourError)
                return ""
            end
        end
    end

    --[[ Execute Command ]]
    if G_Commands then
        modules.utilities.Log({level=G_LevelInfo}, string.format('%s said: %s', G_Clients[client_id].user:getName(), message))
        if string.sub(message, 1, 1) == prefix then
            local args = modules.utilities.ParseCommand(message, ' ')
            args[1] = args[1]:sub(2)

            local command = G_Commands[args[1]]

            if command then
                if executor.GetRank() >= command.rank then
                    table.remove(args, 1)
                    G_Try(function ()
                        command.exec(executor, args)
                    end, function(err)
                        modules.server.SendChatMessage(executor.user:getID(), string.format('[ %s Failed. Please report it on the github ]\nMessage: %s', message, err), modules.server.ColourError)
                        modules.utilities.Log({level=G_LevelError}, string.format('Command failed! User: %s\n  Message: %s', executor.user:getName(), err))
                        return ""
                    end)
                end
            else
                modules.server.SendChatMessage(executor.user:getID(), 'Invalid Command, please use /help', modules.server.ColourWarning)
            end
        else
            if extensions['vulcan_moderation'] then
                modules.moderation.SendUserMessage(executor, message)
            else
                modules.server.SendChatMessage(executor.user:getName() .. ': ' .. message)
            end
        end
    else
        modules.server.SendChatMessage(executor.user:getName() .. ': ' .. message)
    end

    --[[ Load Extension Hook VK_OnMessageReceive ]]--
    for _, extension in pairs(extensions) do
        if extension.callbacks.VK_OnMessageReceive then
            extension.callbacks.VK_OnMessageReceive(client_id, message)
        end
    end

    return ""
end) -- OnChat

hooks.register('OnStdIn', 'VK_PLAYER_STDIN', function(input);
    --[[ Reload all Modules ]]--
    if input == '!rl' then
        G_ServerLocation = './addons/vulcan_script/settings/server.json'

        G_PlayersLocation = './addons/vulcan_script/settings/players.json'
        G_ColoursLocation = './addons/vulcan_script/settings/colours.json'

        modules = G_ReloadModules(modules, 'main.lua')

        --[[ Reload all Extensions & Modules ]]--
        extensions = G_ReloadExtensions(extensions)
        for _, v in pairs(extensions) do v.ReloadModules() end

        -- Load all extensions

        for _, v in pairs(modules.utilities.GetKey(G_ServerLocation, 'options', 'extensions')) do
            extensions[v] = G_Try(function()
                package.loaded[v] = nil
                return require(string.format('addons.vulcan_script.extensions.%s.%s', v, v))
            end, function()
                modules.utilities.Log({level=G_LevelFatal}, '[Extension] Failed Loading Extension: '..v)
            end)

            modules.utilities.Log({level=G_LevelDebug}, '[Extension] Reloaded Extension: '..v)
        end

        if G_Level < G_LevelDebug then modules.utilities.Log({level=G_LevelInfo}, 'Successfully reloaded all extensions and modules') end

    end

    for _, extension in pairs(extensions) do
        if extension.callbacks.VK_OnStdIn then
            extension.callbacks.VK_OnStdIn(input)
        end
    end
end)

hooks.register("Tick", "VK_TICK", function()
    modules.timed_events.Update()

    -- Server uptime
    G_Uptime = G_Uptime + 1

    -- Update extension hook
    for _, extension in pairs(extensions) do
        if extension.callbacks.VK_Tick then
            extension.callbacks.VK_Tick(1 - 60)
        end
    end
end)
-- [[ ==================== Hooking End ==================== ]] --

local function Initialize()
    --[[ Make sure to change the log level if you don't want console spam :) ]]--
    G_Level = G_LevelDebug
    modules.utilities.Log({level=G_LevelInfo}, '[Server] Initialized')

    modules = G_ReloadModules(modules, 'main.lua')

    --[[ Load all Extensions ]]--
    for _, v in pairs(modules.utilities.GetKey(G_ServerLocation, 'options', 'extensions')) do
        extensions[v] = G_Try(function()
            return require(string.format('addons.vulcan_script.extensions.%s.%s', v, v))
        end, function()
            modules.utilities.Log({level=G_LevelFatal}, '[Extension] Failed Loading Extension: '..v)
        end)

        modules.utilities.Log({level=G_LevelDebug}, '[Extension] Loaded Extension: '..v)
    end

    --[[ Load all Extension Modules ]]--
    for _, v in pairs(extensions) do
        v.ReloadModules()
    end

    G_Verbose = modules.utilities.GetKey(G_ServerLocation, 'log', 'verbose')
    G_LogFile = modules.utilities.GetKey(G_ServerLocation, 'log', 'file')

    G_DiscordLink = modules.utilities.GetKey(G_ServerLocation, 'options', 'discord_link')
    G_PatreonLink = modules.utilities.GetKey(G_ServerLocation, 'options', 'patreon_link')

    prefix = modules.utilities.GetKey(G_ServerLocation, 'options', 'command_prefix')

    --[[ Set Colours ]]--
    modules.server.ColourSuccess = modules.utilities.GetColour(modules.utilities.GetKey(G_ColoursLocation, 'Success'))
    modules.server.ColourWarning = modules.utilities.GetColour(modules.utilities.GetKey(G_ColoursLocation, 'Warning'))
    modules.server.ColourError = modules.utilities.GetColour(modules.utilities.GetKey(G_ColoursLocation, 'Error'))

    --[[ Create Console ]]--
    G_Clients[1337] = modules.server.consolePlayer

    if modules['vulcan_moderation'] then
        modules.moderation = require('addons.vulcan_script.extensions.vulcan_moderation.moderation')
    end
end

Initialize()