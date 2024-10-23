const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub fn main() !void {
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

        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        rl.BeginMode3D(camera);
        rl.DrawModel(model, globe_position, 1.0, rl.WHITE);
        rl.EndMode3D();
        rl.EndDrawing();
    }
}
