extends "res://scripts/penguin.gd"
# nicoma's CC BY 4.0 penguin. Native clips plus small local bone poses.
var skeleton: Skeleton3D
var player: AnimationPlayer
var model: Node3D
var mounts: Dictionary = {}
var body_materials: Array[StandardMaterial3D] = []
const MODEL_SCALE = 4.4 / 3430.925048828125

func _ready():
	rng.randomize()
	torso = pivot(self,Vector3.ZERO)
	model = load("res://assets/nicoma/scene.gltf").instantiate()
	model.scale = Vector3.ONE*MODEL_SCALE
	torso.add_child(model)
	find_parts(model)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for anim in player.get_animation_list():
		player.get_animation(anim).loop_mode = Animation.LOOP_NONE if anim == "Jump" else Animation.LOOP_LINEAR
	player.play("IDLE_01")
	player.advance(0)
	# Hit regions and accessories follow the actual animated bones.
	var head_mount = mount("head","head_16")
	var belly_mount = mount("belly","spine_02_21")
	var l_mount = mount("wing_l","lowerarm_r_6")
	var r_mount = mount("wing_r","lowerarm_l_2")
	var fl_mount = mount("foot_l","foot_l_24")
	var fr_mount = mount("foot_r","foot_r_27")
	# The source uses a dark stylized body. Add soft face/belly patches and eyes
	# while keeping its mesh, skinning, six animation clips and articulated limbs.
	var cream = material("fff4df")
	var ink = material("26343a",0.3)
	orb(belly_mount,Vector3(0,0.085,0.117),Vector3(0.205,0.28,0.075),cream)
	for side in [-1,1]:
		orb(head_mount,Vector3(side*0.043,0.072,0.092),Vector3(0.105,0.137,0.09),cream)
		var eye = pivot(head_mount,Vector3(side*0.043,0.09,0.138))
		orb(eye,Vector3.ZERO,Vector3(0.021,0.032,0.014),ink)
		orb(eye,Vector3(-0.004,0.007,0.007),Vector3(0.007,0.009,0.003),cream)
		eyes.append(eye)
		orb(head_mount,Vector3(side*0.071,0.05,0.127),Vector3(0.035,0.014,0.009),material("dda294"))
	orb(head_mount,Vector3(-0.009,0.165,0),Vector3(0.03,0.045,0.035),material("394e55")).rotation.z=-0.3
	hit(head_mount,"head",Vector3(0,0.07,0.01),Vector3(0.25,0.24,0.27))
	hit(belly_mount,"belly",Vector3(0,0.055,0.01),Vector3(0.25,0.25,0.25))
	hit(l_mount,"wing_l",Vector3(0,0.06,0),Vector3(0.07,0.18,0.09))
	hit(r_mount,"wing_r",Vector3(0,0.06,0),Vector3(0.07,0.18,0.09))
	hit(fl_mount,"feet",Vector3(0,0,0.03),Vector3(0.11,0.06,0.14))
	hit(fr_mount,"feet",Vector3(0,0,0.03),Vector3(0.11,0.06,0.14))
	# Use the same accessory geometry as the fallback, in a 1-unit visual scale.
	head = pivot(head_mount,Vector3(0,0.065,0))
	head.scale = Vector3.ONE/4.4
	hat = pivot(head,Vector3.ZERO)
	neck = pivot(mount("neck","neck_01_18"),Vector3(0,-1.43/4.4,0))
	neck.scale = Vector3.ONE/4.4
	dark = material("354f59")
	book = pivot(torso,Vector3(0,1.0,0.5))
	for side in [-1,1]:
		var page = box(book,Vector3(side*0.18,0,0),Vector3(0.35,0.43,0.04),material("698d82"))
		page.rotation.y = side*0.18
		box(page,Vector3(0,0,0.03),Vector3(0.29,0.36,0.015),cream)
	book.rotation.x = -0.25
	props = pivot(torso,Vector3(0.51,0.94,0.3))
	box(props,Vector3.ZERO,Vector3(0.3,0.43,0.025),cream)
	for i in 3: box(props,Vector3(0,0.1-i*0.08,0.02),Vector3(0.18,0.015,0.01),material("9bac91"))
	for i in 12:
		var b = orb(torso,Vector3.ZERO,Vector3.ONE*0.1,material("d2e5e1",0.15))
		b.visible = false
		bubbles.append(b)
	book.visible = false
	props.visible = false

func find_parts(node: Node):
	if node is Skeleton3D: skeleton = node
	if node is AnimationPlayer: player = node
	if node is MeshInstance3D:
		if node.name in ["Object_7","Object_11"]: node.visible = false
		node.custom_aabb = AABB(Vector3(-0.4,-0.1,-0.4),Vector3(0.8,0.8,0.8))
		for i in node.mesh.get_surface_count():
			var original = node.mesh.surface_get_material(i)
			if original is StandardMaterial3D:
				var mat = original.duplicate() as StandardMaterial3D
				mat.emission_enabled = false
				mat.roughness = 0.75
				if mat.resource_name == "body" or mat.resource_name == "hands":
					mat.albedo_color = Color("394e55")
					body_materials.append(mat)
				node.set_surface_override_material(i,mat)
	for child in node.get_children(): find_parts(child)

func mount(key: String, bone: String) -> BoneAttachment3D:
	var n = BoneAttachment3D.new()
	n.bone_name = bone
	skeleton.add_child(n)
	mounts[key] = n
	return n

func turn_bone(name_: String, axis: Vector3, angle: float):
	var idx = skeleton.find_bone(name_)
	if idx < 0: return
	var pose = skeleton.get_bone_pose_rotation(idx)
	skeleton.set_bone_pose_rotation(idx,Quaternion(axis,angle)*pose)

func update_accessories(head_id: String, neck_id: String, golden: bool):
	super.update_accessories(head_id,neck_id,golden)
	for mat in body_materials: mat.albedo_color = Color("b49a55" if golden else "394e55")

func _process(delta: float):
	time += delta
	action_left = maxf(0,action_left-delta)
	if action_left == 0: action = ""
	idle_left -= delta
	if idle_left <= 0 and task_kind.is_empty() and action.is_empty():
		idle_left = rng.randf_range(8,15)
		var pick = rng.randi_range(0,4)
		if pick < 2: target = Vector3(rng.randf_range(-1.0,1.0),0,rng.randf_range(-0.1,0.15))
		else:
			perform(["look","yawn","hop"][pick-2],3.0)
			idle_seen.emit()
	var moving = position.distance_to(target)>0.025 and action.is_empty()
	if moving:
		position = position.move_toward(target,delta*0.24)
		rotation.y = lerp_angle(rotation.y,0.75*signf(target.x-position.x),delta*3)
	else: rotation.y = lerp_angle(rotation.y,0,delta*2)
	var clip = "walk" if moving else "IDLE_01"
	if action == "look": clip = "afk_01"
	if action == "yawn": clip = "afk_02"
	if action in ["hop","feet"]: clip = "Jump"
	if action == "dance" or task_id in ["sport","martial","combat","idol","stage"]: clip = "jojing"
	if player.current_animation != clip: player.play(clip,0.15)
	skeleton.reset_bone_poses()
	player.advance(delta)
	for eye in eyes: eye.scale.y = 1.0
	var elapsed = action_total-action_left
	var wave = sin(elapsed*10)
	var envelope = sin(PI*clampf(action_left/action_total,0,1))
	torso.rotation = Vector3.ZERO
	torso.position.y = 0.0
	book.visible = task_kind == "study" and task_id not in ["sport","martial","combat","stage"]
	props.visible = task_kind == "work" and task_id not in ["carry","guard","idol"]
	if not task_kind.is_empty():
		turn_bone("head_16",Vector3.RIGHT,0.09+sin(time*2.5)*0.04)
		if book.visible or task_id in ["library","code"]:
			book.visible = true
			props.visible = false
			turn_bone("lowerarm_l_2",Vector3.FORWARD,-0.35)
			turn_bone("lowerarm_r_6",Vector3.FORWARD,0.35)
		elif task_kind == "work":
			turn_bone("lowerarm_l_2",Vector3.FORWARD,sin(time*3)*0.25)
	match action:
		"head": turn_bone("head_16",Vector3.FORWARD,envelope*0.18)
		"pet":
			turn_bone("head_16",Vector3.FORWARD,sin(time*5)*0.1)
			close_eyes(1)
		"belly":
			turn_bone("spine_02_21",Vector3.RIGHT,-envelope*0.15)
			turn_bone("head_16",Vector3.RIGHT,-envelope*0.12)
			turn_bone("beak_01_14",Vector3.RIGHT,envelope*0.15+absf(wave)*0.08)
			close_eyes(envelope*0.8)
		"wing_l": turn_bone("lowerarm_r_6",Vector3.FORWARD,-envelope*(0.9+wave*0.22))
		"wing_r": turn_bone("lowerarm_l_2",Vector3.FORWARD,envelope*(0.9+wave*0.22))
		"feed":
			turn_bone("head_16",Vector3.RIGHT,wave*0.07)
			turn_bone("beak_01_14",Vector3.RIGHT,absf(wave)*0.22)
		"wash":
			turn_bone("spine_02_21",Vector3.FORWARD,wave*0.05)
			close_eyes(0.95)
		"angry":
			turn_bone("head_16",Vector3.UP,wave*0.15*envelope)
			turn_bone("lowerarm_l_2",Vector3.FORWARD,envelope*0.25)
			turn_bone("lowerarm_r_6",Vector3.FORWARD,-envelope*0.25)
		"spin":
			torso.rotation.y = (1.0-action_left/action_total)*TAU
			turn_bone("lowerarm_l_2",Vector3.FORWARD,envelope*0.6)
			turn_bone("lowerarm_r_6",Vector3.FORWARD,-envelope*0.6)
		"celebrate":
			torso.position.y = absf(sin(elapsed*5))*0.2*envelope
			turn_bone("lowerarm_l_2",Vector3.FORWARD,envelope*0.8)
			turn_bone("lowerarm_r_6",Vector3.FORWARD,-envelope*0.8)
	if fmod(time,4.3)<0.14: close_eyes(1)
	if low_mood and action.is_empty(): turn_bone("head_16",Vector3.RIGHT,0.08)
	torso.rotation.y += view_yaw
	skeleton.force_update_all_bone_transforms()
	for i in bubbles.size():
		var b = bubbles[i]
		b.visible = action == "wash"
		if b.visible:
			var a = float(i)*2.4+time
			b.position = Vector3(sin(a)*0.7,0.4+fmod(time*0.65+i*0.19,2),cos(a)*0.5)
			b.scale = Vector3.ONE*(0.09+0.04*sin(i*3.1))

func close_eyes(amount: float):
	for eye in eyes: eye.scale.y = 1.0-amount*0.9
	for bone in ["eye_l_01_10","eye_l_02_11","eye_r_01_12","eye_r_02_13"]:
		var idx = skeleton.find_bone(bone)
		var pose = skeleton.get_bone_pose_scale(idx)
		pose.y *= 1.0-amount*0.9
		skeleton.set_bone_pose_scale(idx,pose)
