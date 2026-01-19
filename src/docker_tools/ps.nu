use ./utils.nu [get-current-container-name]

export def main [
    --all(-a)
] {
    if $all {
        docker ps --filter "name=^ocx-"
    } else {
        let name = (get-current-container-name)
        docker ps --filter $"name=^($name)$"
    }
}
