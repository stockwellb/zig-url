//! Example: Simple HTTP GET request

const std = @import("std");
const zig_url = @import("zig_url");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("zig-url example: Simple GET request\n", .{});

    var client = zig_url.http.Client.init(allocator);

    // This will fail for now since we haven't implemented HTTP yet
    if (client.get("http://httpbin.org/get")) |response| {
        std.debug.print("Response status: {}\n", .{response.status_code});
    } else |err| switch (err) {
        error.NotImplemented => {
            std.debug.print("HTTP GET not yet implemented - this is expected!\n", .{});
            std.debug.print("This example will work once we implement the HTTP client.\n", .{});
        },
        else => return err,
    }
}