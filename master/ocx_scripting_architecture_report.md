# OCX Scripting Integration Report

## 1. Executive Summary

The goal was to design a robust scripting interface for `ocx`. The discussion evolved from a simple command alias to a comprehensive, multi-modal architecture that provides users with clear choices between safety, simplicity, and performance. The final agreed-upon plan is to implement two distinct, non-interfering scripting workflows.

## 2. The Challenge

The initial design of `ocx opencode` uses `docker run` with a persistent, named container for interactive sessions. This model is unsuitable for scripting because:
- **Conflict:** It prevents running a one-shot command if an interactive session is already active.
- **Concurrency:** It cannot handle multiple script invocations in parallel.

## 3. The Final Plan: A Multi-Modal Architecture

We will implement two separate tracks for scripting to cater to different user needs.

### Track 1: Simple, Stateless Scripting (`ocx run`)

This mode prioritizes safety, isolation, and correctness for common scripting tasks.

- **Command:** `ocx run <prompt...>`
- **Mechanism:**
    - Always creates a **new, ephemeral container** for each invocation (`docker run --rm`).
    - The container is given a **unique, randomized name** to prevent conflicts.
- **Key Features:**
    - **Isolation:** Each run is completely sandboxed and cannot interfere with interactive sessions or other runs.
    - **Data Safety:** Prevents data corruption by mounting the shared configuration **read-only** and using a temporary, isolated data volume that is destroyed with the container.
    - **Code Freshness:** Always operates on the latest version of the code in the mounted workspace.
- **Use Case:** The default choice for most scripts; ideal for CI/CD, git hooks, and general automation.

### Track 2: Advanced, High-Performance Scripting (`ocx serve` & `ocx exec`)

This mode prioritizes performance and stateful interaction for high-throughput, parallel workloads.

- **Commands:**
    - `ocx serve start|stop|status`: Manually manages the lifecycle of a persistent, background server container.
    - `ocx exec <prompt...>`: Connects to the running server to execute a command.
- **Mechanism:**
    - `ocx serve start` runs a detached `opencode serve` instance in a container with a fixed name (e.g., `ocx-project-server`) and exposes its port.
    - `ocx exec` uses the fast `opencode run --attach <url>` command to send tasks to the "hot" server, bypassing container startup overhead.
- **Key Features:**
    - **High Performance:** Subsequent `exec` calls are extremely fast.
    - **Parallelism:** Allows for firing off multiple commands to be processed in parallel by the server.
    - **Shared State:** All `exec` commands operate on the same session history within the server.
- **Use Case:** Intensive scripts, running many tasks in a loop, or workflows that require a shared context between commands.

## 4. Naming Convention

- `ocx run`: Chosen for its simplicity and directness for the stateless mode.
- `ocx exec`: Chosen over `client` or `send` because it leverages developers' familiarity with `docker exec`, clearly implying "execute a command inside a running container."
