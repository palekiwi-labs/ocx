# Environment Variables Reference

OCX can be configured via environment variables, which take precedence over configuration files. This is a comprehensive reference of all supported environment variables.

## Configuration Priority

Environment variables are evaluated in this order (highest to lowest):

1. **Environment Variables** (highest priority)
2. Project Config (`./ocx.json`)
3. Global Config (`~/.config/ocx/ocx.json`)
4. Defaults (lowest priority)

## Complete Environment Variables

### Workspace and Container

#### `OCX_WORKSPACE`
Path to the workspace directory mounted into the container. Defaults to current directory.

**Type:** Path string

**Example:**
```bash
export OCX_WORKSPACE=/home/user/projects/my-app
ocx opencode
```

**Note:** The path determines how it's mapped inside the container:
- Paths under `$HOME` → `/home/username/...`
- Paths outside `$HOME` → `/workspace/...`

#### `OCX_CONTAINER_NAME`
Override the automatic container name.

**Type:** String

**Example:**
```bash
export OCX_CONTAINER_NAME=my-dev-container
```

**Default:** Generated as `ocx-<projectname>-<port>`

### Port and Network

#### `OCX_PORT`
Override the port number used by opencode.

**Type:** Integer (1024-65535)

**Example:**
```bash
export OCX_PORT=8080
```

**Default:** Auto-generated based on project path hash

#### `OCX_PUBLISH_PORT`
Whether to publish port 80 in the container to the host port.

**Type:** Boolean (`true`/`false`)

**Example:**
```bash
export OCX_PUBLISH_PORT=true
```

**Default:** `false`

#### `OCX_NETWORK`
Docker networking mode for the container.

**Type:** String (`bridge`, `host`, `none`)

**Example:**
```bash
export OCX_NETWORK=host
```

**Default:** `bridge`

**Note:** See [Security Hardening](security-hardening.md) for security implications.

#### `OCX_ADD_HOST_DOCKER_INTERNAL`
Add `--add-host=host.docker.internal:host-gateway` to enable container access to host services.

**Type:** Boolean (`true`/`false`)

**Example:**
```bash
export OCX_ADD_HOST_DOCKER_INTERNAL=true
```

**Default:** `true`

**Use case:** Access services running on the host (e.g., databases, APIs) from within the container via `host.docker.internal`. This is useful for local development scenarios where the container needs to communicate with host services.

### Docker Image and Version

#### `OCX_OPENCODE_VERSION`
The opencode version to use.

**Type:** Version string (`latest` or `X.Y.Z`)

**Example:**
```bash
export OCX_OPENCODE_VERSION=1.2.3
export OCX_OPENCODE_VERSION=latest
```

**Default:** `latest`

#### `OCX_CUSTOM_BASE_DOCKERFILE`
Path to a custom Dockerfile to use as the base image.

**Type:** File path

**Example:**
```bash
export OCX_CUSTOM_BASE_DOCKERFILE=docker-ocx/Dockerfile
```

**Default:** None (uses default base)

**See:** [Custom Base Image Template](custom-base-template.md) for details

### Resource Limits

#### `OCX_MEMORY`
Memory limit for the container.

**Type:** String with suffix (`k`, `m`, `g`)

**Example:**
```bash
export OCX_MEMORY=2048m
export OCX_MEMORY=2g
```

**Default:** `1024m`

**Valid formats:** `512m`, `1g`, `2048m`, etc.

#### `OCX_CPUS`
CPU limit for the container.

**Type:** Float (number of CPUs)

**Example:**
```bash
export OCX_CPUS=2.0
export OCX_CPUS=0.5
```

**Default:** `1.0`

#### `OCX_PIDS_LIMIT`
Maximum number of processes (PIDs) in the container.

**Type:** Integer

**Example:**
```bash
export OCX_PIDS_LIMIT=200
```

**Default:** `100`

**Note:** Set higher for applications that spawn many processes.

### Security

#### `OCX_FORBIDDEN_PATHS`
Paths that should be shadow-mounted (isolated from host) for security.

**Type:** Comma-separated paths

**Example:**
```bash
export OCX_FORBIDDEN_PATHS=/etc,/root,/var
```

**Default:** None

**See:** [Security Hardening](security-hardening.md) for details

#### `OCX_READ_ONLY`
Whether to mount the container root filesystem as read-only.

**Type:** Boolean (`true`/`false`)

**Example:**
```bash
export OCX_READ_ONLY=false
```

**Default:** `true`

**Warning:** Disabling read-only root reduces security significantly.

### Tmpfs Configuration

#### `OCX_TMP_SIZE`
Size of the tmpfs mount for `/tmp`.

**Type:** String with suffix (`k`, `m`, `g`)

**Example:**
```bash
export OCX_TMP_SIZE=1g
```

**Default:** `500m`

#### `OCX_WORKSPACE_TMP_SIZE`
Size of the tmpfs mount for `/workspace/tmp`.

**Type:** String with suffix (`k`, `m`, `g`)

**Example:**
```bash
export OCX_WORKSPACE_TMP_SIZE=1g
```

**Default:** `500m`

**Note:** tmpfs mounts are in-memory and don't persist data.

### User Mapping

#### `OCX_USERNAME`
Username to create inside the container.

**Type:** String

**Example:**
```bash
export OCX_USERNAME=developer
```

**Default:** Your host username

#### `OCX_UID`
User ID to use inside the container.

**Type:** Integer

**Example:**
```bash
export OCX_UID=1000
```

**Default:** Your host UID

**Note:** OCX automatically handles UID conflicts with existing users.

#### `OCX_GID`
Group ID to use inside the container.

**Type:** Integer

**Example:**
```bash
export OCX_GID=1000
```

**Default:** Your host GID

**Note:** OCX automatically handles GID conflicts with existing groups.

### Configuration and Environment Files

#### `OCX_OPENCODE_CONFIG_DIR`
Path to the OpenCode configuration directory (mounted into the container).

**Type:** Directory path

**Example:**
```bash
export OCX_OPENCODE_CONFIG_DIR=/home/user/.config/opencode
```

**Default:** `~/.config/opencode`

#### `OCX_ENV_FILE`
Path to a project-specific environment file to load.

**Type:** File path

**Example:**
```bash
export OCX_ENV_FILE=.env.local
```

**Default:** `./ocx.env`

**Note:** Both global (`~/.config/ocx/ocx.env`) and project environment files are loaded.

### Data Volumes

#### `OCX_DATA_VOLUMES_MODE`
Control when data volumes (cache and local) are created.

**Type:** Enum (`always`, `git`, `never`)

**Example:**
```bash
export OCX_DATA_VOLUMES_MODE=always
export OCX_DATA_VOLUMES_MODE=never
```

**Default:** `git`

**Values:**
- `git` - Create volumes only for git repositories (default)
- `always` - Create volumes for all projects (git and non-git)
- `never` - Never create data volumes

**See:** [Volume Management](volume-management.md) for detailed information

#### `OCX_DATA_VOLUMES_NAME`
Override automatic volume naming with a custom name.

**Type:** String (lowercase alphanumeric + hyphens)

**Example:**
```bash
export OCX_DATA_VOLUMES_NAME=my-shared-cache
```

**Default:** None (uses automatic naming based on git remote or directory path)

**Warning:** Using the same volume name across different projects will make them share volumes, which can cause dependency conflicts.

**Valid format:** Must contain only lowercase letters, numbers, and hyphens, and start with a letter or number.

### Other

#### `TZ`
Timezone for the container.

**Type:** Timezone string (IANA timezone database)

**Example:**
```bash
export TZ=America/New_York
export TZ=UTC
```

**Default:** Host timezone

## Usage Examples

### Quick Override for One Command

```bash
OCX_PORT=9000 OCX_PUBLISH_PORT=true ocx opencode
```

### Temporary Resource Increase

```bash
OCX_MEMORY=4096m OCX_CPUS=4.0 ocx exec bundle test
```

### Development vs Production Configuration

**Development (`~/.bashrc` or shell profile):**
```bash
export OCX_MEMORY=2048m
export OCX_CPUS=2.0
export OCX_NETWORK=bridge
export OCX_PUBLISH_PORT=true
```

**Production/CI (environment-specific):**
```bash
export OCX_MEMORY=1024m
export OCX_CPUS=1.0
export OCX_NETWORK=none
export OCX_PUBLISH_PORT=false
export OCX_FORBIDDEN_PATHS=/etc,/root,/var
```

### Using Environment Files

Create `.env` files for different scenarios:

**`~/.config/ocx/ocx.env` (global defaults):**
```bash
OCX_MEMORY=2048m
OCX_CPUS=2.0
TZ=UTC
```

**`./ocx.env` (project-specific):**
```bash
OCX_PORT=8080
OCX_PUBLISH_PORT=true
OCX_CUSTOM_BASE_DOCKERFILE=docker/Dockerfile
```

Both files are loaded, with project settings taking precedence.

### Debugging Configuration

To see which configuration values are being used and their source:

```bash
ocx config --sources
```

This shows each configuration option with its value and where it came from (env var, config file, or default).

## Validation Rules

### Memory Format
Must be a number followed by a unit:
- Valid: `512m`, `1g`, `2048m`, `4g`
- Invalid: `512`, `1gb`, `1024`, `2.5g`

### Port Range
Must be between 1024 and 65535 (inclusive)

### Version Format
Must be either `latest` or a semantic version `X.Y.Z`

### CPU Values
Must be a positive number or zero
- Valid: `0.5`, `1.0`, `2.0`, `4.5`
- Invalid: `-1`, `abc`

### PIDS Limit
Must be a positive integer

## Common Patterns

### 1. Override All Resources for Heavy Workloads

```bash
export OCX_MEMORY=8192m
export OCX_CPUS=8.0
export OCX_PIDS_LIMIT=500
export OCX_TMP_SIZE=2g
export OCX_WORKSPACE_TMP_SIZE=2g
```

### 2. Isolated Network for Security

```bash
export OCX_NETWORK=none
export OCX_PUBLISH_PORT=false
export OCX_FORBIDDEN_PATHS=/etc,/root,/var,/home
```

### 3. Host Network for Local Services

```bash
export OCX_NETWORK=host
export OCX_PUBLISH_PORT=false
```

**Use case:** Accessing local databases, services running on host

### 4. Custom Port for Multiple Projects

**Project A:**
```bash
export OCX_PORT=3001
ocx opencode
```

**Project B:**
```bash
export OCX_PORT=3002
ocx opencode
```

Or use auto-generated ports:
```bash
ocx port  # Returns deterministic port based on path
```

### 5. Minimal Resources for CI/CD

```bash
export OCX_MEMORY=512m
export OCX_CPUS=0.5
export OCX_PIDS_LIMIT=50
export OCX_NETWORK=none
export OCX_PUBLISH_PORT=false
export OCX_DATA_VOLUMES_MODE=never  # No caching in CI
```

### 6. Share Volumes Across Related Projects

```bash
# For microservices that share dependencies
export OCX_DATA_VOLUMES_NAME=my-team-shared-cache
```

**Use case:** Multiple related projects with compatible dependencies can share the same cache volumes for faster installs.

### 7. Disable Volumes for Temporary Work

```bash
export OCX_DATA_VOLUMES_MODE=never
ocx opencode
```

**Use case:** Quick testing, disposable environments, or when you want a completely clean state.

## Troubleshooting

### Variables Not Taking Effect

1. Check if you're setting them correctly:
   ```bash
   export OCX_PORT=8080  # Correct
   OCX_PORT=8080         # Only for current command
   ```

2. Verify with `ocx config --sources`

3. Check for typos in variable names

### Resource Limit Errors

**"OCI runtime create failed: container_linux.go:380: starting container process caused: process_linux.go:545: container init caused: process_linux.go:519: setting cgroup config for process caused: failed to write "memory.limit_in_bytes": write /sys/fs/cgroup/memory/.../memory.limit_in_bytes: invalid argument"**

**Cause:** Invalid memory format

**Solution:** Use correct format like `1024m` or `1g`, not `1024`

### Port Already in Use

**Error:** Port is already allocated

**Solution:** Either:
- Use a different port: `export OCX_PORT=9000`
- Use auto-generated: remove `OCX_PORT` variable
- Stop the conflicting container

### Permission Issues

If files are not writable after changing UID/GID:

```bash
# Rebuild images with new user mapping
ocx build --force
```

## Best Practices

1. **Use Config Files for Persistent Settings**
   - Store project settings in `./ocx.json`
   - Store global settings in `~/.config/ocx/ocx.json`
   - Use env vars for temporary overrides

2. **Keep Secrets Out of Environment Files**
   - Don't commit `.env` files to version control
   - Use secret management tools for sensitive data
   - Pass secrets as runtime env vars only

3. **Document Your Environment**
   - Comment your `.env` files
   - Keep a `.env.example` file for reference
   - Document required env vars in README

4. **Use Different Configs for Different Environments**
   ```bash
   # Development
   export OCX_ENV_FILE=.env.development

   # Testing
   export OCX_ENV_FILE=.env.test

   # Production
   export OCX_ENV_FILE=.env.production
   ```

5. **Version Pinning for Reproducibility**
   ```bash
   export OCX_OPENCODE_VERSION=1.2.3  # Pin specific version
   ```
   This ensures all team members use the same version.
