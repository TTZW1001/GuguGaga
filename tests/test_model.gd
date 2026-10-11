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
	return skin_mesh_vertices(body,pet.skeleton)

func skin_mesh_vertices(body: MeshInstance3D, skeleton: Skeleton3D, surface: int = 0) -> PackedVector3Array:
	var arrays = body.mesh.surface_get_arrays(surface)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var transforms: Array[Transform3D] = []
	for i in body.skin.get_bind_count():
		var name_ = body.skin.get_bind_name(i)
		var bone = skeleton.find_bone(name_) if not name_.is_empty() else body.skin.get_bind_bone(i)
		transforms.append(skeleton.get_bone_global_pose(bone)*body.skin.get_bind_pose(i))
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
	# Stretching lifts the wings farther than a wave. Compare the chest with the
	# exact same head/spine pose and only the wing hinges reset, so the intended
	# upper-body extension does not hide another shoulder-skinning regression.
	pet.perform("yawn",2.6)
	pet.action_left = pet.action_total*0.5
	pet._process(0)
	var stretched = skin_vertices(pet)
	var hinges: Array[int] = []
	var hinge_rotations: Array[Quaternion] = []
	for bone in ["arm_stretch_l","arm_stretch_r"]:
		var idx = pet.skeleton.find_bone(bone)
		hinges.append(idx)
		hinge_rotations.append(pet.skeleton.get_bone_pose_rotation(idx))
		pet.skeleton.set_bone_pose_rotation(idx,Quaternion.IDENTITY)
	pet.skeleton.force_update_all_bone_transforms()
	var stretch_reference = skin_vertices(pet)
	var stretch_chest_motion = 0.0
	var stretch_wing_motion = 0.0
	for i in rest.size():
		if i in chest: stretch_chest_motion = maxf(stretch_chest_motion,stretched[i].distance_to(stretch_reference[i]))
		if absf(rest[i].x)>0.35: stretch_wing_motion = maxf(stretch_wing_motion,stretched[i].distance_to(stretch_reference[i]))
	expect(stretch_chest_motion<0.006,"raised stretch wings preserve chest and neck geometry")
	expect(stretch_wing_motion>0.1,"stretch wing hinges actually move the flippers")
	for i in hinges.size(): pet.skeleton.set_bone_pose_rotation(hinges[i],hinge_rotations[i])
	pet.skeleton.force_update_all_bone_transforms()
	# The angry pose bends real forearm skin, rather than pulling the shoulder
	# roots inward. Isolate the elbow motion at the fully held waist pose.
	pet.perform("angry",1.8)
	pet.action_left = pet.action_total-3.0
	pet._process(0)
	var folded = skin_vertices(pet)
	var elbows: Array[int] = []
	var elbow_rotations: Array[Quaternion] = []
	for side in ["l","r"]:
		var idx = pet.skeleton.find_bone("forearm_stretch_"+side)
		elbows.append(idx)
		elbow_rotations.append(pet.skeleton.get_bone_pose_rotation(idx))
		pet.skeleton.set_bone_pose_rotation(idx,pet.skeleton.get_bone_rest(idx).basis.get_rotation_quaternion())
	pet.skeleton.force_update_all_bone_transforms()
	var unfolded = skin_vertices(pet)
	var elbow_chest_motion = 0.0
	var folded_tip_width = 0.0
	var unfolded_tip_width = 0.0
	var tip_count = 0
	for i in rest.size():
		if i in chest: elbow_chest_motion = maxf(elbow_chest_motion,folded[i].distance_to(unfolded[i]))
		if absf(rest[i].x)>0.43:
			tip_count += 1
			folded_tip_width += absf(folded[i].x)
			unfolded_tip_width += absf(unfolded[i].x)
	expect(elbow_chest_motion<0.006,"angry elbow folds preserve chest and neck geometry")
	expect(tip_count>0 and folded_tip_width<unfolded_tip_width*0.8,"actual skinned wing tips fold inward toward the waist")
	for i in elbows.size(): pet.skeleton.set_bone_pose_rotation(elbows[i],elbow_rotations[i])
	pet.skeleton.force_update_all_bone_transforms()
	# Reaching the mouth uses two independent wing segments. Check the skinned
	# chest against the same chewing head pose with those segments at rest.
	pet.feed_item("bread")
	pet.action_left = pet.action_total-2.0
	pet._process(0)
	var feeding = skin_vertices(pet)
	for side in ["l","r"]:
		for segment in ["arm_stretch_","forearm_stretch_"]:
			var idx = pet.skeleton.find_bone(segment+side)
			pet.skeleton.set_bone_pose_rotation(idx,pet.skeleton.get_bone_rest(idx).basis.get_rotation_quaternion())
	pet.skeleton.force_update_all_bone_transforms()
	var feed_reference = skin_vertices(pet)
	var feed_chest_motion = 0.0
	for i in chest: feed_chest_motion = maxf(feed_chest_motion,feeding[i].distance_to(feed_reference[i]))
	expect(feed_chest_motion<0.006,"two-hand feeding preserves chest and neck geometry")
	pet._process(0)
	test_accessories(pet)
	test_folded_sleeves(pet)
	pet.free()
	await capture_poses()
	print("MODEL_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed==0 else 1)

func test_folded_sleeves(pet: Node3D):
	pet.update_accessories("none","none",true)
	pet.perform("angry",1.8)
	pet.action_left = pet.action_total-3.0
	pet._process(0)
	var sleeve_mesh = pet.elegant_suit.find_children("*","MeshInstance3D",true,false)[0]
	var folded = skin_mesh_vertices(sleeve_mesh,pet.skeleton,2)
	for side in ["l","r"]:
		var idx = pet.skeleton.find_bone("forearm_stretch_"+side)
		pet.skeleton.set_bone_pose_rotation(idx,pet.skeleton.get_bone_rest(idx).basis.get_rotation_quaternion())
	pet.skeleton.force_update_all_bone_transforms()
	var unfolded = skin_mesh_vertices(sleeve_mesh,pet.skeleton,2)
	var arrays = sleeve_mesh.mesh.surface_get_arrays(2)
	var indices = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	var stride = indices.size()/folded.size()
	var counts = {"l":0,"r":0}
	var inward = {"l":0.0,"r":0.0}
	for i in folded.size():
		for j in stride:
			var k = i*stride+j
			var bone = sleeve_mesh.skin.get_bind_name(indices[k])
			if weights[k]>0.99 and bone in ["forearm_stretch_l","forearm_stretch_r"]:
				var side = "l" if bone.ends_with("_l") else "r"
				counts[side] += 1
				inward[side] += absf(unfolded[i].x)-absf(folded[i].x)
	for side in ["l","r"]:
		expect(counts[side]>20 and inward[side]/maxi(counts[side],1)>0.04,"suit cuff folds inward with the wing tip: "+side)
	pet._process(0)

func test_accessories(pet: Node3D):
	var choices=[["redhat","scarf","red_hood","red_scarf"],["graduate","tie","graduation_cap","blue_tie"],["crown","bow","small_crown","red_bow"]]
	for choice in choices:
		pet.update_accessories(choice[0],choice[1],false)
		for key in [choice[2],choice[3]]:
			var accessory=pet.get(key)
			expect(is_instance_valid(accessory) and accessory.visible,"remodeled accessory visible: "+key)
			check_skin(pet,accessory,key)
		pet.update_accessories(choice[0],choice[1],true)
		expect(pet.elegant_suit.visible and not pet.get(choice[2]).visible and not pet.get(choice[3]).visible,"suit hides head and neck: "+choice[0])
		var cached=pet.elegant_suit
		pet.update_accessories(choice[0],choice[1],false)
		expect(not cached.visible and pet.get(choice[2]).visible and pet.get(choice[3]).visible,"removing suit restores both slots: "+choice[0])
		pet.update_accessories(choice[0],choice[1],true)
		expect(pet.elegant_suit==cached,"suit reuses cached mesh")
	check_skin(pet,pet.elegant_suit,"elegant_suit")
	pet.update_accessories("none","none",false)
	for key in ["red_hood","graduation_cap","small_crown","red_scarf","red_bow","blue_tie","elegant_suit"]:
		expect(not pet.get(key).visible,"unequipped model hidden: "+key)
	for mat in pet.body_materials:expect(mat.albedo_color==Color.WHITE,"original body color preserved")

func check_skin(pet: Node3D, accessory: Node3D, title: String):
	var meshes=accessory.find_children("*","MeshInstance3D",true,false)
	expect(not meshes.is_empty(),title+" has actual mesh")
	for mesh in meshes:
		expect(mesh.get_node(mesh.skeleton)==pet.skeleton,title+" uses live pet skeleton")
		var binds_ok=mesh.skin.get_bind_count()>0
		for i in mesh.skin.get_bind_count():
			binds_ok=binds_ok and pet.skeleton.find_bone(mesh.skin.get_bind_name(i))>=0
		expect(binds_ok,title+" all skin binds resolve")

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
