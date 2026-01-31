---
status: todo
branch: host-exec
---

# Feature: `host-exec`

---

## Context

`ocx` allows running `opencode` in a container sandbox with fine-grained control.
Agents operating inside the container are only allowed to run the binaries that
we have explicitly specified in the dockerfie and installed in the container during
the build process.

Some of the commands cannot be practically set up in the container because they may
require the use of `docker` or need special authentication mechanisms or access tokens
that the agent cannot be granted.

## Scope

Explore the possibility of delegating the execution of certain whitelisted
commands directly on the host by means of a custom bi-directional container-to-host communication
process with a mounted Unix socket.

## Proposed design

### Basic architecture

Both a client side (container) and serves side (host) solutions are needed.

Create and mount a Unix socket associated with the directory in which `ocx` is run.

The container must be allowed to send requests to the host via the mounted Unix socket
with payload identifying the command and the arguments they would like to run.
This client-side utility could be called `host-exec` (inspired by Distrobox).

On the host, a process must listen to requests arriving at the socket and process them.
It should validate the requests against a whitelist of allowed/denied commands.

Example config entry in `ocx.json`:
```json
{
  "host_exec": {
    "teraform": {
      "*": false,
      "plan": true
    }
  }
}
```

If a request with payload requesting the output of `terraform plan` arrives,
the server should run this command on the host in the current directory and
respond with the output of the command so that the client in the container
could return it to caller.

If validation fails, return an error message informing the caller that
they are not authorized to run this command with the given args.


### Possible Refinement

Wrap whitelisted commands in scripts that impersonate real commands and install them
in `/usr/local/bin`, e.g. `/usr/local/bin/docker` in the container.

The script should intercept the arguments and invoke `host-exec` with a request
sent to the socket. The purpos of this refinement is to allow the AI agent
inside the container to call the commands they are familiar with, or call them
the same way the README in the project they are working on instructs them to do.
E.g. an agent may be instructed to run `rspec` via `docker exec -it test-container bin/rspec`.

If possible, when on the whitelist, the wrapped commands should be functionally indistinguishable to real commands
as far as possible.

## Implementation

`ocx` is an application currently written in nushell which is not an ideal choice for
writing a sensitive socket communication tool as described in this document.
Moreover, the container runs bash and bash is likewise inadequate.
For that reason, we would like to implement both the client-side and server-side
binaries in rust.
