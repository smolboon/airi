#!/usr/bin/env python3
"""Read one RGBA PNG and require a clear pixel plus a lit pixel."""

import pathlib
import struct
import sys
import zlib


def paeth(left, up, up_left):
    estimate = left + up - up_left
    distance_left = abs(estimate - left)
    distance_up = abs(estimate - up)
    distance_up_left = abs(estimate - up_left)
    if distance_left <= distance_up and distance_left <= distance_up_left:
        return left
    if distance_up <= distance_up_left:
        return up
    return up_left


def decode_rgba(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(1)
    offset = 8
    width = None
    height = None
    depth = None
    color = None
    idat = bytearray()
    while offset + 12 <= len(data):
        length, kind = struct.unpack(">I4s", data[offset:offset + 8])
        chunk = data[offset + 8:offset + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color = struct.unpack(">IIBB", chunk[:10])
        elif kind == b"IDAT":
            idat.extend(chunk)
        elif kind == b"IEND":
            break
        offset += 12 + length
    if width is None or height is None or depth != 8 or color != 6:
        raise SystemExit(1)
    raw = zlib.decompress(bytes(idat))
    stride = width * 4
    rows = []
    previous = bytearray(stride)
    cursor = 0
    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row = bytearray(raw[cursor:cursor + stride])
        cursor += stride
        if filter_type == 1:
            for column in range(stride):
                left = row[column - 4] if column >= 4 else 0
                row[column] = (row[column] + left) & 255
        elif filter_type == 2:
            for column in range(stride):
                row[column] = (row[column] + previous[column]) & 255
        elif filter_type == 3:
            for column in range(stride):
                left = row[column - 4] if column >= 4 else 0
                row[column] = (row[column] + ((left + previous[column]) // 2)) & 255
        elif filter_type == 4:
            for column in range(stride):
                left = row[column - 4] if column >= 4 else 0
                up = previous[column]
                up_left = previous[column - 4] if column >= 4 else 0
                row[column] = (row[column] + paeth(left, up, up_left)) & 255
        elif filter_type != 0:
            raise SystemExit(1)
        rows.append(row)
        previous = row
    return width, height, rows


def main():
    path = pathlib.Path(sys.argv[1])
    width, height, rows = decode_rgba(path.read_bytes())
    clear = False
    lit = False
    for row in rows:
        for column in range(0, width * 4, 4):
            red = row[column]
            green = row[column + 1]
            alpha = row[column + 3]
            if alpha == 0:
                clear = True
            if alpha == 255 and red > 80 and green < red:
                lit = True
    print(f"aori_gpui_clear={int(clear)} aori_gpui_lit={int(lit)} size={width}x{height}")
    if not clear or not lit:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
