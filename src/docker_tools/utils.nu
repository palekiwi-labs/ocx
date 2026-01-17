use ../config.nu

export def image_exists [name: string] {
    (docker image inspect $name | complete).exit_code == 0
}

export def resolve-container-name [] {
    let cfg = (config load)
    
    if $cfg.container_name != null {
        $cfg.container_name
    } else {
        let parent = ($env.PWD | path dirname | path basename)
        let base = ($env.PWD | path basename)
        $"ocx-($parent)-($base)"
    }
}
