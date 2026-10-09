extends SceneTree
# Check actual skinned geometry, so an arm animation cannot quietly pinch the
# upper chest again. The reference is the imported model's undeformed rest pose.
var checks = 0
var failed = 0

func _initialize(): call_deferred("run")

func expect(ok: bool, description: String):
	checks += 1
	if not ok:
		failed += 1
		printerr("MODEL FAIL: ",description)
	else: print("MODEL OK: ",description)

func skin_vertices(pet: Node3D) -> PackedVector3Array:
	var body = pet.model.find_children("mesh0","MeshInstance3D",true,false)[0]
	var arrays = body.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var transforms: Array[Transform3D] = []
	for i in body.skin.get_bind_count():
		var bone = body.skin.get_bind_bone(i)
		if bone < 0: bone = pet.skeleton.find_bone(body.skin.get_bind_name(i))
		transforms.append(pet.skeleton.get_bone_global_pose(bone)*body.skin.get_bind_pose(i))
	var result = PackedVector3Array()
	var stride = bones.size()/positions.size()
	for i in positions.size():
		var p = Vector3.ZERO
		for j in stride:
			var k = i*stride+j
			p += (transforms[bones[k]]*positions[i])*weights[k]
		result.append(p)
	return result

func run():
	var pet = load("res://scripts/tomori_penguin.gd").new()
	root.add_child(pet)
	pet.set_process(false)
	pet.idle_left = 1000
	pet.skeleton.reset_bone_poses()
	var rest = skin_vertices(pet)
	var chest: Array[int] = []
	for i in rest.size():
		var p = rest[i]
		if absf(p.x)<0.105 and p.y>0.43 and p.y<0.58 and p.z>0.03:
			chest.append(i)
	expect(chest.size()>15,"upper chest geometry sampled from rest pose")
	pet._process(0)
	var idle = skin_vertices(pet)
	for action in ["","wing_l","wing_r"]:
		if action != "":
			pet.perform(action,1.8)
			pet.action_left = 0.9
		pet._process(0)
		var posed = skin_vertices(pet)
		var chest_motion = 0.0
		var left_motion = 0.0
		var right_motion = 0.0
		for i in rest.size():
			if i in chest: chest_motion = maxf(chest_motion,rest[i].distance_to(posed[i]))
			if rest[i].x>0.35: left_motion = maxf(left_motion,idle[i].distance_to(posed[i]))
			if rest[i].x< -0.35: right_motion = maxf(right_motion,idle[i].distance_to(posed[i]))
		expect(chest_motion<0.006,"rest chest silhouette preserved during "+("idle" if action=="" else action))
		if action=="wing_l": expect(right_motion>0.1 and left_motion<0.001,"left interaction moves its flipper independently")
		if action=="wing_r": expect(left_motion>0.1 and right_motion<0.001,"right interaction moves its flipper independently")
	pet.free()
	await capture_poses()
	print("MODEL_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed==0 else 1)

func capture_poses():
	var canvas = SubViewport.new()
	canvas.size = Vector2i(1500,1000)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var layout = GridContainer.new()
	layout.columns = 5
	canvas.add_child(layout)
	for angle in [0.0,0.5]:
		for pose in ["Source rest","Idle","Wave","Study","Exercise"]:
			var cell = VBoxContainer.new()
			cell.custom_minimum_size = Vector2(296,490)
			layout.add_child(cell)
			var title = Label.new()
			title.text = pose+(" / front" if angle==0 else " / 3-4")
			cell.add_child(title)
			var container = SubViewportContainer.new()
			cell.add_child(container)
			var viewport = SubViewport.new()
			viewport.size = Vector2i(296,460)
			viewport.own_world_3d = true
			container.add_child(viewport)
			var pet = load("res://scripts/tomori_penguin.gd").new()
			viewport.add_child(pet)
			pet.set_process(false)
			pet.idle_left = 1000
			if pose=="Wave":
				pet.perform("wing_l",1.8)
				pet.action_left = 0.9
			if pose=="Study":
				pet.task_kind = "study"
				pet.task_id = "read"
			if pose=="Exercise":
				pet.task_kind = "study"
				pet.task_id = "sport"
			pet._process(0)
			if pose=="Source rest": pet.skeleton.reset_bone_poses()
			pet.rotation.y = angle
			var env = WorldEnvironment.new()
			env.environment = Environment.new()
			env.environment.background_mode = Environment.BG_COLOR
			env.environment.background_color = Color("eee7da")
			env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.environment.ambient_light_color = Color("fff4df")
			env.environment.ambient_light_energy = 0.65
			viewport.add_child(env)
			var light = DirectionalLight3D.new()
			light.rotation_degrees = Vector3(-30,-25,0)
			light.light_energy = 0.65
			viewport.add_child(light)
			var camera = Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 2.9
			camera.position = Vector3(0,1.4,6)
			viewport.add_child(camera)
			camera.look_at(Vector3(0,1.3,0))
			camera.current = true
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png("res://tests/output/model_poses.png")
