# GBA Emulator — Technical Specification

## Overview

A Game Boy Advance emulator written in Zig, as a learning project. The goal is a working emulator that can run homebrew and commercial ROMs, built incrementally with each step introducing a new concept.

## Target hardware: Game Boy Advance

| Component | Specification |
|-----------|--------------|
| CPU | ARM7TDMI @ 16.78 MHz (2^24 Hz) |
| Instruction sets | ARM (32-bit) + Thumb (16-bit) |
| Display | 240 x 160 pixels, 15-bit color (RGB555) |
| EWRAM | 256 KB external work RAM |
| IWRAM | 32 KB internal work RAM (faster) |
| VRAM | 96 KB video RAM |
| Palette RAM | 1 KB (256 colors x 2 palettes) |
| OAM | 1 KB (128 sprites) |
| ROM | Max 32 MB (Game Pak) |
| SRAM | Max 64 KB (save data) |
| Audio | 2x DirectSound + 4x PSG channels |
| DMA | 4 channels |
| Timers | 4 units |

## Architecture

### Components and their responsibilities

```
┌─────────────────────────────────────────────────┐
│                    main.zig                      │
│            (main loop, SDL events)               │
└─────────────┬───────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────┐
│                    gba.zig                        │
│          (connects all components)                │
│                                                   │
│  ┌─────────┐  ┌──────────┐  ┌────────────────┐  │
│  │ cpu.zig  │  │ ppu.zig  │  │ scheduler.zig  │  │
│  │ arm.zig  │  │          │  │                │  │
│  │ thumb.zig│  │          │  │                │  │
│  └────┬─────┘  └────┬─────┘  └────────────────┘  │
│       │              │                            │
│  ┌────▼──────────────▼─────┐                     │
│  │        bus.zig           │                     │
│  │   (memory map + routing) │                     │
│  └──┬───┬───┬───┬───┬──────┘                     │
│     │   │   │   │   │                            │
│   BIOS EWRAM IWRAM VRAM  gamepak.zig             │
│                           io.zig                  │
│                           irq.zig                 │
│                           timer.zig               │
│                           dma.zig                 │
│                           apu.zig                 │
└───────────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────┐
│              platform/                            │
│  renderer.zig (SDL3 window + framebuffer)         │
│  audio.zig    (SDL3 audio output)                 │
└───────────────────────────────────────────────────┘
```

### Data flow

1. **Main loop** calls `gba.step()` — run 1 frame
2. **GBA** lets the scheduler determine how many cycles the CPU may run
3. **CPU** fetches an instruction via `bus.read32(pc)` (ARM) or `bus.read16(pc)` (Thumb)
4. **CPU** decodes and executes the instruction, reads/writes via the bus
5. **Bus** routes the address to the correct memory or I/O register
6. **Scheduler** fires events (PPU scanline, timer overflow, DMA, etc.)
7. **PPU** renders scanlines into a framebuffer
8. **Renderer** copies the framebuffer to the SDL window at VBlank

## Memory Map

```
Address             Size      Region          Access
────────────────────────────────────────────────────────
0x00000000-0x00003FFF  16 KB   BIOS            Read-only
0x02000000-0x0203FFFF  256 KB  EWRAM           R/W
0x03000000-0x03007FFF  32 KB   IWRAM           R/W
0x04000000-0x040003FE  1 KB    I/O Registers   R/W (per register)
0x05000000-0x050003FF  1 KB    Palette RAM     R/W
0x06000000-0x06017FFF  96 KB   VRAM            R/W
0x07000000-0x070003FF  1 KB    OAM             R/W
0x08000000-0x09FFFFFF  32 MB   ROM (Wait 0)    Read-only
0x0A000000-0x0BFFFFFF  32 MB   ROM (Wait 1)    Read-only (mirror)
0x0C000000-0x0DFFFFFF  32 MB   ROM (Wait 2)    Read-only (mirror)
0x0E000000-0x0E00FFFF  64 KB   SRAM            R/W (8-bit only)
```

- Address decoding via bits [27:24] → `(address >> 24) & 0xF`
- All regions mirror (address masking with region size)
- Little-endian byte ordering

## CPU — ARM7TDMI

### Registers
- R0-R12: general purpose
- R13 (SP): stack pointer (banked per mode)
- R14 (LR): link register (banked per mode)
- R15 (PC): program counter (+8 ARM, +4 Thumb due to pipeline)
- CPSR: flags (N,Z,C,V), mode bits, T bit (ARM/Thumb), interrupt disable bits
- SPSR: saved CPSR per exception mode

### Processor modes
| Mode | Bits | Banked registers |
|------|------|-----------------|
| User/System | 10000/11111 | — |
| FIQ | 10001 | R8-R14, SPSR |
| IRQ | 10010 | R13-R14, SPSR |
| Supervisor | 10011 | R13-R14, SPSR |
| Abort | 10111 | R13-R14, SPSR |
| Undefined | 11011 | R13-R14, SPSR |

### ARM instruction set (32-bit)
- All instructions conditional (bits [31:28])
- Data processing (ADD, SUB, MOV, CMP, AND, ORR, etc.)
- Branch (B, BL, BX)
- Load/Store (LDR, STR, LDRH, LDRB, etc.)
- Block transfer (LDM, STM)
- Multiply (MUL, MLA)
- Software interrupt (SWI)
- Status register transfer (MRS, MSR)

### Thumb instruction set (16-bit)
- More compact encoding, subset of ARM functionality
- Most instructions only work on R0-R7
- Higher code density, lower performance per instruction

## PPU (Pixel Processing Unit)

### Timing
- 1 scanline = 1232 cycles (960 draw + 272 HBlank)
- 160 visible scanlines + 68 VBlank scanlines = 228 total
- 1 frame = 228 x 1232 = 280896 cycles ≈ 59.73 fps

### Video modes
| Mode | Type | Backgrounds |
|------|------|-------------|
| 0 | Tiled | 4x text BG |
| 1 | Tiled | 2x text + 1x affine BG |
| 2 | Tiled | 2x affine BG |
| 3 | Bitmap | 1x 240x160 @ 15-bit |
| 4 | Bitmap | 2x 240x160 @ 8-bit (page flip) |
| 5 | Bitmap | 2x 160x128 @ 15-bit (page flip) |

### Rendering order (priority)
1. Sprites (per priority)
2. Backgrounds (per priority)
3. Backdrop color (palette[0])

### Features
- 128 sprites (OAM), 8x8 to 64x64 pixels
- Affine transformations (rotation/scaling) on BG and sprites
- Windowing (2 windows + OBJ window)
- Alpha blending and brightness fade

## Audio

### Direct Sound (2 channels)
- 8-bit signed PCM samples
- Fed by DMA (usually DMA1/DMA2)
- Timer-driven (usually Timer 0/1)

### PSG (4 channels, Game Boy compatible)
- Channel 1: square wave + sweep
- Channel 2: square wave
- Channel 3: wave RAM (4-bit samples)
- Channel 4: noise

## Interrupts

| IRQ | Bit | Source |
|-----|-----|--------|
| VBlank | 0 | PPU — start of vertical blank |
| HBlank | 1 | PPU — start of horizontal blank |
| VCount | 2 | PPU — scanline == LYC |
| Timer 0-3 | 3-6 | Timer overflow |
| Serial | 7 | Serial communication |
| DMA 0-3 | 8-11 | DMA transfer complete |
| Keypad | 12 | Key pressed |
| Game Pak | 13 | External (cartridge) |

### Interrupt flow
1. Hardware sets bit in IF (Interrupt Flag) register
2. If bit is also set in IE (Interrupt Enable) AND IME=1:
3. CPU switches to IRQ mode, jumps to 0x00000018 (BIOS IRQ handler)
4. BIOS jumps to address stored at 0x03007FFC

## DMA (4 channels)

- Channel 0: highest priority, internal only
- Channel 1-2: often used for audio (Direct Sound)
- Channel 3: general purpose, lowest priority
- Triggers: immediate, VBlank, HBlank, Sound FIFO

## Timers (4 units)

- 16-bit counters
- Prescaler: 1, 64, 256, 1024 cycles
- Cascade mode: timer increments on overflow of previous timer
- Overflow generates interrupt and can trigger DMA

## Save types

| Type | Size | Detection |
|------|------|-----------|
| SRAM | 32 KB | String "SRAM_V" in ROM |
| Flash 64K | 64 KB | String "FLASH_V" or "FLASH512_V" |
| Flash 128K | 128 KB | String "FLASH1M_V" |
| EEPROM | 512B/8KB | String "EEPROM_V" |

## Implementation order

See `.stories/README.md` for the complete order with stories.

### Milestone 1 — First pixels on screen
Stories 1.1 through 5.2 + 6.1, 7.1, 8.1: basic CPU + bus + Mode 3 PPU + input + interrupts.
Result: simple homebrew ROMs that draw something on screen.

### Milestone 2 — Playable games
Stories 9.1 through 13.1: timers, DMA, full PPU modes, BIOS HLE.
Result: commercial games boot and are playable.

### Milestone 3 — Compatibility
Stories 15.x through 17.x: accuracy improvements (wait states, prefetch, edge cases).
Result: >95% compatibility.

## References

- GBATEK (Martin Korth) — the definitive GBA hardware reference
- Tonc (J. Vijn) — GBA programming tutorial
- ARM7TDMI Technical Reference Manual — official CPU document
- mGBA, NanoBoyAdvance — reference emulators for comparison
