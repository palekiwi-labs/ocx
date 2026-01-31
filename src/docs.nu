# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

use config
use version
use errors.nu

# OpenCode Docs Config
const OPENCODE_OWNER = "anomalyco"
const OPENCODE_REPO = "opencode"
const OPENCODE_DOCS_PATH = "packages/web/src/content/docs"
const OPENCODE_REPO_URL = $"https://github.com/($OPENCODE_OWNER)/($OPENCODE_REPO)"

# OCX Docs Config
const OCX_OWNER = "palekiwi-labs"
const OCX_REPO = "ocx"
const OCX_DOCS_PATH = "docs"
const OCX_REPO_URL = $"https://github.com/($OCX_OWNER)/($OCX_REPO)"

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

    let owner = if $ocx { $OCX_OWNER } else { $OPENCODE_OWNER }
    let repo = if $ocx { $OCX_REPO } else { $OPENCODE_REPO }
    let docs_path = if $ocx { $OCX_DOCS_PATH } else { $OPENCODE_DOCS_PATH }
    let repo_url = if $ocx { $OCX_REPO_URL } else { $OPENCODE_REPO_URL }
    let repo_name = if $ocx { "ocx" } else { "opencode" }

    let output_path = if $skill {
        let opencode_config_dir = ($cfg.opencode_config_dir | path expand)
        let base_path = if $project { "./opencode" } else { $opencode_config_dir }
        $"($base_path)/skills/($repo_name)-documentation"
    } else {
        $"($dir)/($repo_name)"
    }

    let files = list_remote_docs $owner $repo $docs_path $version

    fetch_files $output_path $version $files --force=$force

    if $skill {
        generate_skill $repo_name $output_path $files $version $repo_url
    }
}

def list_remote_docs [owner: string, repo: string, docs_path: string, version: string] {
    print $"Fetching file list from GitHub API for version ($version)..."
    let ref = if ($version | str starts-with "v") {
        $version
    } else if (version validate-semver $version) {
        $"v($version)"
    } else {
        $version # Branch or SHA
    }

    let tree_url = $"https://api.github.com/repos/($owner)/($repo)/git/trees/($ref)?recursive=1"

    try {
        let response = http get $tree_url

        let files = ($response.tree
            | where type == "blob"
            | where path starts-with $docs_path
            | each { |file|
                let relative_path = ($file.path | str substring (($docs_path | str length) + 1)..)
                {
                    path: $relative_path,
                    download_url: $"https://raw.githubusercontent.com/($owner)/($repo)/($ref)/($file.path)"
                }
            })

        $files
    } catch { |err|
        error make {
            msg: $"Cannot find documentation tree for version ($version) at ($tree_url)"
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

    let failures = ($files | par-each { |file|
        let output_file = ([$output_path $file.path] | path join)
        let output_dir = ($output_file | path dirname)

        try {
            # Ensure the parent directory exists
            mkdir $output_dir

            let content = http get $file.download_url
            $content | save $output_file
            null
        } catch {
            {file: $file.path, url: $file.download_url}
        }
    } | compact)

    if ($failures | length) > 0 {
        print $"✗ Failed to fetch ($failures | length) files:"
        for $fail in $failures {
            print $"  - ($fail.file)"
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

    let md_files = ($files | each { |file|
        ($file.path | str replace ".mdx" ".md")
    })

    let skill_content = (generate_skill_content $name $repo_url $version $md_files)
    $skill_content | save -f $skill_file

    print $"✓ Skill generated successfully at '($skill_file)'"
}

def generate_skill_content [
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

## Documentation pages for version ($version):

($files | each { |name|
    $"[($name)]\(./($version)/($name)\)"
} | str join "\n")

## Source

Repository: [($repo_url)]\(($repo_url)\)
"
}
