//! zig-url: A HTTP client library for Zig
//! This is the main entry point for the zig-url library.

const std = @import("std");

// Re-export main types at top level for convenience
pub const Url = @import("url.zig").Url;

// Re-export modules for advanced usage
pub const http = @import("http.zig");
pub const url = @import("url.zig");

// Version information
pub const version = "0.1.0";

test "library imports" {
    std.testing.refAllDecls(@This());
}
