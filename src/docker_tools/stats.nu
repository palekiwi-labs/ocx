use ./utils.nu [get-current-container-name]

export def main [--all] {
    if $all {
        # Stat all ocx containers
        # Using grep to filter for names starting with ocx- is a bit fragile but docker stats doesn't support regex filters nicely for names
        # Better approach: Get list of running containers matching filter, then pass to stats
        
        let containers = (docker ps --filter "name=^ocx-" --format "{{.Names}}" 
                         | lines 
                         | where ($it | str starts-with "ocx-"))
        
        if ($containers | is-empty) {
            print "No running OCX containers found."
            return
        }
        
        docker stats ...$containers
    } else {
        let name = (get-current-container-name)
        docker stats $name
    }
}
