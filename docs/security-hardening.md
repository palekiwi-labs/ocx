# Security Hardening

OCX implements multiple security layers to protect your development environment and host system. These features are enabled by default and can be configured as needed.

## Default Security Features

### Read-Only Root Filesystem

The container's root filesystem is mounted as read-only, preventing any modifications to the system files:

```bash
--read-only
```

This protects against:
- Accidental system file modifications
- Malicious processes modifying system files
- Inconsistencies from container restarts

**What can be modified:**
- Your workspace directory (mounted read-write)
- `/tmp` and `/workspace/tmp` (tmpfs, writable)
- `.cache` and `.local` volumes (persistent)

### Capability Dropping

All Linux capabilities are dropped from the container:

```bash
--cap-drop ALL
```

Capabilities are granular permissions that allow processes to perform privileged operations. By dropping all capabilities, the container runs with minimal privileges, following the principle of least privilege.

### No New Privileges

Prevents processes from gaining additional privileges:

```bash
--security-opt no-new-privileges
```

This blocks common privilege escalation techniques and ensures that any child process cannot have more privileges than its parent.

### Default Network Isolation

Containers use bridge networking by default, which provides:
- Network isolation from the host
- Separate network namespace
- Controlled port exposure via `OCX_PUBLISH_PORT`

### UID/GID Mapping

OCX automatically maps the container user to your host UID/GID, ensuring:
- Correct file permissions on mounted volumes
- No root user inside the container
- Consistent ownership across container restarts

### Shadow Mounting for Forbidden Paths

For security-sensitive paths, OCX creates shadow mounts (empty directories) to prevent access to host files:

```bash
--mount type=tmpfs,destination=/etc/passwd
--mount type=tmpfs,destination=/etc/shadow
--mount type=tmpfs,destination=/etc/sudoers
```

This prevents containers from accessing or modifying critical system files.

### tmpfs for Temporary Directories

Temporary directories are mounted as tmpfs (in-memory filesystems):

```bash
--tmpfs /tmp:size=500m
--tmpfs /workspace/tmp:size=500m
```

Benefits:
- No persistence of temporary files
- Automatic cleanup on container stop
- Better performance for temporary operations
- Configurable size limits

## Configuration

### Forbidden Paths

Define paths that should be shadow-mounted (isolated from host):

**Environment Variable:**
```bash
export OCX_FORBIDDEN_PATHS="/etc,/root,/var"
```

**Config File (`ocx.json`):**
```json
{
  "forbidden_paths": ["/etc", "/root", "/var"]
}
```

**Use Cases:**
- Prevent access to system configuration files
- Isolate container from sensitive host directories
- Comply with security policies

### Network Mode

Control how the container interacts with the network:

**Environment Variable:**
```bash
export OCX_NETWORK="bridge"
```

**Config File (`ocx.json`):**
```json
{
  "network": "bridge"
}
```

**Available Modes:**

| Mode | Description | Use Case |
|------|-------------|----------|
| `bridge` (default) | Isolated bridge network | Standard development |
| `host` | Shares host network namespace | Debugging network issues, local services |
| `none` | No network access | Computation-only tasks, offline work |

**Security Note:** Using `host` mode exposes all host network interfaces to the container. Use with caution.

### Read-Only Override

To disable read-only root filesystem (not recommended):

```bash
export OCX_READ_ONLY=false
```

**When you might need this:**
- Certain debugging scenarios
- Legacy applications requiring write access to system directories
- Custom base images with specific requirements

**Warning:** This significantly reduces security and should be avoided.

### Tmpfs Sizing

Configure the size of temporary filesystems:

```bash
export OCX_TMP_SIZE="1g"
export OCX_WORKSPACE_TMP_SIZE="1g"
```

**Config File:**
```json
{
  "tmp_size": "1g",
  "workspace_tmp_size": "1g"
}
```

**Default:** `500m` for each

**Considerations:**
- Larger tmpfs uses more RAM
- Too small tmpfs can cause failures for large temporary files
- Monitor usage with `docker stats`

## Security Best Practices

### 1. Use Custom Base Images Wisely

When creating custom base images:
- Use minimal base images (e.g., `-slim` variants)
- Avoid installing unnecessary packages
- Remove package caches after installation
- Don't run services as root

### 2. Don't Mount Sensitive Directories

Avoid using `OCX_WORKSPACE` to mount directories containing:
- SSH keys (`~/.ssh`)
- API credentials (`~/.aws`, `~/.config/gcloud`)
- Passwords and secrets (`~/.password-store`)
- System directories (`/etc`, `/var`)

Instead, use environment variables for secrets when needed.

### 3. Review Forbidden Paths

Configure `OCX_FORBIDDEN_PATHS` to shadow:
- System directories: `/etc`, `/root`, `/var`
- Sensitive directories: `~/.ssh`, `~/.gnupg`
- Project-specific sensitive paths

### 4. Use Resource Limits

Set appropriate limits to prevent resource exhaustion:

```json
{
  "memory": "2048m",
  "cpus": "2.0",
  "pids_limit": "200"
}
```

### 5. Keep OCX Updated

Regularly run:
```bash
ocx upgrade
```

This ensures you have the latest security patches and features.

### 6. Network Exposure

Only expose ports when necessary:
```json
{
  "publish_port": false
}
```

When using `OCX_PUBLISH_PORT=true`:
- Use specific hostnames instead of `0.0.0.0` when possible
- Configure firewall rules
- Consider reverse proxies for production
- Use SSL/TLS termination

### 7. Audit Your Configuration

Check your current security settings:
```bash
ocx config
```

Review and audit:
- Network mode
- Published ports
- Forbidden paths
- Resource limits
- Read-only setting

## Common Security Scenarios

### Scenario 1: Highly Sensitive Project

```json
{
  "network": "none",
  "publish_port": false,
  "forbidden_paths": ["/etc", "/root", "/var", "/home"],
  "tmp_size": "256m",
  "workspace_tmp_size": "256m",
  "memory": "1024m",
  "cpus": "1.0"
}
```

This configuration:
- Disables network access completely
- Prevents port exposure
- Isolates from all system directories
- Limits temporary file sizes
- Constrains CPU and memory

### Scenario 2: Development with Local Services

```json
{
  "network": "host",
  "publish_port": false,
  "forbidden_paths": ["/etc", "/root"],
  "memory": "4096m",
  "cpus": "4.0"
}
```

This configuration:
- Uses host networking for access to local databases/services
- Doesn't publish ports (uses host network directly)
- Still isolates system directories
- Allows more resources for heavy development

### Scenario 3: Web Application Development

```json
{
  "network": "bridge",
  "publish_port": true,
  "hostname": "127.0.0.1",
  "forbidden_paths": ["/etc", "/root", "/var"],
  "memory": "2048m",
  "cpus": "2.0"
}
```

This configuration:
- Standard isolated network
- Publishes port to localhost only
- Allows access from browser/editor plugins
- Standard resource allocation

## Monitoring Security

### Check Container Security Settings

```bash
# Inspect running container
docker inspect $(ocx ps --format "{{.ID}}")

# Check for dropped capabilities
docker inspect $(ocx ps --format "{{.ID}}") | grep CapDrop

# Check for read-only root
docker inspect $(ocx ps --format "{{.ID}}") | grep ReadonlyRootfs

# Check security options
docker inspect $(ocx ps --format "{{.ID}}") | grep SecurityOpt
```

### Monitor Resource Usage

```bash
# View resource stats
ocx stats

# View all OCX container stats
ocx stats --all
```

### Check Access Logs

```bash
# View container logs
docker logs $(ocx ps --format "{{.ID}}")

# Follow logs in real-time
docker logs -f $(ocx ps --format "{{.ID}}")
```

## Security Trade-offs

| Feature | Security | Convenience | Recommendation |
|---------|----------|-------------|----------------|
| Read-only root | High | Low | Keep enabled |
| Capability drop | High | Medium | Keep enabled |
| No new privileges | High | High | Keep enabled |
| Bridge network | Medium | High | Default setting |
| Forbidden paths | High | Medium | Configure as needed |
| Resource limits | Medium | Medium | Set appropriately |

OCX is designed with security by default. Only disable features when absolutely necessary and understand the implications.
