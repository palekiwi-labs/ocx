Here is a detailed plan for implementing the config-passing refactor.

### Phase 1: Refactor `src/docker_tools/utils.nu`

The functions in `utils.nu` are the most frequently used, so they are the first target.

1.  **Modify function signatures**:
    *   `export def resolve-container-name [cfg: record, port: int]`
    *   `export def get-current-container-name [cfg: record]`
    *   `export def get-image-name-base [cfg: record]`
2.  **Remove `(config load)`**: Delete the `let cfg = (config load)` line from each of these functions.
3.  **Update internal calls**: In `get-current-container-name`, update the call to `resolve-container-name` to pass the `cfg` record: `resolve-container-name $cfg $port`.

### Phase 2: Refactor `src/docker_tools/build.nu`

This file has several nested calls that need to be updated.

1.  **`main` function**:
    *   The existing `let cfg = (config load)` will be the single source of truth.
    *   Update calls to `build_custom_base` and `build_ocx` to pass the `$cfg` variable.
2.  **`build_ocx` function**:
    *   Modify signature to `def build_ocx [cfg: record, --force, --no-cache]`.
    *   Remove its internal `(config load)`.
    *   Update calls to `get-image-name-base`, `config resolve-user`, and `build_custom_base` to pass the `$cfg` variable.
3.  **`build_custom_base` function**:
    *   Modify signature to `def build_custom_base [cfg: record, --force, --no-cache]`.
    *   Remove its internal `(config load)`.
    *   Update the call to `config resolve-user` to pass `$cfg`.

### Phase 3: Update Callers of `utils.nu`

I will now iterate through the files that `use ./utils.nu` and update them.

*   For each file (`ps.nu`, `run.nu`, `exec.nu`, `stats.nu`, `shell.nu`, `stop.nu`):
    1.  In the `main` (or equivalent top-level) function, add `let cfg = (config load)`.
    2.  Find all calls to the modified `utils.nu` functions (`get-current-container-name`, `resolve-container-name`, etc.).
    3.  Update these calls to pass the `$cfg` variable.
    4.  Remove any now-redundant `(config load)` calls from within these files.

### Phase 4: Refactor Remaining Files

Finally, address the remaining files identified in the initial `grep` search.

*   For each file (`src/upgrade.nu`, `src/version/resolver.nu`, `src/docs.nu`, `src/docker_tools/volume.nu`, `src/docker_tools/image.nu`, `src/workspace.nu`):
    1.  Apply the same pattern: locate the top-level function.
    2.  Ensure the config is loaded only once.
    3.  Pass the `$cfg` variable to any internal functions that require it.
    4.  Remove all other `(config load)` calls. For many of these files, this will just involve removing a single redundant call within one function.

By following these four phases, the redundant config loading will be eliminated, and the codebase will be more efficient and maintainable.