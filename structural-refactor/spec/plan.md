# OCX Repository Refactoring Plan

## Executive Summary

This document outlines a comprehensive plan to refactor the OCX repository structure to improve discoverability for contributors and establish clear organizational patterns for future growth.

**Goal**: Reorganize the repository from a flat structure into a clear `commands/` and `lib/` separation pattern.

**Timeline**: 2-4 hours of careful execution
**Risk Level**: Low (mechanical refactoring)
**Files Affected**: ~35 files

---

## Current vs. Proposed Structure

### Current Structure (2639 lines total)
```
src/
├── main.nu                    # 325 lines - Entrypoint with all subcommand definitions
├── docker_tools/              # Already modularized
│   ├── mod.nu
│   ├── build.nu, run.nu, shell.nu, exec.nu, stop.nu, etc.
├── config/                    # Already modularized
│   ├── mod.nu
│   ├── loader.nu, display.nu, defaults.nu, validation.nu, etc.
├── version/                   # Already modularized
│   ├── mod.nu
│   ├── resolver.nu, github.nu, cache.nu, local.nu
├── docs.nu                    # Standalone command (204 lines)
├── upgrade.nu                 # Standalone command (132 lines)
├── errors.nu                  # Library module
├── git_utils.nu              # Library module
├── ports.nu                  # Library module
├── volume_name.nu            # Library module
├── workspace.nu              # Library module
└── shadow_mounts.nu          # Library module
```

### Proposed Structure
```
src/
├── main.nu                    # 50-80 lines - Minimal routing logic
├── commands/                  # User-facing CLI commands
│   ├── mod.nu                # Export all commands
│   ├── opencode.nu           # Run OpenCode (handles both 'opencode' and 'o' alias)
│   ├── build.nu              # Build Docker images
│   ├── config.nu             # Show configuration
│   ├── docs.nu               # Fetch documentation
│   ├── port.nu               # Show port number
│   ├── shell.nu              # Open shell in container
│   ├── stats.nu              # Show container stats
│   ├── ps.nu                 # List containers
│   ├── volume.nu             # List volumes
│   ├── exec.nu               # Execute command in container
│   ├── stop.nu               # Stop container
│   ├── upgrade.nu            # Upgrade OpenCode
│   ├── version.nu            # Show version
│   ├── help.nu               # Show help
│   └── image.nu              # Manage images (with subcommands: list, prune, remove-all)
├── lib/                       # Internal/reusable modules
│   ├── docker_tools/         # Docker operations
│   │   ├── mod.nu
│   │   ├── build.nu
│   │   ├── run.nu
│   │   ├── shell.nu
│   │   ├── exec.nu
│   │   ├── stop.nu
│   │   ├── stats.nu
│   │   ├── ps.nu
│   │   ├── volume.nu
│   │   ├── image.nu
│   │   └── utils.nu
│   ├── config/               # Configuration management
│   │   ├── mod.nu
│   │   ├── loader.nu
│   │   ├── display.nu
│   │   ├── defaults.nu
│   │   ├── validation.nu
│   │   ├── user.nu
│   │   └── env.nu
│   ├── version/              # Version resolution
│   │   ├── mod.nu
│   │   ├── resolver.nu
│   │   ├── github.nu
│   │   ├── cache.nu
│   │   └── local.nu
│   ├── errors.nu             # Error handling utilities
│   ├── git_utils.nu          # Git operations
│   ├── ports.nu              # Port generation
│   ├── volume_name.nu        # Volume naming
│   ├── workspace.nu          # Workspace resolution
│   └── shadow_mounts.nu      # Security shadow mounts
```

---

## Benefits

### 1. Clearer Separation of Concerns
- `commands/` → User-facing CLI commands
- `lib/` → Internal/reusable modules
- Immediately obvious what users can invoke vs. internal utilities

### 2. Simplified main.nu
- Reduce from 325 lines to ~50-80 lines
- Main file becomes pure routing logic
- Better readability and maintainability

### 3. Better Discoverability for Contributors
- New commands immediately visible in `commands/` directory
- Clear pattern for where to add new features
- "Want to add a command? → Look in `commands/`"
- "Need utility functions? → Look in `lib/`"

### 4. Consistent with Industry Standards
- Similar to popular CLI tools (git, cargo, npm)
- Follows the "command pattern" design principle
- Professional structure that scales well

### 5. Improved Testing Structure
- Each command module can be tested independently
- Easier to mock dependencies in `lib/`
- Clear boundaries between command logic and utilities

---

## Implementation Plan

### Phase 1: Create New Directory Structure

**Actions:**
1. Create `src/commands/` directory
2. Create `src/lib/` directory

**Commands:**
```bash
mkdir -p src/commands
mkdir -p src/lib
```

---

### Phase 2: Move Existing Modules to lib/

**Actions:**
Move existing well-organized modules into `lib/`:

1. `src/docker_tools/` → `src/lib/docker_tools/`
2. `src/config/` → `src/lib/config/`
3. `src/version/` → `src/lib/version/`
4. `src/errors.nu` → `src/lib/errors.nu`
5. `src/git_utils.nu` → `src/lib/git_utils.nu`
6. `src/ports.nu` → `src/lib/ports.nu`
7. `src/volume_name.nu` → `src/lib/volume_name.nu`
8. `src/workspace.nu` → `src/lib/workspace.nu`
9. `src/shadow_mounts.nu` → `src/lib/shadow_mounts.nu`

**Commands:**
```bash
mv src/docker_tools src/lib/
mv src/config src/lib/
mv src/version src/lib/
mv src/errors.nu src/lib/
mv src/git_utils.nu src/lib/
mv src/ports.nu src/lib/
mv src/volume_name.nu src/lib/
mv src/workspace.nu src/lib/
mv src/shadow_mounts.nu src/lib/
```

---

### Phase 3: Extract Commands from main.nu

Create individual command files in `commands/`. Each command should follow this pattern:

#### Pattern: Simple Command
```nu
# commands/shell.nu
use ../lib/docker_tools
use ../lib/errors

export def main [] {
    try {
        docker_tools shell
    } catch { |err|
        errors pretty-print $err
    }
}
```

#### Pattern: Command with Parameters
```nu
# commands/build.nu
use ../lib/docker_tools
use ../lib/errors

export def main [
    --base,
    --force(-f),
    --no-cache
] {
    try {
        docker_tools build --base=$base --force=$force --no-cache=$no_cache
    } catch { |err|
        errors pretty-print $err
    }
}
```

#### Pattern: Wrapped Command (variadic args)
```nu
# commands/opencode.nu
use ../lib/docker_tools
use ../lib/errors

export def main [...args] {
    try {
        docker_tools run ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

# Also support 'o' alias in main.nu routing
```

#### Pattern: Command with Subcommands
```nu
# commands/image.nu
use ../lib/docker_tools
use ../lib/errors

export def main [] {
    try {
        docker_tools image
    } catch { |err|
        errors pretty-print $err
    }
}

export def list [
    --base     # Show only base images
    --final    # Show only final OCX images
    --json     # Output as JSON
] {
    try {
        docker_tools image list --base=$base --final=$final --json=$json
    } catch { |err|
        errors pretty-print $err
    }
}

export def prune [
    --base     # Prune only base images
    --final    # Prune only final OCX images
] {
    try {
        docker_tools image prune --base=$base --final=$final
    } catch { |err|
        errors pretty-print $err
    }
}

export def "remove-all" [
    --base     # Remove only base images
    --final    # Remove only final OCX images
] {
    try {
        docker_tools image remove-all --base=$base --final=$final
    } catch { |err|
        errors pretty-print $err
    }
}
```

#### Commands to Create:

1. **commands/opencode.nu** - Main command to run OpenCode
2. **commands/build.nu** - Build Docker images
3. **commands/config.nu** - Show configuration
4. **commands/docs.nu** - Move from `src/docs.nu`
5. **commands/port.nu** - Show port number
6. **commands/shell.nu** - Open shell
7. **commands/stats.nu** - Container stats
8. **commands/ps.nu** - List containers
9. **commands/volume.nu** - List volumes
10. **commands/exec.nu** - Execute command
11. **commands/stop.nu** - Stop container
12. **commands/upgrade.nu** - Move from `src/upgrade.nu`
13. **commands/version.nu** - Show version
14. **commands/help.nu** - Show help
15. **commands/image.nu** - Image management with subcommands

---

### Phase 4: Create commands/mod.nu

Export all command modules:

```nu
# commands/mod.nu
export use opencode.nu
export use build.nu
export use config.nu
export use docs.nu
export use port.nu
export use shell.nu
export use stats.nu
export use ps.nu
export use volume.nu
export use exec.nu
export use stop.nu
export use upgrade.nu
export use version.nu
export use help.nu
export use image.nu
```

---

### Phase 5: Refactor main.nu

Slim down `main.nu` to pure routing logic:

```nu
#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

# OCX - Secure Docker wrapper for OpenCode

use commands

# Main entry point
def main [--version(-v)] {
    if $version {
        commands version
    } else {
        commands help
    }
}

# Primary command: run OpenCode
def --wrapped "main opencode" [...args] {
    commands opencode ...$args
}

# Alias for opencode
def --wrapped "main o" [...args] {
    commands opencode ...$args
}

# Build Docker images
def "main build" [--base, --force(-f), --no-cache] {
    commands build --base=$base --force=$force --no-cache=$no_cache
}

# Show configuration
def "main config" [--sources, --json] {
    commands config --sources=$sources --json=$json
}

# Fetch documentation
def "main docs" [
    --dir: string,
    --version: string,
    --force,
    --skill,
    --global,
    --project,
    --ocx,
] {
    commands docs --dir=$dir --version=$version --force=$force --skill=$skill --global=$global --project=$project --ocx=$ocx
}

# Show port number
def "main port" [] {
    commands port
}

# Open shell in container
def "main shell" [] {
    commands shell
}

# Show container stats
def "main stats" [--all] {
    commands stats --all=$all
}

# List containers
def "main ps" [--all(-a)] {
    commands ps --all=$all
}

# List volumes
def "main volume" [] {
    commands volume
}

# Execute command in container
def --wrapped "main exec" [...args] {
    commands exec ...$args
}

# Stop container
def "main stop" [] {
    commands stop
}

# Upgrade OpenCode
def "main upgrade" [--check] {
    commands upgrade --check=$check
}

# Show version
def "main version" [] {
    commands version
}

# Show help
def "main help" [] {
    commands help
}

# Manage images
def "main image" [] {
    commands image
}

def "main image list" [--base, --final, --json] {
    commands image list --base=$base --final=$final --json=$json
}

def "main image prune" [--base, --final] {
    commands image prune --base=$base --final=$final
}

def "main image remove-all" [--base, --final] {
    commands image "remove-all" --base=$base --final=$final
}

# Override built-in help
def help [...rest] {
    commands help
}
```

**Note**: This keeps the routing in main.nu but delegates all logic to command modules. Main.nu remains the CLI interface definition.

---

### Phase 6: Update Import Statements

Update all import statements throughout the codebase to use new paths.

#### Files Requiring Import Updates:

**In lib/ subdirectories:**
1. `lib/docker_tools/build.nu` - imports from config, version, workspace, etc.
2. `lib/docker_tools/run.nu` - imports from config, workspace, volume_name, etc.
3. Other docker_tools files
4. `lib/config/loader.nu` - imports from defaults, validation, etc.
5. Other config files
6. Version files
7. `lib/workspace.nu` - imports from config
8. `lib/volume_name.nu` - imports from git_utils

**Import Pattern Changes:**
- Old: `use config`
- New: `use ../config` (from lib subdirs) or `use lib/config` (from commands)

- Old: `use errors.nu`
- New: `use ../errors` (from lib subdirs) or `use lib/errors` (from commands)

#### Specific Files to Update:

**Commands (new files will use correct imports from start):**
- All new command files: use `../lib/` prefix

**lib/docker_tools/ files:**
- `lib/docker_tools/build.nu`: Update imports
- `lib/docker_tools/run.nu`: Update imports
- `lib/docker_tools/shell.nu`: Update imports
- `lib/docker_tools/exec.nu`: Update imports
- `lib/docker_tools/stop.nu`: Update imports
- `lib/docker_tools/stats.nu`: Update imports
- `lib/docker_tools/ps.nu`: Update imports
- `lib/docker_tools/volume.nu`: Update imports
- `lib/docker_tools/image.nu`: Update imports
- `lib/docker_tools/utils.nu`: Update imports

**lib/config/ files:**
- `lib/config/loader.nu`: Update imports
- `lib/config/display.nu`: Update imports
- `lib/config/user.nu`: Update imports
- `lib/config/validation.nu`: Update imports
- `lib/config/env.nu`: Update imports (if any)

**lib/version/ files:**
- `lib/version/resolver.nu`: Update imports
- `lib/version/github.nu`: Update imports
- `lib/version/cache.nu`: Update imports
- `lib/version/local.nu`: Update imports

**lib/ utility files:**
- `lib/workspace.nu`: Update `use ./config` → `use config`
- `lib/volume_name.nu`: Update `use ./git_utils.nu` → `use git_utils`

**Standalone files to move:**
- Move `src/docs.nu` → `commands/docs.nu` (update imports)
- Move `src/upgrade.nu` → `commands/upgrade.nu` (update imports)

---

### Phase 7: Testing & Verification

After refactoring, test each command to ensure functionality is intact:

```bash
# Basic commands
ocx --version
ocx --help
ocx help

# Configuration
ocx config
ocx config --sources
ocx config --json

# Build & run
ocx build
ocx opencode
ocx o

# Container management
ocx shell
ocx ps
ocx stats
ocx stop
ocx exec ls -la
ocx volume

# Port management
ocx port

# Image management
ocx image
ocx image list
ocx image list --base
ocx image list --final
ocx image list --json
ocx image prune
ocx image prune --base
ocx image remove-all

# Documentation & upgrade
ocx docs --dir ./test-docs
ocx docs --skill
ocx docs --ocx --dir ./test-docs
ocx upgrade --check

# Version
ocx version
```

---

## File Movement Summary

### Files to Create (15 new command files)
- `src/commands/mod.nu`
- `src/commands/opencode.nu`
- `src/commands/build.nu`
- `src/commands/config.nu`
- `src/commands/docs.nu`
- `src/commands/port.nu`
- `src/commands/shell.nu`
- `src/commands/stats.nu`
- `src/commands/ps.nu`
- `src/commands/volume.nu`
- `src/commands/exec.nu`
- `src/commands/stop.nu`
- `src/commands/upgrade.nu`
- `src/commands/version.nu`
- `src/commands/help.nu`
- `src/commands/image.nu`

### Files to Move (3 directories + 6 utility files)
- `src/docker_tools/` → `src/lib/docker_tools/`
- `src/config/` → `src/lib/config/`
- `src/version/` → `src/lib/version/`
- `src/errors.nu` → `src/lib/errors.nu`
- `src/git_utils.nu` → `src/lib/git_utils.nu`
- `src/ports.nu` → `src/lib/ports.nu`
- `src/volume_name.nu` → `src/lib/volume_name.nu`
- `src/workspace.nu` → `src/lib/workspace.nu`
- `src/shadow_mounts.nu` → `src/lib/shadow_mounts.nu`

### Files to Delete (2 - content moved to commands/)
- `src/docs.nu` (→ `commands/docs.nu`)
- `src/upgrade.nu` (→ `commands/upgrade.nu`)

### Files to Update (1 major refactor)
- `src/main.nu` (325 lines → ~100 lines)

### Files Requiring Import Updates (~25-30 files)
- All files in `lib/docker_tools/` (10 files)
- All files in `lib/config/` (7 files)
- All files in `lib/version/` (5 files)
- `lib/workspace.nu`
- `lib/volume_name.nu`
- Various command files (as needed)

---

## Potential Gotchas & Mitigation

### 1. Nushell Module Resolution
**Issue**: Nushell's module system behavior with nested paths
**Mitigation**:
- Test imports carefully after each move
- Use relative imports (`../lib/module`) for predictable behavior
- Verify `mod.nu` exports work correctly

### 2. Relative Path Imports
**Issue**: Different relative paths from `commands/` vs `lib/` subdirectories
**Mitigation**:
- From `commands/`: use `../lib/module`
- From `lib/subdir/`: use `../other_subdir` or `../module`
- Be consistent with import patterns

### 3. Error Handling Consistency
**Issue**: Ensure all commands maintain the try/catch pattern
**Mitigation**: Use templates for each command type (shown in Phase 3)

### 4. Subcommand Routing
**Issue**: Image subcommands need special handling
**Mitigation**: Keep both routing in main.nu AND subcommand exports in image.nu

### 5. File Permissions
**Issue**: Shebang line and executable permissions
**Mitigation**: Maintain shebang only in main.nu (entry point)

---

## Rollback Plan

If issues arise during refactoring:

### Quick Rollback
```bash
# If using git
git checkout src/

# Or restore from backup
cp -r src.backup/ src/
```

### Incremental Rollback
1. Revert main.nu changes
2. Move files back from lib/ to src/
3. Delete commands/ directory
4. Restore original import statements

---

## Success Criteria

Refactoring is complete when:

1. ✅ All commands execute successfully (see Testing section)
2. ✅ No Nushell import errors
3. ✅ `commands/` directory contains all user-facing commands
4. ✅ `lib/` directory contains all internal modules
5. ✅ `main.nu` is under 100 lines
6. ✅ All tests pass (if tests exist)
7. ✅ Documentation updated (README, if needed)
8. ✅ Git commit created with clear message

---

## Post-Refactoring

### Documentation Updates
Consider updating:
- `CONTRIBUTING.md` - Add section on where to add new commands
- `README.md` - If it references file structure
- Developer docs - Add architectural overview

### Future Benefits
With this structure in place:
1. Adding new commands is trivial (create file in `commands/`, add to `mod.nu`, add routing in `main.nu`)
2. Contributors can easily find command implementations
3. Testing strategy becomes clearer (unit test lib/, integration test commands/)
4. Can add command-specific documentation alongside code

---

## Estimated Timeline

| Phase | Task | Time |
|-------|------|------|
| 1 | Create directory structure | 5 min |
| 2 | Move existing modules to lib/ | 10 min |
| 3 | Extract commands from main.nu | 60-90 min |
| 4 | Create commands/mod.nu | 5 min |
| 5 | Refactor main.nu | 20 min |
| 6 | Update import statements | 30-45 min |
| 7 | Testing & verification | 30-45 min |
| **Total** | | **2-4 hours** |

---

## Questions for Review

Before proceeding with implementation:

1. ✅ Confirmed: Full refactor approach
2. ✅ Confirmed: Goal is better contributor discoverability
3. ✅ Confirmed: Expecting 3-5 new commands in next 6 months

**Ready for implementation?** Review this plan and provide any feedback or concerns before proceeding.

---

## Implementation Checklist

- [ ] Phase 1: Create `commands/` and `lib/` directories
- [ ] Phase 2: Move modules to `lib/`
- [ ] Phase 3: Extract all 15 commands
- [ ] Phase 4: Create `commands/mod.nu`
- [ ] Phase 5: Refactor `main.nu`
- [ ] Phase 6: Update ~30 import statements
- [ ] Phase 7: Test all commands
- [ ] Create git commit
- [ ] Update documentation (if needed)

---

**Document Version**: 1.0
**Date**: 2026-01-31
**Author**: AI Assistant
**Status**: Ready for Review
