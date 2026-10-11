"""Build the Windows release and assemble its portable distribution."""
import argparse
import hashlib
import os
import pathlib
import re
import shutil
import subprocess
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot', help='Godot console executable')
    parser.add_argument('--skip-build', action='store_true', help='Package an already exported EXE')
    args = parser.parse_args()
    version = re.search(r'^config/version="([\d.]+)"', (ROOT / 'project.godot').read_text(encoding='utf-8'), re.M)[1]
    build = ROOT / 'build'
    build.mkdir(exist_ok=True)
    (build / '.gdignore').touch()
    exe = build / f'养一只咕咕嘎嘎吧！-{version}.exe'
    if not args.skip_build:
        runtime = ROOT / 'tests/runtime' / f'export-{version}'
        runtime.mkdir(parents=True, exist_ok=True)
        log = runtime / 'export.log'
        with log.open('w', encoding='utf-8') as output:
            result = subprocess.run(
                [args.godot, '--headless', '--path', str(ROOT), '--export-release',
                 'Windows Desktop', str(exe)], cwd=ROOT,
                env=dict(os.environ, APPDATA=str(runtime)), stdout=output,
                stderr=subprocess.STDOUT, encoding='utf-8')
        text = log.read_text(encoding='utf-8', errors='replace')
        if result.returncode or any(error in text for error in ['SCRIPT ERROR', 'Export failed', 'Failed to load']):
            raise RuntimeError(f'Export failed; see {log}')
        print(f'Export log: {log}', flush=True)
    if not exe.is_file():
        raise FileNotFoundError(exe)
    usage = f'''# 养一只咕咕嘎嘎吧！ · {version}

解压后双击 `{exe.name}` 即可运行。Windows 64 位单机游戏，无需安装、联网，全程静音。

- 点击头、肚子、翅膀或脚；按住头部轻轻移动可抚摸。
- 拖动地面旋转角色，停下 10 秒后回正。
- 喂食、洗澡菜单可连续使用物品，点击外面或按 Esc 收起。
- 点击名字查看资料、成就和装扮。左侧模型可旋转、预览动作，预览不打断主场景任务。
- 改名、装扮和设置自动保存。Lv.20 解锁「高雅人士」套装，与头饰、颈饰互斥。
- 学习、打工同时只能进行一项，退出游戏后任务继续。
- 「常规」设置可调整窗口大小、30 / 60 FPS、后台省电，并打开存档文件夹；「关于」提供游玩方法、素材来源和仓库链接。
- 弹窗支持滚轮滚动，右上角、弹窗外和 Esc 均可关闭。

沿用旧版存档：`%APPDATA%/Godot/app_userdata/企鹅小日子/penguin.json`，备份为同目录 `.bak`。更新版本无需搬运存档。请勿同时运行新旧版本，以免互相覆盖存档。

素材来源、署名和改动见同目录 `素材署名.md`，引擎许可见 `GODOT_LICENSE.txt`。
'''
    (build / '使用说明.md').write_text(usage, encoding='utf-8')
    shutil.copyfile(ROOT / 'assets/CREDITS.md', build / '素材署名.md')
    shutil.copyfile(ROOT / 'assets/GODOT_LICENSE.txt', build / 'GODOT_LICENSE.txt')
    archive = build / f'养一只咕咕嘎嘎吧！-{version}-Windows.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        for file in [exe, build / '使用说明.md', build / '素材署名.md', build / 'GODOT_LICENSE.txt']:
            package.write(file, file.name)
    with zipfile.ZipFile(archive) as package:
        if package.testzip() is not None:
            raise RuntimeError('ZIP integrity check failed')
        if hashlib.sha256(package.read(exe.name)).digest() != hashlib.sha256(exe.read_bytes()).digest():
            raise RuntimeError('Packaged EXE differs from export')
    sums = build / f'SHA256SUMS-{version}.txt'
    sums.write_text(''.join(f'{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n'
                            for file in [exe, archive]), encoding='utf-8')
    for file in [exe, archive, sums]:
        print(f'{file.name}: {file.stat().st_size:,} bytes', flush=True)


if __name__ == '__main__':
    main()
