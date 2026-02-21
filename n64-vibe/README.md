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

- `n64-vibe/dist/VibeDodger.z64`
- `n64-vibe/dist/VibeDodger.n64` (proper little-endian word-swapped image)

## Emulator compatibility

The build script now writes CIC-6102-style ROM CRC values in the header to improve loader compatibility (including Parallel Launcher workflows).

Generated files under `build/` and `dist/` are intentionally git-ignored so PRs only contain source/tooling changes.
