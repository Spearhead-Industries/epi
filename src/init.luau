_G.EPI_OUTPUT_MODE = _G.EPI_OUTPUT_MODE or "CLI";

local process = require("@lune/process");
local output = require("./libs/output");

local api = require("./api");

local function main()
    local command = process.args[1];
    
    if not command then
        output.header();
        process.exit(0); 
    end
    
    local command_func = api.commands[command];
    output.assert(command_func, `Command '{command}' not found`);
    command_func();
    process.exit(0);
end

main();