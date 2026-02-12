# Nix Development Container Example

This example demonstrates sharing the host Nix store with the container using read-only bind mounts.

## Prerequisites

- Nix installed on host system
- Flake-based project with `flake.nix`

## Setup

1. Build packages on host:
   ```bash
   nix develop
   ```

2. Configure ocx to mount Nix store:
   ```bash
   cp ocx.json /path/to/your/project/
   ```

3. Start container:
   ```bash
   cd /path/to/your/project
   ocx opencode
   ```

4. Inside container:
   ```bash
   nix develop  # Reuses host packages from read-only store
   ```

## Benefits

- Zero package duplication between host and containers
- Maximum security (containers cannot modify Nix store)
- Consistent environments (host and containers use identical binaries)
- Fast container startup (no downloads or builds)

## Security

The read-only mounts (`mode: "ro"`) ensure containers cannot:
- Corrupt packages used by host or other containers
- Replace binaries with malicious versions
- Manipulate garbage collection

All builds happen on host; containers are read-only consumers.
