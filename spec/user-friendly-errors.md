---
status: todo
branch: user-friendly-errors
pr:
---

# User friendly errors

Currently, all our errors appear to the user as:

```bash
ocx exec ls
Error: nu::shell::error

  × Container 'ocx-ocx-54023' is not running
   ╭─[/nix/store/875z9823i2bxzg00xsf5b9mbdlbgzws0-ocx-0.1.0-alpha.2-/share/ocx/src/docker_tools/exec.nu:8:9]
 7 │     if not (container-is-running $container_name) {
 8 │         error make {
   ·         ─────┬────
   ·              ╰── originates from here
 9 │             msg: $"Container '($container_name)' is not running"
   ╰────
  help: Start the container first with: ocx opencode
```

This is because we use `error make` to create errors but we never handle them in the entrypoint functions for subcommands.

Make sure every subcommand in `main.nu` prints clean user-friendly errors.
