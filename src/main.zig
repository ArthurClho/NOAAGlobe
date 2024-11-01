const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});
const time = @cImport({
    @cInclude("time.h");
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

    pub fn log(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        const string = std.fmt.allocPrintZ(self.allocator, fmt, args) catch unreachable;
        self.entries.append(LogEntry.init(string)) catch unreachable;
    }

    const MESSAGE_TIMEOUT = 5.0;

    pub fn draw(self: *Logger) void {
        const bottom: usize = @intCast(rl.GetRenderHeight());

        const now = rl.GetTime();
        while (self.entries.items.len > 0) {
            const entry = self.entries.items[0];
            if (now - entry.time > MESSAGE_TIMEOUT) {
                self.allocator.free(entry.message);
                _ = self.entries.orderedRemove(0);
            } else {
                break;
            }
        }

        for (self.entries.items, 0..) |entry, index| {
            const y = bottom - (index + 1) * 20;

            var a: u8 = 255;
            const time_left = (entry.time + MESSAGE_TIMEOUT) - now;
            if (time_left < 1.0) {
                a = @intFromFloat(time_left * 255);
            }

            const color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = a };
            rl.DrawText(entry.message, 0, @intCast(y), 20, color);
        }
    }
};

fn get_datetime() *time.tm {
    var t: time.time_t = time.time(null);
    return time.gmtime(&t);
}

fn nomads_request_url() [:0]u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();

    const base = "https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_1p00.pl";

    const datetime = get_datetime();
    const dir = std.fmt.allocPrintZ(a, "gfs.{}{}{}", .{ datetime.tm_year + 1900, datetime.tm_mon + 1, datetime.tm_mday }) catch unreachable;
    const cycle = (@divFloor(datetime.tm_hour, 6) - 1) * 6;
    const file = std.fmt.allocPrintZ(a, "gfs.t{}z.pgrb2.1p00.f000", .{cycle}) catch unreachable;

    const string = std.fmt.allocPrintZ(a, "{s}?dir=%2F{s}%2F{}%2Fatmos&file={s}&var_TCDC=on&lev_entire_atmosphere=on", .{ base, dir, cycle, file }) catch unreachable;
    return string;
}

pub fn main() !void {
    try request.global_init();
    defer request.global_cleanup();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var logger = Logger.init(gpa.allocator());

    rl.SetTraceLogLevel(rl.LOG_ERROR);
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

    var response: ?*request.Response = null;

    while (!rl.WindowShouldClose()) {
        model.transform = rl.MatrixMultiply(rl.MatrixRotateZ(-0.5 * rl.DEG2RAD), model.transform);

        if (response) |r| {
            if (r.is_done()) {
                logger.log("Request done", .{});

                try std.io.getStdOut().writeAll(r.body.items);

                response = null;
            }
        } else if (rl.IsKeyPressed(rl.KEY_F)) {
            logger.log("Sending request", .{});
            response = try request.request(gpa.allocator(), nomads_request_url());
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
