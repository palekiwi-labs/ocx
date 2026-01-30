use ./utils.nu [get-current-container-name, container-is-running]
use ../config

export def main [] {
    let cfg = (config load)
    let container_name = (get-current-container-name $cfg)
    
    if not (container-is-running $container_name) {
        error make {
            msg: $"Container '($container_name)' is not running"
            help: $"Start the container first with: ocx opencode"
        }
    }
    
    let user_settings = (config resolve-user $cfg)
    let user = $user_settings.username
    
    let cmd = [
        "docker" "exec" "-it"
        "--user" $user
        $container_name
        "/bin/bash"
    ]
    
    run-external ...$cmd
}
