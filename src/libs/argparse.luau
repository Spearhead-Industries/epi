--!nocheck

local process = require("@lune/process");
local output = require("./output");

type DataType = "string"|"number"|"boolean"|"string?"|"number?"|"boolean?";

local function cooerce_type<_, T>(value: string, datatype: DataType): (boolean, any)
    if datatype == "string" then
        return true, value;
    elseif datatype == "number" then
        local val = tonumber(value);
        return val ~= nil, val;
    elseif datatype == "boolean" then
        if value:lower() == "true" then
            return true, true;
        elseif value:lower() == "false" then
            return true, false;
        end
        return false;
    end

    return false;
end

local function apply_arg_prefix(arg: string): string
    if typeof(arg) == "string" then
        return if #arg == 1 then "-" else "--"..arg;
    else
        return arg;
    end
end

local function string_wrap(val: any): string
    if typeof(val) == "string" then
        return `'{apply_arg_prefix(val)}'`
    elseif typeof(val) == "number" then
        return `#{val}`;
    else
        return `{val}`;
    end
end

local function trim_arg_prefix(arg: string): string
    return arg:gsub("$--?", "");
end

local args_lib = {};

args_lib.no_default = newproxy(false);

type ArgumentSpec = {
    name: {string}|string,
    kind: "named",
    required: boolean?,
    default: any?,
    datatype: DataType,
} | {
    position: number,
    kind: "positional",
    required: boolean?,
    default: any?,
    datatype: DataType,
} | {
    name: {string}|string,
    required: boolean?,
    kind: "flag",
    default: boolean?,
};

local function parse_datatype(raw_datatype: DataType): (DataType, boolean)
    local optional = raw_datatype:sub(-1) == "?";
    local datatype = if not optional then raw_datatype else raw_datatype:sub(1, #raw_datatype-1);
    return datatype, not optional;
end

function args_lib.NamedArgument(name: {string}|string, datatype: DataType?, default: any?): ArgumentSpec
    if name and typeof(name) == "string" then
        name = {name};
    end

    local parsed_dt, required = parse_datatype(datatype or "string");

    return {
        kind = "named",
        name = name,
        datatype = parsed_dt,
        required = required,
        default = default,
    };
end

function args_lib.PositionalArgument(position: number, datatype: DataType?, default: any?): ArgumentSpec
    local parsed_dt, required = parse_datatype(datatype or "string");

    return {
        kind = "positional",
        position = position,
        datatype = parsed_dt,
        required = required,
        default = default,
    };
end

function args_lib.FlagArgument(name: {string}|string): ArgumentSpec
    if name and typeof(name) == "string" then
        name = {name};
    end

    return {
        kind = "flag",
        name = name,
    };
end

type ParsedArgs = {
    get_positional: (position: number)->any,
    get_named: (name: string)->any,
    get_flag: (name: string)->boolean,
    raw_args: {},
};

local function longest_string(strings: {string}): string
    local pos, len = 0, -1;
    for i, v in strings do
        if #v > len then
            len = #v;
            pos = i;
        end
    end

    return strings[pos];
end

function args_lib.parse(specification: {ArgumentSpec}): ParsedArgs
    local args = {
        positional = {},
        named = {},
        flags = {},
    };

    local positional_ended = false;
    
    for i, arg: string in process.args do
        if arg:sub(1, 1) == "-" and arg:sub(2, 2) ~= "-" and arg:find("[^%w%-]") == nil then -- Short Flag
            positional_ended = true;
            
            local flags = arg:sub(2):split("");
            for _, flag in flags do
                table.insert(args.flags, flag);
            end
        elseif arg:sub(1, 2) == "--" or arg:sub(1, 1) == "-" then
            positional_ended = true;
            if not arg:find("=") then -- Long Flag
                table.insert(args.flags, arg:sub(3))
            else -- Named Arg
                local k, v = unpack(arg:split("="));
                if arg:sub(1, 1) == "-" and arg:sub(2, 2) ~= "-" then
                    output.assert(#trim_arg_prefix(k) == 1, "Use '--' instead of '-' to prefix named arguments");
                end
                args.named[trim_arg_prefix(k)] = v;
            end
        else
            output.assert(not positional_ended, "Positional arguments must appear before other argument types");
            args.positional[i-1] = arg;
        end
    end

    local function check_unknown_args(type: string)
        for k, v in args[if type == "flag" then "flags" else type] do
            if k == 0 then
                continue;
            end

            local found = false;
            local descriptor = if type == "flag"
                                then `flag '{apply_arg_prefix(v)}'`
                                else `{type} argument {string_wrap(k)}`;

            for _, spec in specification do
                if spec.kind == type then
                    if
                        (type == "flag" and table.find(spec.name, v))
                        or (type == "named" and table.find(spec.name, k))
                        or (type == "positional" and spec.position == k)
                    then
                        found = true;
                    end
                end
            end
            
            output.assert(found, `Unknown {descriptor}`);
        end
    end

    check_unknown_args("positional");
    check_unknown_args("named");
    check_unknown_args("flag");

    for _, arg_spec in specification do
        if arg_spec.required then
            local found = false;

            for k, v in args[arg_spec.kind] do
                if arg_spec.kind == "positional" then
                    if k == arg_spec.position then
                        found = true; 
                    end
                else
                    if table.find(arg_spec.name, k) then
                        found = true; 
                    end
                end
            end

            if not found then
                output.assert(found, `Missing required {arg_spec.kind} argument {string_wrap(arg_spec.position or arg_spec.name and longest_string(arg_spec.name))}`);
            end
        end
    end

    return {
        get_named = function(name: string): any
            local spec;

            for _, arg_spec in specification do
                if arg_spec.kind == "named" and table.find(arg_spec.name, name) then
                    spec = arg_spec;
                end
            end

            if not spec then
                error(`Cannot get named argument '{name}' as it is not registered in the specification.`, 2);
            end
            
            for k, v in args.named do
                if table.find(spec.name, k) then
                    local cooercion_ok, coorced_v = cooerce_type(v, spec.datatype or "string");
                    output.assert(cooercion_ok, `Named argument {string_wrap(k)} should be of type {spec.datatype}`);
                    return coorced_v;
                end
            end

            if spec.required then
                error(`Unable to find named argument '{name}'`, 2);
            else
                return spec.default;
            end
        end,

        get_positional = function(position: number): any
            local spec;

            for _, arg_spec in specification do
                if arg_spec.kind == "positional" and arg_spec.position == position then
                    spec = arg_spec;
                end
            end

            if not spec then
                error(`Cannot get positional argument #{position} as it is not registered in the specification.`, 2);
            end

            local val = args.positional[position];

            if val then
                local cooercion_ok, coorced_v = cooerce_type(val, spec.datatype or "string");
                output.assert(cooercion_ok, `Positional argument {string_wrap(position)} should be of type {spec.datatype}`);
                return coorced_v;
            elseif spec.required then
                error(`Unable to find positional argument #{position}`, 2);
            else
                return spec.default;
            end
        end,

        get_flag = function(name: string): boolean
            local spec;

            for _, arg_spec in specification do
                if arg_spec.kind == "flag" and table.find(arg_spec.name, name) then
                    spec = arg_spec;
                end
            end

            if not spec then
                error(`Cannot get flag '{name}' as it is not registered in the specification.`, 2);
            end
            
            for k, v in args.flags do
                if table.find(spec.name, v) then
                    return true;
                end
            end

            return false;
        end,

        raw_args = args,
        spec = specification,
    };
end

return args_lib;