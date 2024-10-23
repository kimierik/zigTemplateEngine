const std = @import("std");
const parser = @import("template.zig");

extern var Engine: *parser.Engine;

pub fn homeRedirectHandler(req: *std.http.Server.Request, allocator: std.mem.Allocator) !void {
    _ = allocator;
    const responseHead: std.http.Header = .{ .name = "Location", .value = "/home" };
    const rlist: [1]std.http.Header = .{responseHead};

    try req.respond("", .{ .extra_headers = &rlist, .status = .permanent_redirect });
}

pub fn genericHandler(req: *std.http.Server.Request, allocator: std.mem.Allocator) !void {
    //const res = try Engine.renderTemplate(req.head.target[1..req.head.target.len], .{ .context = undefined });
    var c: parser.Ctx = .{ .context = std.StringArrayHashMap(parser.Ctx.Variable).init(allocator) };
    defer c.context.deinit();
    const quer = getQueryValue(req.head.target, "content");

    if (quer) |value| {
        try c.context.put("content", .{ .str = value });
    } else {
        try c.context.put("content", .{ .str = "no query" });
    }

    const res = try Engine.renderTemplate("testTemplates/test3.html", c);
    defer res.deinit();
    try req.respond(res.items, .{});
}

/// get query from target string
fn getQueryValue(target: []const u8, query: []const u8) ?[]const u8 {
    if (query.len == 0) {
        return null;
    }
    // no query that is larger than 255
    if (query.len >= 256) {
        return null;
    }
    // add '=' at the edn of query so we dont find a substring if a name
    var qs: [256]u8 = [_]u8{0} ** 256;
    std.mem.copyForwards(u8, &qs, query);
    qs[query.len] = '=';
    const qslice = qs[0 .. query.len + 1];

    const indexq = std.mem.indexOf(u8, target, qslice);

    if (indexq) |i| {
        const index = i + query.len + 1;

        // find next &. if not found then end of string
        const end = std.mem.indexOfScalar(u8, target[index..target.len], '&');
        if (end) |end_index| {
            return target[index .. end_index + index];
        } else {
            return target[index..target.len];
        }

        //return fron index to & or end of string

    } else {
        return null;
    }
}

test getQueryValue {
    const targ = "end?valie1=asdfgh&value2=42069";
    try std.testing.expect(std.mem.eql(u8, getQueryValue(targ, "valie1").?, "asdfgh"));
    try std.testing.expect(std.mem.eql(u8, getQueryValue(targ, "value2").?, "42069"));
}

/// gets corresponding character from excape
fn getExcapeChar(excapeSlice: []const u8) !u8 {
    // this should be some sort of a map not if thir or that
    if (std.mem.eql(u8, excapeSlice, "20"))
        return ' ';
    if (std.mem.eql(u8, excapeSlice, "3C"))
        return '<';
    if (std.mem.eql(u8, excapeSlice, "3E"))
        return '>';
    if (std.mem.eql(u8, excapeSlice, "23"))
        return '#';
    if (std.mem.eql(u8, excapeSlice, "25"))
        return '%';
    if (std.mem.eql(u8, excapeSlice, "2B"))
        return '+';
    if (std.mem.eql(u8, excapeSlice, "7B"))
        return '{';
    if (std.mem.eql(u8, excapeSlice, "7D"))
        return '}';
    if (std.mem.eql(u8, excapeSlice, "7C"))
        return '|';
    if (std.mem.eql(u8, excapeSlice, "5C"))
        return '\\';
    if (std.mem.eql(u8, excapeSlice, "5E"))
        return '^';
    if (std.mem.eql(u8, excapeSlice, "7E"))
        return '~';
    if (std.mem.eql(u8, excapeSlice, "5B"))
        return '[';
    if (std.mem.eql(u8, excapeSlice, "5D"))
        return ']';
    if (std.mem.eql(u8, excapeSlice, "60"))
        return '‘';
    if (std.mem.eql(u8, excapeSlice, "3B"))
        return ';';
    if (std.mem.eql(u8, excapeSlice, "2F"))
        return '/';
    if (std.mem.eql(u8, excapeSlice, "3F"))
        return '?';
    if (std.mem.eql(u8, excapeSlice, "3A"))
        return ':';
    if (std.mem.eql(u8, excapeSlice, "40"))
        return '@';
    if (std.mem.eql(u8, excapeSlice, "3D"))
        return '=';
    if (std.mem.eql(u8, excapeSlice, "26"))
        return '&';
    if (std.mem.eql(u8, excapeSlice, "24"))
        return '$';

    return error.InvalidExcape;
}

// https://docs.microfocus.com/OMi/10.62/Content/OMi/ExtGuide/ExtApps/URL_encoding.htm
/// parses excapes from string
/// caller owns return
pub fn parseQueryValue(str: []const u8, allocator: std.mem.Allocator) ?std.ArrayList(u8) {
    var returnlist = std.ArrayList(u8).init(allocator);
    errdefer returnlist.deinit();

    var i: usize = 0;
    while (i < str.len) {
        const char = str[i];
        if (char == '%' or char == '$') {
            const excapeSlice = str[i - 1 .. i + 3];
            const exchar = try getExcapeChar(excapeSlice);
            try returnlist.append(exchar);
            i += 3;
        } else {
            try returnlist.append(char);
        }
    }
}

/// remove get query from target
pub fn getTargetSlice(target: []const u8) []const u8 {
    // index of scalar can be used from std.mem

    for (0..target.len) |i| {
        if (target[i] == '?') {
            return target[0..i];
        }
    }
    return target;
}
