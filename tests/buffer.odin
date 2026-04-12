#+feature using-stmt
package tests

import "core:mem"
import "core:slice"
import "core:c/libc"
import "core:testing"
@(require) import "core:sys/posix"
@(require) import win32 "core:sys/windows"

import bytebuf ".."

// no windows case needed, handling code maps SEH exception to SIGILL
TRAP_SIG :: posix.SIGTRAP when ODIN_OS == .Darwin else win32.EXCEPTION_ILLEGAL_INSTRUCTION when ODIN_OS == .Windows else libc.SIGILL

// TODO: generic testing harness that tests transactional reads and readability
// - ensure short reads are indeed transactional
// - ensure invalid data produces .InvalidData error

@(test)
creation :: proc(t: ^testing.T) {
    using bytebuf, testing

    s: StaticBuffer = create([]u8{9, 3, 4})
    expect(t, type_of(s.data) == []u8)

    g, err := create(512, context.allocator)
    defer destroy_growable(g)
    expect_value(t, err, mem.Allocator_Error.None)
    expect(t, type_of(g.data) == [dynamic]u8)
}

@(test)
create_dynamic_zero_cap_works :: proc(t: ^testing.T) {
    using bytebuf, testing
    
    g, err := create_growable(0, context.temp_allocator)
    expect_value(t, err, mem.Allocator_Error.None)
    expect(t, type_of(g.data) == [dynamic]u8)
    
    g, err = create_growable_from_copy([]u8{}, 0, context.temp_allocator)
    expect_value(t, err, mem.Allocator_Error.None)
    expect(t, type_of(g.data) == [dynamic]u8)
}

@(test)
dynamic_cap_violation :: proc(t: ^testing.T) {
    using bytebuf, testing
    testing.expect_signal(t, TRAP_SIG)
    _, _ = create_growable(-1, context.temp_allocator)
}

@(test)
dynamic_from_copy_cap_violation :: proc(t: ^testing.T) {
    using bytebuf, testing
    testing.expect_signal(t, TRAP_SIG)
    _, _ = create_growable_from_copy([]u8{}, -1, context.temp_allocator)
}

@(test)
dynamic_from_contents_cap_violation :: proc(t: ^testing.T) {
    using bytebuf, testing
    testing.expect_signal(t, TRAP_SIG)
    _, _ = create_growable_from_copy([]u8{16, 32, 12}, cap=2, allocator=context.temp_allocator)
}

@(test)
creation_from_copy :: proc(t: ^testing.T) {
    using bytebuf, testing
    contents := []u8{8, 16, 7, 48}
    g, err := create_growable_from_copy(contents, 64, context.temp_allocator)
    expect_value(t, err, mem.Allocator_Error.None)
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

    g: GBuffer
    expect_value(t, readable(s), 0)
    g.data = slice.to_dynamic([]u8{1, 1, 1}, context.temp_allocator)
    expect_value(t, readable(g), 3)
    g.read_off = 1
    expect_value(t, readable(g), 2)
    g.read_off = 2
    expect_value(t, readable(g), 1)
    g.read_off = 3
    expect_value(t, readable(g), 0)
}

@(test)
ensure_readability :: proc(t: ^testing.T) {
    using bytebuf
    test(t, &SBuffer {})
    test(t, &GBuffer {})

    test :: proc(t: ^testing.T, buf: ^bytebuf.Buffer($K)) {
        using bytebuf, testing

        expect_value(t, ensure_readable(buf^, 0), ReadError.None)
        expect_value(t, ensure_readable(buf^, 1), ReadError.ShortRead)
        expect_value(t, ensure_readable(buf^, 8), ReadError.ShortRead)

        data := []u8 {1, 1, 1}
        buf.data = data when K == .Static else slice.to_dynamic(data, context.temp_allocator)

        for n in 0..=len(data) {
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
}

@(test)
read_u8 :: proc(t: ^testing.T) {
    using bytebuf
    test(t, &SBuffer{})
    test(t, &GBuffer{})

    test :: proc(t: ^testing.T, buf: ^bytebuf.Buffer($K)) {
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
}

@(test)
unchecked_read_u8 :: proc(t: ^testing.T) {
    using bytebuf
    test(t, &SBuffer{})
    test(t, &GBuffer{})

	test :: proc(t: ^testing.T, buf: ^bytebuf.Buffer($K)) {
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
		// ensure successive reads fail, we cant really assume another unchecked read to segfault
		// as it's theoretically undefined behaviour what happens
		expect_value(t, ensure_readable(buf^, 1), ReadError.ShortRead)
	}
}

@(test)
read_bool_exact :: proc(t: ^testing.T) {
    using bytebuf
    test(t, &SBuffer{})
    test(t, &GBuffer{})

    test :: proc(t: ^testing.T, buf: ^bytebuf.Buffer($K)) {
        using bytebuf, testing

        data := []u8{0, 12, 1}
        buf.data = data when K == .Static else slice.to_dynamic(data, context.temp_allocator)

        expect_value(t, readable(buf^), len(data))
        expect_value(t, ensure_readable(buf^, len(data)), ReadError.None)

        b0, err := read_bool_exact(buf)
        // expect_value()
    }
}
