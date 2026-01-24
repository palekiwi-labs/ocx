# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

# Error handling utility for OCX
#
# This module provides clean, user-friendly error output by extracting
# error messages and help text from Nushell errors and presenting them
# without implementation details like stack traces and line numbers.
#
# Usage:
#   use errors
#
#   try {
#       some-command-that-may-fail
#   } catch { |err|
#       errors pretty-print $err
#   }

# Pretty-print an error message and exit
#
# Extracts the error message and help text from a Nushell error record
# and prints them to stderr in a clean, user-friendly format without
# stack traces or implementation details, then exits with code 1.
#
# Error output format:
#   Error: <error message>
#   <help text if available>
#
# Note: All Nushell errors caught in a catch block have a standardized structure:
#   - error.json: JSON string representation (always present)
#   - Parsed JSON has: msg, help, labels, code, url, inner (all always present)
#   - help field may be null if not provided in error make
export def pretty-print [error: record] {
    let error_data = $error.json | from json

    let msg = $error_data.msg

    print -e $"Error: ($msg)"

    # Print help text if provided (help field is always present but may be null)
    if $error_data.help != null {
        print -e $error_data.help
    }

    exit 1
}
