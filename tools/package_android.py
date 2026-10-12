"""Export an Android preview or release without changing Windows artifacts/settings."""
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
    parser.add_argument('--release', action='store_true')
    parser.add_argument('--preset', help='Defaults to Android Preview or Android Release')
    parser.add_argument('--signing-file', type=Path, help='Private JSON with keystore, alias, password; never committed')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    for path in [args.sdk / 'platform-tools/adb.exe', args.jdk / 'bin/java.exe',
                 ROOT / ('tools/templates/android_release.apk' if args.release else 'tools/templates/android_debug.apk')]:
        if not path.is_file():
            raise FileNotFoundError(path)
    if args.release and not args.signing_file:
        parser.error('--release requires --signing-file with a persistent release key')
    if args.signing_file and args.debug_keystore:
        parser.error('Choose --signing-file or --debug-keystore')
    runtime = ROOT / ('tests/runtime/android-export-release' if args.release else 'tests/runtime/android-export')
    runtime.mkdir(parents=True, exist_ok=True)
    if args.signing_file:
        signing_file = args.signing_file.resolve()
        signing = json.loads(signing_file.read_text(encoding='utf-8'))
        keystore = Path(signing['keystore'])
        if not keystore.is_absolute():
            keystore = signing_file.parent / keystore
        if not keystore.is_file():
            raise FileNotFoundError(keystore)
        password, alias = signing['password'], signing['alias']
        if not password or not alias:
            raise ValueError('Signing password and alias must not be empty')
    else:
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
                            str(keystore), '-storepass:env', 'QPET_DEBUG_KEY_PASSWORD', '-alias', alias,
                            '-keypass:env', 'QPET_DEBUG_KEY_PASSWORD', '-dname', 'CN=Android Debug', '-keyalg',
                            'RSA', '-keysize', '2048', '-validity', '10000'], check=True,
                           env=dict(os.environ, QPET_DEBUG_KEY_PASSWORD=password))
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
    output = (args.output or ROOT / ('build/android/GuguGaga-1.3.2-android.apk' if args.release else 'build/android/GuguGaga-1.3.2-portrait-preview.apk')).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    log = runtime / 'export.log'
    env = {key: value for key, value in os.environ.items() if not key.startswith('GODOT_ANDROID_KEYSTORE_')}
    env.update(APPDATA=str(runtime), JAVA_HOME=str(args.jdk))
    prefix = 'GODOT_ANDROID_KEYSTORE_RELEASE_' if args.release else 'GODOT_ANDROID_KEYSTORE_DEBUG_'
    env.update({prefix + 'PATH': str(keystore.resolve()), prefix + 'USER': alias, prefix + 'PASSWORD': password})
    preset = args.preset or ('Android Release' if args.release else 'Android Preview')
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run([args.godot, '--headless', '--path', str(ROOT),
                                 '--export-release' if args.release else '--export-debug', preset, str(output)],
                                cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
    content = log.read_text(encoding='utf-8', errors='replace')
    if result.returncode or not output.exists() or any(
            marker in content for marker in ['SCRIPT ERROR', 'Export failed', 'Failed to load']):
        raise RuntimeError(f'Android export failed; see {log}')
    output.with_suffix('.apk.sha256').write_text(
        hashlib.sha256(output.read_bytes()).hexdigest() + '  ' + output.name + '\n', encoding='utf-8')
    print(f'{"RELEASE" if args.release else "DEBUG"}: {output} ({output.stat().st_size:,} bytes)')
    print(f'Export log: {log}')


if __name__ == '__main__':
    main()
