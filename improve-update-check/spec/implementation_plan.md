# Implementation Plan: Fix Docker Image Name Mismatch

## 1. The Problem

The `ocx upgrade` command fails because the Docker image name is inconsistent. The build process in `src/docker_tools/build.nu` creates a dynamic image name (e.g., `localhost/ocx-ocx`) when a custom Dockerfile is specified in `ocx.json`. However, the version check in `src/version/local.nu` looks for a hardcoded image name (`localhost/ocx`), causing a mismatch.

## 2. The Solution

I will centralize the image-naming logic by creating a new, configuration-aware function. This ensures that both the build process and the version check use the same image name, resolving the conflict.

### Step 1: Create a Centralized Image Name Function

-   **File:** `src/docker_tools/utils.nu`
-   **Action:** Add a new exported function, `get-image-name-base`.
-   **Logic:**
    -   This function will load the project configuration.
    -   It will check if `custom_base_dockerfile` is defined in the config.
    -   If it is, the function will return `localhost/ocx-<project_name>`.
    -   If not, it will return the default `localhost/ocx`.

### Step 2: Update the Build Process

-   **File:** `src/docker_tools/build.nu`
-   **Action:** Modify the `build_ocx` function.
-   **Logic:**
    -   Replace the existing image name logic with a call to the new `get-image-name-base` function.
    -   This will ensure the Docker images are built and tagged with the correct, centralized name.

### Step 3: Update the Version Check

-   **File:** `src/version/local.nu`
-   **Action:** Modify the `get-local-image-tags` function.
-   **Logic:**
    -   Import the `get-image-name-base` function from `docker_tools/utils.nu`.
    -   Replace the hardcoded `localhost/ocx` string with a call to the new function.
    -   This will make the version check look for the correct, dynamically-named image.

## 3. Expected Outcome

After these changes, the `ocx upgrade` command will correctly identify the locally built image, recognize that the latest version is already installed, and print the "Already up to date" message instead of prompting for an unnecessary upgrade.