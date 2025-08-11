//! URL parsing and manipulation utilities

const std = @import("std");

const default_scheme = "https";
const max_scheme_length = 40;

pub const SchemeResult = struct {
    scheme: ?[]const u8,
    rest: []const u8,
    guessed: bool,
};

pub const HostResult = struct {
    host: ?[]const u8,
    port: ?[]const u8,
    rest: []const u8,
};

pub const PathResult = struct {
    path: ?[]const u8,
    rest: []const u8,
};

pub const QueryResult = struct {
    query: ?[]const u8,
    rest: []const u8,
};

pub const FragmentResult = struct {
    fragment: ?[]const u8,
    rest: []const u8,
};

pub const UserInfoResult = struct {
    user: ?[]const u8,
    password: ?[]const u8,
    rest: []const u8,
};

pub const Url = struct {
    scheme: []const u8,
    user: ?[]const u8,
    password: ?[]const u8,
    options: []const u8,
    host: []const u8,
    zoneid: ?[]const u8,
    port: ?[]const u8,
    portnum: ?u16,
    path: []const u8,
    query: ?[]const u8,
    fragment: ?[]const u8,
    guessed_scheme: bool,

    pub fn init(url_str: []const u8) Url {
        
        // Parse URL components in sequence
        const scheme_result = parseScheme(url_str);
        
        // Check for user info before host
        const userinfo_result = parseUserInfo(scheme_result.rest);
        
        // Parse host and port using the rest after userinfo
        const host_result = parseHostWithUserInfo(userinfo_result);
        
        // Parse path
        const path_result = parsePath(host_result);
        
        // Parse query
        const query_result = parseQuery(path_result);
        
        // Parse fragment
        const fragment_result = parseFragment(query_result);
        
        // Convert port string to number if present
        var portnum: ?u16 = null;
        if (host_result.port) |port_str| {
            portnum = std.fmt.parseInt(u16, port_str, 10) catch null;
        }
        
        return Url{
            .scheme = scheme_result.scheme orelse default_scheme,
            .user = userinfo_result.user,
            .password = userinfo_result.password,
            .options = "", // TODO: IMAP specific, handle later
            .host = host_result.host orelse "",
            .zoneid = null, // TODO: IPv6 zone ID support
            .port = host_result.port,
            .portnum = portnum,
            .path = path_result.path orelse "/",
            .query = query_result.query,
            .fragment = fragment_result.fragment,
            .guessed_scheme = scheme_result.guessed,
        };
    }


    pub fn toString(self: *const Url, allocator: std.mem.Allocator) ![]u8 {
        // Calculate required buffer size
        var size: usize = 0;
        
        // Scheme + ://
        size += self.scheme.len + 3;
        
        // User info
        if (self.user) |user| {
            size += user.len;
            if (self.password) |password| {
                size += 1 + password.len; // :password
            }
            size += 1; // @
        }
        
        // Host
        size += self.host.len;
        
        // Port
        if (self.port) |port| {
            size += 1 + port.len; // :port
        }
        
        // Path
        size += self.path.len;
        
        // Query
        if (self.query) |query| {
            size += query.len;
        }
        
        // Fragment  
        if (self.fragment) |fragment| {
            size += fragment.len;
        }
        
        // Allocate buffer
        const buffer = try allocator.alloc(u8, size);
        var pos: usize = 0;
        
        // Build URL string
        // Scheme
        @memcpy(buffer[pos..pos + self.scheme.len], self.scheme);
        pos += self.scheme.len;
        @memcpy(buffer[pos..pos + 3], "://");
        pos += 3;
        
        // User info
        if (self.user) |user| {
            @memcpy(buffer[pos..pos + user.len], user);
            pos += user.len;
            
            if (self.password) |password| {
                buffer[pos] = ':';
                pos += 1;
                @memcpy(buffer[pos..pos + password.len], password);
                pos += password.len;
            }
            
            buffer[pos] = '@';
            pos += 1;
        }
        
        // Host
        @memcpy(buffer[pos..pos + self.host.len], self.host);
        pos += self.host.len;
        
        // Port
        if (self.port) |port| {
            buffer[pos] = ':';
            pos += 1;
            @memcpy(buffer[pos..pos + port.len], port);
            pos += port.len;
        }
        
        // Path
        @memcpy(buffer[pos..pos + self.path.len], self.path);
        pos += self.path.len;
        
        // Query
        if (self.query) |query| {
            @memcpy(buffer[pos..pos + query.len], query);
            pos += query.len;
        }
        
        // Fragment
        if (self.fragment) |fragment| {
            @memcpy(buffer[pos..pos + fragment.len], fragment);
            pos += fragment.len;
        }
        
        return buffer[0..pos];
    }
};

fn parseScheme(url: []const u8) SchemeResult {
    if (std.mem.indexOf(u8, url, "://")) |idx| {
        const scheme = url[0..idx];
        return .{
            .scheme = scheme,
            .rest = url[idx + 3 ..],
            .guessed = false,
        };
    } else {
        // No scheme found, assume default scheme
        return .{
            .scheme = default_scheme,
            .rest = url,
            .guessed = true,
        };
    }
}

fn parseHost(result: SchemeResult) HostResult {
    // This is the simplified version for tests that don't handle userinfo
    const url = result.rest;
    
    // Find where host:port section ends (/, ?, #, or end of string)
    const end = std.mem.indexOfAny(u8, url, "/?#") orelse url.len;

    // Empty host case
    if (end == 0) {
        return .{
            .host = null,
            .port = null,
            .rest = url,
        };
    }

    const host_port = url[0..end];

    // Check for port separator
    if (std.mem.lastIndexOf(u8, host_port, ":")) |colon| {
        // TODO: Handle IPv6 addresses like [::1]:8080
        return .{
            .host = host_port[0..colon],
            .port = host_port[colon + 1 ..],
            .rest = url[end..],
        };
    }

    return .{
        .host = host_port,
        .port = null,
        .rest = url[end..],
    };
}

fn parseHostWithUserInfo(result: UserInfoResult) HostResult {
    // Parse host from the rest after userinfo extraction
    const url = result.rest;
    
    // Find where host:port section ends (/, ?, #, or end of string)
    const end = std.mem.indexOfAny(u8, url, "/?#") orelse url.len;

    // Empty host case
    if (end == 0) {
        return .{
            .host = null,
            .port = null,
            .rest = url,
        };
    }

    const host_port = url[0..end];

    // Check for port separator
    if (std.mem.lastIndexOf(u8, host_port, ":")) |colon| {
        // TODO: Handle IPv6 addresses like [::1]:8080
        return .{
            .host = host_port[0..colon],
            .port = host_port[colon + 1 ..],
            .rest = url[end..],
        };
    }

    return .{
        .host = host_port,
        .port = null,
        .rest = url[end..],
    };
}

fn parsePath(result: HostResult) PathResult {
    // Find where the path starts (/, ?, #, or end of string)
    const url = result.rest;
    const start = if (std.mem.indexOf(u8, url, "/")) |idx| idx else 0;
    const end = std.mem.indexOfAny(u8, url[start..], "?#") orelse url[start..].len;

    // If no path is found, return empty path
    if (end == start) {
        return .{
            .path = null,
            .rest = url[start..],
        };
    }

    return .{
        .path = url[start .. start + end],
        .rest = url[start + end ..],
    };
}

fn parseQuery(result: PathResult) QueryResult {
    const url = result.rest;
    
    // Check if query exists
    if (std.mem.indexOf(u8, url, "?")) |idx| {
        // Find where query ends (at # or end of string)
        const end = std.mem.indexOf(u8, url[idx..], "#") orelse url[idx..].len;
        
        return .{
            .query = url[idx..idx + end],
            .rest = url[idx + end..],
        };
    }
    
    // No query found
    return .{
        .query = null,
        .rest = url,
    };
}

fn parseFragment(result: QueryResult) FragmentResult {
    const url = result.rest;
    
    // Check if fragment exists
    if (std.mem.indexOf(u8, url, "#")) |idx| {
        return .{
            .fragment = url[idx..],
            .rest = url[url.len..], // Fragment is always last, so rest is empty
        };
    }
    
    // No fragment found
    return .{
        .fragment = null,
        .rest = url,
    };
}

fn parseUserInfo(url: []const u8) UserInfoResult {
    // User info appears before @ in the host section
    // Format: scheme://user:password@host/path
    
    // Look for @ to determine if userinfo exists
    if (std.mem.indexOf(u8, url, "@")) |at_idx| {
        // Check this @ comes before any path indicators
        const path_start = std.mem.indexOfAny(u8, url, "/?#") orelse url.len;
        
        if (at_idx < path_start) {
            const userinfo = url[0..at_idx];
            
            // Split user and password on :
            if (std.mem.indexOf(u8, userinfo, ":")) |colon| {
                return .{
                    .user = userinfo[0..colon],
                    .password = userinfo[colon + 1..],
                    .rest = url[at_idx + 1..],
                };
            }
            
            // No password, just user
            return .{
                .user = userinfo,
                .password = null,
                .rest = url[at_idx + 1..],
            };
        }
    }
    
    // No user info found
    return .{
        .user = null,
        .password = null,
        .rest = url,
    };
}

fn findHostSep(url: []const u8) ?usize {
    // Find the first occurrence of a host separator
    const start = if (std.mem.indexOf(u8, url, "//")) |idx|
        // If '//' is found, start after it
        idx + 2
    else
        0;
    const end_offset = std.mem.indexOfAny(u8, url[start..], "/?") orelse url[start..].len;
    return start + end_offset;
}

test "parseScheme with explicit schemes" {
    // HTTP scheme
    const http_result = parseScheme("http://example.com");
    try std.testing.expectEqualStrings("http", http_result.scheme.?);
    try std.testing.expectEqualStrings("example.com", http_result.rest);
    try std.testing.expect(http_result.guessed == false);

    // HTTPS scheme
    const https_result = parseScheme("https://secure.example.com/path");
    try std.testing.expectEqualStrings("https", https_result.scheme.?);
    try std.testing.expectEqualStrings("secure.example.com/path", https_result.rest);
    try std.testing.expect(https_result.guessed == false);

    // FTP scheme
    const ftp_result = parseScheme("ftp://files.example.com");
    try std.testing.expectEqualStrings("ftp", ftp_result.scheme.?);
    try std.testing.expectEqualStrings("files.example.com", ftp_result.rest);
    try std.testing.expect(ftp_result.guessed == false);
}

test "parseScheme without scheme" {
    // No scheme - should guess default
    const no_scheme = parseScheme("example.com/path");
    try std.testing.expectEqualStrings(default_scheme, no_scheme.scheme.?);
    try std.testing.expectEqualStrings("example.com/path", no_scheme.rest);
    try std.testing.expect(no_scheme.guessed == true);

    // Just domain
    const domain_only = parseScheme("www.example.com");
    try std.testing.expectEqualStrings(default_scheme, domain_only.scheme.?);
    try std.testing.expectEqualStrings("www.example.com", domain_only.rest);
    try std.testing.expect(domain_only.guessed == true);
}

test "parseScheme edge cases" {
    // Empty string
    const empty = parseScheme("");
    try std.testing.expectEqualStrings(default_scheme, empty.scheme.?);
    try std.testing.expectEqualStrings("", empty.rest);
    try std.testing.expect(empty.guessed == true);

    // Only path
    const path_only = parseScheme("/path/to/resource");
    try std.testing.expectEqualStrings(default_scheme, path_only.scheme.?);
    try std.testing.expectEqualStrings("/path/to/resource", path_only.rest);
    try std.testing.expect(path_only.guessed == true);

    // Unusual but valid schemes
    const git_scheme = parseScheme("git+ssh://github.com/user/repo");
    try std.testing.expectEqualStrings("git+ssh", git_scheme.scheme.?);
    try std.testing.expectEqualStrings("github.com/user/repo", git_scheme.rest);
    try std.testing.expect(git_scheme.guessed == false);

    // File scheme
    const file_scheme = parseScheme("file:///home/user/document.txt");
    try std.testing.expectEqualStrings("file", file_scheme.scheme.?);
    try std.testing.expectEqualStrings("/home/user/document.txt", file_scheme.rest);
    try std.testing.expect(file_scheme.guessed == false);
}

test "findHostSep with scheme" {
    try std.testing.expectEqual(@as(?usize, 18), findHostSep("http://example.com/path"));
    try std.testing.expectEqual(@as(?usize, 18), findHostSep("http://example.com?query"));
}

test "findHostSep without scheme" {
    try std.testing.expectEqual(@as(?usize, 11), findHostSep("example.com/path"));
    try std.testing.expectEqual(@as(?usize, 11), findHostSep("example.com?query"));
}

test "findHostSep edge cases" {
    try std.testing.expectEqual(@as(?usize, 0), findHostSep(""));
    try std.testing.expectEqual(@as(?usize, 11), findHostSep("example.com"));
    try std.testing.expectEqual(@as(?usize, 10), findHostSep("//host.com/path"));
}

test "parseHost basic functionality" {
    // Simple host
    const scheme1 = SchemeResult{ .scheme = "http", .rest = "example.com/path", .guessed = false };
    const result1 = parseHost(scheme1);
    try std.testing.expectEqualStrings("example.com", result1.host.?);
    try std.testing.expect(result1.port == null);
    try std.testing.expectEqualStrings("/path", result1.rest);

    // Host with port
    const scheme2 = SchemeResult{ .scheme = "http", .rest = "example.com:8080/path", .guessed = false };
    const result2 = parseHost(scheme2);
    try std.testing.expectEqualStrings("example.com", result2.host.?);
    try std.testing.expectEqualStrings("8080", result2.port.?);
    try std.testing.expectEqualStrings("/path", result2.rest);

    // Host only, no path
    const scheme3 = SchemeResult{ .scheme = "http", .rest = "example.com", .guessed = false };
    const result3 = parseHost(scheme3);
    try std.testing.expectEqualStrings("example.com", result3.host.?);
    try std.testing.expect(result3.port == null);
    try std.testing.expectEqualStrings("", result3.rest);
}

test "parseHost with query and fragment" {
    // Host with query
    const scheme1 = SchemeResult{ .scheme = "http", .rest = "example.com?query=value", .guessed = false };
    const result1 = parseHost(scheme1);
    try std.testing.expectEqualStrings("example.com", result1.host.?);
    try std.testing.expect(result1.port == null);
    try std.testing.expectEqualStrings("?query=value", result1.rest);

    // Host with fragment
    const scheme2 = SchemeResult{ .scheme = "http", .rest = "example.com#section", .guessed = false };
    const result2 = parseHost(scheme2);
    try std.testing.expectEqualStrings("example.com", result2.host.?);
    try std.testing.expect(result2.port == null);
    try std.testing.expectEqualStrings("#section", result2.rest);

    // Host with port and query
    const scheme3 = SchemeResult{ .scheme = "http", .rest = "example.com:3000?key=val", .guessed = false };
    const result3 = parseHost(scheme3);
    try std.testing.expectEqualStrings("example.com", result3.host.?);
    try std.testing.expectEqualStrings("3000", result3.port.?);
    try std.testing.expectEqualStrings("?key=val", result3.rest);
}

test "parseHost edge cases" {
    // Empty string
    const scheme1 = SchemeResult{ .scheme = "http", .rest = "", .guessed = false };
    const result1 = parseHost(scheme1);
    try std.testing.expect(result1.host == null);
    try std.testing.expect(result1.port == null);
    try std.testing.expectEqualStrings("", result1.rest);

    // Just a path
    const scheme2 = SchemeResult{ .scheme = "http", .rest = "/path", .guessed = false };
    const result2 = parseHost(scheme2);
    try std.testing.expect(result2.host == null);
    try std.testing.expect(result2.port == null);
    try std.testing.expectEqualStrings("/path", result2.rest);

    // Just a query
    const scheme3 = SchemeResult{ .scheme = "http", .rest = "?query", .guessed = false };
    const result3 = parseHost(scheme3);
    try std.testing.expect(result3.host == null);
    try std.testing.expect(result3.port == null);
    try std.testing.expectEqualStrings("?query", result3.rest);
}

test "parseHost workflow with parseScheme" {
    // Complete workflow: parseScheme -> parseHost
    const url = "https://api.example.com:443/v1/users?limit=10";

    const scheme_result = parseScheme(url);
    try std.testing.expectEqualStrings("https", scheme_result.scheme.?);

    const host_result = parseHost(scheme_result);
    try std.testing.expectEqualStrings("api.example.com", host_result.host.?);
    try std.testing.expectEqualStrings("443", host_result.port.?);
    try std.testing.expectEqualStrings("/v1/users?limit=10", host_result.rest);
}

test "parseQuery basic functionality" {
    // Query with single parameter
    const path1 = PathResult{ .path = "/users", .rest = "?id=123" };
    const result1 = parseQuery(path1);
    try std.testing.expectEqualStrings("?id=123", result1.query.?);
    try std.testing.expectEqualStrings("", result1.rest);
    
    // Query with multiple parameters
    const path2 = PathResult{ .path = "/search", .rest = "?q=test&limit=10&page=2" };
    const result2 = parseQuery(path2);
    try std.testing.expectEqualStrings("?q=test&limit=10&page=2", result2.query.?);
    try std.testing.expectEqualStrings("", result2.rest);
    
    // Query with fragment after
    const path3 = PathResult{ .path = "/docs", .rest = "?version=1.0#section" };
    const result3 = parseQuery(path3);
    try std.testing.expectEqualStrings("?version=1.0", result3.query.?);
    try std.testing.expectEqualStrings("#section", result3.rest);
}

test "parseQuery edge cases" {
    // No query present
    const path1 = PathResult{ .path = "/users", .rest = "" };
    const result1 = parseQuery(path1);
    try std.testing.expect(result1.query == null);
    try std.testing.expectEqualStrings("", result1.rest);
    
    // Fragment without query
    const path2 = PathResult{ .path = "/page", .rest = "#top" };
    const result2 = parseQuery(path2);
    try std.testing.expect(result2.query == null);
    try std.testing.expectEqualStrings("#top", result2.rest);
    
    // Empty query (just ?)
    const path3 = PathResult{ .path = "/search", .rest = "?" };
    const result3 = parseQuery(path3);
    try std.testing.expectEqualStrings("?", result3.query.?);
    try std.testing.expectEqualStrings("", result3.rest);
    
    // Empty query with fragment
    const path4 = PathResult{ .path = "/page", .rest = "?#section" };
    const result4 = parseQuery(path4);
    try std.testing.expectEqualStrings("?", result4.query.?);
    try std.testing.expectEqualStrings("#section", result4.rest);
}

test "parseQuery special characters" {
    // URL encoded spaces
    const path1 = PathResult{ .path = "/search", .rest = "?name=John%20Doe&city=New%20York" };
    const result1 = parseQuery(path1);
    try std.testing.expectEqualStrings("?name=John%20Doe&city=New%20York", result1.query.?);
    try std.testing.expectEqualStrings("", result1.rest);
    
    // Special characters in query
    const path2 = PathResult{ .path = "/api", .rest = "?email=user@example.com&redirect=/home" };
    const result2 = parseQuery(path2);
    try std.testing.expectEqualStrings("?email=user@example.com&redirect=/home", result2.query.?);
    try std.testing.expectEqualStrings("", result2.rest);
    
    // Array notation
    const path3 = PathResult{ .path = "/filter", .rest = "?tags[]=red&tags[]=blue#results" };
    const result3 = parseQuery(path3);
    try std.testing.expectEqualStrings("?tags[]=red&tags[]=blue", result3.query.?);
    try std.testing.expectEqualStrings("#results", result3.rest);
}

test "parseQuery full workflow" {
    // Complete workflow: parseScheme -> parseHost -> parsePath -> parseQuery
    const url = "https://api.example.com/v1/search?q=zig&limit=50&offset=0#results";
    
    const scheme_result = parseScheme(url);
    const host_result = parseHost(scheme_result);
    const path_result = parsePath(host_result);
    const query_result = parseQuery(path_result);
    
    try std.testing.expectEqualStrings("?q=zig&limit=50&offset=0", query_result.query.?);
    try std.testing.expectEqualStrings("#results", query_result.rest);
}

test "parseFragment basic functionality" {
    // Fragment only
    const query1 = QueryResult{ .query = null, .rest = "#section" };
    const result1 = parseFragment(query1);
    try std.testing.expectEqualStrings("#section", result1.fragment.?);
    try std.testing.expectEqualStrings("", result1.rest);
    
    // Fragment with special characters
    const query2 = QueryResult{ .query = "?id=123", .rest = "#header-with-dashes" };
    const result2 = parseFragment(query2);
    try std.testing.expectEqualStrings("#header-with-dashes", result2.fragment.?);
    try std.testing.expectEqualStrings("", result2.rest);
    
    // No fragment
    const query3 = QueryResult{ .query = "?test=value", .rest = "" };
    const result3 = parseFragment(query3);
    try std.testing.expect(result3.fragment == null);
    try std.testing.expectEqualStrings("", result3.rest);
}

test "parseUserInfo basic functionality" {
    // User and password
    const result1 = parseUserInfo("user:pass@example.com/path");
    try std.testing.expectEqualStrings("user", result1.user.?);
    try std.testing.expectEqualStrings("pass", result1.password.?);
    try std.testing.expectEqualStrings("example.com/path", result1.rest);
    
    // User only
    const result2 = parseUserInfo("admin@api.example.com:8080");
    try std.testing.expectEqualStrings("admin", result2.user.?);
    try std.testing.expect(result2.password == null);
    try std.testing.expectEqualStrings("api.example.com:8080", result2.rest);
    
    // No user info
    const result3 = parseUserInfo("example.com/path");
    try std.testing.expect(result3.user == null);
    try std.testing.expect(result3.password == null);
    try std.testing.expectEqualStrings("example.com/path", result3.rest);
    
    // @ in path (not userinfo)
    const result4 = parseUserInfo("example.com/user@domain.com");
    try std.testing.expect(result4.user == null);
    try std.testing.expect(result4.password == null);
    try std.testing.expectEqualStrings("example.com/user@domain.com", result4.rest);
}

test "complete URL parsing with Url.init" {
    // Simple URL
    const url1 = Url.init("https://example.com/path");
    try std.testing.expectEqualStrings("https", url1.scheme);
    try std.testing.expect(url1.user == null);
    try std.testing.expect(url1.password == null);
    try std.testing.expectEqualStrings("example.com", url1.host);
    try std.testing.expect(url1.port == null);
    try std.testing.expectEqualStrings("/path", url1.path);
    try std.testing.expect(url1.query == null);
    try std.testing.expect(url1.fragment == null);
    try std.testing.expect(!url1.guessed_scheme);
    
    // Complex URL with all components
    const url2 = Url.init("ftp://user:pass@files.example.com:2121/dir/file.txt?type=binary#section");
    try std.testing.expectEqualStrings("ftp", url2.scheme);
    try std.testing.expectEqualStrings("user", url2.user.?);
    try std.testing.expectEqualStrings("pass", url2.password.?);
    try std.testing.expectEqualStrings("files.example.com", url2.host);
    try std.testing.expectEqualStrings("2121", url2.port.?);
    try std.testing.expectEqual(@as(?u16, 2121), url2.portnum);
    try std.testing.expectEqualStrings("/dir/file.txt", url2.path);
    try std.testing.expectEqualStrings("?type=binary", url2.query.?);
    try std.testing.expectEqualStrings("#section", url2.fragment.?);
    try std.testing.expect(!url2.guessed_scheme);
    
    // URL without scheme (should guess)
    const url3 = Url.init("api.github.com/repos");
    try std.testing.expectEqualStrings("https", url3.scheme);
    try std.testing.expectEqualStrings("api.github.com", url3.host);
    try std.testing.expectEqualStrings("/repos", url3.path);
    try std.testing.expect(url3.guessed_scheme);
}

test "toString functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Simple URL
    var url1 = Url.init("https://example.com/path");
    const str1 = try url1.toString(allocator);
    defer allocator.free(str1);
    try std.testing.expectEqualStrings("https://example.com/path", str1);
    
    // Complex URL with all components
    var url2 = Url.init("ftp://user:pass@files.example.com:2121/dir/file.txt?type=binary#section");
    const str2 = try url2.toString(allocator);
    defer allocator.free(str2);
    try std.testing.expectEqualStrings("ftp://user:pass@files.example.com:2121/dir/file.txt?type=binary#section", str2);
    
    // URL with query but no fragment
    var url3 = Url.init("https://api.github.com/repos?sort=updated");
    const str3 = try url3.toString(allocator);
    defer allocator.free(str3);
    try std.testing.expectEqualStrings("https://api.github.com/repos?sort=updated", str3);
    
    // URL with fragment but no query
    var url4 = Url.init("https://docs.example.com/guide#installation");
    const str4 = try url4.toString(allocator);
    defer allocator.free(str4);
    try std.testing.expectEqualStrings("https://docs.example.com/guide#installation", str4);
    
    // URL with port but no userinfo
    var url5 = Url.init("http://localhost:3000/api/v1/users");
    const str5 = try url5.toString(allocator);
    defer allocator.free(str5);
    try std.testing.expectEqualStrings("http://localhost:3000/api/v1/users", str5);
}

test "toString roundtrip" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const original = "https://user:secret@api.example.com:8443/v2/data?filter=active&limit=100#results";
    
    // Parse -> toString should give back the same URL
    var url = Url.init(original);
    const reconstructed = try url.toString(allocator);
    defer allocator.free(reconstructed);
    
    try std.testing.expectEqualStrings(original, reconstructed);
}
