---
status: todo
---

# Port documentation

---

Opencode has a client/server architecture.
By default it listens on a random port on the localhost interface inside the container.

`ocx` allows publishing the port by binding to port 80 in the container.
However, unless `opencode` is explictly instructed to listen on port 80,
then the binding is not effective.

There are two ways to specify the port and hostname for `opencode`.

1. with command line arguments: `--port` and `--hostname` which we can append to `ocx opencode`
2. via opencode config

Example `opencode.json` config:

```json
{
  "server": {
    "port": 80,
    "hostname": "0.0.0.0",
  }
}
```

`ocx` allows the user to manually specify a fixed port in the config, or it will default
to generating a port based on the path of the project.

The port is useful for editor integration that may use a plugin to communicate with
the opencode server. `ocx` exposes a command `ocx port` that will return the host port number
that running `ocx` in this directory would bind to (bind port `80` in the container to).
