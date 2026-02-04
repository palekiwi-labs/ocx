//! host-exec client (stub implementation)
//!
//! This binary will be installed in the container at /usr/local/bin/host-exec
//! For now, it just prints a static message to verify the build pipeline works.

use host_exec_shared::greeting;

fn main() {
    println!("host-exec client stub");
    println!("{}", greeting());
    println!();
    println!("Command: {:?}", std::env::args().collect::<Vec<_>>());
    println!();
    println!("✓ Client binary is working!");
    println!("✓ Rust build pipeline is functional");
    println!("✓ Nix integration successful");

    // Exit with success
    std::process::exit(0);
}
