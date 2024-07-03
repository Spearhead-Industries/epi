# Packages

## Package Manifest Format

```toml
# Required
name = ""                   # Package Name
version = ""                # Semver
main = "./src/init.luau"    # Path pointing to the entrypoint

# Not required, but created automatically
owner = "plain"             # The owner of the package
files = ["*"]               # Glob pointing to the files to be included
dependencies = []           # List of dependency identifiers
description = ""            # Brief description of the package
keywords = []               # List of keywords
repository = ""             # URL to the git repository

# Optional
dev_dependencies = []       # List of dependency identifiers that will only be installed if the package is the project root
contributors = ["ahh"]      # List of contributors
private = true              # CLI will refuse to publish if true
arch = ["x86_64"]           # CPUs the code will run on, all if not present
os = ["windows"]            # OSes the code will run on, all if not present
runtimes = ["lune"]         # Runtimes the code will run on, all if not present
build_config = {}           # List of `epi build` defaults
documentation = ""          # URL to the docs
```
