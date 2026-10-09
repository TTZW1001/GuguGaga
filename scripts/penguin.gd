extends Node3D
signal idle_seen
var torso: Node3D
var head: Node3D
var left: Node3D
var right: Node3D
var foot_l: Node3D
var foot_r: Node3D
var eyes: Array[Node3D] = []
var beak: Node3D
var hat: Node3D
var neck: Node3D
var book: Node3D
var props: Node3D
var bubbles: Array[Node3D] = []
var dark: StandardMaterial3D
var time = 0.0
var action = ""
var action_left = 0.0
var action_total = 1.0
var idle_left = 6.0
var target = Vector3.ZERO
var task_kind = ""
var task_id = ""
var equipped = ""
var low_mood = false
var gold = false
var rng = RandomNumberGenerator.new()

func material(hex: String, rough: float = 0.8) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = rough
	return m

func orb(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 32
	mesh.rings = 16
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.scale = size
	parent.add_child(m)
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m

func pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func hit(parent: Node3D, part: String, pos: Vector3, size: Vector3):
	var area = Area3D.new()
	area.set_meta("part",part)
	area.position = pos
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	collision.scale = size
	area.add_child(collision)
	parent.add_child(area)

func _ready():
	rng.randomize()
	dark = material("354f59",0.65)
	var cream = material("fff5df")
	var orange = material("e9a951",0.6)
	var black = material("222f35",0.3)
	torso = pivot(self,Vector3.ZERO)
	orb(torso,Vector3(0,0.99,0),Vector3(1.32,1.62,1.0),dark)
	orb(torso,Vector3(0,0.94,0.345),Vector3(1.07,1.29,0.48),cream)
	head = pivot(torso,Vector3(0,1.85,0.025))
	orb(head,Vector3.ZERO,Vector3(1.31,1.2,1.08),dark)
	for side in [-1,1]:
		orb(head,Vector3(side*0.255,-0.03,0.395),Vector3(0.67,0.78,0.35),cream)
		var eye = pivot(head,Vector3(side*0.235,0.055,0.575))
		orb(eye,Vector3.ZERO,Vector3(0.115,0.17,0.075),black)
		orb(eye,Vector3(-0.018,0.035,0.035),Vector3(0.035,0.045,0.02),cream)
		eyes.append(eye)
		orb(head,Vector3(side*0.39,-0.14,0.531),Vector3(0.19,0.087,0.035),material("e9b4a3"))
	beak = orb(head,Vector3(0,-0.13,0.62),Vector3(0.26,0.15,0.25),orange)
	orb(head,Vector3(-0.065,0.54,-0.035),Vector3(0.17,0.29,0.2),dark).rotation.z = -0.35
	orb(head,Vector3(0.07,0.52,-0.04),Vector3(0.13,0.23,0.18),dark).rotation.z = 0.5
	left = pivot(torso,Vector3(-0.58,1.24,0))
	right = pivot(torso,Vector3(0.58,1.24,0))
	orb(left,Vector3(-0.13,-0.32,0),Vector3(0.3,0.85,0.38),dark).rotation.z = -0.28
	orb(right,Vector3(0.13,-0.32,0),Vector3(0.3,0.85,0.38),dark).rotation.z = 0.28
	foot_l = pivot(torso,Vector3(-0.3,0.16,0.13))
	foot_r = pivot(torso,Vector3(0.3,0.16,0.13))
	orb(foot_l,Vector3(0,0,0.08),Vector3(0.43,0.2,0.63),orange)
	orb(foot_r,Vector3(0,0,0.08),Vector3(0.43,0.2,0.63),orange)
	hit(head,"head",Vector3(0,0,0.12),Vector3(1.28,1.15,1.12))
	hit(torso,"belly",Vector3(0,0.95,0.2),Vector3(1.16,1.35,1.0))
	hit(left,"wing_l",Vector3(-0.14,-0.32,0),Vector3(0.35,0.88,0.43))
	hit(right,"wing_r",Vector3(0.14,-0.32,0),Vector3(0.35,0.88,0.43))
	hit(foot_l,"feet",Vector3(0,0,0.1),Vector3(0.46,0.25,0.65))
	hit(foot_r,"feet",Vector3(0,0,0.1),Vector3(0.46,0.25,0.65))
	hat = pivot(head,Vector3.ZERO)
	neck = pivot(torso,Vector3.ZERO)
	book = pivot(torso,Vector3(0,1.0,0.65))
	box(book,Vector3(-0.2,0,0),Vector3(0.39,0.5,0.06),material("698d82")).rotation.y = -0.25
	box(book,Vector3(0.2,0,0),Vector3(0.39,0.5,0.06),material("698d82")).rotation.y = 0.25
	box(book,Vector3(0,0,0.04),Vector3(0.7,0.43,0.025),cream)
	book.rotation.x = -0.35
	props = pivot(torso,Vector3(0.6,0.9,0.45))
	box(props,Vector3.ZERO,Vector3(0.34,0.5,0.025),cream)
	for i in 3: box(props,Vector3(0,0.12-i*0.09,0.02),Vector3(0.21,0.018,0.01),material("98b3a2"))
	for i in 12:
		var b = orb(torso,Vector3.ZERO,Vector3.ONE*0.13,material("d1e8e5",0.15))
		b.visible = false
		bubbles.append(b)
	book.visible = false
	props.visible = false

func perform(name_: String, duration: float = 1.8):
	action = name_
	action_left = duration
	action_total = duration

func update_task(kind: String, id: String):
	task_kind = kind
	task_id = id
	if not kind.is_empty(): target = Vector3.ZERO

func update_accessories(head_id: String, neck_id: String, golden: bool):
	var key = head_id+neck_id+str(golden)
	if key == equipped: return
	equipped = key
	dark.albedo_color = Color("c5a25a" if golden else "354f59")
	for n in hat.get_children(): n.queue_free()
	for n in neck.get_children(): n.queue_free()
	var red = material("c97764")
	var yellow = material("e5b649",0.35)
	if head_id == "redhat":
		orb(hat,Vector3(0,0.49,0),Vector3(1.03,0.28,0.83),red)
		orb(hat,Vector3(0,0.64,-0.02),Vector3(0.73,0.38,0.65),red)
		orb(hat,Vector3(0.23,0.84,0),Vector3.ONE*0.15,material("fff5df"))
	if head_id == "graduate":
		box(hat,Vector3(0,0.57,0),Vector3(1.1,0.07,0.95),material("30404a"))
		box(hat,Vector3(0,0.43,0),Vector3(0.6,0.23,0.5),material("30404a"))
		box(hat,Vector3(0.5,0.41,0.35),Vector3(0.035,0.34,0.035),yellow)
	if head_id == "crown":
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 0.36
		cylinder.bottom_radius = 0.34
		cylinder.height = 0.2
		var mesh = MeshInstance3D.new()
		mesh.mesh = cylinder
		mesh.material_override = yellow
		mesh.position.y = 0.57
		hat.add_child(mesh)
		for i in 5:
			var a = TAU*i/5.0
			orb(hat,Vector3(cos(a)*0.32,0.73,sin(a)*0.32),Vector3(0.12,0.3,0.12),yellow)
	if neck_id == "scarf":
		var scarf_mesh = TorusMesh.new()
		scarf_mesh.inner_radius = 0.37
		scarf_mesh.outer_radius = 0.56
		var scarf_ring = MeshInstance3D.new()
		scarf_ring.mesh = scarf_mesh
		scarf_ring.material_override = material("bd7665")
		scarf_ring.position = Vector3(0,1.43,0)
		neck.add_child(scarf_ring)
		box(neck,Vector3(0.26,1.17,0.56),Vector3(0.23,0.51,0.07),material("bd7665")).rotation.z = 0.15
	if neck_id == "bow":
		for side in [-1,1]: orb(neck,Vector3(side*0.16,1.44,0.52),Vector3(0.32,0.24,0.12),red).rotation.z = side*0.25
		orb(neck,Vector3(0,1.44,0.59),Vector3.ONE*0.15,red)
	if neck_id == "tie":
		orb(neck,Vector3(0,1.43,0.54),Vector3.ONE*0.17,material("6e90a2"))
		box(neck,Vector3(0,1.17,0.6),Vector3(0.16,0.41,0.06),material("6e90a2"))

func _process(delta: float):
	time += delta
	action_left = maxf(0,action_left-delta)
	if action_left == 0: action = ""
	idle_left -= delta
	if idle_left <= 0 and task_kind.is_empty() and action.is_empty():
		idle_left = rng.randf_range(7,13)
		var pick = rng.randi_range(0,4)
		if pick < 2: target = Vector3(rng.randf_range(-1.15,1.15),0,rng.randf_range(-0.15,0.2))
		else:
			perform(["look","yawn","hop"][pick-2],2.4)
			idle_seen.emit()
	var moving = position.distance_to(target) > 0.025 and action.is_empty()
	if moving:
		position = position.move_toward(target,delta*0.22)
		rotation.y = lerp_angle(rotation.y,0.45*signf(target.x-position.x),delta*3)
	else: rotation.y = lerp_angle(rotation.y,0,delta*2)
	torso.rotation = Vector3.ZERO
	torso.position.y = sin(time*2)*0.012
	torso.scale = Vector3.ONE
	head.rotation = Vector3(sin(time*1.3)*0.025,0,0)
	left.rotation = Vector3(0,0,-0.05+sin(time*1.8)*0.035)
	right.rotation = Vector3(0,0,0.05-sin(time*1.8)*0.035)
	foot_l.rotation.x = 0
	foot_r.rotation.x = 0
	beak.scale.y = 0.15
	var blink = fmod(time,4.7) < 0.13
	for e in eyes: e.scale.y = 0.12 if blink else 1.0
	book.visible = task_kind == "study"
	props.visible = task_kind == "work"
	if moving:
		var walk = sin(time*9)
		torso.rotation.z = walk*0.055
		torso.position.y += absf(walk)*0.035
		foot_l.rotation.x = walk*0.3
		foot_r.rotation.x = -walk*0.3
		left.rotation.x = -walk*0.13
		right.rotation.x = walk*0.13
	if task_kind == "study":
		head.rotation.x = 0.12+sin(time*2.4)*0.08
		left.rotation.x = -0.5
		right.rotation.x = -0.5
		if task_id in ["sport","martial","combat"]:
			book.visible = false
			left.rotation.z = -0.7+sin(time*3)*0.3
			right.rotation.z = 0.7-sin(time*3)*0.3
			torso.position.y += absf(sin(time*3))*0.07
	if task_kind == "work":
		left.rotation.z = -0.3
		right.rotation.z = 0.4+sin(time*3)*0.25
		head.rotation.z = sin(time*1.8)*0.06
		if task_id in ["carry","guard"]:
			props.rotation.z = sin(time*3)*0.2
			torso.rotation.x = sin(time*3)*0.07
		elif task_id in ["library","code"]:
			book.visible = true
			props.visible = false
			head.rotation.x = 0.15+sin(time*3)*0.06
	var wave = sin((action_total-action_left)*12)
	var envelope = sin(PI*clampf(action_left/action_total,0,1))
	match action:
		"head","look":
			head.rotation.z = envelope*0.2
			head.rotation.y = sin(time*3)*0.2*envelope
		"pet":
			head.rotation.z = sin(time*5)*0.12
			for e in eyes: e.scale.y = 0.12
			torso.rotation.z = sin(time*5)*0.045
		"belly":
			torso.rotation.x = -envelope*0.16
			torso.scale.y = 1.0+wave*0.025*envelope
			left.rotation.z = -0.6*envelope
			right.rotation.z = 0.6*envelope
			for e in eyes: e.scale.y = 0.25
		"wing_l": left.rotation.z = -envelope*(1.25+wave*0.25)
		"wing_r": right.rotation.z = envelope*(1.25+wave*0.25)
		"hop","feet","celebrate":
			torso.position.y = absf(sin((action_total-action_left)*5))*0.27*envelope
			left.rotation.z = -envelope*0.8
			right.rotation.z = envelope*0.8
			foot_l.rotation.x = -envelope*0.3
			foot_r.rotation.x = -envelope*0.3
		"feed":
			head.rotation.x = 0.1+wave*0.05
			beak.scale.y = 0.15+absf(wave)*0.12
			left.rotation.x = -envelope*0.8
		"wash":
			torso.rotation.z = sin(time*8)*0.06*envelope
			for e in eyes: e.scale.y = 0.15
		"angry":
			head.rotation.y = sin(time*10)*0.12*envelope
			left.rotation.z = -0.5*envelope
			right.rotation.z = 0.5*envelope
		"yawn":
			head.rotation.x = -envelope*0.2
			beak.scale.y = 0.15+envelope*0.2
			for e in eyes: e.scale.y = 0.2
		"spin":
			torso.rotation.y = (1.0-action_left/action_total)*TAU
			left.rotation.z = -0.8*envelope
			right.rotation.z = 0.8*envelope
		"dance":
			torso.rotation.z = sin(time*6)*0.14*envelope
			left.rotation.z = -0.6-wave*0.35
			right.rotation.z = 0.6-wave*0.35
			foot_l.rotation.x = wave*0.25
			foot_r.rotation.x = -wave*0.25
	if low_mood and action.is_empty(): head.rotation.x += 0.09
	for i in bubbles.size():
		var b = bubbles[i]
		b.visible = action == "wash"
		if b.visible:
			var a = float(i)*2.4+time
			b.position = Vector3(sin(a)*0.85,0.4+fmod(time*0.65+i*0.19,2.1),cos(a)*0.6)
			b.scale = Vector3.ONE*(0.09+0.07*sin(i*3.1))
