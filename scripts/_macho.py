"""Shared Mach-O parsing primitives for the reproducible-build scripts.

Handles both thin 64-bit Mach-O files and fat/universal binaries (some
vendored system dylibs, e.g. libswiftCompatibilitySpan.dylib, ship as
arm64+arm64e universal binaries even though this project's own ARCHS is
arm64-only).
"""

import os
import struct

MH_MAGIC_64 = 0xFEEDFACF
MH_CIGAM_64 = 0xCFFAEDFE
FAT_MAGIC = 0xCAFEBABE
FAT_CIGAM = 0xBEBAFECA
LC_SEGMENT_64 = 0x19
LC_UUID = 0x1B

CPU_TYPE_ARM64 = 0x0100000C
CPU_SUBTYPE_ARM64E = 2
CPU_SUBTYPE_MASK = 0x00FFFFFF


def _endian_for_magic(magic):
    if magic == MH_MAGIC_64:
        return "<"
    if magic == MH_CIGAM_64:
        return ">"
    return None


def is_macho(head4):
    """head4 is the first 4 bytes of a file."""
    if len(head4) != 4:
        return False
    magic = struct.unpack("<I", head4)[0]
    return magic in (MH_MAGIC_64, MH_CIGAM_64, FAT_MAGIC, FAT_CIGAM)


def _arch_label(cputype, cpusubtype):
    if cputype == CPU_TYPE_ARM64:
        return "arm64e" if (cpusubtype & CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64E else "arm64"
    return f"cputype_{cputype:#x}_subtype_{cpusubtype:#x}"


def iter_slices(data):
    """Yield (arch_label, start, size) for each Mach-O arch slice.

    start/size are byte offsets into the original file passed in. A thin
    Mach-O yields exactly one slice covering the whole file; a fat/universal
    binary yields one slice per contained architecture. Fat header fields
    are always big-endian on disk, regardless of host byte order.
    """
    if len(data) < 4:
        return
    magic = struct.unpack_from("<I", data, 0)[0]
    endian = _endian_for_magic(magic)
    if endian is not None:
        cputype, cpusubtype = struct.unpack_from(endian + "2I", data, 4)
        yield _arch_label(cputype, cpusubtype), 0, len(data)
        return
    if magic in (FAT_MAGIC, FAT_CIGAM):
        if len(data) < 8:
            return
        nfat_arch = struct.unpack_from(">I", data, 4)[0]
        off = 8
        for _ in range(nfat_arch):
            if off + 20 > len(data):
                return
            cputype, cpusubtype, fileoff, size, _align = struct.unpack_from(">5I", data, off)
            yield _arch_label(cputype, cpusubtype), fileoff, size
            off += 20


def _walk_load_commands(data):
    """Yield (cmd, cmdsize, offset) for a thin 64-bit Mach-O's load commands."""
    if len(data) < 32:
        return
    magic = struct.unpack_from("<I", data, 0)[0]
    endian = _endian_for_magic(magic)
    if endian is None:
        return
    _, _, _, _, ncmds, _sizeofcmds, _, _ = struct.unpack_from(endian + "8I", data, 0)
    offset = 32
    for _ in range(ncmds):
        if offset + 8 > len(data):
            return
        cmd, cmdsize = struct.unpack_from(endian + "2I", data, offset)
        yield cmd, cmdsize, offset
        offset += cmdsize


def read_segments(thin_data):
    """Return [(segname, fileoff, filesize), ...] for a thin 64-bit Mach-O slice, or None."""
    magic = struct.unpack_from("<I", thin_data, 0)[0] if len(thin_data) >= 4 else 0
    endian = _endian_for_magic(magic)
    if endian is None:
        return None
    segments = []
    for cmd, cmdsize, offset in _walk_load_commands(thin_data):
        if cmd == LC_SEGMENT_64:
            segname = thin_data[offset + 8 : offset + 24].rstrip(b"\x00").decode("ascii", "replace")
            fileoff, filesize = struct.unpack_from(endian + "2Q", thin_data, offset + 40)
            segments.append((segname, fileoff, filesize))
    return segments


def segment_for_offset(segments, off):
    for name, fileoff, filesize in segments:
        if fileoff <= off < fileoff + filesize:
            return name
    return None


def load_commands_end(thin_data):
    """Return the file offset where a thin 64-bit Mach-O's load commands end
    (header + sizeofcmds) — i.e. where real section content begins. Signing
    adds an LC_CODE_SIGNATURE load command, which grows this value and shifts
    bytes within whichever segment has fileoff 0 (normally __TEXT), without
    touching any actual code — callers must not compare that prefix region
    byte-for-byte between an unsigned and signed binary.
    """
    magic = struct.unpack_from("<I", thin_data, 0)[0] if len(thin_data) >= 32 else 0
    endian = _endian_for_magic(magic)
    if endian is None:
        return None
    _, _, _, _, _ncmds, sizeofcmds, _, _ = struct.unpack_from(endian + "8I", thin_data, 0)
    return 32 + sizeofcmds


def read_uuid(thin_data):
    """Return the raw 16-byte LC_UUID value for a thin 64-bit Mach-O slice, or None."""
    magic = struct.unpack_from("<I", thin_data, 0)[0] if len(thin_data) >= 4 else 0
    if _endian_for_magic(magic) is None:
        return None
    for cmd, cmdsize, offset in _walk_load_commands(thin_data):
        if cmd == LC_UUID:
            return thin_data[offset + 8 : offset + 24]
    return None


def format_uuid(raw16):
    h = raw16.hex().upper()
    return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"


def locate_segment(data, abs_offset):
    """Given a byte offset into the original (possibly fat) file, return
    (arch_label, segment_name_or_None). segment_name is None if the offset
    falls in that slice's header/load-commands area rather than a segment,
    or if the slice's segments couldn't be parsed. arch_label is None if the
    offset doesn't fall within any recognized arch slice at all.
    """
    for arch, start, size in iter_slices(data):
        if start <= abs_offset < start + size:
            segs = read_segments(data[start : start + size])
            if segs is None:
                return arch, None
            return arch, segment_for_offset(segs, abs_offset - start)
    return None, None


def find_macho_files(bundle_root):
    """Return sorted relative paths of every Mach-O file under a bundle."""
    found = []
    for dirpath, _dirnames, filenames in os.walk(bundle_root):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            try:
                with open(full, "rb") as f:
                    head = f.read(4)
            except OSError:
                continue
            if is_macho(head):
                found.append(os.path.relpath(full, bundle_root))
    return sorted(found)
