extends "res://tools/preview_look.gd"
const PHONE_OUT = "res://build/动作预览/F04-远程客服/"
var verified = false
func verify_phone(character: Script):
	var baseline = load(PHONE_OUT+"v0/character.gd")
	for task in [["",""],["study","sport"],["study","martial"],["study","combat"],["study","read"],["study","math"],["study","science"],["study","manners"],["study","music"],["work","library"],["study","stage"],["work","code"],["work","idol"],["work","flyer"],["work","carry"],["work","guard"]]:
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
				if task[1] in ["read"]: assert(current.book.transform.is_equal_approx(old.book.transform) and current.book.visible == old.book.visible,"other shared book tasks unchanged")
				if task[1] == "flyer":
					for name_ in ["flyer_stack","flyer_single"]: assert(current.get(name_).transform.is_equal_approx(old.get(name_).transform) and current.get(name_).visible == old.get(name_).visible,"frozen F01 props")
				if task[1] == "carry": assert(current.carry_box.transform.is_equal_approx(old.carry_box.transform) and current.carry_box.visible == old.carry_box.visible,"frozen F02 box")
				if task[1] == "library":
					for name_ in ["proof_root","proof_leaf","proof_mark","proof_stamp"]: assert(current.get(name_).transform.is_equal_approx(old.get(name_).transform) and current.get(name_).visible == old.get(name_).visible,"frozen F03 props")
				if task[1] == "code":
					for name_ in ["laptop_root","laptop_cursor"]: assert(current.get(name_).transform.is_equal_approx(old.get(name_).transform) and current.get(name_).visible == old.get(name_).visible,"frozen F06 props")
					for i in 2: assert(current.laptop_keys[i].transform.is_equal_approx(old.laptop_keys[i].transform),"frozen F06 keys")
				if gesture == "feed": assert(current.food_root.transform.is_equal_approx(old.food_root.transform) and current.food_root.visible == old.food_root.visible,"frozen C01")
			old.free()
			current.free()
	var pet = character.new()
	root.add_child(pet)
	pet.set_process(false)
	pet.idle_left = 10000
	pet.view_yaw = 0.4
	pet.phone_rng.seed = 807
	pet.update_task("work","waiter")
	pet.rng.seed = 807
	pet.blink_wait = 2.8
	var closures = []
	var was_closed = false
	var lengths = {}
	var listening_frames = 0
	var talking_frames = 0
	var rest_frames = 0
	for frame in FPS*70:
		pet._process(1.0/FPS)
		assert(not pet.props.visible and not pet.book.visible and (frame<30 or pet.phone_root.visible),"customer service uses telephone only")
		assert(pet.phone_call_length>=6.0 and pet.phone_call_length<=10.0,"call lengths stay in the configured range")
		lengths[pet.phone_call_length] = true
		var start = pet.phone_wait+1.65
		var phase = (pet.phone_clock-start)/pet.phone_call_length
		if phase>0.02 and phase<0.98:
			var desired = pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone("head_x"))*pet.phone_in_head
			assert(desired.origin.distance_to(pet.phone_receiver.position)<0.002,"receiver stays at its intended ear-side position")
		var mouth = pet.expression_weights.get("face_Base_obj_morph5",0.0)
		if phase>0.04 and phase<0.20 or phase>0.55 and phase<0.70:
			assert(is_zero_approx(mouth),"listening closes the mouth")
			listening_frames += 1
		if phase>0.27 and phase<0.47 or phase>0.77 and phase<0.95:
			assert(mouth>=0.09,"speaking animates the mouth")
			talking_frames += 1
		if pet.phone_held:
			var tip = pet.skeleton.get_bone_global_pose(pet.skeleton.find_bone("hand_r"))*(pet.FLYER_WING_TIP*Vector3(-1,1,1))
			assert((pet.phone_receiver.transform*pet.PHONE_GRIP).distance_to(tip)<0.0001,"handset stays in the visible wing tip")
		elif frame>30 and pet.phone_clock<pet.phone_wait:
			assert(pet.phone_receiver.position.distance_to(pet.PHONE_HOME-Vector3(0,pet.torso.position.y/pet.SCALE,0))<0.0001,"handset returns to its cradle")
			rest_frames += 1
		var amount = pet.expression_weights.get("face_Base_obj_morph0",0.0)
		if amount>0.9 and not was_closed: closures.append(frame/float(FPS))
		was_closed = amount>0.9
		for name_ in ["face_Base_obj_morph7","face_NoOutline_obj_morph0","face_NoOutline_obj_morph1"]:
			assert(is_equal_approx(pet.face.get_blend_shape_value(pet.morphs[name_]),amount),"face/eye/lash blink pairing")
	assert(lengths.size()>=4 and listening_frames>300 and talking_frames>300 and rest_frames>50,"random calls repeat listen/speak/hang-up cycles")
	assert(closures.size()>=10,"long-running work has natural blinks")
	for i in range(1,closures.size()): assert(closures[i]-closures[i-1]>=2.8 and closures[i]-closures[i-1]<6.0,"natural blink spacing")
	print("PHONE_BLINK_OK closures=",closures," call_lengths=",lengths.keys())
	for gesture in ["head","pet","belly","wing_l","wing_r","feet","feed","wash","angry","spin"]:
		var clock = pet.phone_clock
		var number = pet.phone_call_number
		pet.perform(gesture,2.4)
		for frame in FPS*8:
			pet._process(1.0/FPS)
			assert(pet.task_kind == "work" and pet.task_id == "waiter" and is_equal_approx(pet.view_yaw,0.4),"task and user rotation retained")
			if frame == 18:
				assert(is_equal_approx(pet.phone_clock,clock) and pet.phone_call_number == number and not pet.phone_root.visible and not pet.phone_receiver.visible,"pause the visual call and put away telephone during interaction")
		assert(pet.action.is_empty() and pet.phone_blend == 1.0 and pet.phone_root.visible,"interaction returns to telephone work")
	pet.update_task("","")
	for frame in FPS: pet._process(1.0/FPS)
	assert(is_zero_approx(pet.phone_blend) and not pet.phone_root.visible and not pet.phone_receiver.visible,"work returns to idle")
	pet.free()
	print("PHONE_VERIFY_OK: frozen A-E/F01/F02/F03/F05/F06 and other jobs; listen/speak/hang-up; all interactions return; rotation retained")
	verified = true

func capture_phone(character: Script, version: String, mode: String):
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
		if entry[1]:
			var camera = view.get_camera_3d()
			camera.size = 1.8
			camera.position.x = -0.15
			camera.look_at(Vector3(-0.15,1.85,0))
		if not entry[1]:
			var camera = view.get_camera_3d()
			var shift = 0.30 if entry[0] == PI/2 else 0.0
			camera.position.x += shift
			camera.look_at(Vector3(shift,1.15,0))
		if not version == "v0": pet.phone_rng.seed = 301
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
	var seconds = 8 if "--draft" in OS.get_cmdline_user_args() else 30 if mode == "care" else 26
	var finish = 27.0 if mode == "care" else 23.0 if seconds == 26 else 13.6
	var folder = PHONE_OUT+version+"/"+mode+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	for frame in FPS*seconds:
		for pet in actors:
			if frame == FPS: pet.update_task("work","waiter")
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
		if frame%90 == 0: print("PHONE_CAPTURE ",version," ",mode," ",frame,"/",FPS*seconds)
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
	var character = load(PHONE_OUT+"v0/character.gd" if baseline else "res://scripts/tomori_penguin.gd")
	if not baseline and "--draft" not in args and "--capture-only" not in args:
		verify_phone(character)
		if not verified:
			quit(1)
			return
	if "--verify-only" not in args:
		for selected in (["bare"] if baseline else ["bare","clothes","care"]):
			if mode.is_empty() or mode == selected: await capture_phone(character,"v0" if baseline else version,selected)
	print("PHONE_PREVIEW_COMPLETE")
	quit()
