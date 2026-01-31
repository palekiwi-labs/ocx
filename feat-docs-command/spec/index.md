---
status: todo
---

# Add a feature to fetch docs

Opencode github repo publishes documentation for `opencode` in markdown files.

`https://api.github.com/repos/anomalyco/opencode/contents/packages/web/src/content/docs?ref=($version)`

This documentation could be useful for users working with opencode when configuring and developing workflows.

Let's support a convienient way to fetch and save the available documentation.

## Possible API

`ocx docs --output <dirname>` should download all the available documentation into the specified <dirname>

## Reference files

- .agents/feat-docs-command/ref/fetch-docs.nu
