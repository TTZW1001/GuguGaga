# 企鹅小日子

Windows 64 位单机、全程静音的 3D 企鹅养成游戏。开发依据为上一级 `docs/开发说明.md`。

本版本主角使用用户提供的「企鹅高松灯.blend」。保留原有骨骼及表情形态，增加程序骨骼动作、互动、配饰挂点；运行时不需要 Blender。贴图缩至 1024px，保留游戏实际使用的 7 个表情形态。

双击 `build/企鹅小日子-1.0.1.exe` 即可运行，无需安装 Godot 或联网。
窗口可调整大小，最低 760×600，使用 Compatibility / OpenGL 3.3 渲染。

- 首次启动输入名字并领养；初始 500 金币、小鱼干×3、普通肥皂×2。领养后会自动发放符合条件的成就奖励（初次见面 +30、幸福企鹅 +80）。
- 点击头、肚子、左右翅膀和脚会有不同反馈。按住头部，轻轻来回移动约半秒即可抚摸；有效抚摸奖励间隔 20 秒。
- 底部喂食、洗澡使用背包物品，商店补充物品。点击顶部名字可改名、查看属性及已解锁动作。
- 学习和打工各有固定时长，只能同时进行一项。关掉游戏后继续计时，期间照顾不中断任务。
- 学费开始时全部预留，提前结束仅收实际进度的学费并退还余额。金币、属性、经验均保留小数，日常界面显示整数。
- 等级上限 20；中级任务按每天 1.5 小时估算约 52 天到满级。装扮由等级及成就解锁，奖励自动到账。
- Esc 关闭浮层。关闭窗口会再次保存。

单一存档位于 `%APPDATA%/Godot/app_userdata/企鹅小日子/penguin.json`，备份同目录 `.bak`。
购入、照顾、任务操作和奖励立即保存，平时每 15 秒保存。离线自然消耗最多补算 8 小时；活动按自身固定时长完成一次。
系统时钟倒退会重新定位剩余任务时间，向前异常跳变限制自然衰减。
损坏主存档自动尝试备份；所有存档均损坏时保留文件并提示，不自动覆盖旧宠物。

用 `G:\Godot\Godot_v4.6.2-stable_win64.exe` 打开 `project.godot` 可编辑。
Windows 导出预设使用 `tools/templates` 中的官方模板；若缺失，可运行 `python tools/fetch_templates.py` 下载所需两个 Windows 模板。

验证命令（测试时请将 APPDATA 指向工作区内隔离目录，避免触碰个人存档）：

```powershell
$env:APPDATA = "$PWD/tests/runtime"
& 'G:\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/test_state.gd
& 'G:\Godot\Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/test_ui.gd
```

企鹅身体作者 **Guilherme Navarro**，许可 **CC BY 4.0**；头部来源随用户提供的组合模型记录。备用纯企鹅作者 **nicoma**，许可 **CC BY 4.0**。完整来源、改动说明与引擎许可见 `assets/CREDITS.md` 和发行包 `素材署名.md`。
