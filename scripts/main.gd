extends Node
const State = preload("res://scripts/state.gd")
const C = preload("res://scripts/catalog.gd")
const Penguin = preload("res://scripts/penguin.gd")
const Platform = preload("res://scripts/platform.gd")
const PortraitLayout = preload("res://scripts/portrait_layout.gd")
var portrait = Platform.portrait()
var room: TextureRect
var interaction: Control
var growth: VBoxContainer
var statuses: HBoxContainer
var toolbar: BoxContainer
var settings_button: Button
var game = State.new()
var ui: Control
var hud: Control
var stage: SubViewportContainer
var viewport: SubViewport
var camera: Camera3D
var pet: Node3D
var info: Button
var coins: Label
var level_label: Label
var xp_label: Label
var xp_bar: ProgressBar
var attributes: Label
var status_bars: Dictionary = {}
var status_labels: Dictionary = {}
var idle_actions: HBoxContainer
var task_box: VBoxContainer
var task_label: Label
var task_progress: ProgressBar
var task_end: Button
var toast: Label
var toast_time = 0.0
var hint: Label
var adopt_box: PanelContainer
var nickname: LineEdit
var modal: Control
var panel: PanelContainer
var panel_body: VBoxContainer
var panel_title: Label
var panel_error: Label
var panel_close: Button
var panel_scroll: ScrollContainer
var scroll_fade: TextureRect
var panel_mode = ""
var panel_tween: Tween
var previous_focus: Control
var tabs: HBoxContainer
var tab_buttons: Dictionary = {}
var profile_tab = "profile"
var settings_tabs: HBoxContainer
var settings_buttons: Dictionary = {}
var settings_tab = "general"
var settings_path = "user://settings.cfg"
var preferences = {"window_width":0,"fps":60,"background_saving":true}
var window_focused = true
var application_paused = false
var name_edit: LineEdit
var preview_pane: Control
var preview_viewport: SubViewport
var preview_pet: Node3D
var preview_dragging = false
var item_menu: PanelContainer
var menu_body: VBoxContainer
var menu_title: Label
var menu_error: Label
var menu_mode = ""
var item_buttons: Dictionary = {}
var stock_labels: Dictionary = {}
var rotating = false
var rotate_idle = 0.0
var return_tween: Tween
var tick = 0.0
var save_tick = 0.0
var reported_save_error = false
var pressed_part = ""
var press_pos = Vector2.ZERO
var motion_distance = 0.0
var press_time = 0.0
var stroked = false
var pressing = false
var pending_messages: Array[String] = []

func now() -> float: return Time.get_unix_time_from_system()

func _ready():
	load_preferences()
	apply_window_size()
	apply_frame_limit()
	get_tree().auto_accept_quit = false
	if OS.has_feature("android"):get_tree().quit_on_go_back=false
	game.message.connect(show_message)
	game.changed.connect(refresh)
	if "--smoke" in OS.get_cmdline_user_args(): game.path="user://smoke-penguin.json"
	game.load_game(now())
	build_ui()
	build_world()
	build_preview()
	if portrait:
		PortraitLayout.apply(self)
		get_viewport().size_changed.connect(func():PortraitLayout.apply(self))
		PortraitLayout.apply.call_deferred(self)
	refresh()
	if OS.has_feature("android"):update_mobile_activity()
	if not pending_messages.is_empty():
		show_message(" / ".join(pending_messages),8)
		pending_messages.clear()
	adopt_box.visible = not game.data.adopted
	if game.load_error:
		nickname.editable=false
		show_message("存档无法读取，原文件已保留。",30)
	print("QPET_READY")

func configure_window():
	if portrait:
		Platform.configure_window(get_window())
		return
	DisplayServer.window_set_min_size(Vector2i(960,540))
	var usable=DisplayServer.screen_get_usable_rect()
	if usable.size.x<1: return
	var width=minf(1920,usable.size.x*0.68)
	width=minf(width,usable.size.y*0.84*16.0/9.0)
	width=maxf(minf(960,usable.size.x*0.95),width)
	var desired=Vector2i(int(width),int(width*9.0/16.0))
	get_window().size=desired
	DisplayServer.window_set_position(usable.position+(usable.size-desired)/2)

func load_preferences():
	var cfg=ConfigFile.new()
	if cfg.load(settings_path)!=OK:return
	var width=cfg.get_value("general","window_width",0)
	var fps=cfg.get_value("general","fps",60)
	var saving=cfg.get_value("general","background_saving",true)
	if width in [0,1280,1600,1920]:preferences.window_width=int(width)
	if fps in [30,60]:preferences.fps=int(fps)
	if saving is bool:preferences.background_saving=saving

func save_preferences():
	var cfg=ConfigFile.new()
	for key in preferences:cfg.set_value("general",key,preferences[key])
	if cfg.save(settings_path)!=OK:show_message("设置保存失败，请检查存档目录。",5)

func apply_window_size():
	configure_window()
	if portrait:return
	if preferences.window_width==0:return
	var usable=DisplayServer.screen_get_usable_rect()
	if usable.size.x<1:return
	var width=minf(preferences.window_width,minf(usable.size.x-48,(usable.size.y-48)*16.0/9.0))
	width=maxf(960,floorf(width/16)*16)
	var desired=Vector2i(int(width),int(width*9/16))
	get_window().size=desired
	DisplayServer.window_set_position(usable.position+(usable.size-desired)/2)

func apply_frame_limit():
	Engine.max_fps=15 if preferences.background_saving and (not window_focused or application_paused) else preferences.fps
	if OS.has_feature("android"):update_mobile_activity()

func update_mobile_activity():
	var active=window_focused and not application_paused
	if is_instance_valid(pet):pet.process_mode=Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	var preview_active=active and is_instance_valid(modal) and modal.visible and panel_mode=="profile"
	if is_instance_valid(preview_pet):preview_pet.process_mode=Node.PROCESS_MODE_INHERIT if preview_active else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(preview_viewport):preview_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if preview_active else SubViewport.UPDATE_DISABLED

func suspend_game():
	pressing=false
	rotating=false
	preview_dragging=false
	save_profile_name()
	if not game.data.is_empty():
		game.advance(now())
		game.save()
	save_tick=0

func resume_game():
	if game.data.is_empty():return
	# A still-running session keeps the existing real-time decay rules. Only
	# load_game applies the eight-hour cap after a process restart.
	game.advance(now())
	game.save()
	tick=0
	save_tick=0

func flat(color: Color, radius: int = 10) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.content_margin_left=16
	s.content_margin_right=16
	s.content_margin_top=10
	s.content_margin_bottom=10
	return s

func label(text_: String, size_: int=16, color: Color=Color("40514b")) -> Label:
	var l=Label.new()
	l.text=text_
	l.add_theme_font_size_override("font_size",maxi(16,size_) if portrait else size_)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func button(text_: String, callback: Callable, primary: bool=false) -> Button:
	var b=Button.new()
	b.text=text_
	b.custom_minimum_size.y=44 if portrait else 42
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	if primary:
		b.add_theme_stylebox_override("normal",flat(Color("718e7a")))
		b.add_theme_stylebox_override("hover",flat(Color("607d69")))
		b.add_theme_stylebox_override("pressed",flat(Color("506f5b")))
		b.add_theme_color_override("font_color",Color("fffaf0"))
		b.add_theme_color_override("font_hover_color",Color("fffaf0"))
		b.add_theme_color_override("font_pressed_color",Color("fffaf0"))
		b.add_theme_color_override("font_hover_pressed_color",Color("fffaf0"))
		b.add_theme_color_override("font_focus_color",Color("fffaf0"))
	return b

func anchored(node: Control, left_: float, top_: float, right_: float, bottom_: float, offsets: Vector4):
	node.anchor_left=left_
	node.anchor_top=top_
	node.anchor_right=right_
	node.anchor_bottom=bottom_
	node.offset_left=offsets.x
	node.offset_top=offsets.y
	node.offset_right=offsets.z
	node.offset_bottom=offsets.w

func progress_bar(color: String, height: float=5) -> ProgressBar:
	var bar=ProgressBar.new()
	bar.custom_minimum_size.y=height
	bar.show_percentage=false
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var bg=flat(Color("e5ddcd"),3)
	bg.content_margin_top=0
	bg.content_margin_bottom=0
	var fill=bg.duplicate()
	fill.bg_color=Color(color)
	bar.add_theme_stylebox_override("background",bg)
	bar.add_theme_stylebox_override("fill",fill)
	return bar

func build_ui():
	ui=Control.new()
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme=Theme.new()
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	theme.default_font=font
	theme.default_font_size=18 if portrait else 16
	theme.set_stylebox("normal","Button",flat(Color("eee6d8")))
	theme.set_stylebox("hover","Button",flat(Color("dce4d6")))
	theme.set_stylebox("pressed","Button",flat(Color("c8d8c5")))
	theme.set_stylebox("disabled","Button",flat(Color("eee9df")))
	var focus=flat(Color(0,0,0,0))
	focus.set_border_width_all(2)
	focus.border_color=Color("8d9f81")
	theme.set_stylebox("focus","Button",focus)
	for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:theme.set_color(key,"Button",Color("40514b"))
	theme.set_color("font_disabled_color","Button",Color("9b9a90"))
	var panel_style=flat(Color("faf6ec"),16)
	panel_style.content_margin_left=16 if portrait else 26
	panel_style.content_margin_right=16 if portrait else 26
	panel_style.content_margin_top=12 if portrait else 20
	panel_style.content_margin_bottom=12 if portrait else 20
	panel_style.shadow_color=Color(0.1,0.15,0.12,0.14)
	panel_style.shadow_size=16
	theme.set_stylebox("panel","PanelContainer",panel_style)
	theme.set_stylebox("normal","LineEdit",flat(Color("eee8db")))
	theme.set_stylebox("focus","LineEdit",focus)
	theme.set_color("font_color","LineEdit",Color("40514b"))
	theme.set_color("caret_color","LineEdit",Color("40514b"))
	theme.set_color("font_color","Label",Color("40514b"))
	ui.theme=theme
	var bg=ColorRect.new()
	bg.color=Color("f6f0e5")
	ui.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud=Control.new()
	ui.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	room=TextureRect.new()
	hud.add_child(room)
	anchored(room,0,0,1,1,Vector4(0,82,0,-78))
	room.texture=load("res://assets/room_portrait.svg" if portrait else "res://assets/room.svg")
	room.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage=SubViewportContainer.new()
	hud.add_child(stage)
	anchored(stage,0,0,1,1,Vector4(0,82,0,-78))
	stage.stretch=true
	stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,560)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	stage.add_child(viewport)
	interaction=Control.new()
	hud.add_child(interaction)
	anchored(interaction,0,0,1,1,Vector4(0,82,0,-78))
	interaction.gui_input.connect(stage_input)
	info=button("小嘎嘎",func():open_panel("profile"))
	info.clip_text=true
	info.alignment=HORIZONTAL_ALIGNMENT_LEFT
	info.tooltip_text="资料 · 成就 · 装扮"
	info.add_theme_stylebox_override("normal",flat(Color(0,0,0,0)))
	hud.add_child(info)
	anchored(info,0,0,0,0,Vector4(18,21,228,63))
	growth=VBoxContainer.new()
	hud.add_child(growth)
	anchored(growth,0,0,0,0,Vector4(252,21,410,62))
	level_label=label("Lv.1",15)
	var growth_row=HBoxContainer.new()
	growth.add_child(growth_row)
	level_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	growth_row.add_child(level_label)
	xp_label=label("0 / 120",12,Color("7c8976"))
	xp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	growth_row.add_child(xp_label)
	xp_bar=progress_bar("b7a17c")
	growth.add_child(xp_bar)
	statuses=HBoxContainer.new()
	hud.add_child(statuses)
	anchored(statuses,0,0,1,0,Vector4(452,21,-208,62))
	statuses.add_theme_constant_override("separation",24)
	for entry in [["food","饱食","c39c61"],["clean","清洁","83a9a5"],["mood","心情","b49aab"]]:
		var col=VBoxContainer.new()
		col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		statuses.add_child(col)
		var text_=label(entry[1],14)
		col.add_child(text_)
		status_labels[entry[0]]=text_
		var bar=progress_bar(entry[2])
		col.add_child(bar)
		status_bars[entry[0]]=bar
	coins=label("金币 500",18,Color("9e7941"))
	coins.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(coins)
	anchored(coins,1,0,1,0,Vector4(-188,21,-30,63))
	attributes=label("",16)
	attributes.add_theme_constant_override("line_spacing",16)
	hud.add_child(attributes)
	anchored(attributes,0,0,0,0,Vector4(34,120,210,244))
	toolbar=BoxContainer.new()
	toolbar.vertical=true
	hud.add_child(toolbar)
	anchored(toolbar,1,0.5,1,0.5,Vector4(-112,-120,-28,138))
	toolbar.add_theme_constant_override("separation",12)
	for entry in [["商店","shop"],["喂食","food"],["洗澡","clean"]]:
		var b=button(entry[0],func():open_panel("shop") if entry[1]=="shop" else toggle_menu(entry[1]))
		b.custom_minimum_size=Vector2(84,76)
		var style=flat(Color(0.98,0.96,0.91,0.92),16)
		style.content_margin_top=42
		style.content_margin_bottom=9
		b.add_theme_stylebox_override("normal",style)
		var hover=style.duplicate()
		hover.bg_color=Color("e4eadc")
		b.add_theme_stylebox_override("hover",hover)
		b.add_theme_stylebox_override("pressed",hover)
		toolbar.add_child(b)
		var icon=load("res://scripts/ui_icon.gd").new()
		icon.kind=entry[1]
		b.add_child(icon)
		icon.position=Vector2(28,9)
		icon.size=Vector2(28,28)
	var settings=button("设置",func():open_panel("settings"))
	settings_button=settings
	hud.add_child(settings)
	anchored(settings,0,1,0,1,Vector4(28,-65,112,-23))
	idle_actions=HBoxContainer.new()
	hud.add_child(idle_actions)
	anchored(idle_actions,0.5,1,0.5,1,Vector4(-248,-65,248,-20))
	idle_actions.add_theme_constant_override("separation",30)
	for entry in [["学习","study"],["打工","work"]]:
		var b=button(entry[0],func():open_panel(entry[1]),entry[1]=="study")
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		idle_actions.add_child(b)
	task_box=VBoxContainer.new()
	hud.add_child(task_box)
	anchored(task_box,0.5,1,0.5,1,Vector4(-270,-72,270,-13))
	var task_row=HBoxContainer.new()
	task_box.add_child(task_row)
	task_label=label("",16)
	task_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	task_row.add_child(task_label)
	task_end=button("提前结束",request_end)
	task_end.custom_minimum_size.y=34
	task_end.add_theme_font_size_override("font_size",14)
	task_row.add_child(task_end)
	task_progress=progress_bar("90a58a",5)
	task_box.add_child(task_progress)
	hint=label("",12,Color("8a8c7b"))
	hud.add_child(hint)
	anchored(hint,0.5,1,0.5,1,Vector4(-180,-102,180,-82))
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	build_item_menu()
	build_modal()
	toast=label("",14)
	ui.add_child(toast)
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	anchored(toast,0.15,1,0.85,1,Vector4(0,-128,0,-104))
	adopt_box=PanelContainer.new()
	ui.add_child(adopt_box)
	anchored(adopt_box,0.5,1,0.5,1,Vector4(-240,-213,240,-91))
	var intro=VBoxContainer.new()
	intro.add_theme_constant_override("separation",12)
	adopt_box.add_child(intro)
	intro.add_child(label("来起个名字吧~",20))
	var name_row=HBoxContainer.new()
	intro.add_child(name_row)
	nickname=LineEdit.new()
	nickname.text="小嘎嘎"
	nickname.max_length=12
	nickname.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	name_row.add_child(nickname)
	var adopt=button("开始领养！",func():
		if game.load_error:return
		game.adopt(nickname.text,now())
		adopt_box.hide()
		pet.perform("wing_r",2)
		show_message(game.data.name+"有家啦！",3)
	,true)
	adopt.disabled=game.load_error
	name_row.add_child(adopt)

func build_item_menu():
	item_menu=PanelContainer.new()
	item_menu.custom_minimum_size.x=312
	ui.add_child(item_menu)
	anchored(item_menu,1,0.5,1,0.5,Vector4(-440,-150,-128,190))
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",8 if portrait else 12)
	item_menu.add_child(col)
	menu_title=label("喂食",20)
	if portrait:
		var header=HBoxContainer.new()
		col.add_child(header)
		menu_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		header.add_child(menu_title)
		var close=button("×",close_menu)
		close.custom_minimum_size=Vector2(44,44)
		header.add_child(close)
	else:col.add_child(menu_title)
	menu_body=VBoxContainer.new()
	menu_body.add_theme_constant_override("separation",8)
	col.add_child(menu_body)
	menu_error=label("",13,Color("a57154"))
	menu_error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(menu_error)
	item_menu.hide()

func build_modal():
	modal=Control.new()
	ui.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var backdrop=ColorRect.new()
	modal.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader=ShaderMaterial.new()
	shader.shader=load("res://assets/modal_blur.gdshader")
	backdrop.material=shader
	backdrop.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:close_panel()
	)
	panel=PanelContainer.new()
	if portrait:panel.add_theme_font_size_override("font_size",16)
	modal.add_child(panel)
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var column=VBoxContainer.new()
	column.add_theme_constant_override("separation",10 if portrait else 16)
	panel.add_child(column)
	var header=HBoxContainer.new()
	column.add_child(header)
	panel_title=label("",20 if portrait else 23)
	panel_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(panel_title)
	var close=button("×",close_panel)
	panel_close=close
	close.name="Close"
	close.tooltip_text="关闭 · Esc"
	close.custom_minimum_size=Vector2(44,44) if portrait else Vector2(42,42)
	close.add_theme_font_size_override("font_size",24)
	header.add_child(close)
	var body_row=BoxContainer.new()
	body_row.vertical=portrait
	body_row.add_theme_constant_override("separation",8 if portrait else 28)
	body_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(body_row)
	preview_pane=Control.new()
	preview_pane.custom_minimum_size.x=0 if portrait else 330
	preview_pane.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body_row.add_child(preview_pane)
	var right=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.size_flags_vertical=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",8 if portrait else 16)
	body_row.add_child(right)
	tabs=HBoxContainer.new()
	right.add_child(tabs)
	for entry in [["资料","profile"],["成就","achieve"],["装扮","dress"]]:
		var b=button(entry[0],func():set_profile_tab(entry[1]))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.toggle_mode=true
		tabs.add_child(b)
		tab_buttons[entry[1]]=b
	settings_tabs=HBoxContainer.new()
	right.add_child(settings_tabs)
	for entry in [["常规","general"],["关于","about"]]:
		var b=button(entry[0],func():set_settings_tab(entry[1]))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.toggle_mode=true
		settings_tabs.add_child(b)
		settings_buttons[entry[1]]=b
	var scroll_area=Control.new()
	scroll_area.size_flags_vertical=Control.SIZE_EXPAND_FILL
	right.add_child(scroll_area)
	panel_scroll=ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	panel_scroll.follow_focus=true
	panel_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	panel_scroll.focus_mode=Control.FOCUS_ALL
	scroll_area.add_child(panel_scroll)
	panel_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_body=VBoxContainer.new()
	panel_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation",8 if portrait else 13)
	panel_scroll.add_child(panel_body)
	# A soft edge reveals that content continues, without drawing a scrollbar.
	var fade=GradientTexture2D.new()
	fade.gradient=Gradient.new()
	fade.gradient.set_color(0,Color(0.98,0.965,0.925,0))
	fade.gradient.set_color(1,Color("faf6ec"))
	fade.fill_from=Vector2(0,0)
	fade.fill_to=Vector2(0,1)
	scroll_fade=TextureRect.new()
	scroll_area.add_child(scroll_fade)
	scroll_fade.texture=fade
	scroll_fade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	anchored(scroll_fade,0,1,1,1,Vector4(0,-18,0,0))
	scroll_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel_error=label("",14,Color("a57154"))
	panel_error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(panel_error)
	modal.hide()

func new_pet() -> Node3D:
	if ResourceLoader.exists("res://assets/tomori/penguin.glb"):return load("res://scripts/tomori_penguin.gd").new()
	if ResourceLoader.exists("res://assets/nicoma/scene.gltf"):return load("res://scripts/rig_penguin.gd").new()
	return Penguin.new()

func build_preview():
	var container=SubViewportContainer.new()
	preview_pane.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch=true
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	preview_viewport=SubViewport.new()
	preview_viewport.size=Vector2i(330,360)
	preview_viewport.own_world_3d=true
	preview_viewport.transparent_bg=true
	preview_viewport.msaa_3d=Viewport.MSAA_2X
	container.add_child(preview_viewport)
	var env=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("fff4e0")
	env.environment.ambient_light_energy=0.6
	preview_viewport.add_child(env)
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-35,0)
	light.light_color=Color("fff4df")
	light.light_energy=0.75
	preview_viewport.add_child(light)
	var fill=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-20,140,0)
	fill.light_color=Color("d8ecea")
	fill.light_energy=0.3
	preview_viewport.add_child(fill)
	var cam=Camera3D.new()
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=3.3
	cam.position=Vector3(0,1.95,6)
	preview_viewport.add_child(cam)
	cam.look_at(Vector3(0,1.35,0))
	cam.current=true
	preview_pet=new_pet()
	preview_viewport.add_child(preview_pet)
	preview_pet.idle_left=1000000
	preview_pet.autonomous_idle=false
	preview_pet.process_mode=Node.PROCESS_MODE_DISABLED
	preview_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	var drag=Control.new()
	preview_pane.add_child(drag)
	drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drag.mouse_default_cursor_shape=Control.CURSOR_DRAG
	drag.tooltip_text="拖动旋转"
	drag.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:preview_dragging=event.pressed
		if event is InputEventMouseMotion and preview_dragging:preview_pet.view_yaw=wrapf(preview_pet.view_yaw+event.relative.x*0.012,-PI,PI)
	)

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
	camera.size = 3.5
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
	if not is_instance_valid(info):return
	var d=game.data
	for key in status_bars:
		status_bars[key].value=d[key]
		status_labels[key].text="%s  %d" % [{"food":"饱食","clean":"清洁","mood":"心情"}[key],int(round(d[key]))]
	info.text=d.name
	level_label.text="Lv.%d" % d.level
	xp_label.text="已满级" if d.level==20 else "%d / %d" % [d.xp,C.next_xp(d.level)]
	xp_bar.value=100 if d.level==20 else d.xp/C.next_xp(d.level)*100
	xp_bar.tooltip_text="已满级" if d.level==20 else "经验 %d / %d" % [d.xp,C.next_xp(d.level)]
	coins.text="金币  %d" % int(floor(d.coins+0.000001))
	attributes.text="武力   %.1f\n智力   %.1f\n魅力   %.1f" % [d.power,d.mind,d.charm]
	var active=not d.task.is_empty()
	if not active and panel_mode=="end":close_panel()
	idle_actions.visible=not active
	task_box.visible=active
	if active:
		var cfg=C.task(d.task.kind,d.task.id)
		var remaining=int(ceil(cfg.duration-d.task.elapsed))
		task_label.text="%s  ·  %02d:%02d" % [cfg.name,remaining/60,remaining%60]
		task_progress.value=d.task.elapsed/cfg.duration*100
	if is_instance_valid(pet):
		pet.update_task(d.task.get("kind",""),d.task.get("id",""))
		pet.low_mood=d.mood<25 or d.food<20 or d.clean<20
		pet.update_accessories(d.head,d.neck,d.gold and d.level>=20)
		pet.unlocked_idle_actions.clear()
		if d.adopted:
			for entry in C.ACTIONS:
				if d.level>=entry[2]:pet.unlocked_idle_actions.append(entry[0])
	if is_instance_valid(preview_pet):preview_pet.update_accessories(d.head,d.neck,d.gold and d.level>=20)
	if game.save_error and not reported_save_error:show_message("保存失败，请检查存档目录。",15)
	reported_save_error=game.save_error
	for id in item_buttons:
		if is_instance_valid(item_buttons[id]):item_buttons[id].get_node("Copy/Name").text="%s  ×%d" % [C.item(id).name,d.inventory.get(id,0)]
	for id in stock_labels:
		if is_instance_valid(stock_labels[id]):stock_labels[id].text="库存 %d" % d.inventory.get(id,0)

func show_message(value: String, seconds: float=4.0):
	if is_instance_valid(toast):toast.text=value
	else:pending_messages.append(value)
	toast_time=seconds
	print(value)

func clear_body():
	save_profile_name()
	name_edit=null
	stock_labels.clear()
	for n in panel_body.get_children():
		panel_body.remove_child(n)
		n.queue_free()

func row_text(text_: String, size_: int=14, color: Color=Color("536257")) -> Label:
	var l=label(text_,size_,color)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	panel_body.add_child(l)
	return l

func divider():
	var line=HSeparator.new()
	line.modulate=Color(0.6,0.6,0.5,0.2)
	panel_body.add_child(line)

func toggle_menu(mode: String):
	if not game.data.adopted:return
	if item_menu.visible and menu_mode==mode:
		close_menu()
		return
	close_panel()
	menu_mode=mode
	menu_title.text="喂食" if mode=="food" else "洗澡"
	menu_error.text=""
	item_buttons.clear()
	for node in menu_body.get_children():
		menu_body.remove_child(node)
		node.queue_free()
	for item in C.ITEMS:
		if (mode=="clean") != (item.clean>0):continue
		var b=button("",func():
			var error=game.use_item(item.id,now())
			menu_error.text=error
			if error.is_empty():
				if item.clean>0: pet.perform("wash",2.4)
				else: pet.feed_item(item.id)
				show_message("洗刷刷洗刷刷♪" if item.clean>0 else "好次好次~",2)
			refresh()
		)
		b.custom_minimum_size.y=60 if portrait else 64
		menu_body.add_child(b)
		var copy=VBoxContainer.new()
		copy.name="Copy"
		b.add_child(copy)
		copy.mouse_filter=Control.MOUSE_FILTER_IGNORE
		anchored(copy,0,0,1,1,Vector4(14,8,-14,-8))
		var title=label("%s  ×%d" % [item.name,game.data.inventory.get(item.id,0)],15)
		title.name="Name"
		copy.add_child(title)
		copy.add_child(label(item_effects(item),12,Color("7c8976")))
		item_buttons[item.id]=b
	menu_body.add_child(button("去商店",func():open_panel("shop")))
	item_menu.show()
	item_menu.size=Vector2(312,item_menu.get_combined_minimum_size().y)
	if portrait:
		menu_error.visible=not menu_error.text.is_empty()
		PortraitLayout.apply_item_menu(self)

func close_menu():
	if is_instance_valid(item_menu):item_menu.hide()
	menu_mode=""

func open_panel(mode: String):
	if not game.data.adopted:return
	game.advance(now())
	close_menu()
	pressing=false
	rotating=false
	if not modal.visible:previous_focus=get_viewport().gui_get_focus_owner()
	panel_mode="profile" if mode in ["profile","achieve","dress"] else mode
	panel_error.text=""
	var profile=panel_mode=="profile"
	preview_pane.visible=profile
	tabs.visible=profile
	settings_tabs.visible=panel_mode=="settings"
	reset_preview_action()
	if is_instance_valid(preview_pet):
		preview_pet.process_mode=Node.PROCESS_MODE_INHERIT if profile else Node.PROCESS_MODE_DISABLED
		preview_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if profile else SubViewport.UPDATE_DISABLED
	var half_width=500 if profile else 380
	anchored(panel,0.5,0.5,0.5,0.5,Vector4(-half_width,-260,half_width,260))
	panel_title.text={"profile":"我的企鹅","study":"学习","work":"打工","shop":"商店","settings":"设置","end":"提前结束"}.get(panel_mode,"")
	modal.show()
	anchored(toast,0.15,0,0.85,0,Vector4(0,74,0,96))
	if portrait:PortraitLayout.apply_panel(self)
	set_hud_focus(false)
	clear_body()
	panel_scroll.scroll_vertical=0
	match panel_mode:
		"profile":set_profile_tab(mode if mode in ["achieve","dress"] else profile_tab)
		"shop":shop_panel()
		"study","work":activity_panel(mode)
		"settings":settings_panel()
	if portrait:PortraitLayout.prepare_scroll_body(panel_body)
	if is_instance_valid(panel_tween):panel_tween.kill()
	panel.modulate.a=0
	panel_tween=create_tween()
	panel_tween.tween_property(panel,"modulate:a",1.0,0.16)
	panel_close.grab_focus()

func set_hud_focus(enabled: bool):
	for b in hud.find_children("*","Button",true,false):b.focus_mode=Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func close_panel():
	save_profile_name()
	if not is_instance_valid(modal):return
	modal.hide()
	if is_instance_valid(toast):anchored(toast,0.15,1,0.85,1,Vector4(0,-128,0,-104))
	if portrait and is_instance_valid(toast):PortraitLayout.apply(self)
	panel_mode=""
	preview_dragging=false
	if is_instance_valid(preview_pet):
		reset_preview_action()
		preview_pet.process_mode=Node.PROCESS_MODE_DISABLED
		preview_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	set_hud_focus(true)
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():previous_focus.grab_focus()

func set_profile_tab(tab: String):
	reset_preview_action()
	var scroll_position=panel_scroll.scroll_vertical if profile_tab==tab else 0
	clear_body()
	profile_tab=tab
	for key in tab_buttons:tab_buttons[key].set_pressed_no_signal(key==tab)
	match tab:
		"profile":profile_panel()
		"achieve":achievement_panel()
		"dress":dress_panel()
	if portrait:PortraitLayout.prepare_scroll_body(panel_body)
	panel_scroll.set_deferred("scroll_vertical",scroll_position)

func reset_preview_action():
	if not is_instance_valid(preview_pet):return
	preview_dragging=false
	preview_pet.perform("",1.0)
	preview_pet.action_left=0.0
	preview_pet.target=Vector3.ZERO
	preview_pet.position=Vector3.ZERO
	# Apply the neutral pose now, before a closed preview is suspended.
	preview_pet._process(0.0)

func preview_action(id: String, level: int):
	if panel_mode!="profile" or profile_tab!="profile" or game.data.level<level:return
	preview_pet.perform(id,2.8)

func item_effects(item: Dictionary) -> String:
	var restores: Array[String]=[]
	for key in ["food","clean","mood"]:
		if item[key]>0:restores.append("%s +%d" % [{"food":"饱食","clean":"清洁","mood":"心情"}[key],item[key]])
	return "  ".join(restores)

func shop_panel():
	for item in C.ITEMS:
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",18)
		panel_body.add_child(row)
		var copy=VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		copy.add_child(label(item.name,17))
		copy.add_child(label(item_effects(item),13,Color("7c8976")))
		var stock=label("库存 %d" % game.data.inventory.get(item.id,0),13,Color("8a8b78"))
		copy.add_child(stock)
		stock_labels[item.id]=stock
		wrap_list_copy(copy)
		row.add_child(button("%d 金币" % item.price,func():
			var error=game.buy(item.id,now())
			panel_error.text=error
			if error.is_empty():show_message("已购买 "+item.name,2)
		))
		divider()

func activity_panel(kind: String):
	if kind=="study":row_text("学费预留，提前结束退还余额。",13,Color("8a8b78"))
	for row in C.COURSES if kind=="study" else C.JOBS:
		var cfg=C.task(kind,row[0])
		var h=HBoxContainer.new()
		panel_body.add_child(h)
		var copy=VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		h.add_child(copy)
		copy.add_child(label("%s  ·  %d 分钟" % [cfg.name,cfg.duration/60],17))
		copy.add_child(label("%s  ·  经验 +%d" % ["学费 %d / %s +%d" % [cfg.money,C.ATTR_NAMES[cfg.attr],cfg.gain] if kind=="study" else "工资 %d 金币" % cfg.money,cfg.xp],13,Color("7c8976")))
		copy.add_child(label("饱食 −%d  清洁 −%d%s" % [cfg.food,cfg.clean,"" if cfg.need==0 else "  ·  %s ≥%d" % [C.ATTR_NAMES[cfg.attr],cfg.need]],13,Color("8a8b78")))
		wrap_list_copy(copy)
		var start=button("开始",func():
			var error=game.start_task(kind,cfg.id,now())
			panel_error.text=error
			if error.is_empty():
				close_panel()
				show_message("开始"+cfg.name,3)
		)
		start.name=cfg.id
		start.disabled=not game.data.task.is_empty()
		h.add_child(start)
		divider()

func wrap_list_copy(copy: VBoxContainer):
	if not portrait:return
	for child in copy.get_children():
		if child is Label:child.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func achievement_panel():
	row_text("已达成 %d / 20" % game.data.achievements.size(),15)
	var progress=game.achievement_values()
	for i in C.ACHIEVEMENTS.size():
		var a=C.ACHIEVEMENTS[i]
		var unlocked=a[0] in game.data.achievements
		var hidden=i>=17 and not unlocked
		row_text(("✓  " if unlocked else "·  ")+("???" if hidden else a[1]),17)
		if not hidden:
			row_text(a[2]+("  ·  %d 金币" % a[3] if a[3]>0 else ""),13,Color("8a8b78"))
			if not unlocked:row_text("%.1f / %.0f" % [minf(progress[i][0],progress[i][1]),progress[i][1]],12,Color("8a8b78"))
		divider()

func save_profile_name():
	if is_instance_valid(name_edit) and game.data.adopted:
		var clean=game.clean_name(name_edit.text)
		if clean!=game.data.name:game.rename(clean)
		name_edit.text=clean

func profile_panel():
	row_text("名字",14)
	name_edit=LineEdit.new()
	name_edit.text=game.data.name
	name_edit.max_length=12
	name_edit.custom_minimum_size.y=42
	panel_body.add_child(name_edit)
	name_edit.text_submitted.connect(func(_value):save_profile_name();name_edit.release_focus())
	name_edit.focus_exited.connect(save_profile_name)
	row_text("Lv.%d  ·  %s" % [game.data.level,"传奇企鹅" if game.data.level==20 else "经验 %d / %d" % [game.data.xp,C.next_xp(game.data.level)]],15)
	row_text("武力 %.1f   智力 %.1f   魅力 %.1f" % [game.data.power,game.data.mind,game.data.charm],14)
	row_text("学习 %.1f 小时   打工 %.1f 小时" % [game.data.stats.study/3600,game.data.stats.work/3600],13,Color("8a8b78"))
	divider()
	row_text("动作",15)
	for entry in C.ACTIONS:
		var b=button(entry[1]+(" · Lv.%d" % entry[2] if game.data.level<entry[2] else ""),func():preview_action(entry[0],entry[2]))
		b.disabled=game.data.level<entry[2]
		panel_body.add_child(b)

func dress_panel():
	for a in C.ACCESSORIES:
		if a[0]=="none":row_text("头饰" if a[2]=="head" else "颈饰",15)
		var unlocked=game.accessory_unlocked(a)
		var condition="Lv.%d" % a[3] if a[4]=="" else "三好学生成就" if a[4]=="all60" else "职场达人成就"
		var text_=a[1]+("  ✓" if game.data[a[2]]==a[0] and not game.data.gold else "" if unlocked else "  ·  "+condition)
		var b=button(text_,func():game.equip(a);set_profile_tab("dress"))
		b.disabled=not unlocked
		panel_body.add_child(b)
	divider()
	row_text("套装",15)
	var suit_button=button("高雅人士"+(" · Lv.20" if game.data.level<20 else "  ✓" if game.data.gold else ""),func():game.set_suit(not game.data.gold);set_profile_tab("dress"))
	suit_button.tooltip_text="再次点击脱下" if game.data.gold else "与头饰、颈饰互斥"
	suit_button.disabled=game.data.level<20
	panel_body.add_child(suit_button)
	if game.data.gold: row_text("再次点击脱下，或选择头饰、颈饰切换。",13,Color("8a8b78"))

func settings_panel():
	set_settings_tab(settings_tab)

func set_settings_tab(tab: String):
	clear_body()
	settings_tab=tab
	panel_scroll.scroll_vertical=0
	panel_error.text=""
	for key in settings_buttons:settings_buttons[key].set_pressed_no_signal(key==tab)
	if tab=="general":general_panel()
	else:about_panel()
	if portrait:PortraitLayout.prepare_scroll_body(panel_body)

func setting_row(title: String) -> HBoxContainer:
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	panel_body.add_child(row)
	var text_=label(title,16)
	text_.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(text_)
	return row

func window_settings():
	var row=setting_row("窗口大小")
	var sizes=OptionButton.new()
	sizes.name="WindowSize"
	sizes.custom_minimum_size=Vector2(225,42)
	sizes.add_item("默认窗口",0)
	var usable=DisplayServer.screen_get_usable_rect().size
	for width in [1280,1600,1920]:
		if width<=usable.x-48 and width*9/16<=usable.y-48:sizes.add_item("%d × %d" % [width,width*9/16],width)
	for i in sizes.item_count:
		if sizes.get_item_id(i)==preferences.window_width:sizes.select(i)
	sizes.item_selected.connect(func(index):
		preferences.window_width=sizes.get_item_id(index)
		apply_window_size()
		save_preferences()
	)
	row.add_child(sizes)
	row.add_child(button("恢复默认窗口",func():
		preferences.window_width=0
		apply_window_size()
		save_preferences()
		set_settings_tab("general")
	))

func general_panel():
	if not portrait:window_settings()
	var row=setting_row("帧率上限")
	var fps=OptionButton.new()
	fps.name="FrameLimit"
	fps.custom_minimum_size=Vector2(120,44) if portrait else Vector2(225,42)
	fps.add_item("30 FPS",30)
	fps.add_item("60 FPS",60)
	fps.select(0 if preferences.fps==30 else 1)
	fps.item_selected.connect(func(index):
		preferences.fps=fps.get_item_id(index)
		apply_frame_limit()
		save_preferences()
	)
	row.add_child(fps)
	row=setting_row("后台省电")
	var saving=CheckButton.new()
	saving.name="BackgroundSaving"
	saving.custom_minimum_size=Vector2(120,44) if portrait else Vector2(225,42)
	saving.text="开启" if preferences.background_saving else "关闭"
	saving.set_pressed_no_signal(preferences.background_saving)
	saving.toggled.connect(func(enabled):
		saving.text="开启" if enabled else "关闭"
		preferences.background_saving=enabled
		apply_frame_limit()
		save_preferences()
	)
	row.add_child(saving)
	row_text("切到后台时降低帧率，任务照常进行。",13,Color("8a8b78"))
	divider()
	if not portrait:panel_body.add_child(button("打开存档文件夹",func():OS.shell_open(ProjectSettings.globalize_path(game.path).get_base_dir())))
	row_text("自动保存 · 退出后任务继续",13,Color("8a8b78"))

func source_link(title: String, url: String):
	if portrait:
		var wrapped=RichTextLabel.new()
		wrapped.bbcode_enabled=true
		wrapped.fit_content=true
		wrapped.scroll_active=false
		wrapped.text="[url="+url+"]"+title+"[/url]"
		wrapped.add_theme_font_size_override("normal_font_size",16)
		wrapped.add_theme_color_override("default_color",Color("607d69"))
		wrapped.meta_clicked.connect(func(meta):OS.shell_open(str(meta)))
		panel_body.add_child(wrapped)
		return
	var link=LinkButton.new()
	link.text=title
	link.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	link.add_theme_color_override("font_color",Color("607d69"))
	link.add_theme_color_override("font_hover_color",Color("40514b"))
	link.add_theme_color_override("font_pressed_color",Color("40514b"))
	link.add_theme_font_size_override("font_size",14)
	link.tooltip_text=url
	link.pressed.connect(func():OS.shell_open(url))
	panel_body.add_child(link)

func about_panel():
	row_text("养一只咕咕嘎嘎吧！",21)
	row_text("版本 "+str(ProjectSettings.get_setting("application/config/version")),13,Color("8a8b78"))
	row_text("陪小嘎嘎吃饭、洗澡、学习和打工，慢慢长大。",14)
	divider()
	row_text("游玩方法",16)
	var guide="点击头、肚子、翅膀或脚，按住头部轻轻移动来抚摸。\n拖动地面旋转，停下 10 秒后回正。\n点击名字查看资料、成就和装扮，动作可在左侧预览。\n喂食、洗澡可连续使用物品，点外面收起。\n学习和打工同时只能进行一项，退出后任务继续。\nEsc 关闭菜单或弹窗，游戏自动保存。"
	row_text(guide.replace("左侧","上方").replace("Esc","返回键") if portrait else guide,14)
	divider()
	row_text("玩法与素材",16)
	row_text("养成玩法参考 QQ 宠物。",14)
	source_link("企鹅高松灯 · -爱啃梨（组合模型下载）","https://www.bilibili.com/video/BV15WD9BPEPR/")
	source_link("高松灯头部 · BanG Dream! / Bushiroad Games","https://www.deviantart.com/bunglescrungle/art/BanG-Dream-MyGO-FBX-and-PMX-DL-1036304336")
	row_text("以下 CC BY 4.0 仅适用于企鹅身体。",12,Color("8a8b78"))
	source_link("企鹅身体 · Private (Madagascar) / Guilherme Navarro","https://sketchfab.com/3d-models/private-madagascar-a288037027374e089d4744b3ad25ad24")
	source_link("身体素材许可 · CC BY 4.0","https://creativecommons.org/licenses/by/4.0/")
	row_text("本项目调整了模型导出、贴图、表情与翼根，增加程序动作。\n配饰、动作道具、背景和图标由本项目制作。",13)
	source_link("备用企鹅 · Penguin (Rig-CntRig-Anim) / nicoma · CC BY 4.0","https://sketchfab.com/3d-models/penguin-rig-cntrig-anim-db8a037d135b41b08752ce4c57f43525")
	source_link("Godot Engine · MIT License","https://godotengine.org/license/")
	divider()
	source_link("项目仓库 · TTZW1001 / GuguGaga","https://github.com/TTZW1001/GuguGaga")

func request_end():
	game.advance(now())
	if game.data.task.is_empty():return
	open_panel("end")
	var t=game.data.task
	var cfg=C.task(t.kind,t.id)
	var ratio=t.elapsed/cfg.duration
	row_text("已完成 %.1f%%" % (ratio*100),20)
	row_text("经验 +%.2f" % (cfg.xp*ratio),16)
	row_text("%s +%.2f · 退还学费 %.2f" % [C.ATTR_NAMES[cfg.attr],cfg.gain*ratio,t.escrow*(1-ratio)] if t.kind=="study" else "工资 +%.2f 金币" % (cfg.money*ratio),16)
	divider()
	panel_body.add_child(button("确认结束",func():game.end_task(now());close_panel(),true))
	panel_body.add_child(button("继续任务",close_panel))
	if portrait:PortraitLayout.prepare_scroll_body(panel_body)

func hit_part(pos: Vector2) -> String:
	var origin = camera.project_ray_origin(pos)
	var direction = camera.project_ray_normal(pos)
	var query = PhysicsRayQueryParameters3D.create(origin,origin+direction*30)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result = camera.get_world_3d().direct_space_state.intersect_ray(query)
	return result.collider.get_meta("part","") if not result.is_empty() else ""

func stage_point(pos: Vector2) -> Vector2:
	return pos/stage.size*Vector2(viewport.size)

func is_ground(pos: Vector2) -> bool:
	var point=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(pos),camera.project_ray_normal(pos))
	if point==null:return false
	return pow(point.x/2.0,2)+pow((point.z-0.15)/1.45,2)<=1.0

func stage_input(event: InputEvent):
	if not is_instance_valid(camera) or not game.data.adopted:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed_part=hit_part(stage_point(event.position))
			pressing=not pressed_part.is_empty()
			rotating=not pressing and is_ground(stage_point(event.position))
			if rotating:
				if is_instance_valid(return_tween):return_tween.kill()
				rotate_idle=0
			press_pos=event.position
			motion_distance=0
			press_time=Time.get_ticks_msec()/1000.0
			stroked=false
		elif pressing:
			pressing=false
			if not stroked and motion_distance<16:
				game.interact(false,now(),Time.get_datetime_dict_from_system().hour)
				if game.clicks.size()>=6:
					pet.perform("angry",1.8)
					show_message("慢一点啦！",2)
				else:
					pet.perform(pressed_part,1.8)
					show_message({"head":"嗯？","belly":"痒痒！","wing_l":"抬抬左手~","wing_r":"抬抬右手~","feet":"跳跳！"}.get(pressed_part,""),2)
	if event is InputEventMouseMotion:
		if rotating:
			pet.view_yaw=wrapf(pet.view_yaw+event.relative.x*0.012,-PI,PI)
			rotate_idle=0
		elif pressing:
			motion_distance+=event.relative.length()
			if pressed_part=="head" and not stroked and motion_distance>=18 and Time.get_ticks_msec()/1000.0-press_time>=0.3 and event.position.distance_to(press_pos)<120 and hit_part(stage_point(event.position))=="head":
				stroked=true
				var rewarded=game.interact(true,now(),Time.get_datetime_dict_from_system().hour)
				pet.perform("pet",2.2)
				show_message(("啦啦啦啦♪" if rewarded else "好舒服~") if "pet" in game.data.achievements else ("嗯哼哼♪" if rewarded else "舒服~"),3)
		else:hint.text="拖动地面旋转" if is_ground(stage_point(event.position)) and hit_part(stage_point(event.position)).is_empty() else ""

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		close_panel()
		close_menu()
		pressing=false
		rotating=false
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if not event.pressed:
			rotating=false
			preview_dragging=false
			var logical=ui.get_global_transform_with_canvas().affine_inverse()*event.position
			if not stage.get_global_rect().has_point(logical):pressing=false
		elif event.button_index==MOUSE_BUTTON_LEFT and item_menu.visible:
			var logical=ui.get_global_transform_with_canvas().affine_inverse()*event.position
			var outside_trigger=not toolbar.get_global_rect().has_point(logical) if portrait else logical.x<ui.size.x-120
			if not item_menu.get_global_rect().has_point(logical) and outside_trigger:
				close_menu()
				get_viewport().set_input_as_handled()

func _process(delta: float):
	if OS.has_feature("android") and (application_paused or not window_focused):return
	if portrait and is_instance_valid(panel_error):
		panel_error.visible=not panel_error.text.is_empty()
		menu_error.visible=not menu_error.text.is_empty()
	if is_instance_valid(panel_scroll) and modal.visible:
		var bar=panel_scroll.get_v_scroll_bar()
		scroll_fade.visible=bar.max_value>bar.page and bar.value+bar.page<bar.max_value-1
	tick+=delta
	save_tick+=delta
	if tick>=0.5:
		tick=0
		game.advance(now())
	if save_tick>=15:
		save_tick=0
		game.save()
	if is_instance_valid(pet) and not rotating and absf(pet.view_yaw)>0.001:
		rotate_idle+=delta
		if rotate_idle>=10 and (not is_instance_valid(return_tween) or not return_tween.is_running()):
			return_tween=create_tween()
			return_tween.tween_property(pet,"view_yaw",0.0,2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if toast_time>0:
		toast_time-=delta
		if toast_time<=0 and is_instance_valid(toast):toast.text=""

func _notification(what: int):
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(modal) and modal.visible:close_panel()
		elif is_instance_valid(item_menu) and item_menu.visible:close_menu()
		else:_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_profile_name()
		game.advance(now())
		if game.data.adopted and not game.save() and game.save_error:
			show_message("保存失败，暂未退出。",15)
			return
		get_tree().quit()
	if what==NOTIFICATION_APPLICATION_FOCUS_IN:
		window_focused=true
		apply_frame_limit()
		if not application_paused:resume_game()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		window_focused=false
		apply_frame_limit()
		suspend_game()
	if what==NOTIFICATION_APPLICATION_PAUSED:
		application_paused=true
		apply_frame_limit()
		suspend_game()
	if what==NOTIFICATION_APPLICATION_RESUMED:
		application_paused=false
		apply_frame_limit()
		if window_focused:resume_game()
