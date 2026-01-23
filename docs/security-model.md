# OCX Security Model

OCX provides a secure development environment through multiple layers of defense. This document explains the security architecture, threat model, and how to configure OCX for different security requirements.

## Overview

OCX is designed for **local development environments** where developers run code editors and development tools in isolated containers. The security model balances strong isolation with developer productivity.

## Default Security Layers

OCX implements defense-in-depth through multiple independent security mechanisms:

### 1. Capability Dropping (`--cap-drop ALL`)

**What it does:** Removes all Linux capabilities from the container.

**Why it matters:** This is one of the most critical security layers. Capabilities are granular permissions that allow processes to perform privileged operations (like changing network configuration, loading kernel modules, or accessing raw devices). By dropping all capabilities, OCX prevents the container from performing any privileged operations, even if an attacker achieves code execution.

**Protects against:**
- Privilege escalation to host kernel
- Network manipulation
- Device access
- System time modification
- Loading kernel modules

**Example attacks prevented:**
- Exploiting kernel vulnerabilities that require specific capabilities
- Container breakout attempts that rely on CAP_SYS_ADMIN or CAP_NET_ADMIN

### 2. No New Privileges (`--security-opt no-new-privileges`)

**What it does:** Prevents any process in the container from gaining additional privileges.

**Why it matters:** Even if a process tries to use setuid binaries or other privilege escalation techniques, this flag ensures no child process can have more privileges than its parent.

**Protects against:**
- Setuid/setgid binary exploitation
- Privilege escalation via sudo or similar tools
- Common container escape techniques

### 3. Non-Root User (UID/GID Mapping)

**What it does:** OCX automatically creates a non-root user inside the container, mapped to your host UID/GID.

**Why it matters:** Running as a non-root user limits what the container can do to its own filesystem and prevents root-level access to mounted volumes. This is critical for protecting your host files and the container's system files.

**Protects against:**
- Modifications to system binaries in `/bin`, `/usr/bin`, etc.
- Changes to system configuration in `/etc`
- Writing to protected areas of the filesystem
- File permission issues on mounted volumes

**Benefits:**
- Files created in mounted volumes have correct ownership
- Cannot accidentally `rm -rf /` as root
- Reduces impact of compromised processes

### 4. Network Isolation (Bridge Networking)

**What it does:** Containers run in an isolated network namespace by default (bridge mode).

**Why it matters:** The container has its own network stack, separate from the host. It cannot directly access host network interfaces or sniff host traffic.

**Protects against:**
- Lateral movement to other containers or host services
- Network-based attacks on host system
- Unauthorized access to host services

**Configuration:**
- Ports must be explicitly published (`publish_port: true`)
- Host services accessible via `host.docker.internal` (optional)
- Can be fully isolated with `network: "none"`

### 5. Shadow Mounts for Forbidden Paths

**What it does:** Mounts empty tmpfs over sensitive host paths to prevent access.

**Why it matters:** Prevents the container from reading or modifying critical host files that might be accessible through bind mounts.

**Default protected paths:**
- `/etc/passwd`, `/etc/shadow` (when mounted)
- `/etc/sudoers`
- Other paths specified in `forbidden_paths` config

**Protects against:**
- Reading host credentials
- Tampering with system authentication
- Information disclosure

### 6. Tmpfs for Temporary Directories

**What it does:** Mounts `/tmp` and `/workspace/tmp` as in-memory filesystems (tmpfs).

**Why it matters:** 
- Temporary files are automatically cleaned up when container stops
- No persistence of potentially sensitive temporary data
- Better performance for temporary operations
- Prevents filling up host disk with temp files

**Configuration:**
- `tmp_size`: Size of `/tmp` (default: 500m)
- `workspace_tmp_size`: Size of `/workspace/tmp` (default: 500m)

## Writable Root Filesystem (Default)

By default, OCX containers have a **writable root filesystem** (`read_only: false`). This design decision prioritizes developer experience while maintaining strong security through the layers described above.

### Why Writable by Default?

1. **Developer Tool Compatibility**: Many development tools expect to write to various locations in the home directory:
   - `~/.config` - Application configuration
   - `~/.npm`, `~/.gem`, `~/.cargo` - Package manager caches
   - `~/.bash_history`, `~/.zsh_history` - Shell history
   - `~/.vscode-server` - VS Code server data
   - And many more...

2. **Industry Alignment**: Other development container solutions use writable filesystems:
   - VS Code Dev Containers
   - GitHub Codespaces
   - Gitpod
   - Docker Desktop Dev Environments

3. **Ephemeral by Design**: Development containers are typically short-lived. Any malicious modifications are lost when the container is removed.

4. **Strong Baseline Security**: The combination of dropped capabilities, non-root user, and no-new-privileges provides robust protection even with a writable filesystem.

### What's the Risk?

With a writable filesystem, a compromised process can:

**Session Persistence:**
- Modify shell startup files (`~/.bashrc`, `~/.zshrc`) to re-execute on next session
- This is the primary risk for long-running dev containers

**Configuration Tampering:**
- Alter tool configurations (e.g., `.gitconfig` to steal credentials)
- Modify editor settings or extensions

**Data Tampering:**
- Subtly alter source code files being developed

### Why This Risk is Acceptable for Development

1. **Development vs. Production**: Development containers are workspaces, not production services. The threat model is different.

2. **Other Layers Prevent Breakout**: An attacker still cannot:
   - Escape to the host system (no capabilities)
   - Escalate privileges (no-new-privileges)
   - Persist beyond container removal
   - Access other containers (network isolation)

3. **Developer Awareness**: Developers working with untrusted code should practice defense-in-depth:
   - Review dependencies before installing
   - Use separate containers for untrusted work
   - Regularly rebuild containers from clean images
   - Enable strict mode when needed

## Strict Security Mode (Optional)

For security-sensitive projects or when working with untrusted code, OCX offers an opt-in strict security mode with a read-only root filesystem.

### Enabling Strict Mode

**Configuration file (`ocx.json`):**
```json
{
  "read_only": true
}
```

**Environment variable:**
```bash
export OCX_READ_ONLY=true
```

### What Changes in Strict Mode?

- Container root filesystem is mounted as read-only (`--read-only`)
- System files in `/bin`, `/usr`, `/etc`, etc. cannot be modified
- Home directory is read-only by default

### Important: Data Volumes Required

**Strict mode requires data volumes to be enabled** (`data_volumes_mode: "git"` or `"always"`). This is because:

- Data volumes (`~/.cache` and `~/.local`) are mounted as writable
- These provide the necessary writable storage for tools to function
- Without volumes, the container cannot write anywhere (unless using tmpfs)

### Known Limitations in Strict Mode

Some tools may fail or require workarounds:

1. **Shell history won't persist** (unless you mount `~/.bash_history` as a volume)
2. **Some package managers** may need additional configuration
3. **VS Code extensions** may have issues (write to `~/.vscode-server`)

**Workaround:** Use `data_volumes_name` to create a shared volume for all paths that need to be writable.

### When to Use Strict Mode

Consider strict mode when:
- Working with untrusted or unreviewed code
- Security requirements mandate immutable infrastructure
- Running containers in a semi-production or CI/CD context
- You need compliance with security policies
- Long-running containers that might be targeted

## Threat Model

### What OCX Protects Against

**✅ Container Breakout/Escape:**
- Dropped capabilities prevent privilege escalation to host kernel
- Non-root user limits damage potential
- No-new-privileges blocks common escape techniques

**✅ Privilege Escalation:**
- No capabilities means no privileged operations
- No-new-privileges prevents setuid exploitation
- Non-root user contains damage

**✅ Host File Access:**
- Workspace is explicitly mounted
- Shadow mounts protect sensitive paths
- UID mapping ensures correct ownership

**✅ Network-Based Attacks:**
- Isolated network namespace
- Explicit port publishing required
- Can be fully isolated with `network: "none"`

**✅ Resource Exhaustion:**
- Memory limits (`memory: "1024m"`)
- CPU limits (`cpus: 1.0`)
- Process limits (`pids_limit: 100`)
- Tmpfs size limits

### What OCX Does Not Protect Against (Default Mode)

**⚠️ In-Container Persistence (writable filesystem):**
- Malicious code can modify dotfiles for persistence
- Shell startup files can be compromised
- Tool configurations can be hijacked
- **Mitigation:** Use strict mode or rebuild containers regularly

**⚠️ Data Exfiltration:**
- If the container has network access, compromised code can send data out
- **Mitigation:** Use `network: "none"` for sensitive work, review code before running

**⚠️ Supply Chain Attacks:**
- Malicious dependencies in npm/pip/gem packages execute with user permissions
- **Mitigation:** Review dependencies, use separate containers for untrusted code

**⚠️ Code Tampering:**
- With writable filesystem, source code can be modified
- **Mitigation:** Use version control, code signing, strict mode

## Security Configuration Examples

### Maximum Compatibility (Default)

```json
{
  "read_only": false,
  "data_volumes_mode": "git",
  "network": "bridge",
  "publish_port": true
}
```

**Use case:** Regular development work with trusted code and tools.

### Enhanced Security for Sensitive Projects

```json
{
  "read_only": true,
  "data_volumes_mode": "git",
  "network": "bridge",
  "publish_port": false,
  "forbidden_paths": [".ssh", ".gnupg"]
}
```

**Use case:** Working with proprietary code, security-sensitive projects.

### Maximum Isolation (CI/CD, Untrusted Code)

```json
{
  "read_only": true,
  "data_volumes_mode": "never",
  "network": "none",
  "publish_port": false,
  "forbidden_paths": [".ssh", ".gnupg", ".aws", ".config"]
}
```

**Note:** This configuration may require tmpfs mounts for home directory to function properly.

**Use case:** Running untrusted code, automated testing, CI/CD pipelines.

## Best Practices

### For All Users

1. **Regularly Rebuild Containers**: Don't let development containers run for weeks. Rebuild from clean images periodically.

2. **Use Separate Containers for Untrusted Code**: If you need to test a questionable npm package or script, create a dedicated throwaway container.

3. **Review Dependencies**: Before installing packages, review their source and reputation.

4. **Keep OCX Updated**: Security improvements and bug fixes are released regularly.

5. **Mount Only What You Need**: Don't mount your entire home directory. Mount specific project directories.

### For Security-Sensitive Work

1. **Enable Strict Mode**: Use `read_only: true` for an additional security layer.

2. **Disable Network Access**: Use `network: "none"` if the project doesn't require internet access.

3. **Use Forbidden Paths**: Shadow-mount sensitive directories like `.ssh`, `.gnupg`, `.aws`.

4. **Minimize Volume Sharing**: Avoid using `data_volumes_name` to share volumes across unrelated projects.

5. **Audit Container Images**: If using custom base images, regularly audit and rebuild them.

### For Teams

1. **Provide Project Templates**: Create `ocx.json` configurations for different security levels.

2. **Document Security Choices**: Explain why certain settings are chosen for each project.

3. **Security Training**: Ensure developers understand the threat model and limitations.

4. **Incident Response**: Have a plan for what to do if a container is compromised.

## Comparison with Production Security

OCX's security model is designed for **development**, not production:

| Feature | OCX Development | Production Best Practice |
|---------|----------------|-------------------------|
| Root filesystem | Writable (default) | Read-only (mandatory) |
| User | Non-root (always) | Non-root (mandatory) |
| Capabilities | None (always) | None (mandatory) |
| Network | Isolated | Isolated + policies |
| Volumes | Persistent | External/ephemeral |
| Updates | Manual rebuild | Automated deployment |

**Key difference:** Development containers are mutable workspaces; production containers should be immutable infrastructure.

## Additional Resources

- [Security Hardening](security-hardening.md) - Detailed security configuration options
- [Volume Management](volume-management.md) - Understanding data persistence and volumes
- [Environment Variables](environment-variables.md) - All security-related configuration options

## Questions or Concerns?

If you have security questions or discover vulnerabilities, please:
- Review the documentation thoroughly
- Check if your use case matches the threat model
- Consider enabling strict mode for sensitive work
- Report security issues responsibly (see project README for contact)
