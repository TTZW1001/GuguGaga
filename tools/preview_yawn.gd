extends "res://tools/preview_look.gd"
# Reuse the same cameras and lighting as the approved glance preview.
const YAWN_OUT = "res://build/动作预览/A04-伸懒腰/"

func capture_yawn(character: Script, version: String, clothes: bool):
	actors.clear()
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
		var texture = TextureRect.new()
		texture.texture = view.get_texture()
		texture.position = Vector2((i%3)*size.x,(i/3)*(size.y+30)+30)
		texture.size = size
		canvas.add_child(texture)
		var label = Label.new()
		label.text = entry[3]
		label.position = Vector2((i%3)*size.x+8,(i/3)*(size.y+30)+3)
		canvas.add_child(label)
	var folder = YAWN_OUT+version+("/clothes/" if clothes else "/bare/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*8:
		for pet in actors:
			if frame == FPS: pet.perform("yawn",2.6)
			pet._process(1.0/FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(folder+"%04d.png"%frame)
		if frame%60 == 0: print("YAWN_CAPTURE ",version," ","clothes" if clothes else "bare"," ",frame,"/240")
	for pet in actors:
		assert(pet.action.is_empty(),"stretch finishes and returns to idle")
	canvas.queue_free()
	await process_frame

func verify_yawn(character: Script):
	var pet = character.new()
	root.add_child(pet)
	pet.set_process(false)
	pet.idle_left = 10000
	pet.update_task("study","read")
	pet.view_yaw = 0.4
	pet._process(0)
	var feet: Array[Vector3] = []
	for bone in ["leftfoot","rightfoot"]:
		feet.append(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(bone)).origin)
	pet.perform("yawn",2.6)
	assert(is_equal_approx(pet.action_total,4.6),"stretch has time to rise, hold and settle")
	for frame in FPS*6:
		pet._process(1.0/FPS)
		assert(pet.task_kind == "study" and pet.task_id == "read","stretch retains task")
		assert(is_equal_approx(pet.view_yaw,0.4) and pet.torso.scale == Vector3.ONE,"view rotation and body scale stay intact")
		for i in 2:
			var bone = "leftfoot" if i == 0 else "rightfoot"
			assert(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(bone)).origin.distance_to(feet[i])<0.0001,"feet stay planted")
	assert(pet.action.is_empty() and pet.book.visible,"original task is visible after stretch")
	pet.free()
	# Compare the approved A03 against the pre-stretch snapshot at every frame.
	var old = load(YAWN_OUT+"v0/character.gd").new()
	var current = character.new()
	for actor in [old,current]:
		root.add_child(actor)
		actor.set_process(false)
		actor.rng.seed = 301
		actor.idle_left = 10000
		actor.perform("look",2.6)
	for frame in FPS*6:
		for actor in [old,current]: actor._process(1.0/FPS)
		for i in current.skeleton.get_bone_count():
			assert(current.skeleton.get_bone_pose_rotation(i).is_equal_approx(old.skeleton.get_bone_pose_rotation(i)),"A03 bone rotations are unchanged")
			assert(current.skeleton.get_bone_pose_position(i).is_equal_approx(old.skeleton.get_bone_pose_position(i)),"A03 bone positions are unchanged")
		assert(current.expression_weights == old.expression_weights,"A03 expressions are unchanged")
	old.free()
	current.free()
	print("YAWN_VERIFY_OK: planted feet, fixed scale, view rotation, task return, approved A03 unchanged")

func run():
	Engine.max_fps = 60
	root.size = Vector2i(100,100)
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	var version = "v1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = arg.trim_prefix("--version=")
	assert(version.is_valid_filename() and version not in [".",".."],"version must be a directory name")
	var character = load(YAWN_OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline: verify_yawn(character)
	if "--verify-only" not in OS.get_cmdline_user_args():
		await capture_yawn(character,"v0" if baseline else version,false)
		if not baseline: await capture_yawn(character,version,true)
	print("YAWN_PREVIEW_COMPLETE")
	quit()
