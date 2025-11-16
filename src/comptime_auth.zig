const std = @import("std");
const tls = @import("tls");

const CertKeyPair = tls.config.CertKeyPair;
const crypto = std.crypto;
const Certificate = crypto.Certificate;
const Bundle = Certificate.Bundle;
const Allocator = std.mem.Allocator;
const mem = std.mem;

const base64 = std.base64.standard.decoderWithIgnore(" \t\r\n");

pub fn init(alloc: Allocator, comptime cert: []const u8, comptime key: []const u8) !CertKeyPair {
    var bundle = Bundle{};
    try addCertsFromSlice(&bundle, alloc, cert);
    return .{
        .key = try .parsePem(key),
        .ecdsa_key_pair = try .init(try .parsePem(key)),
        .bundle = bundle,
    };
}

//Copied from std.crypto.Certificate.Bundle.addCertsFromFile and modified accept a slice
pub fn addCertsFromSlice(cb: *Bundle, alloc: Allocator, comptime cert: []const u8) !void {
    const size = cert.len;

    // We borrow `bytes` as a temporary buffer for the base64-encoded data.
    // This is possible by computing the decoded length and reserving the space
    // for the decoded bytes first.
    const decoded_size_upper_bound = size / 4 * 3;
    const needed_capacity = std.math.cast(u32, decoded_size_upper_bound + size) orelse
        return error.CertificateAuthorityBundleTooBig;
    try cb.bytes.ensureUnusedCapacity(alloc, needed_capacity);
    const end_reserved: u32 = @intCast(cb.bytes.items.len + decoded_size_upper_bound);
    const buffer = cb.bytes.allocatedSlice()[end_reserved..];
    @memcpy(buffer[0..cert.len], cert);
    const encoded_bytes = buffer[0..cert.len];

    const begin_marker = "-----BEGIN CERTIFICATE-----";
    const end_marker = "-----END CERTIFICATE-----";

    const now_sec = std.time.timestamp();

    var start_index: usize = 0;
    while (mem.indexOfPos(u8, encoded_bytes, start_index, begin_marker)) |begin_marker_start| {
        const cert_start = begin_marker_start + begin_marker.len;
        const cert_end = mem.indexOfPos(u8, encoded_bytes, cert_start, end_marker) orelse
            return error.MissingEndCertificateMarker;
        start_index = cert_end + end_marker.len;
        const encoded_cert = mem.trim(u8, encoded_bytes[cert_start..cert_end], " \t\r\n");
        const decoded_start: u32 = @intCast(cb.bytes.items.len);
        const dest_buf = cb.bytes.allocatedSlice()[decoded_start..];
        cb.bytes.items.len += try base64.decode(dest_buf, encoded_cert);
        try cb.parseCert(alloc, decoded_start, now_sec);
    }
}