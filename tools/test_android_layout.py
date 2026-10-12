"""Capture portrait dialogs at multiple Android sizes and with a simulated cutout.

Only changes an existing emulator's display overrides, restoring them in finally.
The installed game must already be adopted. No save fixtures are written.
"""
import argparse
import io
from pathlib import Path
import subprocess
import time
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', required=True)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--package', default='com.ttzw1001.gugugaga')
    args = parser.parse_args()
    base = [args.adb, '-s', args.serial]

    def adb(*words):
        return subprocess.check_output(base + list(words), timeout=30)

    def shell(*words):
        return adb('shell', *words).decode('utf-8', errors='replace')

    def tap(x, y):
        shell('input', 'tap', str(round(x)), str(round(y)))
        time.sleep(0.4)

    def capture(name):
        content = adb('exec-out', 'screencap', '-p')
        (ROOT / 'tests/output' / (name + '.png')).write_bytes(content)
        return Image.open(io.BytesIO(content)).convert('RGB')

    def wait_for_home():
        # Enabling a display cutout can recreate the Android activity.
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            image = Image.open(io.BytesIO(adb('exec-out', 'screencap', '-p'))).convert('RGB')
            red, green, _ = image.getpixel((image.width // 10, image.height // 10))
            if red > 230 and green > 220:
                return
            time.sleep(0.3)
        raise AssertionError('Game did not finish starting after display change')

    checks = 0

    def expect(value, title):
        nonlocal checks
        checks += 1
        if not value:
            raise AssertionError(title)
        print('ANDROID LAYOUT OK:', title, flush=True)

    def check_panel(image, title):
        # Detect the cream modal surface against the dimmed room; independent
        # of text/animation, so this also checks actual rendered panel bounds.
        channels = image.split()
        mask = channels[0].point(lambda value: 255 if 248 <= value <= 252 else 0)
        for channel, low, high in [(channels[1], 244, 248), (channels[2], 234, 239)]:
            mask = ImageChops.multiply(mask, channel.point(lambda value: 255 if low <= value <= high else 0))
        bounds = mask.getbbox()
        expect(bounds is not None and mask.histogram()[255] > image.width * image.height * 0.1,
               title + ' renders a dialog')
        left, top, right, bottom = bounds
        width, height = image.size
        expect(left > width * 0.03 and right < width * 0.97, title + ' has side margins')
        expect(top > height * 0.1 and bottom < height * 0.9, title + ' has top/bottom margins')
        expect((right - left) < width * 0.9 and (bottom - top) < height * 0.75,
               title + ' stays compact')

    display = shell('wm', 'size')
    original_size = next((line.split(':', 1)[1].strip() for line in display.splitlines()
                          if line.startswith('Override size:')), None)
    cutout = 'com.android.internal.display.cutout.emulation.tall'
    overlays = shell('cmd', 'overlay', 'list')
    cutout_was_enabled = '[x] ' + cutout in overlays
    try:
        for size in ['720x1280', '1080x2400', '1600x2560']:
            shell('wm', 'size', size)
            time.sleep(1)
            shell('monkey', '-p', args.package, '-c', 'android.intent.category.LAUNCHER', '1')
            wait_for_home()
            width, height = map(int, size.split('x'))
            scale = min(width / 432, height / 864)
            capture('android-home-' + size)
            tap(width * 0.2, 103 * scale)
            check_panel(capture('android-profile-' + size), 'profile ' + size)
            shell('input', 'keyevent', '4')
            time.sleep(0.3)
            tap(width * 0.17, height - 140 * scale)
            check_panel(capture('android-shop-' + size), 'shop ' + size)
            shell('input', 'keyevent', '4')
            time.sleep(0.3)
        if cutout in overlays:
            shell('wm', 'size', '1080x2400')
            shell('cmd', 'overlay', 'enable', '--user', '0', cutout)
            time.sleep(1)
            shell('monkey', '-p', args.package, '-c', 'android.intent.category.LAUNCHER', '1')
            wait_for_home()
            capture('android-home-cutout')
            tap(220, 360)
            check_panel(capture('android-profile-cutout'), 'profile with cutout')
            shell('input', 'keyevent', '4')
    finally:
        if not cutout_was_enabled and cutout in overlays:
            shell('cmd', 'overlay', 'disable', '--user', '0', cutout)
        shell('wm', 'size', original_size or 'reset')
    print(f'ANDROID_LAYOUT_TESTS {checks} checks, 0 failures', flush=True)


if __name__ == '__main__':
    main()
