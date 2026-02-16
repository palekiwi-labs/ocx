# Improved nix image management

---

## Context

In `27a59b8` we introduced support for a nix workflow, see the docs: `docs/nix-workflow.md`

I would like to take this approach further and implement a single image mod for the nix workflow.

Up till now, we have allowed user customization by means of splitting the images into: base and final,
with their own dockerfiles: `src/Dockerfile.base` and `src/Dockerfile.opencode`.

### Single universal nix workflow ocx image

With nix, we give users absolute freedom to define their own environments, they should be able to set up
`opencode` as a dependency in their flakes too. `opencode` can be installed from the official github flake:
`https://github.com/anomalyco/opencode/blob/dev/flake.nix`. Users can define it as an input in their flake,
include it in their devshell and let nix build it. Letting `nix` manage `opencode` means that users
on the "nix workflow" will not need to fetch the `opencode` binary from github every time on update
and that the derivation will be available in the store for any dev container to use.

This means that with nix workflow enabled, we do not need base and final images. We use only one
combined Dockerfile named `Dockerfile.nix-dev` for a single universal "nix workflow" image that:
- enables flakes in nix.conf
- ensures the PATH is configured for nix use
- mounts the `ocx-nix` volume
- sets up the user and other general configs (as in the current `Dockerfile.base`)

### Support for default ocx dev shell

However, we should also support a use case where users do not define their own `flake.nix`, maybe
exploring a clone opensource repository or just  non-nix project. In that case, we should provide
support for a default nix flake with a default dev shell that will have `opencode` included.

This flake.nix should be present in a location that can be access by both the daemon and the dev
containers. Example of usage:
user enables "nix workflow" and runs `ocx opencode`. `ocx` should start the dev container
with `nix develop <path to our built-in flake> -c opencode`


## Important considerations

The workflow with a single "univeral" image differs in some ways from our current setup:
- there is no base, just a single final image
- updates/upgrades of opencode do not apply the same way because we do not download the binary of `opencode`
- everything is managed by the flake that we ship in, which means we need to generate a flake.lock and expose some command that allows user to run updates
