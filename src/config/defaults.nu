export const DEFAULTS = {
    # Container Identity & Version
    opencode_version: "latest"  # "latest" or specific version like "1.1.23"
    container_name: null  # auto-generate if null
    
    # Resource Limits
    memory: "1024m"
    cpus: 1.0
    pids_limit: 100
    tmp_size: "500m"
    workspace_tmp_size: "500m"
    
    # Networking
    network: "bridge"
    port: null  # auto-generate if null
    publish_port: true
    add_host_docker_internal: true  # add --add-host=host.docker.internal:host-gateway
    
    # User Settings
    username: null  # auto-detect from $env.USER if null
    uid: null       # auto-detect from `id -u` if null
    gid: null       # auto-detect from `id -g` if null
    
    # Paths & Files
    opencode_config_dir: "~/.config/opencode"  # OpenCode container config dir (mounted into container)
    rgignore_file: null  # optional
    custom_base_dockerfile: null  # e.g., "ruby/Dockerfile" - path to custom base Dockerfile
    env_file: null # e.g. "ocx.env" - if null defaults to ocx.env
    
    # Data Volumes
    data_volumes_mode: "git"  # "always" | "git" | "never" - controls when to create data volumes
    data_volumes_name: null   # optional: explicit volume name override (shares across all projects if set)
    
    # Security
    read_only: false  # mount container root filesystem as read-only (set true for strict security)
    forbidden_paths: []  # array of relative paths to shadow-mount
    
    # Environment
    timezone: null  # use $env.TZ if null
}
