local fs = require("@lune/fs");
local serde = require("@lune/serde");
local config = require("../config");
local output = require("./output");
local sys = require("./sys");
local t = require("../types");

local MANIFEST_PATH = `./{sys.manifest_name}`;
local MANIFEST_DEFAULTS = {
    owner = sys.username,
    files = {"*"},
    dependencies = {},
    description = "",
    keywords = {},
    repository = "",

    dev_dependencies = {},
    contributors = {},
    private = false, 
    arch = {},
    os = {},
    runtimes = {},
    build_config = nil,
    documentation = "",
};

local manifest_helper = {};

function manifest_helper.new(questionnaire: {[string]: any}): t.PackageManifest
    return {
        name = questionnaire.name or sys.cwd_name,
        version = questionnaire.version or "0.1.0",
        main = questionnaire.main or "./src/init.luau",

        owner = questionnaire.owner or sys.username,
        files = {"*"},
        dependencies = {},
        description = questionnaire.description or "",
        keywords = questionnaire.keywords or {},
        repository = questionnaire.repository or "",
    };
end

function manifest_helper.read(modifiable: boolean?, path: string?): (boolean, t.PackageManifest?, ()->()?)
    local manifest_path = path or MANIFEST_PATH;
    if not fs.isFile(manifest_path) then
        return false;
    end

    local read_ok, raw_manifest = pcall(fs.readFile, manifest_path);
    output.assert(read_ok, "Failed to read package manifest", raw_manifest);

    local parse_ok, parsed_manifest = pcall(serde.decode, "toml" :: "toml", raw_manifest);
    output.assert(parse_ok, "Failed to parse package manifest", parsed_manifest);

    local function commit()
        manifest_helper.save(parsed_manifest);
    end

    return true, setmetatable(parsed_manifest, MANIFEST_DEFAULTS), if modifiable then commit else nil;
end

function manifest_helper.save(manifest: t.PackageManifest, path: string?)
    local manifest_path = path or MANIFEST_PATH;
    local serialised = serde.encode("toml", manifest);
    fs.writeFile(manifest_path, serialised);
end

function manifest_helper.exists()
    return fs.isFile(MANIFEST_PATH);
end

return manifest_helper;
