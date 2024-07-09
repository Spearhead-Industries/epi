export type PackageData = {
    valid: true,
    identifier: string,
    owner: string,
    name: string,
    ref: string?,
} | {
    valid: false,
};

export type BuildTargets = 
    "windows-x86_64"|
    "linux-aarch64" | 
    "macos-aarch64" |
    "linux-x86_64"  |
    "macos-x86_64"  |
    "rbxm"          |
    "dev"           |
    "bytecode"      |
    "bundled"       |
    "all"           ;

export type BuildConfig = {
    resource_folder: string?,
    optimisation_level: number?,
    coverage_level: number?,
    debug_lvel: number?,
    target: BuildTargets?,
    zip: boolean?,
    lune_version: string?,
    name: string?,
};

export type PackageManifest = {
    name: string,
    version: string,
    main: string|{lib: string, bin: string},
    
    owner: string?,
    files: {string}?,
    dependencies: {string}?,
    description: string?,
    keywords: {string}?,

    dev_dependencies: {string}?,
    contributors: {string}?,
    private: boolean?,
    arch: {string}?,
    os: {string}?,
    runtimes: {string}?,
    build_config: (BuildConfig & {dev: BuildConfig, release: BuildConfig})?,
    scripts: string?, -- wip
    tests: string?,
};

export type Semver = {
    valid: boolean,
    major: number?,
    minor: number?,
    patch: number?,
    prerelease_identifiers: {string}?,
    build_identifiers: {string}?
};

return {};