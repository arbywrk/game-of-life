const std = @import("std");
const Io = std.Io;

const Error = error{
    OutOfBounds,
};

fn is_alive(c: Coordinates, generation: Generation) Error!bool {
    if (c.y >= generation.universe.len or c.x >= generation.universe[0].len) {
        return Error.OutOfBounds;
    }
    return generation.universe[c.y][c.x].state == CellState.alive;
}

fn number_of_neighbours(c: Coordinates, generation: Generation, default_args: struct { cache: bool = false }) u4 {
    const LastChecked = struct {
        var lc: Coordinates = undefined;
        var lr: u4 = undefined;
    };

    if (default_args.cache and std.meta.eql(c, LastChecked.lc)) {
        return LastChecked.lr;
    }

    const dy: [8]i8 = .{ -1, -1, 0, 1, 1, 1, 0, -1 };
    const dx: [8]i8 = .{ 0, 1, 1, 1, 0, -1, -1, -1 };

    var neighbours: u4 = 0;
    for (0..8) |i| {
        if (is_alive(.{
            .x = std.math.cast(usize, @as(isize, @intCast(c.x)) + dx[i]) orelse continue,
            .y = std.math.cast(usize, @as(isize, @intCast(c.y)) + dy[i]) orelse continue,
        }, generation) catch continue) {
            neighbours += 1;
        }
    }

    LastChecked.lc = c;
    LastChecked.lr = neighbours;

    return neighbours;
}

// Create initial configuration
// Observe how it evolves in each generation
//
// Rules
// - The universe is theoretically infinite (I will do 100x100 at first)
// - Each cell can either be dead or alive
// - Each cell interacts with all its 8 neighboars
// - At each time (each generation) the following transitions occur:
//      - Any live cell with fewer than two live neighbours dies, as if by underpopulation
fn is_underpopulated(c: Coordinates, generation: Generation) bool {
    return number_of_neighbours(c, generation, .{ .cache = true }) < 2;
}
//      - Any live cell with two or three live neighbours lives on to the next generation
//      - Any live cell with more than three live neighbours dies, as if by overpopulation
fn is_overpopulated(c: Coordinates, generation: Generation) bool {
    return number_of_neighbours(c, generation, .{ .cache = true }) > 3;
}
//      - Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction
fn can_reproduce(c: Coordinates, generation: Generation) bool {
    return number_of_neighbours(c, generation, .{ .cache = true }) == 3;
}

const Coordinates = struct {
    x: usize,
    y: usize,
};

const CellState = enum {
    alive,
    dead,
};

const Cell = struct {
    state: CellState,
};

const Configuration = struct {
    alive: []Coordinates,
};

const universe_t: type = [20][20]Cell;

const Generation = struct {
    universe: universe_t,
};

fn display_universe(writer: *Io.Writer, universe: universe_t) !void {
    try writer.print("-", .{});
    for (universe) |row| {
        for (row) |_| {
            try writer.print("--", .{});
        }
        try writer.print("\n", .{});
        try writer.print("|", .{});
        for (row) |cell| {
            if (cell.state == CellState.alive) {
                try writer.print("X|", .{});
            } else {
                try writer.print(" |", .{});
            }
        }
        try writer.print("\n", .{});
    }
    for (universe[0]) |_| {
        try writer.print("--", .{});
    }
    try writer.print("-\n", .{});
}

fn create_next_generation(current_generation: Generation) Generation {
    var next_generation: Generation = .{ .universe = @splat(@splat(.{ .state = CellState.dead })) };
    for (current_generation.universe, 0..) |row, y| {
        for (row, 0..) |cell, x| {
            if (cell.state == CellState.alive and (is_underpopulated(.{ .x = x, .y = y }, current_generation) or is_overpopulated(.{ .x = x, .y = y }, current_generation))) {
                next_generation.universe[y][x].state = CellState.dead;
                // std.debug.print("Will die: {} {}\n", .{ y, x });
            } else if (cell.state == CellState.dead and can_reproduce(.{ .x = x, .y = y }, current_generation)) {
                next_generation.universe[y][x].state = CellState.alive;
                //std.debug.print("Will be born: {} {}\n", .{ y, x });
            } else {
                next_generation.universe[y][x].state = current_generation.universe[y][x].state;
                // std.debug.print("Nothing will change: {} {}\n", .{ y, x });
            }
        }
    }

    return next_generation;
}

fn game_of_life(writer: *Io.Writer, reader: *Io.Reader, initial_configuration: Configuration) !void {
    var first_generation: Generation = .{ .universe = @splat(@splat(.{ .state = CellState.dead })) };

    for (initial_configuration.alive) |cell_coordinates| {
        first_generation.universe[cell_coordinates.y][cell_coordinates.x].state = CellState.alive;
    }

    var current_generation = first_generation;
    while (true) {
        try display_universe(writer, current_generation.universe);
        try writer.flush(); // Don't forget to flush!
        var read_buffer: [1]u8 = undefined;
        _ = try reader.readSliceShort(&read_buffer);
        current_generation = create_next_generation(current_generation);
    }
}

pub fn main(init: std.process.Init) !void {
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
    const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    const stdin_reader = &stdin_file_reader.interface;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator();
    const alive_coordinates_ptr = try allocator.create([12]Coordinates);
    alive_coordinates_ptr.* = [_]Coordinates{
        .{ .x = 6, .y = 9 },
        .{ .x = 6, .y = 10 },
        .{ .x = 6, .y = 11 },
        .{ .x = 7, .y = 12 },
        .{ .x = 8, .y = 13 },
        .{ .x = 9, .y = 12 },
        .{ .x = 10, .y = 11 },
        .{ .x = 10, .y = 10 },
        .{ .x = 10, .y = 9 },
        .{ .x = 9, .y = 8 },
        .{ .x = 8, .y = 7 },
        .{ .x = 7, .y = 8 },
    };

    try game_of_life(stdout_writer, stdin_reader, .{ .alive = alive_coordinates_ptr });

    // try printAnotherMessage(stdout_writer);

    // try stdout_writer.flush(); // Don't forget to flush!
}
