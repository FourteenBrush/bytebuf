package tests

import "core:mem"
import "core:slice"
import "core:testing"

import bytebuf ".."

@(test)
creation :: proc(t: ^testing.T) {
    using bytebuf, testing

    s: StaticBuffer = create([]u8{9, 3, 4})
    expect(t, type_of(s.data) == []u8)

    d, err := create(512, context.temp_allocator)
    expect_value(t, err, mem.Allocator_Error.None)
    expect(t, type_of(d.data) == [dynamic]u8)
}

@(test)
num_readable_with_offsets :: proc(t: ^testing.T) {
    using bytebuf, testing

    s: SBuffer
    expect_value(t, readable(s), 0)
    s.data = {1, 1, 1}
    expect_value(t, readable(s), 3)
    s.read_off = 1
expect_value(t, readable(s), 2)
    s.read_off = 2
    expect_value(t, readable(s), 1)
    s.read_off = 3
    expect_value(t, readable(s), 0)
    // there is no way read_off can become bigger than len(data), unless set manually

    d: DBuffer
    expect_value(t, readable(s), 0)
    d.data = slice.to_dynamic([]u8{1, 1, 1}, context.temp_allocator)
    expect_value(t, readable(d), 3)
    d.read_off = 1
    expect_value(t, readable(d), 2)
    d.read_off = 2
    expect_value(t, readable(d), 1)
    d.read_off = 3
    expect_value(t, readable(d), 0)
}

@(test)
ensure_readability :: proc(t: ^testing.T) {
    using bytebuf
    _test_readability(t, &SBuffer {})
    _test_readability(t, &DBuffer {})
}

@(private="file")
_test_readability :: proc(t: ^testing.T, buf: ^bytebuf.Buffer($K)) {
    using bytebuf, testing

    expect_value(t, ensure_readable(buf^, 0), ReadError.None)
    expect_value(t, ensure_readable(buf^, 1), ReadError.ShortRead)
    expect_value(t, ensure_readable(buf^, 8), ReadError.ShortRead)

    data := []u8 {1, 1, 1}
    buf.data = data when K == .Static else slice.to_dynamic(data, context.temp_allocator)

    for n in 0..=3 {
        expect_value(t, ensure_readable(buf^, n), ReadError.None)
    }
    expect_value(t, ensure_readable(buf^, 4), ReadError.ShortRead)

    buf.read_off = 2
    expect_value(t, ensure_readable(buf^, 0), ReadError.None)
    expect_value(t, ensure_readable(buf^, 1), ReadError.None)
    expect_value(t, ensure_readable(buf^, 2), ReadError.ShortRead)

    buf.read_off = 3
    expect_value(t, ensure_readable(buf^, 0), ReadError.None)
    expect_value(t, ensure_readable(buf^, 1), ReadError.ShortRead)
}

@(test)
read_u8 :: proc(t: ^testing.T) {
    using bytebuf
    _read_u8(t, &SBuffer{})
    _read_u8(t, &DBuffer{})
}

@(private="file")
_read_u8 :: proc(t: ^testing.T, buf: ^bytebuf.Buffer($K)) {
    using bytebuf, testing

    data := []u8 {4, 8, 9}
    buf.data = data when K == .Static else slice.to_dynamic(data, context.temp_allocator)
    expect_value(t, readable(buf^), 3)
    expect_value(t, ensure_readable(buf^, 3), ReadError.None)

    for byte, i in data {
        b, err := read_u8(buf)
        expect_value(t, b, byte)
        expect_value(t, err, ReadError.None)

        expect_value(t, readable(buf^), len(data) - i - 1)
        expect_value(t, ensure_readable(buf^, len(data) - i), ReadError.ShortRead)
    }

    expect_value(t, readable(buf^), 0)
    // ensure successive reads fail
    expect_value(t, compress_values(read_u8(buf)), compress_values(u8(0), ReadError.ShortRead))
    expect_value(t, ensure_readable(buf^, 1), ReadError.ShortRead)
}

@(test)
unchecked_read_u8 :: proc(t: ^testing.T) {
    using bytebuf
    _unchecked_read_u8(t, &SBuffer{})
    _unchecked_read_u8(t, &DBuffer{})
}

@(private="file")
_unchecked_read_u8 :: proc(t: ^testing.T, buf: ^bytebuf.Buffer($K)) {
    using bytebuf, testing
    
    data := []u8{7, 12, 34, 8}
    buf.data = data when K == .Static else slice.to_dynamic(data, context.temp_allocator)

    expect_value(t, readable(buf^), len(data))
    expect_value(t, ensure_readable(buf^, len(data)), ReadError.None)

    for byte, i in data {
        b := unchecked_read_u8(buf)
        expect_value(t, b, byte)

        expect_value(t, readable(buf^), len(data) - i - 1)
        expect_value(t, ensure_readable(buf^, len(data) - i), ReadError.ShortRead)
    }

    expect_value(t, readable(buf^), 0)
    // ensure successive reads would fail, we cant really assume another unchecked read to segfault
    // as it's theoretically undefined behaviour what happens
    expect_value(t, ensure_readable(buf^, 1), ReadError.ShortRead)
}
