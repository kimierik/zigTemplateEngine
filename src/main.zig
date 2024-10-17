const std = @import("std");
const parser = @import("parser.zig");

var APP_RUNNING = true;
var Engine: parser.Engine = undefined;

const HandlerSignature = *const fn (*std.http.Server.Request, std.mem.Allocator) anyerror!void;

const HttpContext = struct {
    routingTable: std.StringArrayHashMap(HandlerSignature),
};

fn genericHandler(req: *std.http.Server.Request, allocator: std.mem.Allocator) !void {
    //const res = try Engine.renderTemplate(req.head.target[1..req.head.target.len], .{ .context = undefined });
    var c: parser.Ctx = .{ .context = std.StringArrayHashMap(parser.Ctx.Variable).init(allocator) };
    defer c.context.deinit();
    try c.context.put("content", .{ .str = "item from ctx" });

    const res = try Engine.renderTemplate("testTemplates/test2.html", c);
    defer res.deinit();
    try req.respond(res.items, .{});
}

/// get query from target string
fn getSlice(target: *const []u8, query: *const []u8) ?*const []u8 {
    const indexq = std.mem.indexOf(u8, target, query);
    if (indexq) |index| {
        _ = index; // autofix

        //return fron index to & or end of string

    } else {
        return null;
    }
}

/// remove get query from target
fn getTargetSlice(target: *const []u8) *const []u8 {
    for (0..target.len) |i| {
        if (target[i] == '?') {
            return target[0..i];
        }
    }
    return target;
}

/// handles accepting http requests to server and routing them to the propper response handler
fn handleServer(server: *std.net.Server, httpctx: *HttpContext) !void {
    var headerBuffer: [1024]u8 = undefined;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    while (true) {
        var connection = try server.accept();
        defer connection.stream.close();

        var httpServer = std.http.Server.init(connection, &headerBuffer);

        // this cannot be a try statement needs to be case and send user 400 to client
        var a = try httpServer.receiveHead();
        // write 400 to a.stream if this is fucked

        std.debug.print("target:{s}\n", .{a.head.target});

        const target = getTargetSlice(a.head.target);
        const handle = httpctx.routingTable.get(target);
        if (handle) |Handle| {
            try Handle(&a, allocator);
            arena.reset(.free_all);
        } else {
            //const f = try std.fs.cwd().openFile("html/404.html", .{});
            //defer f.close();
            try a.respond("404 page not found", .{});
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // template engine
    Engine = try parser.Engine.init(allocator);
    defer Engine.deinit();

    var ctx = HttpContext{ .routingTable = std.StringArrayHashMap(HandlerSignature).init(allocator) };
    defer ctx.routingTable.deinit();

    // init routing table
    try ctx.routingTable.put("/home", genericHandler);

    const ip4 = "192.168.1.107";
    const port = 3000;
    const address: std.net.Address = try std.net.Address.parseIp4(ip4, port);

    var server = try address.listen(.{});
    defer server.deinit();
    errdefer server.deinit();

    std.debug.print("server has been started {s}:{d}\n", .{ ip4, port });

    const serverThread = try std.Thread.spawn(.{ .allocator = allocator }, handleServer, .{ &server, &ctx });
    defer serverThread.detach();

    // main thread rn listenes stdin for input things
    var inputBuffer: [1024]u8 = undefined;
    while (APP_RUNNING) {
        inputBuffer = [_]u8{0} ** 1024;
        _ = try std.io.getStdIn().reader().readUntilDelimiter(&inputBuffer, '\n');
        //std.debug.print("reading:{s}", .{inputBuffer});
        const inputSlice = std.mem.sliceTo(&inputBuffer, 0);
        //std.debug.print("{any}\n", .{std.mem.eql(u8, inputSlice, "exit\n")});
        if (std.mem.eql(u8, inputSlice, "exit\n")) {
            APP_RUNNING = false;
            std.debug.print("Stopping server\n", .{});
        }
    }
}
