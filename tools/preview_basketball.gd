extends "res://tools/preview_look.gd"
const BASKET_OUT = "res://build/动作预览/E01-体育课/"
var verified = false

func verify_basketball(character: Script):
	var baseline = load(BASKET_OUT+"v0/character.gd")
	# Every frozen A-D performance and every other course/job keeps its pose.
	for task in [["",""],["study","read"],["study","martial"],["study","combat"],["work","flyer"],["work","idol"]]:
		for gesture in (["","head","look","yawn","hop","pet","belly","wing_l","wing_r","feet","feed","wash","angry","spin","dance","celebrate"] if task[0].is_empty() else ["","feed","wash"]):
			var old = baseline.new()
			var current = character.new()
			for pet in [old,current]:
				root.add_child(pet)
				pet.set_process(false)
				pet.rng.seed = 301
				pet.idle_left = 10000
				pet.blink_wait = 2.8
				pet.update_task(task[0],task[1])
				if not gesture.is_empty(): pet.perform(gesture,2.4)
			for frame in FPS*8:
				for pet in [old,current]: pet._process(1.0/FPS)
				for i in current.skeleton.get_bone_count():
					assert(current.skeleton.get_bone_pose(i).is_equal_approx(old.skeleton.get_bone_pose(i)),"frozen bone: "+str(task)+gesture)
				assert(current.expression_weights == old.expression_weights,"frozen expressions")
				assert(current.torso.transform.is_equal_approx(old.torso.transform),"frozen torso")
				assert(current.book.scale == old.book.scale and current.props.scale == old.props.scale,"frozen task props")
				if gesture == "feed": assert(current.food_root.transform.is_equal_approx(old.food_root.transform) and current.food_root.visible == old.food_root.visible,"frozen C01 food")
			old.free()
			current.free()
	var pet = character.new()
	root.add_child(pet)
	pet.set_process(false)
	pet.idle_left = 10000
	pet.view_yaw = 0.4
	pet.update_task("study","sport")
	for frame in FPS*4: pet._process(1.0/FPS)
	assert(pet.basketball.visible,"sports course shows basketball")
	for gesture in ["head","pet","belly","wing_l","wing_r","feet","feed","wash","angry","spin"]:
		pet.perform(gesture,2.4)
		pet._process(0.5)
		assert(not pet.basketball.visible,"ball clears for interaction: "+gesture)
		if gesture == "feed": assert(not pet.food_root.visible,"ball clears before receiving food")
		for frame in FPS*8:
			pet._process(1.0/FPS)
			assert(pet.task_kind == "study" and pet.task_id == "sport" and is_equal_approx(pet.view_yaw,0.4),"task and presentation rotation retained")
		assert(pet.basketball.visible and pet.action.is_empty(),"returns to basketball: "+gesture)
	pet.update_task("","")
	for frame in FPS: pet._process(1.0/FPS)
	assert(not pet.basketball.visible and is_zero_approx(pet.basketball_blend),"course ends and removes basketball")
	pet.free()
	print("BASKETBALL_VERIFY_OK: frozen A-D and other tasks; all interactions return to sports; prop cleanup; rotation retained")
	verified = true

func capture_basketball(character: Script, version: String, mode: String):
	actors.clear()
	var clothes = mode == "clothes"
	var size = Vector2i(360,450) if clothes else Vector2i(480,600)
	var entries = [[0.0,false,"bare","FRONT"],[PI/2,false,"bare","SIDE"],[0.0,true,"bare","FACE"]]
	if clothes:
		entries.clear()
		for angle in [0.0,PI/2]:
			for outfit in ["scarf","hood","suit"]: entries.append([angle,false,outfit,outfit.to_upper()+(" / FRONT" if angle == 0 else " / SIDE")])
	var canvas = SubViewport.new()
	canvas.size = Vector2i(size.x*3,(size.y+30)*(2 if clothes else 1))
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
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
	var seconds = 16 if mode in ["feed","wash","touch"] else 10
	var finish = 13 if seconds == 16 else 7
	var folder = BASKET_OUT+version+"/"+mode+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*seconds:
		for pet in actors:
			if frame == FPS: pet.update_task("study","sport")
			if frame == FPS*4 and mode == "feed": pet.feed_item("bread")
			if frame == FPS*4 and mode == "wash": pet.perform("wash",2.4)
			if frame == FPS*4 and mode == "touch": pet.perform("wing_l",1.8)
			if frame == FPS*finish: pet.update_task("","")
			pet._process(1.0/FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(folder+"%04d.png"%frame)
		if frame%90 == 0: print("BASKET_CAPTURE ",version," ",mode," ",frame,"/",FPS*seconds)
	canvas.queue_free()
	await process_frame

func run():
	Engine.max_fps = 60
	root.size = Vector2i(100,100)
	var args = OS.get_cmdline_user_args()
	var baseline = "--baseline" in args
	var mode = ""
	for arg in args:
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	var character = load(BASKET_OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline:
		verify_basketball(character)
		if not verified:
			quit(1)
			return
	if "--verify-only" not in args:
		for selected in (["bare"] if baseline else ["bare","clothes","feed","wash","touch"]):
			if mode.is_empty() or mode == selected: await capture_basketball(character,"v0" if baseline else "v1",selected)
	print("BASKET_PREVIEW_COMPLETE")
	quit()
