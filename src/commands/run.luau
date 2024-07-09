--!nocheck

local manifest_helper = require("../libs/manifest_helper");
local script_manager = require("../libs/script_manager");

return function()
    script_manager.run_hook("run", function()
        local ok, manifest = manifest_helper.read(false);
        assert(ok and manifest, "Package manifest not found");
        assert(manifest.main, "Package manifest does not have an entrypoint");
    
        script_manager.execute_file(manifest.main.bin or manifest.main);
    end);
end