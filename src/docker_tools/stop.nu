use ./utils.nu [get-current-container-name, container-is-running]
use ../config

export def main [] {
    let cfg = (config load)
    let container_name = (get-current-container-name $cfg)
    
    if not (container-is-running $container_name) {
        print $"Container '($container_name)' is not running."
        return
    }
    
    print $"Stopping container ($container_name)..."
    docker stop $container_name
}
