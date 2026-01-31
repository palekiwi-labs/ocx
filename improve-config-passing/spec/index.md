# Improve config passing

In many commands, we frequently do this:

```nu
let cfg = (config load)
```

This means that the config is recomputed every time in different functions on the stack.

Investigate the extent of this occuring in the code and analyze if we could
improve it by computing the config once (maybe when the subcommand starts) and pass config as
an argument down into the functions.
