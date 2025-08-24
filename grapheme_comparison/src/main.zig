const std = @import("std");
const Graphemes = @import("Graphemes");
const DisplayWidth = @import("DisplayWidth");
const code_point = @import("code_point");
const uucode = @import("uucode");

// libvaxic's wcwidth-based width calculation
fn wcwidthBasedWidth(str: []const u8, data: *const DisplayWidth) u16 {
    var total: u16 = 0;
    var iter: code_point.Iterator = .init(str);
    while (iter.next()) |cp| {
        const w: u16 = switch (cp.code) {
            // undo an override in zg for emoji skintone selectors
            0x1f3fb...0x1f3ff,
            => 2,
            else => @max(0, data.codePointWidth(cp.code)),
        };
        total += w;
    }
    return total;
}

// uucode's wcwidth-based width calculation
fn uucodeBasedWidth(str: []const u8) u16 {
    var total: u16 = 0;
    var iter: code_point.Iterator = .init(str);
    while (iter.next()) |cp| {
        const w = uucode.get(.wcwidth, cp.code);
        const width: u16 = if (w < 0) 0 else @intCast(w);
        total += width;
    }
    return total;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const graphemes = try Graphemes.init(allocator);
    defer graphemes.deinit(allocator);

    const display_width = try DisplayWidth.initWithGraphemes(allocator, graphemes);
    defer display_width.deinit(allocator);

    const print = std.debug.print;

    const test_strings = [_][]const u8{
        // Basic ASCII
        "Hello World!",

        // Emoji
        "👋",

        // Complex emoji sequences
        "👨‍👩‍👧‍👦", // family emoji (ZWJ sequence)
        "🏳️‍🌈", // flag emoji (ZWJ sequence)

        // Devanagari with ZWJ sequences
        "क्‍ष",
    };

    for (test_strings) |test_str| {
        try analyzeString(&graphemes, &display_width, test_str);
        print("\n", .{});
    }
}

fn analyzeString(graphemes: *const Graphemes, display_width: *const DisplayWidth, text: []const u8) !void {
    const print = std.debug.print;

    print("String: \"{s}\"\n", .{text});

    var codepoint_count: usize = 0;
    var codepoint_total_width: usize = 0;

    var code_point_iter: code_point.Iterator = .init(text);
    while (code_point_iter.next()) |cp| {
        codepoint_count += 1;
        const width_i4 = display_width.codePointWidth(cp.code);
        const width: usize = if (width_i4 < 0) 0 else @intCast(width_i4);
        codepoint_total_width += width;
    }

    var iterator = graphemes.iterator(text);
    var grapheme_count: usize = 0;
    var total_display_width: usize = 0;
    var total_wcwidth_width: usize = 0;
    var total_uucode_width: usize = 0;

    while (iterator.next()) |grapheme_cluster| {
        const bytes = grapheme_cluster.bytes(text);
        const width = display_width.strWidth(bytes);
        const wcwidth_width = wcwidthBasedWidth(bytes, display_width);
        const uucode_width = uucodeBasedWidth(bytes);

        grapheme_count += 1;
        total_display_width += width;
        total_wcwidth_width += wcwidth_width;
        total_uucode_width += uucode_width;
    }

    print("Code Point Iterator: {} units,   width: {}\n", .{ codepoint_count, codepoint_total_width });
    print("Display Width:       {} units,   width: {}\n", .{ grapheme_count, total_display_width });
    print("wcwidth-based:       {} units,  width: {}\n", .{ grapheme_count, total_wcwidth_width });
    print("uucode wcwidth:      {} units,  width: {}\n", .{ grapheme_count, total_uucode_width });
}
