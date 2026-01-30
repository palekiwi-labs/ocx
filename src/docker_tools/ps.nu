use ./utils.nu [get-current-container-name]
use ../config

export def main [
    --all(-a)
] {
    let cfg = (config load)
    if $all {
        docker ps --filter "name=^ocx-"
    } else {
        let name = (get-current-container-name $cfg)
        docker ps --filter $"name=^($name)$"
    }
}
