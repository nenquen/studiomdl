"""Generate a minimal GoldSrc compile corpus: test.qc + tri.smd + test.bmp."""
import os
import struct
import sys

outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)))
os.makedirs(outdir, exist_ok=True)

qc = """$modelname test.mdl
$cd .
$cdtexture .
$scale 1.0
$body studio "tri.smd"
$sequence idle "tri.smd" fps 30
"""
with open(os.path.join(outdir, "test.qc"), "w", newline="\n") as f:
    f.write(qc)

smd = """version 1
nodes
0 "root" -1
end
skeleton
time 0
0 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000
end
triangles
test.bmp
0 0.0000 0.0000 0.0000 0.0000 0.0000 1.0000 0.0000 0.0000
0 1.0000 0.0000 0.0000 0.0000 0.0000 1.0000 1.0000 0.0000
0 0.0000 1.0000 0.0000 0.0000 0.0000 1.0000 0.0000 1.0000
end
"""
with open(os.path.join(outdir, "tri.smd"), "w", newline="\n") as f:
    f.write(smd)

W = H = 8
pixels = bytes([i % 256 for i in range(W * H)])
palette = b"".join(bytes([i, 255 - i, (i * 2) % 256, 0]) for i in range(256))
row = ((W + 3) & ~3)
area = row * H
offbits = 14 + 40 + 256 * 4
bmp = struct.pack("<HIHHI", 0x4D42, offbits + area, 0, 0, offbits)
bmp += struct.pack("<IiiHHIIiiII", 40, row, H, 1, 8, 0, 0, 0, 0, 256, 0)
bmp += palette
bmp += pixels  # bottom-up irrelevant for 8x8 smoke
with open(os.path.join(outdir, "test.bmp"), "wb") as f:
    f.write(bmp)

print("wrote corpus to", outdir)
