local process = require("@lune/process");
local output = require("../libs/output");
local argparse = require("../libs/argparse");
local package_helper = require("../libs/package_helper");

return function()
    local args = argparse.parse({
        argparse.PositionalArgument(1, "string"),
    })

    local identifier = args.get_positional(1);
    package_helper.uninstall_package(identifier);
end