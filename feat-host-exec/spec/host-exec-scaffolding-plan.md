# Implementation Plan: Stub Client/Server Foundation with Nix Integration

## Overview
This plan focuses on creating minimal "hello world" style Rust binaries for the client and server, integrating them into the Nix build system, and testing the full pipeline from Rust compilation → Nix packaging → Docker image inclusion → Nushell integration.

**Goals:**
1. Initialize Rust workspace with stub client and server
2. Update `flake.nix` to build Rust binaries
3. Modify Nushell scripts to use the binaries
4. Update Dockerfile to install client binary
5. Test the complete build and integration flow
6. **No socket implementation yet** - just static output

---

## Phase 1: Rust Workspace Initialization

### 1.1 Create Directory Structure

```
ocx/
├── rust/
│   ├── Cargo.toml              # Workspace manifest
│   ├── shared/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       └── lib.rs          # Stub shared types
│   ├── client/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       └── main.rs         # Stub client
│   └── server/
│       ├── Cargo.toml
│       └── src/
│           └── main.rs         # Stub server
```

### 1.2 Workspace `Cargo.toml` Content

```toml
[workspace]
members = ["shared", "client", "server"]
resolver = "2"

[workspace.package]
version = "0.1.0"
edition = "2024"
authors = ["Palekiwi Labs"]
license = "MIT"

[workspace.dependencies]
# Shared library available to all crates
host-exec-shared = { path = "./shared" }
```

### 1.3 Shared Library (`rust/shared/`)

**`rust/shared/Cargo.toml`:**
```toml
[package]
name = "host-exec-shared"
version.workspace = true
edition.workspace = true
authors.workspace = true
license.workspace = true

[dependencies]
# Empty for now - just establish the structure
```

**`rust/shared/src/lib.rs`:**
```rust
//! Shared types and utilities for host-exec client and server
//!
//! This is a stub implementation for testing the build pipeline.

/// Version constant for the host-exec system
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Simple greeting function for testing
pub fn greeting() -> String {
    format!("host-exec shared library v{}", VERSION)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_exists() {
        assert!(!VERSION.is_empty());
    }

    #[test]
    fn test_greeting() {
        let msg = greeting();
        assert!(msg.contains("host-exec"));
        assert!(msg.contains(VERSION));
    }
}
```

### 1.4 Client Binary (`rust/client/`)

**`rust/client/Cargo.toml`:**
```toml
[package]
name = "host-exec"
version.workspace = true
edition.workspace = true
authors.workspace = true
license.workspace = true

[[bin]]
name = "host-exec"
path = "src/main.rs"

[dependencies]
host-exec-shared = { workspace = true }
```

**`rust/client/src/main.rs`:**
```rust
//! host-exec client (stub implementation)
//!
//! This binary will be installed in the container at /usr/local/bin/host-exec
//! For now, it just prints a static message to verify the build pipeline works.

use host_exec_shared::greeting;

fn main() {
    println!("host-exec client stub");
    println!("{}", greeting());
    println!();
    println!("Command: {:?}", std::env::args().collect::<Vec<_>>());
    println!();
    println!("✓ Client binary is working!");
    println!("✓ Rust build pipeline is functional");
    println!("✓ Nix integration successful");

    // Exit with success
    std::process::exit(0);
}
```

### 1.5 Server Binary (`rust/server/`)

**`rust/server/Cargo.toml`:**
```toml
[package]
name = "host-exec-server"
version.workspace = true
edition.workspace = true
authors.workspace = true
license.workspace = true

[[bin]]
name = "host-exec-server"
path = "src/main.rs"

[dependencies]
host-exec-shared = { workspace = true }
```

**`rust/server/src/main.rs`:**
```rust
//! host-exec-server (stub implementation)
//!
//! This binary will run on the host machine
//! For now, it just prints a static message to verify the build pipeline works.

use host_exec_shared::greeting;

fn main() {
    println!("host-exec-server stub");
    println!("{}", greeting());
    println!();
    println!("✓ Server binary is working!");
    println!("✓ Rust build pipeline is functional");
    println!("✓ Nix integration successful");
    println!();
    println!("(Server will listen on Unix socket in future implementation)");

    // For now, just exit successfully
    // In the real implementation, this would start a daemon
    std::process::exit(0);
}
```

---

## Phase 2: Nix Flake Integration

### 2.1 Update `flake.nix`

1. Build the Rust workspace binaries
2. Make binaries available to the main `ocx` package
3. Set up environment variables for binary paths

**Key changes:**

```nix
{
  # ... existing inputs ...

  outputs = { nixpkgs, flake-utils, fenix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Use fenix for Rust toolchain
        rustToolchain = fenix.packages.${system}.stable.toolchain;

        # Create Rust platform for building
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };

        # Common Rust package arguments
        rustPackageBase = {
          src = ./rust;
          cargoLock.lockFile = ./rust/Cargo.lock;

          # Build in release mode
          buildType = "release";

          # Metadata
          meta = with pkgs.lib; {
            license = licenses.mit;
            platforms = platforms.unix;
          };
        };

        # Build client binary (for container)
        host-exec-client = rustPlatform.buildRustPackage (rustPackageBase // {
          pname = "host-exec";
          version = "0.1.0";

          # Build only the client crate
          cargoBuildFlags = [ "-p" "host-exec" ];
          cargoTestFlags = [ "-p" "host-exec" ];

          meta = rustPackageBase.meta // {
            description = "host-exec client for container";
            mainProgram = "host-exec";
          };
        });

        # Build server binary (for host)
        host-exec-server = rustPlatform.buildRustPackage (rustPackageBase // {
          pname = "host-exec-server";
          version = "0.1.0";

          # Build only the server crate
          cargoBuildFlags = [ "-p" "host-exec-server" ];
          cargoTestFlags = [ "-p" "host-exec-server" ];

          meta = rustPackageBase.meta // {
            description = "host-exec server for host machine";
            mainProgram = "host-exec-server";
          };
        });

      in {
        packages = {
          # Expose individual Rust binaries
          inherit host-exec-client host-exec-server;

          # Main ocx package (updated)
          default = pkgs.stdenv.mkDerivation {
            pname = "ocx";
            version = builtins.readFile ./src/VERSION.txt;

            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/bin $out/share/ocx $out/libexec $out/share/ocx/binaries

              # Bundle all Nushell source files
              cp -r src $out/share/ocx/

              # Install server binary to libexec (for host use)
              cp ${host-exec-server}/bin/host-exec-server $out/libexec/

              # Install client binary to shared location (for Docker build context)
              cp ${host-exec-client}/bin/host-exec $out/share/ocx/binaries/

              # Create wrapper with access to binaries
              makeWrapper ${pkgs.nushell}/bin/nu $out/bin/ocx \
                --add-flags "$out/share/ocx/src/main.nu" \
                --set OCX_SERVER_BIN "$out/libexec/host-exec-server" \
                --set OCX_CLIENT_BIN "$out/share/ocx/binaries/host-exec"
            '';

            meta = with pkgs.lib; {
              description = "Secure Docker wrapper for OpenCode";
              homepage = "https://github.com/palekiwi-labs/ocx";
              license = licenses.mit;
              platforms = platforms.unix;
              mainProgram = "ocx";
            };
          };
        };
        # ... rest of flake ...
      }
    );
}
```

---

## Phase 3: Nushell Integration

### 3.1 Create `src/host_exec/mod.nu`

This module will provide helper functions for the stub implementation:

```nu
# host_exec module - provides utilities for host command execution

# Get the path to the server binary from environment
export def get-server-binary-path [] -> string {
    let from_env = $env.OCX_SERVER_BIN? | default null
    if $from_env != null { return $from_env }
    "./rust/target/release/host-exec-server"
}

# Get the path to the client binary from environment
export def get-client-binary-path [] -> string {
    let from_env = $env.OCX_CLIENT_BIN? | default null
    if $from_env != null { return $from_env }
    "./rust/target/release/host-exec"
}

# ... helper functions to test binaries ...
```

### 3.2 Add Test Command to `src/main.nu`

Add a new subcommand to test the host-exec binaries:

```nu
use host_exec

def "main host-exec" [
    --test-server
    --test-client
] {
    # ... implementation to run server/client binaries ...
}
```

---

## Phase 4: Docker Integration

### 4.1 Update `src/Dockerfile.opencode`

Modify the Dockerfile to copy the client binary from the build context:

```dockerfile
# ... existing content ...

# Install host-exec client binary (if provided)
ARG HOST_EXEC_CLIENT_PATH
COPY ${HOST_EXEC_CLIENT_PATH:-/dev/null} /tmp/host-exec 2>/dev/null || true
RUN if [ -f /tmp/host-exec ]; then \
        mv /tmp/host-exec /usr/local/bin/host-exec && \
        chmod +x /usr/local/bin/host-exec; \
    fi

# ... rest of Dockerfile ...
```

### 4.2 Update `src/docker_tools/build.nu`

Modify the build script to pass the client binary to Docker build:

```nu
# Pass --build-arg HOST_EXEC_CLIENT_PATH if OCX_CLIENT_BIN is available
```

---

## Phase 5: Testing Plan

1. **Local Rust Build**: `cd rust && cargo build --release`
2. **Nix Build**: `nix build`
3. **Integration Test**: `ocx host-exec --test-server` and `ocx host-exec --test-client`
4. **Docker Test**: `ocx build` and verify `host-exec` inside container

---

## Success Criteria

- Rust workspace builds with `cargo build`
- Nix builds successfully and bundles binaries
- `ocx` can execute both binaries via wrapper
- Docker image includes and can execute `host-exec`
