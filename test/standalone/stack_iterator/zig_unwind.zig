const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;
const testing = std.testing;

noinline fn frame3(expected: *[4]usize, unwound: *[4]usize) void {
    expected[0] = @returnAddress();

    var context: debug.ThreadContext = undefined;
    testing.expect(debug.getContext(&context)) catch @panic("failed to getContext");

    var debug_info = debug.getSelfDebugInfo() catch @panic("failed to openSelfDebugInfo");
    var it = debug.StackIterator.initWithContext(null, debug_info, &context) catch @panic("failed to initWithContext");
    defer it.deinit();

    if (comptime builtin.target.isDarwin() and builtin.cpu.arch == .aarch64) {
        const module = debug_info.getModuleForAddress(it.unwind_state.?.dwarf_context.pc) catch |err| {
            debug.print("no module found {}\n", .{err});
            @panic("no module");
        };

        debug.print("module has eh_frame: {} unwind_info: {} pc {}\n", .{
            module.eh_frame != null,
            module.unwind_info != null,
            it.unwind_state.?.dwarf_context.pc,
        });
        if (module.eh_frame) |e| {
            debug.print("eh_frame: {x} {x}\n", .{ @as(usize, @intFromPtr(e.ptr)), e.len });
        } else {
            debug.print("eh_frame: none\n", .{});
        }
    }

    const tty_config = std.io.tty.detectConfig(std.io.getStdErr());
    for (unwound, 0..) |*addr, i| {
        if (it.getLastError()) |unwind_error| {
            std.debug.printUnwindError(debug_info, std.io.getStdErr().writer(), unwind_error.address, unwind_error.err, tty_config) catch @panic("error printing");
            @panic("error during unwinding");
        }


        if (comptime builtin.target.isDarwin()) std.debug.print("i {} dwarf_context: {any}\nmcontext: {any}\n", .{ i, it.unwind_state.?.dwarf_context, it.unwind_state.?.dwarf_context.thread_context.mcontext.* });

        if (it.next()) |return_address| addr.* = return_address;
    }
}

noinline fn frame2(expected: *[4]usize, unwound: *[4]usize) void {
    // Excercise different __unwind_info / DWARF CFI encodings by forcing some registers to be restored
    if (builtin.target.ofmt != .c) {
        switch (builtin.cpu.arch) {
            .x86 => {
                if (builtin.omit_frame_pointer) {
                    asm volatile (
                        \\movl $3, %%ebx
                        \\movl $1, %%ecx
                        \\movl $2, %%edx
                        \\movl $7, %%edi
                        \\movl $6, %%esi
                        \\movl $5, %%ebp
                        ::: "ebx", "ecx", "edx", "edi", "esi", "ebp");
                } else {
                    asm volatile (
                        \\movl $3, %%ebx
                        \\movl $1, %%ecx
                        \\movl $2, %%edx
                        \\movl $7, %%edi
                        \\movl $6, %%esi
                        ::: "ebx", "ecx", "edx", "edi", "esi");
                }
            },
            .x86_64 => {
                if (builtin.omit_frame_pointer) {
                    asm volatile (
                        \\movq $3, %%rbx
                        \\movq $12, %%r12
                        \\movq $13, %%r13
                        \\movq $14, %%r14
                        \\movq $15, %%r15
                        \\movq $6, %%rbp
                        ::: "rbx", "r12", "r13", "r14", "r15", "rbp");
                } else {
                    asm volatile (
                        \\movq $3, %%rbx
                        \\movq $12, %%r12
                        \\movq $13, %%r13
                        \\movq $14, %%r14
                        \\movq $15, %%r15
                        ::: "rbx", "r12", "r13", "r14", "r15");
                }
            },
            else => {},
        }
    }

    expected[1] = @returnAddress();
    frame3(expected, unwound);
}

noinline fn frame1(expected: *[4]usize, unwound: *[4]usize) void {
    expected[2] = @returnAddress();

    // Use a stack frame that is too big to encode in __unwind_info's stack-immediate encoding
    // to exercise the stack-indirect encoding path
    var pad: [std.math.maxInt(u8) * @sizeOf(usize) + 1]u8 = undefined;
    _ = pad;

    frame2(expected, unwound);
}

noinline fn frame0(expected: *[4]usize, unwound: *[4]usize) void {
    expected[3] = @returnAddress();
    frame1(expected, unwound);
}

pub fn main() !void {
    if (!std.debug.have_ucontext or !std.debug.have_getcontext) return;

    var expected: [4]usize = undefined;
    var unwound: [4]usize = undefined;
    frame0(&expected, &unwound);
    try testing.expectEqual(expected, unwound);
}
