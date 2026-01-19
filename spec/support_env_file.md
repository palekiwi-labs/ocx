---
status: todo
---

# Support env file

Allow config to specify a location of an env file that is used for `--env-file`.

This file can contain variables (key-value pairs) that will be mounted in the container and used by `opencode`, such as `GEMINI_API_KEY`, etc

This by default should be `ocx.env` that can be place in either the root global config (`~/.config/ocx`) or per project in the project dir. We should load both global and per project env files in such an order that gives per proect env a priority
