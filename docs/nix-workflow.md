# Nix Workflow

OCX supports optional Nix package management through a dual-container architecture. This enables you to use Nix for centralized dependency management across all your OCX projects without requiring Nix to be installed on your host system.

## Architecture

The Nix workflow uses two types of containers:

1. **Master Nix Container (nix-daemon)**: A long-running container that runs the Nix daemon and manages the shared `/nix` store
2. **Dev Containers**: Your regular OCX containers that access the `/nix` store read-only to use Nix packages

This architecture provides:
- **Centralized package cache**: All projects share the same Nix store, reducing disk usage and build times
- **Portability**: Works on any system with Docker, no host Nix installation required
- **Isolation**: Nix daemon runs in its own container with appropriate security controls

## Configuration

### Enable Nix Workflow

You can enable the Nix workflow in three ways:

#### 1. Project Configuration (Recommended)

Create or edit `ocx.json` in your project directory:

```json
{
  "nix_enabled": true
}
```

#### 2. Global Configuration

Create or edit `~/.config/ocx/ocx.json`:

```json
{
  "nix_enabled": true
}
```

#### 3. Environment Variables

```bash
export OCX_NIX_ENABLED=true
```

### Configuration Options

All Nix-related configuration options with their defaults:

| Option | Default | Description |
|--------|---------|-------------|
| `nix_enabled` | `false` | Enable Nix workflow |
| `nix_volume_name` | `"ocx-nix"` | Named volume for shared /nix store |
| `nix_daemon_container_name` | `"ocx-nix-daemon"` | Master nix daemon container name |

### Environment Variables

- `OCX_NIX_ENABLED` - Enable/disable Nix workflow (true/false)
- `OCX_NIX_VOLUME_NAME` - Override the Nix volume name
- `OCX_NIX_DAEMON_CONTAINER_NAME` - Override the daemon container name

## Usage

### Basic Usage

Once you've enabled the Nix workflow, OCX will automatically:

1. Start the nix-daemon container when you run `ocx opencode` (or any dev container command)
2. Mount the shared `/nix` volume read-only in your dev containers
3. Make `nix` commands available in your containers

```bash
# Enable nix in your project
echo '{"nix_enabled": true}' > ocx.json

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

### Example Project Setup

Here's a complete example of setting up a project with Nix and OCX:

1. **Create a flake.nix** in your project:

```nix
{
  description = "My development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
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
  "nix_enabled": true,
  "opencode_command": ["nix", "develop", "-c", "opencode"]
}
EOF
```

3. **Run OCX**:

```bash
ocx opencode
# Nix daemon starts automatically
# Your flake environment is loaded
# OpenCode runs with all your Nix packages available
```

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

When `nix_enabled: true`, the nix-daemon image is automatically built when needed.

### Manual Build

```bash
# Build all images including nix-daemon
ocx build --base --force

# The nix-daemon image will be built if nix is enabled
```

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

# Ensure nix_enabled is true
echo '{"nix_enabled": true}' > ocx.json

# Rebuild if needed
ocx build --force
```

### Slow First Run

**Symptom**: First `nix develop` or `nix-shell` command takes a long time.

**Explanation**: This is normal. The first run:
1. Initializes the Nix store in the volume
2. Downloads all packages from scratch

Subsequent runs will be much faster as packages are cached.

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
  "nix_enabled": true,
  "nix_volume_name": "my-project-nix"
}
```

Each unique volume name creates a separate Nix store.

### Custom Daemon Container Name

```json
{
  "nix_enabled": true,
  "nix_daemon_container_name": "my-nix-daemon"
}
```

### Using with Custom OpenCode Commands

Combine Nix workflow with custom commands:

```json
{
  "nix_enabled": true,
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
  "nix_enabled": true
}
```

Remove the `extra_data_volumes` entry and enable `nix_enabled`. The nix-daemon container will provide `/nix` instead of your host.

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

Simply set `nix_enabled: false` and rebuild. The volume and daemon remain but won't be used.

### How do I backup my Nix store?

```bash
# Backup the volume
docker run --rm -v ocx-nix:/nix -v $(pwd):/backup alpine \
  tar czf /backup/ocx-nix-backup.tar.gz /nix
```

### Can I use Nix flakes with this?

Yes! Flakes are enabled by default in the nix-daemon configuration.

## See Also

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [OCX Custom Base Images](custom-base-template.md)
- [OCX Configuration](../README.md#configuration)
