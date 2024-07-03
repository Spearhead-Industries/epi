--!nocheck

local fs = require("@lune/fs");
local net = require("@lune/net");
local process = require("@lune/process");
local luau = require("@lune/luau");
local roblox = require("@lune/roblox");

local output = require("./output");
local bundler = require("./bundler");
local t = require("../types");
local sys = require("./sys");
local config = require("../config");
local manifest_helper = require("./manifest_helper");
local zip = require("../dependencies/zzlib");

local MAGIC = "cr3sc3nt";

local build = {};

function build.get_local_runtime(): string
    local where = process.spawn((if sys.win then "where" else "whereis"), {"lune"});
    local path = sys.normalise_eol(where.stdout):split("\n")[1]:gsub("%s", "");
    
    if fs.isFile(path) then
        return fs.readFile(path);
    end

    error("Lune runtime not found, do you have it installed and in your PATH?");
end

function build.patch_binary(runtime: string, bytecode: string): string
    return runtime .. bytecode .. string.pack(">I8", #bytecode) .. MAGIC;
end

function build.get_remote_runtime(os: string, arch: string, version: string?): string
    local cache_name = `{sys.global_dir}/binaries/{config.lune_version}-{os}-{arch}`;

    if fs.isFile(cache_name) then
        return fs.readFile(cache_name);
    end

    local url = string.format(
        "https://github.com/lune-org/lune/releases/download/v%s/lune-%s-%s-%s.zip",
        version or config.lune_version, version or config.lune_version, os, arch
    );

    local container = net.request(url);
    
    local runtime = zip.unzip(container.body, `lune{if os == "windows" then ".exe" else ""}`);
    fs.writeFile(cache_name, runtime);

    return runtime;
end

local function run(cmd: string)
    local arguments = cmd:split(" ");
    local command = table.remove(arguments, 1);
    process.spawn(command, arguments, { stdio = "none" });
end

local function compress(a: string, b: string)
    if sys.win then
        run(`powershell Compress-Archive {a} {b} -Force`);
    else
        run(`zip {b} {a}`);
    end
end

local targets = {
    "windows-x86_64",
    "linux-aarch64",
    "macos-aarch64",
    "linux-x86_64",
    "macos-x86_64",
    "all",
};

function build.build(mode: "dev"|"release"?, overrides: {[any]: any}?)
    if fs.isDir("./dist/") then
        fs.removeDir("./dist/");
    end
    fs.writeDir("./dist/");
    
    local DEFAULT_RESOURCE_FOLDER = if fs.isDir("./resources") then "./resources" else nil;
    local DEFAULT_OPT_LVL = if mode == "release" then 2 else 1;
    local DEFAULT_DBG_LVL = if mode == "release" then 0 else 1;
    local DEFAULT_CV_LVL = if mode == "release" then 0 else 0;
    local DEFAULT_TARGET = if mode == "release" then "all" else "dev";
    local DEFAULT_ZIP = if mode == "release" then true else false;

    overrides = overrides or {};

    local ok, manifest = manifest_helper.read(false);
    assert(ok and manifest, "No manifest")

    local b_config = {};

    if manifest.build_config and manifest.build_config.release and mode == "release" then
        b_config = manifest.build_config.release;
        setmetatable(b_config, {__index = manifest.build_config});
    elseif manifest.build_config and manifest.build_config.dev and mode == "dev" then
        b_config = manifest.build_config.dev;
        setmetatable(b_config, {__index = manifest.build_config});
    else
        b_config = manifest.build_config or b_config;
    end

    b_config.resource_folder = overrides.resource_folder or b_config.resource_folder or DEFAULT_RESOURCE_FOLDER;
    b_config.optimisation_level = overrides.optimisation_level or b_config.optimisation_level or DEFAULT_OPT_LVL;
    b_config.coverage_level = overrides.coverage_level or b_config.coverage_level or DEFAULT_CV_LVL;
    b_config.debug_level = overrides.debug_level or b_config.debug_level or DEFAULT_DBG_LVL;
    b_config.target = overrides.target or b_config.target or DEFAULT_TARGET;
    b_config.zip = overrides.zip or b_config.zip or DEFAULT_ZIP;
    b_config.lune_version = overrides.lune_version or b_config.lune_version or config.lune_version;
    b_config.name = overrides.name or b_config.name or manifest.name;

    local bundled = bundler.bundle(manifest.main); -- do resource header
    local bytecode = luau.compile(bundled, {
        optimizationLevel = b_config.optimisation_level,
        debugLevel = b_config.debug_level,
        coverageLevel = b_config.coverage_level,
    });

    
    
    local target = b_config.target;
    local out_name = b_config.name;

    if not target or target == "dev" then
        local EXT = if sys.win then ".exe" else "";
        local BINARY_NAME = `./dist/{out_name}`..EXT;
        fs.writeFile(BINARY_NAME, build.patch_binary(build.get_local_runtime(), bytecode));
        fs.writeFile(`./dist/{out_name}.luau`, bundled);
        elseif target == "bytecode" then
        fs.writeFile(`./dist/{out_name}.luauc`, bytecode);
    elseif target == "bundled" then
        fs.writeFile(`./dist/{out_name}.luau`, bundled);
    elseif target == "rbxm" then
        fs.writeFile(`./dist/{out_name}.luau`, bundled);
        local rbxm_root = roblox.Instance.new("Script");
        rbxm_root.Name = out_name;
        rbxm_root.Source = bundled;
        fs.writeFile(`./dist/{out_name}.rbxm`, roblox.serializeModel({rbxm_root}));
    elseif table.find(targets, target) then
        local function create_release(bytecode: string, os: string, arch: string)
            local ext = if os == "windows" then ".exe" else "";
            local name = if target == "all"
                            then `./dist/{out_name}-{os}-{arch}{ext}`
                            else `./dist/{out_name}{ext}`;
            
            output.write(`Getting remote runtime for {os}-{arch}.`);
            local runtime = build.get_remote_runtime(os, arch, b_config.lune_version);
            
            output.write(`Creating binary for {os}-{arch}`);
            fs.writeFile(name, build.patch_binary(runtime, bytecode));
            
            if b_config.zip then
                output.write(`Creating .zip for {os}-{arch}`);
                compress(name, `./dist/{out_name}-{os}-{arch}`);
            end

            output.write(`Created binary for {os}-{arch}.`);
        end
        
        if target == "all" then
            fs.writeFile(`./dist/{out_name}.luau`, bundled);
            fs.writeFile(`./dist/{out_name}.luauc`, bytecode);
            create_release(bytecode, "windows", "x86_64");
            create_release(bytecode, "linux", "aarch64");
            create_release(bytecode, "linux", "x86_64");
            create_release(bytecode, "macos", "aarch64");
            create_release(bytecode, "macos", "x86_64"); 
        else
            create_release(bytecode, unpack(target:split("-")));
        end
        
        output.write("Building complete.");

    else
        output.error(`Unknown target '{target}'`)
    end
end

return build;