---
status: done
---

# Rename `run` to `opencode`

`opencode` also supports the `run` sub-command which would result in user calling:

```sh
ocx run run "user prompt"
```

Rename `main run` to `main opencode`.

An alternative would be to just use `main` and call run from it, but we might be shadowing any of our own subcommands or opencode subcommands that are named the same.
