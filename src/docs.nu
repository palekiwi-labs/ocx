# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

use config
use version
use errors.nu

const OPENCODE_GITHUB_API_BASE = "https://api.github.com/repos/anomalyco/opencode/contents/packages/web/src/content/docs"
const OPENCODE_REPO_URL = "https://github.com/anomalyco/opencode"

const OCX_GITHUB_API_BASE = "https://api.github.com/repos/palekiwi-labs/ocx/contents/docs"
const OCX_REPO_URL = "https://github.com/palekiwi-labs/ocx"

export def main [
    --dir: string,      # Output directory (base)
    --version: string, # Optional version override
    --force,           # Overwrite existing files
    --skill,           # Create agent skill instead of regular docs
    --global,          # Create skill in global config (~/.config/opencode)
    --project,         # Create skill in project config (./.opencode)
    --ocx,             # Download OCX documentation instead of OpenCode
] {
    # 1. Load Config
    let cfg = (config load)
    let opencode_config_dir = ($cfg.opencode_config_dir | path expand)

    # 2. Determine Mode and Paths
    # If skill mode is active without explicit location, default to global
    let use_global = $skill and not $project

    # Validate: if not in skill mode, dir is required
    if not $skill and ($dir == null) {
        error make {
            msg: "--dir is required when not using --skill flag"
        }
    }

    # 3. Resolve Version
    let version_to_fetch = if $version != null {
        $version
    } else if $ocx {
        # For OCX docs, default to current version from VERSION.txt
        let version_path = ($env.FILE_PWD | path join "VERSION.txt")
        open $version_path | str trim
    } else {
        $cfg.opencode_version
    }

    let resolved_version = if $ocx {
        # For OCX, just use the version directly (no need to resolve via GitHub releases for OCX)
        $version_to_fetch
    } else {
        # For OpenCode, resolve version through the resolver
        (version resolve-version $version_to_fetch $cfg)
    }

    # 4. Configure based on --ocx flag
    let github_api_base = if $ocx { $OCX_GITHUB_API_BASE } else { $OPENCODE_GITHUB_API_BASE }
    let repo_url = if $ocx { $OCX_REPO_URL } else { $OPENCODE_REPO_URL }
    let skill_name = if $ocx { "ocx" } else { "opencode" }
    let doc_dir = if $ocx { "ocx" } else { "opencode" }
    let file_ext = if $ocx { ".md" } else { ".mdx" }

    # 5. Construct Paths based on mode
    let output_path = if $skill {
        if $use_global {
            [$opencode_config_dir "skills" $skill_name $resolved_version] | path join
        } else {
            ["./.opencode/skills" $skill_name $resolved_version] | path join
        }
    } else {
        [$dir $doc_dir $resolved_version] | path join
    }

    let skill_root = if $skill {
        if $use_global {
            [$opencode_config_dir "skills" $skill_name] | path join
        } else {
            ["./.opencode/skills" $skill_name] | path join
        }
    } else {
        null
    }

    # 5. Safety Checks
    if ($output_path | path exists) {
        if not $force {
            error make {
                msg: $"Directory '($output_path)' already exists and is not empty."
                label: {
                    text: "Use the --force flag to overwrite the contents of this directory."
                }
            }
        }
        print $"Cleaning directory '($output_path)'..."
        rm -r $output_path
    }

    mkdir $output_path

    # 6. Fetch & Download Loop
    let api_url = $"($github_api_base)?ref=v($resolved_version)"
    print $"Fetching file list from GitHub API for version ($resolved_version)..."

    let dir_contents = try {
        http get $api_url
    } catch { |err|
        errors pretty-print $err
        return
    }

    let files = ($dir_contents | where type == "file" and ($it.name | str ends-with $file_ext))

    print $"Found ($files | length) ($file_ext) files to download"

    for $file in $files {
        let filename = ($file.name | str replace ".mdx" ".md")
        let output_file = ([$output_path $filename] | path join)
        print $"Fetching '($file.name)' -> '($output_file)'"

        try {
            let content = http get $file.download_url
            $content | save $output_file
        } catch {
            print $"✗ Failed to fetch '($file.download_url)'"
        }
    }

    print $"✓ Documentation downloaded successfully to '($output_path)'"

    # 7. Generate SKILL.md if in skill mode
    if $skill and ($skill_root != null) {
        let skill_file = [$skill_root "SKILL.md"] | path join
        print $"Generating skill file at '($skill_file)'..."

        # Collect markdown file names for links
        let md_files = ($files | each { |file|
            ($file.name | str replace ".mdx" ".md")
        })

        # Generate skill content
        let skill_content = (generate-skill-content $skill_name $repo_url $resolved_version $md_files)
        $skill_content | save -f $skill_file

        print $"✓ Skill generated successfully at '($skill_file)'"
    }
}

def generate-skill-content [
    skill_name: string
    repo_url: string
    version: string
    files: list<string>
] {
    let base_name = ($skill_name | str replace "-documentation" "")
    let description = $"provides documentation pages to help answer user questions about ($base_name)"

    $"---
name: ($base_name)-documentation
description: ($description)
---

## Documentation pages for latest version:

($files | each { |name|
    $"[($name)]\(./($version)/($name)\)"
} | str join "\n")

## Source

Repository: [($repo_url)]\(($repo_url)\)
"
}
