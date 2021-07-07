## How to create your own extension ##
1. Create a folder in extensions
2. Create a lua file (this is where all your callbacks/hooks will go)
3. If you have commands then add a folder called commands
4. Make sure absolutely no filenames conflict with eachother

## Template ##
> Note: No callbacks are required, you can pick and choose what you need.  

**extensions/template.lua**
```lua
require('addons.vulcan_script.globals')

local modules = {
    utilities = require('addons.vulcan_script.utilities'),
    server = require('addons.vulcan_script.server')
}

M.callbacks = {
    VK_PlayerConnect = function(client_id)
        local client = G_Clients[client_id]
    end,

    VK_PlayerDisconnect = function(client)
        --[[ You can still use all functions in the G_Clients table except for "user" (they no longer exist in-game) ]]--
    end,

    VK_VehicleSpawn = function(vehicle_id, client_id)

    end,

    VK_VehicleRemoved = function(vehicle_id, client_id)

    end,

    VK_VehicleReset = function(vehicle_id, client_id)

    end,

    VK_OnMessageReceive = function(client_id, message)
        --[[
            If you're using my moderation extension and have your own commands then you will want to modify the /help command (I'll automate it one day)
        ]]--
    end,

    VK_OnStdIn = function(input)

    end,

    VK_Tick = function(dt)

    end
}

local function ReloadModules()
    --[[ If you have commands ]]--
    G_RemoveCommandTable(modules.cmd_template.commands)

    modules = G_ReloadModules(modules, 'template.lua')

    --[[ If you have commands ]]--
    G_AddCommandTable(modules.cmd_template.commands)
end

M.callbacks = M.callbacks
M.ReloadModules = ReloadModules

return M
```

Once done, modify your server.json and add your extension to extensions.  
`"extensions": ["template", "if_you_have_any_other_extensions"],`