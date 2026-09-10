#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Validate the checked-in ICNS without requiring macOS or third-party Python packages.
python3 - "$ROOT/packaging/AppIcon.icns" <<'PY'
import pathlib
import struct
import sys
import zlib

data = pathlib.Path(sys.argv[1]).read_bytes()
assert data[:4] == b"icns", "Invalid ICNS signature"
assert struct.unpack(">I", data[4:8])[0] == len(data), "Invalid ICNS length"
expected = {b"ic11": 32, b"ic12": 64, b"ic07": 128, b"ic08": 256,
            b"ic13": 256, b"ic09": 512, b"ic14": 512, b"ic10": 1024}
seen = set()
offset = 8
while offset < len(data):
    kind, size = struct.unpack(">4sI", data[offset:offset + 8])
    assert size > 8 and offset + size <= len(data), "Invalid ICNS entry"
    payload = data[offset + 8:offset + size]
    if kind in expected:
        assert kind not in seen, "Duplicate icon representation"
        seen.add(kind)
        assert payload[:8] == b"\x89PNG\r\n\x1a\n", "Expected PNG representation"
        width, height = struct.unpack(">II", payload[16:24])
        assert width == height == expected[kind], "Incorrect icon dimensions"
        cursor = 8
        compressed = bytearray()
        ended = False
        while cursor < len(payload):
            length = struct.unpack(">I", payload[cursor:cursor + 4])[0]
            tag = payload[cursor + 4:cursor + 8]
            chunk = payload[cursor + 8:cursor + 8 + length]
            crc = struct.unpack(">I", payload[cursor + 8 + length:cursor + 12 + length])[0]
            assert zlib.crc32(tag + chunk) == crc, "Invalid PNG checksum"
            if tag == b"IDAT":
                compressed.extend(chunk)
            cursor += length + 12
            if tag == b"IEND":
                ended = True
                break
        assert ended and cursor == len(payload), "Incomplete PNG"
        assert zlib.decompress(compressed), "Empty PNG pixels"
    offset += size
assert offset == len(data) and seen == set(expected), "Missing icon representations"
print("Application icon structure validated")
PY

# Also exercise Apple's decoder on the macOS CI host.
if [[ "$(uname -s)" == Darwin ]]; then
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tokeni-icon-tests.XXXXXX")"
    trap 'rm -rf "$TEST_ROOT"' EXIT
    /usr/bin/iconutil -c iconset "$ROOT/packaging/AppIcon.icns" \
        -o "$TEST_ROOT/AppIcon.iconset"
    test -f "$TEST_ROOT/AppIcon.iconset/icon_512x512@2x.png"
fi
