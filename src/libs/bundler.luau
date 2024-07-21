--!nocheck

local fs = require("@lune/fs");
local sys = require("./sys");
local output = require("./output");
local serde = require("@lune/serde");

local luaup = require("../dependencies/luaup");

local bundler = {};

local WIDTH = 100;

local BUNDLE_INDEX = [==[
--[=[
    Epinephrine Bundler

    Index:%s
]=]

--!nocheck
--!nolint

]==]

local BUNDLE_HEADER = [=[
local __EPI_REQUIRE_CACHE = {};
local __EPI_MODULES = {};

local function __EPI_REQUIRE(hash: string): any
    if not __EPI_REQUIRE_CACHE[hash] then
        __EPI_REQUIRE_CACHE[hash] = __EPI_MODULES[hash]();
    end

    return __EPI_REQUIRE_CACHE[hash];
end

]=];

local function header(text: string): string
    local v_ln = ("-"):rep(WIDTH);

    local out = "";
    for _, v in text:split("\n") do
        local t =  "--  "..v;
        local ws = (" "):rep(WIDTH - 2 - #t);
        out ..= t..ws.."--\n";
    end

    return `{v_ln}\n{out}{v_ln}`;
end

local function is_require(call): (boolean, string?)
    local path;

    if not (call.lhs
        and call.lhs.kind == "name"
        and call.lhs.tok.value == "require")
    then
        return false;
    end

    if #call.args.exprs ~= 1 then
        return false;
    end

    local first_exp = call.args.exprs[1].item;

    if first_exp.kind == "string" then
        path = first_exp.tok.value;
        
        local literal_syntax = first_exp.tok.value:sub(1, 1);
        if literal_syntax == "[" then
            return false;
        end

        path = path:sub(2, #path-1);
    elseif first_exp.kind == "istring" and first_exp.istring.kind == "simple" then
        path = first_exp.istring.tok.value;
    else
        return false;
    end

    local start = call.lhs.tok.span.start;
    local finish = call.args.parens.close.span.finish;

    return true, path, {start = start, finish = finish}, call;
end

local function gsub_alias(path: string, aliases: { [string]: string }): string
    if path:sub(1, 1) == "@" then
        path = path:gsub("^(@.-)/", function(alias)
            local new_path = aliases[alias];
            
            if new_path:sub(#new_path, #new_path) ~= "/" then
                new_path ..= "/";
            end

            return new_path;
        end);
    end

    return path;
end

local function get_lines(str: string): number
    return #str:split("\n");
end

function bundler.bundle(entrypoint_path: string, extra_headers: {string}?): string
    local luaurc = sys.luaurc() :: any;
    local aliases = luaurc.aliases or {};
    local files = {};
    local extensions = {"", ".lua", ".luau", "/init.lua", "/init.luau"};

    local function process_file(file_path: string)
        local source = fs.readFile(file_path);
        local source_dir = sys.folder_of(file_path);
        local original_src_hash = serde.hash("sha256", source);
        local write_offset = 0;

        local obj = {
            original_src = source,
            src = source,
            hash = original_src_hash,
            path = file_path,
            metadata = fs.metadata(file_path),
        };

        if files[original_src_hash] then
            return files[original_src_hash];
        end

        local parsed = luaup.ast.parse(source);

        local function recurse(tbl)
            if tbl.kind == "call" then
                local ok, path, span = is_require(tbl.call);
                
                if ok then
                    if path:sub(1, 6) ~= "@lune/" then
                        path = gsub_alias(path, aliases);

                        for _, ext in extensions do
                            local final_path = source_dir .. path .. ext;
                            if fs.isFile(final_path) then
                                local processed = process_file(final_path);

                                local hash = processed.hash;
                                local new_require = ` __EPI_REQUIRE("{hash}") `;

                                local start_byte = span.start.byte;
                                local stop_byte = span.finish.byte;

                                local original_size = stop_byte-start_byte;
                                local new_size = #new_require;
                                local offset = new_size - original_size;

                                local pre = obj.src:sub(1, start_byte-1+write_offset);
                                local suf = obj.src:sub(stop_byte+1+write_offset, #obj.src);
                                obj.src = pre..new_require..suf;

                                write_offset += offset-1;

                                break;
                            end
                        end
                    end
                else
                    if tbl.call.lhs then
                        recurse(tbl.call.lhs);
                    end
                end
            else
                for _, v in tbl do
                    if typeof(v) == "table" then
                        recurse(v);
                    end
                end
            end
        end
        
        files[original_src_hash] = obj;

        recurse(parsed.ast);
        return obj;  
    end

    local index = {};

    local entrypoint = process_file(entrypoint_path);
    
    local bundled = BUNDLE_HEADER;

    local function write_header(file)
        local path = sys.normalise_path(file.path);
        local name = path:split("/");
        bundled ..= header(`\n{name[#name]}\n\nPath: {path}\nHash: {file.hash}\nCreated: {file.metadata.createdAt:toIsoDate()}\nModified: {file.metadata.modifiedAt:toIsoDate()}\n`);
    end

    for hash, file in files do
        table.insert(index, {
            ln = get_lines(bundled),
            file = file,
        });
        write_header(file);
        bundled ..= `\n__EPI_MODULES["{hash}"] = function()\n\n{file.src}\n\nend\n\n\n`
    end

    bundled ..= entrypoint.src;

    local index_str = "";

    local offset = get_lines(BUNDLE_INDEX) + #index - 1;

    for _, entry in index do
        index_str ..= `\n      * Line {entry.ln + offset} = {sys.normalise_path(entry.file.path)} ({entry.file.hash})`
    end

    return BUNDLE_INDEX:format(index_str) .. bundled
end

--[=[function bundler.bundle(entrypoint_path: string, extra_headers: {string}?): string
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

            
            local hash = serde.hash("md5", d_path);
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
            local hash = serde.hash("md5", data.source);

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
]=]
return bundler;