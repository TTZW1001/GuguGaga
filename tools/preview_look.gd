extends SceneTree
# Render the live character code, with one fixed simulation step per saved frame.
# Run with --log-file inside a writable directory; -- --baseline uses the saved v0 script.
const OUT = "res://build/动作预览/A03-张望/"
const FPS = 30
var actors: Array[Node3D] = []

func _initialize(): call_deferred("run")

func make_view(parent: Node, character: Script, yaw: float, close: bool, outfit: String, size: Vector2i) -> SubViewport:
	var view = SubViewport.new()
	view.size = size
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(view)
	var world = Node3D.new()
	view.add_child(world)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("f6f0e5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff4e0")
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	for settings in [[Vector3(-45,-35,0),Color("fff4df"),0.75],[Vector3(-20,140,0),Color("d8ecea"),0.3]]:
		var light = DirectionalLight3D.new()
		light.rotation_degrees = settings[0]
		light.light_color = settings[1]
		light.light_energy = settings[2]
		world.add_child(light)
	var pet = character.new()
	world.add_child(pet)
	pet.set_process(false)
	pet.rng.seed = 301
	pet.idle_left = 10000
	pet.blink_wait = 20.0
	pet.view_yaw = yaw
	pet.update_accessories("redhat" if outfit == "hood" else "none","scarf" if outfit == "scarf" else "none",outfit == "suit")
	pet._process(0)
	pet.box(world,Vector3(0,-0.04,0),Vector3(7,0.06,6),pet.material("d6d4b5"))
	pet.orb(world,Vector3(0,0.002,0),Vector3(1.3,0.01,0.8),pet.material("a5a58d"))
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.45 if close else 3.05
	cam.position = Vector3(0,2.12 if close else 2.3,6)
	world.add_child(cam)
	cam.look_at(Vector3(0,2.04 if close else 1.35,0))
	cam.current = true
	actors.append(pet)
	return view

func capture(character: Script, version: String, clothes: bool):
	actors.clear()
	var size = Vector2i(360,450) if clothes else Vector2i(480,600)
	var canvas = SubViewport.new()
	var directions = [1.0] if version in ["v0","v1"] else [-1.0,1.0]
	canvas.size = Vector2i(size.x*3,(size.y+30)*(2 if clothes else 1)*directions.size())
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var entries = []
	for direction in directions:
		var suffix = " / LOOK LEFT" if direction < 0 else " / LOOK RIGHT"
		if clothes:
			for angle in [0.0,PI/2]:
				for outfit in ["scarf","hood","suit"]:
					entries.append([angle,false,outfit,outfit.to_upper()+(" / FRONT" if angle == 0 else " / SIDE")+suffix,direction])
		else:
			entries.append([0.0,false,"bare","FRONT"+suffix,direction])
			entries.append([PI/2,false,"bare","SIDE"+suffix,direction])
			entries.append([0.0,true,"bare","FACE"+suffix,direction])
	for i in entries.size():
		var entry = entries[i]
		var view = make_view(canvas,character,entry[0],entry[1],entry[2],size)
		actors[-1].set_meta("preview_direction",entry[4])
		var texture = TextureRect.new()
		texture.texture = view.get_texture()
		texture.position = Vector2((i%3)*size.x,(i/3)*(size.y+30)+30)
		texture.size = size
		canvas.add_child(texture)
		var label = Label.new()
		label.text = entry[3]
		label.position = Vector2((i%3)*size.x+8,(i/3)*(size.y+30)+3)
		canvas.add_child(label)
	var folder = OUT+version+("/clothes/" if clothes else "/bare/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*8:
		for pet in actors:
			if frame == FPS:
				pet.perform("look",2.6)
				# Keep the same glance direction for comparing cameras and outfits.
				if version != "v0": pet.look_direction = pet.get_meta("preview_direction")
			pet._process(1.0/FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(folder+"%04d.png"%frame)
		if frame%60 == 0: print("LOOK_CAPTURE ",version," ","clothes" if clothes else "bare"," ",frame,"/240")
	for pet in actors:
		assert(pet.action.is_empty(),"look must finish and return to idle")
		assert(pet.task_kind.is_empty() and pet.view_yaw in [0.0,PI/2],"presentation keeps task and view rotation intact")
	canvas.queue_free()
	await process_frame

func verify(character: Script):
	var pet = character.new()
	root.add_child(pet)
	pet.set_process(false)
	pet.idle_left = 10000
	var chosen_directions = {}
	pet.rng.seed = 301
	for i in 20:
		pet.perform("look",2.6)
		chosen_directions[pet.look_direction] = true
	assert(chosen_directions.has(-1.0) and chosen_directions.has(1.0),"actual trigger selects both glance directions")
	for direction in [-1.0,1.0]:
		pet.update_task("study","read")
		pet.perform("look",2.6)
		pet.look_direction = direction
		assert(is_equal_approx(pet.action_total,4.8),"glance has enough time for turn, blinks and return")
		var feet: Array[Vector3] = []
		pet._process(0)
		for bone in ["leftfoot","rightfoot"]: feet.append(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(bone)).origin)
		for frame in FPS*6:
			pet._process(1.0/FPS)
			assert(pet.task_kind == "study" and pet.task_id == "read","presentation never clears an active task")
			for i in 2:
				var bone = "leftfoot" if i == 0 else "rightfoot"
				assert(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(bone)).origin.distance_to(feet[i])<0.0001,"feet remain planted")
		assert(pet.action.is_empty() and pet.book.visible,"short action returns to original task")
	pet.free()
	print("LOOK_VERIFY_OK: both random directions, duration, planted feet, task retention, task return")

func run():
	Engine.max_fps = 60
	root.size = Vector2i(100,100)
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	var version = "v2"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = arg.trim_prefix("--version=")
	assert(version.is_valid_filename() and version not in [".",".."],"version must be a directory name")
	var character = load(OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline: verify(character)
	if "--verify-only" not in OS.get_cmdline_user_args():
		await capture(character,"v0" if baseline else version,false)
		if not baseline: await capture(character,version,true)
	print("LOOK_PREVIEW_COMPLETE")
	quit()
