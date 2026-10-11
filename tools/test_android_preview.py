"""Exercise the installed layout preview on a 1080x1920 Android device via ADB.

Only the disposable com.ttzw1001.gugugaga.preview package is modified. This is
a layout/input smoke test, not the full Android lifecycle acceptance suite.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'com.ttzw1001.gugugaga.preview'
OUTPUT = ROOT / 'tests/output'
checks = 0


def main():
    global checks
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--serial', required=True)
    args = parser.parse_args()
    base = [args.adb, '-s', args.serial]

    def adb(*words, **kwargs):
        return subprocess.check_output(base + list(words), timeout=30, **kwargs)

    def shell(*words):
        return adb('shell', *words).decode('utf-8', errors='replace')

    def expect(condition, title):
        global checks
        checks += 1
        if not condition:
            raise AssertionError(title)
        print('ANDROID PREVIEW OK:', title, flush=True)

    def tap(x, y):
        shell('input', 'tap', str(x), str(y))
        time.sleep(0.35)

    def swipe(x, y, dx, dy, duration=650):
        shell('input', 'swipe', str(x), str(y), str(x + dx), str(y + dy), str(duration))
        time.sleep(0.35)

    def capture(name):
        OUTPUT.mkdir(parents=True, exist_ok=True)
        (OUTPUT / (name + '.png')).write_bytes(adb('exec-out', 'screencap', '-p'))

    def read_save():
        envelope = json.loads(adb('exec-out', 'run-as', PACKAGE, 'cat', 'files/penguin.json'))
        expect(hashlib.sha256(envelope['payload'].encode()).hexdigest() == envelope['sha256'],
               'save checksum valid')
        return json.loads(envelope['payload'])

    def launch():
        shell('monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')
        time.sleep(2)
        expect(bool(shell('pidof', PACKAGE).strip()), 'preview process running')

    expect('1080x1920' in shell('wm', 'size'), 'device has expected screenshot size')
    # This package was installed/adopted for the preview. Never read desktop saves.
    launch()
    shell('am', 'force-stop', PACKAGE)
    fixture = read_save()
    timestamp = float(shell('date', '+%s').strip())
    fixture.update(name='小嘎嘎', level=20, xp=0, food=82.0, clean=91.0,
                   mood=96.0, head='none', neck='none', gold=False, last=timestamp,
                   task={'kind': 'study', 'id': 'read', 'elapsed': 60.0,
                         'start': timestamp - 60, 'end': timestamp + 840, 'escrow': 5.0})
    payload = json.dumps(fixture, ensure_ascii=False, separators=(',', ':'))
    envelope = json.dumps({'payload': payload, 'sha256': hashlib.sha256(payload.encode()).hexdigest()},
                          ensure_ascii=False).encode()
    encoded = base64.b64encode(envelope).decode('ascii')
    shell('run-as', PACKAGE, 'sh', '-c',
          "'echo " + encoded + " | base64 -d > files/penguin.json'")
    launch()
    capture('android-task')
    tap(220, 220)
    capture('android-profile-task')
    before = read_save()
    swipe(520, 510, 180, 0)
    capture('android-preview-rotated')
    tap(530, 1510)  # Spin in the profile tab; preview only.
    capture('android-preview-action')
    tap(850, 840)  # Dress tab.
    tap(510, 1150)  # Red hood.
    dressed = read_save()
    expect(dressed['head'] == 'redhat', 'finger tap equips red hood')
    expect(dressed['task']['id'] == 'read' and dressed['task']['elapsed'] > before['task']['elapsed'],
           'task continues while rotating and previewing')
    expect(dressed['stats']['pet'] == before['stats']['pet'] and
           dressed['stats']['poke'] == before['stats']['poke'], 'preview does not award interactions')
    capture('android-dress')
    swipe(700, 1560, 0, -590)
    capture('android-dress-scrolled')
    shell('input', 'keyevent', '4')
    time.sleep(0.4)
    expect(bool(shell('pidof', PACKAGE).strip()), 'back from profile keeps game running')
    capture('android-back-home')
    shell('am', 'force-stop', PACKAGE)
    launch()
    restored = read_save()
    expect(restored['head'] == 'redhat' and restored['task']['id'] == 'read',
           'process restart retains outfit and active task')
    expect(restored['coins'] == dressed['coins'], 'restart does not charge tuition twice')
    capture('android-restart')
    pid = shell('pidof', PACKAGE).strip()
    logs = adb('logcat', '-d', '--pid=' + pid).decode('utf-8', errors='replace')
    (OUTPUT / 'android-preview.log').write_text(logs, encoding='utf-8')
    expect('SCRIPT ERROR' not in logs and 'FATAL EXCEPTION' not in logs and
           'Failed loading resource' not in logs, 'no script/resource/crash errors in current process')
    print(f'ANDROID_PREVIEW_TESTS {checks} checks, 0 failures', flush=True)


if __name__ == '__main__':
    main()
