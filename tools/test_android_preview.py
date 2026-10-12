"""Exercise the installed layout preview on a 1080x1920 Android device via ADB.

By default only the disposable preview package is modified. --full also tests
task selection, background/lock recovery and backup restoration. Testing the
final package name requires --reset-test-save and a debuggable test build.
"""
import argparse
import base64
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import time
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'com.ttzw1001.gugugaga.preview'
OUTPUT = ROOT / 'tests/output'
checks = 0


def main():
    global checks, PACKAGE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--serial', required=True)
    parser.add_argument('--capture-prefix', default='')
    parser.add_argument('--package', choices=[PACKAGE, 'com.ttzw1001.gugugaga'], default=PACKAGE)
    parser.add_argument('--reset-test-save', action='store_true')
    parser.add_argument('--full', action='store_true')
    args = parser.parse_args()
    if args.package != PACKAGE and not args.reset_test_save:
        parser.error('Final package fixtures require --reset-test-save on an isolated test device')
    PACKAGE = args.package
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
        path = OUTPUT / (args.capture_prefix + name + '.png')
        path.write_bytes(adb('exec-out', 'screencap', '-p'))
        return Image.open(path).convert('RGB')

    def read_save():
        envelope = json.loads(adb('exec-out', 'run-as', PACKAGE, 'cat', 'files/penguin.json'))
        expect(hashlib.sha256(envelope['payload'].encode()).hexdigest() == envelope['sha256'],
               'save checksum valid')
        return json.loads(envelope['payload'])

    def launch():
        shell('monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')
        time.sleep(2)
        expect(bool(shell('pidof', PACKAGE).strip()), 'preview process running')

    def write_bytes(name, data):
        encoded = base64.b64encode(data).decode('ascii')
        shell('run-as', PACKAGE, 'sh', '-c',
              "'echo " + encoded + " | base64 -d > files/" + name + "'")

    def write_save(data):
        payload = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        write_bytes('penguin.json', json.dumps(
            {'payload': payload, 'sha256': hashlib.sha256(payload.encode()).hexdigest()},
            ensure_ascii=False).encode())

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
    write_save(fixture)
    launch()
    capture('android-task')
    tap(220, 220)
    capture('android-profile-task')
    before = read_save()
    swipe(520, 650, 180, 0)
    capture('android-preview-rotated')
    tap(530, 1430)  # Spin in the compact profile tab; preview only.
    capture('android-preview-action')
    tap(850, 890)  # Fixed dress tab.
    tap(510, 1150)  # Red hood.
    dressed = read_save()
    expect(dressed['head'] == 'redhat', 'finger tap equips red hood')
    expect(dressed['task']['id'] == 'read' and dressed['task']['elapsed'] > before['task']['elapsed'],
           'task continues while rotating and previewing')
    expect(dressed['stats']['pet'] == before['stats']['pet'] and
           dressed['stats']['poke'] == before['stats']['poke'], 'preview does not award interactions')
    before_scroll = capture('android-dress')
    swipe(700, 1400, 0, -400)
    after_scroll = capture('android-dress-scrolled')
    expect(ImageChops.difference(before_scroll.crop((140, 975, 940, 1460)),
                                 after_scroll.crop((140, 975, 940, 1460))).getbbox() is not None,
           'finger swipe scrolls lower outfit content')
    for name, region in [('title and close', (140, 430, 940, 535)),
                         ('profile tabs', (140, 860, 940, 950))]:
        expect(ImageChops.difference(before_scroll.crop(region), after_scroll.crop(region)).getbbox() is None,
               name + ' stay fixed during finger scrolling')
    expect(read_save()['head'] == 'redhat', 'swiping outfit buttons does not equip another item')
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
    # Capture the other compact dialogs on the device as well as on desktop.
    for x, name in [(170, 'shop'), (540, 'food'), (900, 'clean')]:
        tap(x, 1640)
        capture('android-' + name)
        if name == 'food':
            tap(20, 960)  # Outside a centered care menu.
        else:
            shell('input', 'keyevent', '4')
            time.sleep(0.4)
    tap(785, 1780)
    capture('android-end')
    shell('input', 'keyevent', '4')
    time.sleep(0.4)
    tap(950, 1800)
    capture('android-settings')
    tap(760, 700)
    capture('android-about')
    swipe(700, 1300, 0, -400)
    capture('android-about-scrolled')
    shell('input', 'keyevent', '4')
    time.sleep(0.4)
    if args.full:
        # All catalog achievements are pre-recorded so reward assertions below
        # isolate tuition/wages from unrelated one-time achievement rewards.
        import re
        achievement_ids = re.findall(r'^\s*\["([^"]+)"',
            (ROOT / 'scripts/catalog.gd').read_text(encoding='utf-8').split('const ACHIEVEMENTS')[1].split('const ACCESSORIES')[0], re.M)

        def fixture_task(kind='', task_id='', remaining=0):
            shell('am', 'force-stop', PACKAGE)
            stamp = float(shell('date', '+%s').strip())
            data = copy.deepcopy(fixture)
            data.update(name='Android验收', coins=500.0, level=20, xp=0.0,
                        food=40.0, clean=40.0, mood=96.0, power=100.0, mind=100.0,
                        charm=100.0, last=stamp, pet_at=0.0, care_at=0.0,
                        inventory={'fish': 3, 'soap': 2}, head='none', neck='none', gold=False,
                        achievements=achievement_ids, task={})
            data['stats'] = {key: 0 for key in data['stats']}
            if kind:
                elapsed = 900.0 - remaining
                data['task'] = {'kind': kind, 'id': task_id, 'elapsed': elapsed,
                                'start': stamp - elapsed, 'end': stamp + remaining,
                                'escrow': 5.0 if kind == 'study' else 0.0}
                if kind == 'study':
                    data['coins'] -= 5
            write_save(data)
            launch()
            return data

        fixture_task()
        tap(250, 1800)
        capture('android-study')
        tap(875, 740)
        selected = read_save()
        expect(selected['task'].get('kind') == 'study' and selected['task'].get('id') == 'sport',
               'finger selection starts course and closes dialog')
        capture('android-study-action')
        tap(785, 1780)
        tap(540, 1075)
        expect(not read_save()['task'], 'finger confirmation ends course')
        tap(680, 1800)
        capture('android-work')
        tap(875, 740)
        selected = read_save()
        expect(selected['task'].get('kind') == 'work' and selected['task'].get('id') == 'flyer',
               'finger selection starts work and closes dialog')
        capture('android-work-action')
        tap(540, 1640)
        tap(540, 885)
        tap(540, 885)
        fed = read_save()
        expect(fed['inventory']['fish'] == 1 and fed['stats']['feed'] == 2,
               'two finger taps consume two foods without closing care menu')
        capture('android-repeat-food')
        shell('input', 'keyevent', '4')
        time.sleep(0.4)
        tap(900, 1640)
        tap(540, 875)
        tap(540, 875)
        washed = read_save()
        expect(washed['inventory']['soap'] == 0 and washed['stats']['wash'] == 2,
               'two finger taps consume two soaps without closing care menu')
        expect(washed['task'].get('id') == 'flyer', 'care retains active work task')
        shell('input', 'keyevent', '4')
        time.sleep(3)
        capture('android-after-care')

        data = fixture_task('study', 'read', 7)
        shell('input', 'keyevent', '3')
        time.sleep(1)
        paused = read_save()
        expect(paused['task'].get('id') == 'read', 'home transition saves an active course')
        time.sleep(7)
        launch()
        settled = read_save()
        expect(not settled['task'] and settled['stats']['full_study'] == 1 and settled['mind'] == 102.0,
               'background recovery settles course exactly once')
        expect(settled['coins'] == 495.0, 'background recovery never charges tuition again')
        capture('android-background-course')
        shell('input', 'keyevent', '3')
        time.sleep(0.5)
        launch()
        expect(read_save()['coins'] == settled['coins'], 'repeated foreground transition keeps same rewards')

        fixture_task('work', 'flyer', 7)
        shell('input', 'keyevent', '223')  # Sleep/lock, not a toggling power key.
        time.sleep(1)
        expect(read_save()['task'].get('id') == 'flyer', 'lock transition saves an active job')
        time.sleep(7)
        shell('input', 'keyevent', '224')
        shell('input', 'keyevent', '82')
        launch()
        settled = read_save()
        expect(not settled['task'] and settled['stats']['full_work'] == 1 and
               settled['coins'] == 520.0 and settled['stats']['income'] == 20.0,
               'unlock recovery pays job wages exactly once')
        capture('android-lock-job')
        shell('am', 'force-stop', PACKAGE)
        launch()
        expect(read_save()['coins'] == 520.0, 'process restart does not pay settled job twice')

        fixture_task('work', 'flyer', 5)
        shell('am', 'force-stop', PACKAGE)
        time.sleep(6)
        launch()
        settled = read_save()
        expect(not settled['task'] and settled['coins'] == 520.0 and settled['stats']['full_work'] == 1,
               'killed process settles overdue job on cold start')
        shell('am', 'force-stop', PACKAGE)
        # A committed backup is a complete transaction, including its wallet.
        write_save(settled)
        shell('run-as', PACKAGE, 'cp', 'files/penguin.json', 'files/penguin.json.bak')
        write_bytes('penguin.json', b'broken json')
        launch()
        recovered = read_save()
        expect(recovered['coins'] == 520.0 and recovered['stats']['full_work'] == 1 and not recovered['task'],
               'corrupt primary recovers backup without repeating job rewards')
        capture('android-backup-restored')

        fixture_task('study', 'read', 600)
        swipe(520, 850, 70, 5, 850)
        expect(read_save()['stats']['pet'] == 1, 'finger head stroke awards one petting interaction')
        capture('android-main-petting')
        for _ in range(10):
            shell('input', 'tap', '540', '1050')
        expect(read_save()['stats']['poke'] == 1, 'body taps reach main model')
        swipe(240, 1300, 160, 0)
        capture('android-main-rotated')
        time.sleep(12)
        capture('android-main-returned')
        shell('input', 'keyevent', '3')
        time.sleep(0.4)
        after = read_save()
        expect(after['stats']['pet'] == 1 and after['task'].get('id') == 'read',
               'main model rotation retains petting count and active task')
        launch()

    pid = shell('pidof', PACKAGE).strip()
    logs = adb('logcat', '-d', '--pid=' + pid).decode('utf-8', errors='replace')
    (OUTPUT / (args.capture_prefix + 'android-preview.log')).write_text(logs, encoding='utf-8')
    expect('SCRIPT ERROR' not in logs and 'FATAL EXCEPTION' not in logs and
           'Failed loading resource' not in logs, 'no script/resource/crash errors in current process')
    print(f'ANDROID_PREVIEW_TESTS {checks} checks, 0 failures', flush=True)


if __name__ == '__main__':
    main()
