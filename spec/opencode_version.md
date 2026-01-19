---
status: done
---

# Opencode Version

---

## Description

Right now we are hardcoding version of opencode in: `src/docker_tools/build.nu`

It is essential that the version of opencode can be easily set and updated by the user.
We need to analyze how to approach this.

There are a couple of aspects to is:

### What version does the `build` command build for?

Right now it is hardcoded inline without any user control.
We should move it into the config (with some default).

### When we run `ocx run`, what is the version of the image being run?

Right now it is the `latest`.
How does it related to the version that we will set in the config?
Should we even be using `latest` at all or always be explicit with a number?

### How are users expected to stay up to date?

Some users will actively track the release information and will prefer to manually upgrade/downgrade by updating the value in their config.

However, other users may appreciate the feature of having the version set in their config to `latest`.
In such case, we would need to periodically check the github releases (run an http request?) to check the latest release,
compare it to the latest local release, and prompt the user if they would like to update?

### `upgrade` command

If we implement the above release check mechanism, we can expose it under `ocx upgrade` command that would perform the check
and prompt the user if they want to upgrade.

---

## Implementation Summary

### Changes Made

**New Module: `src/version/`**
- `mod.nu` - Main exports for version module
- `github.nu` - GitHub API integration to fetch latest release
- `cache.nu` - Cache management with 24-hour TTL
- `resolver.nu` - Version resolution, normalization, and validation

**Config Changes:**
- Added `opencode_version` field to defaults (default: "latest")
- Removed `image_name` field (breaking change)
- Added version validation to config validation

**Build Command (`src/docker_tools/build.nu`):**
- Removed hardcoded version constant
- Resolves version dynamically from config
- Tags images with specific version and `latest`

**Run Command (`src/docker_tools/run.nu`):**
- Derives image name from resolved version
- No longer uses `image_name` from config

**Upgrade Command (`src/upgrade.nu`):**
- New command to check for updates
- Displays release notes from GitHub
- Prompts user to update
- Updates global config
- Triggers automatic rebuild

### Design Decisions

1. **Default version**: `"latest"` - auto-track latest version
2. **Version checking**: Daily cache (24-hour TTL) to reduce GitHub API calls
3. **Update target**: Global config (`~/.config/ocx/ocx.json`)
4. **Rebuild**: Automatic after version update
5. **Version normalization**: Strip 'v' prefix (e.g., `v1.2.3` → `1.2.3`)
6. **Image naming**: Automatically derived from `opencode_version`

### Usage Examples

```bash
# Use latest version (default)
ocx run
ocx build

# Use specific version
echo '{"opencode_version": "1.1.23"}' > ~/.config/ocx/ocx.json
ocx build
ocx run

# Check for updates
ocx upgrade --check

# Update to latest version
ocx upgrade
```

### Migration Notes

Users need to remove `image_name` from config files and use `opencode_version` instead:

```json
{
  "opencode_version": "latest"
}
```

Or for pinned versions:

```json
{
  "opencode_version": "1.1.23"
}
```

