# Shadow mount generation for forbidden paths

# Generate Docker arguments to shadow-mount forbidden paths
# Prevents access to specified paths by mounting tmpfs for directories
# or /dev/null for files
export def generate [
    forbidden_paths: list<string>
    workspace_host_path: string
    workspace_container_path: string
]: nothing -> list<string> {
    mut args = []
    
    for path in $forbidden_paths {
        let full_path = ($workspace_host_path | path join $path)
        let container_forbidden_path = ($workspace_container_path | path join $path)
        
        if ($full_path | path exists) {
            if ($full_path | path type) == "dir" {
                $args = ($args | append [
                    "--tmpfs" $"($container_forbidden_path):ro,noexec,nosuid,size=1k,mode=000"
                ])
            } else {
                $args = ($args | append [
                    "-v" $"/dev/null:($container_forbidden_path):ro"
                ])
            }
        }
    }
    
    $args
}
