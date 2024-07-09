--!nolint
--!nocheck

local stdio = require("@lune/stdio");
local process = require("@lune/process");

local config = require("../config");

local LEADER = "  ";

local output = {};

function output.format(format: {stdio.Color|stdio.Style}|(stdio.Color|stdio.Style), text: string)
    if typeof(format) == "string" then
        format = {format};
    end

    local format_header = "";

    for _, fmt in pairs(format) do
        local is_colour, colour = pcall(stdio.color, fmt);
        if is_colour then
            format_header ..= colour;
        else
            local is_style, style = pcall(stdio.style, fmt :: any);
            if is_style then
                format_header ..= style;
            else 
                error(`Format '{fmt}' does not exist.`, 2);
            end
        end
    end

    return format_header .. text .. stdio.color("reset");
end

local ERROR_HEADER = output.format(config.colour_theme.error :: any, "error: ");
local WARN_HEADER = output.format(config.colour_theme.warn :: any, "warn: ");

function output.write_removable(message: string): ()->()
    if _G.EPI_OUTPUT_MODE == "CLI" then
        stdio.write(LEADER .. message);
    end
    
    return function()
        stdio.write(("\b"):rep(#(LEADER .. message)));
        stdio.write((" "):rep(#(LEADER .. message)));
        stdio.write(("\b"):rep(#(LEADER .. message)));
    end
end

function output.write(message: string)
    if _G.EPI_OUTPUT_MODE == "CLI" then
        stdio.write(LEADER .. message .. "\n");
    end
end

function output.warn(message: string, secondary_message: string?)
    if _G.EPI_OUTPUT_MODE == "CLI" then
        stdio.write(LEADER .. WARN_HEADER .. message .. "\n");
        if secondary_message then
            stdio.write(LEADER .. secondary_message .. "\n");
        end
    else
        warn(message);
    end
end

function output.error(message: string, secondary_message: string?)
    if _G.EPI_OUTPUT_MODE == "CLI" then
        stdio.ewrite(LEADER .. ERROR_HEADER .. message .. "\n");
        if secondary_message then
            stdio.ewrite(LEADER .. secondary_message .. "\n");
        end
        process.exit(1);
        error(message, 2);
    else
        error(message, 2);
    end
end

function output.assert(condition: any?, message: string, secondary_message: string?)
    if not condition then
        output.error(message, secondary_message);
    end
end

function output.header()
    if _G.EPI_OUTPUT_MODE == "CLI" then
        stdio.write(`{output.format(config.colour_theme.author :: any, config.author)}/{output.format(config.colour_theme.primary :: any, config.name.long)} v{config.version}`);
    end
end

if _G.EPI_OUTPUT_MODE == "CLI" then
    _G.EPI_OLD_ASSERT = assert;
    assert = output.assert;
end

return output;
