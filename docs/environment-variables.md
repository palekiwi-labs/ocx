# Environment Variables Reference

OCX can be configured via environment variables, which take precedence over configuration files. This is a comprehensive reference of all supported environment variables.

## Configuration Priority

Environment variables are evaluated in this order (highest to lowest):

1. **Environment Variables** (highest priority)
2. Project Config (`./ocx.json`)
3. Global Config (`~/.config/ocx/ocx.json`)
4. Defaults (lowest priority)

## Complete Environment Variables

### Workspace and Container

#### `OCX_WORKSPACE`
Path to the workspace directory mounted into the container. Defaults to current directory.

**Type:** Path string

**Example:**
```bash
export OCX_WORKSPACE=/home/user/projects/my-app
ocx opencode
```

**Note:** The path determines how it's mapped inside the container:
- Paths under `$HOME` → `/home/username/...`
- Paths outside `$HOME` → `/workspace/...`

#### `OCX_CONTAINER_NAME`
Override the automatic container name.

**Type:** String

**Example:**
```bash
export OCX_CONTAINER_NAME=my-dev-container
```

**Default:** Generated as `ocx-<projectname>-<port>`. 

**Note:** For `ocx run`, a unique UUID suffix is appended (e.g., `ocx-<projectname>-<port>-run-a1b2c3d4`) to allow multiple headless tasks to run simultaneously or alongside an interactive session.

### Port and Network

#### `OCX_PORT`
Override the port number used by opencode.

**Type:** Integer (1024-65535)

**Example:**
```bash
export OCX_PORT=8080
```

**Default:** Auto-generated based on project path hash

#### `OCX_PUBLISH_PORT`
Whether to publish port 80 in the container to the host port.

**Type:** Boolean (`true`/`false`)

**Example:**
```bash
export OCX_PUBLISH_PORT=true
```

**Default:** `false`

#### `OCX_NETWORK`
Docker networking mode for the container.

**Type:** String (`bridge`, `host`, `none`)

**Example:**
```bash
export OCX_NETWORK=host
```

**Default:** `bridge`

**Note:** See [Security Hardening](security-hardening.md) for security implications.

#### `OCX_ADD_HOST_DOCKER_INTERNAL`
Add `--add-host=host.docker.internal:host-gateway` to enable container access to host services.

**Type:** Boolean (`true`/`false`)

**Example:**
```bash
export OCX_ADD_HOST_DOCKER_INTERNAL=true
```

**Default:** `true`

**Use case:** Access services running on the host (e.g., databases, APIs) from within the container via `host.docker.internal`. This is useful for local development scenarios where the container needs to communicate with host services.

### Docker Image and Version

#### `OCX_OPENCODE_VERSION`
The opencode version to use.

**Type:** Version string (`latest` or `X.Y.Z`)

**Example:**
```bash
export OCX_OPENCODE_VERSION=1.2.3
export OCX_OPENCODE_VERSION=latest
```

**Default:** `latest`

#### `OCX_CUSTOM_BASE_DOCKERFILE`
Path to a custom Dockerfile to use as the base image.

**Type:** File path

**Example:**
```bash
export OCX_CUSTOM_BASE_DOCKERFILE=docker-ocx/Dockerfile
```

**Default:** None (uses default base)

**See:** [Custom Base Images](custom-base-images.md) for details

### Resource Limits

#### `OCX_MEMORY`
Memory limit for the container.

**Type:** String with suffix (`k`, `m`, `g`)

**Example:**
```bash
export OCX_MEMORY=2048m
export OCX_MEMORY=2g
```

**Default:** `1024m`

**Valid formats:** `512m`, `1g`, `2048m`, etc.

#### `OCX_CPUS`
CPU limit for the container.

**Type:** Float (number of CPUs)

**Example:**
```bash
export OCX_CPUS=2.0
export OCX_CPUS=0.5
```

**Default:** `1.0`

#### `OCX_PIDS_LIMIT`
Maximum number of processes (PIDs) in the container.

**Type:** Integer

**Example:**
```bash
export OCX_PIDS_LIMIT=200
```

**Default:** `100`

**Note:** Set higher for applications that spawn many processes.

### Security

#### `OCX_FORBIDDEN_PATHS`
Paths that should be shadow-mounted (isolated from host) for security.

**Type:** Comma-separated paths

**Example:**
```bash
export OCX_FORBIDDEN_PATHS=/etc,/root,/var
```

**Default:** None

**See:** [Security Hardening](security-hardening.md) for details

#### `OCX_READ_ONLY`
Whether to mount the container root filesystem as read-only.

**Type:** Boolean (`true`/`false`)

**Example:**
```bash
export OCX_READ_ONLY=false
```

**Default:** `true`

**Warning:** Disabling read-only root reduces security significantly.

### Tmpfs Configuration

#### `OCX_TMP_SIZE`
Size of the tmpfs mount for `/tmp`.

**Type:** String with suffix (`k`, `m`, `g`)

**Example:**
```bash
export OCX_TMP_SIZE=1g
```

**Default:** `500m`

#### `OCX_WORKSPACE_TMP_SIZE`
Size of the tmpfs mount for `/workspace/tmp`.

**Type:** String with suffix (`k`, `m`, `g`)

**Example:**
```bash
export OCX_WORKSPACE_TMP_SIZE=1g
```

**Default:** `500m`

**Note:** tmpfs mounts are in-memory and don't persist data.

### User Mapping

#### `OCX_USERNAME`
Username to create inside the container.

**Type:** String

**Example:**
```bash
export OCX_USERNAME=developer
```

**Default:** Your host username

#### `OCX_UID`
User ID to use inside the container.

**Type:** Integer

**Example:**
```bash
export OCX_UID=1000
```

**Default:** Your host UID

**Note:** OCX automatically handles UID conflicts with existing users.

#### `OCX_GID`
Group ID to use inside the container.

**Type:** Integer

**Example:**
```bash
export OCX_GID=1000
```

**Default:** Your host GID

**Note:** OCX automatically handles GID conflicts with existing groups.

### Configuration and Environment Files

#### `OCX_OPENCODE_CONFIG_DIR`
Path to the OpenCode configuration directory (mounted into the container).

**Type:** Directory path

**Example:**
```bash
export OCX_OPENCODE_CONFIG_DIR=/home/user/.config/opencode
```

**Default:** `~/.config/opencode`

#### `OCX_ENV_FILE`
Path to a project-specific environment file to load.

**Type:** File path

**Example:**
```bash
export OCX_ENV_FILE=.env.local
```

**Default:** `./ocx.env`

**Note:** Both global (`~/.config/ocx/ocx.env`) and project environment files are loaded.

### Data Volumes

#### `OCX_DATA_VOLUMES_MODE`
Control when data volumes (cache and local) are created.

**Type:** Enum (`always`, `git`, `never`)

**Example:**
```bash
export OCX_DATA_VOLUMES_MODE=always
export OCX_DATA_VOLUMES_MODE=never
```

**Default:** `git`

**Values:**
- `git` - Create volumes only for git repositories (default)
- `always` - Create volumes for all projects (git and non-git)
- `never` - Never create data volumes

**See:** [Volume Management](volume-management.md) for detailed information

#### `OCX_DATA_VOLUMES_NAME`
Override automatic volume naming with a custom name.

**Type:** String (lowercase alphanumeric + hyphens)

**Example:**
```bash
export OCX_DATA_VOLUMES_NAME=my-shared-cache
```

**Default:** None (uses automatic naming based on git remote or directory path)

**Warning:** Using the same volume name across different projects will make them share volumes, which can cause dependency conflicts.

**Valid format:** Must contain only lowercase letters, numbers, and hyphens, and start with a letter or number.

#### `OCX_EXTRA_DATA_VOLUMES`

Configure extra data volumes as a JSON string.

**Type:** JSON string (record)

**Format:** JSON record mapping keys to mount configurations.

Each configuration is a record with:
- `target` (required): Container mount path
- `source` (optional): Volume name or host path
- `mode` (optional): "rw" or "ro" (default: "rw")
- `type` (optional): "volume" or "bind" (default: "volume")

**Examples:**

Docker volume:
```bash
export OCX_EXTRA_DATA_VOLUMES='{"cargo":{"target":"~/.cargo","type":"volume"}}'
```

Host bind mount (read-only):
```bash
export OCX_EXTRA_DATA_VOLUMES='{"nix-store":{"source":"/nix/store","target":"/nix/store","mode":"ro","type":"bind"}}'
```

Multiple volumes:
```bash
export OCX_EXTRA_DATA_VOLUMES='{
  "cargo":{"target":"~/.cargo"},
  "nix-store":{"source":"/nix/store","target":"/nix/store","mode":"ro","type":"bind"}
}'
```

**Default:** `{}`

**Validation:**
- Keys: lowercase letters, numbers, hyphens only
- Bind mounts require absolute source paths
- Invalid configs cause immediate errors

**Note:** This provides an environment variable alternative to the `extra_data_volumes` setting in `ocx.json`. See [Volume Management](volume-management.md#extra-data-volumes) for more details.

### Other

#### `TZ`
Timezone for the container.

**Type:** Timezone string (IANA timezone database)

**Example:**
```bash
export TZ=America/New_York
export TZ=UTC
```

**Default:** Host timezone

## OpenCode Passthrough Environment Variables

OCX automatically passes through OpenCode-specific environment variables from your host environment to the container. This allows you to configure OpenCode's behavior, authenticate with LLM providers, and customize its operation.

### How It Works

When you run `ocx opencode`, `ocx run`, or `ocx exec`, OCX checks for OpenCode-specific environment variables in your host environment and passes them through to the container if they exist. This works seamlessly with the `ocx.env` files:

**Precedence Order (highest to lowest):**
1. Host environment variables (e.g., `ANTHROPIC_API_KEY=xyz ocx run summarize`)
2. Project env file (`./ocx.env`)
3. Global env file (`~/.config/ocx/ocx.env`)

This means you can store API keys in `ocx.env` files and temporarily override them with environment variables when needed.

### Important Notes

1. **Path-based variables** - `OPENCODE_CONFIG` and `OPENCODE_MODELS_PATH` must use paths inside the container, not host paths. However, `OPENCODE_CONFIG_DIR` supports host paths and will be automatically bind-mounted by OCX.

2. **API keys and secrets** should be stored in `ocx.env` files (which should not be committed to version control) rather than in shell profiles.

3. **Optional variables** - You only need to set the variables you actually use. OCX only passes through variables that exist in your environment.

### Supported Variables

#### LLM Provider API Keys & Credentials

| Variable | Provider |
| :--- | :--- |
| `ANTHROPIC_API_KEY` | Anthropic Claude models |
| `OPENAI_API_KEY` | OpenAI models |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Google Gemini models |
| `AZURE_OPENAI_API_KEY` | Azure OpenAI deployments |
| `AWS_BEARER_TOKEN_BEDROCK` | Bearer token for Amazon Bedrock auth |
| `AWS_REGION` | AWS region for Bedrock |
| `AWS_PROFILE` | AWS credentials profile for Bedrock |
| `OPENROUTER_API_KEY` | OpenRouter models |
| `MISTRAL_API_KEY` | Mistral models |
| `GROQ_API_KEY` | Groq models |
| `XAI_API_KEY` | xAI models |
| `DEEPSEEK_API_KEY` | DeepSeek models |
| `TOGETHER_API_KEY` | Together AI models |
| `PERPLEXITY_API_KEY` | Perplexity models |
| `FIREWORKS_API_KEY` | Fireworks AI models |
| `AICORE_SERVICE_KEY` | SAP AI Core authentication |
| `AICORE_DEPLOYMENT_ID` | SAP AI Core deployment target |
| `GITLAB_TOKEN` | GitLab Duo authentication |
| `GITLAB_INSTANCE_URL` | GitLab instance endpoint |

#### External Integration

| Variable | Description |
| :--- | :--- |
| `GITHUB_TOKEN` | Used by GitHub tools and for fetching updates |
| `USE_GITHUB_TOKEN` | Boolean flag to explicitly enable use of `GITHUB_TOKEN` |

#### OpenCode Configuration & Behavior

| Variable | Description | Default |
| :--- | :--- | :--- |
| `OPENCODE_AUTO_SHARE` | Automatically share newly created sessions | `false` |
| `OPENCODE_DISABLE_AUTOUPDATE` | Disable automatic updates of OpenCode | `false` |
| `OPENCODE_DISABLE_PRUNE` | Disable automatic pruning of old tool outputs | `false` |
| `OPENCODE_DISABLE_AUTOCOMPACT` | Disable automatic context compaction | `false` |
| `OPENCODE_DISABLE_TERMINAL_TITLE` | Disable updating terminal title | `false` |
| `OPENCODE_DISABLE_PROJECT_CONFIG` | Ignore `opencode.json` files in project tree | `false` |
| `OPENCODE_DISABLE_SHARE` | Disable all session sharing capabilities | `false` |
| `OPENCODE_EXPERIMENTAL` | Enable experimental features | `false` |
| `OPENCODE_PERMISSION` | Inline JSON string defining tool/action permissions | `undefined` |
| `OPENCODE_MODELS_URL` | URL to fetch available model definitions from | `undefined` |
| `OPENCODE_GIT_BASH_PATH` | Explicit path to bash executable (useful on Windows) | `undefined` |
| `OPENCODE_SERVER_USERNAME` | Username for basic auth on OpenCode server | `undefined` |
| `OPENCODE_SERVER_PASSWORD` | Password for basic auth on OpenCode server | `undefined` |

### Path-Based Configuration

OCX provides special handling for path-based OpenCode variables to simplify usage between host and container.

| Variable | Description | Handling |
| :--- | :--- | :--- |
| `OPENCODE_CONFIG` | Custom path to configuration file | Requires **container path**. |
| `OPENCODE_CONFIG_DIR` | Path to directory containing configuration | **Host path supported**. OCX will automatically bind-mount this directory read-only into the container. |
| `OPENCODE_CONFIG_CONTENT` | Inline JSON string containing full configuration | N/A |
| `OPENCODE_MODELS_PATH` | Local file path for model definitions | Requires **container path**. |

**Special handling for `OPENCODE_CONFIG_DIR`:**
If `OPENCODE_CONFIG_DIR` is set in your host environment and points to a directory that exists, OCX will:
1. Automatically bind-mount that host directory into the container at the same absolute path.
2. The mount is performed **read-only** (`ro`) for security.
3. Missing parent directories in the container are automatically created by Docker.

This allows you to point OpenCode to a custom set of agents or configurations stored anywhere on your host without manually configuring extra volumes in `ocx.json`.

**Note:** The default OpenCode config directory is always mounted at `/home/username/.config/opencode` in the container.

#### System Settings

| Variable | Description |
| :--- | :--- |
| `HTTP_PROXY` | HTTP proxy configuration |
| `HTTPS_PROXY` | HTTPS proxy configuration |
| `SHELL` | Shell used for bash tool execution |
| `EDITOR` | Editor for session exports or file editing |
| `VISUAL` | Visual editor (fallback to `EDITOR`) |
| `LANG` | Locale setting for terminal |
| `LC_ALL` | Locale override |
| `TMUX` | Detect if running inside tmux for clipboard |
| `STY` | Detect if running inside screen for clipboard |

### Common Usage Examples

#### Setting Up API Keys

**Using global env file (`~/.config/ocx/ocx.env`):**
```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GITHUB_TOKEN=ghp_...
```

**Temporary override:**
```bash
ANTHROPIC_API_KEY=sk-ant-different-key ocx opencode
```

#### Enable Experimental Features

**In shell profile (`~/.bashrc` or `~/.zshrc`):**
```bash
export OPENCODE_EXPERIMENTAL=true
export OPENCODE_DISABLE_AUTOUPDATE=true
```

**Or in `ocx.env`:**
```bash
OPENCODE_EXPERIMENTAL=true
OPENCODE_DISABLE_AUTOUPDATE=true
```

#### Using Proxy Settings

```bash
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
ocx opencode
```

#### Using Inline Configuration

```bash
export OPENCODE_CONFIG_CONTENT='{"defaultModel":"claude-sonnet-4"}'
ocx opencode
```

#### Multiple LLM Providers

Store all your API keys in `~/.config/ocx/ocx.env`:
```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GOOGLE_GENERATIVE_AI_API_KEY=...
DEEPSEEK_API_KEY=...
```

Then switch models in OpenCode using the model selector without changing configuration.

#### Path-Based Variables (Advanced)

If you need to use a custom config location inside the container:

```bash
# The config dir is mounted at /home/username/.config/opencode
export OPENCODE_CONFIG=/home/username/.config/opencode/custom.json
ocx opencode
```

### Security Best Practices

1. **Never commit `ocx.env` files** containing API keys to version control:
   ```bash
   echo "ocx.env" >> .gitignore
   ```

2. **Use restrictive permissions** on env files:
   ```bash
   chmod 600 ~/.config/ocx/ocx.env
   chmod 600 ./ocx.env
   ```

3. **Store secrets in env files**, not shell profiles:
   - Shell profiles may be synced or shared
   - Env files can be easily excluded from version control
   - Easier to rotate keys by editing files

4. **Use different API keys** for different projects if needed:
   ```bash
   # In project-a/ocx.env
   ANTHROPIC_API_KEY=sk-ant-project-a-key
   
   # In project-b/ocx.env
   ANTHROPIC_API_KEY=sk-ant-project-b-key
   ```

### Troubleshooting

#### API Key Not Working

1. Check if the variable is set:
   ```bash
   echo $ANTHROPIC_API_KEY
   ```

2. Verify it's being passed to the container:
   ```bash
   ocx exec -- env | grep ANTHROPIC_API_KEY
   ```

3. Check file precedence:
   ```bash
   ocx config --sources
   ```

#### Path Variables Not Found

Remember that `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, and `OPENCODE_MODELS_PATH` require container paths:

**Wrong:**
```bash
export OPENCODE_CONFIG=~/.config/opencode/custom.json  # Host path
```

**Correct:**
```bash
export OPENCODE_CONFIG=/home/username/.config/opencode/custom.json  # Container path
```

#### Proxy Not Working

Make sure both `HTTP_PROXY` and `HTTPS_PROXY` are set:
```bash
export HTTP_PROXY=http://proxy:8080
export HTTPS_PROXY=http://proxy:8080
ocx opencode
```

Some corporate proxies may require authentication:
```bash
export HTTP_PROXY=http://user:pass@proxy:8080
export HTTPS_PROXY=http://user:pass@proxy:8080
```

## Usage Examples

### Quick Override for One Command

```bash
OCX_PORT=9000 OCX_PUBLISH_PORT=true ocx opencode
```

### Temporary Resource Increase

```bash
OCX_MEMORY=4096m OCX_CPUS=4.0 ocx exec bundle test
```

### Development vs Production Configuration

**Development (`~/.bashrc` or shell profile):**
```bash
export OCX_MEMORY=2048m
export OCX_CPUS=2.0
export OCX_NETWORK=bridge
export OCX_PUBLISH_PORT=true
```

**Production/CI (environment-specific):**
```bash
export OCX_MEMORY=1024m
export OCX_CPUS=1.0
export OCX_NETWORK=none
export OCX_PUBLISH_PORT=false
export OCX_FORBIDDEN_PATHS=/etc,/root,/var
```

### Using Environment Files

Create `.env` files for different scenarios:

**`~/.config/ocx/ocx.env` (global defaults):**
```bash
OCX_MEMORY=2048m
OCX_CPUS=2.0
TZ=UTC
```

**`./ocx.env` (project-specific):**
```bash
OCX_PORT=8080
OCX_PUBLISH_PORT=true
OCX_CUSTOM_BASE_DOCKERFILE=docker/Dockerfile
```

Both files are loaded, with project settings taking precedence.

### Debugging Configuration

To see which configuration values are being used and their source:

```bash
ocx config --sources
```

This shows each configuration option with its value and where it came from (env var, config file, or default).

## Validation Rules

### Memory Format
Must be a number followed by a unit:
- Valid: `512m`, `1g`, `2048m`, `4g`
- Invalid: `512`, `1gb`, `1024`, `2.5g`

### Port Range
Must be between 1024 and 65535 (inclusive)

### Version Format
Must be either `latest` or a semantic version `X.Y.Z`

### CPU Values
Must be a positive number or zero
- Valid: `0.5`, `1.0`, `2.0`, `4.5`
- Invalid: `-1`, `abc`

### PIDS Limit
Must be a positive integer

## Common Patterns

### 1. Override All Resources for Heavy Workloads

```bash
export OCX_MEMORY=8192m
export OCX_CPUS=8.0
export OCX_PIDS_LIMIT=500
export OCX_TMP_SIZE=2g
export OCX_WORKSPACE_TMP_SIZE=2g
```

### 2. Isolated Network for Security

```bash
export OCX_NETWORK=none
export OCX_PUBLISH_PORT=false
export OCX_FORBIDDEN_PATHS=/etc,/root,/var,/home
```

### 3. Host Network for Local Services

```bash
export OCX_NETWORK=host
export OCX_PUBLISH_PORT=false
```

**Use case:** Accessing local databases, services running on host

### 4. Custom Port for Multiple Projects

**Project A:**
```bash
export OCX_PORT=3001
ocx opencode
```

**Project B:**
```bash
export OCX_PORT=3002
ocx opencode
```

Or use auto-generated ports:
```bash
ocx port  # Returns deterministic port based on path
```

### 5. Minimal Resources for CI/CD

```bash
export OCX_MEMORY=512m
export OCX_CPUS=0.5
export OCX_PIDS_LIMIT=50
export OCX_NETWORK=none
export OCX_PUBLISH_PORT=false
export OCX_DATA_VOLUMES_MODE=never  # No caching in CI
```

### 6. Share Volumes Across Related Projects

```bash
# For microservices that share dependencies
export OCX_DATA_VOLUMES_NAME=my-team-shared-cache
```

**Use case:** Multiple related projects with compatible dependencies can share the same cache volumes for faster installs.

### 7. Disable Volumes for Temporary Work

```bash
export OCX_DATA_VOLUMES_MODE=never
ocx opencode
```

**Use case:** Quick testing, disposable environments, or when you want a completely clean state.

## Troubleshooting

### Variables Not Taking Effect

1. Check if you're setting them correctly:
   ```bash
   export OCX_PORT=8080  # Correct
   OCX_PORT=8080         # Only for current command
   ```

2. Verify with `ocx config --sources`

3. Check for typos in variable names

### Resource Limit Errors

**"OCI runtime create failed: container_linux.go:380: starting container process caused: process_linux.go:545: container init caused: process_linux.go:519: setting cgroup config for process caused: failed to write "memory.limit_in_bytes": write /sys/fs/cgroup/memory/.../memory.limit_in_bytes: invalid argument"**

**Cause:** Invalid memory format

**Solution:** Use correct format like `1024m` or `1g`, not `1024`

### Port Already in Use

**Error:** Port is already allocated

**Solution:** Either:
- Use a different port: `export OCX_PORT=9000`
- Use auto-generated: remove `OCX_PORT` variable
- Stop the conflicting container

### Permission Issues

If files are not writable after changing UID/GID:

```bash
# Rebuild images with new user mapping
ocx build --force
```

## Best Practices

1. **Use Config Files for Persistent Settings**
   - Store project settings in `./ocx.json`
   - Store global settings in `~/.config/ocx/ocx.json`
   - Use env vars for temporary overrides

2. **Keep Secrets Out of Environment Files**
   - Don't commit `.env` files to version control
   - Use secret management tools for sensitive data
   - Pass secrets as runtime env vars only

3. **Document Your Environment**
   - Comment your `.env` files
   - Keep a `.env.example` file for reference
   - Document required env vars in README

4. **Use Different Configs for Different Environments**
   ```bash
   # Development
   export OCX_ENV_FILE=.env.development

   # Testing
   export OCX_ENV_FILE=.env.test

   # Production
   export OCX_ENV_FILE=.env.production
   ```

5. **Version Pinning for Reproducibility**
   ```bash
   export OCX_OPENCODE_VERSION=1.2.3  # Pin specific version
   ```
   This ensures all team members use the same version.
