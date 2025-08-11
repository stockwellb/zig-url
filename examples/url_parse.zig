//! Example: URL parsing

const std = @import("std");
const zig_url = @import("zig_url");

// Format strings
const HEADER = "zig-url example: Complex URL parsing\n";
const SEPARATOR = "=" ** 50 ++ "\n";
const URL_LABEL = "Original URL:\n{s}\n\n";
const COMPONENTS_HEADER = "Parsed components:\n";
const SCHEME_FMT = "  Scheme:   {s}\n";
const USER_FMT = "  User:     {s}\n";
const PASSWORD_FMT = "  Password: {s}\n";
const HOST_FMT = "  Host:     {s}\n";
const PORT_FMT = "  Port:     {s}";
const PORT_NUMERIC_FMT = " (numeric: {})";
const PORT_DEFAULT = "  Port:     (default)\n";
const PATH_FMT = "  Path:     {s}\n";
const QUERY_FMT = "  Query:    {s}\n";
const FRAGMENT_FMT = "  Fragment: {s}\n";
const GUESSED_FMT = "  Guessed:  {}\n";
const NEWLINE = "\n";
const FOOTER = "All URL components successfully parsed!\n";

pub fn main() !void {
    std.debug.print(HEADER, .{});
    std.debug.print(SEPARATOR, .{});

    // Complex URL with all supported components
    const complex_url = "ftp://admin:secret123@files.example.com:2121/documents/reports/2024/annual.pdf?type=binary&encoding=utf8&download=true#page-42";

    std.debug.print(URL_LABEL, .{complex_url});

    const url = zig_url.Url.init(complex_url);

    std.debug.print(COMPONENTS_HEADER, .{});
    std.debug.print(SCHEME_FMT, .{url.scheme});

    if (url.user) |user| {
        std.debug.print(USER_FMT, .{user});
    }

    if (url.password) |password| {
        std.debug.print(PASSWORD_FMT, .{password});
    }

    std.debug.print(HOST_FMT, .{url.host});

    if (url.port) |port| {
        std.debug.print(PORT_FMT, .{port});
        if (url.portnum) |portnum| {
            std.debug.print(PORT_NUMERIC_FMT, .{portnum});
        }
        std.debug.print(NEWLINE, .{});
    } else {
        std.debug.print(PORT_DEFAULT, .{});
    }

    std.debug.print(PATH_FMT, .{url.path});

    if (url.query) |query| {
        std.debug.print(QUERY_FMT, .{query});
    }

    if (url.fragment) |fragment| {
        std.debug.print(FRAGMENT_FMT, .{fragment});
    }

    std.debug.print(GUESSED_FMT, .{url.guessed_scheme});

    std.debug.print(NEWLINE ++ SEPARATOR, .{});
    std.debug.print(FOOTER, .{});
}

