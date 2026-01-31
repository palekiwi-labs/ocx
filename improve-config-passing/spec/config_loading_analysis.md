The spec file at `.agents/improve-config-passing/spec/index.md` suggests that the command `(config load)` is used frequently and redundantly, leading to unnecessary re-computation of the configuration.

### Analysis

1.  **Grep Results**: A `grep` for `(config load)` confirms this suspicion, revealing 17 occurrences across the codebase. The files with multiple calls are concentrated in the `src/docker_tools` directory, specifically in `build.nu` and `utils.nu`. Other affected files include `src/upgrade.nu`, `src/version/resolver.nu`, `src/docs.nu`, and `src/workspace.nu`.

2.  **Code Inspection**:
    *   `src/docker_tools/build.nu`: The `main` function loads the config, and then calls `build_ocx` and `build_custom_base`, which *also* load the config. This is a clear example of redundant loading within a single command execution.
    *   `src/docker_tools/utils.nu`: Contains several functions that load the config. Notably, `get-current-container-name` loads the config and then calls `resolve-container-name`, which loads it again.

3.  **Call Hierarchy**: The `use ./utils.nu` grep reveals that the utility functions in `utils.nu` are widely used across most of the files in `src/docker_tools`. This means the redundant config loading in `utils.nu` has a cascading effect.

### Refactoring Plan

The proposed solution is to apply a "pass-through" pattern for the configuration.

1.  **Load Once**: Identify the top-level entry point for each command (e.g., the `main` function). Load the configuration *once* in this function.
2.  **Pass as Argument**: Pass the loaded config object as an argument to any subsequent functions that need it.
3.  **Remove Redundant Loads**: Remove the `let cfg = (config load)` lines from all the child functions that now receive the config as a parameter.

This approach will be applied systematically to all affected files, starting with the most heavily impacted `src/docker_tools` directory. Special attention will be paid to `utils.nu` to ensure the changes are propagated correctly to all its callers.