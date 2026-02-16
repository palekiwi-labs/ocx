# Nix Workflow

OCX supports optional Nix package management through a dual-container architecture. This enables you to use Nix for centralized dependency management across all your OCX projects without requiring Nix to be installed on your host system.

## Architecture

The Nix workflow uses a specialized architecture optimized for Nix package management:

1. **Master Nix Container (nix-daemon)**: A long-running container that runs the Nix daemon and manages the shared `/nix` store
2. **Dev Containers**: Lightweight containers that use the single `ocx-nix:latest` image and access the `/nix` store read-only
3. **Default Flake**: A shared flake configuration at `/nix/var/ocx/` that provides OpenCode and can be used by all dev containers

This architecture provides:
- **Centralized package cache**: All projects share the same Nix store, reducing disk usage and build times
- **Portability**: Works on any system with Docker, no host Nix installation required
- **Isolation**: Nix daemon runs in its own container with appropriate security controls
- **Simplified images**: Dev containers use a single universal image without embedded OpenCode binaries
- **Flexible package management**: OpenCode and other tools are managed entirely through Nix

### Single Universal Image

When the Nix workflow is enabled, OCX uses a single universal dev image (`localhost/ocx-nix:latest`) instead of the traditional two-layer architecture (base + opencode). This image:

- Contains essential development tools (git, ripgrep, curl, etc.)
- Configures Nix with flakes enabled
- Sets up the container user and workspace
- **Does not include the OpenCode binary** - OpenCode is provided by Nix

This means:
- No version in the image tag (OpenCode version is managed by the flake)
- Faster image builds (no binary downloads)
- Updates are managed through `ocx nix update` rather than rebuilding images
- Custom base images (`custom_base_dockerfile`) are not supported with the Nix workflow

### Default Flake & Nested Shells

OCX automatically provides a default flake at `/nix/var/ocx/flake.nix` that includes OpenCode from the official GitHub repository. This flake:

- Tracks the production branch of OpenCode (`github:anomalyco/opencode/production`)
- Is shared across all your OCX projects using the same nix volume
- Can be updated with `ocx nix update` to get the latest stable OpenCode
- Provides the base development environment (OpenCode + common tools)

**Important**: When the Nix workflow is enabled, OCX **always** runs your commands inside the default flake's devshell first, then executes your project-specific environment (if configured). This nested shell architecture means:

1. **You don't need to include OpenCode in your project's `flake.nix`** - it's automatically provided by the default flake
2. **Your project flake is for project-specific dependencies** - Node.js, Python, Rust, etc.
3. **Environments are additive** - You get both the platform tools (from default) and your project tools
4. **You can override OpenCode version** - If you include `opencode` in your project flake, it takes precedence

Example command execution:
```bash
# What you configure:
"opencode_command": ["nix", "develop", "-c", "opencode"]

# What actually runs:
nix develop /nix/var/ocx -c nix develop -c opencode
#           ↑                          ↑
#     Default flake (platform)    Your project flake
#     Provides: OpenCode          Provides: Your deps
```

## Configuration

### Enable Nix Workflow

You can enable the Nix workflow in three ways:

#### 1. Project Configuration (Recommended)

Create or edit `ocx.json` in your project directory:

```json
{
  "nix": true
}
```

#### 2. Global Configuration

Create or edit `~/.config/ocx/ocx.json`:

```json
{
  "nix": true
}
```

#### 3. Environment Variables

```bash
export OCX_NIX=true
```

### Configuration Options

All Nix-related configuration options with their defaults:

| Option | Default | Description |
|--------|---------|-------------|
| `nix` | `false` | Enable Nix workflow |
| `nix_volume_name` | `"ocx-nix"` | Named volume for shared /nix store |
| `nix_daemon_container_name` | `"ocx-nix-daemon"` | Master nix daemon container name |
| `nix_extra_substituters` | `[]` | Additional binary cache servers beyond cache.nixos.org |
| `nix_extra_trusted_public_keys` | `[]` | Public keys for additional substituters |

### Environment Variables

- `OCX_NIX` - Enable/disable Nix workflow (true/false)
- `OCX_NIX_VOLUME_NAME` - Override the Nix volume name
- `OCX_NIX_DAEMON_CONTAINER_NAME` - Override the daemon container name
- `OCX_NIX_EXTRA_SUBSTITUTERS` - Colon-separated list of additional binary caches
- `OCX_NIX_EXTRA_TRUSTED_PUBLIC_KEYS` - Colon-separated list of public keys for caches

## Usage

### Basic Usage

Once you've enabled the Nix workflow, OCX will automatically:

1. Start the nix-daemon container when you run `ocx opencode` (or any dev container command)
2. Mount the shared `/nix` volume read-only in your dev containers
3. Make `nix` commands available in your containers

```bash
# Enable nix in your project
echo '{"nix": true}' > ocx.json

# Run OCX (nix daemon starts automatically)
ocx opencode

# Inside the container, use nix as normal
$ nix develop
$ nix-shell
$ nix run nixpkgs#hello
```

### Managing the Nix Daemon

The nix-daemon container is automatically managed, but you can also control it manually:

#### Check Status

```bash
ocx nix status
```

Output:
```
Nix Workflow Status:
  Enabled: true
  Container: ocx-nix-daemon
  Volume: ocx-nix
  Image: localhost/ocx-nix-daemon:latest

  Status: Running ✓

Container stats:
CONTAINER        CPU %    MEM USAGE / LIMIT    MEM %    NET I/O          BLOCK I/O
ocx-nix-daemon   0.01%    23.45MiB / 1.952GiB  1.17%    1.23kB / 0B      0B / 0B

Volume info:
Name        Mountpoint                                      Driver    CreatedAt
ocx-nix     /var/lib/docker/volumes/ocx-nix/_data          local     2026-02-16T10:30:45Z
```

#### Manually Start

```bash
ocx nix start
```

The daemon is automatically started when needed, so this is rarely necessary.

#### Stop Daemon

```bash
ocx nix stop
```

The daemon is lightweight when idle, so stopping it is usually not necessary. However, you might want to stop it:
- Before system shutdown or restart
- To force a clean restart
- To free up minimal resources

#### Restart Daemon

```bash
ocx nix restart
```

#### Update Default Flake

```bash
ocx nix update
```

Updates the default flake's `flake.lock` to get the latest OpenCode and other dependencies. After updating, restart your dev containers to use the new versions:

```bash
ocx nix update
ocx stop
ocx opencode
```

### Configuring Binary Caches (Substituters)

Binary caches (also called substituters) allow Nix to download pre-built packages instead of building them from source. OCX automatically configures the official `cache.nixos.org` cache, but you can add additional caches such as corporate caches, community caches, or private caches.

#### Adding Custom Caches

To add additional binary caches, configure `nix_extra_substituters` and their corresponding `nix_extra_trusted_public_keys` in your `ocx.json`:

```json
{
  "nix": true,
  "nix_extra_substituters": [
    "https://cache.garnix.io",
    "https://mycorp-cache.example.com"
  ],
  "nix_extra_trusted_public_keys": [
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=",
    "mycorp-cache:abc123..."
  ]
}
```

**Important Notes:**

- **Rebuild Required**: After changing substituter configuration, you must rebuild the nix-daemon image:
  ```bash
  ocx build --base --force
  ocx nix restart
  ```

- **Security**: Only add trusted public keys for caches you trust. The public key ensures that packages from the cache haven't been tampered with.

- **Default Cache**: The official `cache.nixos.org` is always included automatically with its public key. You only need to specify additional caches.

#### Using Environment Variables

You can also configure substituters via environment variables using colon-separated lists:

```bash
export OCX_NIX_EXTRA_SUBSTITUTERS="https://cache.garnix.io:https://mycorp.example.com"
export OCX_NIX_EXTRA_TRUSTED_PUBLIC_KEYS="cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=:mycorp:abc123..."
```

#### Finding Public Keys

Most public Nix caches publish their public keys in their documentation:

- **Cachix caches**: Visit `https://app.cachix.org/<cache-name>` for instructions
- **Garnix**: Documentation at https://garnix.io/docs/caching
- **Custom caches**: Usually provided by your infrastructure team or in the cache's setup documentation

#### Common Use Cases

**Corporate/Private Cache:**
```json
{
  "nix": true,
  "nix_extra_substituters": ["https://nix-cache.corp.internal"],
  "nix_extra_trusted_public_keys": ["corp-cache:YourPublicKeyHere="]
}
```

**Community Cache (Cachix):**
```json
{
  "nix": true,
  "nix_extra_substituters": ["https://cache.cachix.org/your-cache"],
  "nix_extra_trusted_public_keys": ["your-cache.cachix.org:YourPublicKeyHere="]
}
```

**Multiple Caches:**
```json
{
  "nix": true,
  "nix_extra_substituters": [
    "https://cache.garnix.io",
    "https://cache.cachix.org/devenv",
    "https://nix-cache.corp.internal"
  ],
  "nix_extra_trusted_public_keys": [
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=",
    "devenv.cachix.org:SomePublicKeyHere=",
    "corp-cache:YourPublicKeyHere="
  ]
}
```

### Version Management

When using the Nix workflow, OpenCode versions are managed through Nix flakes rather than downloading binaries from GitHub releases. This provides several advantages:

- **Reproducible builds**: The `flake.lock` file pins exact versions of all dependencies
- **Easy updates**: Run `ocx nix update` to get the latest versions
- **Custom versions**: Override with your own `flake.nix` to pin specific OpenCode versions
- **No image rebuilds**: Version changes don't require rebuilding the dev container image

#### Using the Default Flake

By default, OCX provides a flake at `/nix/var/ocx/` that tracks the latest OpenCode development version. This is used automatically when you run `ocx opencode` without a project-specific flake.

**To update to the latest OpenCode:**
```bash
ocx nix update
ocx stop
ocx opencode
```

#### Using a Specific OpenCode Version

To override the default OpenCode version, create a `flake.nix` in your project that includes OpenCode:

```nix
{
  description = "My project with OpenCode v1.1.23";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    opencode.url = "github:anomalyco/opencode/v1.1.23";  # Pin to specific version
  };

  outputs = { self, nixpkgs, opencode, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          opencode.packages.${system}.default  # This shadows the default flake's OpenCode
        ];
      };
    };
}
```

Configure OCX to use your flake:
```json
{
  "nix": true,
  "opencode_command": ["nix", "develop", "-c", "opencode"]
}
```

**How it works**: With nested shells, your project's OpenCode appears earlier in PATH and takes precedence over the default flake's version.

#### Checking Current Version

Inside the container:
```bash
opencode --version
```

Or to see what the flake would provide:
```bash
nix flake show /nix/var/ocx
```

### Example Project Setup

#### Quick Start (No Custom Flake)

For projects without specific dependency requirements:

```bash
# Enable nix workflow
echo '{"nix": true}' > ocx.json

# Run OCX
ocx opencode
# System automatically:
# 1. Starts nix-daemon
# 2. Initializes default flake with OpenCode
# 3. Launches OpenCode via nix develop
```

The default flake provides OpenCode and common tools. Perfect for exploring projects or quick prototyping.

#### With Custom Dependencies

For projects needing specific packages alongside OpenCode:

1. **Create a flake.nix** in your project:

```nix
{
  description = "My development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # Note: OpenCode is provided by OCX's default flake
          # Only include your project-specific dependencies here
          nodejs_20
          python311
          rustc
          cargo
        ];
      };
    };
}
```

2. **Configure OCX** for Nix workflow:

```bash
cat > ocx.json <<EOF
{
  "nix": true,
  "opencode_command": ["nix", "develop", "-c", "opencode"]
}
EOF
```

3. **Run OCX**:

```bash
ocx opencode
# What happens:
# 1. Nix daemon starts automatically
# 2. Default flake provides OpenCode + base tools
# 3. Your project flake provides Node.js, Python, Rust
# 4. Nested shells merge both environments
# 5. OpenCode runs with all packages available
```

#### Overriding OpenCode Version

If you need a specific OpenCode version instead of the default:

```nix
{
  description = "Project with custom OpenCode version";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    opencode.url = "github:anomalyco/opencode/v1.2.5";  # Pin to specific version
  };

  outputs = { self, nixpkgs, opencode, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          opencode.packages.${system}.default  # Your version takes precedence
          pkgs.nodejs_20
        ];
      };
    };
}
```

Because of PATH precedence in nested shells, your project's OpenCode shadows the default flake's version.

## Volume Management

### Shared Volume

The Nix store is persisted in a Docker volume (default: `ocx-nix`). This volume is shared across all your OCX projects, which means:

- Packages are only downloaded and built once
- All projects benefit from the shared cache
- Disk usage is minimized

### Inspect Volume

```bash
# List volumes
docker volume ls | grep ocx-nix

# Inspect volume details
docker volume inspect ocx-nix

# Check volume size
docker system df -v | grep ocx-nix
```

### Clean Up

**Warning**: This will remove all cached Nix packages and require re-downloading them.

```bash
# Stop the daemon first
ocx nix stop

# Remove the volume
docker volume rm ocx-nix

# Next ocx run will create a fresh volume
```

### Garbage Collection

To clean up unused packages without removing everything:

```bash
# Run garbage collection in the nix daemon container
docker exec ocx-nix-daemon nix-collect-garbage -d

# For more aggressive cleanup
docker exec ocx-nix-daemon nix-store --gc
```

## Building Images

### Automatic Build

When `nix: true`, OCX automatically builds:
1. The nix-daemon image (`localhost/ocx-nix-daemon:latest`)
2. The single universal dev image (`localhost/ocx-nix:latest`)

These images are built when needed (first run or when missing).

### Manual Build

```bash
# Build all nix-related images
ocx build --base --force

# This builds:
# - localhost/ocx-nix-daemon:latest (nix daemon)
# - localhost/ocx-nix:latest (universal dev image)
```

**Note**: The dev image (`ocx-nix:latest`) has no version tag because it doesn't contain the OpenCode binary. OpenCode is provided by Nix at runtime through the flake configuration.

## Important Notes

### Custom Base Images Not Supported

When `nix: true`, the `custom_base_dockerfile` configuration option is **not supported**. The Nix workflow uses a specialized single-image architecture optimized for Nix package management.

If you have `custom_base_dockerfile` configured and enable the Nix workflow, OCX will:
- Display a warning
- Ignore the custom base configuration
- Use the standard `ocx-nix:latest` image

If you need custom dependencies, define them in your project's `flake.nix` instead.

### First Run Takes Longer

The first time you run `ocx opencode` with the Nix workflow or after running `ocx nix update`:
- Nix downloads and builds OpenCode and all dependencies
- This can take several minutes depending on your internet connection
- Subsequent runs are much faster as packages are cached in the shared `/nix` store

### Version Management Differences

Unlike the traditional OCX workflow where OpenCode versions are managed via image tags:
- The Nix workflow manages versions through `flake.lock`
- Run `ocx nix update` to get the latest versions
- Image rebuilds are not required for version updates
- The `opencode_version` config option is ignored when `nix: true`

### Shared Flake Across Projects

The default flake at `/nix/var/ocx/` is shared across all projects using the same nix volume:
- All projects without a custom flake use this shared configuration
- Running `ocx nix update` affects all projects using the default flake
- For project-specific versions, create a `flake.nix` in your project

## Troubleshooting

### Error: "cannot connect to nix daemon"

**Symptom**: Nix commands fail with connection errors.

**Solution**:
```bash
# Check if daemon is running
ocx nix status

# Restart daemon
ocx nix restart

# If still failing, try rebuilding
ocx build --base --force
```

### Error: "nix: command not found"

**Symptom**: The `nix` command is not available in the container.

**Possible causes**:
1. Nix workflow is not enabled
2. `/nix` volume is not mounted

**Solution**:
```bash
# Check configuration
ocx config | grep nix

# Ensure nix is true
echo '{"nix": true}' > ocx.json

# Rebuild if needed
ocx build --force
```

### Error: "opencode: command not found"

**Symptom**: OpenCode is not available in the container.

**Possible causes**:
1. Default flake not initialized
2. Nix develop command not configured correctly
3. OpenCode download failed

**Solution**:
```bash
# Check if default flake exists
docker exec ocx-nix-daemon test -f /nix/var/ocx/flake.nix && echo "Flake exists" || echo "Flake missing"

# If missing, the next run should initialize it
ocx stop
ocx opencode

# If flake exists but OpenCode still not available, try updating
ocx nix update
ocx stop
ocx opencode
```

### Error: "Default flake not found"

**Symptom**: Error message about missing default flake when running commands.

**Cause**: The default flake at `/nix/var/ocx/flake.nix` was not initialized or was deleted.

**Solution**:
```bash
# Ensure daemon is running
ocx nix start

# The next run of ocx opencode will reinitialize the flake
ocx opencode
```

If the problem persists, the template file may be missing from your OCX installation. Try reinstalling OCX.

### Slow First Run

**Symptom**: First `nix develop` or `nix-shell` command takes a long time.

**Explanation**: This is normal. The first run:
1. Initializes the Nix store in the volume
2. Downloads all packages from scratch
3. Builds OpenCode and dependencies from source

This can take 5-10 minutes on first run. Subsequent runs will be much faster as packages are cached.

### Volume Size Growing Large

**Symptom**: The `ocx-nix` volume is consuming significant disk space.

**Solutions**:

1. **Garbage collection** (recommended):
```bash
docker exec ocx-nix-daemon nix-collect-garbage -d
```

2. **Complete cleanup** (drastic):
```bash
ocx nix stop
docker volume rm ocx-nix
```

3. **Monitor usage**:
```bash
docker system df -v | grep ocx-nix
```

### Daemon Container Stops Unexpectedly

**Symptom**: The nix-daemon container is not running after reboot or Docker restart.

**Solution**:
```bash
# Restart daemon
ocx nix start

# Or just run ocx - it will auto-start
ocx opencode
```

## Advanced Usage

### Custom Nix Volume Name

If you want to isolate Nix stores between different project groups:

```json
{
  "nix": true,
  "nix_volume_name": "my-project-nix"
}
```

Each unique volume name creates a separate Nix store.

### Custom Daemon Container Name

```json
{
  "nix": true,
  "nix_daemon_container_name": "my-nix-daemon"
}
```

### Using with Custom OpenCode Commands

Combine Nix workflow with custom commands:

```json
{
  "nix": true,
  "opencode_command": ["nix", "develop", ".#myshell", "-c", "opencode", "--model", "claude-sonnet-4"]
}
```

### Accessing Nix Daemon Logs

```bash
# View daemon logs
docker logs ocx-nix-daemon

# Follow logs
docker logs -f ocx-nix-daemon
```

### Running Nix Commands in Daemon

```bash
# Execute commands in the daemon container
docker exec ocx-nix-daemon nix-channel --update
docker exec ocx-nix-daemon nix-store --verify --check-contents
docker exec ocx-nix-daemon nix-env -qa
```

## Migration

### From Host Nix (Bind Mount)

If you're currently using a bind mount from host `/nix`:

**Before** (bind mount):
```json
{
  "extra_data_volumes": {
    "nix": {
      "source": "/nix",
      "target": "/nix",
      "mode": "ro",
      "type": "bind"
    }
  }
}
```

**After** (nix workflow):
```json
{
  "nix": true
}
```

Remove the `extra_data_volumes` entry and enable `nix`. The nix-daemon container will provide `/nix` instead of your host.

## Performance Considerations

### Benefits

- **Package Cache Sharing**: Build once, use in all projects
- **Faster Startup**: Daemon stays warm between runs
- **Reduced Disk Usage**: One copy of packages shared across all projects

### Resource Usage

- **Idle Daemon**: ~20-30MB RAM, negligible CPU
- **During Builds**: Depends on what's being built
- **Volume Size**: Grows with packages; use garbage collection periodically

### Best Practices

1. **Let the daemon run**: It's lightweight when idle
2. **Share volumes**: Use default volume name to share cache across projects
3. **Regular garbage collection**: Run `nix-collect-garbage` periodically
4. **Monitor volume size**: Check with `docker system df -v`

## Security Considerations

### Isolation

- Nix daemon runs in its own container with minimal privileges
- Dev containers access `/nix` read-only
- No network ports exposed by daemon
- Communication via Unix socket in shared volume

### Shared Volume Implications

- Multiple projects share the same Nix store
- Nix uses content-addressed storage (reproducible, safe)
- Don't use for proprietary/sensitive package sources if sharing with untrusted projects

## FAQ

### Why use the daemon architecture instead of Nix in each container?

The daemon architecture provides:
- Shared package cache across all projects
- Reduced disk usage (one copy vs. many)
- Centralized management
- Better performance (shared builds)

### Does this require Nix on my host?

No! That's one of the main benefits. The nix-daemon container provides everything needed.

### Can I use this with NixOS?

Yes! It works the same way. You can even keep your host Nix separate from OCX's containerized Nix.

### Can I have multiple Nix volumes for different projects?

Yes, use different `nix_volume_name` values. However, sharing a single volume is recommended for maximum efficiency.

### What happens if I disable Nix workflow?

Simply set `nix: false` and rebuild. The volume and daemon remain but won't be used.

### How do I backup my Nix store?

```bash
# Backup the volume
docker run --rm -v ocx-nix:/nix -v $(pwd):/backup alpine \
  tar czf /backup/ocx-nix-backup.tar.gz /nix
```

### Can I use Nix flakes with this?

Yes! Flakes are enabled by default in the nix-daemon configuration.

### How is the Nix workflow different from the standard OCX workflow?

**Standard OCX workflow:**
- Uses base image + final image architecture
- Downloads OpenCode binary from GitHub releases
- Version managed via image tags (e.g., `localhost/ocx:1.1.23`)
- Update via `ocx upgrade` which rebuilds images

**Nix workflow:**
- Uses single universal image (`localhost/ocx-nix:latest`)
- OpenCode provided by Nix at runtime via flake
- Version managed via `flake.lock`
- Update via `ocx nix update` (no rebuild needed)

### Can I use custom base images with the Nix workflow?

No, `custom_base_dockerfile` is not supported when `nix: true`. The Nix workflow uses a specialized single-image architecture.

For custom dependencies, define them in your project's `flake.nix` instead:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    opencode.url = "github:anomalyco/opencode/dev";
  };
  outputs = { nixpkgs, opencode, ... }: {
    # Add your custom packages here
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [
        pkgs.opencode
        pkgs.myCustomPackage
      ];
    };
  };
}
```

### How do I update OpenCode with the Nix workflow?

```bash
ocx nix update  # Updates flake.lock
ocx stop
ocx opencode    # Restart with new version
```

This updates the default flake to get the latest OpenCode from the dev branch.

### What if I need a specific OpenCode version?

Create a project-specific `flake.nix` that pins to the desired version:

```nix
{
  inputs = {
    opencode.url = "github:anomalyco/opencode/v1.1.23";  # Pin version
  };
}
```

Then configure OCX to use your flake:
```json
{
  "nix": true,
  "opencode_command": ["nix", "develop", "-c", "opencode"]
}
```

### Where is the default flake stored?

The default flake is at `/nix/var/ocx/flake.nix` inside the shared nix volume. This location:
- Is accessible to both the daemon and all dev containers
- Persists across container restarts
- Is shared by all projects using the same nix volume

You can inspect it:
```bash
docker exec ocx-nix-daemon cat /nix/var/ocx/flake.nix
```

## See Also

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [OCX Custom Base Images](custom-base-template.md)
- [OCX Configuration](../README.md#configuration)
