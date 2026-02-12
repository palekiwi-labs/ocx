# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### BREAKING CHANGES

#### Extra Data Volumes Configuration Format

The `extra_data_volumes` configuration has been redesigned to support both Docker volumes and host bind mounts with read-only/read-write modes.

**Old Format (No Longer Supported):**
```json
{
  "extra_data_volumes": {
    "cargo": "~/.cargo",
    "npm": "~/.npm"
  }
}
```

**New Format:**
```json
{
  "extra_data_volumes": {
    "cargo": {
      "target": "~/.cargo",
      "type": "volume"
    },
    "npm": {
      "target": "~/.npm",
      "type": "volume"
    }
  }
}
```

**Migration:**
Replace each string value with a record containing at minimum the `target` field:

```bash
# Before
"key": "path"

# After
"key": {"target": "path"}
```

**New Capabilities:**
- Host bind mounts: `{"source": "/host/path", "target": "/container/path", "type": "bind"}`
- Read-only mounts: `{"mode": "ro"}`
- Custom volume names: `{"source": "my-volume", "target": "/path", "type": "volume"}`

**Rationale:**
Enables sharing host directories (like Nix store) with containers while maintaining security through read-only mounts.

### Added

- Support for host bind mounts in `extra_data_volumes`
- Support for read-only mode in `extra_data_volumes`
- Support for custom volume names in `extra_data_volumes`
- Examples for sharing Nix store with containers

## [0.1.0-alpha.1] - 2026-01-23

### Added
- Initial alpha release of OCX (OpenCode Docker Wrapper).
- Core functionality:
  - Secure workspace mounting with automatic UID/GID mapping.
  - Custom base image support (Debian/Ubuntu/Alpine compatibility).
  - Built-in commands: `shell`, `exec`, `logs`, `stats`, `ps`, `stop`.
- Configuration system:
  - Support for `ocx.json` (project and global).
  - Environment variable overrides.
- Volume management:
  - Persistent volumes for `/home/opencode`.
  - Volume inspection and management commands.
- Network configuration:
  - Configurable port mapping.
  - `host.docker.internal` support.
- Security features:
  - Read-only mounts for config.
  - Non-root container execution.
- Documentation:
  - Comprehensive README.
  - Technical specs and architecture docs.
  - Usage guides for images, volumes, and upgrades.

[Unreleased]: https://github.com/palekiwi-labs/ocx/compare/v0.1.0-alpha.1...HEAD
[0.1.0-alpha.1]: https://github.com/palekiwi-labs/ocx/releases/tag/v0.1.0-alpha.1
