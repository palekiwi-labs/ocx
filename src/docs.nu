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
    --version: string,  # Optional version override
    --force,            # Overwrite existing files
    --skill,            # Create agent skill instead of regular docs
    --global,           # Create skill in global config (~/.config/opencode)
    --project,          # Create skill in project config (./.opencode)
    --ocx,              # Download OCX documentation instead of OpenCode
] {
    # Validate: if not in skill mode, dir is required
    if not $skill and ($dir == null) {
        error make {
            msg: "--dir is required when not using --skill flag"
        }
    }

    let cfg = config load
    let version = resolve_version $cfg $version --ocx=$ocx

    let github_api_base = if $ocx { $OCX_GITHUB_API_BASE } else { $OPENCODE_GITHUB_API_BASE }
    let repo_url = if $ocx { $OCX_REPO_URL } else { $OPENCODE_REPO_URL }
    let repo_name = if $ocx { "ocx" } else { "opencode" }

    let output_path = if $skill {
        let opencode_config_dir = ($cfg.opencode_config_dir | path expand)
        let base_path = if $project { "./opencode" } else { $opencode_config_dir }
        $"($base_path)/skills/($repo_name)-documentation"
    } else {
        $"($dir)/($repo_name)"
    }

    let files = fetch_docs_contents $github_api_base $version

    fetch_files $output_path $version $files --force=$force

    if $skill {
        generate_skill $repo_name $output_path $files $version $repo_url
    }
}

def fetch_docs_contents [api_base: string, version: string] {
    print $"Fetching file list from GitHub API for version ($version)..."

    try {
        http get $"($api_base)?ref=v($version)"
    } catch { |err|
        error make {
            msg: $"Cannot find documentation for version ($version)"
        }
    }
}

def fetch_files [
    output_path: string
    version:string
    files: list<record>
    --force
] {
    let output_path = $"($output_path)/($version)"
    validate_output_path $output_path --force=$force

    print $"Fetching ($files | length) files..."

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
}

def resolve_version [cfg: record, version?: string, --ocx] {
    let version = $version | default "latest"
    if $ocx {
        open ($env.FILE_PWD | path join "VERSION.txt") | str trim
    } else {
        version resolve-version $version $cfg
    }
}

def validate_output_path [output_path: string, --force] {
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
}

def generate_skill [
    name: string
    output_path: string
    files: list<record>
    version: string
    repo_url: string
] {
    let skill_file = $"($output_path)/SKILL.md"
    print $"Generating skill file at '($skill_file)'..."

    # Collect markdown file names for links
    let md_files = ($files | each { |file|
        ($file.name | str replace ".mdx" ".md")
    })

    # Generate skill content
    let skill_content = (generate-skill-content $name $repo_url $version $md_files)
    $skill_content | save -f $skill_file

    print $"✓ Skill generated successfully at '($skill_file)'"
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
