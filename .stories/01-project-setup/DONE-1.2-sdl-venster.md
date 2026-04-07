---
status: done
epic: "01 - Project Setup"
---

# Story 1.2 — SDL3 venster openen

**Epic:** 01 - Project Setup & Infrastructuur

**Doel:** Een venster van 240x160 (of geschaald, bijv. 720x480) tonen.

## Zig concepten

### Structs — data groeperen

Een struct is een manier om gerelateerde data bij elkaar te zetten, vergelijkbaar met een class in andere talen maar zonder inheritance.

```zig
const Renderer = struct {
    window: *SDL_Window,
    renderer: *SDL_Renderer,
    texture: *SDL_Texture,

    pub fn init() Renderer {
        // maak alles aan...
        return Renderer{
            .window = window,
            .renderer = renderer,
            .texture = texture,
        };
    }

    pub fn deinit(self: *Renderer) void {
        // ruim alles op...
    }
};
```

- `self: *Renderer` — een pointer naar de struct zelf (zoals `this` in andere talen)
- `*` voor een type = pointer (verwijzing naar geheugen)
- De `.field = value` syntax is hoe je struct velden initialiseert

### defer — opruimen garanderen

```zig
pub fn main() void {
    var renderer = Renderer.init();
    defer renderer.deinit();  // wordt ALTIJD uitgevoerd als main() eindigt

    // ... rest van je code
    // ook als er een error is, deinit() wordt aangeroepen
}
```

`defer` is als een belofte: "als deze functie klaar is (hoe dan ook), voer dit uit". Perfect voor cleanup.

### While loops

```zig
var running = true;
while (running) {
    // poll SDL events
    // render frame
}
```

### C libraries gebruiken vanuit Zig

SDL3 is een C library. Zig kan C code direct aanroepen:

```zig
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

// Nu kun je C functies aanroepen:
_ = c.SDL_Init(c.SDL_INIT_VIDEO);
const window = c.SDL_CreateWindow("GBA Emu", 720, 480, 0);
```

In `build.zig` moet je SDL3 linken:
```zig
exe.root_module.linkSystemLibrary("SDL3");
exe.root_module.linkLibC();
```

## Bestanden

- `src/platform/renderer.zig` — SDL3 init, window create, renderer create, cleanup
  - `pub fn init() Renderer` — initialiseert SDL, maakt window + renderer + texture
  - `pub fn processEvents() bool` — pollt SDL events, geeft `false` terug bij quit/escape
  - `pub fn present(self: *Renderer) void` — tekent frame naar scherm + delay voor ~60fps
  - `pub fn deinit(self: *Renderer) void` — ruimt SDL resources op in omgekeerde volgorde
- `src/main.zig` — gebruikt Renderer, draait een loop die het venster open houdt

## Stap-voor-stap

### Stap 1: `build.zig` — SDL3 linken

SDL3 linken kan via `linkSystemLibrary` op de root module, en `link_libc = true` in de module options:

```zig
exe.root_module.linkSystemLibrary("SDL3", .{ .preferred_link_mode = .dynamic });
```

- `linkSystemLibrary("SDL3")` — zoekt SDL3 op je systeem (via Homebrew) en linkt het
- `link_libc = true` — SDL3 is geschreven in C, dus je hebt de C standaard library nodig

### Stap 2: `src/platform/renderer.zig` — SDL functies invullen

**`init()`** — SDL werkt in stappen:

1. **`SDL_Init(c.SDL_INIT_VIDEO)`** — geeft een `bool` terug in SDL3 (`true` = succes). Check met `!`:
   ```zig
   if (!c.SDL_Init(c.SDL_INIT_VIDEO)) @panic("Cannot initialize SDL");
   ```
2. **`SDL_CreateWindow`** — geeft een nullable pointer terug. In SDL3 zijn de x/y positie-parameters verwijderd:
   ```zig
   const window = c.SDL_CreateWindow("GBA Emulator", 720, 480, 0) orelse @panic("...");
   ```
3. **`SDL_CreateRenderer(window, null)`** — neemt een optionele driver naam i.p.v. een index. `null` = eerste beschikbare.
4. **`SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_ABGR1555, c.SDL_TEXTUREACCESS_STREAMING, 240, 160)`** — zelfde patroon met `orelse`

**Let op:** `SDL_Init` vs de rest — `SDL_Init` geeft een bool terug (check met `!`), de andere functies geven nullable pointers terug (check met `orelse`).

**`deinit(self: *Renderer)`** — ruim op in omgekeerde volgorde (texture → renderer → window → quit).

**`processEvents()`** — geen `self` parameter nodig, want `SDL_PollEvent` is globaal:

```zig
pub fn processEvents() bool {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        if (event.type == c.SDL_EVENT_QUIT) return false;
        if (event.type == c.SDL_EVENT_KEY_DOWN and event.key.key == c.SDLK_ESCAPE) return false;
    }
    return true;
}
```

**`present(self: *Renderer)`** — tekent het frame en wacht ~16ms voor ~60fps:

```zig
pub fn present(self: *Renderer) void {
    c.SDL_RenderPresent(self.renderer);
    c.SDL_Delay(16);
}
```

### Stap 3: `src/main.zig` — schone main loop

```zig
const platform = @import("platform/renderer.zig");

pub fn main() void {
    var renderer = platform.Renderer.init();
    defer renderer.deinit();

    while (platform.Renderer.processEvents()) {
        renderer.present();
    }
}
```

**Waarom `platform.Renderer.processEvents()` vs `renderer.present()`?**
- `processEvents()` heeft geen `self` → aanroepen via het type
- `present()` heeft `self: *Renderer` → aanroepen via de instantie

## Acceptatiecriteria

- Een zwart venster van 720x480 opent en blijft open tot je het sluit
- Sluiten via kruisje of Escape werkt
