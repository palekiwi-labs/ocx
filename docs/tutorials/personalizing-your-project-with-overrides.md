# Personalizing your Project with Overrides

In many projects, `opencode.json` and the `.opencode/` directory are tracked by Git to share custom commands and agents across the team. However, you may want to develop personal workflows, custom agents, or experimental prompts without modifying the shared configuration.

`ocx` provides a clean way to achieve this using environment variable overrides.

## Key Environment Variables

OpenCode recognizes two primary variables for injecting local configuration:

- [**`OPENCODE_CONFIG`**](https://opencode.ai/docs/config/#custom-path): Points to a JSON file that merges with the global and project-level `opencode.json`.
- [**`OPENCODE_CONFIG_DIR`**](https://opencode.ai/docs/config/#custom-directory): Points to a directory containing additional agents, commands, and prompts.

## Implementation Guide

To use these overrides with `ocx`, follow these steps:

### 1. Create your Local Configuration

A good practice is to keep your personal configurations in `~/.config/opencode/` on your host machine. This directory is automatically mounted by `ocx` into the container.

**Example Personal Config (`~/.config/opencode/my-workflow.json`):**

```json
{
  "agent": {
    "ruby-tutor": {
      "mode": "primary",
      "model": "google/gemini-3-pro-preview",
      "color": "#D34516",
      "description": "Interactive Ruby tutor that guides rather than implements",
      "prompt": "You are an expert Ruby tutor. Your goal is to teach me Ruby through practice. Explain concepts and guide me to the solution rather than just writing the code.",
      "permission": {
        "bash": "allow",
        "edit": "deny",
        "write": "deny"
      }
    }
  },
  "command": {
    "test-cov": {
      "template": "Run the full test suite with coverage and summarize failures.",
      "description": "Run tests with coverage",
      "agent": "build"
    }
  }
}
```

### 2. Configure `ocx.env`

In your project's root directory, create or edit `ocx.env` to point OpenCode to your custom files.

```bash
OPENCODE_CONFIG=/home/youruser/opencode/my-workflow.json
OPENCODE_CONFIG_DIR=/home/youruser/opencode/my-custom-agents/
```

> **Note on Paths:** Use the absolute path as it appears *inside* the container. By default, `ocx` maps your home directory to the same path inside the container (e.g., `/home/username`).

### 3. Benefits of this Approach

1.  **Zero Git Noise:** Your personal `ocx.env` is usually git-ignored, and your config files live outside the project repo.
2.  **Portability:** You can use the same `OPENCODE_CONFIG` across multiple projects by simply adding the variables to each project's `ocx.env`.
3.  **Precedence:** Custom configuration is loaded between the global and project levels, allowing you to override team defaults or add unique tools for your specific workflow.
