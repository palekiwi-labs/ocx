use ./utils.nu [get-current-container-name]

export def main [] {
    let name = (get-current-container-name)
    docker volume ls --filter $"name=^($name)-"
}
