# 素材署名

当前主角来自用户提供的 `assets/incoming/企鹅高松灯.blend`，由高松灯头部与企鹅身体组成。
用户提供的组合模型下载来源：**-爱啃梨**《企鹅高松灯 3D模型 下载》，https://www.bilibili.com/video/BV15WD9BPEPR/ 。
视频简介说明发布者将两个现有模型组合，并列出以下身体与头部来源。

养成玩法参考 QQ 宠物；游戏程序、配饰与场景由本项目制作。
头部贴图、网格及表情形态随该文件内嵌提供，来自 **BanG Dream! Girls Band Party**，由 **BungleScrungle** 提取整理：
https://www.deviantart.com/bunglescrungle/art/BanG-Dream-MyGO-FBX-and-PMX-DL-1036304336 。
原下载页要求署名 **Bushiroad Games**，并说明上传者是模型提取者、并非建模作者。头部未核实取得权利方的公开分发许可，不能将以下企鹅身体的 CC BY 许可套用到头部。
本地个人体验版本保留该组合模型；未宣称取得其头部素材的公开分发许可。

企鹅身体：This work is based on **"Private (Madagascar)"**
(https://sketchfab.com/3d-models/private-madagascar-a288037027374e089d4744b3ad25ad24)
by **Guilherme Navarro** (https://sketchfab.com/guinavarro.al), licensed under
**CC BY 4.0** (https://creativecommons.org/licenses/by/4.0/).
原许可随下载包提供，保存在 `assets/tomori/body-license.txt`。

本项目对组合模型进行了 GLB 导出、贴图缩小、表情形态精简和企鹅翼根关节位置调整；增加了逐骨骼动作、表情控制、命中区域、配饰与道具。未修改原始 `.blend`。

备用纯企鹅（当前仅在组合模型缺失时使用）：

This work is based on **"Penguin (Rig-CntRig-Anim)"**
(https://sketchfab.com/3d-models/penguin-rig-cntrig-anim-db8a037d135b41b08752ce4c57f43525)
by **nicoma** (https://sketchfab.com/vladkozhukh), licensed under
**CC BY 4.0** (https://creativecommons.org/licenses/by/4.0/).

模型由用户通过 Sketchfab 官方下载提供，原始许可保存在 `assets/nicoma/license.txt`。
本项目修改了模型材质、脸部、眼睛及腹部表现；增加了程序骨骼互动、命中区域、配饰与道具。
保留原模型骨骼及六段动画。原作者不代表认可本游戏。

企鹅程序降级模型、配饰、小屋 SVG 背景、图标与场景几何均为本项目创建。
喂食用面包、小鱼干、鱼排和零食由本项目通过 Blender 脚本建模，生成脚本 `tools/build_food.py`，源文件位于 `assets/incoming/food/`。
篮球由本项目通过 Blender 脚本建模，源文件位于 `assets/incoming/sports/basketball.blend`，不含品牌标识。
吊挂训练沙袋及支架由本项目通过 Blender 脚本建模，源文件位于 `assets/incoming/sports/punching_bag.blend`，不含品牌标识。
数学课算盘由本项目通过 Blender 脚本建模，源文件位于 `assets/incoming/study/abacus.blend`，算珠由游戏代码独立控制。
科学研究放大镜由本项目通过 Blender 脚本建模，源文件位于 `assets/incoming/study/magnifier.blend`，镜片使用轻量透明材质。
音乐课麦克风由本项目通过 Blender 脚本建模，源文件位于 `assets/incoming/study/microphone.blend`；飘动音符使用游戏内简单几何网格。
作词课本子和铅笔由本项目通过 Blender 脚本建模，源文件位于 `assets/incoming/study/lyric_tools.blend`；书写笔迹由游戏代码生成。
中文字体通过 Windows 系统字体加载，不随安装包分发微软字体。

评估但未在发行包使用：Quaternius Textured Cute Monster Pack，CC0。
https://opengameart.org/content/textured-cute-monster-pack
候选原始 FBX / 贴图与 Blender 文件保留于源码供参考，不参与运行或导出。

Godot Engine 4.6.2，MIT License：https://godotengine.org/license/

- 发传单动作道具：纸叠与单张传单由项目原创几何模型生成；生成脚本 `tools/build_flyers.py`，源文件 `assets/incoming/work/flyers.blend`。
- 搬运工纸箱由项目通过 Blender 脚本建模，生成脚本 `tools/build_carry_box.py`，源文件 `assets/incoming/work/carry_box.blend`。

- 图书校对员的小桌、书本、翻页与印章由项目通过 Blender 脚本建模，生成脚本 `tools/build_proofreading.py`，源文件 `assets/incoming/work/proofreading.blend`。

- 程序员笔记本电脑与小桌由项目通过 Blender 脚本建模，生成脚本 `tools/build_laptop.py`，源文件 `assets/incoming/work/laptop.blend`；键盘按键和屏幕光标由游戏代码控制，不含品牌标识。

- 远程客服的拨盘电话、听筒与小桌由项目通过 Blender 脚本建模，生成脚本 `tools/build_telephone.py`，源文件 `assets/incoming/work/telephone.blend`；卷线由游戏代码生成，不含品牌标识。

- 导游三角小红旗由项目通过 Blender 脚本建模，生成脚本 `tools/build_guide_flag.py`，源文件 `assets/incoming/work/guide_flag.blend`；旗杆随实际翅尖移动，不含品牌标识。
