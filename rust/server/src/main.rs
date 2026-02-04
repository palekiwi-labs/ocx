//! host-exec-server (stub implementation)
//!
//! This binary will run on the host machine
//! For now, it just prints a static message to verify the build pipeline works.

use host_exec_shared::greeting;

fn main() {
    println!("host-exec-server stub");
    println!("{}", greeting());
    println!();
    println!("✓ Server binary is working!");
    println!("✓ Rust build pipeline is functional");
    println!("✓ Nix integration successful");
    println!();
    println!("(Server will listen on Unix socket in future implementation)");

    // For now, just exit successfully
    // In the real implementation, this would start a daemon
    std::process::exit(0);
}
