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

- populates a non-zero 0x40..0xFFF bootcode area (IPL3 region),
- computes and writes valid N64 CRC1/CRC2 values for the final image,
- writes consistent header fields (title, maker code, game code, country code, version),
- emits `.z64` first, then derives `.n64` by byte-order conversion.

For best CIC detection in emulators, pass a real IPL3 via one of:

```bash
N64_DONOR_ROM=/path/to/known-good.z64 ./build_rom.sh
# or
N64_IPL3=/path/to/ipl3_6102.bin ./build_rom.sh
```

If neither variable is set, the script still builds a ROM with non-zero synthetic bootcode and valid CRCs, but some emulators may still report unknown CIC and fall back to 6102 behavior.

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
