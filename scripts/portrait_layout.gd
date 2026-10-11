extends RefCounted
## Only layout differs. All controls call the same handlers as Windows.

static func apply(app: Node):
	var inset=app.Platform.safe_insets(app.get_window())
	app.anchored(app.hud,0,0,1,1,Vector4(inset.x,inset.y,-inset.z,-inset.w))
	app.anchored(app.statuses,0,0,1,0,Vector4(22,18,-22,61))
	app.statuses.add_theme_constant_override("separation",18)
	app.anchored(app.info,0,0,0.5,0,Vector4(14,76,0,130))
	app.info.add_theme_font_size_override("font_size",22)
	app.anchored(app.growth,0.5,0,1,0,Vector4(12,86,-22,129))
	app.anchored(app.coins,0,0,1,0,Vector4(22,146,-22,175))
	app.coins.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	app.anchored(app.room,0,0,1,1,Vector4(0,184,0,-196))
	app.anchored(app.stage,0,0,1,1,Vector4(0,184,0,-196))
	app.anchored(app.interaction,0,0,1,1,Vector4(0,184,0,-196))
	app.attributes.hide()
	app.toolbar.vertical=false
	app.toolbar.add_theme_constant_override("separation",12)
	app.anchored(app.toolbar,0,1,1,1,Vector4(22,-180,-22,-100))
	for b in app.toolbar.get_children():
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.custom_minimum_size=Vector2(0,80)
		var icon=b.get_child(0)
		icon.position=Vector2((b.size.x-28)/2,9)
	app.anchored(app.idle_actions,0,1,1,1,Vector4(22,-82,-88,-26))
	app.idle_actions.add_theme_constant_override("separation",12)
	app.anchored(app.settings_button,1,1,1,1,Vector4(-76,-82,-22,-26))
	app.settings_button.add_theme_font_size_override("font_size",16)
	app.settings_button.tooltip_text="设置"
	app.anchored(app.task_box,0,1,1,1,Vector4(22,-86,-88,-20))
	app.task_end.custom_minimum_size.y=48
	app.hint.hide()
	app.anchored(app.toast,0,1,1,1,Vector4(22,-228,-22,-190))
	app.anchored(app.adopt_box,0,1,1,1,Vector4(14,-348,-14,-206))
	if is_instance_valid(app.camera):
		# Keep both wings and task props in view on narrow portrait screens.
		app.camera.size=maxf(3.8,3.15*app.stage.size.y/maxf(1,app.stage.size.x))
	if app.modal.visible:apply_panel(app)

static func apply_panel(app: Node):
	var inset=app.Platform.safe_insets(app.get_window())
	app.panel.custom_minimum_size=Vector2.ZERO
	app.anchored(app.panel,0,0,1,1,Vector4(14+inset.x,22+inset.y,-14-inset.z,-22-inset.w))
	app.preview_pane.custom_minimum_size=Vector2(0,clampf(app.ui.size.y*0.27,180,260))
	app.preview_pane.size_flags_vertical=Control.SIZE_FILL
	app.anchored(app.toast,0,0,1,0,Vector4(22,inset.y+2,-22,inset.y+22))
