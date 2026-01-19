---
status: done
---

# Extra commands

---

## Description

Create utility commands `ocx <command>` that wrap docker command

### `stat`

By default, the command runs stats for the project container (resolving the name correctly).

With `--all` flag, the command runs stat for all running ocx containers.
We must determine the method of filtering the containers. Some options:
- all the containers using the `ocx` image
- all the containers whose name starts with `ocx-`
- same other more reliably and comprehensive method?

### `ps`

List running containers for this project, match on container name

Support `-a` to list all running `ocx` containers, match on container name prefix `ocx-`

### volume

returns volumes for this project

### exec

execute a command in this projects ocx container

### stop

stop project container
