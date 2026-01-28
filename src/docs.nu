# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

use config
use version
use errors

const GITHUB_API_BASE = "https://api.github.com/repos/anomalyco/opencode/contents/packages/web/src/content/docs"

export def main [
    --dir: string,      # Output directory (base)
    --version: string, # Optional version override
    --force,     # Overwrite existing files
] {
    # 1. Resolve Version
    let cfg = (config load)
    let version_to_fetch = if $version != null {
        $version
    } else {
        $cfg.opencode_version
    }

    let resolved_version = (version resolve-version $version_to_fetch)

    # 2. Construct Path
    let output_path = ([$dir "opencode" $resolved_version] | path join)

    # 3. Safety Checks
    if ($output_path | path exists) {
        if not ($force | default false) {
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

    # 4. Fetch & Download Loop
    let api_url = $"($GITHUB_API_BASE)?ref=v($resolved_version)"
    print $"Fetching file list from GitHub API for version ($resolved_version)..."

    let dir_contents = try {
        http get $api_url
    } catch { |err|
        errors pretty-print $err
        return
    }


    let mdx_files = ($dir_contents | where type == "file" and name =~ '\.mdx$')

    print $"Found ($mdx_files | length) .mdx files to download"

    for $file in $mdx_files {
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
