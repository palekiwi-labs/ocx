# Port generation utilities

# Generate deterministic port from current directory path
# Returns a port number in the range 32768-65535
export def generate [] {
    let path_hash = $env.PWD
    
    let hash = ($path_hash | cksum | split row ' ' | first | into int)
    
    # Map to port range 32768-65535
    32768 + ($hash mod 32768)
}
