extends "res://tools/preview_look.gd"
const HEAD_OUT = "res://build/动作预览/B01-点击头/"

func capture_head(character: Script, version: String, mode: String):
	actors.clear()
	var clothes = mode == "clothes"
	var size = Vector2i(360,450) if clothes else Vector2i(480,600)
	var canvas = SubViewport.new()
	canvas.size = Vector2i(size.x*3,(size.y+30)*(2 if clothes else 1))
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var entries = [[0.0,false,"bare","FRONT"],[PI/2,false,"bare","SIDE"],[0.0,true,"bare","FACE"]]
	if clothes:
		entries.clear()
		for angle in [0.0,PI/2]:
			for outfit in ["scarf","hood","suit"]:
				entries.append([angle,false,outfit,outfit.to_upper()+(" / FRONT" if angle == 0 else " / SIDE")])
	for i in entries.size():
		var entry = entries[i]
		var view = make_view(canvas,character,entry[0],entry[1],entry[2],size)
		if mode == "task": actors[-1].update_task("study","read")
		var texture = TextureRect.new()
		texture.texture = view.get_texture()
		texture.position = Vector2((i%3)*size.x,(i/3)*(size.y+30)+30)
		texture.size = size
		canvas.add_child(texture)
		var label = Label.new()
		label.text = entry[3]+(" / STUDY" if mode == "task" else "")
		label.position = Vector2((i%3)*size.x+8,(i/3)*(size.y+30)+3)
		canvas.add_child(label)
	var folder = HEAD_OUT+version+"/"+mode+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*6:
		for pet in actors:
			if frame == FPS: pet.perform("head",1.8)
			pet._process(1.0/FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(folder+"%04d.png"%frame)
		if frame%60 == 0: print("HEAD_CAPTURE ",version," ",mode," ",frame,"/180")
	for pet in actors:
		assert(pet.action.is_empty(),"head feedback finishes")
		if mode == "task": assert(pet.task_kind == "study" and pet.task_id == "read" and pet.book.visible,"original study pose returns")
	canvas.queue_free()
	await process_frame

func verify_head(character: Script):
	var baseline = load(HEAD_OUT+"v0/character.gd")
	# User-frozen A actions and retained B actions must match the snapshot exactly.
	for action_name in ["","look","yawn","hop","pet","wing_l","wing_r","feet"]:
		var old = baseline.new()
		var current = character.new()
		for actor in [old,current]:
			root.add_child(actor)
			actor.set_process(false)
			actor.rng.seed = 301
			actor.idle_left = 10000
			actor.blink_wait = 2.8
			if not action_name.is_empty(): actor.perform(action_name,2.6)
		for frame in FPS*6:
			for actor in [old,current]: actor._process(1.0/FPS)
			for i in current.skeleton.get_bone_count():
				assert(current.skeleton.get_bone_pose_rotation(i).is_equal_approx(old.skeleton.get_bone_pose_rotation(i)),"retained bone rotations: "+action_name)
				assert(current.skeleton.get_bone_pose_position(i).is_equal_approx(old.skeleton.get_bone_pose_position(i)),"retained bone positions: "+action_name)
			assert(current.expression_weights == old.expression_weights,"retained expressions: "+action_name)
			assert(current.torso.transform.is_equal_approx(old.torso.transform),"retained torso: "+action_name)
		old.free()
		current.free()
	var pet = character.new()
	root.add_child(pet)
	pet.set_process(false)
	pet.idle_left = 10000
	pet.rng.seed = 301
	var directions = {}
	for i in 32:
		pet.perform("head",1.8)
		var chosen = pet.head_tilt_direction
		directions[chosen] = true
		pet._process(0.95)
		assert(pet.head_tilt_direction == chosen,"head direction stays fixed throughout one response")
		for bone in ["head_x","spine_01_x"]:
			assert(pet.skeleton.get_bone_pose_rotation(pet.skeleton.find_bone(bone)).z*chosen<0,"head and body lean to the selected side")
	assert(directions.has(-1.0) and directions.has(1.0),"actual head trigger randomly selects both sides")
	pet.view_yaw = 0.4
	pet.update_task("study","read")
	pet._process(0)
	var feet: Array[Vector3] = []
	for bone in ["leftfoot","rightfoot"]: feet.append(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(bone)).origin)
	pet.perform("head",1.8)
	assert(is_equal_approx(pet.action_total,2.6),"head feedback has time for paired blinks and return")
	for frame in FPS*5:
		pet._process(1.0/FPS)
		assert(pet.task_kind == "study" and pet.task_id == "read" and is_equal_approx(pet.view_yaw,0.4),"head feedback retains task and view rotation")
		for i in 2:
			var bone = "leftfoot" if i == 0 else "rightfoot"
			assert(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(bone)).origin.distance_to(feet[i])<0.0001,"feet stay planted")
	assert(pet.action.is_empty() and pet.book.visible,"head feedback returns to study")
	pet.free()
	print("HEAD_VERIFY_OK: frozen poses unchanged, paired head feedback finishes, planted feet, task return, view rotation")

func run():
	Engine.max_fps = 60
	root.size = Vector2i(100,100)
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	var version = "v1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = arg.trim_prefix("--version=")
	assert(version.is_valid_filename() and version not in [".",".."],"version must be a directory name")
	var character = load(HEAD_OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline: verify_head(character)
	if "--verify-only" not in OS.get_cmdline_user_args():
		await capture_head(character,"v0" if baseline else version,"bare")
		if not baseline:
			await capture_head(character,version,"clothes")
			await capture_head(character,version,"task")
	print("HEAD_PREVIEW_COMPLETE")
	quit()
