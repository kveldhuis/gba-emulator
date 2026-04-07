const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const Renderer = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,

    pub fn init() Renderer {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) @panic("Cannot initialize SDL");
        const window = c.SDL_CreateWindow("GBA Emulator", 720, 480, 0) orelse @panic("Cannot create SDL window");
        const renderer = c.SDL_CreateRenderer(window, null) orelse @panic("Cannot create SDL renderer");
        const texture = c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_ABGR1555, c.SDL_TEXTUREACCESS_STREAMING, 240, 160) orelse @panic("Cannot create SDL texture");

        return Renderer{ .window = window, .renderer = renderer, .texture = texture };
    }

    pub fn deinit(self: *Renderer) void {
        c.SDL_DestroyTexture(self.texture);
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn processEvents() bool {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) return false;
            if (event.type == c.SDL_EVENT_KEY_DOWN and event.key.key == c.SDLK_ESCAPE) return false;
        }

        return true;
    }

    pub fn present(self: *Renderer) void {
        _ = c.SDL_RenderPresent(self.renderer);
        c.SDL_Delay(16);
    }
};
