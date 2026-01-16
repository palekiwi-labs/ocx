# Workspace path calculations and validation

# Get workspace configuration from OCX_WORKSPACE environment variable
export def get [] {
    # Check if OCX_WORKSPACE is set
    let workspace_env = $env.OCX_WORKSPACE? | default ""
    
    if ($workspace_env | is-empty) {
        error make {
            msg: "Error: OCX_WORKSPACE environment variable is required"
            help: "Set it to the directory you want to mount as the workspace"
        }
    }
    
    # Validate and expand the path
    let workspace = $workspace_env | path expand
    
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
    
    # Compute container path
    let container_path = (calculate-container-path $workspace)
    let home = ($env.HOME | path expand)
    
    {
        host_path: $workspace
        container_path: $container_path
    }
}

# Calculate container path based on host path
# If under $HOME, preserve structure under /home/user
# Otherwise mount under /workspace
def calculate-container-path [path: string] {
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
        $"/home/user/($relative_clean)"
    } else {
        # Path outside $HOME, mount under /workspace
        let relative = ($path | str trim --left --char "/")
        $"/workspace/($relative)"
    }
}
