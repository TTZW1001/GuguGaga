extends SceneTree

func _initialize(): call_deferred("run")

func run():
	for course in ["martial","combat","read","math","science","manners","music","stage"]:
		var pet = load("res://scripts/tomori_penguin.gd").new()
		root.add_child(pet)
		pet.set_process(false)
		pet.idle_left = 10000
		pet.rng.seed = 807
		pet.update_task("study",course)
		var closures = []
		var was_closed = false
		for frame in 60*30:
			pet._process(1.0/60)
			var amount = pet.expression_weights.get("face_Base_obj_morph0",0.0)
			if amount>0.9 and not was_closed: closures.append(frame/60.0)
			was_closed = amount>0.9
			for name_ in ["face_Base_obj_morph7","face_NoOutline_obj_morph0","face_NoOutline_obj_morph1"]:
				assert(is_equal_approx(pet.face.get_blend_shape_value(pet.morphs[name_]),amount),"face/eye/lash blink pairing")
		assert(closures.size()>=4,"regular natural course blinking")
		for i in range(1,closures.size()):
			assert(closures[i]-closures[i-1]>=2.8 and closures[i]-closures[i-1]<6.0,"natural blink spacing")
		print("COURSE_BLINK_OK ",course," 30 seconds, natural closures=",closures,"; face/eyes/lashes paired")
		pet.free()
	quit()
