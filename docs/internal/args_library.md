# Internal Documentation: `args` library

The `args` library, located at `./src/libs/args.luau` is used to parse command line arguments.

## Notes on Parsing

### Name Safe Characters

Only alphanumeric characters, dashes and underscores are deemed as 'name' safe characters.

This means only the characters defined above can be used in the name of long flags and long named arguments.

Argument names, in all forms, are case sensitive.

### Flags

A flag is defined as an argument thats presence indicates true, and absense indicates false.

A flag argument can never be mandatory.

#### Short

A short flag is a flag identified by a single alphanumeric character prefixed with a single dash.

During parsing, if the argument is prefixed with a single dash and only contains alphanumeric characters, it is deemed as a sequence of short flags.

For example, `-aBcD` will be treated as four seperate short flags; 'a', 'B', 'c', 'D' respectively.

#### Long

A long flag is a flag identified by more than one character prefixed with two dashes.

During parsing, if the argumnent is prefixed with two dashes and only contains name safe characters, it is deemed to be a long flag.

For example, `--hello-world` will be treated as a single long flag.

### Named Argument

A named argument is an `=` seperated argument.

#### Short

A short named argument is identified by a single alphanumeric character prefixed with a single dash.

During parsing, if the argument is prefixed with a single dash and contains one alphanumeric character followed by an equals character, it is deemed to be a short named argument.

For example, `-p=1552` will be treated as a short named argument.

#### Long

A long named argument is identified by multiple name safe characters, prefixed with two dashes.

During parsing, if the argument is prefixed with two dashes and contains name safe arguments followed by an equals character, it is deemed to be a long named argument.

### Positional Arguments

A positional argument is defined as an argument with no dash prefix.

Positional arguments must appear before non-positional arguments, otherwise an error will be thrown.

## Usage

### `echo` Example

```lua
local fs = require("@lune/fs");

local args = args.parse({
    args.PositionalArgument(1, "string"),
    args.NamedArgument({"output", "o"}, "string?", "./echo.out"),
    args.FlagArgument({"debug", "d"}),
});

local debug_mode = args.get_flag("debug");
local output_folder = args.get_named("output");
local content = args.get_positional(1);

local function dprint(...)
    if debug_mode then
        print(...);
    end
end;

dprint("Output Folder =", output_folder);
dprint("Content =", content);

local ok = pcall(fs.writeFile, output_folder, content);
dprint("Write", if ok then "OK" else "FAIL");
```
