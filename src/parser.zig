const std = @import("std");

// idk if we really need a struct for the aprser really

// we need to have some context thing
// so a string map that we can give to the template so we can actually do any templating
pub const Ctx = struct {
    pub const Variable = union(enum) {
        str: []const u8,
        unsigned_int: u32,
        signed_int: i32,
        float: f32,
    };

    fn getfromCtx(self: Ctx, name: []u8, buffer: *std.ArrayList(u8)) !void {
        const a = self.context.get(name);
        if (a) |value| {
            switch (value) {
                .str => |s| try buffer.appendSlice(s),
                .unsigned_int => |val| try std.fmt.format(buffer.writer(), "{d}", .{val}),
                .signed_int => |val| try std.fmt.format(buffer.writer(), "{d}", .{val}),
                .float => |val| try std.fmt.format(buffer.writer(), "{e}", .{val}),
            }
        } else {
            try buffer.appendSlice("{item not found}");
        }
    }

    context: std.StringArrayHashMap(Variable),
};

// wip name
pub const Engine = struct {
    const Self = @This();
    templates: std.StringArrayHashMap(Template),
    _allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .templates = std.StringArrayHashMap(Template).init(allocator),
            ._allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var templates = self.templates.iterator();
        while (templates.next()) |value| {
            value.value_ptr.source_cache.deinit();
            value.value_ptr._allocator.free(value.value_ptr.source);
        }
        self.templates.deinit();
    }

    // template name is filename rn
    fn getTemplate(self: *Self, template_name: []const u8) !Template {
        const templateQuery = self.templates.get(template_name);
        // if we dont have the template in the templates cache then read it from files
        if (templateQuery) |template| {
            return template;
        } else {
            // make new template from filename
            // then do the thing we need to do
            std.debug.print("trying to open {s}\n", .{template_name});
            const file = std.fs.cwd().openFile(template_name, .{}) catch |e|
                switch (e) {
                error.FileNotFound => try std.fs.cwd().openFile("html/404.html", .{}),
                else => return e,
            };
            // if file not found need to do something else
            defer file.close();

            const content = try file.readToEndAlloc(self._allocator, 1024 * 8);

            const template = try Template.init(self._allocator, content);
            try self.templates.put(template_name, template);
            return template;
        }
    }

    ///caches the templates so it wont read the file more than nececery
    ///template name is filename and path rn
    pub fn renderTemplate(self: *Self, template_name: []const u8, ctx: Ctx) !std.ArrayList(u8) {
        return try (try getTemplate(self, template_name)).render(ctx);
    }
};

const Part = union(enum) {
    Immutable: []u8, // just html text
    Mutable: []u8, // name of the variable
};

///
const Template = struct {
    const Self = @This();
    source: []u8,

    source_cache: std.ArrayList(Part),

    _allocator: std.mem.Allocator,

    /// allocator given must be the same allocator that was used to allocate source
    pub fn init(allocator: std.mem.Allocator, source: []u8) !Self {
        var tmpl: Template = .{
            .source = source,
            .source_cache = std.ArrayList(Part).init(allocator),
            ._allocator = allocator,
        };
        var sliceStart: usize = 0;

        // make parts from the source
        // read untill {{ that slice is part
        var i: usize = 0;
        while (i <= tmpl.source.len - 1) {
            const char = tmpl.source[i];

            if (char == '{' and tmpl.source[i + 1] == '{') {
                try tmpl.source_cache.append(.{ .Immutable = tmpl.source[sliceStart..i] });
                try tmpl.source_cache.append(tmpl.parseVarName(&i, &sliceStart));
            }
            // end loop
            i += 1;
        }

        // at end we jus make the last immutable
        try tmpl.source_cache.append(.{ .Immutable = tmpl.source[sliceStart .. i - 1] });

        return tmpl;
    }

    // gets slice from source that includes the name within {{ }}
    // if we improve this later we could make this into an expression not a simple var name
    fn parseVarName(self: *Self, i: *usize, sliceStart: *usize) Part {
        // skip over {{
        sliceStart.* = i.* + 2;

        // untill we find }} make the mutable thing and end
        //
        while (self.source[i.*] != '}' and self.source[i.* + 1] != '}') {
            i.* += 1;
        }
        //std.debug.print("afterfind({s})\n", .{self.source[0 .. i.* + 1]});

        // i is now the start of }}
        var slice = self.source[sliceStart.* .. i.* + 1];
        // we now need to make the slice and remove the trailing and leading whitespace so we only have the name of the variable

        // i quess walk through it and get indexes of the things....
        var s_start: usize = 0;
        while (slice[s_start] == ' ') {
            s_start += 1;
        }
        slice = slice[s_start..slice.len];

        //std.debug.print("slice({s})\n", .{slice});

        var s_end: usize = 0;
        while (s_end < slice.len and
            slice[s_end] != ' ' and
            slice[s_end] != '\t' and
            slice[s_end] != '\n')
        {
            s_end += 1;
        }

        slice = slice[0..s_end];

        //std.debug.print("slice after cull({s})\n", .{slice});

        const rpart: Part = Part{ .Mutable = slice };
        sliceStart.* = i.* + 3;
        return rpart;
    }

    pub fn deinit(self: *Self) void {
        self.source_cache.deinit();
        self._allocator.free(self.source);
    }

    // makes finished product
    pub fn render(self: Self, ctx: Ctx) !std.ArrayList(u8) {
        var alist = std.ArrayList(u8).init(self._allocator);
        // i want to memcopy stuff to arraylist so we can remove free the arraylist when we are done
        // or if possible dont allocate anything
        for (self.source_cache.items) |item| {
            switch (item) {
                .Immutable => |c| try alist.appendSlice(c),
                .Mutable => |name| try ctx.getfromCtx(name, &alist), // get item from ctx get string from item add to alist
            }
        }
        return alist;
    }
};

// tests
test "Test Template 1" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("testTemplates/test1.html", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 8);
    //defer allocator.free(content);

    var template = try Template.init(allocator, content);
    defer template.deinit();

    //for (template.source_cache.items) |item| { switch (item) { .Immutable => |conten| std.debug.print("immutable:{s}\n", .{conten}), .Mutable => |conten| std.debug.print("mutable:{s}\n", .{conten}), } }

    try std.testing.expect(std.mem.eql(u8, "<p>\n", template.source_cache.items[0].Immutable));
    try std.testing.expect(std.mem.eql(u8, "variable", template.source_cache.items[1].Mutable));
    try std.testing.expect(std.mem.eql(u8, "\n</p>", template.source_cache.items[2].Immutable));
}

test "Test Template 2" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("testTemplates/test2.html", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 8);

    var template = try Template.init(allocator, content);
    defer template.deinit();

    //    for (template.source_cache.items) |item| { switch (item) { .Immutable => |conten| std.debug.print("immutable:{s}\n", .{conten}), .Mutable => |conten| std.debug.print("mutable:{s}\n", .{conten}), } }

    const first =
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\    <meta charset="UTF-8">
        \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\    <title>Document</title>
        \\</head>
        \\<body>
        \\    <h1>web page</h1>
        \\    <p> content :
    ;

    const last =
        \\</p>
        \\</body>
        \\</html>
    ;

    try std.testing.expect(std.mem.eql(u8, first, template.source_cache.items[0].Immutable));
    try std.testing.expect(std.mem.eql(u8, "content", template.source_cache.items[1].Mutable));
    try std.testing.expect(std.mem.eql(u8, last, template.source_cache.items[2].Immutable));
}
