const std = @import("std");
const Io = std.Io;

// Create initial configuration
// Observe how it evolves in each generation
//
// Rules
// - The universe is theoretically infinite (I will do 100x100 at first)
// - Each cell can either be dead or alive
// - Each cell interacts with all its 8 neighboars
// - At each time (each generation) the following transitions occur:
//      - Any live cell with fewer than two live neighbours dies, as if by underpopulation
//      - Any live cell with two or three live neighbours lives on to the next generation
//      - Any live cell with more than three live neighbours dies, as if by overpopulation
//      - Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction

const Coordinates = struct {
    x: usize,
    y: usize,
};

const CellState = enum {
    ALIVE,
    DEAD,
};

const Cell = struct {
    coordinates: Coordinates,
    state: CellState,
};

const Configuration = struct {
    alive: []Coordinates,
};

const Generation = struct {
    universe: @Vector(100, @Vector(1000, Cell)),
};

fn procede_to_next_generation(current_generation: Generation) Generation {
    _ = current_generation;
}

fn game_of_life(initial_configuration: Configuration) void {
    _ = initial_configuration;
    // Create first generation out of the initial configuration
    // Use `procede_to_next_generation` to advance the generations
}

/// This is a documentation comment to explain the `printAnotherMessage` function below.
///
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

pub fn main(init: std.process.Init) !void {
    _ = init;
    // Prints to stderr, unbuffered, ignoring potential errors.
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // This is appropriate for anything that lives as long as the process.
    // const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    // const args = try init.minimal.args.toSlice(arena);
    //for (args) |arg| {
    //    std.log.info("arg: {s}", .{arg});
    //}

    // In order to do I/O operations need an `Io` instance.
    // const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // var stdout_buffer: [1024]u8 = undefined;
    // var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    // const stdout_writer = &stdout_file_writer.interface;

    // try printAnotherMessage(stdout_writer);

    // try stdout_writer.flush(); // Don't forget to flush!
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    try std.testing.fuzz({}, testOne, .{});
}

fn testOne(context: void, smith: *std.testing.Smith) !void {
    _ = context;
    // Try command `zig build test --fuzz -Doptimize=ReleaseFast` to see if it manages to fail this test case!

    const gpa = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);
    while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
        .add_data => {
            const slice = try list.addManyAsSlice(gpa, smith.value(u4));
            smith.bytes(slice);
        },
        .dup_data => {
            if (list.items.len == 0) continue;
            if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
            const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
            const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
            try list.appendSlice(gpa, list.items[off..][0..len]);
            try std.testing.expectEqualSlices(
                u8,
                list.items[off..][0..len],
                list.items[list.items.len - len ..],
            );
        },
    };
}
