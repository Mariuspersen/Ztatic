pub fn hash(bytes: []const u8) u64 {
    var final: u64 = 0x9e3779b185ebca87;
    @setEvalBranchQuota(3000);
    for (bytes) |b| {
        final ^= b;
        final = @mulWithOverflow(final, 0x165667919e3779f9)[0];
        final ^= final >> 27;
    }
    return final;
}