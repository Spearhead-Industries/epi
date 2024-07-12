--!nocheck

local fs = require("@lune/fs");
local process = require("@lune/process");
local output = require("./output");
local sys = require("./sys");

local script_manager = {};

function script_manager.execute_file(file: string)
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
        local cwd = debug.info(3, "s"):match("%[string \"(.-)\"");
        if path:match("^@(.-)$") then
            return o_req(path);
        else
            local src = sys.normalise_path(cwd);
            src = src:split("/");
            table.remove(src, #src);
            src = table.concat(src, "/") .. "/";
            path = sys.normalise_path(src..path);
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

    assert = _G.EPI_OLD_ASSERT;
    pcall(o_req, file); -- Consider converting to a lune run call. Issues with stdin however.
    assert = output.assert;
end

function script_manager.get_scripts(include_hooks: boolean?): {string}
    local scripts = fs.readDir("./scripts/");
    local out = {};
    for i, v in scripts do
        local name = v:match("%./scripts/(.-)%.luau");
        if not name then
            continue;
        end

        if name:sub(1, 2) == "__" and not include_hooks then
            continue;
        end

        table.insert(out, name);
    end
    return out;
end

function script_manager.run_script(name: string)
    if fs.isFile("./scripts/"..name..".luau") then
        script_manager.execute_file(process.cwd.."/scripts/"..name..".luau");
    else
        output.error(`Script '{name}.luau' could not be found`);
    end
end

function script_manager.run_hook(name: string, orelse: ()->()?)
    if fs.isFile("./scripts/__"..name..".luau") then
        script_manager.execute_file(process.cwd.."/scripts/__"..name..".luau");
    else
        if orelse then
            orelse();
        end
    end
end

return script_manager;