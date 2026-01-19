# Custom Base Image Template

## Requirements

Your custom base Dockerfile **MUST**:

1. **Use a Debian/Ubuntu-based image** - OpenCode binary requires glibc (Alpine's musl is not supported)

2. **Accept build arguments:**
   - `USERNAME` - Container username (will match your host username)
   - `UID` - User ID (will match your host UID)
   - `GID` - Group ID (will match your host GID)

3. **Include `curl`** - Required to download OpenCode binary in the final image build

4. **Have `/usr/local/bin` in PATH** - Where OpenCode binary is installed

**Why Debian/Ubuntu only?** OpenCode is compiled for glibc (standard Linux C library). Alpine uses musl libc which is incompatible. Supporting Alpine would require gcompat which adds complexity and potential issues.

**Why UID/GID?** OCX mounts your workspace with files owned by your host UID. The container user must have the same UID to read/write these files.

**Why curl?** The OCX layer (Dockerfile.opencode) downloads the OpenCode binary using curl.

## Basic Template

```dockerfile
FROM ubuntu:22.04

ARG USERNAME=user
ARG UID=1000
ARG GID=1000

# Install your dependencies
# NOTE: curl is required for OCX to download OpenCode binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    # Add your packages here \
    && rm -rf /var/lib/apt/lists/*

# Create user (--non-unique handles UID/GID conflicts)
RUN groupadd ${USERNAME} --gid ${GID} --non-unique && \
    useradd ${USERNAME} \
      --create-home \
      --uid ${UID} \
      --gid ${GID} \
      --non-unique \
      --shell /bin/bash

USER ${USERNAME}
WORKDIR /workspace
```

## Ruby/Rails Example

```dockerfile
FROM ruby:3.4-slim

ARG USERNAME=user
ARG UID=1000
ARG GID=1000

# Install system packages
# NOTE: curl is required for OCX to download OpenCode binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    postgresql-client \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create user with --non-unique to handle conflicts
RUN groupadd ${USERNAME} --gid ${GID} --non-unique && \
    useradd ${USERNAME} \
      --create-home \
      --uid ${UID} \
      --gid ${GID} \
      --non-unique \
      --shell /bin/bash

USER ${USERNAME}

# Pre-install gems (optional - speeds up first run)
WORKDIR /tmp
COPY Gemfile* ./
RUN bundle install

WORKDIR /workspace
```

## Node.js Example

```dockerfile
FROM node:20-slim

ARG USERNAME=user
ARG UID=1000
ARG GID=1000

# Install system packages
# NOTE: curl is required for OCX to download OpenCode binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create user (--non-unique handles conflicts with existing node user)
RUN groupadd ${USERNAME} --gid ${GID} --non-unique && \
    useradd ${USERNAME} \
      --create-home \
      --uid ${UID} \
      --gid ${GID} \
      --non-unique \
      --shell /bin/bash

USER ${USERNAME}

# Pre-install global packages (optional)
RUN npm install -g typescript ts-node

WORKDIR /workspace
```

## Python Example

```dockerfile
FROM python:3.12-slim

ARG USERNAME=user
ARG UID=1000
ARG GID=1000

# Install system packages
# NOTE: curl is required for OCX to download OpenCode binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN groupadd ${USERNAME} --gid ${GID} --non-unique && \
    useradd ${USERNAME} \
      --create-home \
      --uid ${UID} \
      --gid ${GID} \
      --non-unique \
      --shell /bin/bash

USER ${USERNAME}

# Pre-install packages (optional)
COPY requirements.txt /tmp/
RUN pip install --user -r /tmp/requirements.txt

WORKDIR /workspace
```

## Wrapping Existing Images

If you have an existing image that doesn't support USERNAME/UID/GID:

```dockerfile
FROM your-existing-image:latest

ARG USERNAME=user
ARG UID=1000
ARG GID=1000

USER root

# Ensure curl is installed (required for OCX)
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/* || \
    apk add --no-cache curl 2>/dev/null || true

RUN groupadd ${USERNAME} --gid ${GID} --non-unique && \
    useradd ${USERNAME} \
      --create-home \
      --uid ${UID} \
      --gid ${GID} \
      --non-unique \
      --shell /bin/bash

USER ${USERNAME}
WORKDIR /workspace
```

## Handling UID/GID Conflicts

Base images often have existing users with common UIDs/GIDs (e.g., GID 100 for `users` group on NixOS, UID 1000 for `node` user). The `--non-unique` flag handles this gracefully.

### The `--non-unique` Flag

The `--non-unique` flag allows creating a user/group even if the UID/GID already exists:

```bash
groupadd ${USERNAME} --gid ${GID} --non-unique
useradd ${USERNAME} --uid ${UID} --gid ${GID} --non-unique
```

This creates multiple users with the same UID, which is fine since file permissions are based on the numeric UID, not the username.

**Example on NixOS:**
- Your host user has GID 100 (`users` group)
- The base image also has GID 100 (`users` group)
- With `--non-unique`, your user is added to the existing group
- File ownership by GID 100 on host matches GID 100 in container
- Permissions work correctly ✅

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
# Alpine
RUN apk add --no-cache curl

# Debian/Ubuntu
RUN apt-get update && apt-get install -y --no-install-recommends curl
```

### Error: "One or more build-args were not consumed"

**Cause:** Your Dockerfile doesn't accept USERNAME, UID, or GID.

**Solution:** Add these lines at the top of your Dockerfile:

```dockerfile
ARG USERNAME=user
ARG UID=1000
ARG GID=1000
```

### Error: "Permission denied" when editing files

**Cause:** The container user's UID doesn't match your host UID.

**Solution:** Ensure you're passing UID/GID and creating the user correctly in your Dockerfile. Check that the user creation logic matches one of the templates above.

### Error: "addgroup: gid 'XXX' in use" (Alpine)

**Cause:** The GID already exists in the base image (common with GID 100 on NixOS).

**Solution:** Use the GID conflict handling pattern from the templates above (check if GID exists and reuse it).

### Error: "useradd: UID already exists" (Debian)

**Cause:** The UID already exists in the base image.

**Solution:** Add `--non-unique` flag to handle existing UIDs:

```dockerfile
useradd ${USERNAME} --uid ${UID} --gid ${GID} --non-unique
```

## Examples

See `.agents/custom-base-image/82a433c/example-dockerfile` and `example-docker-compose.yml` for a real Rails project example.
