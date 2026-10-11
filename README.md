# 养一只咕咕嘎嘎吧！

双击 `build/养一只咕咕嘎嘎吧！-1.2.0.exe` 即可运行。Windows 64 位单机游戏，无需安装、联网，全程静音。

窗口默认 16:9，按屏幕大小调整；最低 960×540。使用 Compatibility / OpenGL 3.3 渲染。

- 点击头、肚子、翅膀或脚；按住头部轻轻移动可抚摸。
- 拖动地面可旋转角色，停下 10 秒后回正。
- 右侧喂食、洗澡菜单可连续使用物品；点击外面、再次点击入口或按 Esc 收起。
- 点击名字查看资料、成就和装扮。左侧模型可独立旋转，改名和装扮自动保存。
- Lv.20 解锁「高雅人士」套装，替代金色外观；与头饰、颈饰互斥。再次点击套装可脱下并恢复原配饰，选择配饰也可退出套装。
- 学习、打工只能同时进行一项。照顾不中断任务，关闭游戏后任务继续。
- 弹窗支持滚轮滚动；右上角、弹窗外和 Esc 均可关闭。

沿用旧版存档：`%APPDATA%/Godot/app_userdata/企鹅小日子/penguin.json`，备份为同目录 `.bak`。购入、使用、任务操作及奖励立即保存，平时每 15 秒保存。正常关闭再次保存。

开发：用 Godot 4.6.2 打开 `project.godot`。导出模板位于 `tools/templates`，缺失时运行 `python tools/fetch_templates.py`。

已确认的最新动作优化请通过 Godot 运行当前工程；现有 `1.2.0` EXE 和发行 ZIP 为动作优化前版本。动作由 `scripts/tomori_penguin.gd` 中的程序骨骼动画控制，新增道具位于 `assets/food`、`assets/sports`、`assets/study` 和 `assets/work`。

主角为用户提供的「企鹅高松灯.blend」，企鹅身体作者 Guilherme Navarro（CC BY 4.0）；备用模型作者 nicoma（CC BY 4.0）。来源、改动及引擎许可见 `assets/CREDITS.md` 和发行包 `素材署名.md`。
