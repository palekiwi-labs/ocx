# Design Report: `ocx run` Command

## 1. Context and Problem Statement

`ocx` is a secure Docker wrapper for the `opencode` CLI. Its primary command, `ocx opencode`, is designed for long-running, interactive sessions by creating a persistent, named container for a given project.

While functional for interactive use, this design is unsuitable for scripting and automation. The key limitations are:

*   **Container Conflict:** The use of a fixed container name per project means only one `ocx` command can run at a time. If an interactive session is active, any attempt to run a second command (e.g., from a script) will fail with a "container name in use" error.
*   **Lack of Parallelism:** It is impossible to execute multiple `opencode` tasks in parallel, a common requirement for advanced scripting.

The goal is to design a new, top-level `ocx run` command specifically for scripting that overcomes these limitations.

## 2. The `opencode` API Foundation

The `ocx run` command will be a wrapper around the `opencode` CLI's own non-interactive command.

*   **Command:** `opencode run [message..]`
*   **Purpose:** To execute a single, one-shot prompt and return the result to standard output without launching the full TUI. This is the intended entrypoint for scripting and automation within the `opencode` ecosystem.
*   **Key Flags:** `ocx run` must act as a passthrough, accepting any valid flags for `opencode run`, including but not limited to:
    *   `--file, -f`: To attach file(s) as context.
    *   `--model, -m`: To specify the model to use.
    *   `--agent`: To specify the agent to use.
    *   `--command`: To execute a specific slash command.

## 3. Use Cases and Requirements for `ocx run`

### 3.1. Primary Use Cases

The `ocx run` command should be designed to support the following scenarios:

*   **General Automation:** Running `opencode` as part of CI/CD pipelines, cron jobs, or other automated workflows.
*   **Git Hooks:** Automatically generating commit messages from staged diffs, suggesting code improvements, or linting documentation.
*   **CLI Integration:** Integrating with other shell commands by piping input or chaining commands (`git diff | ocx run "Summarize these changes"`).
*   **Parallel Execution:** Allowing scripts to fire off multiple independent `opencode` tasks concurrently without blocking.

### 3.2. Architectural Requirements

To support the above use cases, the implementation of `ocx run` must adhere to the following critical architectural principles:

*   **1. Ephemeral Execution:** Each `ocx run` invocation must create a new, temporary container for the command and ensure this container is automatically deleted upon completion (`docker run --rm`).

*   **2. Concurrency and Isolation:** The command must prevent container name conflicts. This is best achieved by generating a **unique, randomized name** for each ephemeral container. This guarantees that `ocx run` can be executed in parallel without any interference.

*   **3. Non-Interactive Operation:** The container should be run in a non-interactive mode (e.g., without the `-t` flag in `docker run`) as it is intended for scripting and will not require a TTY.
