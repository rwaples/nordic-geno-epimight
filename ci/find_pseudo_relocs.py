"""Fail when a DLL under the given folder has 32-bit MinGW runtime pseudo-relocations.

Such a DLL reaches another DLL's code or data through a 32-bit offset that the MinGW
runtime patches at load time; when Windows maps the two more than 2 GB apart the process
dies with "32 bit pseudo relocation ... out of range". conda-forge's Matrix 1.7-6 had 91
of them (kit/setup.R rebuilds it from source on Windows).

The table (v2) is three 32-bit words 0, 0, 1, then 12-byte entries: symbol RVA, patched
RVA, flags (the patch width in bits). The linker puts it in .rdata, word-aligned, so only
the data sections are searched, at 4-byte steps; a patched RVA below 0x1000 is in the PE
headers, never code, so a run of words that only looks like a table is skipped.
"""

import struct
import sys
from pathlib import Path

HEADER = struct.pack("<III", 0, 0, 1)


def layout(data: bytes) -> tuple[int, list[tuple[int, int]]]:
    """The image size and the (start, end) file offsets of the .rdata and .data sections."""
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    nsec = struct.unpack_from("<H", data, pe + 6)[0]
    optional = struct.unpack_from("<H", data, pe + 20)[0]
    image = struct.unpack_from("<I", data, pe + 24 + 56)[0]
    ranges = []
    for k in range(nsec):
        name, _, _, size, raw = struct.unpack_from("<8sIIII", data, pe + 24 + optional + 40 * k)
        if name.rstrip(b"\0") in (b".rdata", b".data"):
            ranges.append((raw, min(raw + size, len(data))))
    return image, ranges


def narrow_entries(data: bytes) -> list[tuple[int, int, int]]:
    image, ranges = layout(data)
    found = []
    for start, end in ranges:
        i = start - 1
        while (i := data.find(HEADER, i + 1, end)) != -1:
            if (i - start) % 4:
                continue
            j = i + 12
            while j + 12 <= end:
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
