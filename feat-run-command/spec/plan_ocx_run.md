# Implementation Plan: `ocx run` Command

## 1. Overview
The `ocx run` command enables one-shot, non-interactive execution of `opencode` commands. It is designed for scripting, CI/CD pipelines, and parallel execution, overcoming the single-instance limitation of the standard `ocx opencode` session.

## 2. Technical Design

### 2.1. Naming Strategy (Hierarchical)
To ensure observability while allowing parallelism, containers will use a hierarchical naming scheme rooted in the project's standard container name.

*   **Format:** `[project-container-name]-run-[random-suffix]`
*   **Example:**
    *   Main Session: `ocx-myproject-8080`
    *   Run Job A: `ocx-myproject-8080-run-a1b2c3d4`
    *   Run Job B: `ocx-myproject-8080-run-x9y8z7w6`

This links all "run" containers to their parent project while guaranteeing unique names for concurrency.

### 2.2. Execution Model
*   **Ephemeral:** Containers run with `--rm` and are automatically deleted upon exit.
*   **Non-Interactive:** Runs with `docker run -i` (no `-t` pseudo-TTY). This supports piping (stdin/stdout) and background execution.
*   **No Ports:** Does not publish ports (`-p`) to avoid "Address already in use" conflicts.
*   **Volume Consistency:** Reuses the exact same volume mounts (`-v`) and environment variables (`--env-file`) as the main `ocx opencode` command, ensuring scripts share the project's context and cache.

### 2.3. Observability (`ocx ps`)
The `ocx ps` command will be updated to display both the main session and any active "run" jobs for the current project.
*   **Current Filter:** `^name$`
*   **New Filter:** `^name(-run-.*)?$`

## 3. Implementation Steps

### Step 1: Create `src/docker_tools/run_one_shot.nu`
This new module will contain the logic for the ephemeral run command.
*   Import `utils.nu`, `config`, `volume_name.nu`, etc.
*   Replicate the environment setup from `run.nu`.
*   Generate the hierarchical name:
    ```nu
    let parent_name = (resolve-container-name $port)
    let random_suffix = (random chars --length 8)
    let container_name = $"($parent_name)-run-($random_suffix)"
    ```
*   Execute `docker run --rm -i ... opencode run ...`

### Step 2: Update `src/docker_tools/ps.nu`
Modify the `main` function to broaden the filter regex when listing project containers, allowing users to see their background scripts running.

### Step 3: Update `src/docker_tools/mod.nu`
Export the new `run_one_shot` module.

### Step 4: Update `src/main.nu`
*   Add the `run` subcommand:
    ```nu
    def --wrapped "main run" [...args] {
        try {
            docker_tools run_one_shot ...$args
        } catch { |err|
            errors pretty-print $err
        }
    }
    ```
*   Update `print_help` to list the new command.

## 4. Usage Examples
```bash
# Analyze a file and output to stdout
cat src/main.rs | ocx run "Explain this code"

# Generate a commit message
git diff --staged | ocx run "Generate a commit message"

# Run in parallel (background)
ocx run "task 1" &
ocx run "task 2" &
```
