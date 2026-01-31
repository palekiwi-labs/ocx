# Host-Exec Feature Implementation Analysis

**Status:** Planning Phase  
**Branch:** host-exec  
**Date:** 2026-01-31

---

## Executive Summary

The `host-exec` feature enables AI agents running inside the ocx container to execute whitelisted commands on the host machine via a Unix socket-based client-server architecture. This allows containerized agents to use tools like `docker`, `terraform`, or other commands that require host access, authentication, or resources not available in the container.

---

## Current State Analysis

### OCX Architecture Overview

**Technology Stack:**
- Written entirely in **Nushell** (`.nu` files)
- Distributed as a **Nix flake** package
- Uses **Docker** to run OpenCode in an isolated container
- Base image: `debian:bookworm-slim` with essential tools (curl, git, jq, fd-find, ripgrep)

**Security Posture:**
- Container runs with strict security: `--read-only`, `--security-opt no-new-privileges`, `--cap-drop ALL`
- UID/GID mapping for seamless host-container file permissions
- Tmpfs mounts for `/tmp` and `/workspace/tmp`
- Network isolation with configurable network mode
- Resource limits: memory, CPU, and PID limits

**Configuration System:**
- Configuration via `ocx.json` files (global: `~/.config/ocx/ocx.json`, project: `./ocx.json`)
- Priority order: Environment Variables > Project Config > Global Config > Defaults
- Array fields (like `forbidden_paths`) are merged across all levels

**Key Files:**
- `src/main.nu` - Entry point
- `src/docker_tools/run.nu` - Container runtime configuration (line 10-151)
- `src/config/loader.nu` - Configuration loading with merge logic (line 49-120)
- `src/Dockerfile.opencode` - Container build definition (55 lines)

**Current Limitations:**
- No Rust code exists in the current codebase
- No Unix socket communication infrastructure
- No mechanism for container-to-host command delegation

---

## Specification Analysis

### Source Document
`.agents/host-exec/spec/index.md` (84 lines, status: todo)

### Key Requirements

1. **Bidirectional Communication**
   - Container sends command requests to host via Unix socket
   - Host validates against whitelist and executes commands
   - Results (stdout/stderr/exit code) returned to container

2. **Security Model**
   - Whitelist-based command validation
   - Granular control per command and arguments
   - Example configuration pattern:
     ```json
     {
       "host_exec": {
         "terraform": {
           "*": false,
           "plan": true
         }
       }
     }
     ```

3. **Implementation Technology**
   - Both client and server components must be written in **Rust**
   - Rationale: Nushell and Bash are inadequate for sensitive socket communication

4. **Transparency Refinement (Optional but Recommended)**
   - Wrap whitelisted commands in scripts that impersonate real commands
   - Install in `/usr/local/bin/` (e.g., `/usr/local/bin/docker`)
   - AI agents can use familiar command syntax
   - Commands should be functionally indistinguishable from real commands

---

## Architecture Design

### Design Decisions (Confirmed with User)

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Socket Lifecycle** | OCX manages server | Automatic lifecycle, no manual daemon management |
| **Socket Naming** | Per-workspace sockets | Isolation between projects: `/run/user/<uid>/ocx-<hash>.sock` |
| **Default Security** | Deny by default | Most secure, explicit opt-in required |
| **Working Directory** | Host workspace root | Commands execute in the mounted workspace directory |
| **Wrapper Scripts** | Include from start | Better AI agent UX, transparent command delegation |
| **Rust Structure** | Workspace with crates | `shared`, `client`, `server` crates for code reuse |

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Host Machine                                             │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │ ocx (Nushell)                                  │    │
│  │  - Starts host-exec-server before container   │    │
│  │  - Mounts socket into container               │    │
│  │  - Stops server after container exits         │    │
│  └────────────────┬───────────────────────────────┘    │
│                   │                                      │
│  ┌────────────────▼───────────────────────────────┐    │
│  │ host-exec-server (Rust daemon)                 │    │
│  │  - Listens on Unix socket                      │    │
│  │  - Validates against whitelist                 │    │
│  │  - Executes commands in host workspace         │    │
│  └────────────────┬───────────────────────────────┘    │
│                   │                                      │
│      /run/user/<uid>/ocx-<hash>.sock                    │
│                   │                                      │
└───────────────────┼──────────────────────────────────────┘
                    │ (mounted into container)
┌───────────────────▼──────────────────────────────────────┐
│ Container                                                 │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │ /usr/local/bin/docker  (wrapper script)        │    │
│  │ /usr/local/bin/terraform  (wrapper script)     │    │
│  │ /usr/local/bin/kubectl  (wrapper script)       │    │
│  │    ↓ all invoke ↓                               │    │
│  │ /usr/local/bin/host-exec (Rust client)         │    │
│  │  - Sends command via socket                     │    │
│  │  - Returns stdout/stderr/exit code              │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │ AI Agent (OpenCode)                             │    │
│  │  - Runs 'docker ps' naturally                   │    │
│  │  - Transparent to agent, runs on host           │    │
│  └─────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
ocx/
├── rust/
│   ├── Cargo.toml              # Workspace manifest
│   ├── shared/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs          # Protocol types, serialization
│   │       ├── config.rs       # Whitelist parsing/matching
│   │       └── socket.rs       # Socket utilities
│   ├── client/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       └── main.rs         # host-exec binary
│   └── server/
│       ├── Cargo.toml
│       └── src/
│           └── main.rs         # host-exec-server binary
├── src/
│   ├── host_exec/
│   │   ├── mod.nu              # Public interface
│   │   ├── server.nu           # Server lifecycle management
│   │   ├── wrappers.nu         # Generate wrapper scripts
│   │   └── config.nu           # Config validation
│   └── ...
└── templates/
    └── wrapper.sh.template     # Template for command wrappers
```

---

## Implementation Plan

### Phase 1: Rust Foundation (Days 1-3)

**Objective:** Build the core Rust infrastructure for client-server communication.

#### Tasks

**1.1 Initialize Rust Workspace**
- Create `rust/` directory with workspace `Cargo.toml`
- Set up three crates: `shared`, `client`, `server`
- Add dependencies:
  - `tokio` - Async runtime
  - `serde`, `serde_json` - Serialization
  - `anyhow` - Error handling
  - `clap` - CLI argument parsing
  - `nix` - Unix socket utilities
  - `tracing` - Logging infrastructure

**1.2 Define Protocol (`rust/shared/src/lib.rs`)**
```rust
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize)]
pub struct CommandRequest {
    pub command: String,
    pub args: Vec<String>,
    pub env: HashMap<String, String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CommandResponse {
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
    pub exit_code: i32,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum Message {
    Request(CommandRequest),
    Response(CommandResponse),
    Error(String),
}
```

**1.3 Implement Whitelist Logic (`rust/shared/src/config.rs`)**
- Parse `host_exec` config from JSON
- Wildcard pattern matching (`*`, `?` support)
- Rule evaluation algorithm (last matching rule wins)
- Default deny behavior
- Command + args matching logic

```rust
pub struct WhitelistConfig {
    rules: HashMap<String, CommandRules>,
}

pub enum CommandRules {
    Allow(bool),
    Patterns(Vec<(String, bool)>),
}

impl WhitelistConfig {
    pub fn is_allowed(&self, command: &str, args: &[String]) -> bool {
        // Implementation
    }
}
```

**1.4 Build Client (`rust/client/src/main.rs`)**
- CLI argument parsing with `clap`
- Connect to Unix socket at `/run/ocx.sock`
- Send `CommandRequest`, receive `CommandResponse`
- Output handling (stream stdout/stderr, exit with correct code)
- Error handling for connection failures

**1.5 Build Server (`rust/server/src/main.rs`)**
- Unix socket listener (create socket, set permissions)
- Request validation against whitelist config
- Command execution with:
  - Proper working directory (from config)
  - Inherited environment variables (filtered)
  - Stdout/stderr capture
  - Exit code capture
- Response serialization and sending
- Graceful shutdown on SIGTERM/SIGINT
- Cleanup socket file on shutdown

**Deliverables:**
- Working `host-exec` binary (client)
- Working `host-exec-server` binary (server)
- Shared protocol library
- Unit tests for whitelist matching logic
- Integration tests for client-server communication

---

### Phase 2: Nushell Integration (Days 4-5)

**Objective:** Integrate Rust components into the OCX Nushell codebase.

#### Tasks

**2.1 Create `src/host_exec/mod.nu`**
```nushell
# Public API for host_exec feature
export def is-enabled [config: record] -> bool {
    $config.host_exec_enabled? | default false
}

export def generate-socket-path [config: record] -> string {
    let workspace_hash = (workspace get-hash $config)
    let uid = (id -u)
    $"/run/user/($uid)/ocx-($workspace_hash).sock"
}
```

**2.2 Create `src/host_exec/server.nu`**
```nushell
export def start [config: record, socket_path: string] -> record {
    # Resolve server binary path from Nix store
    # Serialize config to temp JSON file
    # Start server process: host-exec-server --socket $socket_path --config $config_file
    # Return server PID and socket path
}

export def stop [socket_path: string, pid: int] {
    # Send SIGTERM to server
    # Wait for graceful shutdown (max 5 seconds)
    # Force kill if necessary
    # Clean up socket file
}

export def is-running [socket_path: string] -> bool {
    # Test if socket exists and is responding
}
```

**2.3 Create `src/host_exec/wrappers.nu`**
```nushell
export def generate [config: record] -> list<record> {
    # Parse host_exec config
    # Extract list of commands that have any allowed rules
    # For each command, generate wrapper script content
    # Return: [{command: "docker", script: "#!/usr/bin/env bash\n..."}]
}

export def write-to-builddir [wrappers: list<record>, builddir: string] {
    # Write each wrapper to builddir/wrappers/<command>
    # Set executable permissions
}
```

**2.4 Update `src/config/defaults.nu`**
```nushell
export const DEFAULTS = {
    # ... existing defaults ...
    
    # Host execution feature (disabled by default for security)
    host_exec_enabled: false,
    host_exec: {},  # Empty object = deny all commands
}
```

**2.5 Update `src/config/validation.nu`**
- Add validation for `host_exec_enabled` (must be boolean)
- Add validation for `host_exec` structure:
  - Must be a record
  - Keys are command names (strings)
  - Values are either:
    - Boolean (simple allow/deny)
    - Record with pattern → boolean mappings
- Validate pattern syntax (no illegal characters)

**Deliverables:**
- Complete `src/host_exec/` module
- Updated configuration defaults and validation
- Integration with existing config loading system

---

### Phase 3: Docker Integration (Days 6-7)

**Objective:** Integrate host-exec into the Docker build and runtime workflow.

#### Tasks

**3.1 Update `src/Dockerfile.opencode`**
```dockerfile
# After OpenCode installation, before USER switch:

# Copy pre-built Rust client binary from Nix build context
ARG HOST_EXEC_CLIENT_PATH
COPY ${HOST_EXEC_CLIENT_PATH} /usr/local/bin/host-exec
RUN chmod +x /usr/local/bin/host-exec

# Copy wrapper scripts (if any) from build context
ARG WRAPPERS_DIR
COPY ${WRAPPERS_DIR}/* /usr/local/bin/ || true
```

**3.2 Update `src/docker_tools/build.nu`**
```nushell
export def main [--force] {
    let cfg = (config load)
    
    # ... existing build logic ...
    
    # Generate wrapper scripts if host_exec enabled
    if (host_exec is-enabled $cfg) {
        let wrappers = (host_exec wrappers generate $cfg)
        let builddir = "/tmp/ocx-build-context"
        host_exec wrappers write-to-builddir $wrappers $builddir
        
        # Pass wrapper dir to Docker build
        $build_args = ($build_args | append [
            "--build-arg" $"WRAPPERS_DIR=($builddir)/wrappers"
        ])
    }
    
    # ... continue with docker build ...
}
```

**3.3 Update `src/docker_tools/run.nu`**
```nushell
export def main [...args] {
    let cfg = (config load)
    
    # ... existing setup logic ...
    
    # Start host-exec server if enabled
    mut server_info = null
    if (host_exec is-enabled $cfg) {
        let socket_path = (host_exec generate-socket-path $cfg)
        $server_info = (host_exec server start $cfg $socket_path)
        
        # Mount socket into container
        $cmd = ($cmd | append [
            "-v" $"($socket_path):/run/ocx.sock:rw"
        ])
    }
    
    # ... build docker run command ...
    
    # Execute container
    try {
        run-external ...$cmd
    } catch { |err|
        # Ensure server cleanup on error
        if $server_info != null {
            host_exec server stop $server_info.socket_path $server_info.pid
        }
        error make $err
    }
    
    # Clean up server after container exits
    if $server_info != null {
        host_exec server stop $server_info.socket_path $server_info.pid
    }
}
```

**Deliverables:**
- Updated Dockerfile with host-exec client installation
- Wrapper script generation and installation
- Server lifecycle management in `run.nu`
- Proper cleanup on container exit or error

---

### Phase 4: Nix Build System (Day 8)

**Objective:** Integrate Rust builds into the Nix flake for distribution.

#### Tasks

**4.1 Update `flake.nix`**
```nix
{
  description = "ocx - a secure Docker wrapper for OpenCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
        
        # Rust toolchain
        rustToolchain = pkgs.rust-bin.stable.latest.default;
        
        # Build Rust workspace
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };
        
        # Shared Rust dependencies
        rustPackageArgs = {
          src = ./rust;
          cargoLock.lockFile = ./rust/Cargo.lock;
        };
        
      in {
        packages = {
          # Client binary (for container)
          host-exec-client = rustPlatform.buildRustPackage (rustPackageArgs // {
            pname = "host-exec";
            version = "0.1.0";
            cargoBuildFlags = [ "-p" "host-exec-client" ];
            cargoTestFlags = [ "-p" "host-exec-client" ];
          });
          
          # Server binary (for host)
          host-exec-server = rustPlatform.buildRustPackage (rustPackageArgs // {
            pname = "host-exec-server";
            version = "0.1.0";
            cargoBuildFlags = [ "-p" "host-exec-server" ];
            cargoTestFlags = [ "-p" "host-exec-server" ];
          });
          
          # Main ocx package (updated)
          default = pkgs.stdenv.mkDerivation {
            pname = "ocx";
            version = builtins.readFile ./src/VERSION.txt;
            
            src = ./.;
            
            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [ 
              pkgs.nushell 
              pkgs.docker
            ];
            
            installPhase = ''
              mkdir -p $out/bin $out/share/ocx $out/libexec
              
              # Bundle source files
              cp -r src $out/share/ocx/
              
              # Install Rust binaries
              cp ${host-exec-server}/bin/host-exec-server $out/libexec/
              
              # Make client binary available for Docker builds
              mkdir -p $out/share/ocx/binaries
              cp ${host-exec-client}/bin/host-exec $out/share/ocx/binaries/
              
              # Create wrapper with access to server binary
              makeWrapper ${pkgs.nushell}/bin/nu $out/bin/ocx \
                --add-flags "$out/share/ocx/src/main.nu" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.docker ]} \
                --set OCX_SERVER_BIN "$out/libexec/host-exec-server" \
                --set OCX_CLIENT_BIN "$out/share/ocx/binaries/host-exec"
            '';
            
            meta = with pkgs.lib; {
              description = "Secure Docker wrapper for OpenCode with host-exec";
              homepage = "https://github.com/palekiwi-labs/ocx";
              license = licenses.mit;
              platforms = platforms.unix;
              mainProgram = "ocx";
            };
          };
        };
      }
    );
}
```

**4.2 Update Nushell Scripts to Use Environment Variables**
```nushell
# In src/host_exec/server.nu
export def get-server-binary-path [] -> string {
    # Check environment variable set by Nix wrapper
    let from_env = $env.OCX_SERVER_BIN? | default null
    if $from_env != null {
        return $from_env
    }
    
    # Fallback for development
    "./rust/target/release/host-exec-server"
}
```

**Deliverables:**
- Complete Nix build integration
- Rust binaries bundled with ocx distribution
- Environment variables for binary paths
- Working `nix build` and `nix run` commands

---

### Phase 5: Testing & Documentation (Days 9-10)

**Objective:** Comprehensive testing and documentation.

#### Tasks

**5.1 Create Test Suite**

**Unit Tests (Rust):**
```rust
// rust/shared/src/config.rs
#[cfg(test)]
mod tests {
    #[test]
    fn test_wildcard_matching() {
        // Test "*" matches everything
        // Test "plan" matches exactly "plan"
        // Test "exec -it *" matches "exec -it container-name"
    }
    
    #[test]
    fn test_last_match_wins() {
        // Test rule precedence
    }
    
    #[test]
    fn test_default_deny() {
        // Empty config should deny all
    }
}
```

**Integration Tests (Rust):**
```rust
// rust/tests/integration_test.rs
#[tokio::test]
async fn test_client_server_communication() {
    // Start server
    // Send request
    // Verify response
    // Cleanup
}
```

**End-to-End Tests (Bash):**
```bash
#!/usr/bin/env bash
# tests/e2e/host-exec.sh

# Test 1: Allowed command succeeds
echo '{"host_exec_enabled": true, "host_exec": {"echo": true}}' > ocx.json
ocx opencode <<EOF
host-exec echo "test"
EOF
# Verify output

# Test 2: Denied command fails
echo '{"host_exec_enabled": true, "host_exec": {"rm": false}}' > ocx.json
ocx opencode <<EOF
host-exec rm -rf /
EOF
# Verify error message
```

**5.2 Create Example Configurations**

**Example 1: Docker access** (`examples/host-exec-docker.json`)
```json
{
  "host_exec_enabled": true,
  "host_exec": {
    "docker": {
      "*": false,
      "ps": true,
      "ps -a": true,
      "images": true,
      "exec -it * *": true,
      "logs *": true
    }
  }
}
```

**Example 2: Terraform workflow** (`examples/host-exec-terraform.json`)
```json
{
  "host_exec_enabled": true,
  "host_exec": {
    "terraform": {
      "*": false,
      "init": true,
      "plan": true,
      "plan -out=*": true,
      "show": true,
      "validate": true
    }
  }
}
```

**Example 3: Multi-tool development** (`examples/host-exec-full.json`)
```json
{
  "host_exec_enabled": true,
  "host_exec": {
    "docker": {
      "*": false,
      "ps *": true,
      "images": true,
      "exec -it test-* *": true
    },
    "kubectl": {
      "*": false,
      "get *": true,
      "describe *": true,
      "logs *": true
    },
    "git": {
      "*": false,
      "status": true,
      "diff": true,
      "log": true
    }
  }
}
```

**5.3 Documentation**

**`docs/host-exec.md`** - Feature overview
- What is host-exec?
- Use cases (Docker, Terraform, kubectl)
- Security model
- Quick start guide
- Architecture diagram

**`docs/host-exec-configuration.md`** - Configuration reference
- Enabling the feature
- Whitelist syntax
- Pattern matching rules
- Examples for common scenarios
- Troubleshooting

**`docs/host-exec-security.md`** - Security considerations
- Threat model
- Default deny rationale
- Workspace isolation
- Command injection prevention
- Audit logging (future feature)
- Best practices

**Update `README.md`:**
- Add host-exec to feature list
- Link to documentation
- Add configuration example

**Update `docs/security-model.md`:**
- Document host-exec security architecture
- Explain socket permissions
- Command validation process

**Deliverables:**
- Complete test suite (unit, integration, e2e)
- Example configurations for common use cases
- Comprehensive documentation
- Updated README

---

## Security Analysis

### Threat Model

**Threats Mitigated:**
1. **Unauthorized Command Execution**: Whitelist prevents arbitrary host access
2. **Command Injection**: Arguments passed directly, no shell expansion
3. **Directory Traversal**: Commands locked to workspace directory
4. **Resource Exhaustion**: Inherits ocx resource limits (memory, CPU, PIDs)

**Attack Vectors:**
1. **Whitelist Bypass**: Carefully crafted args might match overly broad patterns
   - *Mitigation*: Documentation emphasizes specific patterns over wildcards
2. **Socket Hijacking**: Another process could connect to socket
   - *Mitigation*: Socket permissions (0600), UID-namespaced path
3. **Server Compromise**: Bug in server could allow arbitrary execution
   - *Mitigation*: Rust memory safety, minimal dependencies, audit logging

**Trust Boundaries:**
```
┌─────────────────────────────────────────┐
│ Untrusted: Container + AI Agent        │
│  - Can attempt any command             │
│  - Limited by whitelist                │
└──────────────┬──────────────────────────┘
               │ Unix Socket (validated)
┌──────────────▼──────────────────────────┐
│ Trusted: Host + Server Process          │
│  - Enforces whitelist                   │
│  - Executes in workspace only           │
└─────────────────────────────────────────┘
```

### Security Features

1. **Default Deny**: All commands blocked unless explicitly whitelisted
2. **Workspace Isolation**: Commands only run in the workspace directory (no `cd` allowed)
3. **No Shell Expansion**: Args passed directly to prevent injection
4. **Socket Permissions**: Socket owned by user with 0600 permissions, not world-readable
5. **Per-Workspace Isolation**: Each workspace gets its own socket, preventing cross-contamination
6. **Resource Limits**: Spawned processes inherit ocx memory/CPU limits
7. **Audit Capability**: Server can log all commands (optional configuration)

### Configuration Best Practices

**DO:**
- ✅ Use specific patterns: `"terraform plan"` not `"terraform *"`
- ✅ Deny by default: `"*": false` first, then allow specific commands
- ✅ Test configurations with least privilege principle
- ✅ Review whitelist regularly as project needs change

**DON'T:**
- ❌ Use overly broad wildcards: `"*": true` 
- ❌ Allow shell commands: `"bash *": true`
- ❌ Allow destructive commands: `"rm *": true`
- ❌ Enable host-exec without explicit need

---

## Example Usage

### Configuration

**Project `ocx.json`:**
```json
{
  "host_exec_enabled": true,
  "host_exec": {
    "terraform": {
      "*": false,
      "init": true,
      "plan": true,
      "plan -out=*": true,
      "show": true,
      "validate": true
    },
    "docker": {
      "*": false,
      "ps": true,
      "ps -a": true,
      "exec -it test-container *": true
    }
  }
}
```

### From Inside Container (Transparent)

AI agent interacts naturally, wrapper scripts handle delegation:

```bash
# Agent runs this naturally:
docker ps

# What happens behind the scenes:
# 1. /usr/local/bin/docker wrapper intercepts
# 2. Wrapper calls: host-exec docker ps
# 3. host-exec sends request via socket
# 4. Server validates: "docker" + ["ps"] matches whitelist "ps": true
# 5. Server executes on host in workspace directory
# 6. Output returned to container, displayed to agent
```

### Direct CLI Usage

Can also use `host-exec` explicitly:

```bash
# Inside container:
host-exec terraform plan
host-exec docker ps
host-exec docker exec -it test-container bin/rspec
```

### Error Cases

**Denied command:**
```bash
$ host-exec terraform apply
Error: Command denied by whitelist: terraform apply
```

**Feature disabled:**
```bash
$ host-exec docker ps
Error: host-exec feature is not enabled in configuration
```

**Server not running:**
```bash
$ host-exec docker ps
Error: Cannot connect to host-exec server at /run/ocx.sock
```

---

## Open Questions & Future Considerations

### Phase 1 Scope Questions

1. **Environment Variables**: Should container env vars be passed to host commands?
   - **Recommendation**: No, for security. Host commands use host environment.
   - **Exception**: May need to pass specific vars like `TERM` for interactive commands.

2. **Interactive Commands**: How to handle commands requiring TTY/stdin?
   - **Recommendation**: Phase 2 feature. Initial version: stdout/stderr only.
   - **Implementation**: Would require TTY forwarding over socket.

3. **Path Translation**: If agent passes container paths, translate to host paths?
   - **Recommendation**: No translation. Commands run in host workspace, same paths apply.
   - **Edge case**: If container mounts workspace at different path, could cause issues.

4. **Server Recovery**: What if server crashes mid-execution?
   - **Recommendation**: Client should timeout after 30s, ocx should detect dead server.
   - **Implementation**: Health check before each container run.

5. **Nix Distribution**: Pre-build binaries or require Rust toolchain?
   - **Recommendation**: Pre-build in flake. Users shouldn't need Rust installed.
   - **Implementation**: Nix builds Rust binaries, bundles with ocx package.

### Future Enhancements

1. **Audit Logging**: Log all host-exec commands to file for security review
2. **Rate Limiting**: Prevent command spam/DoS from container
3. **Command Aliases**: Map container commands to different host commands
4. **Multiple Workspaces**: Support simultaneous containers with same workspace
5. **Interactive TTY Support**: Allow fully interactive commands (e.g., `vim`)
6. **Notification System**: Alert user when AI attempts denied command
7. **Dynamic Whitelist**: Allow temporary permission grants via user approval
8. **Command Output Streaming**: Stream large outputs instead of buffering

---

## Timeline Estimate

| Phase | Tasks | Duration | Dependencies |
|-------|-------|----------|--------------|
| **Phase 1** | Rust Foundation | 3 days | None |
| **Phase 2** | Nushell Integration | 2 days | Phase 1 complete |
| **Phase 3** | Docker Integration | 2 days | Phases 1-2 complete |
| **Phase 4** | Nix Build System | 1 day | Phases 1-3 complete |
| **Phase 5** | Testing & Documentation | 2 days | All phases complete |

**Total Estimated Time: ~10 working days**

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Rust learning curve slows development | Medium | Medium | Start with simple implementation, iterate |
| Nix build integration complexity | Low | High | Test incrementally, use existing patterns |
| Socket permission issues on different Linux distros | Medium | Medium | Test on multiple platforms, document quirks |
| Whitelist bypass via pattern matching bugs | Low | High | Extensive unit tests, security review |
| Performance overhead of socket communication | Low | Low | Benchmark, optimize if needed |
| Breaking changes to existing ocx users | Low | Medium | Feature is opt-in, backward compatible |

---

## Success Criteria

The implementation will be considered successful when:

1. ✅ AI agents can transparently execute whitelisted host commands (e.g., `docker ps`)
2. ✅ Denied commands are blocked with clear error messages
3. ✅ Server automatically starts/stops with container lifecycle
4. ✅ No permission issues with socket access
5. ✅ Configuration is intuitive and well-documented
6. ✅ Security model is robust against common attack vectors
7. ✅ Nix build produces working binaries on Linux x64 and ARM64
8. ✅ Existing ocx functionality remains unchanged (backward compatible)
9. ✅ Test suite covers unit, integration, and e2e scenarios
10. ✅ Documentation enables users to configure for their use cases

---

## Next Steps

**Immediate Actions:**

1. **Get approval on this plan** - Review with stakeholders
2. **Set up development environment** - Ensure Rust toolchain available
3. **Create feature branch** - `git checkout -b host-exec`
4. **Initialize Rust workspace** - Start Phase 1

**Development Workflow:**

1. Implement phases sequentially (1 → 2 → 3 → 4 → 5)
2. Write tests alongside implementation (TDD where appropriate)
3. Commit frequently with clear messages
4. Document as you go (inline comments + docs)
5. Test on both x64 and ARM64 if possible

**Review Points:**

- After Phase 1: Review Rust implementation, protocol design
- After Phase 3: Review full integration, test end-to-end
- Before Phase 5: Security review of whitelist logic
- Final: Complete QA pass, documentation review

---

## Conclusion

The `host-exec` feature is a well-scoped addition that addresses a real limitation of container-based AI agent environments. The proposed Rust-based implementation aligns with security best practices, while the wrapper script refinement ensures a seamless user experience for AI agents.

The architecture is sound, the timeline is realistic, and the security model is robust. With careful implementation following this plan, the feature will significantly expand OCX's capabilities while maintaining its security-first philosophy.

**Recommendation: Proceed with implementation as planned.**
