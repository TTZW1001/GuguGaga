extends "res://tools/preview_look.gd"
const READ_OUT = "res://build/动作预览/E02-识字课/"
var verified = false
func verify_read(character: Script):
	var baseline = load(READ_OUT+"v0/character.gd")
	for task in [["",""],["study","sport"],["study","martial"],["study","combat"],["study","math"],["study","science"],["work","library"],["work","code"],["work","flyer"],["work","idol"]]:
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
			for frame in FPS*16:
				for pet in [old,current]: pet._process(1.0/FPS)
				for i in current.skeleton.get_bone_count():
					assert(current.skeleton.get_bone_pose(i).is_equal_approx(old.skeleton.get_bone_pose(i)),"frozen bone: "+str(task)+gesture)
				assert(current.expression_weights == old.expression_weights,"frozen expressions")
				assert(current.torso.transform.is_equal_approx(old.torso.transform),"frozen torso")
				if task[1] == "sport": assert(current.basketball.transform.is_equal_approx(old.basketball.transform) and current.basketball.visible == old.basketball.visible,"frozen E01 ball")
				if task[1] == "combat": assert(current.combat_root.transform.is_equal_approx(old.combat_root.transform) and current.combat_hanger.transform.is_equal_approx(old.combat_hanger.transform) and current.combat_root.visible == old.combat_root.visible,"frozen E07 bag")
				if task[1] in ["math","science","library","code"]: assert(current.book.transform.is_equal_approx(old.book.transform) and current.book.visible == old.book.visible,"other shared book tasks unchanged")
				if gesture == "feed": assert(current.food_root.transform.is_equal_approx(old.food_root.transform) and current.food_root.visible == old.food_root.visible,"frozen C01")
			old.free()
			current.free()
	var pet = character.new()
	root.add_child(pet)
	pet.set_process(false)
	pet.idle_left = 10000
	pet.view_yaw = 0.4
	pet.update_task("study","read")
	for frame in FPS*4: pet._process(1.0/FPS)
	var book_basis = pet.book.global_transform.basis.orthonormalized()
	var head_point = pet.skeleton.global_transform*pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone("head_x")).origin
	assert((pet.torso.global_transform.basis.inverse()*book_basis.y).z>0.4,"book top tilts away from the body")
	assert(book_basis.z.dot((head_point-pet.book.global_position).normalized())>0.8,"pages face the reader")
	for gesture in ["head","pet","belly","wing_l","wing_r","feet","feed","wash","angry","spin"]:
		pet.perform(gesture,2.4)
		for frame in FPS*8:
			pet._process(1.0/FPS)
			assert(pet.task_kind == "study" and pet.task_id == "read" and is_equal_approx(pet.view_yaw,0.4),"task and user rotation retained")
		assert(pet.action.is_empty() and pet.reading_blend == 1.0,"interaction returns to reading pose")
	pet.update_task("","")
	for frame in FPS: pet._process(1.0/FPS)
	assert(is_zero_approx(pet.reading_blend),"course returns to idle")
	pet.free()
	print("READ_VERIFY_OK: frozen A-D/E01/E04/E07 and other tasks; all interactions return; rotation retained")
	verified = true

func capture_read(character: Script, version: String, mode: String):
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
		# The shared old preview helper delays blinking to 20 seconds. Restore
		# the normal production interval for this preview, without changing gameplay.
		var pet = actors.back()
		pet.blink_wait = pet.rng.randf_range(2.8,5.6)
		var texture = TextureRect.new()
		texture.texture = view.get_texture()
		texture.position = Vector2((i%3)*size.x,(i/3)*(size.y+30)+30)
		texture.size = size
		canvas.add_child(texture)
		var label = Label.new()
		label.text = entry[3]
		label.position = Vector2((i%3)*size.x+8,(i/3)*(size.y+30)+3)
		canvas.add_child(label)
	var seconds = 30 if mode == "care" else 26 if mode in ["feed","wash","touch"] else 16
	var finish = 27.0 if mode == "care" else 23.0 if seconds == 26 else 13.6
	var folder = READ_OUT+version+"/"+mode+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*seconds:
		for pet in actors:
			if frame == FPS: pet.update_task("study","read")
			if frame == FPS*6 and mode in ["feed","care"]: pet.feed_item("bread")
			if frame == FPS*6 and mode == "wash": pet.perform("wash",2.4)
			if frame == FPS*6 and mode == "touch": pet.perform("wing_l",1.8)
			if frame == FPS*14 and mode == "care": pet.perform("wash",2.4)
			if frame == FPS*20 and mode == "care": pet.perform("wing_l",1.8)
			if frame == int(FPS*finish): pet.update_task("","")
			pet._process(1.0/FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(folder+"%04d.png"%frame)
		if frame%90 == 0: print("READ_CAPTURE ",version," ",mode," ",frame,"/",FPS*seconds)
	canvas.queue_free()
	await process_frame

func run():
	Engine.max_fps = 60
	root.size = Vector2i(100,100)
	var args = OS.get_cmdline_user_args()
	var baseline = "--baseline" in args
	var mode = ""
	var version = "v2"
	for arg in args:
		if arg.begins_with("--version="): version = arg.trim_prefix("--version=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	var character = load(READ_OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline:
		verify_read(character)
		if not verified:
			quit(1)
			return
	if "--verify-only" not in args:
		for selected in (["bare"] if baseline else ["bare","clothes","care"]):
			if mode.is_empty() or mode == selected: await capture_read(character,"v0" if baseline else version,selected)
	print("READ_PREVIEW_COMPLETE")
	quit()
