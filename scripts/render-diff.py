#!/usr/bin/env python3
"""Perceptual PNG diff for render goldens.

Compares two PNG files, or two directories of PNGs, without third-party
dependencies. A pixel counts as matching when every RGBA channel differs by at
most --max-delta; a file passes when at least --threshold percent of its pixels
match. The tool is intentionally tolerant of driver rounding while still
catching layout, colour, culling and depth regressions.

Usage:
    render-diff.py [options] <a> <b>

    <a> and <b> are either two PNG files or two directories containing PNGs
    with the same names.

Options:
    --threshold PCT   minimum matching pixel percentage (default 99.5)
    --max-delta N     per-channel tolerance, 0-255 (default 2)
    --json            machine-readable output
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
import zlib
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class PngError(RuntimeError):
    pass


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path: Path) -> tuple[int, int, bytes]:
    """Return (width, height, RGBA bytes) for an 8-bit non-interlaced PNG."""
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise PngError(f"{path}: not a PNG file")

    offset = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = interlace = None
    compressed = bytearray()

    while offset + 8 <= len(data):
        (length,) = struct.unpack(">I", data[offset:offset + 4])
        chunk_type = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        offset += 12 + length
        if len(payload) != length:
            raise PngError(f"{path}: truncated chunk {chunk_type!r}")

        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", payload)
        elif chunk_type == b"IDAT":
            compressed.extend(payload)
        elif chunk_type == b"IEND":
            break

    if width is None:
        raise PngError(f"{path}: missing IHDR")
    if bit_depth != 8:
        raise PngError(f"{path}: only 8-bit PNGs are supported (got {bit_depth})")
    if interlace != 0:
        raise PngError(f"{path}: interlaced PNGs are not supported")

    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(color_type)
    if channels is None:
        raise PngError(f"{path}: unsupported colour type {color_type}")

    raw = zlib.decompress(bytes(compressed))
    stride = width * channels
    if len(raw) != (stride + 1) * height:
        raise PngError(f"{path}: unexpected image data length")

    pixels = bytearray(stride * height)
    previous = bytearray(stride)
    cursor = 0
    for y in range(height):
        filter_type = raw[cursor]
        cursor += 1
        line = bytearray(raw[cursor:cursor + stride])
        cursor += stride

        if filter_type == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif filter_type == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif filter_type == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif filter_type == 4:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                upper_left = previous[i - channels] if i >= channels else 0
                line[i] = (line[i] + _paeth(left, previous[i], upper_left)) & 0xFF
        elif filter_type != 0:
            raise PngError(f"{path}: unknown filter type {filter_type}")

        pixels[y * stride:(y + 1) * stride] = line
        previous = line

    if channels == 4:
        return width, height, bytes(pixels)

    rgba = bytearray(width * height * 4)
    for index in range(width * height):
        source = pixels[index * channels:(index + 1) * channels]
        if channels == 1:
            grey = source[0]
            rgba[index * 4:index * 4 + 4] = bytes((grey, grey, grey, 255))
        elif channels == 2:
            grey, alpha = source
            rgba[index * 4:index * 4 + 4] = bytes((grey, grey, grey, alpha))
        else:
            red, green, blue = source
            rgba[index * 4:index * 4 + 4] = bytes((red, green, blue, 255))
    return width, height, bytes(rgba)


def compare(expected: Path, actual: Path, max_delta: int) -> dict:
    expected_width, expected_height, expected_pixels = read_png(expected)
    actual_width, actual_height, actual_pixels = read_png(actual)

    if (expected_width, expected_height) != (actual_width, actual_height):
        return {
            "name": actual.name,
            "status": "FAIL",
            "reason": f"size mismatch {expected_width}x{expected_height} != "
                      f"{actual_width}x{actual_height}",
            "similarity": 0.0,
            "max_delta": 255,
            "mae": 255.0,
            "pixels": expected_width * expected_height,
        }

    total = expected_width * expected_height
    differing = 0
    worst = 0
    total_error = 0

    for index in range(total):
        base = index * 4
        pixel_delta = 0
        for channel in range(4):
            delta = abs(expected_pixels[base + channel] - actual_pixels[base + channel])
            total_error += delta
            if delta > pixel_delta:
                pixel_delta = delta
        if pixel_delta > worst:
            worst = pixel_delta
        if pixel_delta > max_delta:
            differing += 1

    similarity = 100.0 * (total - differing) / total
    return {
        "name": actual.name,
        "status": "PASS",
        "similarity": similarity,
        "max_delta": worst,
        "mae": total_error / (total * 4),
        "pixels": total,
    }


def collect(a: Path, b: Path) -> list[tuple[Path, Path]]:
    if a.is_file() and b.is_file():
        return [(a, b)]

    if a.is_dir() and b.is_dir():
        a_files = {path.name: path for path in a.glob("*.png")}
        b_files = {path.name: path for path in b.glob("*.png")}
        pairs = []
        for name in sorted(set(a_files) | set(b_files)):
            if name not in a_files:
                raise PngError(f"{name}: present in {b} but missing from {a}")
            if name not in b_files:
                raise PngError(f"{name}: present in {a} but missing from {b}")
            pairs.append((a_files[name], b_files[name]))
        if not pairs:
            raise PngError(f"no PNG files under {a} or {b}")
        return pairs

    raise PngError("<a> and <b> must both be files or both be directories")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Perceptual PNG diff")
    parser.add_argument("a", type=Path, help="reference PNG or directory")
    parser.add_argument("b", type=Path, help="rendered PNG or directory")
    parser.add_argument("--threshold", type=float, default=99.5,
                        help="minimum matching pixel percentage (default 99.5)")
    parser.add_argument("--max-delta", type=int, default=2,
                        help="per-channel tolerance, 0-255 (default 2)")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args(argv)

    if not 0 <= args.max_delta <= 255:
        parser.error("--max-delta must be between 0 and 255")
    if not 0.0 <= args.threshold <= 100.0:
        parser.error("--threshold must be between 0 and 100")

    try:
        pairs = collect(args.a, args.b)
    except PngError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    except OSError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    results = []
    for expected, actual in pairs:
        try:
            result = compare(expected, actual, args.max_delta)
        except (PngError, OSError, zlib.error) as error:
            print(f"error: {error}", file=sys.stderr)
            return 2
        if result["similarity"] < args.threshold:
            result["status"] = "FAIL"
        results.append(result)

    failures = sum(1 for result in results if result["status"] != "PASS")

    if args.json:
        print(json.dumps({
            "threshold": args.threshold,
            "max_delta": args.max_delta,
            "failed": failures,
            "scenes": results,
        }, indent=2))
    else:
        print(f"{'scene':<24} {'similarity':>10}  {'max_d':>5}  {'mae':>7}  status")
        for result in results:
            print(f"{result['name']:<24} {result['similarity']:>9.2f}%  "
                  f"{result['max_delta']:>5}  {result['mae']:>7.3f}  {result['status']}")
        print(f"\n{len(results) - failures}/{len(results)} scenes passed "
              f"(threshold={args.threshold:.2f}%, max delta={args.max_delta})")

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
