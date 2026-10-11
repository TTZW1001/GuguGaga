extends RefCounted
## Platform choices live here; pet state, rewards and animation stay shared.

static func portrait() -> bool:
	return OS.has_feature("android") or "--portrait-preview" in OS.get_cmdline_user_args()

static func configure_window(window: Window):
	if not portrait():return
	window.content_scale_size=Vector2i(432,864)
	window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	if OS.has_feature("android"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	else:
		window.min_size=Vector2i(360,640)
		window.size=Vector2i(432,864)

static func safe_insets(window: Window) -> Vector4:
	if not OS.has_feature("android"):return Vector4.ZERO
	var safe=DisplayServer.get_display_safe_area()
	var screen=DisplayServer.screen_get_size()
	if safe.size.x<=0 or safe.size.y<=0:return Vector4.ZERO
	var scale=window.get_visible_rect().size/Vector2(window.size)
	return Vector4(safe.position.x*scale.x,safe.position.y*scale.y,
		maxi(0,screen.x-safe.end.x)*scale.x,maxi(0,screen.y-safe.end.y)*scale.y)
