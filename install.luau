--[[
    Epinephrine Install Script
    Spearhead Industries
]]

--!nocheck
--!nolint

local net = require("@lune/net");
local process = require("@lune/process");
local stdio = require("@lune/stdio");
local serde = require("@lune/serde");
local luau = require("@lune/luau");
local fs = require("@lune/fs");

local ext = if process.os == "windows" then ".exe" else "";
local previous_message;

local function remove_previous_message()
    local len = #previous_message;
    stdio.write(("\b"):rep(len));
    stdio.write((" "):rep(len));
    stdio.write(("\b"):rep(len));
end

local function write(message: string)
    previous_message = message;
    stdio.write(message);
end

local function log(message: string, level: "info"|"warn"|"error"|"waiting"|"done"?, dont_cr: boolean?)
    local indicator;

    if not level or level == "info" then
        indicator = stdio.color("blue").."* "..stdio.color("reset");
    elseif level == "warn" then
        indicator = stdio.color("yellow").."! "..stdio.color("reset");
    elseif level == "done" then
        indicator = stdio.color("green").."✔ "..stdio.color("reset");
    elseif level == "error" then
        indicator = stdio.color("red").."! "..stdio.color("reset");
    elseif level == "waiting" then
        dont_cr = true;
        indicator = stdio.style("dim").."* "..stdio.color("reset");
    end

    write(indicator..message..if not dont_cr then "\n" else "");
end

assert = function(condition, message)
    if not condition then
        log(message, "error");
        process.exit(1);
    end
end

local function require_remote(url: string)
    local src = net.request(url);
    assert(src.ok, `Failed to download "{url}" ({src.statusCode})`);
    return luau.load(src.body)();
end

local zzlib = require_remote("https://cdn.jsdelivr.net/gh/spearhead-industries/epinephrine@0.1.0/src/dependencies/zzlib.luau");

log("Getting versions", "done");

local raw_releases = serde.decode("json", 
    net.request("https://api.github.com/repos/spearhead-industries/epinephrine/releases").body
);

local releases_map = {};
local releases = {};

for _, release in raw_releases do
    if not release.draft then
        table.insert(releases, `{release.name} - Published: {release.published_at:gsub("T", " "):gsub("Z", ""):gsub("-", "/")}`);
        table.insert(releases_map, release);
    end
end

local version = releases_map[stdio.prompt("select", "Choose version:", releases)].tag_name;
local file_name = `epi-{process.os}-{process.arch}`;
local download_url = `https://github.com/spearhead-industries/epinephrine/releases/download/{version}/{file_name}.zip`;

local function run(cmd: string)
    print(process.spawn(cmd, {}, { shell = if process.os == "windows" then "cmd.exe" else true }));
end

log(`Downloading binary for Epinephrine {version}`, "waiting");

local zipped = net.request(download_url);
assert(zipped.ok, `Failed to get zipped binary ({zipped.statusCode})`);

remove_previous_message();
log(`Downloaded zip for Epinephrine {version}`, "done");

log(`Unzipping binary`, "waiting");
local binary = zzlib.unzip(zipped.body, `{file_name}{ext}`);

remove_previous_message();
log(`Unzipped binary`, "done");

local location;
if process.os == "windows" then
    location = process.env["USERPROFILE"]:gsub("\\", "/").."/.epinephrine/bin";
else
    location = "~/.epinephrine/bin";
end

local install_location = stdio.prompt("text", "Install Location", location);

if not fs.isDir(install_location) then
    fs.writeDir(install_location);
end

fs.writeFile(`{install_location}/epi{ext}`, binary);

log(`Installed Epinephrine as {install_location}/epi{ext}`, "done");
log(`Remember to add it to your path`);
