---
status: todo
branch: fix/ocx-help
pr:
---

# Fix `ocx --help`

Currentl `ocx --help` returns output that may be confusing to the user.
It refers to `main.nu` when it is not how the app is accessed.

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
