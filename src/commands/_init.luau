local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local fs = require("@lune/fs");
local argparse = require("../libs/argparse");
local manifest_helper = require("../libs/manifest_helper");
local sys = require("../libs/sys");

local ALREADY_EXIST_MESSAGE = "A manifest file already exists, would you like to overwrite?";

return function()
    local args = argparse.parse({
        argparse.FlagArgument({"d", "dont_prompt"}),
        argparse.FlagArgument({"o", "overwrite"}),
    });

    local dont_prompt = args.get_flag("dont_prompt");
    local overwrite = args.get_flag("overwrite");
    local questionnaire = {};

    if manifest_helper.exists() and not overwrite then
        if 
            dont_prompt
            or (not stdio.prompt("confirm", ALREADY_EXIST_MESSAGE))
        then
            return;
        end
    end

    if not dont_prompt then
        questionnaire = {
            name = stdio.prompt("text", "Package Name", sys.cwd_name),
            version = stdio.prompt("text", "Package Version", "0.1.0"),
            main = stdio.prompt("text", "Package Entrypoint", "./src/init.luau"),
            owner = stdio.prompt("text", "Package Owner", sys.username),
            description = stdio.prompt("text", "Package Description"),
            keywords = stdio.prompt("text", "Package Keywords (seperated by ';')"):split(";"),
            repository = stdio.prompt("text", "Package Repository"),
        };
    end

    manifest_helper.save(manifest_helper.new(questionnaire));
    
    if not fs.isFile("./.gitignore") then
        fs.writeFile("./.gitignore", "");
    end

    local git_ignore = fs.readFile("./.gitignore");
    if string.find(git_ignore, "# EPI") == nil then
        fs.writeFile("./.gitignore", "# EPI\n\n/dist\n/.epinephrine\n\n"..git_ignore);
    end

    if not fs.isFile("./.luaurc") then
        fs.writeFile("./.luaurc", "{}");
    end

    local luaurc = serde.decode("json", fs.readFile("./.luaurc"));
    luaurc.aliases = luaurc.aliases or {};
    luaurc.aliases["pkg"] = `{sys.local_dir}/`;
    fs.writeFile("./.luaurc", serde.encode("json", luaurc, true))
    
    if not fs.isDir("./.vscode") then
        fs.writeDir("./.vscode");
    end

    if not fs.isFile("./.vscode/settings.json") then
        fs.writeFile("./.vscode/settings.json", "{}");
    end
    
    local vscode_settings = serde.decode("json", fs.readFile("./.vscode/settings.json"));
    vscode_settings["luau-lsp.require.directoryAliases"] = vscode_settings["luau-lsp.require.directoryAliases"] or {};
    vscode_settings["luau-lsp.require.directoryAliases"]["@pkg/"] = `{sys.local_dir}/`;
    vscode_settings["luau-lsp.require.directoryAliases"]["@lune/"] = "~/.lune/.typedefs/0.8.5/";
    vscode_settings["luau-lsp.require.mode"] = "relativeToFile";
    fs.writeFile("./.vscode/settings.json", serde.encode("json", vscode_settings, true));

    sys.ensure_file_exists(questionnaire.main, "print(\"Hello, World!\");");
end