---
status: done
branch: fix/ocx-help
pr:
---

# Fix `ocx --help`

Currently `ocx --help` returns output that may be confusing to the user.
It refers to `main.nu` when it is not how the app is accessed.

## Solution Implemented

Added a custom `help` command override that intercepts `--help` and `-h` flags before Nushell's auto-generated help handler processes them. This allows the existing custom help message (via `print_help()`) to be displayed consistently across all invocations.

### Changes Made

**File: `src/main.nu`**

1. Added a `help` function override at the top of the file (after imports):
   ```nushell
   # Override built-in help to show custom help for main script
   # This intercepts the --help flag before Nushell's auto-generated help
   def help [...rest] {
       print_help
   }
   ```

2. Added documentation comment to the `--version` flag in the `main` function for consistency.

### How It Works

- When users run `ocx --help` or `ocx -h`, Nushell's help system calls the custom `help` function instead of showing auto-generated help
- The custom `help` function calls `print_help()`, which displays the well-formatted custom help message
- All help invocations now show consistent output: `ocx --help`, `ocx -h`, `ocx help`, and `ocx` (no args)

### Original Problem

```
󰲒 ocx --help
Usage:
  > main.nu {flags}

Subcommands:
  main.nu build (custom) -
  main.nu config (custom) -
  main.nu exec (custom) -
  main.nu help (custom) -
  main.nu image (custom) -
  main.nu image list (custom) -
  main.nu image prune (custom) -
  main.nu image remove-all (custom) -
  main.nu o (custom) -
  main.nu opencode (custom) -
  main.nu port (custom) -
  main.nu ps (custom) -
  main.nu shell (custom) -
  main.nu stats (custom) -
  main.nu stop (custom) -
  main.nu upgrade (custom) -
  main.nu version (custom) -
  main.nu volume (custom) -

Flags:
  -h, --help: Display the help message for this command
  -v, --version

Input/output types:
  ╭───┬───────┬────────╮
  │ # │ input │ output │
  ├───┼───────┼────────┤
  │ 0 │ any   │ any    │
  ╰───┴───────┴────────╯
```
