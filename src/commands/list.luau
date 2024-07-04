local output = require("../libs/output");
local package_helper = require("../libs/package_helper");
local argparse = require("../libs/argparse");

return function()
    local args = argparse.parse({
        argparse.FlagArgument({"all", "a"}), 
    });
    
    local packages = {};

    if args.get_flag("all") then
        packages = package_helper.get_all_dependencies();
    else
        packages = package_helper.get_root_dependencies();
    end

    for _, v in packages do
        output.write(`- {v}`);
    end
end