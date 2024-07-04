local sys = require("./libs/sys");

sys.ensure_dir_exists(sys.global_dir);
sys.ensure_dir_exists(`{sys.global_dir}/binaries`);

local api = {};

api.command_aliases = {
    install  = { "i" },
    uninstall = { "ui" },
    run = { "r" },
    ["run-script"] = { "rs" },
    list = { "ls" },
    build = { "b" },
    treeshake = { "ts" },
};

api.commands = {
    ["install"] = require("./commands/install"),
    ["uninstall"] = require("./commands/uninstall"),
    ["run"] = require("./commands/run"),
    ["init"] = require("./commands/_init"),
    ["build"] = require("./commands/build"),
    ["treeshake"] = require("./commands/treeshake"),
    ["run-script"] = require("./commands/run_script"),
    ["list"] = require("./commands/list"),
};

return api;