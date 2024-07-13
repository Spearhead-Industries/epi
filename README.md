<!-- markdownlint-disable MD041 -->
<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD001 -->

<div align="center">

# Epinephrine

</div>

A simple (unofficial) project manager for Luau.

## About

Epinephrine is a prototype rudimentary project manager for Luau, built on top of [Lune](https://github.com/lune-org/lune).

Epinephrine can be used to test, build and install dependencies applications.

Epinephrine is not yet stable; use with caution.

At present, dependency packages are installed using identifiers pointing to a GitHub repo.

Install a package with;

```
epi install author/repo@commit-ish
```

`commit-ish` can be a release Tag (recommended), a branch (not recommended) or blank to denote the latest main branch version (definitely not recommended).

Further install methods will be available in the future, including:

1. HTTP URLs pointing to packages encoded as `.tar.gz`.
2. A dedicated epinephrine registry,
3. Generic Git remote repository URLs.
4. Local file paths.

### Why "Epinephrine"?

It's a fun word to say.

## Installation

No prerequisites are required to install epinephrine.

### Aftman

You can install epinephrine using [Aftman](https://github.com/LPGhatguy/aftman) with the following command:

```bash
aftman add --global Spearhead-Industries/epinephrine epi
```

## Usage

Run `epi`

Commands:

1. install
2. uninstall
3. run
4. build
5. init
6. treeshake
