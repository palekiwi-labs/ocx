# Port Configuration

Opencode has a client/server architecture. By default it listens on a random port on the localhost interface inside the container.

`ocx` allows publishing the port by binding to port 80 in the container. However, unless `opencode` is explicitly instructed to listen on port 80, the binding is not effective.

## Specifying Port and Hostname

There are two ways to specify the port and hostname for `opencode`:

1. **Command line arguments:** Use `--port` and `--hostname` with `ocx opencode`
2. **Configuration file:** Set values in your opencode config

### Example opencode.json config:

```json
{
  "server": {
    "port": 80,
    "hostname": "0.0.0.0"
  }
}
```

## Auto-generated Default Port

When no explicit port is configured, `ocx` automatically generates a default port using a hash of the project path. This ensures that different projects consistently use different ports while maintaining predictability - the same project will always get the same port.

The generated port is deterministic and safe:
- Based on a stable hash of the full project path
- Always produces a valid port number (typically in the range 1024-65535)
- Eliminates the need for manual port management per project
- Allows `ocx port` to accurately predict the port before starting

`ocx` allows the user to manually specify a fixed port in the config, or it will default to generating a port based on the path of the project.

## Checking the Port

The port is useful for editor integration that may use a plugin to communicate with the opencode server. `ocx` exposes a command `ocx port` that will return the host port number that running `ocx` in this directory would bind to (bind port `80` in the container to).

### Usage examples

Check the port that would be used for the current directory:

```bash
ocx port
```

Start opencode with explicit port configuration:

```bash
ocx opencode --port 3000 --hostname 0.0.0.0
```

Use the port in scripts:

```bash
PORT=$(ocx port)
curl http://localhost:$PORT/doc
```

## Troubleshooting

If the port is already in use, opencode will fail to start. You can:
- Specify a different port using `--port` or config
- Check what's using the port: `lsof -i :<port>`
- Use a fixed port configuration to ensure consistency across runs
