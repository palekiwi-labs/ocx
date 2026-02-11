# Custom Base Images

## Requirements

Your custom base image only needs **3 simple requirements**:

1. **Linux with glibc** - OpenCode binary requires glibc (standard Linux C library)
   - Works: Debian, Ubuntu, Fedora, CentOS, Amazon Linux, etc.
   - Needs wrapper: Alpine (uses musl instead of glibc)

2. **Include `curl`** - Required by OCX to download the OpenCode binary

3. **Standard user tools** - Should have `useradd`, `groupadd`, `getent` commands
   - Present in virtually all Linux distributions
   - Part of the `shadow` package (usually pre-installed)

**That's it!** OCX automatically handles:
- User creation with your host UID/GID
- UID/GID conflict resolution
- Directory setup (.cache, .local, /workspace)
- Proper permissions and ownership

**Why glibc?** OpenCode is compiled for glibc (standard Linux C library). Alpine uses musl which is incompatible without a compatibility layer.

**Why curl?** The OCX layer downloads the OpenCode binary during image build.

**Why user tools?** OCX creates a container user matching your host UID to ensure file permissions work correctly.

## Ready-to-Use Examples

For your convenience, we provide ready-to-use Dockerfile examples for common development environments. You can copy these directly into your project or use them as a starting point.

To use an example, copy the files from the desired directory into your project's `docker-ocx` folder and set your configuration accordingly:

- **Nushell**: A modern shell environment with useful tools like `fd-find`, `ripgrep`, and `jq` pre-installed.
  - [`Dockerfile`](./examples/nushell/Dockerfile)
- **Nix**: A Nix-based environment with modern development tools (ast-grep, fd, gh, jq, nushell, ripgrep). Two approaches available:
  - [`Dockerfile.build-user`](./examples/nix/Dockerfile.build-user) - **(Recommended)** Cleaner approach where tools are available without Nix complexity. User doesn't need to know about Nix. Can't install additional Nix packages without rebuild.
  - [`Dockerfile.final-user`](./examples/nix/Dockerfile.final-user) - Full Nix environment available for the OCX user. Can install additional Nix packages at runtime. Better for Nix users or those who want flexibility.
- **Ruby**: A Ruby environment with `ruby-lsp` and common linters (`rubocop`, `erb_lint`) pre-installed.
  - [`Dockerfile`](./examples/ruby/Dockerfile)
  - [`Gemfile`](./examples/ruby/Gemfile)
- **Rust**: A Rust development environment with essential tools like `fd-find`, `ripgrep`, and `jq`.
  - [`Dockerfile`](./examples/rust/Dockerfile)

To use an example, copy the files from the desired directory into your project's `docker-ocx` folder and set your configuration accordingly:

```json
{
  "custom_base_dockerfile": "docker-ocx/Dockerfile"
}
```

## How OCX Handles UID/GID Conflicts

OCX automatically handles common conflicts like:

- **NixOS users** with GID 100 (`users` group)
- **Node.js images** with `node` user at UID 1000
- **Ruby images** with `ruby` user at UID 999
- Any other existing users in base images

**How it works:**
1. OCX checks if your UID/GID already exists in the base image
2. If the GID exists, OCX reuses the existing group
3. OCX creates your user with the `--non-unique` flag to handle conflicts
4. File permissions work because they're based on numeric UID/GID, not usernames

**Example on NixOS:**
- Your host user has GID 100 (`users` group)
- Base image also has GID 100 (`users` group)
- OCX reuses the existing group
- File ownership matches: GID 100 on host = GID 100 in container ✅

You don't need to worry about this - OCX handles it automatically!

## Configuration

### Global Config (Shared Across Projects)

Place your Dockerfile in `~/.config/ocx/<name>/Dockerfile`. See the [Ready-to-Use Examples](#ready-to-use-examples) for templates.

**Config in any project:**
```json
{
  "custom_base_dockerfile": "ruby/Dockerfile"
}
```

**Result:** All projects using this config share `ocx-ruby:<opencode-version>`

### Project-Local (Project-Specific)

Place your Dockerfile in your project directory. See the [Ready-to-Use Examples](#ready-to-use-examples) for templates.

**Config:**
```json
{
  "custom_base_dockerfile": "docker-ocx/Dockerfile"
}
```

**Result:** Project gets unique image like `ocx-myproject-docker-ocx:<opencode-version>`

## Build Context

The build context is always the directory containing the Dockerfile. This means:

- `COPY` and `ADD` commands are relative to that directory
- You can place files next to the Dockerfile for inclusion in the build

**Example:**
```
~/.config/ocx/ruby/
├── Dockerfile
├── Gemfile
└── Gemfile.lock
```

```dockerfile
# In Dockerfile
COPY Gemfile* /tmp/
RUN cd /tmp && bundle install
```

## Troubleshooting

### Error: "curl: not found" during build

**Cause:** Your custom base doesn't include curl, which is required to download OpenCode.

**Solution:** Add curl to your Dockerfile:

```dockerfile
# Debian/Ubuntu
RUN apt-get update && apt-get install -y --no-install-recommends curl

RUN yum install -y curl
```

### Error: "useradd: command not found" or "groupadd: command not found"

**Cause:** Your base image doesn't have standard user management tools.

**Solution:** Install the `shadow` package (or equivalent):

```dockerfile
# Debian/Ubuntu
RUN apt-get update && apt-get install -y --no-install-recommends passwd

# Fedora/CentOS
RUN yum install -y shadow-utils
```

### Error: "Permission denied" when editing files

**Cause:** Likely a volume mount issue or the workspace directory ownership is incorrect.

**Solution:**
1. Rebuild the images: `ocx build --base --force && ocx build --force`
2. Check that your workspace is not in a restricted location
3. Verify your user UID/GID match the container: Run `id` on host and `ocx shell` then `id` in container

### OCX creates user successfully but files aren't writable

**Cause:** The base image might have strict file permissions or AppArmor/SELinux restrictions.

**Solution:**
1. Check Docker volume permissions: `docker volume inspect {container-name}-local`
2. Try running with relaxed security: Add to your config: `{"network": "host"}`
3. Check SELinux labels if on Fedora/RHEL: `ls -Z` on workspace
