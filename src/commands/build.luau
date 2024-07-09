local argparse = require("../libs/argparse");
local build = require("../libs/build");
local script_manager = require("../libs/script_manager");

return function()
    script_manager.run_hook("build", function()
        local args = argparse.parse({
            argparse.FlagArgument({"r", "release"})
        });
    
        local mode = if args.get_flag("r") then "release" else "dev";
    
        build.build(mode :: any, {
            
        });
    end);
end