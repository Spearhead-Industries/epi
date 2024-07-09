local fs = require("@lune/fs");
local luau = require("@lune/luau");
local manifest_helper = require("./manifest_helper");
local output = require("./output");
local process = require("@lune/process");
local stdio = require("@lune/stdio");

local DIM = stdio.style("dim");
local RESET = stdio.color("reset");
local GREEN = stdio.color("green");
local RED = stdio.color("red");

local IN_PROGRESS_PFX = `[{DIM}  ..  {RESET}]`;
local PASS_PREFIX = `[{GREEN} PASS {RESET}]`;
local FAIL_PREFIX = `[{RED} FAIL {RESET}]`;

local test_runner = {};

function test_runner.run_tests()
    local manifest_ok, manifest = manifest_helper.read();
    assert(manifest_ok and manifest, "Manifest not found");

    local pass = true;

    local test_folder = manifest.tests or "./tests";
    assert(fs.isDir(test_folder), "Test folder not found");
    local tests = fs.readDir(test_folder);
    
    for _, name in tests do
        local message = `{DIM}{test_folder}/{RESET}{name}`;

        local remove = output.write_removable(`{IN_PROGRESS_PFX} {message}`);

        local src = fs.readFile(test_folder.."/"..name);
        local compile_ok, compile_err = pcall(luau.load, src);
        
        if not compile_ok then
            remove();
            output.write(`{FAIL_PREFIX} {message} - Compile err: {compile_err}`);
        end

        local fenv = getfenv(compile_err);
        fenv["assert"] = _G.EPI_OLD_ASSERT;

        local ok, err = pcall(compile_err);

        if ok then
            remove();
            output.write(`{PASS_PREFIX} {message}`);
        else
            pass = false;
            remove();
            err = err:gsub("%[string \"luau%.load%(%.%.%.%)\"]:%d-: ", "");
            output.write(`{FAIL_PREFIX} {message} - {err}`);
        end
    end

    if not pass then
        process.exit(1);        
    end
end

return test_runner;