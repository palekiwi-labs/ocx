# OCX - Secure Docker Wrapper for OpenCode

**OCX** is a secure, Nix-powered Docker wrapper designed to simplify running OpenCode environments. It handles the complexities of file permissions (UID/GID mapping), workspace mounting, and container management, allowing you to focus on your code.

## Key Features

- **Secure Workspace Mounting**: Automatically mounts your project directory into the container with correct permissions.
- **Automatic UID/GID Mapping**: Resolves common Docker file permission issues by mapping the container user to your host user.
- **Custom Base Images**: Extend any Docker image (Ubuntu, Ruby, Node, Python, etc.) to use as your development environment.
- **Nix Powered**: Distributed as a Nix flake for reproducible builds and easy installation.
- **Integrated Tooling**: Built-in commands for container management (`shell`, `stats`, `exec`).
- **Easy Upgrades**: Built-in upgrade command to fetch and install the latest OpenCode versions.

## Documentation

For detailed guides and configuration options, see the [docs](docs/index.md) directory:

### Configuration
- [Port Configuration](docs/port-configuration.md) - Configure and manage ports for opencode server
- [Environment Variables](docs/environment-variables.md) - Complete reference of all supported environment variables
- [Volume Management](docs/volume-management.md) - Configure data volumes, sharing, and migration

### Customization
- [Custom Base Image Template](docs/custom-base-template.md) - Create custom Docker base images

### Operations
- [Image Management](docs/image-management.md) - Manage Docker images, building, pruning, and troubleshooting
- [Upgrading](docs/upgrading.md) - Upgrade OpenCode, version management, and release notes

### Security
- [Security Model](docs/security-model.md) - Security architecture, threat model, and design decisions
- [Security Hardening](docs/security-hardening.md) - Security features, configuration, and best practices

## Installation

OCX is available as a Nix Flake.

### Using Nix Flakes

Run directly:
```bash
nix run github:palekiwi-labs/ocx
```

Add to your system configuration or dev shell:
```nix
{
  inputs.ocx.url = "github:palekiwi-labs/ocx";
  # ...
  environment.systemPackages = [ inputs.ocx.packages.${system}.default ];
}
```

## Usage

The main command is `ocx`.

### Quick Start

Run the OpenCode container in the current directory:
```bash
ocx opencode
# OR alias
ocx o
```

This will:
1. Build the necessary Docker images (if missing).
2. Mount the current directory (or `OCX_WORKSPACE`) into the container.
3. Start the OpenCode environment.

### Commands

| Command | Description |
|---------|-------------|
| `ocx opencode`, `ocx o` | Run the OpenCode container interactively. |
| `ocx build` | Build the Docker images. Use `--force` to rebuild. |
| `ocx config` | Display the current configuration. |
| `ocx port` | Show the port number that will be used for the container. |
| `ocx shell` | Open a bash shell inside the running container. |
| `ocx exec <cmd>` | Execute a command inside the running container (e.g., `ocx exec ls -la`). |
| `ocx stop` | Stop the project container. |
| `ocx ps` | Show the status of the project container. |
| `ocx stats` | Show resource usage stats for the container. |
| `ocx upgrade` | Check for and install OpenCode updates. |
| `ocx volume` | List project volumes. |

## Configuration

OCX can be configured via JSON files or environment variables.

**Priority Order:**
1. Environment Variables (highest priority)*
2. Project Config (`./ocx.json`)*
3. Global Config (`~/.config/ocx/ocx.json`)*
4. Defaults (lowest priority)

*For array fields (like `forbidden_paths`), values are merged/combined across all levels rather than replaced. This ensures global security settings are preserved when project-specific values are added.

### Configuration File (`ocx.json`)

Example `ocx.json`:
```json
{
  "custom_base_dockerfile": "docker/Dockerfile",
  "publish_port": true,
  "opencode_version": "latest",
  "memory": "2048m",
  "add_host_docker_internal": true
}
```

### Environment Variables

- `OCX_WORKSPACE`: Path to the workspace directory (defaults to current dir).
- `OCX_CONTAINER_NAME`: Override the container name.
- `OCX_PORT`: Override the port number.
- `OCX_PUBLISH_PORT`: `true`/`false` to expose ports.
- `OCX_ADD_HOST_DOCKER_INTERNAL`: Add `--add-host=host.docker.internal:host-gateway` to enable host access from container (default: `false`).
- `OCX_CUSTOM_BASE_DOCKERFILE`: Path to a custom Dockerfile.
- `OCX_MEMORY`: Memory limit (default `1024m`).
- `OCX_CPUS`: CPU limit (default `1.0`).

## Custom Base Images

You can use any Docker image as your base environment. OCX will automatically layer the OpenCode requirements on top of it.

### Requirements for Custom Images
1. **Linux with glibc**: (Debian, Ubuntu, Fedora, etc. work out of the box).
2. **`curl`**: Must be installed (required to download OpenCode).
3. **User Tools**: `useradd`, `groupadd` (usually in `shadow` or `shadow-utils`).

### Example: Ruby Environment

Create a `Dockerfile` in your project (e.g., `docker-ocx/Dockerfile`):

```dockerfile
FROM ruby:3.2-slim

# Install system dependencies (curl is REQUIRED)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*
```

Update your `ocx.json`:
```json
{
  "custom_base_dockerfile": "docker-ocx/Dockerfile"
}
```

Then rebuild:
```bash
ocx build --force
```

For more details on custom images, see [docs/custom-base-template.md](docs/custom-base-template.md).

## Troubleshooting

**Error: "curl: not found"**
Your custom base image is missing `curl`. Add it to your Dockerfile.

**Permission Denied on Files**
OCX usually handles this automatically. If issues persist:
1. Ensure you are not running `ocx` as root.
2. Run `ocx build --force` to regenerate the user mapping.
3. Check `ocx config` to verify workspace paths.

## License

MIT
