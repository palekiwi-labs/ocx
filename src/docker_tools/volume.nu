use ../config
use ../volume_name.nu

export def main [] {
    let cfg = (config load)
    let volume_base = (volume_name resolve-volume-base-name $cfg)
    
    if $volume_base == null {
        print "No data volumes configured for this project."
        print $"Current mode: ($cfg.data_volumes_mode)"
        return
    }
    
    print $"Data volume base name: ($volume_base)"
    print ""
    
    # List volumes matching this base name
    docker volume ls --filter $"name=^($volume_base)-"
}
