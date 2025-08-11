//! Simple test executable for the zig-url library
//! This file is mainly for basic testing during development

const std = @import("std");
const zig_url = @import("zig_url");

pub fn main() !void {
    std.debug.print("zig-url library v{s}\n", .{zig_url.version});
    std.debug.print("Run examples in the examples/ directory for usage demonstrations.\n");
}

test "library version" {
    try std.testing.expectEqualStrings("0.1.0", zig_url.version);
}
