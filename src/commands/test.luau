local process = require("@lune/process");
local stdio = require("@lune/stdio");
local script_manager = require("../libs/script_manager");
local test_runner = require("../libs/test_runner");

return function()
    script_manager.run_hook("test", function()
        test_runner.run_tests();
    end);
end