extends Node
const State = preload("res://scripts/state.gd")
const C = preload("res://scripts/catalog.gd")
const Penguin = preload("res://scripts/penguin.gd")
var game = State.new()
var ui: Control
var stage: SubViewportContainer
var viewport: SubViewport
var camera: Camera3D
var pet: Node3D
var panel: PanelContainer
var panel_body: VBoxContainer
var panel_title: Label
var panel_mode = ""
var status_bars: Dictionary = {}
var status_labels: Dictionary = {}
var info: Button
var coins: Label
var task_label: Label
var task_progress: ProgressBar
var task_end: Button
var toast: Label
var toast_time = 0.0
var hint: Label
var adopt_box: PanelContainer
var nickname: LineEdit
var tick = 0.0
var save_tick = 0.0
var pressed_part = ""
var press_pos = Vector2.ZERO
var motion_distance = 0.0
var press_time = 0.0
var stroked = false
var pressing = false
var smoke = false
var previous_task = ""
var pending_messages: Array[String] = []

func now() -> float: return Time.get_unix_time_from_system()

func _ready():
	Engine.max_fps = 60
	DisplayServer.window_set_min_size(Vector2i(760,600))
	get_tree().auto_accept_quit = false
	smoke = "--smoke" in OS.get_cmdline_user_args()
	game.message.connect(show_message)
	game.changed.connect(refresh)
	if smoke: game.path = "user://smoke-penguin.json"
	game.load_game(now())
	build_ui()
	build_world()
	refresh()
	if not pending_messages.is_empty():
		show_message("  /  ".join(pending_messages),9)
		pending_messages.clear()
	adopt_box.visible = not game.data.adopted
	if game.load_error:
		nickname.editable = false
		show_message("存档无法读取，原文件已保留；请检查存档备份后重新启动。",30)
	print("QPET_READY")
	if smoke: run_smoke()

func flat(color: Color, radius: int = 10) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s

func thin(color: Color) -> StyleBoxFlat:
	var s = flat(color,3)
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s

func label(text_: String, size_: int = 16, color: Color = Color("3f514e")) -> Label:
	var l = Label.new()
	l.text = text_
	l.add_theme_font_size_override("font_size",size_)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func button(text_: String, callback: Callable, primary: bool = false) -> Button:
	var b = Button.new()
	b.text = text_
	b.custom_minimum_size.y = 38
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	if primary:
		b.add_theme_stylebox_override("normal",flat(Color("718e7a"),8))
		b.add_theme_stylebox_override("hover",flat(Color("607d69"),8))
		b.add_theme_color_override("font_color",Color("fffaf0"))
		b.add_theme_color_override("font_hover_color",Color("fffaf0"))
	return b

func anchored(node: Control, left_: float, top_: float, right_: float, bottom_: float, offsets: Vector4):
	node.anchor_left = left_
	node.anchor_top = top_
	node.anchor_right = right_
	node.anchor_bottom = bottom_
	node.offset_left = offsets.x
	node.offset_top = offsets.y
	node.offset_right = offsets.z
	node.offset_bottom = offsets.w

func build_ui():
	ui = Control.new()
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	theme.default_font = font
	theme.default_font_size = 15
	theme.set_stylebox("normal","Button",flat(Color("eee6d8"),8))
	theme.set_stylebox("hover","Button",flat(Color("dce4d6"),8))
	theme.set_stylebox("pressed","Button",flat(Color("c8d8c5"),8))
	theme.set_stylebox("disabled","Button",flat(Color("e7e1d5"),8))
	var focus = flat(Color(0,0,0,0),8)
	focus.set_border_width_all(2)
	focus.border_color = Color("8d9f81")
	theme.set_stylebox("focus","Button",focus)
	theme.set_color("font_color","Button",Color("40514b"))
	theme.set_color("font_hover_color","Button",Color("2f4c3e"))
	theme.set_color("font_pressed_color","Button",Color("2f4c3e"))
	theme.set_color("font_disabled_color","Button",Color("9b9a90"))
	theme.set_stylebox("panel","PanelContainer",flat(Color("faf6ec"),14))
	theme.set_stylebox("normal","LineEdit",flat(Color("eee8db"),8))
	theme.set_stylebox("focus","LineEdit",focus)
	theme.set_color("font_color","LineEdit",Color("40514b"))
	theme.set_color("caret_color","LineEdit",Color("40514b"))
	theme.set_color("font_color","Label",Color("40514b"))
	ui.theme = theme
	var bg = ColorRect.new()
	bg.color = Color("f6f0e5")
	ui.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header = VBoxContainer.new()
	ui.add_child(header)
	anchored(header,0,0,1,0,Vector4(28,17,-28,104))
	header.add_theme_constant_override("separation",9)
	var statuses = HBoxContainer.new()
	header.add_child(statuses)
	statuses.add_theme_constant_override("separation",30)
	var keys = ["food","clean","mood"]
	var names = ["饱食","清洁","心情"]
	var colors = ["c39c61","83a9a5","b49aab"]
	for i in 3:
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		statuses.add_child(column)
		var l = label(names[i]+"    100",13)
		column.add_child(l)
		status_labels[keys[i]] = l
		var bar = ProgressBar.new()
		bar.custom_minimum_size.y = 5
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background",thin(Color("e5ddcd")))
		var fill = thin(Color(colors[i]))
		fill.content_margin_top = 0
		fill.content_margin_bottom = 0
		bar.add_theme_stylebox_override("fill",fill)
		column.add_child(bar)
		status_bars[keys[i]] = bar
	var row = HBoxContainer.new()
	header.add_child(row)
	info = button("小企鹅  /  Lv.1",func(): open_panel("profile"))
	info.add_theme_stylebox_override("normal",flat(Color(0,0,0,0),5))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(info)
	coins = label("金币  500",17,Color("9e7941"))
	row.add_child(coins)
	stage = SubViewportContainer.new()
	ui.add_child(stage)
	anchored(stage,0,0,1,1,Vector4(0,111,0,-116))
	stage.stretch = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var room = TextureRect.new()
	ui.add_child(room)
	ui.move_child(room,2)
	anchored(room,0,0,1,1,Vector4(0,111,0,-116))
	room.texture = load("res://assets/room.svg")
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(960,473)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	stage.add_child(viewport)
	var interaction = Control.new()
	ui.add_child(interaction)
	anchored(interaction,0,0,1,1,Vector4(0,111,0,-116))
	interaction.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	interaction.gui_input.connect(stage_input)
	hint = label("点点头、肚子、翅膀和脚  ·  按住头部轻轻移动来抚摸",12,Color("8a8c7b"))
	ui.add_child(hint)
	anchored(hint,0,1,1,1,Vector4(20,-105,-20,-79))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nav = HBoxContainer.new()
	ui.add_child(nav)
	anchored(nav,0,1,1,1,Vector4(26,-68,-26,-24))
	nav.add_theme_constant_override("separation",8)
	for entry in [["喂食","food"],["洗澡","clean"],["学习","study"],["打工","work"],["商店","shop"],["成就","achieve"],["装扮","dress"]]:
		var b = button(entry[0],func(): open_panel(entry[1]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(b)
	var task_box = VBoxContainer.new()
	ui.add_child(task_box)
	anchored(task_box,0.5,0,0.5,0,Vector4(-180,124,180,192))
	task_label = label("",13)
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task_box.add_child(task_label)
	task_progress = ProgressBar.new()
	task_progress.show_percentage = false
	task_progress.custom_minimum_size.y = 4
	task_progress.add_theme_stylebox_override("background",thin(Color("ded7c6")))
	task_progress.add_theme_stylebox_override("fill",thin(Color("90a58a")))
	task_box.add_child(task_progress)
	task_end = button("提前结束",request_end)
	task_end.custom_minimum_size.y = 28
	task_end.add_theme_font_size_override("font_size",12)
	task_end.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	task_box.add_child(task_end)
	toast = label("",14)
	ui.add_child(toast)
	anchored(toast,0,1,1,1,Vector4(22,-152,-22,-118))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel = PanelContainer.new()
	ui.add_child(panel)
	anchored(panel,1,0,1,1,Vector4(-402,118,-20,-164))
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	var title_row = HBoxContainer.new()
	column.add_child(title_row)
	panel_title = label("",20)
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(panel_title)
	title_row.add_child(button("关闭",func(): panel.hide(); panel_mode = ""))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation",10)
	scroll.add_child(panel_body)
	panel.hide()
	adopt_box = PanelContainer.new()
	ui.add_child(adopt_box)
	anchored(adopt_box,0.5,1,0.5,1,Vector4(-260,-234,260,-118))
	var intro = VBoxContainer.new()
	adopt_box.add_child(intro)
	var welcome = label("你好呀，往后的日子请多关照。",19)
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_child(welcome)
	var sub = label("给小家伙起个名字，一起慢慢长大。",13,Color("8b8c79"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_child(sub)
	var name_row = HBoxContainer.new()
	intro.add_child(name_row)
	nickname = LineEdit.new()
	nickname.text = "小企鹅"
	nickname.max_length = 12
	nickname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nickname)
	name_row.add_child(button("开始领养",func():
		if game.load_error: return
		game.adopt(nickname.text,now())
		adopt_box.hide()
		pet.perform("wing_r",2)
		show_message("欢迎回家！背包里有小鱼干 ×3、普通肥皂 ×2。",7)
	,true))

func build_world():
	var world = Node3D.new()
	viewport.add_child(world)
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff4e0")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	world.add_child(environment)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45,-35,0)
	key.light_color = Color("fff4df")
	key.light_energy = 0.75
	world.add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,140,0)
	fill.light_color = Color("d8ecea")
	fill.light_energy = 0.3
	world.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.05
	camera.position = Vector3(0,3.5,8)
	world.add_child(camera)
	camera.look_at(Vector3(0,1.28,0))
	camera.current = true
	if ResourceLoader.exists("res://assets/tomori/penguin.glb"):
		pet = load("res://scripts/tomori_penguin.gd").new()
	elif ResourceLoader.exists("res://assets/nicoma/scene.gltf"):
		pet = load("res://scripts/rig_penguin.gd").new()
	else:
		pet = Penguin.new()
	world.add_child(pet)
	pet.idle_seen.connect(func():
		if DisplayServer.window_is_focused() and game.data.adopted: game.witness_idle()
	)
	# Simple wooden floor and a soft contact shadow; no expensive real-time shadows.
	var wood_a = pet.material("c7ad89")
	var wood_b = pet.material("ceb895")
	for i in 24:
		var plank = pet.box(world,Vector3((i-11.5)*0.52,-0.055,0.4),Vector3(0.513,0.06,5.1),wood_a if i%3 == 0 else wood_b)
		plank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rug = pet.orb(world,Vector3(0,-0.005,0.15),Vector3(3.85,0.025,2.55),pet.material("d6d4b5"))
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow = pet.orb(pet,Vector3(0,0.025,0.03),Vector3(1.38,0.015,1.0),pet.material("a5a58d"))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func refresh():
	if not is_instance_valid(info): return
	var d = game.data
	var names = {"food":"饱食","clean":"清洁","mood":"心情"}
	for key in names:
		status_bars[key].value = d[key]
		status_labels[key].text = "%s    %d" % [names[key],int(round(d[key]))]
	info.text = "%s  /  Lv.%d   ·   %s" % [d.name,d.level,"传奇企鹅" if d.level == 20 else "经验 %d / %d" % [int(d.xp),int(C.next_xp(int(d.level)))]]
	coins.text = "金币  %d" % int(floor(d.coins+0.000001))
	var active = not d.task.is_empty()
	task_label.visible = active
	task_progress.visible = active
	task_end.visible = active
	if active:
		var cfg = C.task(d.task.kind,d.task.id)
		var left_ = int(ceil(cfg.duration-d.task.elapsed))
		task_label.text = "%s  ·  %02d:%02d" % [cfg.name,left_/60,left_%60]
		task_progress.value = d.task.elapsed/cfg.duration*100
	if is_instance_valid(pet):
		pet.update_task(d.task.get("kind",""),d.task.get("id",""))
		pet.low_mood = d.mood < 25 or d.food < 20 or d.clean < 20
		pet.update_accessories(d.head,d.neck,d.gold and d.level >= 20)
	if game.save_error: hint.text = "存档写入失败 · 请检查用户目录权限"
	elif not d.task.is_empty(): hint.text = "可以一边学习 / 打工，一边喂食、洗澡和摸摸头。"
	else: hint.text = "点点头、肚子、翅膀和脚  ·  按住头部轻轻移动来抚摸"
	var task_key = d.task.get("id","")
	if task_key != previous_task:
		previous_task = task_key
		if panel_mode in ["study","work"]: call_deferred("open_panel",panel_mode)

func show_message(value: String, seconds: float = 5.0):
	if is_instance_valid(toast): toast.text = value
	else: pending_messages.append(value)
	toast_time = seconds
	print(value)

func row_text(text_: String, size_: int = 14, color: Color = Color("536257")) -> Label:
	var l = label(text_,size_,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_body.add_child(l)
	return l

func divider():
	var h = HSeparator.new()
	h.modulate = Color(0.6,0.6,0.5,0.25)
	panel_body.add_child(h)

func open_panel(mode: String):
	if not game.data.adopted: return
	game.advance(now())
	panel_mode = mode
	panel.show()
	for n in panel_body.get_children():
		panel_body.remove_child(n)
		n.queue_free()
	var names = {"food":"开饭啦","clean":"洗个香香澡","study":"慢慢学，慢慢长大","work":"认真打工的小企鹅","shop":"小小补给铺","achieve":"我们的纪念","profile":"关于小家伙","dress":"今日装扮","end":"提前结束这项任务？"}
	panel_title.text = names.get(mode,mode)
	match mode:
		"food","clean","shop": item_panel(mode)
		"study","work": activity_panel(mode)
		"achieve": achievement_panel()
		"profile": profile_panel()
		"dress": dress_panel()

func item_panel(mode: String):
	row_text("买来的物品收进背包，用多少拿多少。" if mode == "shop" else "使用物品立即恢复状态，任务计时照常进行。",12,Color("8d8c7a"))
	for item in C.ITEMS:
		if mode == "food" and item.clean > 0: continue
		if mode == "clean" and item.clean == 0: continue
		var row = HBoxContainer.new()
		panel_body.add_child(row)
		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(label("%s  ×%d" % [item.name,game.data.inventory.get(item.id,0)],15))
		var restores: Array[String] = []
		for key in ["food","clean","mood"]:
			if item[key]>0: restores.append("%s +%d" % [{"food":"饱食","clean":"清洁","mood":"心情"}[key],item[key]])
		col.add_child(label("  ".join(restores),11,Color("8a8b78")))
		row.add_child(button("%d 金币" % item.price if mode == "shop" else "使用",func():
			var error = game.buy(item.id,now()) if mode == "shop" else game.use_item(item.id,now())
			if error != "": show_message(error)
			else:
				if mode != "shop": pet.perform("wash" if item.clean>0 else "feed",2.4)
				show_message("已买入"+item.name if mode == "shop" else "香香的，真舒服。" if item.clean>0 else "啊呜，真好吃！")
			open_panel(mode)
		))
		divider()
	if mode != "shop": panel_body.add_child(button("去商店补充",func():open_panel("shop")))

func activity_panel(kind: String):
	row_text("固定时长 · 可随时提前结束，按实际进度结算。",12,Color("8d8c7a"))
	if kind == "study": row_text("学费先预留；提前结束会自动退回未使用部分。",12,Color("8d8c7a"))
	if not game.data.task.is_empty(): row_text("已有任务进行中，照顾和购物仍可使用。",12,Color("b08b5b"))
	for row in C.COURSES if kind == "study" else C.JOBS:
		var cfg = C.task(kind,row[0])
		var h = HBoxContainer.new()
		panel_body.add_child(h)
		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(col)
		col.add_child(label("%s  ·  %d 分钟" % [cfg.name,cfg.duration/60],15))
		col.add_child(label("%s  ·  经验 +%d" % ["学费 %d / %s +%d" % [cfg.money,C.ATTR_NAMES[cfg.attr],cfg.gain] if kind == "study" else "工资 %d 金币" % cfg.money,cfg.xp],11,Color("7c8976")))
		col.add_child(label("饱食 −%d  清洁 −%d  %s" % [cfg.food,cfg.clean,"无属性要求" if cfg.need == 0 else "%s ≥%d" % [C.ATTR_NAMES[cfg.attr],cfg.need]],11,Color("8b8d7c")))
		var b = button("开始",func():
			var error = game.start_task(kind,cfg.id,now())
			if error != "": show_message(error)
			else:
				panel.hide()
				panel_mode = ""
				show_message("开始"+cfg.name+"，关掉游戏也会继续。",6)
		)
		b.disabled = not game.data.task.is_empty()
		h.add_child(b)
		divider()

func achievement_panel():
	row_text("%d / 20  ·  奖励自动到账，一起留住小小的成长。" % game.data.achievements.size(),12,Color("8a8c79"))
	var progress = game.achievement_values()
	for i in C.ACHIEVEMENTS.size():
		var a = C.ACHIEVEMENTS[i]
		var unlocked = a[0] in game.data.achievements
		var hidden = i >= 17 and not unlocked
		row_text(("✓  " if unlocked else "·  ")+("???" if hidden else a[1]),15)
		if not hidden:
			row_text(a[2]+("  ·  %d 金币" % a[3] if a[3]>0 else ""),11,Color("8a8c79"))
			if not unlocked: row_text("进度 %.1f / %.0f" % [minf(progress[i][0],progress[i][1]),progress[i][1]],11,Color("8a8c79"))
		divider()

func profile_panel():
	row_text("武力  %.1f    智力  %.1f    魅力  %.1f" % [game.data.power,game.data.mind,game.data.charm],15)
	row_text("累计学习 %.1f 小时 · 打工 %.1f 小时" % [game.data.stats.study/3600,game.data.stats.work/3600],12)
	if game.data.level == 20: row_text("称号 · 传奇企鹅 / 满级纪念",14,Color("aa8952"))
	if not game.data.task.is_empty() and game.data.task.kind == "study": row_text("课程预留学费 %.2f 金币（已从可用金币扣除）" % game.data.task.escrow,12)
	divider()
	var edit = LineEdit.new()
	edit.text = game.data.name
	edit.max_length = 12
	panel_body.add_child(edit)
	panel_body.add_child(button("保存名字",func():game.rename(edit.text);open_panel("profile");show_message("以后就叫这个名字啦。")))
	panel_body.add_child(button("去看看装扮",func():open_panel("dress")))
	divider()
	row_text("小家伙的拿手动作",14)
	for entry in [["spin","开心转圈",2],["dance","跳个小舞",5],["celebrate","庆祝一下",10]]:
		var b = button(entry[1]+(" · Lv.%d 解锁" % entry[2] if game.data.level<entry[2] else ""),func():pet.perform(entry[0],2.8);show_message(entry[1]+"！"))
		b.disabled = game.data.level < entry[2]
		panel_body.add_child(b)
	divider()
	row_text("自动存档 · 关闭窗口后任务继续，离线自然消耗最多补算 8 小时。",12,Color("8a8c79"))
	row_text("存档位置："+ProjectSettings.globalize_path(game.path),10,Color("8a8c79"))

func dress_panel():
	row_text("一件头饰 + 一件颈饰，都是成长的礼物。",12,Color("8a8c79"))
	for a in C.ACCESSORIES:
		if a[0] == "none":
			divider()
			row_text("头饰" if a[2] == "head" else "颈部配饰",15)
		var unlocked = game.accessory_unlocked(a)
		var condition = "Lv.%d" % a[3] if a[4] == "" else "三好学生成就" if a[4] == "all60" else "职场达人成就"
		var text_ = a[1]+("  ·  已佩戴" if game.data[a[2]] == a[0] else "" if unlocked else "  ·  "+condition)
		var b = button(text_,func():game.equip(a);open_panel("dress"))
		b.disabled = not unlocked
		panel_body.add_child(b)
	divider()
	var golden = button("金色外观"+("  ·  Lv.20 解锁" if game.data.level<20 else "  ·  已开启" if game.data.gold else ""),func():game.data.gold = not game.data.gold;game.commit();open_panel("dress"))
	golden.disabled = game.data.level<20
	panel_body.add_child(golden)

func request_end():
	if game.data.task.is_empty(): return
	open_panel("end")
	var t = game.data.task
	var cfg = C.task(t.kind,t.id)
	var ratio = t.elapsed/cfg.duration
	row_text("目前完成 %.1f%%，结算经验 %.2f。" % [ratio*100,cfg.xp*ratio],14)
	row_text("退还学费 %.2f，获得属性 %.2f。" % [t.escrow*(1-ratio),cfg.gain*ratio] if t.kind=="study" else "获得工资 %.2f 金币。" % (cfg.money*ratio),14)
	row_text("小数收益会完整保留，界面日常显示整数。",12,Color("8a8c79"))
	panel_body.add_child(button("确认提前结束",func():game.end_task(now());panel.hide();panel_mode="",true))
	panel_body.add_child(button("继续任务",func():panel.hide();panel_mode=""))

func hit_part(pos: Vector2) -> String:
	var origin = camera.project_ray_origin(pos)
	var direction = camera.project_ray_normal(pos)
	var query = PhysicsRayQueryParameters3D.create(origin,origin+direction*30)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result = camera.get_world_3d().direct_space_state.intersect_ray(query)
	return result.collider.get_meta("part","") if not result.is_empty() else ""

func stage_input(event: InputEvent):
	if not is_instance_valid(camera) or not game.data.adopted: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed_part = hit_part(event.position)
			pressing = not pressed_part.is_empty()
			press_pos = event.position
			motion_distance = 0
			press_time = Time.get_ticks_msec()/1000.0
			stroked = false
		elif pressing:
			pressing = false
			# Bind a short click to the body region hit on press; idle animation can
			# move a thin flipper away before the mouse button is released.
			if not stroked and motion_distance < 16:
				game.interact(false,now(),Time.get_datetime_dict_from_system().hour)
				if game.clicks.size() >= 6:
					pet.perform("angry",1.8)
					show_message("慢一点嘛，小家伙被戳晕啦。")
				else:
					pet.perform(pressed_part,1.8)
					show_message({"head":"嗯？是在叫我吗。","belly":"嘿嘿，肚子痒痒！","wing_l":"左边挥挥手～","wing_r":"你好呀！","feet":"蹦！"}.get(pressed_part,"你好呀。"),2.5)
	if event is InputEventMouseMotion and pressing:
		motion_distance += event.relative.length()
		if pressed_part == "head" and not stroked and motion_distance>=18 and Time.get_ticks_msec()/1000.0-press_time>=0.3 and event.position.distance_to(press_pos)<120 and hit_part(event.position)=="head":
			stroked = true
			var rewarded = game.interact(true,now(),Time.get_datetime_dict_from_system().hour)
			pet.perform("pet",2.2)
			show_message(("♥ " if "pet" in game.data.achievements else "")+"好舒服呀。"+("  心情 +2" if rewarded else ""),3)

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		panel.hide()
		panel_mode = ""
		pressing = false
	if event is InputEventMouseButton and not event.pressed and not stage.get_global_rect().has_point(event.position): pressing = false

func _process(delta: float):
	tick += delta
	save_tick += delta
	if tick >= 0.5:
		tick = 0
		game.advance(now())
	if save_tick >= 15:
		save_tick = 0
		game.save()
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0 and is_instance_valid(toast): toast.text = ""

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		game.advance(now())
		if game.data.adopted and not game.save() and game.save_error:
			show_message("保存失败，暂未退出。请检查存档目录。",15)
			return
		get_tree().quit()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and not game.data.is_empty(): game.advance(now())
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pressing = false
		if not game.data.is_empty(): game.advance(now());game.save()

func run_smoke():
	await get_tree().create_timer(1.0).timeout
	game.data = game.fresh(now())
	game.adopt("团团",now())
	adopt_box.hide()
	game.data.food = 60
	game.data.clean = 60
	refresh()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/output/home.png")
	open_panel("study")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/output/study.png")
	panel.hide()
	game.start_task("study","read",now())
	game.use_item("fish",now())
	pet.perform("feed",2)
	await get_tree().create_timer(2.5).timeout
	open_panel("achieve")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/output/achievements.png")
	panel.hide()
	get_window().size = Vector2i(760,600)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/output/small.png")
	game.save()
	print("UI_SMOKE_PASS")
	get_tree().quit()
