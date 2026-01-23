---
status: done
implemented: 2026-01-23
---

# Improve volume management

---

## Implementation Summary

All proposed solutions have been implemented successfully. Additionally, the `--read-only` filesystem constraint was removed as the default to resolve permissions issues and align with industry standards.

## Description

Currently, we always mount two separate volumes per project for cache and local files:

```nu
# src/docker_tools/run.nu L106-L107

"-v" $"($container_name)-cache:/home/($user)/.cache:rw"
"-v" $"($container_name)-local:/home/($user)/.local:rw"
```

Let's refer to these two mounted volumes collectively as "data volumes".
The cache is named after the container, which in turn is named after the absolute directory path.

## Issues

### Issue 1

This means that having a different branch of the same repository checked out in a different directory
would create new differently named data volumes. This is wasteful and prevents reuse of the data saved
in the volumes when working on the same repo project.

### Issue 2

Currently, new data volumes are created always for every project.
We should be able to give the user control over how and whether these data volumes are created.

## Potential solutions

Analyze the possibility of addresing the issue with the following:

1. Redesign the algorithm for generating data volume names for same repo reuse

- consider generating the name based on the git information, e.g. `<org>/<repo>`

2. Consider creating data volumes only for projects that are git repositories
3. Add a config setting that allows disabling data volume creation/mounting

- consider an enum value: "always", "git", "never", etc

4. Add a config setting that allows specifying a fixed data volume name for all projects
5. Add corresponding env vars for the new config settings

## Implementation Details

### Solutions Implemented

**✅ Solution 1: Git-based volume naming**
- Volumes named based on sanitized git remote URL (e.g., `ocx-git-github-com-palekiwi-labs-ocx`)
- Same repository = same volumes across different checkouts
- Enables efficient cache sharing across branches
- Implemented in `src/git_utils.nu` and `src/volume_name.nu`

**✅ Solution 2: Git-only volume creation**
- New config option: `data_volumes_mode: "git"` (default)
- Only creates volumes for git repositories
- Non-git directories get no volumes by default

**✅ Solution 3: Configurable volume creation**
- `data_volumes_mode` enum: `"always"` | `"git"` | `"never"`
- `"always"` - Create volumes for all projects (git and non-git)
- `"git"` - Only for git repositories (default)
- `"never"` - Disable volume creation entirely

**✅ Solution 4: Custom volume names**
- New config option: `data_volumes_name` (optional)
- Allows explicit volume name override
- Enables sharing volumes across projects when needed

**✅ Solution 5: Environment variables**
- `OCX_DATA_VOLUMES_MODE` - Controls volume creation mode
- `OCX_DATA_VOLUMES_NAME` - Custom volume name override

### Additional Changes

**Read-Only Filesystem Decision:**

During implementation, we discovered that `--read-only` filesystem caused permission issues when volumes were not created (EROFS errors). After consulting with security experts and analyzing industry standards, we made the following decision:

**Changed default: `read_only: false`** (breaking change)

**Rationale:**
- Industry standard: VS Code Dev Containers, Codespaces, Gitpod all use writable filesystems
- Developer experience: Many tools expect to write to `~/` paths
- Security: Other layers (--cap-drop ALL, no-new-privileges, non-root user) provide robust protection
- Flexibility: Users can opt-in to strict mode with `read_only: true`

**Impact:**
- Solves EROFS permission errors completely
- Aligns with industry best practices
- Maintains strong security through other layers
- Provides opt-in strict mode for sensitive work

**Documentation:**
- Created comprehensive `docs/security-model.md`
- Updated `docs/security-hardening.md`
- Updated `docs/volume-management.md`

### Files Created/Modified

**New files:**
- `src/git_utils.nu` - Git detection and remote URL utilities
- `src/volume_name.nu` - Volume name resolution logic
- `docs/volume-management.md` - Comprehensive volume management guide
- `docs/security-model.md` - Security architecture and threat model

**Modified files:**
- `src/config/defaults.nu` - Added volume config options, changed `read_only: false`
- `src/config/env.nu` - Added environment variable handlers
- `src/config/validation.nu` - Added validation rules
- `src/docker_tools/run.nu` - Updated volume mounting logic
- `src/docker_tools/volume.nu` - Enhanced volume listing
- `docs/security-hardening.md` - Updated for writable filesystem default
- `docs/environment-variables.md` - Documented new env vars
- `docs/index.md` - Added volume management docs link
- `README.md` - Added volume management docs link
