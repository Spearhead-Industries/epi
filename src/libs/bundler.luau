--!nocheck

local fs = require("@lune/fs");
local sys = require("./sys");
local output = require("./output");
local hashlib = require("../dependencies/hashlib");
local bundler = {};

local BUNDLE_HEADER = [[
local __EPI_REQUIRE_CACHE = {};
local __EPI_MODULES = {};

local function __EPI_REQUIRE(hash: string): any
    if not __EPI_REQUIRE_CACHE[hash] then
        __EPI_REQUIRE_CACHE[hash] = __EPI_MODULES[hash]();
    end

    return __EPI_REQUIRE_CACHE[hash];
end
]];

function bundler.bundle(entrypoint_path: string, extra_headers: {string}?): string
    local start_t = os.clock();
    local luaurc = sys.luaurc() :: any;
    local aliases = luaurc.aliases or {};
    local extensions = {"", ".lua", ".luau", "/init.lua", "/init.luau"};
    local dependencies = {};

    local function process_file(file_path: string)
        local source = fs.readFile(file_path);
        local source_dir = sys.folder_of(file_path);
        local require_hashes = {};

        -- Pass One: Identify dependencies and replace requires with intermediates
        source = source:gsub("require%([\"']([^\"'{]-)[\"']%)", function(d_path)
            --[[d_path = d_path:gsub("!!EPI_BUNDLER_TEMP_RM:(%d-)!!", function(id)
                return temp_hidden[id];
            end);]]

            if d_path:match("^@lune/") then
                return nil :: any;
            end

            local alias = d_path:match("^@(.-)/");
            if alias and aliases[alias] then
                d_path = d_path:gsub("^(@.-)/", aliases[alias]);
            else
                d_path = source_dir .. d_path;
            end

            
            local hash = hashlib.md5(d_path);
            require_hashes[hash] = d_path;
            return `__EPI_IM("{hash}")`;
        end);

        -- Restore hidden false-positive sources.
        --[[source = source:gsub("!!EPI_BUNDLER_TEMP_RM:(%d-)!!", function(id)
            return temp_hidden[id];
        end);]]

        -- Pass Two: Load dependencies (seperation required due to C yield boundry)
        for hash, d_path in require_hashes do
            local found = false;
            for _, v in pairs(extensions) do
                if fs.isFile(d_path .. v) then
                    found = true;
                    require_hashes[hash] = {
                        source = process_file(d_path .. v),
                        path = d_path .. v,
                    } :: any;
                    break;
                end
            end

            output.assert(found, `Couldn't find {d_path} (Required in {file_path})`);
        end

        -- Pass Three: Replace intermediates with final require calls
        return source:gsub("__EPI_IM%(\"(.-)\"%)", function(src_hash)
            local data = require_hashes[src_hash];
            if not data then
                return
            end
            local hash = hashlib.md5(data.source);

            if not dependencies[hash] then
                dependencies[hash] = data;
            end

            return `__EPI_REQUIRE("{hash}")`;
        end);
    end
    
    local entrypoint_source = process_file(entrypoint_path);
    local file_map = {};
    local comment_length = 100;
    local output = BUNDLE_HEADER;

    local extra_header = "";

    for i, v in pairs(extra_headers or {}) do
        extra_header ..= "\n" .. v .. "\n";
    end

    output ..= extra_header;

    local function write_file(path, contents)
        output ..= "\n\n";
        output ..= string.rep("-", comment_length) .. "\n";
        output ..= `-- File: {path}{string.rep(" ", comment_length - 2 - (9 + #path))}--\n`;

        table.insert(file_map, {
            path = path,
            line =  sys.line_count(output),
        });

        output ..= string.rep("-", comment_length) .. "\n\n";
        output ..= contents;
    end

    for hash, data in pairs(dependencies) do
        write_file(sys.normalise_path(data.path), 
            `__EPI_MODULES["{hash}"] = function()\n\n`
            .. "-- v Original File Start v --\n" .. data.source .. "\n-- ^  Original File End  ^ --"
            .. "\nend\n"
        );
    end

    write_file("[ENTRYPOINT] "..entrypoint_path, entrypoint_source);

    local time_taken = math.round((os.clock() - start_t) * 1000000) / 1000;

    local header = 
        (`--[[\n\tBundled with Luau Package Manager v{_G.VERSION} (https://github`
        .. `.com/Spearhead-Industries/EPI) in {time_taken}ms\n\n\tIndex:`)
        :gsub("\t", "    ");
    
    local header_line_overhead = sys.line_count(header) + 5;

    for i, file in file_map do
        header ..= `\n    - line {file.line + header_line_overhead} = {file.path}`;
        
        if i == #file_map then
            header ..= "\n]]\n\n";
        end
    end

    return header .. output;
end

return bundler;