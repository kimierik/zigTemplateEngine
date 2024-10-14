const std = @import("std");
const parser = @import("parser.zig");

var APP_RUNNING = true;
var Engine: parser.Engine = undefined;

const HandlerSignature = *const fn (*std.http.Server.Request) anyerror!void;

const HttpContext = struct {
    routingTable: std.StringArrayHashMap(*const fn (*std.http.Server.Request) anyerror!void),
};

fn genericHandler(req: *std.http.Server.Request) !void {
    //const res = try Engine.renderTemplate(req.head.target[1..req.head.target.len], .{ .context = undefined });
    const res = try Engine.renderTemplate("testTemplates/test2.html", .{ .context = undefined });
    defer res.deinit();
    try req.respond(res.items, .{});
}

fn handleServer(server: *std.net.Server, httpctx: *HttpContext) !void {
    var headerBuffer: [1024]u8 = undefined;

    while (true) {
        var connection = try server.accept();
        defer connection.stream.close();

        var httpServer = std.http.Server.init(connection, &headerBuffer);

        var a = try httpServer.receiveHead();
        //std.debug.print("{s}", .{headerBuffer});
        //.debug.print("methos:{s}\n", .{a.head.target});
        const handle = httpctx.routingTable.get(a.head.target);
        if (handle) |Handle| {
            try Handle(&a);
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

    var ctx = HttpContext{ .routingTable = std.StringArrayHashMap(*const fn (*std.http.Server.Request) anyerror!void).init(allocator) };
    try ctx.routingTable.put("/home", genericHandler);
    defer ctx.routingTable.deinit();

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
