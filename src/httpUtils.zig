const std = @import("std");
const parser = @import("template.zig");

extern var Engine: *parser.Engine;

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
fn getSlice(target: []const u8, query: []const u8) ?[]const u8 {
    const indexq = std.mem.indexOf(u8, target, query);
    if (indexq) |index| {
        _ = index; // autofix

        //return fron index to & or end of string

    } else {
        return null;
    }
}

/// remove get query from target
pub fn getTargetSlice(target: []const u8) []const u8 {
    for (0..target.len) |i| {
        if (target[i] == '?') {
            return target[0..i];
        }
    }
    return target;
}
