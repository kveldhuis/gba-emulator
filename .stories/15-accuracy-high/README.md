# Accuracy Improvements — Hoge Impact

Deze stories brengen je van ~85% naar ~95% game-compatibiliteit. Focus op timing en effecten die veel commerciële games gebruiken.

## Volgorde

| # | Story | Impact |
|---|-------|--------|
| 1 | [15.1 — Wait States](15.1-wait-states.md) | Correcte cycle-counting per geheugenregio |
| 2 | [15.2 — Prefetch Buffer](15.2-prefetch-buffer.md) | ROM access timing, voorkomt hangs |
| 3 | [15.3 — DMA Timing](15.3-dma-timing.md) | DMA steelt CPU-cycles, audio timing |
| 4 | [15.4 — Mid-scanline Effecten](15.4-mid-scanline.md) | Raster effects (wavey BG, kleur-cycling) |
| 5 | [15.5 — Mosaic](15.5-mosaic.md) | Pixelated effect voor BG en sprites |

## Wanneer beginnen?

Start hiermee nadat de basis-emulator werkt (alle stories 01-14). Test eerst met homebrew ROMs en simpele commerciële games. Als je merkt dat games hangen of timing-problemen hebben, zijn dit de eerste dingen om te verbeteren.
