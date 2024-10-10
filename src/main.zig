const std = @import("std");

var APP_RUNNING = true;

fn handleServer(server: *std.net.Server) !void {
    var headerBuffer: [1024]u8 = undefined;

    while (true) {
        var connection = try server.accept();
        defer connection.stream.close();

        var httpServer = std.http.Server.init(connection, &headerBuffer);

        var a = try httpServer.receiveHead();
        //std.debug.print("{s}", .{headerBuffer});
        std.debug.print("methos:{s}\n", .{a.head.target});

        // start doing parsing things
        // parser should probably have atleast some testing
        try a.respond("hello\n", .{});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const ip4 = "192.168.1.107";
    const port = 3000;
    const address: std.net.Address = try std.net.Address.parseIp4(ip4, port);

    var server = try address.listen(.{});
    defer server.deinit();
    errdefer server.deinit();

    std.debug.print("server has been started {s}:{d}\n", .{ ip4, port });

    const serverThread = try std.Thread.spawn(.{ .allocator = allocator }, handleServer, .{&server});
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
