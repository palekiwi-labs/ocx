# Image Management

OCX manages Docker images for both the base environment and the final development environment. Understanding image management helps you optimize disk space, control versions, and troubleshoot issues.

## Image Types

OCX creates and manages two types of images:

### Base Image
- **Purpose:** Contains your custom base Dockerfile plus OCX requirements (OpenCode binary, user setup)
- **Naming:** `localhost/ocx-base:<hash>` or `ocx-<basename>:<version>`
- **Usage:** Built once per project/custom base configuration
- **Content:**
  - Your custom base (e.g., ruby:3.2-slim)
  - OCX requirements (curl, user tools)
  - OpenCode binary download
  - User and directory setup

### Final Image
- **Purpose:** Runtime image for your project container
- **Naming:** `localhost/ocx:<version>` or `ocx-<projectname>:<version>`
- **Usage:** Built from base image, includes project-specific settings
- **Content:**
  - All base image layers
  - Project configuration
  - Mounted workspace directory
  - Environment-specific settings

## Image Commands

### List Images

View all OCX-managed images:

```bash
ocx image list
```

**Filter options:**

| Option | Description |
|--------|-------------|
| `--base` | Show only base images |
| `--final` | Show only final images |
| `--json` | Output in JSON format |

**Examples:**

```bash
# List all images
ocx image list

# List only base images
ocx image list --base

# List only final images
ocx image list --final

# Output in JSON format
ocx image list --json

# Combine options
ocx image list --base --json
```

**Sample Output:**

```
Base Images:
  localhost/ocx-base-ruby:1.1.23          2 days ago   850 MB
  localhost/ocx-base-node:1.1.23         1 week ago   780 MB

Final Images:
  localhost/ocx-myproject:1.1.23         2 days ago   860 MB
  localhost/ocx-otherproject:1.1.23      3 days ago   920 MB
```

### Prune Images

Remove old versions of OCX images while keeping the latest:

```bash
ocx image prune
```

**What it does:**
- Keeps the most recent base and final images
- Removes older versions
- Frees up disk space
- Does not affect running containers

**When to use:**
- After upgrading OCX
- When switching between different base images
- Periodically to reclaim disk space

**Examples:**

```bash
# Prune all old images
ocx image prune

# Check what would be pruned (dry run)
ocx image list  # Review first
ocx image prune # Then prune
```

**Warning:** This will remove all but the latest version. Ensure you don't need older versions.

### Remove All Images

Remove all OCX-managed images:

```bash
ocx image remove-all
```

**What it does:**
- Removes all OCX base images
- Removes all OCX final images
- Frees maximum disk space
- Does not affect running containers

**When to use:**
- Completely resetting OCX
- Starting fresh with a new configuration
- Troubleshooting image corruption
- Before major OCX version upgrades

**Warning:** This removes ALL images. You'll need to rebuild them next time you run `ocx opencode`.

## Image Building

### Manual Build

Manually trigger image builds:

```bash
# Build images (skips if already built)
ocx build

# Force rebuild even if images exist
ocx build --force

# Build only base image
ocx build --base

# Build only final image
# (Note: final is usually built when running opencode)
```

### Build Process

**Base Image Build:**
1. Uses your custom Dockerfile (if specified)
2. Installs OCX requirements (curl, user tools)
3. Downloads OpenCode binary
4. Creates user and directories
5. Tags the image with version hash

**Final Image Build:**
1. Uses base image as foundation
2. Applies project configuration
3. Tags with project name and version

### Build Errors

**"curl: not found" during build**

**Cause:** Custom base image doesn't have curl

**Solution:** Add curl to your Dockerfile:
```dockerfile
# Debian/Ubuntu
RUN apt-get update && apt-get install -y --no-install-recommends curl

# Alpine
RUN apk add --no-cache curl

# Fedora/CentOS
RUN yum install -y curl
```

**"Permission denied" errors**

**Cause:** Incorrect user mapping or permissions

**Solution:**
```bash
# Rebuild with force to regenerate user
ocx build --base --force
ocx build --force
```

**"No space left on device"**

**Cause:** Insufficient disk space

**Solution:**
```bash
# Prune old images
ocx image prune

# Or remove all
ocx image remove-all

# Also clean Docker system
docker system prune -a
```

## Image Storage

### Disk Usage

Check disk usage:

```bash
# Check OCX images size
docker images | grep ocx

# Check total Docker disk usage
docker system df

# Detailed breakdown
docker system df -v
```

### Image Location

Docker stores images in:
- Linux: `/var/lib/docker/`
- macOS: `~/Library/Containers/com.docker.docker/Data/vms/0/`
- Windows: `C:\ProgramData\Docker\windowsfilter\`

### Large Image Tips

If images are too large:

1. **Use minimal base images:**
   ```dockerfile
   FROM ruby:3.2-slim  # Instead of ruby:3.2
   FROM node:20-alpine # If Alpine works for you
   ```

2. **Clean up package caches:**
   ```dockerfile
   RUN apt-get update && apt-get install -y package && \
       rm -rf /var/lib/apt/lists/*
   ```

3. **Multi-stage builds (advanced):**
   ```dockerfile
   FROM node:20 as builder
   WORKDIR /app
   COPY package*.json ./
   RUN npm ci

   FROM node:20-slim
   COPY --from=builder /app/node_modules ./node_modules
   ```

## Version Management

### Understanding Image Versions

OCX images are versioned using the OCX version number:

```
localhost/ocx:1.1.23
```

When you upgrade OCX, new images are built with the new version:

```
localhost/ocx:1.1.24  # Latest
localhost/ocx:1.1.23  # Previous
```

### Tracking Versions

Check which OCX version you're using:

```bash
ocx config | grep opencode_version
```

List images to see available versions:

```bash
ocx image list
```

### Version Pinning

To use a specific OCX version across builds:

```json
{
  "opencode_version": "1.2.3"
}
```

Or via environment variable:
```bash
export OCX_OPENCODE_VERSION=1.2.3
```

### Upgrading and Images

When you run `ocx upgrade`:

1. New OCX version is downloaded
2. Images are rebuilt with new version
3. Old images remain (can be pruned)

After upgrade, you can:
- Use new images (default)
- Prune old images: `ocx image prune`
- Keep old images as backup

## Common Workflows

### 1. Fresh Start

Completely reset OCX:

```bash
# Stop all containers
ocx stop

# Remove all images
ocx image remove-all

# Clean Docker system
docker system prune -a

# Start fresh
ocx opencode
```

### 2. Switch Base Images

Change from one base to another:

```bash
# Update config
echo '{"custom_base_dockerfile": "docker/new-base/Dockerfile"}' > ocx.json

# Build new base
ocx build --base --force

# Run with new base
ocx opencode

# Clean up old base image (optional)
ocx image prune
```

### 3. Reclaim Disk Space

Periodic cleanup:

```bash
# Stop all OCX containers
ocx stop

# Prune old images
ocx image prune

# Clean Docker system
docker system prune

# Check space saved
docker system df
```

### 4. Debug Image Issues

If images are corrupted:

```bash
# Rebuild from scratch
ocx image remove-all
ocx build --force

# Or rebuild specific components
ocx build --base --force
ocx build --force
```

### 5. Team Synchronization

Ensure all team members use the same images:

```bash
# Pin OCX version
export OCX_OPENCODE_VERSION=1.2.3

# Document custom base in ocx.json
echo '{"custom_base_dockerfile": "docker/Dockerfile"}' > ocx.json

# Share the ocx.json and Dockerfile
git add ocx.json docker/Dockerfile
git commit -m "Pin OCX version and base image"
```

## Advanced Topics

### Image Layer Inspection

Inspect image layers:

```bash
# Show image history
docker history localhost/ocx:1.1.23

# Inspect image details
docker inspect localhost/ocx:1.1.23
```

### Custom Image Tags

While OCX manages version tags automatically, you can add custom tags:

```bash
docker tag localhost/ocx:1.1.23 my-custom-tag
```

**Use case:** Backup, testing, or rollback

### Export/Import Images

Export and import OCX images (useful for air-gapped environments):

```bash
# Export
docker save localhost/ocx:1.1.23 -o ocx-image.tar

# Import
docker load -i ocx-image.tar
```

### Shared Base Images

If multiple projects use the same base, OCX will share the base image:

```bash
# Project A
cd /projects/project-a
echo '{"custom_base_dockerfile": "docker/Dockerfile"}' > ocx.json
ocx build --base  # Creates ocx-base-ruby:1.1.23

# Project B (same Dockerfile)
cd /projects/project-b
echo '{"custom_base_dockerfile": "docker/Dockerfile"}' > ocx.json
ocx build --base  # Reuses ocx-base-ruby:1.1.23
```

This saves disk space and build time.

## Troubleshooting

### Container Not Starting

If container fails to start:

```bash
# Check if images exist
ocx image list

# Rebuild images
ocx build --force

# Check Docker daemon
docker ps
```

### Outdated Version Showing

If you see old version despite upgrade:

```bash
# Check current config
ocx config

# Force rebuild
ocx build --force

# Prune old images
ocx image prune
```

### Permission Errors After Image Change

After changing base images:

```bash
# Rebuild with force
ocx build --base --force
ocx build --force

# Verify user mapping
ocx shell
id  # Should match host user
```

### Disk Space Issues

If running out of space:

```bash
# Check what's using space
docker system df -v

# Prune aggressively
docker system prune -a --volumes

# Then rebuild needed images
ocx build --force
```

## Best Practices

1. **Regular Pruning:** Run `ocx image prune` monthly or after upgrades
2. **Version Pinning:** Pin OCX versions in production for reproducibility
3. **Monitor Usage:** Check `docker system df` periodically
4. **Clean Builds:** Use `--force` when changing base images
5. **Share Bases:** Use consistent Dockerfiles across similar projects
6. **Document Changes:** Commit `ocx.json` and Dockerfiles to version control
7. **Test After Changes:** Always test after upgrading or changing base images
8. **Backup Critical Images:** Export images before major changes if needed
