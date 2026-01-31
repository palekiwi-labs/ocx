# Plan: Fix Dockerfile Architecture Support

## Issue
`src/Dockerfile.opencode` hardcodes the download URL to the `x64` binary:
`.../opencode-linux-x64.tar.gz`

This forces Apple Silicon (M1/M2/M3) users to run the container under emulation (slow), as they require the `arm64` binary.

## Solution
Update the `RUN` command to dynamically detect the system architecture and download the appropriate binary.

## Implementation Steps

1.  **Modify `src/Dockerfile.opencode`**:
    -   Replace the hardcoded `curl` command.
    -   Add a shell script snippet to detect architecture:
        -   `uname -m` returns `x86_64` -> use `x64`
        -   `uname -m` returns `aarch64` -> use `arm64`
    -   Update the download URL to use the detected architecture variable.

## Proposed Code Change

```dockerfile
# ... (existing args)

# Download and install OpenCode (Dynamic Arch)
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) BIN_ARCH="x64" ;; \
        aarch64) BIN_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${BIN_ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/opencode
```

## Verification
- Build the image on the current environment (x64) to ensure no regression.
