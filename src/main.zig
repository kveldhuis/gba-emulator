const std = @import("std");
const platform = @import("platform/renderer.zig");

pub fn main() void {
    var renderer = platform.Renderer.init();
    defer renderer.deinit();

    while (platform.Renderer.processEvents()) {
        renderer.present();
    }
}
