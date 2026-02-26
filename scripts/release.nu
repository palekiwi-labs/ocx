#!/usr/bin/env nu

# Automated release script for OCX
# Updates version, commits, tags, and pushes.

def main [
    --version: string,     # Explicit version to release (e.g. 0.1.0)
    --type: string,        # Version bump type: patch, minor, major, alpha, beta, rc
    --dry-run,             # Show what would be done without executing
    --no-push,             # Don't push changes to remote
    --no-release           # Don't create GitHub release
] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let version_file = ($repo_root | path join "src" "VERSION.txt")
    
    if not ($version_file | path exists) {
        error make {msg: $"Version file not found at ($version_file)"}
    }

    let current_version = (open $version_file | str trim)
    print $"Current version: ($current_version)"

    let next_version = if $version != null {
        $version
    } else {
        calculate-next-version $current_version $type
    }

    print $"Target version:  ($next_version)"

    if not $dry_run {
        check-working-directory
    }

    let tag_name = $"v($next_version)"
    let commit_msg = $"chore: bump version to ($tag_name)"
    let tag_msg = $"Release ($tag_name)"

    if $dry_run {
        print "\n[DRY RUN] Would perform following actions:"
        print $"1. Update ($version_file) to ($next_version)"
        print $"2. git add src/VERSION.txt"
        print $"3. git commit -m '($commit_msg)'"
        if not $no_push {
            print "4. git push origin master"
        }
        print $"5. git tag -a ($tag_name) -m '($tag_msg)'"
        if not $no_push {
            print $"6. git push origin ($tag_name)"
        }
        if not $no_release {
            print $"7. gh release create ($tag_name) --generate-notes"
        }
        return
    }

    # 1. Update version file
    $next_version | save --force $version_file
    print "Updated version file."

    # 2. Git operations
    run-cmd git add src/VERSION.txt
    run-cmd git commit -m $commit_msg

    if not $no_push {
        print "Pushing to master..."
        run-cmd git push origin master
    }

    # 3. Tagging
    print $"Creating tag ($tag_name)..."
    run-cmd git tag -a $tag_name -m $tag_msg

    if not $no_push {
        print $"Pushing tag ($tag_name)..."
        run-cmd git push origin $tag_name
    }

    # 4. GitHub Release
    if not $no_release {
        if (which gh | is-empty) {
            print "gh CLI not found, skipping GitHub release creation."
        } else {
            print "Creating GitHub release..."
            run-cmd gh release create $tag_name --generate-notes
        }
    }

    print $"\nSuccessfully released ($tag_name)!"
}

def calculate-next-version [current: string, type: string] {
    # Simple semver-ish parser
    # Handles: 0.1.0, 0.1.0-alpha.14
    
    let parts = ($current | parse -r '^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(?:-(?P<pre>(?P<pre_type>[a-zA-Z]+)\.(?P<pre_val>\d+)))?$')
    
    if ($parts | is-empty) {
        error make {msg: $"Could not parse current version: ($current)"}
    }
    
    let v = ($parts | first)
    mut major = ($v.major | into int)
    mut minor = ($v.minor | into int)
    mut patch = ($v.patch | into int)
    mut pre_type = $v.pre_type
    mut pre_val = (if ($v.pre_val | is-empty) { 0 } else { $v.pre_val | into int })

    match $type {
        "major" => {
            $major += 1
            $minor = 0
            $patch = 0
            $pre_type = ""
        }
        "minor" => {
            $minor += 1
            $patch = 0
            $pre_type = ""
        }
        "patch" => {
            if ($pre_type | is-empty) {
                $patch += 1
            } else {
                # If we are in pre-release, 'patch' just removes the pre-release suffix
                $pre_type = ""
            }
        }
        "alpha" | "beta" | "rc" => {
            if $pre_type == $type {
                $pre_val += 1
            } else {
                if ($pre_type | is-empty) {
                    $patch += 1
                }
                $pre_type = $type
                $pre_val = 1
            }
        }
        _ => {
            # Default behavior: increment pre-release value if exists, else increment patch
            if ($pre_type | is-not-empty) {
                $pre_val += 1
            } else {
                $patch += 1
            }
        }
    }

    let base = $"($major).($minor).($patch)"
    if ($pre_type | is-not-empty) {
        $"($base)-($pre_type).($pre_val)"
    } else {
        $base
    }
}

def check-working-directory [] {
    let status = (git status --porcelain | str trim)
    if ($status | is-not-empty) {
        error make {
            msg: "Working directory is not clean. Please commit or stash changes first."
        }
    }

    let branch = (git branch --show-current | str trim)
    if $branch != "master" {
        print $"Warning: You are on branch '($branch)', not 'master'."
        let confirm = (input "Continue anyway? [y/N] ")
        if ($confirm | str downcase) != "y" {
            error make {msg: "Release cancelled."}
        }
    }
}

def --wrapped run-cmd [...args] {
    let result = (run-external ...$args | complete)
    if $result.exit_code != 0 {
        print $result.stderr
        error make {msg: $"Command failed: ($args | str join ' ')"}
    }
}
