use ./utils.nu [get-current-container-name, container-is-running]
use ../config

export def --wrapped main [...args] {
    let container_name = (get-current-container-name)
    
    if not (container-is-running $container_name) {
        error make {
            msg: $"Container '($container_name)' is not running"
            help: "Start the container first with: ocx opencode"
        }
    }
    
    let cfg = (config load)
    let user_settings = (config resolve-user $cfg)
    let user = $user_settings.username

    # Default to interactive if no args, otherwise pass args
    # But exec usually requires a command. 
    # If no args provided, maybe default to bash like shell? 
    # The spec says "execute a command".
    
    if ($args | is-empty) {
         error make {
            msg: "No command specified"
            help: "Usage: ocx exec <command> [args...]"
        }
    }

    let cmd = [
        "docker" "exec" "-it"
        "--user" $user
        $container_name
        ...$args
    ]
    
    run-external ...$cmd
}
