# Bug: VERSION overwrites version/ dir on Mac OS

A user on Mac OS (apple silicon) reported failure during installation
of `ocx` via the nix.flake:

- `src/VERSION` file overwrote `src/version/` directory.

They report changing the name to `src/VERSION.txt` fixed it
