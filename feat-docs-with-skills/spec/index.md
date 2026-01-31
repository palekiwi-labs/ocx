---
status: todo
---

# Feat: auto-generate skills from docs

---

`ocx docs` should allow user to generate "agent skills" based on the downloaded documentation content.

Support the following flags:
- `--skill`: creates a properly configured agent skill for "opencode documentation"
- `--global`: creates the skill in global opencode config directory
- `--force`: forces re-creation of the skill directory tree if already exists

Example:
`ocx docs --skill --global` should produce the following example structure:

```sh
~/.config/opencode/skills/
~/.config/opencode/skills/opencode-documentation/
~/.config/opencode/skills/opencode-documentation/SKILL.md
~/.config/opencode/skills/opencode-documentation/1.1.47/
~/.config/opencode/skills/opencode-documentation/1.1.47/agents.md
~/.config/opencode/skills/opencode-documentation/1.1.47/cli.md
~/.config/opencode/skills/opencode-documentation/1.1.47/config.md
...
```

Example of `~/.config/opencode/skills/opencode-documentation/SKILL.md`

```md
---
name: opencode documentation
description: provides documentation pages to help answer user questions about opencode
---

## Documentation pages for latest version:

[agents](./1.1.47/agents.md)
[cli](./1.1.47/cli.md)
[config](./1.1.47/config.md)
```
