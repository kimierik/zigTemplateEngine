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
    try c.context.put("content", .{ .str = "item from ctx" });

    const res = try Engine.renderTemplate("testTemplates/test2.html", c);
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
