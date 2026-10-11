extends "res://tools/preview_look.gd"
const GUARD_OUT = "res://build/动作预览/F05-保安/"
var verified = false
func verify_guard(character: Script):
	var baseline = load(GUARD_OUT+"v0/character.gd")
	for task in [["",""],["study","sport"],["study","martial"],["study","combat"],["study","read"],["study","math"],["study","science"],["study","manners"],["study","music"],["work","library"],["work","code"],["study","stage"],["work","serve"],["work","idol"],["work","flyer"],["work","carry"]]:
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
				assert(current.props.transform.is_equal_approx(old.props.transform) and current.props.visible == old.props.visible,"other job props unchanged")
				if task[1] == "stage":
					for names in [["lyric_notebook","lyric_notebook"],["lyric_pen","lyric_pen"]]:
						assert(current.get(names[0]).transform.is_equal_approx(old.get(names[1]).transform) and current.get(names[0]).visible == old.get(names[1]).visible,"frozen E09 props")
				if task[1] == "sport": assert(current.basketball.transform.is_equal_approx(old.basketball.transform) and current.basketball.visible == old.basketball.visible,"frozen E01 ball")
				if task[1] == "combat": assert(current.combat_root.transform.is_equal_approx(old.combat_root.transform) and current.combat_hanger.transform.is_equal_approx(old.combat_hanger.transform) and current.combat_root.visible == old.combat_root.visible,"frozen E07 bag")
				if task[1] == "music":
					assert(current.microphone.transform.is_equal_approx(old.microphone.transform) and current.microphone.visible == old.microphone.visible,"frozen E06 microphone")
					for i in current.music_notes.size(): assert(current.music_notes[i].transform.is_equal_approx(old.music_notes[i].transform) and current.music_notes[i].visible == old.music_notes[i].visible,"frozen E06 notes")
				if task[1] == "science": assert(current.magnifier.transform.is_equal_approx(old.magnifier.transform) and current.magnifier.visible == old.magnifier.visible,"frozen E08 magnifier")
				if task[1] == "math":
					assert(current.abacus.transform.is_equal_approx(old.abacus.transform) and current.abacus.visible == old.abacus.visible,"frozen E05 abacus")
					for bead in current.abacus_beads.size(): assert(current.abacus_beads[bead].transform.is_equal_approx(old.abacus_beads[bead].transform),"frozen E05 beads")
				if task[1] in ["read","library","code"]: assert(current.book.transform.is_equal_approx(old.book.transform) and current.book.visible == old.book.visible,"other shared book tasks unchanged")
				if task[1] == "flyer":
					for name_ in ["flyer_stack","flyer_single"]: assert(current.get(name_).transform.is_equal_approx(old.get(name_).transform) and current.get(name_).visible == old.get(name_).visible,"frozen F01 props")
				if task[1] == "carry": assert(current.carry_box.transform.is_equal_approx(old.carry_box.transform) and current.carry_box.visible == old.carry_box.visible,"frozen F02 box")
				if gesture == "feed": assert(current.food_root.transform.is_equal_approx(old.food_root.transform) and current.food_root.visible == old.food_root.visible,"frozen C01")
			old.free()
			current.free()
	var pet = character.new()
	var previous = load(GUARD_OUT+"v1/character.gd").new()
	root.add_child(previous)
	previous.set_process(false)
	previous.idle_left = 10000
	previous.update_task("work","guard")
	for frame in FPS*3: previous._process(1.0/FPS)
	root.add_child(pet)
	pet.set_process(false)
	pet.idle_left = 10000
	pet.view_yaw = 0.4
	pet.update_task("work","guard")
	for frame in FPS*3: pet._process(1.0/FPS)
	pet.rng.seed = 807
	pet.blink_wait = 2.8
	var closures = []
	var was_closed = false
	var salute_frames = 0
	for frame in FPS*30:
		pet._process(1.0/FPS)
		assert(not pet.props.visible and not pet.book.visible,"guard has no old generic paper/book props")
		assert(pet.position.distance_to(Vector3.ZERO)<0.001,"guard stays in place")
		var hand = pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone("hand_r")).origin
		if hand.y>0.68: salute_frames += 1
		for name_ in ["arm_stretch_r","forearm_stretch_r","hand_r"]:
			var bone = pet.skeleton.find_bone(name_)
			assert(pet.skeleton.get_bone_pose(bone).is_equal_approx(previous.skeleton.get_bone_pose(bone)),"retain v1 salute pose throughout duty")
		var amount = pet.expression_weights.get("face_Base_obj_morph0",0.0)
		if amount>0.9 and not was_closed: closures.append(frame/float(FPS))
		was_closed = amount>0.9
		for name_ in ["face_Base_obj_morph7","face_NoOutline_obj_morph0","face_NoOutline_obj_morph1"]:
			assert(is_equal_approx(pet.face.get_blend_shape_value(pet.morphs[name_]),amount),"face/eye/lash blink pairing")
	assert(salute_frames == FPS*30,"hold salute throughout the full 30 seconds without lowering")
	assert(closures.size()>=4,"long-running guard has natural blinks")
	for i in range(1,closures.size()): assert(closures[i]-closures[i-1]>=2.8 and closures[i]-closures[i-1]<6.0,"natural blink spacing")
	print("GUARD_BLINK_OK 30 seconds, natural closures=",closures,"; face/eyes/lashes paired")
	previous.free()
	for gesture in ["head","pet","belly","wing_l","wing_r","feet","feed","wash","angry","spin"]:
		var clock = pet.guard_clock
		pet.perform(gesture,2.4)
		for frame in FPS*8:
			pet._process(1.0/FPS)
			assert(pet.task_kind == "work" and pet.task_id == "guard" and is_equal_approx(pet.view_yaw,0.4),"task and user rotation retained")
			if frame == 18: assert(is_equal_approx(pet.guard_clock,clock),"pause salute sequence during interaction")
		assert(pet.action.is_empty() and pet.guard_blend == 1.0,"interaction returns to guard duty")
		assert(pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone("hand_r")).origin.y>0.68,"resume held salute after each interaction")
	pet.update_task("","")
	for frame in FPS: pet._process(1.0/FPS)
	assert(is_zero_approx(pet.guard_blend),"work returns to idle")
	pet.free()
	print("GUARD_VERIFY_OK: frozen A-E/F01/F02 and other jobs; held salute; all interactions return; rotation retained")
	verified = true

func capture_guard(character: Script, version: String, mode: String):
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
	var seconds = 4 if "--draft" in OS.get_cmdline_user_args() else 30 if mode == "care" else 16
	var finish = 27.0 if mode == "care" else 23.0 if seconds == 26 else 13.6
	var folder = GUARD_OUT+version+"/"+mode+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*seconds:
		for pet in actors:
			if frame == FPS: pet.update_task("work","guard")
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
		if frame%90 == 0: print("GUARD_CAPTURE ",version," ",mode," ",frame,"/",FPS*seconds)
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
	var character = load(GUARD_OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline and "--draft" not in args:
		verify_guard(character)
		if not verified:
			quit(1)
			return
	if "--verify-only" not in args:
		for selected in (["bare"] if baseline else ["bare","clothes","care"]):
			if mode.is_empty() or mode == selected: await capture_guard(character,"v0" if baseline else version,selected)
	print("GUARD_PREVIEW_COMPLETE")
	quit()
