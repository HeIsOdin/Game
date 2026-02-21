# Vibe Dodger (Nintendo 64 Homebrew)

A survival arcade game ROM for Nintendo 64.

## Gameplay

- **Start screen**: press **START** to begin.
- Move the green player square (D-pad or analog stick).
- Avoid 4 red enemy squares.
- Grab yellow pickups for bonus score.
- Survive as speed ramps up.
- You have 3 lives; press **START** on game over to restart.

## Build

```bash
cd n64-vibe
./build_rom.sh
```

Outputs:

- `n64-vibe/dist/VibeDodger.z64` (canonical big-endian ROM)
- `n64-vibe/dist/VibeDodger.n64` (little-endian word-swapped image generated from the `.z64`)

## ROM header / CIC / checksum notes

`build_rom.sh` now:

- requires a known-good IPL3 bootcode source (`N64_DONOR_ROM` or `N64_IPL3`) so CIC detection matches a real boot ROM,
- links and writes a homebrew-friendly entrypoint (`0x80000400`) in both linker script and ROM header,
- writes header fields at canonical offsets (manufacturer at `0x3B`, cart/game code at `0x3C..0x3D`),
- computes and writes valid N64 CRC1/CRC2 values for the final image,
- emits `.z64` first, then derives `.n64` by deterministic word-byte swapping,
- prints a validation summary (image type, entrypoint, header fields, IPL3 CRC32/CIC match, CRC1/CRC2).

Provide a real IPL3 via one of:

```bash
N64_DONOR_ROM=/path/to/known-good.z64 ./build_rom.sh
# or
N64_IPL3=/path/to/ipl3_6102.bin ./build_rom.sh
```

If neither variable is set, the build now fails immediately to avoid producing malformed/ambiguous ROM images.

Optional header overrides:

```bash
N64_COUNTRY=E N64_GAME_CODE=VD N64_MAKER_CODE=N N64_VERSION=0 ./build_rom.sh
```

## Parallel-RDP Intel Iris Xe option

To emit a RetroArch core-options snippet that disables Parallel-RDP small-type arithmetic paths:

```bash
PARALLEL_RDP_NO_SMALL_TYPES=1 ./build_rom.sh
```

This writes `dist/retroarch-parallel-rdp-intel-iris-xe.opt`. Import/copy it into your RetroArch core override path and adjust key names if your installed core uses a slightly different option label.

Generated files under `build/` and `dist/` are intentionally git-ignored so PRs only contain source/tooling changes.
