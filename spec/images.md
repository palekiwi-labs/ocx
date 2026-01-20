---
status: done
---

# Images

---

## Description

Add a new command `main image` that wraps `docker image` and supports:
- listing all ocx images
- removing old images
- removing all ocx images

## Implementation

Implemented as `ocx image` command with three subcommands:

### `ocx image list`
Lists all OCX Docker images with repository, tag, creation date, and size.
- `--base`: Show only base images (ocx-base*)
- `--final`: Show only final OCX images (ocx, ocx-*)
- `--json`: Output as JSON

### `ocx image prune`
Removes old image versions, keeping only the latest version from config.
Preserves both the 'latest' tag and the current numbered version tag.
- `--base`: Prune only base images
- `--final`: Prune only final OCX images

### `ocx image remove-all`
Removes all OCX images (base and/or final).
- `--base`: Remove only base images
- `--final`: Remove only final OCX images

Files modified:
- Created: `src/docker_tools/image.nu`
- Modified: `src/docker_tools/mod.nu` (exported image module)
- Modified: `src/main.nu` (added image subcommands and help text)
