# Headless Task Execution (ocx run)

`ocx run` is a subcommand designed for non-interactive execution of OpenCode tasks. It allows you to leverage OpenCode's agents and tools from your host shell without entering the interactive TUI or starting a persistent server.

## Overview

Unlike `ocx opencode`, which starts an interactive development session, `ocx run` executes a specific command and exits.

### Key Differences

| Feature | `ocx opencode` | `ocx run` |
| :--- | :--- | :--- |
| **Interactivity** | Interactive TTY (`-it`) | Headless (Pipe-friendly) |
| **Port Publishing** | Enabled (if configured) | Disabled |
| **Container Name** | `ocx-<project>-<port>` | `ocx-<project>-<port>-run-<uuid>` |
| **Default Command** | Starts OpenCode server/TUI | Appends `run` to arguments |

## Usage Examples

### Summarize a File
Quickly get a summary of a specific file using the default agent:
```bash
ocx run summarize -f src/main.nu
```

### Codebase Exploration
Use a specific agent to explore the project:
```bash
ocx run --agent explore "How does the docker_tools module handle container naming?"
```

### Integration in Scripts
Because `ocx run` does not allocate a TTY by default, its output can be easily piped or captured:
```bash
ocx run summarize -f README.md > summary.txt
```

## How It Works

1. **Automatic Command Wrapping**: When you execute `ocx run <args>`, OCX invokes the internal `opencode` binary with the `run` subcommand prepended to your arguments. For example, `ocx run summarize` becomes `opencode run summarize` inside the container.
2. **Parallel Execution**: Each `ocx run` invocation creates a container with a unique UUID suffix. This allows you to run multiple headless tasks in parallel, even while an interactive `ocx opencode` session is active in the same project.
3. **Environment Passthrough**: All OpenCode-specific environment variables (like `ANTHROPIC_API_KEY`) and `ocx.env` files are passed through to the headless container just as they are in interactive mode.

## Nix Workflow

If the Nix workflow is enabled (`nix: true`), `ocx run` automatically wraps the execution in `nix develop`, ensuring your headless tasks have access to all dependencies defined in your flake.

```bash
# Executed within the nix-develop shell
ocx run --agent research "Find all uses of mkShell in nixpkgs"
```

## Configuration

`ocx run` respects most configuration settings in `ocx.json`, including resource limits (`memory`, `cpus`), volume mounts, and custom base images. 

**Note on Ports**: The `publish_port` setting and `OCX_PORT` environment variable do **not** affect `ocx run`. It will never publish ports to the host.
