package bytebuf

import "core:mem"

BufferKind :: enum { Static, Growable }

Buffer :: struct($Kind: BufferKind) {
    data: ([]u8 when Kind == .Static else [dynamic]u8),
    read_off: int,
}

// Non growable buffer type.
StaticBuffer :: Buffer(.Static)
SBuffer :: Buffer(.Static)

GrowableBuffer :: Buffer(.Growable)
GBuffer :: Buffer(.Growable)

ReadError :: enum {
    None      = 0,
    // Not enough bytes are available to read. Any read operation that returns this error
    // acts transactional and will not have consumed any bytes.
    ShortRead = 1,
    // Encountered invalid bytes while reading a certain type.
    InvalidData,
}

create :: proc {
    create_static,
    create_growable,
    create_growable_from_copy,
}

// Creates a static buffer which does not have the ability to grow beyond its capacity.
create_static :: proc "contextless" (data: []u8) -> SBuffer {
    return SBuffer { data = data }
}

// Creates a growable buffer, using the provided capacity and allocator.
// `cap` must be >= 0.
create_growable :: proc(#any_int cap: int, allocator := context.allocator) -> (d: GBuffer, err: mem.Allocator_Error) #optional_allocator_error {
    d.data = make([dynamic]u8, 0, cap, allocator) or_return
    return
}

// Creates a growable buffer using the provided allocator, additionally, copies `contents` into it.
// `cap` must not be smaller than `len(contents)`.
create_growable_from_copy :: proc(contents: []u8, #any_int cap: int, allocator := context.allocator) -> (d: GBuffer, err: mem.Allocator_Error) #optional_allocator_error {
    d.data = make([dynamic]u8, len(contents), cap, allocator) or_return
    copy(d.data[:], contents)
    return
}

destroy_growable :: proc(buf: GBuffer) {
    delete_dynamic_array(buf.data)
}

// Returns the amount of bytes readable.
@(require_results)
readable :: proc "contextless" (buf: Buffer($K)) -> int {
    return len(buf.data) - buf.read_off
}

// Returns `ReadError.None` if at least `n` bytes can be read from `buf`, returns `ReadError.ShortRead` otherwise.
// Do not pass in negative numbers.
@(require_results)
ensure_readable :: proc "contextless" (buf: Buffer($K), #any_int n: int) -> ReadError {
    #assert(ReadError(0) == .None)
    #assert(ReadError(1) == .ShortRead)
    return ReadError(buf.read_off + n > len(buf.data))
}

// ------------------------------
// Reading primitives
// ------------------------------

// Reads a boolean, only accepting either `0` or `1`, any other value is treated
// as invalid and `ReadError.InvalidData` is returned.
@(require_results)
read_bool_exact :: proc "contextless" (buf: ^Buffer($K)) -> (bool, ReadError) #no_bounds_check {
    if buf.read_off >= len(buf.data) do return false, .ShortRead
    b := buf.data[buf.read_off]
    if b > 1 do return false, .InvalidData
    defer buf.read_off += 1
    return bool(b), .None
}

@(require_results)
unchecked_read_bool_exact :: proc "contextless" (buf: ^Buffer($K)) -> (bool, ReadError) #no_bounds_check {
    b := buf.data[buf.read_off]
    if b > 0 do return false, .InvalidData
    defer buf.read_off += 1
    return bool(b), .None
}

@(require_results)
read_u8 :: proc "contextless" (buf: ^Buffer($K)) -> (u8, ReadError) #no_bounds_check {
    if buf.read_off >= len(buf.data) do return 0, .ShortRead
    defer buf.read_off += 1
    return buf.data[buf.read_off], .None
}

@(require_results)
unchecked_read_u8 :: proc "contextless" (buf: ^Buffer($K)) -> u8 #no_bounds_check {
    defer buf.read_off += 1
    return buf.data[buf.read_off]
}
