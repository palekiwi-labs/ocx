use ../config.nu

export def image_exists [name: string] {
    (docker image inspect $name | complete).exit_code == 0
}

export def resolve-container-name [port: int] {
    let cfg = (config load)
    
    if $cfg.container_name != null {
        $"($cfg.container_name)-($port)"
    } else {
        let base = ($env.PWD | path basename)
        $"ocx-($base)-($port)"
    }
}
