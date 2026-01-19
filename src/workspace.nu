# Workspace path calculations and validation

use ./config

# Get workspace configuration from OCX_WORKSPACE environment variable
export def get-workspace [] {
    # Check if OCX_WORKSPACE is set
    let workspace_env = $env.OCX_WORKSPACE? | default ""
    
    let workspace = if ($workspace_env | is-empty) {
        pwd
    } else {
        $workspace_env
    }
    
    # Validate and expand the path
    let workspace = $workspace | path expand
    
    if not ($workspace | path exists) {
        error make {
            msg: $"Error: OCX_WORKSPACE '($workspace)' does not exist"
        }
    }
    
    if ($workspace | path type) != "dir" {
        error make {
            msg: $"Error: OCX_WORKSPACE '($workspace)' is not a directory"
        }
    }
    
    # Get username for path calculation
    let cfg = (config load)
    let user_settings = (config resolve-user $cfg)
    
    # Compute container path
    let container_path = (calculate-container-path $workspace $user_settings.username)
    let home = ($env.HOME | path expand)
    
    {
        host_path: $workspace
        container_path: $container_path
    }
}

# Calculate container path based on host path
# If under $HOME, preserve structure under /home/<username>
# Otherwise mount under /workspace
def calculate-container-path [path: string, username: string] {
    let home = ($env.HOME | path expand)
    
    if ($path | str starts-with $home) {
        # Path under $HOME, preserve structure
        let relative = ($path | str substring ($home | str length)..)
        # Remove leading slash if present
        let relative_clean = if ($relative | str starts-with "/") {
            $relative | str substring 1..
        } else {
            $relative
        }
        $"/home/($username)/($relative_clean)"
    } else {
        # Path outside $HOME, mount under /workspace
        let relative = ($path | str trim --left --char "/")
        $"/workspace/($relative)"
    }
}
