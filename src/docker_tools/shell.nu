use ./utils.nu resolve-container-name
use ../config.nu

export def main [] {
    let container_name = resolve-container-name
    
    let running = (docker ps --filter $"name=^($container_name)$" --format "{{.Names}}" 
                   | complete 
                   | get stdout 
                   | str trim)
    
    if ($running | is-empty) {
        error make {
            msg: $"Container '($container_name)' is not running"
            help: $"Start the container first with: ocx run"
        }
    }
    
    let cfg = (config load)
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
