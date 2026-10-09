"""Exercise the exported Windows executable through native window messages."""
import argparse, ctypes, json, os, pathlib, subprocess, time
from ctypes import wintypes
import psutil
from PIL import ImageGrab

ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--exe', type=pathlib.Path, default=ROOT / 'build/企鹅小日子-1.0.2.exe')
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

def start():
    log = open(OUTPUT / 'release.log', 'ab')
    engine_log = OUTPUT / ('release-engine-' + str(time.time_ns()) + '.log')
    engine_logs.append(engine_log)
    proc = subprocess.Popen([str(EXE), '--log-file', str(engine_log)],
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

def click(hwnd, x, y):
    w, h = dimensions(hwnd)
    coord = int(x * w / 960) | (int(y * h / 700) << 16)
    user32.PostMessageW(hwnd, 0x200, 0, coord)
    user32.PostMessageW(hwnd, 0x201, 1, coord)
    time.sleep(0.08)
    user32.PostMessageW(hwnd, 0x202, 0, coord)
    time.sleep(0.3)

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
    proc, hwnd = start()
    expect(dimensions(hwnd)[0] >= 760, 'release creates resizable native window')
    capture(hwnd, 'release_adoption.png')
    file = RUNTIME / 'Godot/app_userdata/企鹅小日子/penguin.json'
    if not file.exists():
        click(hwnd, 678, 547)
    expect(wait_until(file.exists), 'native adoption writes user-directory save')
    first = save_data()
    expect(first['adopted'] and first['inventory']['fish'] == 3, 'release adoption initialized')
    expect(first['coins'] == 610, 'initial coins and automatic achievements correct')
    click(hwnd, 350, 655)  # Learning.
    capture(hwnd, 'release_courses.png')
    click(hwnd, 891, 340)  # Literacy course.
    expect(wait_until(lambda: save_data()['task'].get('id')=='read'), 'native course action is persisted')
    active = save_data()
    expect(active['task'].get('id') == 'read', 'native course selection starts fixed task')
    expect(active['coins'] == 605, 'course tuition escrow persisted')
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
    errors = '\n'.join(file.read_text(encoding='utf-8', errors='replace') for file in engine_logs)
    expect('SCRIPT ERROR' not in errors and 'Failed loading resource' not in errors, 'release has no script/resource errors')
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
