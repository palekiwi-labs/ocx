# host_exec module - provides utilities for host command execution

# Get the path to the server binary from environment
export def get-server-binary-path []: nothing -> string {
    let from_env = $env.OCX_SERVER_BIN? | default null
    if $from_env != null { return $from_env }
    "./rust/target/release/host-exec-server"
}

# Get the path to the client binary from environment
export def get-client-binary-path []: nothing -> string {
    let from_env = $env.OCX_CLIENT_BIN? | default null
    if $from_env != null { return $from_env }
    "./rust/target/release/host-exec"
}

# Test the server binary
export def test-server [] {
    let server_bin = get-server-binary-path

    print $"Testing server binary at: ($server_bin)"

    if not ($server_bin | path exists) {
        print $"(ansi red)Error: Server binary not found at ($server_bin)(ansi reset)"
        return 1
    }

    print "Running server binary..."
    ^$server_bin
}

# Test the client binary
export def test-client [...args] {
    let client_bin = get-client-binary-path

    print $"Testing client binary at: ($client_bin)"

    if not ($client_bin | path exists) {
        print $"(ansi red)Error: Client binary not found at ($client_bin)(ansi reset)"
        return 1
    }

    print "Running client binary..."
    if ($args | is-empty) {
        ^$client_bin
    } else {
        ^$client_bin ...$args
    }
}
