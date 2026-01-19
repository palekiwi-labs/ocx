# Custom Base Image Template

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

## Basic Template

```dockerfile
FROM ubuntu:22.04

# Install your dependencies
# NOTE: curl is REQUIRED for OCX to download OpenCode binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    # Add your packages here \
    && rm -rf /var/lib/apt/lists/*

# That's all! OCX automatically handles user creation and directory setup.
```

No user creation needed! OCX creates the user automatically with your host UID/GID.

## Ruby/Rails Example

```dockerfile
FROM ruby:3.4-slim

# Install system packages
# NOTE: curl is REQUIRED for OCX to download OpenCode binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    postgresql-client \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Pre-install gems (optional - speeds up first run)
# Run as root since OCX user doesn't exist yet
WORKDIR /tmp
COPY Gemfile* ./
RUN bundle install
```

Clean and simple! OCX handles all user setup automatically.

## Node.js Example

```dockerfile
FROM node:20-slim

# Install system packages (curl usually pre-installed in node images)
# NOTE: curl is REQUIRED for OCX to download OpenCode binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Pre-install global packages (optional)
RUN npm install -g typescript ts-node
```

No user management needed! Even though the Node.js image has a `node` user, OCX creates your user automatically.

## Python Example

```dockerfile
FROM python:3.12-slim

# Install system packages (curl usually pre-installed in python images)
# NOTE: curl is REQUIRED for OCX to download OpenCode binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Pre-install packages (optional)
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt
```

Simple and clean! OCX creates your user and sets up directories automatically.

## Wrapping Existing Images

You can use any existing Docker image as a base! Just ensure curl is installed:

```dockerfile
FROM your-existing-image:latest

USER root

# Ensure curl is installed (required for OCX)
# Try apt first, fallback to apk for Alpine
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/* || \
    apk add --no-cache curl 2>/dev/null || true
```

That's it! OCX handles everything else automatically.

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

Place your Dockerfile in `~/.config/ocx/<name>/Dockerfile`:

```bash
mkdir -p ~/.config/ocx/ruby
cat > ~/.config/ocx/ruby/Dockerfile <<'EOF'
FROM ruby:3.4-alpine
ARG USERNAME=user
ARG UID=1000
ARG GID=1000
RUN apk add --no-cache bash build-base postgresql-client git
RUN addgroup -g ${GID} ${USERNAME} && \
    adduser -D -u ${UID} -G ${USERNAME} -s /bin/bash ${USERNAME}
USER ${USERNAME}
WORKDIR /workspace
EOF
```

**Config in any project:**
```json
{
  "custom_base_dockerfile": "ruby/Dockerfile"
}
```

**Result:** All projects using this config share `ocx-ruby:1.1.23`

### Project-Local (Project-Specific)

Place your Dockerfile in your project directory:

```bash
mkdir -p docker-ocx
cat > docker-ocx/Dockerfile <<'EOF'
FROM ruby:3.4-alpine
ARG USERNAME=user
ARG UID=1000
ARG GID=1000
# ... custom setup for this project
EOF
```

**Config:**
```json
{
  "custom_base_dockerfile": "docker-ocx/Dockerfile"
}
```

**Result:** Project gets unique image like `ocx-myproject-docker-ocx:1.1.23`

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

# Alpine
RUN apk add --no-cache curl

# Fedora/CentOS
RUN yum install -y curl
```

### Error: "useradd: command not found" or "groupadd: command not found"

**Cause:** Your base image doesn't have standard user management tools.

**Solution:** Install the `shadow` package (or equivalent):

```dockerfile
# Debian/Ubuntu
RUN apt-get update && apt-get install -y --no-install-recommends passwd

# Alpine (uses different commands - busybox)
# Alpine should work out of the box with adduser/addgroup

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

## Examples

See `.agents/custom-base-image/82a433c/example-dockerfile` and `example-docker-compose.yml` for a real Rails project example.
