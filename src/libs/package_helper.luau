local process = require("@lune/process");
local fs = require("@lune/fs");
local serde = require("@lune/serde");
local config = require("../config");
local output = require("./output");
local resolver = require("./resolver");
local sys = require("./sys");
local manifest_helper = require("./manifest_helper");
local t = require("../types");

local package_handler = {};

function package_handler.is_package_installed(name: string): boolean
    return fs.isDir(`{sys.local_dir}/{name:split("/")[1]}`) and fs.isDir(`{sys.local_dir}/{name}`);
end

function package_handler.get_root_dependencies()
    local read_ok, manifest, commit = manifest_helper.read(true);
    assert(read_ok and manifest and commit, "Package manifest not found");

    return manifest.dependencies or {};
end

function package_handler.get_all_dependencies()
    local read_ok, manifest, commit = manifest_helper.read(true);
    assert(read_ok and manifest and commit, "Package manifest not found");

    local total_deps = {};

    local function search(dependencies)
        for _, package in dependencies do
            table.insert(total_deps, package);

            if package_handler.is_package_installed(package) and fs.isFile(`{sys.local_dir}/{package}/{sys.manifest_name}.toml`) then
                local pkgroot = serde.decode("toml", fs.readFile(`{sys.local_dir}/{package}/{sys.manifest_name}.toml`));
                search(pkgroot.dependencies);
            end
        end
    end

    search(manifest.dependencies or {});
    return total_deps;
end

function package_handler.for_each_installed_package(func: (name: string, path: string)->())
    if not fs.isDir(sys.local_dir) then
        return;
    end

    for _, owner_path in fs.readDir(sys.local_dir) do
        for _, pkg_path in fs.readDir(`{sys.local_dir}/{owner_path}`) do
            local pkg = (`{sys.local_dir}/{owner_path}/{pkg_path}`):match(`{sys.escape_gsub(sys.local_dir)}/(.+)$`);
            if pkg then
                func(pkg, sys.local_dir.."/"..pkg);
            end
        end
    end
end

function package_handler.treeshake()
    local valid_dependencies = package_handler.get_all_dependencies();
    
    package_handler.for_each_installed_package(function(name, path)
        if not table.find(valid_dependencies, name) then
            fs.removeDir(path);
            output.write(`Removed {name}`);
        end
    end);

    for _, v in pairs(fs.readDir(sys.local_dir)) do
        if fs.isDir(`{sys.local_dir}/{v}`) and #fs.readDir(`{sys.local_dir}/{v}`) == 0 then
            fs.removeDir(`{sys.local_dir}/{v}`);
        end
    end
end

type InstallPackageOptions = {
    add_dependency: boolean|string?,
    warn_on_already_installed: boolean?,
    dont_reinstall: boolean?
};

function package_handler.install_package(identifier: string, options: InstallPackageOptions?)
    local options = options or {} :: InstallPackageOptions;

    -- Parse package identifier
    local package_data = resolver.parse_identifier(identifier);
    assert(package_data and package_data.valid, "Invalid package identifier");

    -- Edit package manifest
    local read_ok, manifest, commit = manifest_helper.read(true);
    assert(read_ok and manifest and commit, "Package manifest not found");

    assert(package_data.valid, "Invalid package identifier provided");
    
    if options.add_dependency then
        local is_dev_dep = table.find(manifest.dev_dependencies or {} :: any, identifier);
        local is_std_dep = table.find(manifest.dependencies or {} :: any, identifier);
        if options.add_dependency == "dev" then
            output.assert(not is_std_dep, "Package is already installed as a normal dependency");
        else
            output.assert(not is_dev_dep, "Package is already installed as a development dependency");
        end
        
        if options.add_dependency == "dev" and not is_dev_dep then
            manifest.dev_dependencies = manifest.dev_dependencies or {};
            table.insert(manifest.dev_dependencies :: any, package_data.identifier);
        elseif not is_std_dep then
            manifest.dependencies = manifest.dependencies or {};
            table.insert(manifest.dependencies :: any, package_data.identifier);
        end
    end

    commit();
    
    output.write(`Installing {identifier}`);

    -- Download package
    local install_path = `{sys.local_dir}/{package_data.owner}/{package_data.name}`;
    if fs.isDir(install_path) then
        if options.dont_reinstall then
            return;
        end
        if options.warn_on_already_installed then
            output.warn("Package already installed; reinstalling");
        end
        fs.removeDir(install_path);
    end
    sys.ensure_dir_exists(install_path);

    local repo_url = `https://github.com/{package_data.owner}/{package_data.name}.git`;

    output.write(`Downloading package {package_data.owner}/{package_data.name} from GitHub`);

    local git_clone_result;
    if package_data.ref then
        git_clone_result = process.spawn("git", {"clone", "--depth", "1", repo_url, "--branch", package_data.ref, install_path});
        if not git_clone_result.ok then
            -- Maybe they use `v1.0.0` instead of `1.0.0` for tags?
            git_clone_result = process.spawn("git", {"clone", "--depth", "1", repo_url, "--branch", "v"..package_data.ref, install_path});
        end
    else
        git_clone_result = process.spawn("git", {"clone", "--depth", "1", repo_url, install_path});
    end
    
    output.assert(git_clone_result.ok, `Failed to download {identifier} from GitHub:`, git_clone_result.stderr);

    -- Install Package
    fs.removeDir(`{install_path}/.git`);

    local package_has_manifest = fs.isFile(`{install_path}/{sys.manifest_name}`);
    if package_has_manifest then
        local ok, package_manifest = manifest_helper.read(false, `{install_path}/{sys.manifest_name}`);
        if not ok then
            output.warn("Installed package has an invalid manifest file, use with caution");
            return;
        end
        assert(package_manifest);

        -- OS / ARCH warnings --
        if package_manifest.arch and not table.find(package_manifest.arch, process.arch)then
            output.warn("Installed package may not be compatible with this system architecture");
        end

        if package_manifest.os and not table.find(package_manifest.os, process.os)then
            output.warn("Installed package may not be compatible with this operating system");
        end

        -- Include files only --
        local file_globs = package_manifest.files or {"*"};
        local raw_files = sys.read_dir_flat(install_path, true);
        local files_to_keep = {};

        for _, glob in file_globs :: {string} do
            local mid = "";
            if glob:sub(1, 1) ~= "/" then
                mid = "/";
            end
            glob = install_path..mid..glob
            local files = sys.filter_files(raw_files, glob);

            for _, file in files do
                if not table.find(files_to_keep, file) then
                    table.insert(files_to_keep, file);
                end
            end
        end
        
        for _, file in raw_files do
            if not table.find(files_to_keep, file) then
                sys.remove(file);
            end
        end

        -- Add init --
        local has_init = fs.isFile(`{install_path}/init.luau`) or fs.isFile(`{install_path}/init.lua`);
        if not has_init and package_manifest.main then
            local entrypoint;
            if typeof(package_manifest.main) == "table" then
                entrypoint = package_manifest.main.lib;
            else
                entrypoint = package_manifest.main; 
            end
            
            fs.writeFile(`{install_path}/init.luau`, `return require("{entrypoint}")`);
        end

        -- Install Dependencies --
        for _, dependency in package_manifest.dependencies :: any or {} do
            package_handler.install_package(dependency, {
                warn_on_already_installed = false,
                dont_reinstall = true,
                add_dependency = false,
            });
        end
    else
        output.warn(`Installed package is not managed by {config.name}, you may need to navigate to the entrypoint manually`);
    end
end

function package_handler.uninstall_package(identifier: string)
    local read_ok, manifest, commit = manifest_helper.read(true);
    assert(read_ok and manifest and commit, "Package manifest not found");
    manifest.dependencies = manifest.dependencies or {};

    local idx = table.find(manifest.dependencies :: any, identifier);
    assert(idx, `Dependency '{identifier}' is not in the package manifest`);
    
    output.write(`Uninstalling {identifier}`);
    table.remove(manifest.dependencies :: any, idx);
    commit();

    package_handler.treeshake();
end

return package_handler;
