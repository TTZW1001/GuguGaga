extends SceneTree
# Actual skinned game character rendered by the Compatibility renderer.
const PET = preload("res://scripts/tomori_penguin.gd")
const OUTPUT = "res://build/装扮预览/高雅人士-v3/"
var failed = false

func _initialize(): call_deferred("run")

func check(ok: bool, message: String):
	print(("ELEGANT OK: " if ok else "ELEGANT FAIL: ")+message)
	if not ok: failed = true

func make_view(angle: float, close: bool, pose: String = "", sleeve_close: bool = false) -> SubViewport:
	var view = SubViewport.new()
	view.size = Vector2i(800,1000)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("f6f0e5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff4e0")
	env.environment.ambient_light_energy = 0.6
	view.add_child(env)
	for settings in [[Vector3(-45,-35,0),Color("fff4df"),0.75],[Vector3(-20,140,0),Color("d8ecea"),0.3]]:
		var light = DirectionalLight3D.new()
		light.rotation_degrees = settings[0]
		light.light_color = settings[1]
		light.light_energy = settings[2]
		view.add_child(light)
	var pet = PET.new()
	view.add_child(pet)
	pet.set_process(false)
	pet.idle_left = 10000
	pet.view_yaw = angle
	pet.update_accessories("crown","bow",false)
	check(pet.small_crown.visible and pet.red_bow.visible,"normal accessories equip")
	pet.update_accessories("crown","bow",true)
	check(pet.elegant_suit.visible and not pet.small_crown.visible and not pet.red_bow.visible,"full suit replaces both slots")
	check(pet.elegant_suit.get_child_count()==1,"single combined suit mesh")
	var mesh = pet.elegant_suit.get_child(0) as MeshInstance3D
	check(mesh.mesh.get_surface_count()==5,"five shared material surfaces")
	check(mesh.get_node(mesh.skeleton)==pet.skeleton,"suit follows live character skeleton")
	var valid_binds = true
	for i in mesh.skin.get_bind_count():
		valid_binds = valid_binds and pet.skeleton.find_bone(mesh.skin.get_bind_name(i))>=0
	check(valid_binds,"all skin binds resolve")
	for mat in pet.body_materials: check(mat.albedo_color==Color.WHITE,"original body colors retained")
	pet.update_accessories("crown","bow",false)
	check(not pet.elegant_suit.visible and pet.small_crown.visible and pet.red_bow.visible,"disabling suit restores selected accessories")
	var cached = pet.elegant_suit
	pet.update_accessories("redhat","scarf",true)
	check(pet.elegant_suit==cached and (not is_instance_valid(pet.red_hood) or not pet.red_hood.visible) and (not is_instance_valid(pet.red_scarf) or not pet.red_scarf.visible),"hood and scarf stay hidden underneath suit")
	pet.update_accessories("graduate","tie",true)
	check(pet.elegant_suit==cached and (not is_instance_valid(pet.graduation_cap) or not pet.graduation_cap.visible) and (not is_instance_valid(pet.blue_tie) or not pet.blue_tie.visible),"cap and tie stay hidden underneath suit")
	pet.update_accessories("graduate","tie",false)
	check(pet.graduation_cap.visible and pet.blue_tie.visible and not pet.elegant_suit.visible,"normal cap and tie restored")
	pet.update_accessories("none","none",true)
	pet._process(0)
	if not pose.is_empty():
		pet.perform(pose,1.8)
		pet.action_left = 0.9
	pet._process(0)
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.75 if sleeve_close else 1.60 if close else 2.95
	cam.position = Vector3(-0.50 if sleeve_close else 0,1.35 if sleeve_close else 2.05 if close else 1.65,6)
	view.add_child(cam)
	cam.look_at(Vector3(-0.50 if sleeve_close else 0,1.27 if sleeve_close else 2.02 if close else 1.37,0))
	cam.current = true
	return view

func run():
	Engine.max_fps = 30
	root.size = Vector2i(800,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for settings in [["01-正面",0.0,false,"",false],["02-侧面",PI/2,false,"",false],["03-礼帽与墨镜近景",0.15,true,"",false],["04-三分之二侧面",0.65,false,"",false],["05-左手抬起",0.55,false,"wing_l",false],["06-背面风衣与后领",PI,false,"",false],["07-歪头",0.0,true,"head",false],["08-右手抬起",-0.55,false,"wing_r",false],["09-肥大袖子近景",0.65,true,"wing_l",true]]:
		var view = make_view(settings[1],settings[2],settings[3],settings[4])
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(OUTPUT+settings[0]+".png")
		print("CAPTURED ",settings[0])
		view.queue_free()
		await process_frame
	print("ELEGANT_PREVIEW_COMPLETE")
	await process_frame
	await process_frame
	quit(1 if failed else 0)
