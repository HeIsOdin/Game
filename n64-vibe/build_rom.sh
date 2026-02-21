#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build dist

CLANG=${CLANG:-clang}

$CLANG --target=mips64-unknown-elf -c -O2 -ffreestanding -fno-pic -mabi=n64 -march=mips3 -mno-abicalls src/main.c -o build/main.o
ld.lld -m elf64btsmip -T linker.ld -e _start build/main.o -o build/game.elf
llvm-objcopy -O binary build/game.elf build/game.bin

python3 - <<'PY'
import struct
from pathlib import Path

def rol32(v: int, s: int) -> int:
    s &= 31
    return ((v << s) | (v >> (32 - s))) & 0xFFFFFFFF

def crc6102(rom: bytes) -> tuple[int, int]:
    seed = 0xF8CA4DDC
    t1 = t2 = t3 = t4 = t5 = t6 = seed
    for i in range(0x1000, 0x101000, 4):
        d = struct.unpack_from('>I', rom, i)[0]
        if (t6 + d) & 0xFFFFFFFF < t6:
            t4 = (t4 + 1) & 0xFFFFFFFF
        t6 = (t6 + d) & 0xFFFFFFFF
        t3 ^= d
        r = rol32(d, d & 0x1F)
        t5 = (t5 + r) & 0xFFFFFFFF
        if t2 > d:
            t2 ^= r
        else:
            t2 ^= (t6 ^ d) & 0xFFFFFFFF
        t1 = (t1 + (t5 ^ d)) & 0xFFFFFFFF
    crc1 = (t6 ^ t4 ^ t3) & 0xFFFFFFFF
    crc2 = (t5 ^ t2 ^ t1) & 0xFFFFFFFF
    return crc1, crc2

root = Path('.')
bin_data = (root/'build/game.bin').read_bytes()

header = bytearray(0x40)
struct.pack_into('>I', header, 0x00, 0x80371240)
struct.pack_into('>I', header, 0x04, 0x0000000F)
struct.pack_into('>I', header, 0x08, 0x80001000)
struct.pack_into('>I', header, 0x0C, 0x00001444)
name = b'VIBE DODGER         '
header[0x20:0x20+20] = name[:20]
header[0x3B:0x3F] = b'NVD\x00'

bootcode = bytes(0xFC0)
rom = bytearray(header + bootcode + bin_data)
min_size = max(2 * 1024 * 1024, 0x101000)
if len(rom) < min_size:
    rom.extend(b'\x00' * (min_size - len(rom)))

crc1, crc2 = crc6102(rom)
struct.pack_into('>I', rom, 0x10, crc1)
struct.pack_into('>I', rom, 0x14, crc2)

(root/'dist/VibeDodger.z64').write_bytes(rom)
(root/'dist/VibeDodger.n64').write_bytes(rom)
print(f'Wrote ROMs: {len(rom)} bytes, CRC1={crc1:08X}, CRC2={crc2:08X}')
PY
