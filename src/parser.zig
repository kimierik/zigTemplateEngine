const std = @import("std");

// idk if we really need a struct for the aprser really

// we need to have some context thing
// so a string map that we can give to the template so we can actually do any templating
const Ctx = struct {};

// dont really know if we should make a small app or something so i could actually do something with this parser thing
// maby make this into a lib and then make an app with it

// we need a struct or something that would store all of the templates that we can query from the head template
// maybe a head struct or something

// wip name
pub const Engine = struct {
    const Self = @This();
    templates: std.StringArrayHashMap(Template),

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .templates = std.StringArrayHashMap(Template).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        const templates = self.templates.iterator();
        for (templates.next()) |value| {
            value.source.deinit();
        }
        self.templates.deinit();
    }

    fn getTemplate(self: *Self, template_name: *const []u8) !Template {
        const templateQuery = self.templates.get(template_name);
        // if we dont have the template in the templates cache then read it from files
        if (templateQuery) |template| {
            return template;
        } else {
            // make new template from filename
            // then do the thing we need to do
            unreachable;
            // Template.init()
        }
    }

    // caches the templates so it wont read the file more than nececery
    pub fn renderTemplate(self: *Self, template_name: *const []u8, ctx: Ctx) !std.ArrayList(u8) {
        return getTemplate(self, template_name).render(ctx);
    }
};

const Part = union(enum) {
    Immutable: []u8, // just html text
    Mutable: []u8, // name of the variable
};

const Template = struct {
    const Self = @This();
    source: std.ArrayList(u8),

    source_cache: std.ArrayList(Part),

    pub fn init(allocator: std.mem.Allocator, source: std.ArrayList(u8)) !Self {
        var tmpl: Template = .{
            .source = source,
            .source_cache = std.ArrayList(Part).init(allocator),
        };
        var sliceStart: usize = 0;

        // make parts from the source
        // read untill {{ that slice is part
        var i: usize = 0;
        while (i <= tmpl.source.items.len - 1) {
            const char = tmpl.source.items[i];
            if (char == '{' and tmpl.source.items[i + 1] == '{') {
                // make start of the thing
                try tmpl.source_cache.append(.{ .Immutable = tmpl.source.items[sliceStart .. i - 1] });
                sliceStart = i + 2;
                // untill we find }} make the mutable thing and end
                while (tmpl.source.items[i] != '}' and tmpl.source.items[i + 1] != '}') {
                    i += 1;
                }

                // need to remove whitespace from the variable name
                try tmpl.source_cache.append(.{ .Mutable = tmpl.source.items[sliceStart .. i - 1] });
                sliceStart = i + 1; // also need to know how mutch to jump
            }
            // end loop
            i += 1;
        }

        try tmpl.source_cache.append(.{ .Immutable = tmpl.source.items[sliceStart .. i - 1] });

        return tmpl;
    }

    fn deinit(self: *Self) void {
        self.source_cache.deinit();
        self.source.deinit();
    }

    // makes finished product
    fn render(self: Self, ctx: Ctx) !std.ArrayList(u8) {
        _ = ctx; // autofix
        _ = self; // autofix

        //walk through source cache
        //make a string that we return

        //std.mem.indexOfPos(comptime T: type, haystack: []const T, start_index: usize, needle: []const T)
        //std.mem.tokenizeSequence(comptime T: type, buffer: []const T, delimiter: []const T)
        //or other tokenize fn cna

        // if possible use zig std for as many fns
    }
};

test "Template parser" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("testTemplates/test1.html", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 8);
    defer allocator.free(content);

    var items = std.ArrayList(u8).init(allocator);
    try items.appendUnalignedSlice(content);

    var template = try Template.init(allocator, items);
    defer template.deinit();

    for (template.source_cache.items) |item| {
        switch (item) {
            .Immutable => |conten| std.debug.print("immutable:{s}\n", .{conten}),
            .Mutable => |conten| std.debug.print("mutable:{s}\n", .{conten}),
        }
    }
}
