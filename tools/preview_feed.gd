extends "res://tools/preview_look.gd"
const FEED_OUT = "res://build/动作预览/C01-喂食/"
var feed_verified = false

func capture_feed(character: Script, version: String, mode: String):
	actors.clear()
	var small = mode in ["clothes","foods"]
	var size = Vector2i(360,450) if small else Vector2i(480,600)
	var columns = 4 if mode in ["foods","idle"] else 3
	var entries = [[0.0,false,"bare","FRONT","bread",""],[PI/2,false,"bare","SIDE","bread",""],[0.0,true,"bare","FACE","bread",""]]
	if mode == "clothes":
		entries.clear()
		for angle in [0.0,PI/2]:
			for outfit in ["scarf","hood","suit"]:
				entries.append([angle,false,outfit,outfit.to_upper()+(" / FRONT" if angle == 0 else " / SIDE"),"bread",""])
	elif mode == "foods":
		entries.clear()
		for angle in [0.0,PI/2]:
			for food in ["bread","fish","steak","snack"]:
				entries.append([angle,false,"bare",food.to_upper()+(" / FRONT" if angle == 0 else " / SIDE"),food,""])
	elif mode in ["study","work"]:
		for entry in entries: entry[5] = mode
	elif mode == "rear":
		entries = [[PI,false,"bare","BACK","bread",""],[PI*0.75,false,"bare","BACK 3/4","bread",""],[PI*0.75,false,"suit","SUIT / BACK 3/4","bread",""]]
	elif mode == "idle":
		entries = [[0.0,false,"bare","OLD / FRONT","bread",""],[0.0,false,"bare","NEW / FRONT","bread",""],[PI/2,false,"bare","OLD / SIDE","bread",""],[PI/2,false,"bare","NEW / SIDE","bread",""]]
	elif mode == "wash_tasks":
		entries.clear()
		for task in ["study","work"]:
			entries.append([0.0,false,"bare","FRONT / "+task.to_upper(),"bread",task])
			entries.append([PI/2,false,"bare","SIDE / "+task.to_upper(),"bread",task])
			entries.append([0.0,true,"bare","FACE / "+task.to_upper(),"bread",task])
	var rows = ceili(float(entries.size())/columns)
	var canvas = SubViewport.new()
	canvas.size = Vector2i(size.x*columns,(size.y+30)*rows)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	for i in entries.size():
		var entry = entries[i]
		var actor_script = load(FEED_OUT+"before-v3.gd") if entry[3].begins_with("OLD / ") else character
		var view = make_view(canvas,actor_script,entry[0],entry[1],entry[2],size)
		var pet = actors[-1]
		pet.set_meta("food_id",entry[4])
		if not entry[5].is_empty(): pet.update_task(entry[5],"read" if entry[5] == "study" else "flyer")
		var texture = TextureRect.new()
		texture.texture = view.get_texture()
		texture.position = Vector2((i%columns)*size.x,(i/columns)*(size.y+30)+30)
		texture.size = size
		canvas.add_child(texture)
		var label = Label.new()
		label.text = entry[3]
		label.position = Vector2((i%columns)*size.x+8,(i/columns)*(size.y+30)+3)
		canvas.add_child(label)
	var folder = FEED_OUT+version+"/"+mode+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*8:
		for pet in actors:
			if frame == FPS and mode != "idle":
				if mode == "wash_tasks": pet.perform("wash",2.4)
				else: pet.feed_item(pet.get_meta("food_id"))
			pet._process(1.0/FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(folder+"%04d.png"%frame)
		if frame%60 == 0: print("FEED_CAPTURE ",version," ",mode," ",frame,"/240")
	for pet in actors:
		assert(pet.action.is_empty(),"care feedback finishes")
		if mode == "study": assert(pet.task_kind == "study" and pet.book.visible,"returns to study")
		if mode == "work": assert(pet.task_kind == "work" and pet.props.visible,"returns to work")
	canvas.queue_free()
	await process_frame

func verify_feed(character: Script):
	# Compare frozen performances using only the separately verified shared
	# resting-pose correction; their held poses, faces and timings stay intact.
	var baseline = load(FEED_OUT+"before-v3-clear-rest.gd")
	for name_ in ["","head","look","yawn","hop","pet","belly","wing_l","wing_r","feet","wash","angry","spin","dance","celebrate"]:
		var old = baseline.new()
		var current = character.new()
		for pet in [old,current]:
			root.add_child(pet)
			pet.set_process(false)
			pet.rng.seed = 301
			pet.idle_left = 10000
			pet.blink_wait = 2.8
			if not name_.is_empty(): pet.perform(name_,2.4)
		for frame in FPS*8:
			for pet in [old,current]: pet._process(1.0/FPS)
			for i in current.skeleton.get_bone_count():
				assert(current.skeleton.get_bone_pose(i).is_equal_approx(old.skeleton.get_bone_pose(i)),"frozen skeleton: "+name_)
			assert(current.expression_weights == old.expression_weights,"frozen expression: "+name_)
			assert(current.torso.transform.is_equal_approx(old.torso.transform),"frozen torso: "+name_)
			for i in current.bubbles.size():
				assert(current.bubbles[i].visible == old.bubbles[i].visible and current.bubbles[i].transform.is_equal_approx(old.bubbles[i].transform),"C02 bath bubbles unchanged")
		old.free()
		current.free()
	for task in [["",""],["study","read"],["work","flyer"],["study","sport"],["work","code"]]:
		for food in ["bread","fish","steak","snack"]:
			var pet = character.new()
			root.add_child(pet)
			pet.set_process(false)
			pet.idle_left = 10000
			pet.view_yaw = 0.4
			pet.update_task(task[0],task[1])
			pet._process(0)
			var feet: Array[Transform3D] = []
			for bone in ["leftfoot","rightfoot"]: feet.append(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone(bone)))
			pet.feed_item(food)
			for frame in FPS*8:
				pet._process(1.0/FPS)
				assert(pet.task_kind == task[0] and pet.task_id == task[1] and is_equal_approx(pet.view_yaw,0.4),"food keeps the task and user's rotation")
				for i in 2:
					assert(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone("leftfoot" if i == 0 else "rightfoot")).is_equal_approx(feet[i]),"feeding keeps the feet planted")
				if pet.action_total-pet.action_left<1.249: assert(not pet.food_root.visible,"food appears only after the wings extend forward")
				if frame>FPS*4.1: assert(not pet.food_root.visible,"empty wings lower after the food is finished")
				if frame>=FPS*2 and frame<FPS*3:
					var mouth = pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone("head_x"))*pet.mouth_in_head
					assert(pet.food_root.visible and pet.food_root.position.distance_to(mouth)<0.085,"food reaches the mouth")
					assert(pet.food_root.scale.is_equal_approx(Vector3.ONE),"food stays intact while eating")
					for side in ["l","r"]:
						var hand = pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone("hand_"+side)).origin
						var grip = pet.food_root.position+Vector3(pet.FOOD_WIDTHS[food]*(1 if side == "l" else -1),0,0)
						assert(hand.distance_to(grip)<0.002,"both hands grip the food edges")
			assert(pet.action.is_empty() and not pet.food_root.visible,"feeding ends and releases the prop")
			assert(pet.book.scale.is_equal_approx(Vector3.ONE) and pet.props.scale.is_equal_approx(Vector3.ONE),"task props restore")
			pet.free()
	for kind in ["study","work"]:
		var pet = character.new()
		root.add_child(pet)
		pet.set_process(false)
		pet.idle_left = 10000
		pet.update_task(kind,"read" if kind == "study" else "flyer")
		pet.perform("wash",2.4)
		assert(is_equal_approx(pet.action_total,3.4),"task bath wraps the same 2.4 second wash")
		pet._process(0.2)
		assert(not pet.bubbles[0].visible and pet.expression_weights.is_empty(),"task pose settles before bathing begins")
		for frame in FPS*4: pet._process(1.0/FPS)
		assert(pet.action.is_empty() and pet.task_kind == kind and pet.book.scale.is_equal_approx(Vector3.ONE) and pet.props.scale.is_equal_approx(Vector3.ONE),"bath returns to the task")
		pet.feed_item("bread")
		pet._process(2.0)
		pet.perform("head",1.8)
		pet._process(0)
		assert(not pet.food_root.visible and pet.task_kind == kind,"another interaction can replace feeding without leaving a floating prop")
		pet.free()
	print("FEED_VERIFY_OK: confirmed A/B/D match with the shared idle transition correction; C02 bath motion retained; four foods; receive after extension; food finishes before lowering; mouth reach; planted feet; task return; interruption cleanup")
	feed_verified = true

func run():
	Engine.max_fps = 60
	root.size = Vector2i(100,100)
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	var version = "v3"
	var mode = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = arg.trim_prefix("--version=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	assert(version.is_valid_filename() and version not in [".",".."])
	var character = load(FEED_OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline:
		verify_feed(character)
		if not feed_verified:
			quit(1)
			return
	if "--verify-only" not in OS.get_cmdline_user_args():
		for selected in (["bare"] if baseline else ["bare","clothes","foods","study","work","rear","idle"]):
			if selected == "bare" and "--extras-only" in OS.get_cmdline_user_args(): continue
			if mode.is_empty() or mode == selected: await capture_feed(character,"v0" if baseline else version,selected)
	print("FEED_PREVIEW_COMPLETE")
	quit()
