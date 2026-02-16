# Feat: nix infrastructure

---

## Context

I want to be able to optionally use `nix` for centralized package management in ocx.

The example workflow we want to target is based around nix flakes and devshells.
In a git-tracked project, a user defines a typical devshell in their flake.nix.
User runs `ocx` with a custom opencode command (already supported by config), such as `nix develop .#ocx opencode`.

### Proposed architecture

We will use a dual-container architecture: a master nix container for building, and regular Debian dev containers for running shells.
These containers will share the same volume for `/nix`.

#### Nix Container

We need one master container that will be responsible for building packages and running the `nix-daemon`.

- will use a named volume mount (by default `ocx-nix`) that will be bound read-write to `/nix` in the container.
- we need a separate Dockerfile for this container because:
- we need to set `/etc/nix/nix.conf` to enable experimental flakes and nix command
- we need to set `gitconfig` to disable safe directory: nix container will run as root, but it will build for git repos owned by other users.
- we can call the Dockerfile: `Dockerfile.nix-daemon`

#### Dev Containers

- plain miminal Debian-based container
- need to have flakes and nix command enabled in `/etc/nix/nix.conf`.
- need `/nix/var/nix/profiles/default/bin` in the PATH so that they can run `nix develop`
- in runtime mount `ocx-nix` named volume in a read-only mode

## Scope

We need to allow the user to specify whether they want to use the "nix workflow" in the config.
It should be possible to enable this workflow with a single parameter in the config.

We need to expose an `ocx` command that will manage the master nix container with the nix-daemon running.
If a project has "nix workflow" enabled, we need to make sure that the nix master container is running before starting `ocx` dev containers.
Othewise the dev container will try to run `nix` and it will fail to communicate with the daemon.

We also need to plan for the initial run where docker will need to copy the original contents of `/nix` directory in the master container
to the originally empty `ocx-nix` volume.
