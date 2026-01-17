---
status: todo
---

# Command: `stats`

---

## Description

Create an `ocx stats` command that wraps `docker stats`.

By default, the command runs stats for the project container (resolving the name correctly).

With `--all` flag, the command runs stat for all running ocx containers.
We must determine the method of filtering the containers. Some options:
- all the containers using the `ocx` image
- all the containers whose name starts with `ocx-`
- same other more reliably and comprehensive method?
