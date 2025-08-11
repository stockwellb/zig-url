//! HTTP client implementation

const std = @import("std");
const url_mod = @import("url.zig");

pub const Response = struct {
    status_code: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
        self.headers.deinit();
    }
};

pub const Client = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Client {
        return Client{
            .allocator = allocator,
        };
    }

    pub fn get(self: *Client, url_str: []const u8) !Response {
        _ = self;
        _ = url_str;
        // TODO: Implement actual HTTP GET request
        return error.NotImplemented;
    }
};

test "client initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const client = Client.init(allocator);
    _ = client;
}