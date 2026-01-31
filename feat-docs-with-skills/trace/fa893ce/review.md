# Code Review: src/docs.nu

## 1. Correctness and Robustness

### Version Handling
- **Issue:** The script prepends `v` to the version string when calling the GitHub API: `$"($api_base)?ref=v($version)"`.
- **Impact:** This assumes all versions are tagged with a `v` prefix. If a user provides a branch name (e.g., `main`), a commit SHA, or a tag like `1.0.0` (without `v`), the API call will fail with a 404.
- **Recommendation:** Check if `$version` already starts with `v` or look up the version resolution logic to handle non-prefixed tags/branches.

### File Filtering
- **Issue:** `fetch_docs_contents` (GitHub API call) returns all items in the directory. The loop in `fetch_files` iterates over all items.
- **Impact:** If there are subdirectories in the target GitHub path, the script will attempt to download them as files. Since directories don't have a `download_url` in the same way or their URL points to a JSON description, `http get` will likely fail or return metadata instead of file content.
- **Recommendation:** Filter the file list to only include `type == "file"`.

### Extension Mapping
- **Issue:** The logic `str replace ".mdx" ".md"` is duplicated in `fetch_files` and `generate_skill`.
- **Impact:** Maintenance burden. If other extensions need mapping, it must be updated in two places.
- **Recommendation:** Perform the mapping once when the file list is first fetched/processed.

## 2. Performance

### Sequential Downloads
- **Issue:** Downloads are performed in a standard `for` loop: `for $file in $files { ... http get ... }`.
- **Impact:** Each file download waits for the previous one to complete. For documentation with 10-20+ files, this is much slower than parallel execution.
- **Recommendation:** Use Nushell's `par-each` to download files in parallel.

## 3. Readability and Style

### Naming Conventions
- **Issue:** The file uses a mix of snake_case (`fetch_docs_contents`, `resolve_version`, `validate_output_path`) and kebab-case (`generate-skill-content`).
- **Impact:** Inconsistency makes the codebase harder to read and follow.
- **Recommendation:** Standardize on one convention. Given the existing code, snake_case seems more prevalent for internal functions here, though Nushell often prefers kebab-case for commands.

### Function Naming
- **Issue:** `fetch_docs_contents` doesn't fetch contents; it fetches a file list.
- **Recommendation:** Rename to `list_remote_docs`.

### Hardcoded Text in Skills
- **Issue:** `generate_skill_content` includes `## Documentation pages for latest version:`.
- **Impact:** Misleading if the user explicitly requested an older version.
- **Recommendation:** Use the `$version` variable in the header.
