local process = require("@lune/process");
local stdio = require("@lune/stdio");
local script_manager = require("../libs/script_manager");

return function()
    local script_name = process.args[2];

    if not script_name then
        local scripts = script_manager.get_scripts();
        script_name = scripts[stdio.prompt("select", "Select script", scripts)];
        
        script_manager.run_script(script_name);
    else
        script_manager.run_script(script_name);
    end
end