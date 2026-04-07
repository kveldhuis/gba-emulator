# GBA Emulator — Stories

## Beoogde bestandsstructuur

```
src/
├── main.zig              # Entry point, main loop, window
├── core/
│   ├── gba.zig           # GBA struct: verbindt alle componenten
│   ├── cpu.zig           # ARM7TDMI CPU state + step logic
│   ├── arm.zig           # ARM (32-bit) instructie decoding & executie
│   ├── thumb.zig         # Thumb (16-bit) instructie decoding & executie
│   ├── bus.zig           # Memory bus: adres → juiste geheugenregio
│   ├── ppu.zig           # Pixel Processing Unit (graphics)
│   ├── apu.zig           # Audio Processing Unit (geluid)
│   ├── dma.zig           # DMA controller (4 kanalen)
│   ├── timer.zig         # Timer controller (4 timers)
│   ├── io.zig            # I/O register reads/writes dispatcher
│   ├── irq.zig           # Interrupt controller
│   ├── scheduler.zig     # Event scheduler voor timing
│   └── gamepak.zig       # ROM laden, header parsen, save types
└── platform/
    ├── renderer.zig      # SDL venster + framebuffer renderen
    └── audio.zig         # SDL audio output
```

## Aanbevolen implementatievolgorde

| # | Epic | Stories |
|---|------|---------|
| 1 | [01 - Project Setup](01-project-setup/) | 1.1, 1.2, 1.3, 1.4, 1.5 |
| 2 | [02 - Memory Bus](02-memory-bus/) | 2.1, 2.2 |
| 3 | [03 - CPU ARM](03-cpu-arm/) | 3.1 t/m 3.11 |
| 4 | [04 - CPU Thumb](04-cpu-thumb/) | 4.1 t/m 4.12 |
| 5 | [12 - Scheduler](12-scheduler/) | 12.1 |
| 6 | [06 - I/O Registers](06-io-registers/) | 6.1 |
| 7 | [05 - PPU](05-ppu/) | 5.1, 5.2 (begin met Mode 3) |
| 8 | [07 - Input](07-input/) | 7.1 |
| 9 | [08 - Interrupts](08-interrupts/) | 8.1 |
| 10 | [13 - BIOS](13-bios/) | 13.1 |
| 11 | [09 - Timers](09-timers/) | 9.1 |
| 12 | [10 - DMA](10-dma/) | 10.1 |
| 13 | [05 - PPU](05-ppu/) | 5.3 t/m 5.8 (rest, incl. affine sprites) |
| 14 | [02 - Memory Bus](02-memory-bus/) | 2.3 (save types: Flash/EEPROM) |
| 15 | [11 - Audio](11-audio/) | 11.1, 11.2 |
| 16 | [14 - Cross-Platform](14-cross-platform/) | 14.1 |

### Eerste testbare milestone

Na stap 1-9 kun je simpele homebrew ROMs draaien die iets op het scherm tekenen. Story 1.4 (testing) en 1.5 (debug tooling) helpen je om van begin af aan fouten op te sporen.

## Accuracy verbeteren (optioneel)

Na de basis-emulator kun je stapsgewijs de compatibiliteit verhogen:

| Folder | Impact | Compatibiliteit |
|--------|--------|-----------------|
| [15 - Hoge Impact](15-accuracy-high/) | Wait states, prefetch, DMA timing, raster effects, mosaic | ~85% → ~95% |
| [16 - Medium Impact](16-accuracy-medium/) | RTC, open bus, sprite edge cases, BIOS protection | ~95% → ~98% |
| [17 - Lage Impact](17-accuracy-low/) | Serial/sensors, cycle-exact PPU | ~98% → ~99%+ |
