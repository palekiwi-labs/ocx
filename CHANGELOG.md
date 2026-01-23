# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
