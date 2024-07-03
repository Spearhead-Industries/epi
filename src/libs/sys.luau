--!nocheck

local process = require("@lune/process");
local serde = require("@lune/serde");
local fs = require("@lune/fs");

local config = require("../config");

local sys = {};

function sys.standardise_path(path: string): string
    return path:gsub("\\", "/"):gsub("/%./", "/");
end

function sys.remove_trailing_slash(str: string): string
    return str:gsub("/$", "");
end

function sys.ensure_dir_exists(path: string)
    if not fs.isDir(path) then
        fs.writeDir(path);
    end
end

function sys.ensure_file_exists(path: string, content: string?)
  sys.ensure_dir_exists(sys.folder_of(path));

  if not fs.isFile(path) then
      fs.writeFile(path, content or "");
  end
end

sys.win = process.os == "windows";

do
    local home = sys.standardise_path(
        process.env[if sys.win then "USERPROFILE" else "HOME"]
    );

    if home:sub(-1) == "/" then
        home = home:sub(1, #home-1)
    end

    sys.home = sys.remove_trailing_slash(home);
end

do
    local temp = sys.standardise_path(
        process.env["TEMP"]
        or process.env["TMP"]
        or process.env["TMPDIR"]
        or "/tmp/"
    );

    sys.temp = sys.remove_trailing_slash(temp);
end

sys.username = sys.standardise_path(
    process.env["USERNAME"] or process.env["USER"]
);

do
    local split_cwd = sys.standardise_path(process.cwd):gsub("/$", ""):split("/");
    sys.cwd_name = split_cwd[#split_cwd];
end

sys.dir_name = config.name.long:lower();
sys.local_dir = `./.{sys.dir_name}`;
sys.global_dir = `{sys.home}/.{sys.dir_name}`;
sys.manifest_name = `{config.name.long:lower()}.toml`


function sys.normalise_eol(str: string): string
  return str:gsub("\x0D\x0A", "\n");
end

function sys.luaurc(): {}
  return (fs.isFile("./.luaurc") and serde.decode("json", fs.readFile("./.luaurc")))
          or {};
end

function sys.normalise_path(str: string): string
  return str:gsub("\\", "/"):gsub("/%./", "/");
end

function sys.folder_of(file: string): string
    file = sys.normalise_path(file);
    local parts = file:split("/");
    table.remove(parts, #parts);

    return table.concat(parts, "/") .. "/";
end

-- https://github.com/davidm/lua-glob-pattern/tree/master
function sys.globtopattern(g)
    local p = "^"  -- pattern being built
    local i = 0    -- index in g
    local c        -- char at index i in g.
  
    -- unescape glob char
    local function unescape()
      if c == '\\' then
        i = i + 1; c = g:sub(i,i)
        if c == '' then
          p = '[^]'
          return false
        end
      end
      return true
    end
  
    -- escape pattern char
    local function escape(c)
      return c:match("^%w$") and c or '%' .. c
    end
  
    -- Convert tokens at end of charset.
    local function charset_end()
      while 1 do
        if c == '' then
          p = '[^]'
          return false
        elseif c == ']' then
          p = p .. ']'
          break
        else
          if not unescape() then break end
          local c1 = c
          i = i + 1; c = g:sub(i,i)
          if c == '' then
            p = '[^]'
            return false
          elseif c == '-' then
            i = i + 1; c = g:sub(i,i)
            if c == '' then
              p = '[^]'
              return false
            elseif c == ']' then
              p = p .. escape(c1) .. '%-]'
              break
            else
              if not unescape() then break end
              p = p .. escape(c1) .. '-' .. escape(c)
            end
          elseif c == ']' then
            p = p .. escape(c1) .. ']'
            break
          else
            p = p .. escape(c1)
            i = i - 1 -- put back
          end
        end
        i = i + 1; c = g:sub(i,i)
      end
      return true
    end
  
    -- Convert tokens in charset.
    local function charset()
      i = i + 1; c = g:sub(i,i)
      if c == '' or c == ']' then
        p = '[^]'
        return false
      elseif c == '^' or c == '!' then
        i = i + 1; c = g:sub(i,i)
        if c == ']' then
          -- ignored
        else
          p = p .. '[^'
          if not charset_end() then return false end
        end
      else
        p = p .. '['
        if not charset_end() then return false end
      end
      return true
    end
  
    -- Convert tokens.
    while 1 do
      i = i + 1; c = g:sub(i,i)
      if c == '' then
        p = p .. '$'
        break
      elseif c == '?' then
        p = p .. '.'
      elseif c == '*' then
        p = p .. '.*'
      elseif c == '[' then
        if not charset() then break end
      elseif c == '\\' then
        i = i + 1; c = g:sub(i,i)
        if c == '' then
          p = p .. '\\$'
          break
        end
        p = p .. escape(c)
      else
        p = p .. escape(c)
      end
    end
    return p
  end

function sys.escape_gsub(str: string): string
    return str
        :gsub("%%", "%%%%")
        :gsub("%.", "%%.")
        :gsub("%(", "%%(")
        :gsub("%)", "%%)")
        :gsub("%+", "%%+")
        :gsub("%-", "%%-")
        :gsub("%^", "%%^")
        :gsub("%$", "%%$");
end

function sys.read_dir_flat(dir: string, include_directories: boolean?)
    local flat_files = {};

    local function search_dir(next_dir: string)
        local files = fs.readDir(next_dir);
        for _, v in files do
            local name = next_dir.."/"..v;
            local md = fs.metadata(name);

            if md.kind == "dir" then
                if include_directories then
                    table.insert(flat_files, name);
                end
                search_dir(name);
            elseif md.kind == "file" then
                table.insert(flat_files, name);
            end
        end
    end

    search_dir(dir);

    return flat_files;
end

function sys.filter_files(files: {string}, filter: string): {string}
    local pattern = if filter then sys.globtopattern(filter) else nil;
    local new_files = {};

    for _, file in files do
        if file:match(pattern) then
            table.insert(new_files, file);
        end
    end

    return new_files;
end

function sys.remove(path: string)
    if fs.isDir(path) then
        fs.readDir(path);
    elseif fs.isFile(path) then
        fs.removeFile(path);
    end
end

function sys.line_count(str: string): number
  return #str:split("\n");
end

return sys;
