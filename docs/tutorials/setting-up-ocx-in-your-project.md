# Setting up ocx in your Project

This guide walks you through the initial configuration of `ocx` within a project or repository. While many of these settings can be applied globally in `~/.config/ocx`, project-specific configuration ensures a consistent environment for all contributors.

## Configuration Overview

Most `ocx` projects benefit from a few key configuration files. These files allow you to define security boundaries, environment variables, and custom agent behaviors.

### `ocx.json`

The `ocx.json` file is the primary configuration for the `ocx` container itself. The most common use case is defining ["forbidden paths"](../security-hardening.md#forbidden-paths)—files or directories that the agent should never access (e.g., secrets or sensitive configuration).

You can also specify a custom Dockerfile if your project requires specific system dependencies.

```json
{
  "custom_base_dockerfile": "Dockerfile.ocx",
  "forbidden_paths": [
    ".envrc",
    "config/secrets.yml",
    "ocx.env",
    "ocx.json"
  ]
}
```

### `ocx.env`

This file is the default mechanism for loading environment variables into the container. It is the primary way to provide environment variables for [OpenCode configuration](https://opencode.ai/docs/config) and is commonly used for:
- API keys required by OpenCode agents.
- Personal customizations and path overrides.

**Security Note:** Because `ocx.env` often contains sensitive information, it should be added to your `.gitignore` file.

### `Dockerfile.ocx`

If your project requires a [custom base image](../custom-base-images.md), you can provide a `Dockerfile`. `ocx` uses the directory containing the Dockerfile as the build context.

- **Root level:** Placing `Dockerfile.ocx` in the project root uses the entire repository as the build context.
- **Subdirectory:** Placing it in `./ocx/Dockerfile` restricts the build context to that specific subdirectory, which can speed up builds.

### `opencode.json`

This file defines project-wide settings for OpenCode, the intelligence layer running inside `ocx`. It allows you to standardize models, agents, and permissions across the team.

```json
{
  "model": "google/gemini-3-pro-preview",
  "small_model": "google/gemini-3-flash-preview",
  "default_agent": "plan",
  "agent": {
    "plan": {
      "model": "google/gemini-3-pro-preview"
    },
    "build": {
      "model": "google/gemini-2.5-pro"
    }
  },
  "enabled_providers": ["google"],
  "permission": {
    "external_directory": "ask",
    "bash": {
      "*": "allow",
      "git push": "deny",
      "git force": "deny",
      "terraform*": "deny"
    }
  }
}
```

### The `.opencode` Directory

The `.opencode/` directory is used for more complex OpenCode configurations. It typically contains Markdown files defining:
- **Custom commands:** Project-specific shortcuts for common tasks.
- **System prompts:** Specialized instructions for custom agents.
- **Documentation:** Internal context for the AI agents to reference.

## Next Steps

Once your project is set up, you may want to [personalize your local workflow](./personalizing-your-project-with-overrides.md) using overrides that aren't tracked in git.
