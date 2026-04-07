---
status: done
epic: "01 - Project Setup"
---

# Story 1.1 — Zig project initialiseren

**Epic:** 01 - Project Setup & Infrastructuur

**Doel:** Een werkend Zig project met build configuratie.

## Zig concepten

### Hoe een Zig project werkt

Zig heeft geen `npm init` of `cargo init` achtig magic. Een project is gewoon:
- `build.zig` — een Zig-bestand dat beschrijft hoe je project gebouwd wordt
- `build.zig.zon` — metadata (naam, versie) in een simpel formaat
- `src/main.zig` — je code

### De entry point: `pub fn main()`

```zig
const std = @import("std");

pub fn main() void {
    std.debug.print("GBA Emulator\n", .{});
}
```

- `const std = @import("std")` — importeert de standaard library. **Waarom `const`?** In Zig is alles standaard immutable. Je *kunt* de standaard library niet veranderen, dus `const` is logisch.
- `pub fn main()` — de functie die Zig aanroept als je programma start
- `pub` = public, andere bestanden kunnen dit zien. **Waarom `pub`?** De Zig runtime moet `main` kunnen vinden — zonder `pub` is het onzichtbaar buiten het bestand.
- `void` = geeft niks terug
- `std.debug.print` — print naar stderr (handig voor debug output). **Waarom stderr en niet stdout?** Debug-output hoort op stderr zodat je de normale programma-uitvoer (stdout) schoon kunt pipen of redirecten.
- `.{}` — lege "tuple" voor format argumenten (net als `{}` in Python f-strings)

### Print met variabelen

```zig
const x: u32 = 42;
std.debug.print("waarde: {}\n", .{x});      // "waarde: 42"
std.debug.print("hex: 0x{x}\n", .{x});      // "hex: 0x2a"
std.debug.print("twee: {} {}\n", .{x, x});   // "twee: 42 42"
```

### build.zig.zon — package metadata

```zig
.{
    .name = .gba_emu,
    .version = "0.1.0",
    .fingerprint = 0xabcdef1234567890,
    .minimum_zig_version = "0.15.2",
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

- `.name` — de naam van je package als **identifier** (niet als string!). Gebruik underscores, geen streepjes: `.gba_emu` in plaats van `"gba-emu"`. Dit is een Zig enum literal, vandaar de punt-prefix en geen aanhalingstekens.
- `.version` — standaard semver versienummer
- `.fingerprint` — een uniek getal dat je package identificeert. Wordt automatisch gegenereerd door `zig build` als je het veld weglaat (de compiler suggereert een waarde). **Verplicht** sinds Zig 0.15.
- `.minimum_zig_version` — de minimale Zig versie die nodig is om te builden
- `.paths` — welke bestanden/mappen onderdeel zijn van je package (alles wat niet in deze lijst staat wordt genegeerd bij een `zig fetch`)

Dit bestand is vergelijkbaar met `package.json` in Node of `Cargo.toml` in Rust — het beschrijft *wat* je project is, terwijl `build.zig` beschrijft *hoe* het gebouwd wordt.

### build.zig basics

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gba-emu",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    // Dit maakt "zig build run" mogelijk
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the emulator");
    run_step.dependOn(&run_cmd.step);
}
```

Dit vertelt Zig: "bouw een executable genaamd `gba-emu` vanuit `src/main.zig`".

## Bestanden

- `build.zig` — definieert het build target als een executable
- `build.zig.zon` — package metadata (naam, versie)
- `src/main.zig` — bevat `pub fn main()`, print "GBA Emulator" naar stdout

## Stap-voor-stap

### Stap 1: `build.zig.zon` — package metadata aanmaken

Begin met het metadata-bestand, want `build.zig` verwijst impliciet naar dit bestand.

```zig
.{
    .name = .gba_emu,
    .version = "0.1.0",
    .fingerprint = 0xabcdef1234567890, // wordt automatisch gesuggereerd door compiler
    .minimum_zig_version = "0.15.2",
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

**Waarom `.name = .gba_emu` en niet `.name = "gba-emu"`?**
- In Zig 0.15+ is `.name` een **enum literal**, geen string. Gebruik underscores (`gba_emu`), geen streepjes.
- Als je per ongeluk een string gebruikt (`"gba-emu"`), krijg je een cryptische compilerfout. De punt-prefix (`.gba_emu`) geeft aan dat het een identifier is.

**Waarom `.fingerprint`?**
- Sinds Zig 0.15 is dit verplicht. Het is een uniek getal dat je package identificeert over meerdere versies heen. Als je het veld weglaat, zal `zig build` een foutmelding geven met een gesuggereerde waarde — kopieer die simpelweg.

**Waarom `.paths`?**
- Dit vertelt Zig welke bestanden bij je package horen. Alles buiten deze lijst wordt genegeerd bij `zig fetch`. Voor nu zijn `build.zig`, `build.zig.zon`, en de `src` map voldoende.

### Stap 2: `build.zig` — het build-systeem definiëren

Dit bestand is het hart van je Zig project. Het is zelf een Zig-programma dat beschrijft hoe je project gebouwd wordt:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gba-emu",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    // Dit maakt "zig build run" mogelijk
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the emulator");
    run_step.dependOn(&run_cmd.step);
}
```

**Waarom `b.standardTargetOptions(.{})` en `b.standardOptimizeOption(.{})`?**
- Deze functies laten je via de command line het target en optimization level kiezen, bijv. `zig build -Doptimize=ReleaseFast`. Zonder deze regels kun je alleen voor je eigen platform bouwen.
- De lege `.{}` struct betekent: gebruik de standaard defaults.

**Waarom `b.createModule(...)` in `addExecutable`?**
- In Zig 0.15+ is de API veranderd: je maakt eerst een module aan met de source file, target, en optimalisatie-opties, en geeft die als `.root_module` mee. Oudere tutorials gebruiken `.root_source_file` direct in `addExecutable` — dat werkt niet meer.

**Waarom `b.installArtifact(exe)`?**
- Dit zorgt ervoor dat `zig build` de executable kopieert naar `zig-out/bin/`. Zonder dit wordt het programma wel gebouwd maar nergens neergezet.

**Waarom `addRunArtifact` + `step`?**
- `addRunArtifact(exe)` maakt een run-actie die de executable draait.
- `b.step("run", ...)` registreert dit als een benoemd step.
- `run_step.dependOn(&run_cmd.step)` koppelt ze aan elkaar.
- Dit maakt het mogelijk om `zig build run` te gebruiken in plaats van handmatig `./zig-out/bin/gba-emu` te draaien.

### Stap 3: `src/main.zig` — de entry point

```zig
const std = @import("std");

pub fn main() void {
    std.debug.print("GBA Emulator\n", .{});
}
```

**Waarom `std.debug.print` en niet `std.io.getStdOut().writer().print(...)`?**
- `std.debug.print` schrijft naar **stderr** en vereist geen error handling — perfect voor snelle debug-output. De "echte" stdout-writer vereist `try` en is meer code voor hetzelfde resultaat op dit moment.

**Waarom `.{}` als tweede argument?**
- `std.debug.print` werkt net als `printf` in C, maar met Zig's format syntax. Het tweede argument is een **anonymous struct** (tuple) met de waarden die in de `{}` placeholders komen. Geen placeholders? Dan een lege tuple: `.{}`.

**Let op:** `pub fn main() void` vs `pub fn main() !void`:
- `void` = deze functie kan niet falen
- `!void` = deze functie kan een error teruggeven (nodig zodra je `try` gebruikt in main)
- We beginnen met `void` omdat we nog geen error handling nodig hebben. In Story 1.3 schakelen we over naar `!void` wanneer we bestanden gaan lezen.

### Stap 4: bouwen en testen

```bash
# Bouw het project
zig build

# Controleer of de executable bestaat
ls zig-out/bin/gba-emu

# Draai het programma
zig build run
```

**Verwachte output:**
```
GBA Emulator
```

**Veelvoorkomende problemen:**
- **"error: FileNotFound"** bij `zig build` → controleer of `src/main.zig` op het juiste pad staat
- **Fout in `build.zig.zon`** over fingerprint → laat het veld weg, draai `zig build`, en kopieer de gesuggereerde waarde
- **"root_source_file" deprecated warning** → je gebruikt een oudere API. In Zig 0.15+ moet je `b.createModule(...)` gebruiken (zie Stap 2)

## Acceptatiecriteria

- `zig build run` compileert en runt zonder errors
