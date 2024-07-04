_G.EPI_OUTPUT_MODE = _G.EPI_OUTPUT_MODE or "CLI";

local process = require("@lune/process");
local output = require("./libs/output");

local api = require("./api");

local function main()
    local command = process.args[1] :: string;
    
    if not command then
        output.header();
        process.exit(0); 
    end
    
    local command_func = api.commands[command];

    if not command_func then
        for command_name, aliases: any in api.command_aliases do
            if table.find(aliases, command) then
                command_func = api.commands[command_name];
            end
        end
    end
    
    output.assert(command_func, `Command '{command}' not found`);
    command_func();
    process.exit(0);
end

main();