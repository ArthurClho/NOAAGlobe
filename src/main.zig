const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const request = @import("./request.zig");

const LogEntry = struct {
    message: [:0]u8,
    time: f64,

    pub fn init(message: [:0]u8) LogEntry {
        return LogEntry{
            .message = message,
            .time = rl.GetTime(),
        };
    }
};

const Logger = struct {
    entries: std.ArrayList(LogEntry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Logger {
        return Logger{ .entries = std.ArrayList(LogEntry).init(allocator), .allocator = allocator };
    }

    pub fn log(self: *Logger, comptime fmt: []const u8, args: anytype) !void {
        const string = try std.fmt.allocPrintZ(self.allocator, fmt, args);
        try self.entries.append(LogEntry.init(string));
    }

    pub fn draw(self: *Logger) void {
        const bottom: usize = @intCast(rl.GetRenderHeight());

        const now = rl.GetTime();
        while (self.entries.items.len > 0) {
            const entry = self.entries.items[0];
            if (now - entry.time > 1.0) {
                self.allocator.free(entry.message);
                _ = self.entries.orderedRemove(0);
            } else {
                break;
            }
        }

        for (self.entries.items, 0..) |entry, index| {
            const y = bottom - (index + 1) * 20;
            rl.DrawText(entry.message, 0, @intCast(y), 20, rl.RAYWHITE);
        }
    }
};

pub fn main() !void {
    try request.global_init();
    defer request.global_cleanup();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var logger = Logger.init(gpa.allocator());

    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(600, 600, "NOAAGlobe");
    rl.SetTargetFPS(60);

    const texture = rl.LoadTexture("./earthmap1k.png");

    const mesh = rl.GenMeshSphere(3, 32, 32);
    var model = rl.LoadModelFromMesh(mesh);
    model.materials[0].maps[rl.MATERIAL_MAP_DIFFUSE].texture = texture;

    var camera = rl.Camera3D{};
    camera.position = .{ .x = 2.0, .y = 2.0, .z = 10.0 };
    camera.target = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    camera.up = .{ .x = 0.0, .y = 1.0, .z = 0.0 };
    camera.fovy = 45.0;
    camera.projection = rl.CAMERA_PERSPECTIVE;

    const globe_position = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    model.transform = rl.MatrixMultiply(rl.MatrixRotateX(-90 * rl.DEG2RAD), model.transform);

    while (!rl.WindowShouldClose()) {
        model.transform = rl.MatrixMultiply(rl.MatrixRotateZ(-0.5 * rl.DEG2RAD), model.transform);

        if (rl.IsKeyPressed(rl.KEY_F)) {
            try logger.log("asdassdasdsad", .{});
        }

        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        rl.BeginMode3D(camera);
        rl.DrawModel(model, globe_position, 1.0, rl.WHITE);
        rl.EndMode3D();

        logger.draw();

        rl.EndDrawing();
    }
}
