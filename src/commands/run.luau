--!nocheck

local process = require("@lune/process");
local output = require("../libs/output");
local manifest_helper = require("../libs/manifest_helper");

local sys = require("../libs/sys");

return function()
    local ok, manifest = manifest_helper.read(false);
    assert(ok and manifest, "Package manifest not found");
    assert(manifest.main, "Package manifest does not have an entrypoint");

    local args = table.clone(process.args);
    table.remove(args, 1)
    table.freeze(args);

    local fake_process = {};
    for k, v in pairs(process) do
        fake_process[k] = v;
    end

    fake_process.args = args;

    table.freeze(fake_process);

    local o_req;
    o_req = require;
    local function req(path: string)
        if path:match("^@(.-)$") then
            return o_req(path);
        else
            local src = sys.normalise_path(debug.info(3, "s"):match("%[string \"(.-)\""));
            src = src:split("/");
            table.remove(src, #src);
            src = table.concat(src, "/") .. "/";

            path = sys.normalise_path(process.cwd..src..path);
        end

        return o_req(path);
    end

    require = function(request: string)
        if request == "@lune/process" then
            return fake_process;
        else
            return req(request);
        end
    end

    print(pcall(function()
        o_req(manifest.main.bin or manifest.main); -- Consider converting to a lune run call. Issues with stdin however.
    end));
end