# Changelogs

## [0.1.2] - 04/07/2024

### Added

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
