extends "res://scripts/rig_penguin.gd"
# User-provided Tomori/penguin model. The source is a T pose with facial morphs;
# all body motion below is applied to individual bones, never to a rigid mesh.
const SCALE = 2.5
var face: MeshInstance3D
var morphs: Dictionary = {}
var expression_weights: Dictionary = {}
var blink_wait = 3.0
var blink_elapsed = -1.0

func _ready():
	rng.randomize()
	blink_wait = rng.randf_range(2.8,5.6)
	torso = pivot(self,Vector3.ZERO)
	model = load("res://assets/tomori/penguin.glb").instantiate()
	model.scale = Vector3.ONE*SCALE
	torso.add_child(model)
	find_parts(model)
	face = model.find_children("Tomori_mesh","MeshInstance3D",true,false)[0]
	for i in face.mesh.get_blend_shape_count(): morphs[face.mesh.get_blend_shape_name(i)] = i
	var head_mount = mount("head","head_x")
	var belly_mount = mount("belly","spine_01_x")
	var l_mount = mount("wing_l","arm_stretch_r")
	var r_mount = mount("wing_r","arm_stretch_l")
	var fl_mount = mount("foot_l","leftfoot")
	var fr_mount = mount("foot_r","rightfoot")
	hit(head_mount,"head",Vector3(0,0.12,0.02),Vector3(0.4,0.4,0.4))
	hit(belly_mount,"belly",Vector3(0,0.09,0.02),Vector3(0.43,0.43,0.41))
	hit(l_mount,"wing_l",Vector3(0,0.12,0),Vector3(0.16,0.36,0.2))
	hit(r_mount,"wing_r",Vector3(0,0.12,0),Vector3(0.16,0.36,0.2))
	hit(fl_mount,"feet",Vector3(0,0.03,0),Vector3(0.17,0.2,0.085))
	hit(fr_mount,"feet",Vector3(0,0.03,0),Vector3(0.17,0.2,0.085))
	head = pivot(head_mount,Vector3(0,0.13,0))
	head.scale = Vector3.ONE/SCALE
	hat = pivot(head,Vector3.ZERO)
	neck = pivot(mount("neck","neck_x"),Vector3(0,-1.55/SCALE,0))
	neck.scale = Vector3.ONE/SCALE
	dark = material("354f59")
	book = pivot(torso,Vector3(0,1.0,0.48))
	var cream = material("fff4df")
	for side in [-1,1]:
		var page = box(book,Vector3(side*0.18,0,0),Vector3(0.35,0.43,0.04),material("698d82"))
		page.rotation.y = side*0.18
		box(page,Vector3(0,0,0.03),Vector3(0.29,0.36,0.015),cream)
	book.rotation.x = -0.25
	props = pivot(torso,Vector3(0.57,0.92,0.35))
	box(props,Vector3.ZERO,Vector3(0.3,0.43,0.025),cream)
	for i in 3: box(props,Vector3(0,0.1-i*0.08,0.02),Vector3(0.18,0.015,0.01),material("9bac91"))
	for i in 12:
		var bubble = orb(torso,Vector3.ZERO,Vector3.ONE*0.1,material("d2e5e1",0.15))
		bubble.visible = false
		bubbles.append(bubble)
	book.visible = false
	props.visible = false

func find_parts(node: Node):
	if node is Skeleton3D: skeleton = node
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original = node.mesh.surface_get_material(i)
			if original is StandardMaterial3D:
				var mat = original.duplicate() as StandardMaterial3D
				mat.roughness = 0.9
				mat.metallic = 0
				if node.name == "mesh0": body_materials.append(mat)
				node.set_surface_override_material(i,mat)
	for child in node.get_children(): find_parts(child)

func update_accessories(head_id: String, neck_id: String, golden: bool):
	# Grandparent's simple accessories remain anchored to animated bones.
	super.update_accessories(head_id,neck_id,golden)
	for mat in body_materials: mat.albedo_color = Color("e1bf70" if golden else "ffffff")

func set_expression(name_: String, value: float):
	if morphs.has(name_): expression_weights[name_] = clampf(value,0,1)

func close_eyes(amount: float):
	# Skin eyelids and the separate eye/lash surface must use matching morphs.
	# NoOutline 4/5 are different expressions, not the partners of Base 0/7.
	set_expression("face_Base_obj_morph0",amount)
	set_expression("face_Base_obj_morph7",amount)
	set_expression("face_NoOutline_obj_morph0",amount)
	set_expression("face_NoOutline_obj_morph1",amount)

func smile(amount: float):
	set_expression("face_Base_obj_morph3",amount)

func open_mouth(amount: float):
	set_expression("face_Base_obj_morph5",amount)

func turn_flipper(side: String, axis: Vector3, angle: float):
	# Shoulder bones also skin the chest and neck: animate the flipper hinge.
	# Pose rotations use parent space; the shoulder's rolled axes differ on each
	# side, so convert the intended model-space axis instead of assuming local Z.
	var bone_name = "arm_stretch_"+side
	var idx = skeleton.find_bone(bone_name)
	var parent = skeleton.get_bone_parent(idx)
	var axis_in_parent = skeleton.get_bone_global_pose(parent).basis.inverse()*axis
	turn_bone(bone_name,axis_in_parent.normalized(),angle)

func idle_blink(delta: float) -> float:
	if not action.is_empty():
		blink_elapsed = -1.0
		blink_wait = maxf(blink_wait,0.8)
		return 0.0
	if blink_elapsed < 0:
		blink_wait -= delta
		if blink_wait > 0: return 0.0
		blink_elapsed = 0.0
	blink_elapsed += delta
	# Quick closure, a brief fully closed hold, and a softer reopening.
	if blink_elapsed < 0.07: return smoothstep(0.0,0.07,blink_elapsed)
	if blink_elapsed < 0.11: return 1.0
	if blink_elapsed < 0.23: return 1.0-smoothstep(0.11,0.23,blink_elapsed)
	blink_elapsed = -1.0
	blink_wait = rng.randf_range(2.8,5.6)
	return 0.0

func _process(delta: float):
	time += delta
	action_left = maxf(0,action_left-delta)
	if action_left == 0: action = ""
	idle_left -= delta
	if idle_left <= 0 and task_kind.is_empty() and action.is_empty():
		idle_left = rng.randf_range(8,15)
		var pick = rng.randi_range(0,4)
		if pick < 2: target = Vector3(rng.randf_range(-1.0,1.0),0,rng.randf_range(-0.12,0.16))
		else:
			perform(["look","yawn","hop"][pick-2],2.6)
			idle_seen.emit()
	var moving = position.distance_to(target)>0.025 and action.is_empty()
	if moving:
		var direction = target-position
		position = position.move_toward(target,delta*0.24)
		rotation.y = lerp_angle(rotation.y,0.7*signf(direction.x),delta*3)
	else: rotation.y = lerp_angle(rotation.y,0,delta*2)
	skeleton.reset_bone_poses()
	for name_ in expression_weights: face.set_blend_shape_value(morphs[name_],0)
	expression_weights.clear()
	torso.rotation = Vector3.ZERO
	torso.position.y = sin(time*2)*0.009
	# Lower the source's T-pose wings to a relaxed angle before other movement.
	turn_flipper("l",Vector3.FORWARD,1.25)
	turn_flipper("r",Vector3.FORWARD,-1.25)
	turn_bone("head_x",Vector3.RIGHT,sin(time*1.4)*0.018)
	if moving:
		var walk = sin(time*8)
		turn_bone("leftthigh",Vector3.RIGHT,walk*0.22)
		turn_bone("rightthigh",Vector3.RIGHT,-walk*0.22)
		turn_flipper("l",Vector3.RIGHT,walk*0.12)
		turn_flipper("r",Vector3.RIGHT,-walk*0.12)
		turn_bone("spine_01_x",Vector3.FORWARD,walk*0.035)
		torso.position.y += absf(walk)*0.025
	book.visible = task_kind == "study" and task_id not in ["sport","martial","combat","stage"]
	props.visible = task_kind == "work" and task_id not in ["carry","guard","idol","library","code"]
	if task_kind != "":
		if book.visible or task_id in ["library","code"]:
			book.visible = true
			turn_bone("head_x",Vector3.RIGHT,0.1+sin(time*2.5)*0.035)
			turn_flipper("l",Vector3.RIGHT,-0.45)
			turn_flipper("r",Vector3.RIGHT,-0.45)
		elif task_id in ["sport","martial","combat","idol","stage"]:
			turn_flipper("l",Vector3.FORWARD,-0.5+sin(time*3)*0.25)
			turn_flipper("r",Vector3.FORWARD,0.5-sin(time*3)*0.25)
			turn_bone("spine_01_x",Vector3.FORWARD,sin(time*3)*0.07)
			torso.position.y += absf(sin(time*3))*0.035
		else:
			turn_flipper("l",Vector3.FORWARD,-0.35+sin(time*3)*0.2)
			turn_bone("head_x",Vector3.FORWARD,sin(time*2)*0.045)
	var elapsed = action_total-action_left
	var wave = sin(elapsed*10)
	var envelope = sin(PI*clampf(action_left/action_total,0,1))
	var expression_envelope = smoothstep(0.0,0.12,elapsed)*smoothstep(0.0,0.18,action_left)
	match action:
		"head":
			turn_bone("head_x",Vector3.FORWARD,envelope*0.16)
			set_expression("face_Base_obj_morph0",envelope)
			set_expression("face_NoOutline_obj_morph0",envelope)
		"look": turn_bone("head_x",Vector3.UP,sin(elapsed*2.4)*0.25*envelope)
		"yawn":
			turn_bone("head_x",Vector3.RIGHT,-envelope*0.1)
			close_eyes(envelope*0.9)
			open_mouth(envelope*0.85)
		"pet":
			turn_bone("head_x",Vector3.FORWARD,sin(time*4.5)*0.08)
			turn_bone("spine_01_x",Vector3.FORWARD,sin(time*4.5)*0.025)
			close_eyes(expression_envelope)
			smile(0.4*expression_envelope)
		"belly":
			turn_bone("spine_01_x",Vector3.RIGHT,-envelope*0.12)
			turn_bone("head_x",Vector3.RIGHT,-envelope*0.08)
			turn_flipper("l",Vector3.FORWARD,-envelope*0.4)
			turn_flipper("r",Vector3.FORWARD,envelope*0.4)
			close_eyes(expression_envelope)
			smile(envelope)
		"wing_l": turn_flipper("r",Vector3.FORWARD,envelope*(1.2+wave*0.2))
		"wing_r": turn_flipper("l",Vector3.FORWARD,-envelope*(1.2+wave*0.2))
		"hop","feet","celebrate":
			torso.position.y = absf(sin(elapsed*5))*0.23*envelope
			turn_bone("leftthigh",Vector3.RIGHT,-envelope*0.15)
			turn_bone("rightthigh",Vector3.RIGHT,-envelope*0.15)
			turn_flipper("l",Vector3.FORWARD,-envelope*0.6)
			turn_flipper("r",Vector3.FORWARD,envelope*0.6)
			smile(envelope*0.8)
		"feed":
			turn_bone("head_x",Vector3.RIGHT,wave*0.045)
			open_mouth(absf(wave)*0.6)
		"wash":
			turn_bone("spine_01_x",Vector3.FORWARD,wave*0.045)
			close_eyes(expression_envelope)
			smile(0.35*expression_envelope)
		"angry":
			turn_bone("head_x",Vector3.UP,wave*0.12*envelope)
			set_expression("face_Base_obj_morph6",envelope*0.8)
		"spin":
			torso.rotation.y = (1-action_left/action_total)*TAU
			turn_flipper("l",Vector3.FORWARD,-envelope*0.5)
			turn_flipper("r",Vector3.FORWARD,envelope*0.5)
			smile(envelope)
		"dance":
			turn_bone("spine_01_x",Vector3.FORWARD,wave*0.08*envelope)
			turn_bone("head_x",Vector3.FORWARD,-wave*0.05*envelope)
			turn_flipper("l",Vector3.FORWARD,-0.6-wave*0.3)
			turn_flipper("r",Vector3.FORWARD,0.6-wave*0.3)
			turn_bone("leftthigh",Vector3.RIGHT,wave*0.2)
			turn_bone("rightthigh",Vector3.RIGHT,-wave*0.2)
			smile(0.8)
	var blink = idle_blink(delta)
	if blink > 0: close_eyes(blink)
	if low_mood and action.is_empty():turn_bone("head_x",Vector3.RIGHT,0.06)
	torso.rotation.y += view_yaw
	for name_ in expression_weights: face.set_blend_shape_value(morphs[name_],expression_weights[name_])
	skeleton.force_update_all_bone_transforms()
	for i in bubbles.size():
		var bubble = bubbles[i]
		bubble.visible = action == "wash"
		if bubble.visible:
			var a = float(i)*2.4+time
			bubble.position = Vector3(sin(a)*0.72,0.4+fmod(time*0.65+i*0.19,2),cos(a)*0.55)
			bubble.scale = Vector3.ONE*(0.09+0.04*sin(i*3.1))
