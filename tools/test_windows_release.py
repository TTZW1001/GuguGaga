"""Exercise the exported Windows executable through native window messages."""
import argparse, ctypes, hashlib, json, os, pathlib, subprocess, time
from ctypes import wintypes
import psutil
from PIL import ImageGrab

ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--exe', type=pathlib.Path, default=ROOT / 'build/养一只咕咕嘎嘎吧！-1.3.0.exe')
EXE = parser.parse_args().exe.resolve()
RUNTIME = ROOT / ('tests/runtime/release-' + str(time.time_ns()))
OUTPUT = ROOT / 'tests/output'
RUNTIME.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, APPDATA=str(RUNTIME))
user32 = ctypes.WinDLL('user32', use_last_error=True)
user32.SetProcessDPIAware()
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
Callback = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
checks = 0
engine_logs = []

def expect(ok, label):
    global checks
    checks += 1
    if not ok:
        raise AssertionError(label)
    print('RELEASE OK:', label, flush=True)

def wait_until(predicate, seconds=8):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        if predicate():return True
        time.sleep(0.1)
    return False

def window(pid):
    found = []
    @Callback
    def visit(hwnd, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid and user32.IsWindowVisible(hwnd):
            rect = wintypes.RECT()
            user32.GetClientRect(hwnd, ctypes.byref(rect))
            if rect.right > 500:
                found.append(hwnd)
        return True
    user32.EnumWindows(visit, 0)
    return found[0] if found else None

def start(executable=EXE):
    log = open(OUTPUT / 'release.log', 'ab')
    engine_log = OUTPUT / ('release-engine-' + str(time.time_ns()) + '.log')
    engine_logs.append(engine_log)
    proc = subprocess.Popen([str(executable), '--log-file', str(engine_log)],
                            cwd=str(ROOT / 'build'), env=env,
                            stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
    log.close()
    for _ in range(150):
        hwnd = window(proc.pid)
        if hwnd and engine_log.exists() and 'QPET_READY' in engine_log.read_text(encoding='utf-8', errors='replace'):
            time.sleep(0.5)
            return proc, hwnd
        if proc.poll() is not None:
            raise RuntimeError('Release exited early: ' + str(proc.returncode))
        time.sleep(0.1)
    proc.terminate()
    proc.wait(timeout=10)
    raise RuntimeError('Release did not become ready')

def dimensions(hwnd):
    rect = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    return rect.right, rect.bottom

def click(hwnd, x, y, canvas=(1280, 720)):
    w, h = dimensions(hwnd)
    cw, ch = canvas
    scale = min(w / cw, h / ch)
    coord = int((w-cw*scale)/2+x*scale) | (int((h-ch*scale)/2+y*scale) << 16)
    user32.PostMessageW(hwnd, 0x200, 0, coord)
    user32.PostMessageW(hwnd, 0x201, 1, coord)
    time.sleep(0.08)
    user32.PostMessageW(hwnd, 0x202, 0, coord)
    time.sleep(0.3)

def key(hwnd, code):
    scan = user32.MapVirtualKeyW(code, 0)
    user32.PostMessageW(hwnd, 0x100, code, 1 | (scan << 16))
    time.sleep(0.04)
    user32.PostMessageW(hwnd, 0x101, code, 1 | (scan << 16) | (3 << 30))
    time.sleep(0.04)

def scroll_bottom(hwnd):
    w, h = dimensions(hwnd)
    scale = min(w/1280, h/720)
    point = wintypes.POINT(int((w-1280*scale)/2+820*scale), int((h-720*scale)/2+460*scale))
    user32.ClientToScreen(hwnd, ctypes.byref(point))
    for _ in range(40):
        user32.PostMessageW(hwnd, 0x20A, (-120 & 0xffff) << 16, (point.x & 0xffff) | ((point.y & 0xffff) << 16))
    time.sleep(0.5)

def capture(hwnd, name):
    w, h = dimensions(hwnd)
    origin = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(origin))
    try:
        ImageGrab.grab(bbox=(origin.x, origin.y, origin.x+w, origin.y+h), all_screens=True).save(OUTPUT / name)
    except OSError:
        # The tool runner may have no readable interactive desktop. Godot's
        # own viewport captures in test_ui.gd still verify the rendered image.
        pass

def save_data():
    file = RUNTIME / 'Godot/app_userdata/企鹅小日子/penguin.json'
    return json.loads(json.loads(file.read_text(encoding='utf-8'))['payload'])

def close(proc, hwnd):
    user32.PostMessageW(hwnd, 0x10, 0, 0)
    proc.wait(timeout=10)
    expect(proc.returncode == 0, 'normal close exit code 0')

proc = None
try:
    file = RUNTIME / 'Godot/app_userdata/企鹅小日子/penguin.json'
    legacy = ROOT / 'build/企鹅小日子-1.0.2.exe'
    if legacy.exists():
        proc, hwnd = start(legacy)
        click(hwnd, 678, 547, canvas=(960, 700))
        expect(wait_until(file.exists), 'old 1.0.2 executable creates legacy save fixture')
        close(proc, hwnd)
    proc, hwnd = start()
    expect(dimensions(hwnd)[0] >= 960, 'release creates resizable native window')
    width, height = dimensions(hwnd)
    expect(abs(width / height - 16 / 9) < 0.01, 'release starts with 16:9 window')
    title = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(hwnd, title, 256)
    expect(title.value == '养一只咕咕嘎嘎吧！', 'native window uses new game title')
    capture(hwnd, 'release_adoption.png')
    file = RUNTIME / 'Godot/app_userdata/企鹅小日子/penguin.json'
    if not file.exists():
        click(hwnd, 818, 588)
    expect(wait_until(file.exists), 'native adoption writes user-directory save')
    first = save_data()
    expect(first['adopted'] and first['inventory']['fish'] == 3, 'release adoption initialized')
    expect(first['coins'] == 610, 'initial coins and automatic achievements correct')
    click(hwnd, 510, 677)  # Learning.
    capture(hwnd, 'release_courses.png')
    click(hwnd, 962, 350)  # Literacy course.
    expect(wait_until(lambda: save_data()['task'].get('id')=='read'), 'native course action is persisted')
    active = save_data()
    expect(active['task'].get('id') == 'read', 'native course selection starts fixed task')
    expect(active['coins'] == 605, 'course tuition escrow persisted')
    click(hwnd, 1210, 370)  # Feed popout during the course.
    click(hwnd, 920, 370)  # Fish, now effective because time has elapsed.
    expect(wait_until(lambda: save_data()['inventory']['fish']==2), 'native popout uses item during task')
    click(hwnd, 920, 370)  # Menu remains open for another use.
    expect(wait_until(lambda: save_data()['inventory']['fish']==1), 'native popout stays open for repeat use')
    expect(save_data()['task'].get('id') == 'read', 'native care preserves task')
    click(hwnd, 600, 230)  # Outside consumes dismissal click.
    click(hwnd, 110, 42)  # Profile, auto-save a new name on Enter.
    click(hwnd, 690, 284)
    key(hwnd, 0x23)  # End, then remove the existing name.
    for _ in range(12):
        key(hwnd, 0x08)
    # WM_CHAR can type text without depending on keyboard layout.
    for ch in '旧档咕咕':
        user32.PostMessageW(hwnd, 0x102, ord(ch), 0)
        time.sleep(0.06)
    key(hwnd, 0x0D)
    expect(wait_until(lambda: save_data()['name']=='旧档咕咕'), 'native profile name auto-saves')
    click(hwnd, 10, 350)
    time.sleep(1)
    capture(hwnd, 'release_home.png')
    p = psutil.Process(proc.pid)
    p.cpu_percent(interval=None)
    cpu = p.cpu_percent(interval=2)
    memory = p.memory_info().rss / 1024**2
    print(f'RELEASE METRICS: RSS={memory:.1f} MiB; CPU={cpu:.1f}% of one logical core', flush=True)
    try:
        connections = p.net_connections(kind='inet')
        expect(len(connections) == 0, 'release has no network sockets')
    except psutil.AccessDenied:
        print('Network socket enumeration unavailable; no networking code is included.', flush=True)
    close(proc, hwnd)
    saved = save_data()
    expect(saved['task']['elapsed'] > 0, 'normal close preserves active task checkpoint')
    proc, hwnd = start()
    recovered = save_data()
    expect(recovered['task'].get('id') == 'read', 'relaunch continues active task')
    expect(recovered['coins'] == 605, 'relaunch does not charge tuition twice')
    expect(recovered['name'] == '旧档咕咕' and recovered['inventory']['fish']==1, 'renamed release reads existing old-directory save')
    expect(len(recovered['achievements']) == 2, 'relaunch does not repeat achievement rewards')
    capture(hwnd, 'release_restart.png')
    proc.terminate()
    proc.wait(timeout=10)
    proc, hwnd = start()
    after_crash = save_data()
    expect(after_crash['task'].get('id') == 'read', 'forced termination restores last committed task')
    expect(after_crash['coins'] == 605, 'forced termination preserves escrow without double charge')
    close(proc, hwnd)
    proc = None
    # These fixtures use the original save schema, including the old gold flag.
    # Load every new GLB from the embedded release package, not from res:// source.
    fixture = save_data()
    fixture.update(level=20, xp=0, power=60, mind=60, charm=60, task={})
    for head, neck, suit in [('redhat', 'scarf', False), ('graduate', 'tie', False), ('crown', 'bow', False), ('crown', 'bow', True)]:
        fixture.update(head=head, neck=neck, gold=suit, last=time.time())
        payload = json.dumps(fixture, ensure_ascii=False, separators=(',', ':'))
        file.write_text(json.dumps({'payload': payload, 'sha256': hashlib.sha256(payload.encode('utf-8')).hexdigest()}, ensure_ascii=False), encoding='utf-8')
        proc, hwnd = start()
        restored = save_data()
        expect(restored['gold']==suit and restored['head']==head and restored['neck']==neck, 'legacy outfit fixture loads: '+head+'/'+neck+('/suit' if suit else ''))
        capture(hwnd, 'release-v120-'+('suit' if suit else head)+'.png')
        if suit:
            click(hwnd, 110, 42)
            click(hwnd, 1016, 210)
            scroll_bottom(hwnd)
            capture(hwnd, 'release-v120-suit-profile.png')
            click(hwnd, 820, 520)
            expect(wait_until(lambda: not save_data()['gold']), 'native suit button removes outfit and saves')
            expect(save_data()['head']=='crown' and save_data()['neck']=='bow', 'native suit removal preserves accessory choices')
            scroll_bottom(hwnd)
            click(hwnd, 820, 540)
            expect(wait_until(lambda: save_data()['gold']), 'native suit button equips outfit and saves')
        close(proc, hwnd)
        proc = None
    proc, hwnd = start()
    expect(save_data()['gold'], 'native suit remains equipped after restart')
    close(proc, hwnd)
    proc = None
    # Every course/job must load its action props from the exported EXE. Keep
    # existing task IDs to exercise upgrades of saves made before the renames.
    tasks = [('study', task, duration) for task, duration in [
        ('sport',900), ('read',900), ('manners',900), ('martial',1800),
        ('math',1800), ('music',1800), ('combat',3600), ('science',3600), ('stage',3600)
    ]] + [('work', task, duration) for task, duration in [
        ('flyer',900), ('carry',1800), ('library',1800), ('waiter',1800),
        ('guard',3600), ('code',3600), ('idol',3600)
    ]]
    for kind, task_id, duration in tasks:
        timestamp = time.time()
        fixture.update(head='none', neck='none', gold=True, food=80, clean=80,
                       inventory={'fish':3,'soap':2}, last=timestamp,
                       task={'kind':kind,'id':task_id,'elapsed':0,'start':timestamp,
                             'end':timestamp+duration,'escrow':0})
        payload = json.dumps(fixture, ensure_ascii=False, separators=(',', ':'))
        file.write_text(json.dumps({'payload':payload,'sha256':hashlib.sha256(payload.encode('utf-8')).hexdigest()}, ensure_ascii=False), encoding='utf-8')
        proc, hwnd = start()
        time.sleep(1.0)
        expect(save_data()['task'].get('id')==task_id, 'exported action resumes old task ID: '+kind+'/'+task_id)
        if task_id == 'waiter':
            click(hwnd, 1210, 370)
            click(hwnd, 920, 370)
            expect(wait_until(lambda: save_data()['inventory']['fish']==2), 'exported phone job can use the new food model')
            click(hwnd, 600, 230)
            time.sleep(6)
        close(proc, hwnd)
        proc = None
        settled = save_data()
        expect(settled['task']['elapsed']>1 and settled['gold'], 'exported action preserves task progress and suit: '+task_id)
    errors = '\n'.join(file.read_text(encoding='utf-8', errors='replace') for file in engine_logs)
    expect('SCRIPT ERROR' not in errors and 'Failed loading resource' not in errors and 'Failed to load' not in errors, 'release has no script/resource errors')
    print(f'RELEASE_TESTS {checks} checks, 0 failures', flush=True)
finally:
    if proc is not None and proc.poll() is None:
        hwnd = window(proc.pid)
        if hwnd:
            user32.PostMessageW(hwnd, 0x10, 0, 0)
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.terminate()
                proc.wait(timeout=10)
