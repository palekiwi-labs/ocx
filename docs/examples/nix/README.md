# Nix Development Container Examples

> **Note:** The mounted-nix approach is now available as a built-in variant. For most users, we recommend using the simpler configuration:
> ```json
> {"base_variant": "nix"}
> ```
> This automatically configures the mounted-nix setup with a single line. The examples below remain useful for understanding the approach or for advanced customization.

This directory contains several strategies for using Nix with OCX. Nix provides a powerful way to manage reproducible development environments.

## Available Strategies

Choose the strategy that best fits your workflow:

### 1. `Dockerfile.mounted-nix` (Recommended for Nix users)
**Best for:** Developers who already have Nix installed on their host and want to share its packages.

- Mounts the host's `/nix` directory as a read-only bind mount.
- Zero duplication: Uses packages already present on the host.
- Maximum performance: No downloads or builds during container setup.
- **Requires:** Host `/nix` to be mounted via `ocx.json`.

### 2. `Dockerfile.build-user`
**Best for:** Teams who want Nix-provided tools without requiring Nix on every developer's host.

- Installs Nix during the image build to fetch specific tools.
- Copies binaries to `/usr/local/bin`.
- The final container does NOT need Nix installed or mounted.
- Tools are available to all users in the standard `PATH`.

### 3. `Dockerfile.final-user`
**Best for:** Nix power users who want a full, independent Nix environment inside the container.

- Installs Nix specifically for the OCX user.
- Allows installing new packages at runtime (`nix profile add ...`).
- Useful for experiments or dynamic tool requirements.

## Setup Instructions

1. **Choose a Dockerfile** and reference it in your `ocx.json`:
   ```json
   {
     "custom_base_dockerfile": "Dockerfile.mounted-nix"
   }
   ```

2. **Configure Mounts** (Required for `Dockerfile.mounted-nix`):
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

3. **Start OCX**:
   ```bash
   ocx opencode
   ```

## Benefits of the Mounted Approach

- **Security:** The host `/nix` directory is mounted `ro` (read-only), so the container cannot modify host state.
- **Efficiency:** Host and container share the same store, eliminating multi-gigabyte duplication.
- **Consistency:** Ensures the exact same tool versions are used in both environments.
