# Configure git inside the container

---

Currently, the image ships without any git configuration.
If the agents attempts to commit code, they will run into issues.

## Scope

We would like to pregenerate an immutable (read-only) global git config
in the container during build.

We can default the required "user" settings (name, email) to something sensible,
like "opencode", but we need to expose ocx configuration options
to the user the override any global git settings.

Analyze how we could design the git config setting interface and
how we would install it in the container.
