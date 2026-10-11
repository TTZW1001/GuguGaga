extends "res://tools/preview_look.gd"
const ANGRY_OUT = "res://build/动作预览/B07-生气/"

func capture_angry(character: Script, version: String, mode: String):
	actors.clear()
	var clothes = mode == "clothes"
	var size = Vector2i(360,450) if clothes else Vector2i(480,600)
	var canvas = SubViewport.new()
	canvas.size = Vector2i(size.x*3,(size.y+30)*(2 if clothes else 1))
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var entries = [[0.0,false,"bare","FRONT"],[PI/2,false,"bare","SIDE"],[0.0,true,"bare","FACE"]]
	if mode == "rear":
		entries = [[PI,false,"bare","BACK"],[PI*0.75,false,"bare","BACK 3/4"],[PI*0.75,false,"suit","SUIT / BACK 3/4"]]
	if clothes:
		entries.clear()
		for angle in [0.0,PI/2]:
			for outfit in ["scarf","hood","suit"]:
				entries.append([angle,false,outfit,outfit.to_upper()+(" / FRONT" if angle == 0 else " / SIDE")])
	for i in entries.size():
		var entry = entries[i]
		var view = make_view(canvas,character,entry[0],entry[1],entry[2],size)
		if mode == "task": actors[-1].update_task("study","read")
		if mode == "work": actors[-1].update_task("work","flyer")
		var texture = TextureRect.new()
		texture.texture = view.get_texture()
		texture.position = Vector2((i%3)*size.x,(i/3)*(size.y+30)+30)
		texture.size = size
		canvas.add_child(texture)
		var label = Label.new()
		label.text = entry[3]+(" / STUDY" if mode == "task" else (" / WORK" if mode == "work" else ""))
		label.position = Vector2((i%3)*size.x+8,(i/3)*(size.y+30)+3)
		canvas.add_child(label)
	var folder = ANGRY_OUT+version+"/"+mode+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*8:
		for pet in actors:
			if frame == FPS: pet.perform("angry",1.8)
			if mode == "spam" and frame > FPS and frame < FPS*4 and (frame-FPS)%6 == 0: pet.perform("angry",1.8)
			pet._process(1.0/FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(folder+"%04d.png"%frame)
		if frame%60 == 0: print("ANGRY_CAPTURE ",version," ",mode," ",frame,"/240")
	for pet in actors:
		assert(pet.action.is_empty(),"angry feedback finishes")
		if mode == "task": assert(pet.task_kind == "study" and pet.task_id == "read" and pet.book.visible,"original study pose returns")
		if mode == "work": assert(pet.task_kind == "work" and pet.task_id == "flyer" and pet.props.visible,"original work pose returns")
	canvas.queue_free()
	await process_frame

func verify_angry(character: Script):
	var baseline = load(ANGRY_OUT+"v0/character.gd")
	# User-frozen A actions and retained B actions must match the snapshot exactly.
	for action_name in ["","head","look","yawn","hop","pet","wing_l","wing_r","feet","feed","wash","belly","spin","dance","celebrate"]:
		var old = baseline.new()
		var current = character.new()
		for actor in [old,current]:
			root.add_child(actor)
			actor.set_process(false)
			actor.rng.seed = 301
			actor.idle_left = 10000
			actor.blink_wait = 2.8
			if not action_name.is_empty(): actor.perform(action_name,2.6)
		for frame in FPS*8:
			for actor in [old,current]: actor._process(1.0/FPS)
			for i in current.skeleton.get_bone_count():
				assert(current.skeleton.get_bone_pose_rotation(i).is_equal_approx(old.skeleton.get_bone_pose_rotation(i)),"retained bone rotations: "+action_name)
				assert(current.skeleton.get_bone_pose_position(i).is_equal_approx(old.skeleton.get_bone_pose_position(i)),"retained bone positions: "+action_name)
			assert(current.expression_weights == old.expression_weights,"retained expressions: "+action_name)
			assert(current.torso.transform.is_equal_approx(old.torso.transform),"retained torso: "+action_name)
		old.free()
		current.free()
	for task in [["",""],["study","read"],["work","flyer"],["study","sport"],["work","code"],["work","carry"]]:
		var pet = character.new()
		var reference = baseline.new()
		for actor in [pet,reference]:
			root.add_child(actor)
			actor.set_process(false)
			actor.idle_left = 10000
			actor.rng.seed = 301
			actor.blink_wait = 20
			actor.view_yaw = 0.4
			actor.update_task(task[0],task[1])
			actor._process(0)
		var feet: Array[Transform3D] = []
		for bone in ["leftfoot","rightfoot"]: feet.append(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(bone)))
		pet.perform("angry",1.8)
		reference.perform("angry",4.8)
		assert(is_equal_approx(pet.action_total,4.8),"anger has time for hops, stance, head shake and return")
		var airborne = false
		var hops = 0
		var head_signs = {}
		for frame in FPS*8:
			for actor in [pet,reference]: actor._process(1.0/FPS)
			if frame%6 == 0 and frame < FPS*3:
				var remaining = pet.action_left
				pet.perform("angry",1.8)
				assert(is_equal_approx(pet.action_left,remaining),"repeated clicks do not rewind anger")
			assert(pet.task_kind == task[0] and pet.task_id == task[1] and is_equal_approx(pet.view_yaw,0.4),"anger retains task and view rotation")
			var height = pet.torso.position.y-sin(pet.time*2)*0.009
			if pet.action_total-pet.action_left < 0.22 or pet.action_total-pet.action_left > 1.82: height = 0.0
			if height > 0.001 and not airborne: hops += 1
			airborne = height > 0.001
			if not airborne:
				for i in 2:
					var bone = "leftfoot" if i == 0 else "rightfoot"
					assert(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(bone)).is_equal_approx(feet[i]),"feet return to their planted pose after every hop")
			if pet.action_left > 0.9 and pet.action_left < 2.4:
				var head_rotation = pet.skeleton.get_bone_pose_rotation(pet.skeleton.find_bone("head_x"))
				if absf(head_rotation.y)>0.02: head_signs[signf(head_rotation.y)] = true
				for side in ["l","r"]:
					var idx = pet.skeleton.find_bone("forearm_stretch_"+side)
					assert(pet.skeleton.get_bone_pose_rotation(idx).angle_to(pet.skeleton.get_bone_rest(idx).basis.get_rotation_quaternion())>0.8,"both wing tips fold toward the waist")
			if pet.action.is_empty():
				for i in pet.skeleton.get_bone_count():
					assert(pet.skeleton.get_bone_pose(i).is_equal_approx(reference.skeleton.get_bone_pose(i)),"body returns to its original idle or task pose")
		assert(hops == 3,"exactly three hops")
		assert(head_signs.has(-1.0) and head_signs.has(1.0),"head shakes both ways after the hops")
		assert(pet.action.is_empty() and pet.book.scale.is_equal_approx(Vector3.ONE) and pet.props.scale.is_equal_approx(Vector3.ONE),"anger completes and restores task props")
		pet.free()
		reference.free()
	print("ANGRY_VERIFY_OK: frozen actions unchanged including B03; three hops; planted landings; folded wing tips; head shakes both ways; idle/study/work return; view rotation retained")

func run():
	Engine.max_fps = 60
	root.size = Vector2i(100,100)
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	var version = "v1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = arg.trim_prefix("--version=")
	assert(version.is_valid_filename() and version not in [".",".."],"version must be a directory name")
	var character = load(ANGRY_OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline: verify_angry(character)
	if "--verify-only" not in OS.get_cmdline_user_args():
		if "--spam-only" in OS.get_cmdline_user_args():
			await capture_angry(character,version,"spam")
			print("ANGRY_SPAM_PREVIEW_COMPLETE")
			quit()
			return
		if "--extras-only" not in OS.get_cmdline_user_args(): await capture_angry(character,"v0" if baseline else version,"bare")
		if not baseline and "--bare-only" not in OS.get_cmdline_user_args():
			await capture_angry(character,version,"clothes")
			await capture_angry(character,version,"task")
			await capture_angry(character,version,"work")
			await capture_angry(character,version,"rear")
	print("ANGRY_PREVIEW_COMPLETE")
	quit()
