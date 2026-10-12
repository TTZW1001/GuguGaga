"""Fetch Windows templates (default) or one Android template using HTTP ranges."""
import argparse, pathlib, struct, urllib.request, zlib, binascii
parser = argparse.ArgumentParser(description=__doc__)
android = parser.add_mutually_exclusive_group()
android.add_argument('--android-debug', action='store_true', help='Download Android debug template instead of Windows templates')
android.add_argument('--android-release', action='store_true', help='Download Android release template instead of Windows templates')
args = parser.parse_args()
ROOT = pathlib.Path(__file__).resolve().parents[1]
url = 'https://github.com/godotengine/godot-builds/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz'
size = 1251900388
def fetch(start, end):
    req = urllib.request.Request(url + '?range=' + str(start), headers={'Range': f'bytes={start}-{end}'})
    with urllib.request.urlopen(req, timeout=120) as r:
        if r.status != 206:
            raise RuntimeError('Server did not support partial download')
        return r.read()
tail = fetch(size - 65536, size - 1)
eocd = tail.rfind(b'PK\x05\x06')
_, _, _, _, count, cdsize, cdoffset, _ = struct.unpack_from('<4s4H2LH', tail, eocd)
central = fetch(cdoffset, cdoffset + cdsize - 1)
offset = 0
dest = ROOT / 'tools/templates'
dest.mkdir(exist_ok=True)
for _ in range(count):
    h = struct.unpack_from('<4s6H3L5H2L', central, offset)
    name = central[offset+46:offset+46+h[10]].decode()
    offset += 46+h[10]+h[11]+h[12]
    wanted = ('android_debug.apk',) if args.android_debug else ('android_release.apk',) if args.android_release else ('windows_release_x86_64.exe', 'windows_debug_x86_64.exe')
    if name.endswith(wanted):
        print('Downloading', name, h[8], flush=True)
        local = fetch(h[16], h[16]+29)
        lh = struct.unpack('<4s5H3L2H', local)
        start = h[16]+30+lh[9]+lh[10]
        data = fetch(start, start+h[8]-1)
        data = zlib.decompress(data, -15) if h[4] == 8 else data
        assert binascii.crc32(data) == h[7]
        (dest / name.split('/')[-1]).write_bytes(data)
        print('Ready', name, len(data), flush=True)
