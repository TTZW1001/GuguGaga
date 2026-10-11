extends "res://tools/preview_look.gd"
const SPIN_OUT = "res://build/动作预览/D01-转圈/"

func capture_spin(character: Script, version: String, mode: String):
	actors.clear()
	var clothes = mode == "clothes"
	var size = Vector2i(360,450) if clothes else Vector2i(480,600)
	var canvas = SubViewport.new()
	canvas.size = Vector2i(size.x*3,(size.y+30)*(2 if clothes else 1))
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var entries = [[0.0,false,"bare","FRONT"],[PI/2,false,"bare","SIDE"],[0.0,true,"bare","FACE"]]
	if mode == "rear": entries = [[PI,false,"bare","BACK"],[PI*0.75,false,"bare","BACK 3/4"],[PI*0.75,false,"suit","SUIT / BACK 3/4"]]
	if clothes:
		entries.clear()
		for angle in [0.0,PI/2]:
			for outfit in ["scarf","hood","suit"]:
				entries.append([angle,false,outfit,outfit.to_upper()+(" / FRONT" if angle == 0 else " / SIDE")])
	for i in entries.size():
		var entry = entries[i]
		var view = make_view(canvas,character,entry[0],entry[1],entry[2],size)
		if mode == "study": actors[-1].update_task("study","read")
		if mode == "work": actors[-1].update_task("work","flyer")
		var texture = TextureRect.new()
		texture.texture = view.get_texture()
		texture.position = Vector2((i%3)*size.x,(i/3)*(size.y+30)+30)
		texture.size = size
		canvas.add_child(texture)
		var label = Label.new()
		label.text = entry[3]+(" / "+mode.to_upper() if mode in ["study","work"] else "")
		label.position = Vector2((i%3)*size.x+8,(i/3)*(size.y+30)+3)
		canvas.add_child(label)
	var folder = SPIN_OUT+version+"/"+mode+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*8:
		for pet in actors:
			if frame == FPS: pet.perform("spin",2.8)
			pet._process(1.0/FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(folder+"%04d.png"%frame)
		if frame%60 == 0: print("SPIN_CAPTURE ",version," ",mode," ",frame,"/240")
	for pet in actors: assert(pet.action.is_empty(),"spin finishes and returns")
	canvas.queue_free()
	await process_frame

func verify_spin(character: Script):
	var baseline = load(SPIN_OUT+"v0/character.gd")
	for task in [["",""],["study","read"],["work","flyer"]]:
		for name_ in (["","head","look","yawn","hop","pet","belly","wing_l","wing_r","feet","feed","wash","angry","dance","celebrate"] if task[0].is_empty() else ["feed","wash"]):
			var old = baseline.new()
			var current = character.new()
			for pet in [old,current]:
				root.add_child(pet)
				pet.set_process(false)
				pet.rng.seed = 301
				pet.idle_left = 10000
				pet.blink_wait = 2.8
				pet.update_task(task[0],task[1])
				if not name_.is_empty(): pet.perform(name_,2.8)
			for frame in FPS*8:
				for pet in [old,current]: pet._process(1.0/FPS)
				for i in current.skeleton.get_bone_count():
					assert(current.skeleton.get_bone_pose(i).is_equal_approx(old.skeleton.get_bone_pose(i)),"frozen skeleton: "+name_)
				assert(current.expression_weights == old.expression_weights,"frozen expressions: "+name_)
				assert(current.torso.transform.is_equal_approx(old.torso.transform),"frozen torso: "+name_)
				assert(current.book.scale.is_equal_approx(old.book.scale) and current.props.scale.is_equal_approx(old.props.scale),"C task transition unchanged")
				if name_ == "feed": assert(current.food_root.transform.is_equal_approx(old.food_root.transform) and current.food_root.visible == old.food_root.visible,"C01 food grip unchanged")
				for i in current.bubbles.size(): assert(current.bubbles[i].visible == old.bubbles[i].visible and current.bubbles[i].transform.is_equal_approx(old.bubbles[i].transform),"C02 wash unchanged")
			old.free()
			current.free()
		var pet = character.new()
		var reference = baseline.new()
		for actor in [pet,reference]:
			root.add_child(actor)
			actor.set_process(false)
			actor.rng.seed = 301
			actor.idle_left = 10000
			actor.blink_wait = 20
			actor.view_yaw = 0.4
			actor.update_task(task[0],task[1])
			actor._process(0)
		pet.perform("spin",2.8)
		var previous_feet: Array[Transform3D] = []
		var previous_step = -1
		var raised_steps = {}
		var foot_heights: Array[float] = []
		for name_ in ["leftfoot","rightfoot"]: foot_heights.append((pet.skeleton.global_transform*pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(name_))).origin.y)
		var max_angle = 0.0
		for frame in FPS*8:
			for actor in [pet,reference]: actor._process(1.0/FPS)
			assert(pet.task_kind == task[0] and pet.task_id == task[1] and is_equal_approx(pet.view_yaw,0.4),"spin preserves task and view rotation")
			if pet.action == "spin":
				max_angle = maxf(max_angle,pet.torso.rotation.y-pet.view_yaw)
				var elapsed = pet.action_total-pet.action_left
				if elapsed>0.40 and elapsed<4.20:
					var step = mini(int((elapsed-0.38)/0.48),7)
					var feet: Array[Transform3D] = []
					for name_ in ["leftfoot","rightfoot"]: feet.append(pet.skeleton.global_transform*pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(name_)))
					var stance = 1-step%2
					if step == previous_step:
						assert(feet[stance].origin.distance_to(previous_feet[stance].origin)<0.0001,"supporting foot position stays planted: "+str(feet[stance].origin-previous_feet[stance].origin))
						assert(feet[stance].basis.is_equal_approx(previous_feet[stance].basis),"supporting sole does not rotate on the floor")
					if feet[step%2].origin.y-foot_heights[step%2]>0.035: raised_steps[step] = true
					previous_feet = feet
					previous_step = step
			else:
				assert(pet.torso.transform.is_equal_approx(reference.torso.transform),"returns to original facing and breathing")
				for i in pet.skeleton.get_bone_count(): assert(pet.skeleton.get_bone_pose(i).is_equal_approx(reference.skeleton.get_bone_pose(i)),"returns to original idle/task bones")
		assert(raised_steps.size() == 8 and max_angle>TAU-0.001,"eight alternating lifted steps complete one full turn")
		assert(pet.book.scale.is_equal_approx(Vector3.ONE) and pet.props.scale.is_equal_approx(Vector3.ONE),"original task props return")
		pet.free()
		reference.free()
	print("SPIN_VERIFY_OK: frozen A/B/C and D02/D03 unchanged; eight alternating lifted steps; stationary support foot; full turn; task/props/facing return; view rotation retained")

func run():
	Engine.max_fps = 60
	root.size = Vector2i(100,100)
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	var version = "v1"
	var mode = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = arg.trim_prefix("--version=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	assert(version.is_valid_filename() and version not in [".",".."])
	var character = load(SPIN_OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline: verify_spin(character)
	if "--verify-only" not in OS.get_cmdline_user_args():
		for selected in (["bare"] if baseline else ["bare","clothes","study","work","rear"]):
			if selected == "bare" and "--extras-only" in OS.get_cmdline_user_args(): continue
			if mode.is_empty() or mode == selected: await capture_spin(character,"v0" if baseline else version,selected)
	print("SPIN_PREVIEW_COMPLETE")
	quit()
