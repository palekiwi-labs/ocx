# Volume Management

OCX creates persistent Docker volumes to store data that should survive container restarts, such as package caches and local configuration files. This guide explains how volume management works and how to control it.

## Overview

By default, OCX creates two data volumes per project:
- `<volume-base>-cache` - Mounted at `~/.cache` inside the container
- `<volume-base>-local` - Mounted at `~/.local` inside the container

These volumes persist data like:
- Package manager caches (npm, pip, gem, etc.)
- Build artifacts and intermediate files
- User-specific configuration and state

## Volume Naming Strategies

OCX uses intelligent volume naming to enable efficient sharing across different project checkouts:

### Git Repositories (Default)

For git repositories, volumes are named based on the git remote URL:

```
ocx-git-<sanitized-remote-url>-cache
ocx-git-<sanitized-remote-url>-local
```

**Example:**
- Repository: `https://github.com/palekiwi-labs/ocx.git`
- Volume names: `ocx-git-github-com-palekiwi-labs-ocx-cache` and `ocx-git-github-com-palekiwi-labs-ocx-local`

**Benefits:**
- ✅ Same volumes shared across different checkouts of the same repository
- ✅ Efficient disk usage - no duplicate caches
- ✅ Faster setup when switching between branches in different directories
- ✅ Works with git worktrees

**Important:** Different branches of the same repository share the same volumes. This is usually beneficial (faster installs), but can cause issues if branches have incompatible dependencies.

### Non-Git Directories

For non-git directories (when `data_volumes_mode: "always"`), volumes are named using a hash:

```
ocx-dir-<hash>-cache
ocx-dir-<hash>-local
```

The hash is based on the absolute directory path, ensuring stability across sessions.

**Example:**
- Directory: `/home/user/projects/my-app`
- Volume names: `ocx-dir-a1b2c3d4-cache` and `ocx-dir-a1b2c3d4-local`

### Git Repositories Without Remotes

If a git repository has no remote configured, OCX falls back to hash-based naming using the git root directory path.

## Configuration

### Volume Mode

Control when volumes are created using the `data_volumes_mode` setting:

| Mode | Behavior |
|------|----------|
| `"git"` (default) | Create volumes only for git repositories |
| `"always"` | Create volumes for all projects (git and non-git) |
| `"never"` | Never create data volumes |

**Configuration file (`ocx.json`):**
```json
{
  "data_volumes_mode": "git"
}
```

**Environment variable:**
```bash
export OCX_DATA_VOLUMES_MODE=always
```

### Use Cases

**`data_volumes_mode: "git"` (Recommended Default)**
- Most efficient for typical development workflows
- Shares caches across branches of the same repo
- No volumes for temporary/non-git directories

**`data_volumes_mode: "always"`**
- Useful if you work with non-git projects frequently
- Ensures all projects get persistent caches
- Uses more disk space

**`data_volumes_mode: "never"`**
- Useful for CI/CD environments where caches aren't needed
- Ensures completely clean state on every run
- Minimal disk usage
- Slower installation times (no cache reuse)

### Custom Volume Names

You can override the automatic naming and specify an explicit volume name:

**Configuration file (`ocx.json`):**
```json
{
  "data_volumes_name": "my-shared-cache"
}
```

**Environment variable:**
```bash
export OCX_DATA_VOLUMES_NAME=my-shared-cache
```

**Warning:** Using the same `data_volumes_name` across different projects will make them share the same volumes. This can lead to conflicts if projects have incompatible dependencies.

**Valid use case:** Sharing volumes across related projects that have compatible dependencies (e.g., microservices in the same ecosystem).

## Managing Volumes

### List Project Volumes

To see the volumes associated with the current project:

```bash
ocx volume
```

**Example output:**
```
Data volume base name: ocx-git-github-com-palekiwi-labs-ocx

DRIVER    VOLUME NAME                                    CREATED         SIZE
local     ocx-git-github-com-palekiwi-labs-ocx-cache     2 days ago      1.2GB
local     ocx-git-github-com-palekiwi-labs-ocx-local     2 days ago      45MB
```

### List All OCX Volumes

To see all volumes created by OCX:

```bash
docker volume ls --filter name=ocx-
```

### Remove Project Volumes

To remove volumes for the current project:

```bash
# First, check what volumes will be removed
ocx volume

# Then remove them (replace with your volume base name)
docker volume rm ocx-git-github-com-palekiwi-labs-ocx-cache
docker volume rm ocx-git-github-com-palekiwi-labs-ocx-local
```

**Warning:** This will delete all cached data. You'll need to reinstall dependencies next time you run the container.

### Remove All Unused Volumes

Docker provides a command to clean up all unused volumes:

```bash
docker volume prune
```

**Use with caution:** This removes ALL unused Docker volumes, not just OCX volumes.

## Migration from Old Volume Names

If you're upgrading from an older version of OCX, your existing volumes may use the old naming scheme based on directory basename.

### Old vs New Naming

**Old naming:**
- Based on directory basename: `ocx-<basename>-<port>-cache`
- Example: `ocx-myproject-3001-cache`

**New naming:**
- Based on git remote: `ocx-git-<sanitized-url>-cache`
- Example: `ocx-git-github-com-user-myproject-cache`

### Migration Options

**Option 1: Start Fresh (Recommended)**

The simplest approach is to let OCX create new volumes and reinstall dependencies:

1. Remove old volumes (optional - they won't be used anymore):
   ```bash
   docker volume ls --filter name=ocx-
   docker volume rm <old-volume-name>
   ```

2. Start OCX normally - it will create new volumes:
   ```bash
   ocx opencode
   ```

3. Dependencies will be reinstalled (may take time on first run)

**Option 2: Manually Copy Data**

If you want to preserve cached data:

1. Identify old volumes:
   ```bash
   docker volume ls --filter name=ocx-
   ```

2. Determine new volume name:
   ```bash
   ocx volume  # Shows expected volume names
   ```

3. Copy data from old to new volume:
   ```bash
   # Create temporary container to copy data
   docker run --rm \
     -v <old-volume>:/old \
     -v <new-volume>:/new \
     alpine sh -c "cp -a /old/. /new/"
   ```

4. Verify and remove old volumes:
   ```bash
   docker volume rm <old-volume>
   ```

**Option 3: Revert to Old Behavior**

If you prefer the old directory-based naming:

```json
{
  "data_volumes_mode": "always",
  "data_volumes_name": null
}
```

**Note:** This won't replicate the exact old naming (which included port numbers), but provides similar per-directory isolation.

## Troubleshooting

### No Volumes Created

**Symptom:** Running `ocx volume` shows "No data volumes configured for this project."

**Possible causes:**
1. `data_volumes_mode` is set to `"never"`
2. `data_volumes_mode` is set to `"git"` but you're not in a git repository
3. Configuration error

**Solutions:**
```bash
# Check current configuration
ocx config

# Temporarily enable volumes
OCX_DATA_VOLUMES_MODE=always ocx opencode

# Or update config file
echo '{"data_volumes_mode": "always"}' > ocx.json
```

### Different Checkouts Not Sharing Volumes

**Symptom:** Different checkouts of the same repository have separate volumes.

**Possible causes:**
1. Different git remotes configured
2. One checkout has no remote
3. `data_volumes_name` is set differently

**Solutions:**
```bash
# Check remote URLs match
cd /path/to/checkout1 && git remote get-url origin
cd /path/to/checkout2 && git remote get-url origin

# Verify volume names would match
cd /path/to/checkout1 && ocx volume
cd /path/to/checkout2 && ocx volume

# Set explicit volume name to force sharing
export OCX_DATA_VOLUMES_NAME=my-project-cache
```

### Dependency Conflicts Between Branches

**Symptom:** Switching branches causes unexpected dependency issues.

**Cause:** Different branches sharing the same cache volumes may have incompatible dependencies.

**Solutions:**

**Option 1: Use separate volumes per branch (not recommended)**
```bash
# Use custom volume name with branch name
BRANCH=$(git branch --show-current)
export OCX_DATA_VOLUMES_NAME=myproject-$BRANCH
ocx opencode
```

**Option 2: Clean install when switching branches**
```bash
# Inside container, clear the cache
rm -rf ~/.cache/* ~/.local/*

# Reinstall dependencies
npm install  # or bundle install, pip install, etc.
```

**Option 3: Disable volumes for this project**
```json
{
  "data_volumes_mode": "never"
}
```

### Volume Name Too Long

**Symptom:** Error about volume name exceeding Docker's limits.

**Cause:** Very long git remote URLs exceed Docker volume name limits (255 characters).

**Solution:** OCX automatically hashes long URLs. If you still encounter issues, use a custom volume name:

```json
{
  "data_volumes_name": "myproject"
}
```

### Disk Space Issues

**Symptom:** Volumes consuming too much disk space.

**Check volume sizes:**
```bash
docker system df -v
```

**Solutions:**
1. Remove unused volumes:
   ```bash
   docker volume prune
   ```

2. Clear caches inside specific volumes:
   ```bash
   # Start container
   ocx opencode
   
   # Inside container
   rm -rf ~/.cache/*
   ```

3. Disable volumes for projects that don't need them:
   ```json
   {
     "data_volumes_mode": "never"
   }
   ```

## Best Practices

1. **Default to `"git"` mode** - Works well for most development workflows
2. **Use `"never"` mode for CI/CD** - Ensures clean, reproducible builds
3. **Avoid custom volume names** unless you specifically want to share volumes across projects
4. **Periodically clean volumes** - Use `docker volume prune` to reclaim space
5. **Document project-specific volume requirements** - Add `ocx.json` to your repository if you need non-default volume settings
6. **Be aware of cross-branch sharing** - Clear caches after major dependency changes

## Advanced: Volume Internals

### Volume Mount Points

OCX mounts data volumes at these container paths:

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `*-cache` | `~/.cache` | Package manager caches, build artifacts |
| `*-local` | `~/.local` | User-specific binaries, libraries, config |

### Volume Lifecycle

Volumes persist beyond container lifecycle:
- Created: On first container start with volumes enabled
- Shared: Across all containers using the same volume name
- Persisted: Even after container removal
- Removed: Only with explicit `docker volume rm` command

### Filesystem Behavior

OCX uses a **writable root filesystem by default** (`read_only: false`) for maximum tool compatibility:

**With volumes (`data_volumes_mode: "git"` or `"always"`):**
- `~/.cache` and `~/.local` are persistent (stored in Docker volumes)
- Rest of home directory is writable but ephemeral (lost on container removal)
- System directories are writable (though non-root user limits damage)

**Without volumes (`data_volumes_mode: "never"`):**
- Entire filesystem is writable but ephemeral
- All data is lost when container is removed
- Useful for CI/CD or completely clean environments

**Strict mode (`read_only: true`):**
- Requires volumes to be enabled
- Only mounted volumes are writable
- System and home directories are read-only
- Enhanced security at cost of some tool compatibility
- See [Security Model](security-model.md) for details

### Security Considerations

- Volumes are stored in Docker's volume directory (typically `/var/lib/docker/volumes/`)
- Volumes inherit permissions from the container user (mapped to your host UID/GID)
- Shared volumes between projects can potentially leak data - only share when appropriate
- Writable filesystem allows persistence of shell configs and tool settings (see [Security Model](security-model.md))
- For maximum security, use `read_only: true` with volumes enabled
