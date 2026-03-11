# Centralized path resolution for extra_data_volumes
# Handles expansion of ~ and ./ for both host sources and container targets.

export def resolve-extra-volumes [cfg: record, username: string, workspace: record] {
    if $cfg.extra_data_volumes == null {
        return []
    }

    $cfg.extra_data_volumes | columns | each {|key|
        let vol_config = ($cfg.extra_data_volumes | get $key)
        let vol_type = ($vol_config.type? | default "volume")
        let target = $vol_config.target

        # Expand target (container-side)
        let resolved_target = if $target == "~" {
            $"/home/($username)"
        } else if ($target | str starts-with "~/") {
            $"/home/($username)/($target | str substring 2..)"
        } else if $target == "." {
            $workspace.container_path
        } else if ($target | str starts-with "./") {
            let relative = ($target | str substring 2..)
            if ($relative | is-empty) {
                $workspace.container_path
            } else {
                $workspace.container_path | path join $relative
            }
        } else {
            $target
        }

        # Expand source (host-side)
        # Bind mounts: Resolve ~ and relative paths relative to current directory
        # Volumes: Keep as-is (named volumes)
        let source = $vol_config.source?
        let resolved_source = if $vol_type == "bind" and $source != null {
            $source | path expand
        } else {
            $source
        }

        {
            key: $key,
            source: $resolved_source,
            target: $resolved_target,
            mode: ($vol_config.mode? | default "rw"),
            type: $vol_type
        }
    }
}
