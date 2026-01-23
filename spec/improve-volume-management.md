---
status: todo
---

# Improve volume management

---

## Description

Currently, we always mount two separate volumes per project for cache and local files:

```nu
# src/docker_tools/run.nu L106-L107

"-v" $"($container_name)-cache:/home/($user)/.cache:rw"
"-v" $"($container_name)-local:/home/($user)/.local:rw"
```

Let's refer to these two mounted volumes collectively as "data volumes".
The cache is named after the container, which in turn is named after the absolute directory path.

## Issues

### Issue 1

This means that having a different branch of the same repository checked out in a different directory
would create new differently named data volumes. This is wasteful and prevents reuse of the data saved
in the volumes when working on the same repo project.

### Issue 2

Currently, new data volumes are created always for every project.
We should be able to give the user control over how and whether these data volumes are created.

## Potential solutions

Analyze the possibility of addresing the issue with the following:

1. Redesign the algorithm for generating data volume names for same repo reuse

- consider generating the name based on the git information, e.g. `<org>/<repo>`

2. Consider creating data volumes only for projects that are git repositories
3. Add a config setting that allows disabling data volume creation/mounting

- consider an enum value: "always", "git", "never", etc

4. Add a config setting that allows specifying a fixed data volume name for all projects
5. Add corresponding env vars for the new config settings
