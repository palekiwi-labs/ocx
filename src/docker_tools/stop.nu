use ./utils.nu [get-current-container-name, container-is-running]

export def main [] {
    let container_name = (get-current-container-name)
    
    if not (container-is-running $container_name) {
        print $"Container '($container_name)' is not running."
        return
    }
    
    print $"Stopping container ($container_name)..."
    docker stop $container_name
}
