export const DEFAULTS = {
    # Resource limits
    memory: "1024m"
    cpus: 1.0
    pids_limit: 100
    
    # Networking
    network: "bridge"
    publish_port: true
    port: null  # auto-generate if null
    
    # Container settings
    container_name: null  # auto-generate if null
    
    # OpenCode version
    opencode_version: "latest"  # "latest" or specific version like "1.1.23"
    
    # User settings
    username: null  # auto-detect from $env.USER if null
    uid: null       # auto-detect from `id -u` if null
    gid: null       # auto-detect from `id -g` if null
    
    # Paths
    config_dir: "~/.config/opencode"  # OpenCode container config dir (mounted into container)
    rgignore_file: null  # optional
    
    # Security
    forbidden_paths: []  # array of relative paths to shadow-mount
    
    # Environment
    timezone: null  # use $env.TZ if null
    tmp_size: "500m"
    workspace_tmp_size: "500m"
    
    # Custom base image
    custom_base_dockerfile: null  # e.g., "ruby/Dockerfile" - path to custom base Dockerfile
}
