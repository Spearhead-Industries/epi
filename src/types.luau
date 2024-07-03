export type PackageData = {
    valid: true,
    identifier: string,
    owner: string,
    name: string,
    ref: string?,
} | {
    valid: false,
};

export type BuildConfig = {
    resource_folder: string,
};

export type PackageManifest = {
    name: string,
    version: string,
    main: string,
    
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
    build_config: (BuildConfig|{dev: BuildConfig, release: BuildConfig})?,
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