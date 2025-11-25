const std = @import("std");

pub fn slash_index(haystack: []const u8) []const u8 {
        const idx = comptime if (std.mem.lastIndexOf(u8, haystack, "/")) |i| i + 1 else 0;
        return  haystack[idx..];
}