extends SceneTree
# Actual game model, compatibility renderer, real accessory switching.
const PET = preload("res://scripts/tomori_penguin.gd")
const OUTPUT = "res://build/装扮预览/小围巾-v3/"
var failed = false

func _initialize(): call_deferred("run")

func check(ok: bool, message: String):
	print(("SCARF OK: " if ok else "SCARF FAIL: ")+message)
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
	pet.update_accessories("none","scarf",false)
	pet._process(0)
	check(pet.red_scarf.get_child_count() == 1,"single combined scarf mesh")
	var mesh = pet.red_scarf.get_child(0) as MeshInstance3D
	check(mesh.mesh.get_surface_count() == 3,"three shared cloth surfaces")
	check(mesh.get_node(mesh.skeleton) == pet.skeleton,"scarf uses live character skeleton")
	var valid_binds = true
	for i in mesh.skin.get_bind_count():
		valid_binds = valid_binds and pet.skeleton.find_bone(mesh.skin.get_bind_name(i)) >= 0
	check(valid_binds,"all skin binds resolve")
	var chest_index = pet.skeleton.find_bone("spine_01_x")
	var idle_chest = pet.skeleton.get_bone_global_pose(chest_index)
	pet.perform("belly",1.8)
	pet.action_left = 0.9
	pet._process(0)
	check(not idle_chest.basis.is_equal_approx(pet.skeleton.get_bone_global_pose(chest_index).basis),"body interaction moves bound scarf")
	pet.action = ""
	pet.action_left = 0
	pet.update_accessories("graduate","scarf",false)
	check(pet.graduation_cap.visible and pet.red_scarf.visible,"approved cap and scarf use independent slots")
	pet.update_accessories("crown","scarf",false)
	check(pet.small_crown.visible and pet.red_scarf.visible and not pet.graduation_cap.visible,"approved crown and scarf coexist")
	pet.update_accessories("redhat","scarf",false)
	check(pet.red_hood.visible and pet.red_scarf.visible and not pet.graduation_cap.visible and not pet.small_crown.visible,"approved hood and scarf coexist")
	pet.update_accessories("none","none",false)
	check(not pet.red_hood.visible and not pet.graduation_cap.visible and not pet.red_scarf.visible,"unequip hides scarf and headwear")
	pet.update_accessories("crown","bow",true)
	check(not pet.red_scarf.visible and pet.small_crown.visible and pet.red_bow.visible,"bow replaces scarf without changing crown")
	pet.update_accessories("none","scarf",false)
	pet.update_accessories("none","scarf",false)
	check(pet.red_scarf.visible and pet.red_scarf.get_child_count() == 1,"refresh reuses scarf")
	if not pose.is_empty():
		pet.perform(pose,1.8)
		pet.action_left = 0.9
	pet._process(0)
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.80 if close else 2.95
	cam.position = Vector3(0,1.56 if close else 1.65,6)
	view.add_child(cam)
	cam.look_at(Vector3(0,1.42 if close else 1.28,0))
	cam.current = true
	return view

func run():
	Engine.max_fps = 30
	root.size = Vector2i(800,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for settings in [["01-正面",0.0,false,""],["02-侧面",PI/2,false,""],["03-近景",0.15,true,""],["04-歪头",0.0,true,"head"],["05-挥翅",0.55,false,"wing_l"],["06-后侧贴合",PI-0.45,true,""]]:
		var view = make_view(settings[1],settings[2],settings[3])
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(OUTPUT+settings[0]+".png")
		print("CAPTURED ",settings[0])
		view.queue_free()
		await process_frame
	print("SCARF_PREVIEW_COMPLETE")
	await process_frame
	await process_frame
	quit(1 if failed else 0)
