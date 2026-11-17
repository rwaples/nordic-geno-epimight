"""Fail when a DLL under the given folder has 32-bit MinGW runtime pseudo-relocations.

Such a DLL reaches another DLL's code or data through a 32-bit offset that the MinGW
runtime patches at load time; when Windows maps the two more than 2 GB apart the process
dies with "32 bit pseudo relocation ... out of range". conda-forge's Matrix 1.7-6 had 91
of them (kit/setup.R rebuilds it from source on Windows).

The table (v2) is three 32-bit words 0, 0, 1, then 12-byte entries: symbol RVA, patched
RVA, flags (the patch width in bits). A patched RVA below 0x1000 is in the PE headers,
never code, so a run of words that only looks like a table is skipped.
"""

import struct
import sys
from pathlib import Path

HEADER = struct.pack("<III", 0, 0, 1)


def image_size(data: bytes) -> int:
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    return struct.unpack_from("<I", data, pe + 24 + 56)[0]


def narrow_entries(data: bytes) -> list[tuple[int, int, int]]:
    image = image_size(data)
    found, start = [], 0
    while (i := data.find(HEADER, start)) != -1:
        start, j = i + 4, i + 12
        while j + 12 <= len(data):
            sym, target, flags = struct.unpack_from("<III", data, j)
            if flags not in (8, 16, 32, 64) or not (0 < sym < image) or not (0x1000 <= target < image):
                break
            if flags < 64:
                found.append((sym, target, flags))
            j += 12
    return found


def main(root: Path) -> int:
    bad = 0
    for dll in sorted(root.rglob("*.dll")):
        try:
            data = dll.read_bytes()
            if data[:2] != b"MZ":
                continue
            narrow = narrow_entries(data)
        except (OSError, struct.error):
            continue
        if narrow:
            bad += 1
            print(f"{dll.relative_to(root)}: {len(narrow)} 32-bit pseudo-relocations, at "
                  + ", ".join(hex(t) for _, t, _ in narrow[:6]))
    print(f"{bad} DLL(s) with 32-bit pseudo-relocations under {root}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1])))
