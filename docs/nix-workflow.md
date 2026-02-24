# Nix Workflow

OCX supports optional Nix package management through a daemon-based architecture. This enables you to use Nix for centralized dependency management across all your OCX projects without requiring Nix to be installed on your host system.

## Architecture Overview

The Nix workflow uses a specialized two-container architecture:

1. **Nix Daemon Container** (`ocx-nix-daemon`): A long-running container that runs the Nix daemon and manages the shared `/nix` store volume
2. **Dev Containers**: Lightweight containers that run the `localhost/ocx-nix` image (versioned by OpenCode version) with `/nix` mounted read-only

Key design points:
- **OpenCode is embedded in the dev image** (versioned like `localhost/ocx-nix:1.2.3`)
- **User flake is on the host** at `~/.config/ocx/nix/flake.nix` (optional)
- **Shared Nix store** reduces disk usage and build times across all projects
- **No host Nix installation required** — the daemon container provides everything

## Enabling Nix Workflow

Enable in your `ocx.json` (project or global):

```json
{
  "nix": true
}
```

Or via environment variable:
```bash
export OCX_NIX=true
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `nix` | `false` | Enable Nix workflow |
| `nix_volume_name` | `"ocx-nix"` | Named volume for shared `/nix` store |
| `nix_daemon_container_name` | `"ocx-nix-daemon"` | Nix daemon container name |
| `nix_extra_substituters` | `[]` | Additional binary cache servers |
| `nix_extra_trusted_public_keys` | `[]` | Public keys for additional caches |

### Environment Variables

- `OCX_NIX` — Enable/disable Nix workflow (true/false)
- `OCX_NIX_VOLUME_NAME` — Override the Nix volume name
- `OCX_NIX_DAEMON_CONTAINER_NAME` — Override the daemon container name
- `OCX_NIX_EXTRA_SUBSTITUTERS` — Colon-separated list of additional binary caches
- `OCX_NIX_EXTRA_TRUSTED_PUBLIC_KEYS` — Colon-separated list of public keys

## Basic Usage

Once enabled, OCX handles the Nix daemon automatically:

```bash
# Enable nix in your project
echo '{"nix": true}' > ocx.json

# Run OCX (daemon starts automatically if needed)
ocx opencode

# Inside the container, nix is available
$ nix --version
$ nix develop
$ nix-shell
```

## Managing the Nix Daemon

### Check Status

```bash
ocx nix status
```

Shows daemon status, Nix version, container stats, and volume information.

### Start Daemon Manually

```bash
ocx nix start
```

The daemon is started automatically when needed, so this is rarely necessary.

### Stop Daemon

```bash
ocx nix stop
```

### Restart Daemon

```bash
ocx nix restart
```

### Upgrade Nix Binary

```bash
ocx nix upgrade
```

Upgrades the Nix binary and daemon to the latest stable version from nixpkgs-unstable. The daemon is restarted automatically.

## Flake Management

If you have a custom flake at `~/.config/ocx/nix/flake.nix`, use these commands to manage it:

```bash
# Show flake outputs
ocx nix flake show

# Show flake metadata
ocx nix flake metadata

# Check flake evaluates correctly
ocx nix flake check

# Create missing lock entries
ocx nix flake lock

# Update all dependencies in lock file
ocx nix flake update

# Update a specific input
ocx nix flake update nixpkgs
```

## OpenCode Version Management

OpenCode is embedded in the dev image (`localhost/ocx-nix:<version>`), so version updates require rebuilding the image.

### Update to Latest Version

```bash
ocx upgrade        # Check GitHub for latest version
# Follow prompts to confirm and rebuild the image
```

### Use a Specific Version

Configure in `ocx.json`:

```json
{
  "nix": true,
  "opencode_version": "1.2.3"
}
```

Then rebuild:
```bash
ocx build --force
```

## Binary Caches (Substituters)

OCX automatically configures the official `cache.nixos.org`, but you can add additional caches for faster builds.

### Configure Additional Caches

In `ocx.json`:

```json
{
  "nix": true,
  "nix_extra_substituters": [
    "https://cache.garnix.io",
    "https://nix-cache.corp.internal"
  ],
  "nix_extra_trusted_public_keys": [
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=",
    "corp-cache:YourPublicKeyHere="
  ]
}
```

**After changing caches, rebuild the daemon:**
```bash
ocx build --base --force
```

## User-Wide Development Environment with Flakes

OCX looks for a single, user-wide flake at `~/.config/ocx/nix/flake.nix`. If this file exists, it will be used to create a development environment for your projects.

**Note**: This is different from the typical project-based flake setup. This single flake is intended to provide a consistent development environment across all your OCX projects.

To set this up, create a flake at `~/.config/ocx/nix/flake.nix`:

```nix
{
  description = "My development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nodejs_20
          python311
          rustc
        ];
      };
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

When you run `ocx opencode`, the dev environment will have both your packages and OpenCode available across all your projects.

## Volume Management

### Inspect the Nix Store

```bash
# List volumes
docker volume ls | grep ocx-nix

# Inspect volume details
docker volume inspect ocx-nix

# Check volume size
docker system df -v | grep ocx-nix
```

### Garbage Collection

Clean up unused packages (recommended periodically):

```bash
docker exec ocx-nix-daemon nix-collect-garbage -d
```

### Complete Cleanup (Removes All Cached Packages)

```bash
ocx nix stop
docker volume rm ocx-nix
# The next ocx run will create a fresh volume
```

## Building Images

### Automatic

When `nix: true`, OCX automatically builds:
- The nix-daemon image (`localhost/ocx-nix-daemon:latest`)
- The dev image (`localhost/ocx-nix:<version>`)

### Manual Build

```bash
# Build all nix-related images
ocx build --base --force
```

## Troubleshooting

### "cannot connect to nix daemon"

The nix daemon container may have crashed or not started:

```bash
# Check status
ocx nix status

# Restart daemon
ocx nix start

# If still failing, rebuild
ocx build --base --force
```

### "nix: command not found"

Ensure the Nix workflow is enabled:

```bash
# Check configuration
ocx config | grep nix

# Enable it
echo '{"nix": true}' > ocx.json

# Rebuild
ocx build --force
```

### "opencode: command not found"

The dev image may not have been built with the OpenCode binary. Rebuild:

```bash
ocx build --force
```

### Slow First Run

The first time you run `nix develop` or `nix-shell`, Nix downloads and builds packages from scratch. This can take several minutes. Subsequent runs use cached packages and are much faster.

### Volume Growing Large

Garbage collection helps:

```bash
docker exec ocx-nix-daemon nix-collect-garbage -d
```

For more aggressive cleanup, see "Complete Cleanup" above.

## Advanced Configuration

### Separate Nix Stores

Use different `nix_volume_name` values to isolate Nix stores between project groups:

```json
{
  "nix": true,
  "nix_volume_name": "my-project-nix"
}
```

### Custom Daemon Container Name

```json
{
  "nix": true,
  "nix_daemon_container_name": "my-nix-daemon"
}
```

### Accessing Daemon Logs

```bash
# View logs
docker logs ocx-nix-daemon

# Follow logs in real-time
docker logs -f ocx-nix-daemon
```

## Important Notes

- **Custom base images are not supported** with `nix: true`. Use your project's `flake.nix` instead.
- **`opencode_version` is respected** — the dev image is built with the specified OpenCode version.
- **The Nix store persists** across container restarts and is shared by all projects using the same volume.
- **First run may be slow** as Nix downloads and builds packages. Subsequent runs are much faster.

## See Also

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [OCX Configuration](../README.md#configuration)
