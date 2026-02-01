//! Shared types and utilities for host-exec client and server
//!
//! This is a stub implementation for testing the build pipeline.

/// Version constant for the host-exec system
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Simple greeting function for testing
pub fn greeting() -> String {
    format!("host-exec shared library v{}", VERSION)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_exists() {
        assert!(!VERSION.is_empty());
    }

    #[test]
    fn test_greeting() {
        let msg = greeting();
        assert!(msg.contains("host-exec"));
        assert!(msg.contains(VERSION));
    }
}
