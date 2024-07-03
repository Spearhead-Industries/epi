local process = require("@lune/process");
local output = require("../libs/output");
local argparse = require("../libs/argparse");
local build = require("../libs/build");

return function()
    local args = argparse.parse({
        argparse.FlagArgument({"r", "release"})
    });

    local mode = if args.get_flag("r") then "release" else "dev";

    build.build(mode :: any, {
        
    });
end