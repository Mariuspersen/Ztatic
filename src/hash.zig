pub fn hash(bytes: []const u8) u64 {
    var final: u64 = 0;
    for (bytes, 1..) |b, i| {
        const mul = @mulWithOverflow(b, i)[0];
        const res = @addWithOverflow(final, mul)[0];
        final = res;
    }
    return final;
}