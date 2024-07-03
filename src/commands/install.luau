local process = require("@lune/process");
local output = require("../libs/output");
local argparse = require("../libs/argparse");
local package_helper = require("../libs/package_helper");

return function()
    local args = argparse.parse({
        argparse.PositionalArgument(1, "string?"),
        argparse.FlagArgument({"d", "dev"}),
    })

    local identifier = args.get_positional(1);
    if identifier then
        package_helper.install_package(identifier, {
            add_dependency = if args.get_flag("dev") then "dev" else true,
            warn_on_already_installed = true,
        });
    else
        -- setup
    end
end