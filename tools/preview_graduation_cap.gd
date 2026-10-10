extends SceneTree
# Render the actual game character and exercise both approved headwear slots.
const PET = preload("res://scripts/tomori_penguin.gd")
const OUTPUT = "res://build/装扮预览/学士帽-v3/"
var failed = false

func _initialize(): call_deferred("run")

func check(ok: bool, message: String):
	print(("CAP OK: " if ok else "CAP FAIL: ")+message)
	if not ok: failed = true

func make_view(angle: float, close: bool, pose: String = "") -> SubViewport:
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
	pet.update_accessories("graduate","none",false)
	pet._process(0)
	check(pet.graduation_cap.get_child_count() == 1,"single combined cap mesh")
	var mesh = pet.graduation_cap.get_child(0) as MeshInstance3D
	check(mesh.mesh.get_surface_count() == 3,"three shared material surfaces")
	check(mesh.get_node(mesh.skeleton) == pet.skeleton,"cap uses the game character skeleton")
	for i in mesh.skin.get_bind_count():
		check(pet.skeleton.find_bone(mesh.skin.get_bind_name(i)) >= 0,"valid bone "+str(mesh.skin.get_bind_name(i)))
	# The cap has a rigid head binding: verify its actual skin transform responds
	# to a head interaction, independently of body movement and display rotation.
	var head_index = pet.skeleton.find_bone("head_x")
	var idle_head = pet.skeleton.get_bone_global_pose(head_index)
	pet.perform("head",1.8)
	pet.action_left = 0.9
	pet._process(0)
	check(not idle_head.basis.is_equal_approx(pet.skeleton.get_bone_global_pose(head_index).basis),"head pose moves the bound cap")
	pet.action = ""
	pet.action_left = 0
	pet.update_accessories("redhat","none",false)
	check(pet.red_hood.visible and not pet.graduation_cap.visible,"switching to approved hood hides cap")
	pet.update_accessories("none","none",false)
	check(not pet.red_hood.visible and not pet.graduation_cap.visible,"unequip hides both headwear assets")
	pet.update_accessories("graduate","bow",false)
	check(pet.graduation_cap.visible and not pet.red_hood.visible and pet.red_bow.visible,"cap supports independent neck slot")
	pet.update_accessories("graduate","none",false)
	pet.update_accessories("graduate","none",false)
	check(pet.graduation_cap.get_child_count() == 1,"repeat refresh reuses the existing cap")
	if not pose.is_empty():
		pet.perform(pose,1.8)
		pet.action_left = 0.9
	pet._process(0)
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.80 if close else 2.95
	cam.position = Vector3(0,2.20 if close else 1.65,6)
	view.add_child(cam)
	cam.look_at(Vector3(0,2.00 if close else 1.28,0))
	cam.current = true
	return view

func run():
	Engine.max_fps = 30
	root.size = Vector2i(800,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for settings in [["01-正面",0.0,false,""],["02-侧面",PI/2,false,""],["03-近景",0.0,true,""],["04-歪头",0.0,true,"head"],["05-挥翅",0.55,false,"wing_l"],["06-后侧贴合",PI-0.45,true,""],["07-外侧流苏",-0.55,true,""]]:
		var view = make_view(settings[1],settings[2],settings[3])
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(OUTPUT+settings[0]+".png")
		print("CAPTURED ",settings[0])
		view.queue_free()
		await process_frame
	print("CAP_PREVIEW_COMPLETE")
	await process_frame
	await process_frame
	quit(1 if failed else 0)
