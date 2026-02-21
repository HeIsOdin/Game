#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build dist

CLANG=${CLANG:-clang}

$CLANG --target=mips64-unknown-elf -c -O2 -ffreestanding -fno-pic -mabi=n64 -march=mips3 -mno-abicalls -G0 src/main.c -o build/main.o
$CLANG --target=mips64-unknown-elf -c -O2 -ffreestanding -fno-pic -mabi=n64 -march=mips3 -mno-abicalls -G0 src/start.S -o build/start.o
ld.lld -m elf64btsmip -T linker.ld -e _start build/start.o build/main.o -o build/game.elf
llvm-objcopy -O binary build/game.elf build/game.bin

python3 - <<'PY'
import os
import struct
from pathlib import Path

ROM_NAME = os.environ.get('ROM_NAME', 'VIBE DODGER')
COUNTRY_CODE = os.environ.get('N64_COUNTRY', 'E')  # E = North America/NTSC
GAME_CODE = os.environ.get('N64_GAME_CODE', 'VD')
MAKER_CODE = os.environ.get('N64_MAKER_CODE', 'N')
ROM_VERSION = int(os.environ.get('N64_VERSION', '0'), 0) & 0xFF
DONOR_ROM = os.environ.get('N64_DONOR_ROM')
IPL3_PATH = os.environ.get('N64_IPL3')
PARALLEL_RDP_NO_SMALL_TYPES = os.environ.get('PARALLEL_RDP_NO_SMALL_TYPES', '').strip().lower() in {'1', 'true', 'yes', 'on'}

KNOWN_CIC_BY_IPL3_CRC32 = {
    0x6170A4A1: 'CIC-NUS-6101',
    0x90BB6CB5: 'CIC-NUS-6102',
    0x0B050EE0: 'CIC-NUS-6103',
    0x98BC2C86: 'CIC-NUS-6105',
    0xACC8580A: 'CIC-NUS-6106',
}


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


def load_ipl3(root: Path) -> bytes:
    if IPL3_PATH:
        ipl3 = Path(IPL3_PATH).read_bytes()
        if len(ipl3) < 0xFC0:
            raise SystemExit(f'N64_IPL3 must contain at least 0xFC0 bytes, got {len(ipl3):#x}')
        return ipl3[:0xFC0]

    if DONOR_ROM:
        donor = Path(DONOR_ROM).read_bytes()
        if len(donor) < 0x1000:
            raise SystemExit(f'N64_DONOR_ROM is too small ({len(donor):#x}); expected full ROM image')

        # Accept .z64/.n64/.v64 input and normalize to big-endian first.
        magic = donor[0:4]
        if magic == b'\x80\x37\x12\x40':
            z64 = donor
        elif magic == b'\x40\x12\x37\x80':  # .n64 little-endian words
            z64 = bytearray(len(donor))
            for i in range(0, len(donor), 4):
                z64[i:i+4] = donor[i:i+4][::-1]
            z64 = bytes(z64)
        elif magic == b'\x37\x80\x40\x12':  # .v64 byte-swapped halfwords
            z64 = bytearray(len(donor))
            for i in range(0, len(donor), 2):
                z64[i:i+2] = donor[i:i+2][::-1]
            z64 = bytes(z64)
        else:
            raise SystemExit('N64_DONOR_ROM has unknown byte order/magic; expected z64/n64/v64 ROM')

        return z64[0x40:0x1000]

    raise SystemExit(
        'A known-good IPL3 is required. Set N64_DONOR_ROM (preferred) or N64_IPL3 '
        'so CIC detection and boot sequencing are valid on emulators/hardware.'
    )


def detect_image_type(rom: bytes) -> str:
    magic = rom[0:4]
    if magic == b'\x80\x37\x12\x40':
        return 'z64 (big-endian)'
    if magic == b'\x40\x12\x37\x80':
        return 'n64 (word-swapped little-endian)'
    if magic == b'\x37\x80\x40\x12':
        return 'v64 (byte-swapped halfwords)'
    return f'unknown ({magic.hex()})'


root = Path('.')
bin_data = (root / 'build/game.bin').read_bytes()
bootcode = load_ipl3(root)

header = bytearray(0x40)
struct.pack_into('>I', header, 0x00, 0x80371240)    # PI BSD Domain 1 register
struct.pack_into('>I', header, 0x04, 0x0000000F)    # Clock rate
struct.pack_into('>I', header, 0x08, 0x80000400)    # Entry point (common homebrew start)
struct.pack_into('>I', header, 0x0C, 0x00001444)    # Release offset

name = ROM_NAME.encode('ascii', errors='ignore')[:20]
header[0x20:0x34] = name.ljust(20, b' ')
# Manufacturer field is 32-bit at 0x38..0x3B; for homebrew set low byte to 'N'.
header[0x3B] = ord(MAKER_CODE[0])
# Game code/cartridge ID is 0x3C..0x3D.
header[0x3C:0x3E] = GAME_CODE.encode('ascii', errors='ignore')[:2].ljust(2, b'0')
header[0x3E] = ord(COUNTRY_CODE[0])
header[0x3F] = ROM_VERSION

rom = bytearray(header + bootcode + bin_data)
min_size = max(2 * 1024 * 1024, 0x101000)
if len(rom) < min_size:
    rom.extend(b'\x00' * (min_size - len(rom)))

crc1, crc2 = crc6102(rom)
struct.pack_into('>I', rom, 0x10, crc1)
struct.pack_into('>I', rom, 0x14, crc2)

(root / 'dist/VibeDodger.z64').write_bytes(rom)

# `.n64` is little-endian word order.
n64 = bytearray(len(rom))
for i in range(0, len(rom), 4):
    n64[i:i+4] = rom[i:i+4][::-1]
(root / 'dist/VibeDodger.n64').write_bytes(n64)

if PARALLEL_RDP_NO_SMALL_TYPES:
    (root / 'dist/retroarch-parallel-rdp-intel-iris-xe.opt').write_text(
        '\n'.join([
            'mupen64plus-Next-gfxplugin = "parallel"',
            'mupen64plus-Next-parallel-rdp-allow-small-types = "disabled"',
            '',
        ])
    )

import zlib

entry = struct.unpack_from('>I', rom, 0x08)[0]
manufacturer = struct.unpack_from('>I', rom, 0x38)[0]
cart_id = rom[0x3C:0x3E].decode('ascii', errors='replace')
country = chr(rom[0x3E])
version = rom[0x3F]
image_name = rom[0x20:0x34].decode('ascii', errors='replace').rstrip()
ipl3_crc32 = zlib.crc32(rom[0x40:0x1000]) & 0xFFFFFFFF
cic_name = KNOWN_CIC_BY_IPL3_CRC32.get(ipl3_crc32, 'UNKNOWN')

print(f'Wrote ROMs: {len(rom)} bytes')
print(f'Validation: type={detect_image_type(rom)}, entry=0x{entry:08X}, name="{image_name}"')
print(f'Validation: manufacturer=0x{manufacturer:08X}, cart_id={cart_id}, country={country}, version={version}')
print(f'Validation: IPL3 CRC32=0x{ipl3_crc32:08X} ({cic_name}), CRC1=0x{crc1:08X}, CRC2=0x{crc2:08X}')

if cic_name == 'UNKNOWN':
    print('WARNING: IPL3 does not match known CIC fingerprints; emulator may fall back to guessed CIC behavior.')
PY
