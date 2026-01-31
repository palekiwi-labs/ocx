# Improve update frequency management

## Context

The version in the cache is already set to the latest version, but `ocx upgrade` still promts the user to upgrade.
Instead it should print that the version is up to date and exit

```bash
󰲒 cat ~/.cache/ocx/version-cache.json
{
  "version": "1.1.44",
  "fetched_at": 1769751768795639899
}

ocx  improve-update-check 1󰆢
󰲒 nu src/main.nu upgrade
Checking for OpenCode updates...
New version available: v1.1.44

Release notes:
No notable changes

Build v1.1.44? [y/N] y
Rebuilding image...
Building OCX image: localhost/ocx-ocx:1.1.44
  Container user: pl (UID: 1000, GID: 100)
[+] Building 0.2s (8/8) FINISHED                                                                                                                docker:default
 => [internal] load build definition from Dockerfile.opencode                                                                                             0.0s
 => => transferring dockerfile: 1.84kB                                                                                                                    0.0s
 => [internal] load metadata for localhost/ocx-base-ocx:latest                                                                                            0.0s
 => [internal] load .dockerignore                                                                                                                         0.0s
 => => transferring context: 2B                                                                                                                           0.0s
 => [1/4] FROM localhost/ocx-base-ocx:latest                                                                                                              0.0s
 => CACHED [2/4] RUN set -eux;     case "amd64" in         amd64) BIN_ARCH="x64" ;;         arm64) BIN_ARCH="arm64" ;;         *) echo "Unsupported arch  0.0s
 => CACHED [3/4] RUN set -e;     if getent group 100 >/dev/null 2>&1; then         GROUP_NAME=$(getent group 100 | cut -d: -f1);     else         groupa  0.0s
 => CACHED [4/4] WORKDIR /workspace                                                                                                                       0.0s
 => exporting to image                                                                                                                                    0.0s
 => => exporting layers                                                                                                                                   0.0s
 => => writing image sha256:d702673ea381ae02fda7bfce8861f49d58fa6025e85b70fcedd70ade9f8aa418                                                              0.0s
 => => naming to localhost/ocx-ocx:1.1.44                                                                                                                 0.0s
 => => naming to localhost/ocx-ocx:latest                                                                                                                 0.0s
OpenCode v1.1.44 is ready!
```
