"""Export a debug-signed portrait preview, without changing Windows artifacts/settings."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--jdk', type=Path, required=True)
    parser.add_argument('--debug-keystore', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/android/GuguGaga-1.3.2-portrait-preview.apk')
    args = parser.parse_args()
    for path in [args.sdk / 'platform-tools/adb.exe', args.jdk / 'bin/java.exe',
                 ROOT / 'tools/templates/android_debug.apk']:
        if not path.is_file():
            raise FileNotFoundError(path)
    runtime = ROOT / 'tests/runtime/android-export'
    runtime.mkdir(parents=True, exist_ok=True)
    keystore = args.debug_keystore or runtime / 'debug.keystore'
    signing_file = runtime / 'debug-signing.json'
    signing = json.loads(signing_file.read_text(encoding='utf-8')) if signing_file.exists() and not args.debug_keystore else {}
    password = os.environ.get('GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD') or signing.get('password')
    alias = os.environ.get('GODOT_ANDROID_KEYSTORE_DEBUG_USER') or signing.get('alias', 'androiddebugkey')
    if keystore.exists() and not password:
        raise RuntimeError('Existing debug key requires GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD')
    password = password or secrets.token_hex(24)
    if not keystore.exists():
        subprocess.run([str(args.jdk / 'bin/keytool.exe'), '-genkeypair', '-keystore',
                        str(keystore), '-storepass', password, '-alias', alias,
                        '-keypass', password, '-dname', 'CN=Android Debug', '-keyalg',
                        'RSA', '-keysize', '2048', '-validity', '10000'], check=True)
    if not args.debug_keystore:
        signing_file.write_text(json.dumps({'password': password, 'alias': alias}), encoding='utf-8')
    settings = runtime / 'Godot/editor_settings-4.6.tres'
    settings.parent.mkdir(parents=True, exist_ok=True)
    values = {'java_sdk_path': args.jdk.resolve().as_posix(),
              'android_sdk_path': args.sdk.resolve().as_posix(),
              'debug_keystore': keystore.resolve().as_posix()}
    settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' +
                        ''.join(f'export/android/{k} = {json.dumps(v)}\n' for k, v in values.items()),
                        encoding='utf-8')
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    log = runtime / 'export.log'
    env = dict(os.environ, APPDATA=str(runtime), JAVA_HOME=str(args.jdk),
               GODOT_ANDROID_KEYSTORE_DEBUG_PATH=str(keystore.resolve()),
               GODOT_ANDROID_KEYSTORE_DEBUG_USER=alias,
               GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=password)
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run([args.godot, '--headless', '--path', str(ROOT),
                                 '--export-debug', 'Android Preview', str(output)],
                                cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
    content = log.read_text(encoding='utf-8', errors='replace')
    if result.returncode or not output.exists() or any(
            marker in content for marker in ['SCRIPT ERROR', 'Export failed', 'Failed to load']):
        raise RuntimeError(f'Android export failed; see {log}')
    output.with_suffix('.apk.sha256').write_text(
        hashlib.sha256(output.read_bytes()).hexdigest() + '  ' + output.name + '\n', encoding='utf-8')
    print(f'DEBUG PREVIEW: {output} ({output.stat().st_size:,} bytes)')
    print(f'Export log: {log}')


if __name__ == '__main__':
    main()
