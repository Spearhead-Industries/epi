# Changelogs

## [0.1.5] -

### Changed

- New Bundler
  - The bundler now uses jackdotink/luaup to find require calls instead of gsub, meaning comments and strings are no longer falsely converted.
  - All string types, except for multiline strings, can be used. This includes interpolated strings provided they are 'simple', i.e contains no interpolated sections.
  - Files are now identified by the source SHA1 hash, rather than MD5.
  - Aliases now apply correctly regardless of whether the `.luaurc` entry has a trailing slash or not.

### Fixed

- Fixed `init` command specifying .luaurc incorrectly.

## [0.1.4] - 12/07/2024

### Fixed

- Fixed require issue.

## [0.1.3] - 09/07/2024

### Fixed

- Fixed tracebacks including epinephrine.
- Fixed `assert` being overwritten in ran scripts.

## [0.1.2] - 09/07/2024

### Added

- Added `test` command to run simple automated tests.
- Added `run-script` command to run .luau scripts within the `./scripts/` folder.
- Added `list` command to list all currently installed packages.
- Command aliases, i.e ls for list, rs for run-script.

### Changed

- Bumped Lune version from 0.8.5 to 0.8.6.
- Replaced hashlib use with the Lune `serde` API.

## [0.1.1] - 03/07/2024

### Added

- Added feature to have seperate entrypoints for `require()` and `epi run/epi build`.
- Added `treeshake` command to remove installed packages without any dependants.

## [0.1.0] - 03/07/2024

Initial Release
