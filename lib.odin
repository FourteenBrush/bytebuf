package bytebuf

import "core:mem"

BufferKind :: enum { Static, Dynamic }

Buffer :: struct($Kind: BufferKind) {
    data: ([]u8 when Kind == .Static else [dynamic]u8),
    read_off: int,
}

StaticBuffer :: Buffer(.Static)
SBuffer :: Buffer(.Static)

DynamicBuffer :: Buffer(.Dynamic)
DBuffer :: Buffer(.Dynamic)

ReadError :: enum {
    None      = 0,
    // Not enough bytes are available to read. Any read operation that returns this error
    // acts transactional and will not have consumed any bytes.
    ShortRead = 1,
}

create :: proc {
    create_static,
    create_dynamic,
    create_dynamic_from_copy,
}

create_static :: proc(data: []u8) -> SBuffer {
    return SBuffer { data = data }
}

create_dynamic :: proc(cap: uint, allocator := context.allocator) -> (d: DBuffer, err: mem.Allocator_Error) #optional_allocator_error {
    d.data = make([dynamic]u8, 0, cap, allocator) or_return
    return
}

create_dynamic_from_copy :: proc(contents: []u8, cap: uint, allocator := context.allocator) -> (d: DBuffer, err: mem.Allocator_Error) #optional_allocator_error {
    d.data = make([dynamic]u8, len(contents), cap, allocator) or_return
    copy(d.data[:], contents)
    return
}

destroy_dynamic :: proc(buf: DBuffer) {
    delete(buf.data)
}

// Returns the amount of bytes readable.
@(require_results)
readable :: proc(buf: Buffer($K)) -> int {
    return len(buf.data) - buf.read_off
}

// Returns `ReadError.None` if at least `n` bytes can be read from `buf`, returns `ReadError.ShortRead` otherwise.
// Do not pass in negative numbers.
@(require_results)
ensure_readable :: proc(buf: Buffer($K), #any_int n: int) -> ReadError {
    #assert(ReadError(0) == .None)
    #assert(ReadError(1) == .ShortRead)
    return ReadError(buf.read_off + n > len(buf.data))
}

// ------------------------------
// Reading primitives
// ------------------------------

@(require_results)
read_u8 :: proc(buf: ^Buffer($K)) -> (u8, ReadError) #no_bounds_check {
    if buf.read_off >= len(buf.data) do return 0, .ShortRead
    defer buf.read_off += 1
    return buf.data[buf.read_off], .None
}

@(require_results)
unchecked_read_u8 :: proc(buf: ^Buffer($K)) -> u8 #no_bounds_check {
    defer buf.read_off += 1
    return buf.data[buf.read_off]
}
