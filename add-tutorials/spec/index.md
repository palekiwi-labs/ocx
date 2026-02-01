# Add Tutorials

Create a tutorial subdirectory inside `docs/`.
Tutorials are different from standard documentatio entries because docs
focus on a specific feature of the app, such as "environmental variables",
or "custom base images". In contrast, tutorials take a more comprehensive
and eclectic approach and instead guide the user in solving a specific
use case or situation. Tutorial may explain how to bring together different
features of the app and link to specific entries of the documentation
for a more thorough and detailed explanation.

## Scope

Write these tutorials:

### Setting up ocx in your project

We want to guide the user about what files they should probably want
to create when first setting up ocx in their project/repo.

Athough this guide focuses on per project configuration, user may also create
these files in the global config directory in `~/.config/ocx` if they want
to apply the configuration globally.

Most commonly these are the files they would wan to create:

#### `ocx.json`

Most likey they will want to add entries to "forbidden_paths" and possibly define
a custom base dockefile, e.g.:

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

#### `ocx.env`

This file is the default way to load environment variables into the container.
They might want to put secrets, such as API keys that opencode reads, or any
of their personal customizations (link to the second tutorial below about customization).
For that reason, it is recommended to `.gitignore` this file.

#### `Dockerfile.ocx`

If user decides to use a custom base image, they must provide a Dockrefile.
ocx will use the directory where the Dockerfile is found for build context.
Putting this file in the root of the project, will use the entire project
as context. Puttin it in `./ocx/Dockerefile` will allow scoping the build context
to `./ocx/`subdirectory only.

#### `opencode.json`

This file is read by opencode and defines opencode settings for this project.
Some of the settings that are worth considering are providers, agents, models and permissions, e.g.:

```json
{
  "model": "google/gemini-3-pro-preview",
  "small_model": "google/gemini-3-flash-preview",
  "default_agent": "plan",
  "agent": {
    "plan": {
      "model": "google/gemini-3-pro-preview",
    },
    "build": {
      "model": "google/gemini-2.5-pro"
    },
    "explore": {
      "model": "google/gemini-3-flash-preview"
    }
  },
  "enabled_providers": ["google"],
  "permission": {
    "external_directory": "ask",
    "bash": {
      "*": "allow",
      "direnv*": "deny",
      "git -f": "deny",
      "git branch -D": "deny",
      "git cherry-pick": "deny",
      "git clean": "deny",
      "git force": "deny",
      "git merge": "deny",
      "git pull": "deny",
      "git push": "deny",
      "git rebase": "deny",
      "git reset": "deny",
      "git stash drop": "deny",
      "git tag -d": "deny",
      "nix*": "deny",
      "sops*": "deny",
      "task*": "deny",
      "terraform*": "deny",
    }
  }
}
```

#### `.opencode`

This directory is also used by opencode and contains other configuration, mostly defined
in markdown files, such as cuctom commands bodies, prompts, etc.

### Personalizing your project with overrides

Files such as `opencode.json` which configure opencode per project are typically
tracked by git so that all devs could share the same custom commands, agents, etc.
However, users might want to develop their own workflows with their own custom commands,
sub-agents and prompts. How could they add these custom settings without modifying the tracked config files?

Opencode exposes two variables that are very suitable for this purpose:

- [OPENCODE_CONFIG](https://opencode.ai/docs/config/#custom-path)
  * points to a custom equivalent of `opencode.json` file.
  * Custom config is loaded between global and project configs in the precedence order.

- [OPENCODE_CONFIG_DIR](https://opencode.ai/docs/config/#custom-directory)
  * points to a custom equivalent of `.opencode/` dir.
  * The custom directory is loaded after the global config and .opencode directories, so it can override their settings.


How to make use of this variables with ocx?
use `ocx.env` in your project to define the variables. The values must point to a json file and directory
respectively. Where to place the files? One good place is in the global config at `~/.config/opencode/`
because `ocx` mounts this directory into the container.

Ex:
- `~/.config/opencode/custom-repo-a.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "ruby-tutor": {
      "mode": "primary",
      "model": "googe/gemini-3-pro-preview",
      "color": "#D34516",
      "description": "Interactive Ruby tutor that guides rather than implements",
      "prompt": "You are an expert Ruby tutor. Your goal is to teach me Ruby through practice. When I ask for help, explain the concepts and guide me to the solution rather than just writing the code. Use analogies, point out common pitfalls, and encourage idiomatic Ruby.",
      "permission": {
        "bash": "allow",
        "edit": "deny",
        "write": "deny",
      }
    }
  },
  "command": {
    "test": {
      "template": "Run the full test suite with coverage report and show any failures.\nFocus on the failing tests and suggest fixes.",
      "description": "Run tests with coverage",
      "agent": "build",
      "model": "anthropic/claude-haiku-4-5",
    }
  }
}
```

- `~/.config/opencode/custom-repo-a/`

```
~/.config/opencode/custom-repo-a/
~/.config/opencode/custom-repo-a/agents/
~/.config/opencode/custom-repo-a/agents/my-agent.md
```

Then inside your "repo-a" directory create `ocx.env` and define one or both:
```
OPENCODE_CONFIG=/home/<your-user-name>/opencode/custom-repo-a.json
OPENCODE_CONFIG_DIR=/home/<your-user-name>/opencode/custom-repo-a
```

**Important**: if using absolute paths, use expanded paths. The name of the user in the
container is by the fault the same as their user on host.
