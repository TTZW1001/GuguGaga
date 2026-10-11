extends "res://scripts/rig_penguin.gd"
# User-provided Tomori/penguin model. The source is a T pose with facial morphs;
# all body motion below is applied to individual bones, never to a rigid mesh.
const SCALE = 2.5
const LOOK_DURATION = 4.8
const YAWN_DURATION = 4.6
const HEAD_TILT_DURATION = 2.6
const BELLY_WIGGLE_DURATION = 3.2
const ANGRY_DURATION = 4.8
const FEED_DURATION = 5.4
const SPIN_DURATION = 4.6
const CARE_BLEND_IN = 0.45
const CARE_BLEND_OUT = 0.55
const FOOD_WIDTHS = {"bread":0.074,"fish":0.077,"steak":0.074,"snack":0.060}
const REST_WING_CLEARANCE = 0.25
const REST_WING_OFFSET = 0.03
var look_direction = 1.0
var head_tilt_direction = 1.0
var face: MeshInstance3D
var morphs: Dictionary = {}
var expression_weights: Dictionary = {}
var blink_wait = 3.0
var blink_elapsed = -1.0
var red_hood: Node3D
var graduation_cap: Node3D
var small_crown: Node3D
var red_scarf: Node3D
var red_bow: Node3D
var blue_tie: Node3D
var elegant_suit: Node3D
var feed_food_id = "fish"
var food_root: Node3D
var food_models: Dictionary = {}
var mouth_in_head = Vector3.ZERO
var wash_task_transition = false
const BASKETBALL_RADIUS = 0.064
const BASKETBALL_BEAT = 1.1
var basketball: Node3D
var basketball_blend = 0.0
var basketball_clock = 0.0
const MARTIAL_DURATION = 12.0
# Penguin adaptation: feet stay close enough for the short thigh/foot rig.
# time, body yaw, hip offset, left/right foot offsets, foot yaws, wing targets.
const MARTIAL_POSES = [
	# Ready, bow stance punch, kick and opposite punch.
	[0.0,0.0,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector2.ZERO,Vector3(0.25,0.36,0.15),Vector3(-0.25,0.36,0.15)],
	[0.7,0.22,Vector3(0.01,-0.015,0),Vector3(0.055,0,0),Vector3.ZERO,Vector2(0.25,0),Vector3(0.28,0.46,0.18),Vector3(-0.25,0.36,0.15)],
	[1.4,0.40,Vector3(0.025,-0.015,0.018),Vector3(0.060,0,0.065),Vector3.ZERO,Vector2(0.40,0),Vector3(0.25,0.36,0.15),Vector3(-0.13,0.49,0.275)],
	[2.1,0.40,Vector3(0.03,-0.01,0.025),Vector3(0.060,0,0.065),Vector3(0,0.075,0.12),Vector2(0.40,0),Vector3(0.13,0.49,0.275),Vector3(-0.25,0.36,0.15)],
	# Horse stance block/punch, short crossed step and covering strike.
	[2.6,0.0,Vector3(0,-0.025,0.02),Vector3(0.060,0,0.065),Vector3(-0.055,0,0.04),Vector2(0.40,-0.10),Vector3(0.20,0.61,0.17),Vector3(-0.25,0.36,0.15)],
	[3.3,0.0,Vector3(0,-0.025,0.015),Vector3(0.055,0,0),Vector3(-0.055,0,0.04),Vector2(0,-0.10),Vector3(0.20,0.61,0.17),Vector3(-0.13,0.49,0.275)],
	[4.1,-0.40,Vector3(-0.025,-0.020,-0.005),Vector3(-0.070,0,-0.07),Vector3(-0.055,0,0.04),Vector2(-0.30,-0.10),Vector3(0.25,0.36,0.15),Vector3(-0.20,0.60,0.16)],
	[4.8,-0.40,Vector3(-0.025,-0.020,-0.005),Vector3(-0.070,0,-0.07),Vector3(-0.055,0,0.04),Vector2(-0.30,-0.10),Vector3(0.13,0.48,0.275),Vector3(-0.13,0.46,0.25)],
	# Knee lift/palm, shallow low stance, empty stance/upward palm, then close.
	[5.5,-0.10,Vector3(-0.035,0,0.02),Vector3(-0.015,0.085,0.045),Vector3(-0.055,0,0.04),Vector2(0,-0.10),Vector3(0.25,0.36,0.15),Vector3(-0.10,0.58,0.23)],
	[6.3,0.24,Vector3(0.015,-0.028,0.01),Vector3(0.080,0,0.015),Vector3(-0.055,0,0.04),Vector2(0.20,-0.10),Vector3(0.37,0.28,0.06),Vector3(-0.25,0.36,0.15)],
	[7.1,0.24,Vector3(0.025,-0.025,0.01),Vector3(0.080,0,0.015),Vector3(-0.055,0,0.04),Vector2(0.20,-0.10),Vector3(0.37,0.28,0.06),Vector3(-0.25,0.36,0.15)],
	[7.9,0.0,Vector3(0.02,-0.010,0.02),Vector3(0.080,0,0.015),Vector3(-0.010,0.012,0.10),Vector2(0.20,0),Vector3(0.38,0.37,-0.015),Vector3(-0.12,0.56,0.235)],
	[8.7,0.0,Vector3(0.02,-0.010,0.02),Vector3(0.080,0,0.015),Vector3(-0.010,0.012,0.10),Vector2(0.20,0),Vector3(0.38,0.37,-0.015),Vector3(-0.12,0.56,0.235)],
	[9.5,0.0,Vector3(0,-0.012,0),Vector3(0.080,0,0.015),Vector3.ZERO,Vector2(0.20,0),Vector3(0.25,0.36,0.15),Vector3(-0.25,0.36,0.15)],
	[10.3,0.0,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector2.ZERO,Vector3(0.25,0.36,0.15),Vector3(-0.25,0.36,0.15)],
	[12.0,0.0,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector2.ZERO,Vector3(0.25,0.36,0.15),Vector3(-0.25,0.36,0.15)],
]
var martial_blend = 0.0
var martial_clock = 0.0
const COMBAT_BEAT = 0.95
var combat_root: Node3D
var combat_hanger: Node3D
var combat_blend = 0.0
var combat_clock = 0.0
var combat_hit = -1
var bag_angle = Vector2.ZERO
var bag_velocity = Vector2.ZERO
var reading_blend = 0.0
const ABACUS_BEAT = 1.75
const ABACUS_COLUMNS = [1,5,2,4,0,6]
const ABACUS_COUNTS = [1,2,3,1,2,4]
var abacus: Node3D
var abacus_beads: Array[Node3D] = []
var math_blend = 0.0
var math_clock = 0.0
const SCIENCE_DURATION = 8.5
const SCIENCE_SCAN = [[0.0,0.0],[1.2,-1.0],[2.8,-1.0],[4.4,1.0],[6.1,1.0],[7.6,0.0],[8.5,0.0]]
var magnifier: Node3D
var science_blend = 0.0
var science_clock = 0.0
const MANNERS_DURATION = 6.4
var manners_blend = 0.0
var manners_clock = 0.0
const MUSIC_PHRASE = 4.8
const MUSIC_NOTE_BEAT = 0.72
const MUSIC_NOTE_LIFE = 2.2
var microphone: Node3D
var music_blend = 0.0
var music_clock = 0.0
var music_notes: Array[Node3D] = []
var music_note_step = -1
const LYRICS_DURATION = 7.2
const LYRIC_SUPPORT = Vector3(-0.16,-0.015,0.002)
const LYRIC_PEN_TIP = 0.115
var lyric_notebook: Node3D
var lyric_pen: Node3D
var lyric_ink: Array[ImmediateMesh] = []
var lyrics_blend = 0.0
var lyrics_clock = 0.0
const FLYER_DURATION = 4.8
const FLYER_STACK_GRIP = Vector3(0,0.055,-0.035)
const FLYER_SINGLE_GRIP = Vector3(0,-0.04,-0.010)
const FLYER_WING_TIP = Vector3(0.026235,0.057372,-0.003949)
var flyer_stack: Node3D
var flyer_single: Node3D
var flyer_blend = 0.0
var flyer_clock = 0.0
const CARRY_CYCLE = 1.6
var carry_box: Node3D
var carry_blend = 0.0
var carry_clock = 0.0
var guard_blend = 0.0
var guard_clock = 0.0

const GUIDE_CYCLE = 14.8
const GUIDE_STEP = 1.4
var guide_flag: Node3D
var guide_blend = 0.0
var guide_clock = 0.0
var guide_step_clock = 0.0

func guide_march_amount() -> float:
	var phase = fmod(guide_clock,GUIDE_CYCLE)
	return 1.0-smoothstep(7.0,7.8,phase)*(1.0-smoothstep(11.8,12.6,phase))

func ensure_guide_flag():
	if is_instance_valid(guide_flag): return
	guide_flag = load("res://assets/work/guide_flag.glb").instantiate()
	skeleton.add_child(guide_flag)
	guide_flag.visible = false

func lead_tour(weight: float):
	var phase = fmod(guide_clock,GUIDE_CYCLE)
	var march = guide_march_amount()
	var stride = sin(TAU*guide_step_clock/GUIDE_STEP)
	var glance = smoothstep(8.0,9.2,phase)*(1.0-smoothstep(10.6,11.7,phase))
	var direction = 1.0 if int(guide_clock/GUIDE_CYCLE)%2 == 0 else -1.0
	var turn = Basis(Vector3.UP,0.55*direction*glance*weight)
	var feet = [skeleton.find_bone("leftfoot"),skeleton.find_bone("rightfoot")]
	var resting: Array[Transform3D] = []
	for foot in feet: resting.append(skeleton.get_bone_global_pose(foot))
	var breathing = torso.position.y
	var body_offset = Vector3(-0.005*stride*march,0.004*stride*stride*march,0.004)*SCALE*weight
	body_offset.y += breathing*(1.0-0.7*weight)
	torso.position = Basis(Vector3.UP,view_yaw)*body_offset
	torso.rotation.y = 0.55*direction*glance*weight
	for i in 2:
		var lift = maxf(0.0,stride if i == 0 else -stride)*march
		var target = resting[i]
		target.origin += Vector3(0,0.030*lift,0.012*lift)*weight
		target.origin.y += breathing/SCALE*(1.0-weight)
		target.origin = turn.inverse()*(target.origin-body_offset/SCALE)
		target.basis = turn.inverse()*Basis(Vector3.RIGHT,-0.10*lift*weight)*target.basis
		aim_wing_segment(skeleton.find_bone("leftthigh" if i == 0 else "rightthigh"),feet[i],target.origin)
		var local = skeleton.get_bone_global_pose(skeleton.get_bone_parent(feet[i])).affine_inverse()*target
		skeleton.set_bone_pose_position(feet[i],local.origin)
		skeleton.set_bone_pose_rotation(feet[i],local.basis.orthonormalized().get_rotation_quaternion())
	turn_bone("head_x",Vector3.UP,1.05*direction*glance*weight)
	turn_bone("head_x",Vector3.RIGHT,0.025*glance*weight)
	turn_flipper("l",Vector3.RIGHT,0.12*stride*march*weight)
	smile(0.18*weight)
	var raise = smoothstep(0.15,0.95,guide_clock)*weight
	if raise>0.00001:
		var grip = Vector3(-0.29-0.05*sin(PI*raise),0.70,0.17)
		hold_food_with_wing("r",grip,raise)
	var show = smoothstep(0.65,1.0,raise)
	guide_flag.scale = Vector3.ONE*maxf(show,0.001)
	guide_flag.rotation = Vector3(0,-0.12,-0.025*stride*march*weight)
	guide_flag.visible = show>0.001
	attach_guide_flag()

func attach_guide_flag():
	guide_flag.position = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*Vector3(-FLYER_WING_TIP.x,FLYER_WING_TIP.y,FLYER_WING_TIP.z)

# Grip the lower receiver cup so the confirmed suit cuff stays below the handset.
const PHONE_GRIP = Vector3(-0.10,0.015,0)
const PHONE_HOME = Vector3(-0.055,0.465,0.310)
var phone_root: Node3D
var phone_receiver: Node3D
var phone_cord: ImmediateMesh
# Call timing has its own RNG; frozen actions and natural blinks keep their stream.
var phone_rng = RandomNumberGenerator.new()
var phone_in_head = Transform3D.IDENTITY
var phone_blend = 0.0
var phone_clock = 0.0
var phone_wait = 1.0
var phone_call_length = 8.0
var phone_cycle = 12.0
var phone_call_number = 0
var phone_held = false

func ensure_telephone():
	if is_instance_valid(phone_root): return
	phone_root = load("res://assets/work/telephone_station.glb").instantiate()
	add_child(phone_root)
	phone_receiver = load("res://assets/work/telephone_receiver.glb").instantiate()
	skeleton.add_child(phone_receiver)
	phone_cord = ImmediateMesh.new()
	var wire = MeshInstance3D.new()
	wire.mesh = phone_cord
	wire.material_override = material("594b40")
	phone_root.add_child(wire)
	var axis = Vector3(-0.50,0.40,-0.77).normalized()
	var outward = Vector3(-0.85,-0.05,0.52)
	outward = (outward-axis*axis.dot(outward)).normalized()
	var basis = Basis(axis,outward,axis.cross(outward))
	# Pivot around the confirmed earpiece position, lifting the lower cup to the mouth.
	var ear = Vector3(-0.20950519,0.67326134,0.04578487)
	var held = Transform3D(basis,ear-basis*Vector3(0.10,-0.018,0))
	phone_in_head = skeleton.get_bone_global_rest(skeleton.find_bone("head_x")).affine_inverse()*held
	phone_root.visible = false
	phone_receiver.visible = false

func next_phone_call():
	phone_clock = 0.0
	phone_wait = phone_rng.randf_range(0.7,1.6)
	phone_call_length = phone_rng.randf_range(6.0,10.0)
	phone_cycle = phone_wait+1.65+phone_call_length+2.05
	phone_call_number += 1

func answer_telephone(weight: float):
	var start = phone_wait+1.65
	var finish = start+phone_call_length
	var approach = smoothstep(phone_wait,phone_wait+0.45,phone_clock)*(1.0-smoothstep(finish+1.2,finish+1.65,phone_clock))
	var pickup = smoothstep(phone_wait+0.45,start,phone_clock)*(1.0-smoothstep(finish,finish+1.2,phone_clock))
	var call_phase = clampf((phone_clock-start)/phone_call_length,0,1)
	var speaking = smoothstep(0.22,0.25,call_phase)*(1.0-smoothstep(0.49,0.52,call_phase))+smoothstep(0.72,0.75,call_phase)*(1.0-smoothstep(0.97,1.0,call_phase))
	var listening = (1.0-speaking)*smoothstep(start,start+0.2,phone_clock)*(1.0-smoothstep(finish-0.15,finish,phone_clock))
	turn_bone("head_x",Vector3.RIGHT,(0.018*sin(phone_clock*3.6)*listening+0.012*sin(phone_clock*2.2)*speaking)*pickup*weight)
	turn_bone("head_x",Vector3.FORWARD,-0.025*pickup*weight)
	smile(0.18*weight)
	open_mouth((0.10+0.38*(0.5-0.5*cos(phone_clock*TAU*2.3)))*speaking*pickup*weight)
	var show = smoothstep(0.35,1.0,weight)
	phone_root.rotation = Vector3(0,view_yaw,0)
	phone_root.scale = Vector3.ONE*SCALE*maxf(show,0.001)
	phone_root.position = Basis(Vector3.UP,view_yaw)*Vector3(0,0,0.405*(1.0-show)*SCALE)
	phone_root.visible = show>0.001
	var home = Transform3D(Basis.IDENTITY,PHONE_HOME-Vector3(0,torso.position.y/SCALE,0))
	var held = skeleton.get_bone_global_pose(skeleton.find_bone("head_x"))*phone_in_head
	# The hood covers the ear; hold the receiver outside its front edge.
	if is_instance_valid(red_hood) and red_hood.visible: held.origin += Vector3(-0.005,0.005,0.08)
	var pose = home.interpolate_with(held,pickup*weight)
	pose.origin.z += 0.05*sin(PI*pickup)*weight
	pose.origin.x -= 0.06*sin(PI*pickup)*weight
	var reach = approach*weight
	if reach>0.00001:
		var grip = pose*PHONE_GRIP
		grip.x -= 0.07*sin(PI*reach)
		aim_phone_tip("r",grip,reach)
	phone_receiver.quaternion = pose.basis.get_rotation_quaternion()
	phone_receiver.scale = Vector3.ONE*maxf(show,0.001)
	phone_receiver.position = pose.origin
	phone_receiver.visible = show>0.001
	phone_held = approach>=0.999 and weight>0.001
	attach_phone_receiver()

func attach_phone_receiver():
	if not phone_held: return
	var tip = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*Vector3(-FLYER_WING_TIP.x,FLYER_WING_TIP.y,FLYER_WING_TIP.z)
	phone_receiver.position = tip-phone_receiver.basis*PHONE_GRIP

func update_phone_cord():
	phone_cord.clear_surfaces()
	if not phone_root.visible: return
	var begin = Vector3(-0.165,0.407,0.340)
	var end = phone_root.to_local(phone_receiver.to_global(Vector3(-0.10,-0.006,0.025)))
	var points: Array[Vector3] = []
	for i in 65:
		var t = i/64.0
		var envelope = sin(PI*t)
		var point = begin.lerp(end,t)+Vector3(0,-0.045*envelope,0.025*envelope)
		point += Vector3(0,cos(t*TAU*10)*0.005,sin(t*TAU*10)*0.005)*envelope
		points.append(point)
	phone_cord.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		var direction = (points[i+1]-points[i]).normalized()
		var u = direction.cross(Vector3.RIGHT).normalized()
		if u.length_squared()<0.1: u = direction.cross(Vector3.UP).normalized()
		var v = direction.cross(u).normalized()
		for j in 6:
			var n1 = u*cos(j*TAU/6.0)+v*sin(j*TAU/6.0)
			var n2 = u*cos((j+1)*TAU/6.0)+v*sin((j+1)*TAU/6.0)
			for vertex in [[points[i]+n1*0.0015,n1],[points[i+1]+n1*0.0015,n1],[points[i+1]+n2*0.0015,n2],[points[i]+n1*0.0015,n1],[points[i+1]+n2*0.0015,n2],[points[i]+n2*0.0015,n2]]:
				phone_cord.surface_set_normal(vertex[1])
				phone_cord.surface_add_vertex(vertex[0])
	phone_cord.surface_end()

const CODE_CYCLE = 8.4
const CODE_TAP_BEAT = 0.36
var laptop_root: Node3D
var laptop_keys: Array[Node3D] = []
var laptop_cursor: Node3D
var code_blend = 0.0
var code_clock = 0.0

func ensure_laptop():
	if is_instance_valid(laptop_root): return
	laptop_root = load("res://assets/work/laptop_station.glb").instantiate()
	add_child(laptop_root)
	for name_ in ["Key_0_10","Key_0_1"]: laptop_keys.append(laptop_root.find_child(name_,true,false))
	laptop_cursor = laptop_root.find_child("TextCursor",true,false)
	laptop_root.visible = false

func type_on_laptop(weight: float):
	var phase = fmod(code_clock,CODE_CYCLE)
	var pause = smoothstep(4.6,5.1,phase)*(1.0-smoothstep(6.4,6.9,phase))
	var typing = 1.0-pause
	var show = smoothstep(0.35,1.0,weight)
	laptop_root.rotation = Vector3(0,view_yaw,0)
	laptop_root.scale = Vector3.ONE*SCALE*maxf(show,0.001)
	laptop_root.position = Basis(Vector3.UP,view_yaw)*Vector3(0,0,0.405*(1.0-show)*SCALE)
	laptop_root.visible = show>0.001
	# A short pause raises the eye-line from the keyboard to the display.
	turn_bone("head_x",Vector3.RIGHT,(0.11-0.075*pause+0.008*sin(TAU*code_clock/CODE_CYCLE))*weight)
	smile(0.10*weight)
	for i in 2:
		var side = "l" if i == 0 else "r"
		var sign_ = 1.0 if i == 0 else -1.0
		var lift = 0.5+0.5*cos(TAU*code_clock/CODE_TAP_BEAT+i*PI)
		var height = 0.405+typing*0.020*lift+pause*0.006
		var target = Vector3(sign_*0.12,height,0.300)
		target.y -= torso.position.y/SCALE
		target.x += sign_*0.07*sin(PI*weight)
		if weight>0.00001: aim_proof_tip(side,target,weight)
		# The tip presses a real key; both keys return fully during pauses.
		laptop_keys[i].position.y = 0.400-0.002*typing*(1.0-smoothstep(0.0,0.28,lift))
	laptop_cursor.visible = fmod(code_clock,1.0)<0.55

const PROOF_CYCLE = 9.6
const PROOF_GRIP = Vector3(0,0.045,0)
var proof_root: Node3D
var proof_leaf: Node3D
var proof_mark: Node3D
var proof_stamp: Node3D
var proof_blend = 0.0
var proof_clock = 0.0

func ensure_proof_tools():
	if is_instance_valid(proof_root): return
	proof_root = load("res://assets/work/proof_desk.glb").instantiate()
	add_child(proof_root)
	proof_leaf = load("res://assets/work/proof_leaf.glb").instantiate()
	proof_mark = load("res://assets/work/proof_mark.glb").instantiate()
	proof_root.add_child(proof_leaf)
	proof_root.add_child(proof_mark)
	proof_stamp = load("res://assets/work/proof_stamp.glb").instantiate()
	skeleton.add_child(proof_stamp)
	proof_root.visible = false
	proof_stamp.visible = false

func aim_proof_tip(side: String, target: Vector3, weight: float):
	# Solve for the visible distal tip, rather than stopping at the hand joint.
	# Only the independent wing chain moves; the shared chest shoulder stays put.
	var arm = skeleton.find_bone("arm_stretch_"+side)
	var elbow = skeleton.find_bone("forearm_stretch_"+side)
	var original_arm = skeleton.get_bone_pose_rotation(arm)
	var original_elbow = skeleton.get_bone_pose_rotation(elbow)
	var hand = skeleton.find_bone("hand_"+side)
	var tip = FLYER_WING_TIP*Vector3(1 if side == "l" else -1,1,1)
	var joint_target = target-Vector3(0,0.025,0.05)
	for iteration in 5:
		skeleton.set_bone_pose_rotation(arm,original_arm)
		skeleton.set_bone_pose_rotation(elbow,original_elbow)
		hold_food_with_wing(side,joint_target,1.0)
		joint_target += target-skeleton.get_bone_global_pose(hand)*tip
	skeleton.set_bone_pose_rotation(arm,original_arm)
	skeleton.set_bone_pose_rotation(elbow,original_elbow)
	hold_food_with_wing(side,joint_target,weight)

func proofread_and_stamp(weight: float):
	var phase = fmod(proof_clock,PROOF_CYCLE)
	var page = smoothstep(0.6,1.9,phase)
	var show = smoothstep(0.35,1.0,weight)
	proof_root.rotation = Vector3(0,view_yaw,0)
	proof_root.scale = Vector3.ONE*SCALE*maxf(show,0.001)
	proof_root.position = Basis(Vector3.UP,view_yaw)*Vector3(0,0,0.42*(1.0-show)*SCALE)
	proof_root.visible = show>0.001
	proof_leaf.position = Vector3(0,0.401,0.40)
	proof_leaf.rotation = Vector3(0,0,PI*page)
	proof_leaf.visible = phase>=0.6 and phase<1.9
	proof_mark.position = Vector3(-0.105,0.4005,0.335)
	proof_mark.visible = phase>=5.62
	# Read between the two deliberate hand actions, with a small eye-line scan.
	turn_bone("head_x",Vector3.RIGHT,(0.16+0.015*sin(phase*1.1))*weight)
	turn_bone("head_x",Vector3.UP,0.045*sin(phase*1.5)*weight)
	smile(0.10*weight)
	var turn_contact = smoothstep(0.2,0.6,phase)*(1.0-smoothstep(0.92,1.35,phase))
	var page_point = Vector3(0,0.401,0.40)+Basis(Vector3.BACK,PI*minf(page,0.40))*Vector3(0.12,0.004,-0.075)
	var left = Vector3(0.205,0.42,0.285).lerp(page_point,turn_contact)
	var lift = smoothstep(4.5,5.1,phase)*(1.0-smoothstep(5.15,5.62,phase))
	var press = smoothstep(5.15,5.62,phase)*(1.0-smoothstep(5.85,6.55,phase))
	var right = Vector3(-0.105,0.495+0.055*lift-0.0495*press,0.335)
	for side in ["l","r"]:
		var target = left if side == "l" else right
		# Use the stable desk frame, compensating for idle torso breathing.
		target.y -= torso.position.y/SCALE
		target.x += (1 if side == "l" else -1)*0.07*sin(PI*weight)
		if weight>0.00001: aim_proof_tip(side,target,weight)
	var stamp_show = smoothstep(0.70,1.0,weight)
	proof_stamp.visible = stamp_show>0.001
	proof_stamp.scale = Vector3.ONE*maxf(stamp_show,0.001)
	proof_stamp.quaternion = Quaternion.IDENTITY
	attach_proof_stamp()

func attach_proof_stamp():
	var tip = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*Vector3(-FLYER_WING_TIP.x,FLYER_WING_TIP.y,FLYER_WING_TIP.z)
	proof_stamp.position = tip-proof_stamp.basis*PROOF_GRIP

func salute_and_stand(weight: float):
	var salute = smoothstep(0.45,1.35,guard_clock)
	# Hold the salute throughout duty; the task blend lowers the wing only
	# for interactions or when work ends. Keep the shared shoulder at rest.
	turn_bone("head_x",Vector3.RIGHT,-0.018*weight)
	smile(0.10*weight)
	var reach = salute*weight
	if reach>0.00001:
		var target = Vector3(-0.20-0.06*sin(PI*reach),0.71,0.16)
		hold_food_with_wing("r",target,reach)

func carry_and_step(weight: float):
	var phase = TAU*carry_clock/CARRY_CYCLE
	var stride = sin(phase)
	var feet = [skeleton.find_bone("leftfoot"),skeleton.find_bone("rightfoot")]
	var resting: Array[Transform3D] = []
	for foot in feet: resting.append(skeleton.get_bone_global_pose(foot))
	var breathing = torso.position.y
	var body_offset = Vector3(-0.006*stride,0.004*stride*stride,0.008)*SCALE*weight
	body_offset.y += breathing*(1.0-weight)
	torso.position = Basis(Vector3.UP,view_yaw)*body_offset
	for i in 2:
		var lift = maxf(0.0,stride if i == 0 else -stride)
		var target = resting[i]
		target.origin += Vector3(0,0.032*lift,0.012*lift)*weight
		target.origin.y += breathing/SCALE*(1.0-weight)
		target.origin -= body_offset/SCALE
		target.basis = Basis(Vector3.RIGHT,-0.10*lift*weight)*target.basis
		aim_wing_segment(skeleton.find_bone("leftthigh" if i == 0 else "rightthigh"),feet[i],target.origin)
		var local = skeleton.get_bone_global_pose(skeleton.get_bone_parent(feet[i])).affine_inverse()*target
		skeleton.set_bone_pose_position(feet[i],local.origin)
		skeleton.set_bone_pose_rotation(feet[i],local.basis.orthonormalized().get_rotation_quaternion())
	turn_bone("spine_01_x",Vector3.RIGHT,0.035*weight)
	turn_bone("head_x",Vector3.RIGHT,-0.035*weight)
	smile(0.16*weight)
	for side in ["l","r"]:
		var sign_ = 1.0 if side == "l" else -1.0
		var grip = Vector3(sign_*(0.16+0.08*sin(PI*weight)),0.37,0.30)
		if weight>0.00001: hold_food_with_wing(side,grip,weight)
	var show = smoothstep(0.75,1.0,weight)
	carry_box.scale = Vector3.ONE*maxf(show,0.001)
	carry_box.quaternion = Quaternion.IDENTITY
	carry_box.visible = show>0.001
	attach_carry_box()

func attach_carry_box():
	var left = skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))*FLYER_WING_TIP
	var right = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*Vector3(-FLYER_WING_TIP.x,FLYER_WING_TIP.y,FLYER_WING_TIP.z)
	# Scale around the supported underside, keeping the rear face in front of
	# the belly while entering, leaving or temporarily putting away the parcel.
	carry_box.position = (left+right)*0.5+Vector3(0,0.014+0.10*carry_box.scale.y,0.110)

func ensure_flyers():
	if is_instance_valid(flyer_stack): return
	flyer_stack = load("res://assets/work/flyer_stack.glb").instantiate()
	flyer_single = load("res://assets/work/flyer_single.glb").instantiate()
	for paper in [flyer_stack,flyer_single]:
		skeleton.add_child(paper)
		paper.visible = false

func hand_out_flyer(weight: float):
	var phase = fmod(flyer_clock,FLYER_DURATION)
	var offer = smoothstep(0.5,1.65,phase)*(1.0-smoothstep(2.75,4.15,phase))
	turn_bone("spine_01_x",Vector3.RIGHT,0.025*offer*weight)
	turn_bone("head_x",Vector3.UP,-0.12*offer*weight)
	smile(0.22*weight)
	# Both wing tips stay in front of the belly. Aim at these full targets
	# throughout the entry/return blend, independent of the shrinking props.
	var support = Vector3(0.19,0.49,0.25)
	var deliver = Vector3(-0.17,0.40,0.19).lerp(Vector3(-0.235,0.455,0.275),offer)
	support.x += 0.08*sin(PI*weight)
	deliver.x -= 0.08*sin(PI*weight)
	if weight>0.00001:
		hold_food_with_wing("l",support,weight)
		hold_food_with_wing("r",deliver,weight)
	var show = smoothstep(0.65,1.0,weight)
	# Paper faces upward: the raised wing supports the underside of the pile.
	flyer_stack.quaternion = (Basis(Vector3.UP,-0.10)*Basis(Vector3.RIGHT,-PI/2.0)).get_rotation_quaternion()
	flyer_single.quaternion = (Basis(Vector3.UP,-0.18-0.18*offer)*Basis(Vector3.RIGHT,-0.12+0.08*offer)*Basis(Vector3.BACK,0.10-0.12*offer)).get_rotation_quaternion()
	for paper in [flyer_stack,flyer_single]:
		paper.scale = Vector3.ONE*maxf(show,0.001)
		paper.visible = show>0.001
	attach_flyers()

func attach_flyers():
	# The visible wing tip extends past the hand joint. These local points
	# were measured from the fully hand-weighted distal vertices in the model.
	var left = skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))*FLYER_WING_TIP
	var right = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*Vector3(-FLYER_WING_TIP.x,FLYER_WING_TIP.y,FLYER_WING_TIP.z)
	flyer_stack.position = left-flyer_stack.basis*FLYER_STACK_GRIP
	flyer_stack.position += Basis(flyer_stack.quaternion)*Vector3(0,0,0.012*(1.0-flyer_stack.scale.x))
	flyer_single.position = right-flyer_single.basis*FLYER_SINGLE_GRIP
	# Retain a small gap while the paper scales away during task transitions.
	flyer_single.position += Basis(flyer_single.quaternion)*Vector3(0,0,0.006*(1.0-flyer_single.scale.x))

func ensure_lyric_tools():
	if is_instance_valid(lyric_notebook): return
	lyric_notebook = load("res://assets/study/lyric_notebook.glb").instantiate()
	lyric_pen = load("res://assets/study/lyric_pencil.glb").instantiate()
	for prop in [lyric_notebook,lyric_pen]:
		skeleton.add_child(prop)
		prop.visible = false
	var ink = material("53675f")
	for line in 3:
		var stroke = MeshInstance3D.new()
		stroke.mesh = ImmediateMesh.new()
		stroke.material_override = ink
		stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lyric_notebook.add_child(stroke)
		lyric_ink.append(stroke.mesh)

func lyric_point(line: int, progress: float) -> Vector3:
	return Vector3(lerpf(0.095,0.005,progress),0.035-line*0.03+0.003*sin(progress*TAU*3.0),0.010)

func draw_lyric_line(mesh: ImmediateMesh, line: int, progress: float):
	mesh.clear_surfaces()
	if progress<=0.0001: return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var start = float(i)/24.0
		if start>=progress: break
		var a = lyric_point(line,start)-Vector3(0,0,0.001)
		var b = lyric_point(line,minf(float(i+1)/24.0,progress))-Vector3(0,0,0.001)
		var edge = Vector3(0,0.0007,0)
		# Decreasing X keeps the visible triangle normal towards the reader (+Z).
		for vertex in [a-edge,b-edge,b+edge,a-edge,b+edge,a+edge]:
			mesh.surface_set_normal(Vector3.BACK)
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()

func write_lyrics(weight: float):
	var phase = fmod(lyrics_clock,LYRICS_DURATION)
	var thought = smoothstep(4.2,4.75,phase)*(1.0-smoothstep(5.85,6.8,phase))
	turn_bone("head_x",Vector3.RIGHT,lerpf(0.22,0.035,thought)*weight)
	turn_bone("head_x",Vector3.UP,-0.09*thought*weight)
	smile(0.16*weight)
	var show = smoothstep(0.65,1.0,weight)
	var frame = Transform3D(Basis(Vector3.RIGHT,1.0)*Basis(Vector3.UP,PI),Vector3(-0.015,0.405,0.255))
	var support = frame*LYRIC_SUPPORT+Vector3(0.08*sin(PI*weight),0,0)
	if weight>0.00001: hold_food_with_wing("l",support,weight)
	lyric_notebook.quaternion = frame.basis.get_rotation_quaternion()
	lyric_notebook.scale = Vector3.ONE*maxf(show,0.001)
	lyric_notebook.position = skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin-lyric_notebook.basis*LYRIC_SUPPORT
	lyric_notebook.visible = show>0.001
	var point = lyric_point(2,1.0)
	var lift = 0.055*thought
	if phase<4.2:
		var line = mini(int(phase/1.4),2)
		var beat = fmod(phase,1.4)
		point = lyric_point(line,smoothstep(0.1,1.02,beat))
		if beat>1.08:
			var change = smoothstep(1.08,1.4,beat)
			lift = 0.018*sin(PI*change)
			if line<2: point = point.lerp(lyric_point(line+1,0),change)
	else:
		point = point.lerp(lyric_point(0,0),smoothstep(6.15,7.15,phase))
	# Aim at the full writing pose while blending the wings. The shrinking
	# notebook follows the supporting wing during entry/exit; using that
	# partial transform here would send the pen across the belly to that wing.
	var tip = frame*(point+Vector3(0,0,lift))
	var pen_up = Vector3(-0.70,0.65,-0.30).normalized()
	var grip = tip+pen_up*LYRIC_PEN_TIP-Vector3(0.08*sin(PI*weight),0,0)
	if weight>0.00001: hold_food_with_wing("r",grip,weight)
	lyric_pen.quaternion = Quaternion(Vector3.UP,pen_up)
	lyric_pen.scale = Vector3.ONE*maxf(show,0.001)
	lyric_pen.position = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).origin
	lyric_pen.visible = show>0.001
	for line in 3:
		var written = 1.0 if lyrics_clock>=LYRICS_DURATION else smoothstep(0.1,1.02,phase-line*1.4)
		draw_lyric_line(lyric_ink[line],line,written)

func attach_lyric_tools():
	# Short interactions may add a final bone pose after the task blend. Keep
	# both props attached to the rendered wing tips during those transitions too.
	lyric_notebook.position = skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin-lyric_notebook.basis*LYRIC_SUPPORT
	lyric_pen.position = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).origin

func ensure_music_props():
	if is_instance_valid(microphone): return
	microphone = load("res://assets/study/microphone.glb").instantiate()
	skeleton.add_child(microphone)
	microphone.visible = false
	# A fixed pool of five small geometric notes, with no texture/font dependency.
	for i in 5:
		var note = Node3D.new()
		skeleton.add_child(note)
		var ink = material(["c69042","bd7581","548f8a"][i%3])
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		orb(note,Vector3(-0.007,0,0),Vector3(0.027,0.017,0.006),ink).rotation.z = 0.3
		box(note,Vector3(0.004,0.027,0),Vector3(0.0045,0.052,0.005),ink)
		box(note,Vector3(0.015,0.047,0),Vector3(0.024,0.006,0.005),ink).rotation.z = -0.4
		box(note,Vector3(0.025,0.039,0),Vector3(0.006,0.018,0.005),ink).rotation.z = 0.25
		note.set_meta("ink",ink)
		note.set_meta("born",-1.0)
		note.visible = false
		for mesh in note.get_children(): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		music_notes.append(note)

func sing_with_microphone(weight: float):
	var phase = fmod(music_clock,MUSIC_PHRASE)
	var phrase = smoothstep(0.0,0.18,phase)*(1.0-smoothstep(3.65,3.95,phase))
	var syllable = 0.5-0.5*cos(music_clock*TAU*2.1+0.22*sin(music_clock*TAU*0.7))
	var sway = sin(music_clock*TAU/3.2)*weight
	turn_bone("spine_01_x",Vector3.FORWARD,0.018*sway)
	turn_bone("head_x",Vector3.FORWARD,-0.035*sway)
	turn_bone("head_x",Vector3.RIGHT,0.035*phrase*weight)
	var mouth = skeleton.get_bone_global_pose(skeleton.find_bone("head_x"))*mouth_in_head
	var mic_basis = Basis(Vector3.RIGHT,-0.45)*Basis(Vector3.BACK,0.50)
	var grip = mouth+Vector3(0.035,-0.005,0.075)-mic_basis*Vector3(0,0.105,0)
	grip.x += 0.08*sin(PI*weight)
	if weight>0.00001: hold_food_with_wing("l",grip,weight)
	var hand = skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin
	var elbow = skeleton.get_bone_global_pose(skeleton.find_bone("forearm_stretch_l")).origin
	microphone.position = hand+(hand-elbow).normalized()*0.012
	microphone.quaternion = mic_basis.get_rotation_quaternion()
	var show = smoothstep(0.65,1.0,weight)
	microphone.scale = Vector3.ONE*maxf(show,0.001)
	microphone.visible = show>0.001
	smile(0.25*weight)
	open_mouth((0.08+0.65*syllable)*phrase*weight)

func update_music_notes(weight: float):
	var step = int(music_clock/MUSIC_NOTE_BEAT)
	if weight<0.99 or not action.is_empty():
		for note in music_notes:
			note.visible = false
			note.set_meta("born",-1.0)
		music_note_step = step
		return
	if step != music_note_step:
		music_note_step = step
		# A short gap between phrases also stops note emission for a breath.
		if fmod(music_clock,MUSIC_PHRASE)<3.65:
			var note = music_notes[step%music_notes.size()]
			note.set_meta("born",music_clock)
			var mouth = skeleton.get_bone_global_pose(skeleton.find_bone("head_x"))*mouth_in_head
			note.set_meta("origin",mouth+Vector3(0,0.012,0.05))
			note.set_meta("side",-1.0 if step%2 == 0 else 1.0)
			note.set_meta("flight",Vector3((-1.0 if step%2 == 0 else 1.0)*(0.16+0.04*(step%3)),0.18+0.035*(step%3),0.10))
	for note in music_notes:
		var born = float(note.get_meta("born"))
		var age = (music_clock-born)/MUSIC_NOTE_LIFE
		note.visible = born>=0 and age<1.0
		if not note.visible: continue
		note.position = note.get_meta("origin")+note.get_meta("flight")*age
		# Move sideways before rising past eye height, keeping the face readable.
		note.position.x += float(note.get_meta("side"))*0.16*sin(age*PI*0.5)
		var tilt = 0.12*sin(age*PI*2.0+born)
		var camera = get_viewport().get_camera_3d()
		# Face each viewport's camera as a complete note, including side previews.
		var facing = skeleton.global_basis.orthonormalized().inverse()*camera.global_basis.orthonormalized() if is_instance_valid(camera) else Basis(Vector3.UP,-view_yaw)
		note.quaternion = (facing*Basis(Vector3.BACK,tilt)).get_rotation_quaternion()
		note.scale = Vector3.ONE*lerpf(0.22,1.35,smoothstep(0,1,age))
		var ink = note.get_meta("ink") as StandardMaterial3D
		ink.albedo_color.a = smoothstep(0.0,0.12,age)*(1.0-smoothstep(0.7,1.0,age))

func practice_manners(weight: float):
	var phase = fmod(manners_clock,MANNERS_DURATION)
	var greeting = smoothstep(0.35,1.0,phase)*(1.0-smoothstep(2.15,2.75,phase))
	var wave_time = clampf((phase-1.0)/1.15,0,1)
	var wave = sin(TAU*2.0*wave_time)*sin(PI*wave_time)
	# Raise a straight wing from its independent hinge, give two small waves,
	# then lower it completely before bowing. The chest/neck shoulders stay still.
	turn_flipper("l",Vector3.FORWARD,(-1.65+0.13*wave)*greeting*weight)
	turn_flipper("l",Vector3.RIGHT,0.07*wave*greeting*weight)
	var bow = smoothstep(3.05,3.95,phase)*(1.0-smoothstep(4.45,5.5,phase))*weight
	turn_bone("spine_01_x",Vector3.RIGHT,0.30*bow)
	turn_bone("head_x",Vector3.RIGHT,0.14*bow)
	turn_bone("head_x",Vector3.FORWARD,-0.035*greeting*weight)
	smile(0.55*weight)

func scan_with_magnifier(weight: float):
	var phase = fmod(science_clock,SCIENCE_DURATION)
	var scan = 0.0
	for i in SCIENCE_SCAN.size()-1:
		var start = SCIENCE_SCAN[i]
		var finish = SCIENCE_SCAN[i+1]
		if phase<=finish[0]:
			scan = lerpf(start[1],finish[1],smoothstep(start[0],finish[0],phase))
			break
	# A single independent wing reaches forward; keep the other wing resting.
	# The grip travels outside the belly during lifting and lowering as well.
	var grip = Vector3(0.13+0.065*scan,0.535-0.008*absf(scan),0.235+0.008*(1.0-absf(scan)))
	grip.x += 0.08*sin(PI*weight)
	if weight>0.00001: hold_food_with_wing("l",grip,weight)
	var hand = skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin
	var elbow = skeleton.get_bone_global_pose(skeleton.find_bone("forearm_stretch_l")).origin
	# Follow the actual wing tip, including the blended entrance and return.
	magnifier.position = hand+(hand-elbow).normalized()*0.016
	magnifier.rotation = Vector3(0,0.10+0.24*scan,0.32-0.40*scan)
	var show = smoothstep(0.65,1.0,weight)
	magnifier.scale = Vector3.ONE*maxf(show,0.001)
	magnifier.visible = show>0.001
	turn_bone("head_x",Vector3.UP,(0.10+0.24*scan)*weight)
	turn_bone("head_x",Vector3.RIGHT,(0.12+0.045*(1.0-scan))*weight)
	turn_bone("head_x",Vector3.FORWARD,-0.035*scan*weight)

func count_with_abacus(weight: float):
	# Keep the frame in front of the belly. One wing supports its edge while
	# the other reaches around to the reader's side and slides a group of beads.
	abacus.position = Vector3(0,0.425,0.27)
	abacus.rotation.x = 0.55
	var show = smoothstep(0.65,1.0,weight)
	abacus.scale = Vector3.ONE*maxf(show,0.001)
	abacus.visible = show>0.001
	var step = int(math_clock/ABACUS_BEAT)%12
	var phase = fmod(math_clock,ABACUS_BEAT)
	var slide = smoothstep(0.60,0.98,phase)
	for col in 7:
		var order = ABACUS_COLUMNS.find(col)
		var engaged = 0.0
		if order>=0:
			if step == order: engaged = slide
			elif step == order+6: engaged = 1.0-slide
			elif step>order and step<order+6: engaged = 1.0
		for bead in 5:
			var raised = engaged if order>=0 and bead<ABACUS_COUNTS[order] else 0.0
			abacus_beads[col*7+bead].position.y = -0.016-0.022*bead+0.024*raised
	var active_col = ABACUS_COLUMNS[step%6]
	var active_left = active_col>3
	var reach = smoothstep(0.16,0.48,phase)*(1.0-smoothstep(1.10,1.53,phase))
	var frame = Transform3D(Basis(Vector3.RIGHT,0.55),abacus.position)
	for side in ["l","r"]:
		var sign_ = 1.0 if side == "l" else -1.0
		var grip = frame*Vector3(sign_*0.205,-0.045,-0.010)
		if (side == "l") == active_left:
			var bead_position = abacus_beads[active_col*7].position
			var touch = frame*(bead_position+Vector3(sign_*0.016,-0.004,-0.025))
			grip = grip.lerp(touch,reach)
		grip.x += sign_*0.08*sin(PI*weight)
		if weight>0.00001: hold_food_with_wing(side,grip,weight)
	turn_bone("head_x",Vector3.RIGHT,(0.105+sin(time*1.8)*0.012)*weight)
	turn_bone("head_x",Vector3.UP,(0.045 if active_left else -0.045)*reach*weight)

func hold_reading_book(weight: float):
	# Keep the familiar book and reading nod. Reach for its outer edges instead
	# of rotating a straight wing through the belly. Coordinates here are in
	# torso units; the independent wing IK works in model units.
	book.position = Vector3(0,1.0,0.68)
	# Tilt the top away from the reader and face the pages towards the face.
	# Apply the tilt in torso space, then turn the original front-facing book.
	var reading_basis = Basis(Vector3.RIGHT,0.60)*Basis(Vector3.UP,PI)
	book.quaternion = reading_basis.get_rotation_quaternion()
	var show = smoothstep(0.65,1.0,weight)
	book.scale = Vector3.ONE*maxf(show,0.001)
	book.visible = show>0.001
	turn_bone("head_x",Vector3.RIGHT,(0.1+sin(time*2.5)*0.035)*weight)
	for side in ["l","r"]:
		var sign_ = 1.0 if side == "l" else -1.0
		var grip = (Transform3D(reading_basis,book.position)*Vector3(-sign_*0.40,-0.06,0.035))/SCALE
		# Let the elbows travel outside the belly during lift and return, too.
		grip.x += sign_*0.08*sin(PI*weight)
		if weight>0.00001: hold_food_with_wing(side,grip,weight)

func _ready():
	rng.randomize()
	phone_rng.randomize()
	blink_wait = rng.randf_range(2.8,5.6)
	torso = pivot(self,Vector3.ZERO)
	model = load("res://assets/tomori/penguin.glb").instantiate()
	model.scale = Vector3.ONE*SCALE
	torso.add_child(model)
	find_parts(model)
	mouth_in_head = skeleton.get_bone_global_pose(skeleton.find_bone("head_x")).affine_inverse()*Vector3(0,0.578,0.135)
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
	# Retain the saved head/neck choices underneath this complete skin. The old
	# gold flag remains the save-compatible Lv.20 unlock for the elegant suit.
	if golden:
		head_id = "none"
		neck_id = "none"
		if not is_instance_valid(elegant_suit):
			elegant_suit = load_skinned_accessory("res://assets/accessories/elegant_suit.glb","ElegantSuit")
	if is_instance_valid(elegant_suit): elegant_suit.visible = golden
	super.update_accessories(head_id,neck_id,false)
	if is_instance_valid(red_hood): red_hood.visible = head_id == "redhat"
	if is_instance_valid(graduation_cap): graduation_cap.visible = head_id == "graduate"
	if is_instance_valid(small_crown): small_crown.visible = head_id == "crown"
	if is_instance_valid(red_scarf): red_scarf.visible = neck_id == "scarf"
	if is_instance_valid(red_bow): red_bow.visible = neck_id == "bow"
	if is_instance_valid(blue_tie): blue_tie.visible = neck_id == "tie"
	for mat in body_materials: mat.albedo_color = Color.WHITE

func build_red_hat(_red: StandardMaterial3D):
	if is_instance_valid(red_hood): return
	# Reuse the character skeleton: the hood follows the head, while its lower
	# cloth blends through neck to spine instead of rotating as a rigid hat.
	red_hood = load_skinned_accessory("res://assets/accessories/red_hood.glb","RedHood")

func build_graduate_hat(_yellow: StandardMaterial3D):
	if is_instance_valid(graduation_cap): return
	graduation_cap = load_skinned_accessory("res://assets/accessories/graduation_cap.glb","GraduationCap")

func build_crown(_yellow: StandardMaterial3D):
	if is_instance_valid(small_crown): return
	small_crown = load_skinned_accessory("res://assets/accessories/small_crown.glb","SmallCrown")

func build_scarf():
	if is_instance_valid(red_scarf): return
	red_scarf = load_skinned_accessory("res://assets/accessories/red_scarf.glb","RedScarf")

func build_bow(_red: StandardMaterial3D):
	if is_instance_valid(red_bow): return
	red_bow = load_skinned_accessory("res://assets/accessories/red_bow.glb","RedBow")

func build_tie():
	if is_instance_valid(blue_tie): return
	blue_tie = load_skinned_accessory("res://assets/accessories/blue_tie.glb","BlueTie")

func load_skinned_accessory(path: String, node_name: String) -> Node3D:
	var source = load(path).instantiate()
	model.add_child(source)
	var source_skeleton = source.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var accessory = Node3D.new()
	accessory.name = node_name
	skeleton.add_child(accessory)
	for mesh in source.find_children("*","MeshInstance3D",true,false):
		var relative = source_skeleton.global_transform.affine_inverse()*mesh.global_transform
		var skin = mesh.skin.duplicate() as Skin
		for i in skin.get_bind_count():
			var bone_name = skin.get_bind_name(i)
			if bone_name.is_empty(): bone_name = source_skeleton.get_bone_name(skin.get_bind_bone(i))
			skin.set_bind_name(i,bone_name)
		mesh.reparent(accessory,false)
		mesh.transform = relative
		mesh.skin = skin
		mesh.skeleton = mesh.get_path_to(skeleton)
	source.free()
	return accessory

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

func frown(amount: float):
	# Reverse a small part of the smile to lower the corners. The old morph6
	# purses and crumples the whole mouth instead of giving a simple frown.
	expression_weights["face_Base_obj_morph3"] = -0.35*clampf(amount,0,1)

func turn_flipper(side: String, axis: Vector3, angle: float):
	# Shoulder bones also skin the chest and neck: animate the flipper hinge.
	# Pose rotations use parent space; the shoulder's rolled axes differ on each
	# side, so convert the intended model-space axis instead of assuming local Z.
	var bone_name = "arm_stretch_"+side
	var idx = skeleton.find_bone(bone_name)
	var parent = skeleton.get_bone_parent(idx)
	var axis_in_parent = skeleton.get_bone_global_pose(parent).basis.inverse()*axis
	turn_bone(bone_name,axis_in_parent.normalized(),angle)

func perform(name_: String, duration: float = 1.8):
	wash_task_transition = name_ == "wash" and not task_kind.is_empty()
	if name_ == "look":
		# Choose once per glance; do not oscillate through both directions.
		look_direction = -1.0 if rng.randf() < 0.5 else 1.0
		duration = maxf(duration,LOOK_DURATION)
	elif name_ == "yawn":
		duration = maxf(duration,YAWN_DURATION)
	elif name_ == "head":
		head_tilt_direction = -1.0 if rng.randf() < 0.5 else 1.0
		duration = maxf(duration,HEAD_TILT_DURATION)
	elif name_ == "belly":
		duration = maxf(duration,BELLY_WIGGLE_DURATION)
	elif name_ == "angry":
		# Rapid clicks already counted by main must not rewind this reaction before
		# the first hop. Other interactions can still replace it normally.
		if action == "angry" and action_left > 0.0: return
		duration = maxf(duration,ANGRY_DURATION)
	elif name_ == "feed":
		ensure_food_model()
		duration = maxf(duration,FEED_DURATION)
	elif name_ == "spin":
		duration = maxf(duration,SPIN_DURATION)
	elif wash_task_transition:
		duration += CARE_BLEND_IN+CARE_BLEND_OUT
	super.perform(name_,duration)

func feed_item(item_id: String):
	feed_food_id = item_id if FOOD_WIDTHS.has(item_id) else "fish"
	perform("feed",2.4)

func update_task(kind: String, id: String):
	if kind == "work" and id == "idol" and (task_kind != kind or task_id != id):
		ensure_guide_flag()
		guide_clock = 0.0
		guide_step_clock = 0.0
	if kind == "work" and id == "waiter" and (task_kind != kind or task_id != id):
		ensure_telephone()
		phone_call_number = 0
		next_phone_call()
	if kind == "work" and id == "code" and (task_kind != kind or task_id != id):
		ensure_laptop()
		code_clock = 0.0
	if kind == "work" and id == "library" and (task_kind != kind or task_id != id):
		ensure_proof_tools()
		proof_clock = 0.0
	if kind == "work" and id == "guard" and (task_kind != kind or task_id != id): guard_clock = 0.0
	if kind == "work" and id == "carry" and (task_kind != kind or task_id != id):
		if not is_instance_valid(carry_box):
			carry_box = load("res://assets/work/carry_box.glb").instantiate()
			skeleton.add_child(carry_box)
			carry_box.visible = false
		carry_clock = 0.0
	if kind == "work" and id == "flyer" and (task_kind != kind or task_id != id):
		ensure_flyers()
		flyer_clock = 0.0
	if kind == "study" and id == "stage" and (task_kind != kind or task_id != id):
		ensure_lyric_tools()
		lyrics_clock = 0.0
	if kind == "study" and id == "music" and (task_kind != kind or task_id != id):
		ensure_music_props()
		music_clock = 0.0
		music_note_step = -1
		for note in music_notes: note.set_meta("born",-1.0)
	if kind == "study" and id == "manners" and (task_kind != kind or task_id != id): manners_clock = 0.0
	if kind == "study" and id == "science" and (task_kind != kind or task_id != id):
		if not is_instance_valid(magnifier):
			magnifier = load("res://assets/study/magnifier.glb").instantiate()
			skeleton.add_child(magnifier)
			magnifier.visible = false
		science_clock = 0.0
	if kind == "study" and id == "math" and (task_kind != kind or task_id != id):
		if not is_instance_valid(abacus):
			abacus = load("res://assets/study/abacus.glb").instantiate()
			skeleton.add_child(abacus)
			abacus.visible = false
			for col in 7:
				for bead in 5: abacus_beads.append(abacus.find_child("Bead_%d_L%d"%[col,bead],true,false))
				for bead in 2: abacus_beads.append(abacus.find_child("Bead_%d_U%d"%[col,bead],true,false))
		math_clock = 0.0
	if kind == "study" and id == "combat" and (task_kind != kind or task_id != id):
		if not is_instance_valid(combat_root):
			combat_root = load("res://assets/sports/punching_bag.glb").instantiate()
			combat_root.name = "PunchingBag"
			add_child(combat_root)
			combat_hanger = combat_root.find_child("BagHanger",true,false)
			combat_root.visible = false
		combat_clock = 0.0
		combat_hit = -1
		bag_angle = Vector2.ZERO
		bag_velocity = Vector2.ZERO
	if kind == "study" and id == "martial" and (task_kind != kind or task_id != id): martial_clock = 0.0
	if kind == "study" and id == "sport" and (task_kind != kind or task_id != id):
		if not is_instance_valid(basketball):
			basketball = load("res://assets/sports/basketball.glb").instantiate()
			basketball.name = "Basketball"
			skeleton.add_child(basketball)
			basketball.visible = false
		basketball_clock = 0.0
	super.update_task(kind,id)

func update_training_bag(delta: float, training: bool):
	if not is_instance_valid(combat_root): return
	var hit = int(floor((combat_clock-0.42)/COMBAT_BEAT))
	if training and action.is_empty() and combat_blend>=1.0 and hit>combat_hit:
		combat_hit = hit
		# One impulse at contact, then a damped pendulum independent of the wings.
		bag_velocity += Vector2(-0.42,0.13*(1 if hit%2 == 0 else -1))
	var steps = maxi(1,int(ceil(minf(delta,0.1)*120)))
	var step = minf(delta,0.1)/steps
	for i in steps:
		bag_velocity += (-18.0*bag_angle-4.5*bag_velocity)*step
		bag_angle += bag_velocity*step
	combat_hanger.rotation = Vector3(bag_angle.x,0,bag_angle.y)

func punch_training_bag(weight: float):
	combat_root.rotation.y = view_yaw
	# Keep the bag's centre in front of the body while the prop appears or
	# disappears; scaling around the character origin would sweep it through us.
	combat_root.position = Basis(Vector3.UP,view_yaw)*Vector3(0,0,0.405*SCALE*(1.0-weight))
	combat_root.scale = Vector3.ONE*SCALE*maxf(weight,0.001)
	combat_root.visible = weight>0.001
	var beat = fposmod(combat_clock,COMBAT_BEAT)
	var side = 1.0 if int(floor(combat_clock/COMBAT_BEAT))%2 == 0 else -1.0
	var punch = smoothstep(0.18,0.42,beat)*(1.0-smoothstep(0.46,0.80,beat))
	var advance = smoothstep(0.08,0.32,beat)*(1.0-smoothstep(0.58,0.86,beat))
	var foot_lift = sin(PI*clampf((beat-0.08)/0.24,0,1)) if beat<0.45 else sin(PI*clampf((beat-0.58)/0.28,0,1))
	var response = weight*smoothstep(0.0,0.40,combat_clock)
	var feet = [skeleton.find_bone("leftfoot"),skeleton.find_bone("rightfoot")]
	var resting: Array[Transform3D] = []
	for foot in feet: resting.append(skeleton.get_bone_global_pose(foot))
	var hip = Vector3(side*0.008*punch,-0.012-0.005*punch,0.025+0.035*punch)*response
	var yaw = -side*0.10*punch*response
	var turn = Basis(Vector3.UP,yaw)
	var breathing = torso.position.y
	var body_offset = hip*SCALE+Vector3.UP*breathing
	torso.position = Basis(Vector3.UP,view_yaw)*body_offset
	torso.rotation.y = yaw
	for i in 2:
		var active = (i == 0 and side>0) or (i == 1 and side<0)
		var offset = Vector3(0.012 if i == 0 else -0.012,0,0.025 if i == 0 else -0.005)
		if active: offset += Vector3(0,0.014*foot_lift,0.022*advance)
		var target = resting[i]
		target.origin += offset*response
		target.origin.y += breathing/SCALE*(1.0-response)
		target.origin = turn.inverse()*(target.origin-body_offset/SCALE)
		target.basis = turn.inverse()*target.basis
		aim_wing_segment(skeleton.find_bone("leftthigh" if i == 0 else "rightthigh"),feet[i],target.origin)
		var local = skeleton.get_bone_global_pose(skeleton.get_bone_parent(feet[i])).affine_inverse()*target
		skeleton.set_bone_pose_position(feet[i],local.origin)
		skeleton.set_bone_pose_rotation(feet[i],local.basis.orthonormalized().get_rotation_quaternion())
	turn_bone("spine_01_x",Vector3.UP,-side*0.025*punch*response)
	turn_bone("head_x",Vector3.RIGHT,0.055*response)
	turn_bone("head_x",Vector3.UP,side*0.025*punch*response)
	for wing in ["l","r"]:
		var sign_ = 1.0 if wing == "l" else -1.0
		var guard = Vector3(sign_*0.24,0.46,0.24)
		# Aim at the actual moving bag surface; transform back to the body frame.
		var contact = combat_hanger.transform*Vector3(sign_*0.055,-0.575,-0.094)
		contact = turn.inverse()*(contact-body_offset/SCALE)
		var target = guard.lerp(contact,punch if sign_ == side else 0.0)
		# Keep the folding tip outside the belly while entering or returning from
		# care, then finish reaching inward only once the wing is lifted clear.
		target.x += sign_*0.08*sin(PI*response)
		if response>0.00001: hold_food_with_wing(wing,target,response)

func martial_routine(weight: float):
	var phase = fposmod(martial_clock,MARTIAL_DURATION)
	var index = 0
	while index<MARTIAL_POSES.size()-2 and phase>MARTIAL_POSES[index+1][0]: index += 1
	var a = MARTIAL_POSES[index]
	var b = MARTIAL_POSES[index+1]
	var progress = clampf((phase-a[0])/(b[0]-a[0]),0,1)
	# Arrive decisively, hold briefly, then move into the next technique.
	var blend = smoothstep(0.08,0.82,progress)
	var response = weight*smoothstep(0.0,0.55,phase)*(1.0-smoothstep(10.7,11.4,phase))
	var feet = [skeleton.find_bone("leftfoot"),skeleton.find_bone("rightfoot")]
	var resting: Array[Transform3D] = []
	for foot in feet: resting.append(skeleton.get_bone_global_pose(foot))
	var hip: Vector3 = a[2].lerp(b[2],blend)*response
	var yaw = lerpf(a[1],b[1],blend)*response
	var turn = Basis(Vector3.UP,yaw)
	var breathing = torso.position.y
	var body_offset = hip*SCALE+Vector3.UP*breathing
	torso.position = Basis(Vector3.UP,view_yaw)*body_offset
	torso.rotation.y = yaw
	for i in 2:
		var start: Vector3 = a[3+i]
		var finish: Vector3 = b[3+i]
		var offset = start.lerp(finish,blend)
		if start.distance_to(finish)>0.001 or absf(a[5][i]-b[5][i])>0.01:
			offset.y += 0.025*sin(PI*blend)
		var foot_yaw = lerpf(a[5][i],b[5][i],blend)*response
		var target = resting[i]
		target.origin += offset*response
		var toe_pitch = -0.40*smoothstep(0.03,0.07,offset.y)
		toe_pitch += 0.08*smoothstep(0.005,0.010,offset.y)*(1.0-smoothstep(0.02,0.04,offset.y))
		target.basis = Basis(Vector3.UP,foot_yaw)*Basis(Vector3.RIGHT,toe_pitch*response)*target.basis
		target.origin.y += breathing/SCALE*(1.0-response)
		target.origin = turn.inverse()*(target.origin-body_offset/SCALE)
		target.basis = turn.inverse()*target.basis
		var thigh = skeleton.find_bone("leftthigh" if i == 0 else "rightthigh")
		aim_wing_segment(thigh,feet[i],target.origin)
		var local = skeleton.get_bone_global_pose(skeleton.get_bone_parent(feet[i])).affine_inverse()*target
		skeleton.set_bone_pose_position(feet[i],local.origin)
		skeleton.set_bone_pose_rotation(feet[i],local.basis.orthonormalized().get_rotation_quaternion())
	turn_bone("spine_01_x",Vector3.UP,0.035*sin(phase*0.8)*response)
	turn_bone("head_x",Vector3.UP,-0.08*yaw)
	turn_bone("head_x",Vector3.RIGHT,0.025*sin(phase*1.8)*response)
	for i in 2:
		var target: Vector3 = a[6+i].lerp(b[6+i],blend)
		if response>0.00001: hold_food_with_wing("l" if i == 0 else "r",target,response)

func basketball_dribble(weight: float):
	var beat = fposmod(basketball_clock/BASKETBALL_BEAT,1.0)
	var angle = basketball_clock/BASKETBALL_BEAT*PI
	# Parabolic flights, a sharp ground rebound and zero vertical speed at each
	# hand. The crossover stays ahead of the belly and feet, in model space.
	var flight = 1.0-4.0*pow(beat if beat<0.5 else 1.0-beat,2)
	var ball = Vector3(0.14*cos(angle),BASKETBALL_RADIUS+0.006+(0.43-BASKETBALL_RADIUS-0.006)*flight,0.30)
	turn_bone("spine_01_x",Vector3.FORWARD,-0.025*cos(angle)*weight)
	turn_bone("spine_01_x",Vector3.UP,0.025*sin(angle)*weight)
	turn_bone("head_x",Vector3.RIGHT,(0.07+0.035*(1.0-flight))*weight)
	turn_bone("head_x",Vector3.UP,-0.05*cos(angle)*weight)
	for side in ["l","r"]:
		var sign_ = 1.0 if side == "l" else -1.0
		var contact = smoothstep(0.30,0.95,cos(angle)*sign_)
		var ready = Vector3(0.22*sign_,0.43,0.25)
		# Release the ball as it crosses inward; the pushing wing stays on its
		# own side instead of following the ball across the belly.
		var palm = Vector3(0.14*sign_,ball.y+0.055,ball.z-0.025)
		hold_food_with_wing(side,ready.lerp(palm,contact),weight)
	basketball.position = ball-Vector3.UP*torso.position.y/SCALE
	basketball.rotation = Vector3(basketball_clock*3.5,0,basketball_clock*1.3)
	basketball.scale = Vector3.ONE*maxf(weight,0.001)
	basketball.visible = weight>0.001

func ensure_food_model():
	if not is_instance_valid(food_root):
		food_root = Node3D.new()
		food_root.name = "HeldFood"
		skeleton.add_child(food_root)
	if not food_models.has(feed_food_id):
		var food = load("res://assets/food/"+feed_food_id+".glb").instantiate()
		food_root.add_child(food)
		food_models[feed_food_id] = food
	for id in food_models: food_models[id].visible = id == feed_food_id
	food_root.visible = false

func aim_wing_segment(bone: int, child: int, target: Vector3):
	var current = skeleton.get_bone_global_pose(bone)
	var direction = skeleton.get_bone_global_pose(child).origin-current.origin
	var desired = target-current.origin
	if direction.length_squared()<0.000001 or desired.length_squared()<0.000001: return
	var rotation = Basis(Quaternion(direction.normalized(),desired.normalized()))*current.basis
	var parent = skeleton.get_bone_parent(bone)
	var local_basis = skeleton.get_bone_global_pose(parent).basis.inverse()*rotation
	skeleton.set_bone_pose_rotation(bone,local_basis.orthonormalized().get_rotation_quaternion())

func hold_food_with_wing(side: String, target: Vector3, weight: float = 1.0):
	# Two-bone reach on the independent wing hinge and forearm. Shoulder roots
	# remain at rest so the reach cannot pinch the chest or neck.
	var arm = skeleton.find_bone("arm_stretch_"+side)
	var elbow = skeleton.find_bone("forearm_stretch_"+side)
	var hand = skeleton.find_bone("hand_"+side)
	var rest_arm = skeleton.get_bone_pose_rotation(arm)
	var rest_elbow = skeleton.get_bone_pose_rotation(elbow)
	var start = skeleton.get_bone_global_pose(arm).origin
	var upper = skeleton.get_bone_pose_position(elbow).length()
	var lower = skeleton.get_bone_pose_position(hand).length()
	var reach = target-start
	var distance = clampf(reach.length(),absf(upper-lower)+0.0001,upper+lower-0.0001)
	var direction = reach.normalized()
	var pole = Vector3(0.8 if side == "l" else -0.8,-0.25,1.6)
	var bend = (pole-direction*pole.dot(direction)).normalized()
	var along = (upper*upper-lower*lower+distance*distance)/(2.0*distance)
	var out = sqrt(maxf(0,upper*upper-along*along))
	var elbow_target = start+direction*along+bend*out
	aim_wing_segment(arm,elbow,elbow_target)
	aim_wing_segment(elbow,hand,start+direction*distance)
	if weight<1.0:
		# The upper wing gently leads the tip, giving the belly clearance while
		# both joints move continuously through the same lift/lower gesture.
		var arm_weight = weight+0.15*sin(PI*weight)
		skeleton.set_bone_pose_rotation(arm,rest_arm.slerp(skeleton.get_bone_pose_rotation(arm),arm_weight))
		skeleton.set_bone_pose_rotation(elbow,rest_elbow.slerp(skeleton.get_bone_pose_rotation(elbow),weight))

func feed_with_food(elapsed: float):
	var phase = clampf(elapsed/action_total,0,1)*FEED_DURATION
	var reach = smoothstep(0.45,1.25,phase)*(1.0-smoothstep(4.05,5.05,phase))
	var lift = smoothstep(1.45,1.95,phase)
	var chewing = smoothstep(1.85,2.05,phase)*(1.0-smoothstep(3.75,3.95,phase))
	# Keep the existing head nod and mouth motion: same frequency and amplitude.
	var chew_wave = sin(maxf(0,phase-1.95)*10)
	turn_bone("head_x",Vector3.RIGHT,chew_wave*0.045*chewing)
	open_mouth(absf(chew_wave)*0.6*chewing)
	var mouth = skeleton.get_bone_global_pose(skeleton.find_bone("head_x"))*mouth_in_head
	var centre = Vector3(0,0.46,0.25).lerp(mouth+Vector3(0,-0.022,0.066),lift)
	for side in ["l","r"]:
		var sign_ = 1.0 if side == "l" else -1.0
		var grip = centre+Vector3(FOOD_WIDTHS[feed_food_id]*sign_,0,0)
		# Blend both joints together in one continuous arc: lift and gather at the
		# same time, then lower directly from the mouth to the straight resting wing.
		if reach>0.00001: hold_food_with_wing(side,grip,reach)
	var left = skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin
	var right = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).origin
	# The food follows the actual two-hand midpoint, including the head's tiny
	# eating nods. Its shape and size stay constant during the eating hold.
	food_root.position = (left+right)*0.5
	# Receive the food only after both wings are extended; finish eating before
	# lowering the empty wings directly back to rest.
	var show = smoothstep(1.25,1.35,phase)*(1.0-smoothstep(3.95,4.05,phase))
	food_root.visible = show>0.001
	food_root.scale = Vector3.ONE*maxf(show,0.001)

func step_and_spin(elapsed: float):
	var phase = clampf(elapsed/action_total,0,1)*SPIN_DURATION
	var response = smoothstep(0.0,0.38,phase)*(1.0-smoothstep(4.22,4.6,phase))
	# Four pairs of steps make a full turn. One foot stays at its last landing
	# while the other swings around, rather than rotating both soles on the floor.
	var steps = clampf((phase-0.38)/0.48,0,8)
	var step = mini(int(steps),7)
	var fraction = steps-step
	var swing = smoothstep(0.10,0.90,fraction)
	var lift = pow(sin(PI*clampf(fraction,0,1)),2)
	var pair_angle = floorf(float(step)/2.0)*PI/2.0
	var left_angle = pair_angle+(swing if step%2 == 0 else 1.0)*PI/2.0
	var right_angle = pair_angle+(0.0 if step%2 == 0 else swing)*PI/2.0
	var angle = (step+smoothstep(0.0,1.0,fraction))*TAU/8.0
	var turn = Basis(Vector3.UP,angle)
	var feet = [skeleton.find_bone("leftfoot"),skeleton.find_bone("rightfoot")]
	var rest_feet: Array[Transform3D] = []
	for foot in feet: rest_feet.append(skeleton.get_bone_global_pose(foot))
	var pivot = (rest_feet[0].origin+rest_feet[1].origin)*0.5
	pivot.y = 0
	var targets: Array[Transform3D] = []
	for i in 2:
		var foot_turn = Basis(Vector3.UP,left_angle if i == 0 else right_angle)
		var target = Transform3D(foot_turn*rest_feet[i].basis,pivot+foot_turn*(rest_feet[i].origin-pivot))
		if i == step%2:
			target.origin.y += 0.028*lift
			target.basis = foot_turn*Basis(Vector3.RIGHT,-0.12*lift)*rest_feet[i].basis
		targets.append(target)
	var midpoint = (targets[0].origin+targets[1].origin)*0.5-pivot
	midpoint.y = 0
	var shift = (pivot-turn*pivot+midpoint*0.4)*SCALE
	var breathing = torso.position.y
	var body_offset = shift+Vector3.UP*(breathing-0.035*lift)
	torso.position = Basis(Vector3.UP,view_yaw)*body_offset
	torso.rotation.y = angle
	for i in 2:
		var target = targets[i]
		target.origin.y += breathing*(1.0-response)/SCALE
		target.origin = turn.inverse()*(target.origin-body_offset/SCALE)
		target.basis = turn.inverse()*target.basis
		var thigh = skeleton.find_bone("leftthigh" if i == 0 else "rightthigh")
		aim_wing_segment(thigh,feet[i],target.origin)
		var parent = skeleton.get_bone_parent(feet[i])
		var local = skeleton.get_bone_global_pose(parent).affine_inverse()*target
		skeleton.set_bone_pose_position(feet[i],local.origin)
		skeleton.set_bone_pose_rotation(feet[i],local.basis.orthonormalized().get_rotation_quaternion())
	var sway = (1.0 if step%2 == 0 else -1.0)*sin(PI*fraction)
	turn_bone("spine_01_x",Vector3.FORWARD,0.025*sway)
	turn_bone("head_x",Vector3.FORWARD,-0.015*sway)
	turn_flipper("l",Vector3.FORWARD,-0.22*response-0.04*sway)
	turn_flipper("r",Vector3.FORWARD,0.22*response-0.04*sway)
	smile(sin(PI*clampf(phase/SPIN_DURATION,0,1)))

func angry_hops_and_hands_on_hips(elapsed: float):
	var phase = clampf(elapsed/action_total,0,1)*ANGRY_DURATION
	var mood = smoothstep(0.0,0.22,phase)*(1.0-smoothstep(4.05,4.8,phase))
	frown(mood)
	# Three small hops, with a grounded pause between each and diminishing height.
	var lift = 0.0
	var landing = 0.0
	for i in 3:
		var start = 0.32+i*0.52
		var flight = (phase-start)/0.38
		if flight > 0.0 and flight < 1.0:
			lift = (0.14-i*0.02)*4.0*flight*(1.0-flight)
		var settle = (phase-start-0.38)/0.14
		if settle > 0.0 and settle < 1.0: landing = sin(PI*settle)
	torso.position.y += lift
	var anticipation = smoothstep(0.0,0.12,phase)*(1.0-smoothstep(0.18,0.32,phase))
	var spine = skeleton.find_bone("spine_01_x")
	var parent = skeleton.get_bone_parent(spine)
	var up_in_parent = skeleton.get_bone_global_pose(parent).basis.inverse()*Vector3.UP
	skeleton.set_bone_pose_position(spine,skeleton.get_bone_pose_position(spine)-up_in_parent*(0.006*anticipation+0.008*landing))
	turn_bone("head_x",Vector3.RIGHT,0.035*anticipation-0.04*landing)
	var airborne = lift/0.14
	turn_bone("leftthigh",Vector3.RIGHT,-0.10*airborne)
	turn_bone("rightthigh",Vector3.RIGHT,-0.10*airborne)
	# Open the elbows after landing, then fold the wing tips toward the waist.
	# Never rotate shoulder_l/r: those shared roots also skin the chest and neck.
	var stance = smoothstep(1.82,2.28,phase)*(1.0-smoothstep(4.02,4.8,phase))
	turn_flipper("l",Vector3.FORWARD,-0.50*stance-0.18*airborne)
	turn_flipper("r",Vector3.FORWARD,0.50*stance+0.18*airborne)
	for side in ["l","r"]:
		var elbow = skeleton.find_bone("forearm_stretch_"+side)
		var elbow_parent = skeleton.get_bone_parent(elbow)
		var axis = skeleton.get_bone_global_pose(elbow_parent).basis.inverse()*Vector3.FORWARD
		turn_bone("forearm_stretch_"+side,axis.normalized(),(1.4 if side == "l" else -1.4)*stance)
	var shake_phase = clampf((phase-2.4)/1.55,0,1)
	var shake = sin(TAU*2.0*shake_phase)*smoothstep(0.0,0.14,shake_phase)*(1.0-smoothstep(0.82,1.0,shake_phase))
	turn_bone("head_x",Vector3.UP,0.25*shake)
	turn_bone("head_x",Vector3.RIGHT,-0.035*stance)
	turn_bone("spine_01_x",Vector3.UP,-0.025*shake)

func smile_and_wiggle(elapsed: float):
	var progress = clampf(elapsed/action_total,0,1)
	var response = smoothstep(0.0,0.15,progress)*(1.0-smoothstep(0.80,1.0,progress))
	var sway = sin(TAU*2.0*progress)*smoothstep(0.0,0.18,progress)*(1.0-smoothstep(0.76,1.0,progress))
	# The hip root skins the rump and parents both legs. Preserve the legs' global
	# poses while moving the hips, so the small weight shift never slides the feet.
	var legs = [skeleton.find_bone("leftthigh"),skeleton.find_bone("rightthigh")]
	var planted_legs: Array[Transform3D] = []
	for leg in legs: planted_legs.append(skeleton.get_bone_global_pose(leg))
	turn_bone("root_x",Vector3.UP,0.17*sway)
	turn_bone("root_x",Vector3.FORWARD,0.025*sway)
	var hips = skeleton.find_bone("root_x")
	var parent = skeleton.get_bone_parent(hips)
	var parent_basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var side_in_parent = parent_basis.inverse()*Vector3.RIGHT
	skeleton.set_bone_pose_position(hips,skeleton.get_bone_pose_position(hips)+side_in_parent*0.014*sway)
	for i in legs.size():
		var local = skeleton.get_bone_global_pose(skeleton.get_bone_parent(legs[i])).affine_inverse()*planted_legs[i]
		skeleton.set_bone_pose_position(legs[i],local.origin)
		skeleton.set_bone_pose_rotation(legs[i],local.basis.get_rotation_quaternion())
	# Let the upper body counter the hip twist; the face stays easy to read.
	turn_bone("spine_01_x",Vector3.UP,-0.10*sway)
	turn_bone("spine_01_x",Vector3.FORWARD,-0.045*sway)
	turn_bone("head_x",Vector3.UP,-0.035*sway)
	turn_bone("head_x",Vector3.FORWARD,0.025*sway)
	turn_flipper("l",Vector3.FORWARD,-0.16*response-0.035*sway)
	turn_flipper("r",Vector3.FORWARD,0.16*response-0.035*sway)
	close_eyes(0.95*response)
	smile(0.85*response)

func tilt_head_and_blink(elapsed: float):
	var progress = clampf(elapsed/action_total,0,1)
	var tilt = smoothstep(0.0,0.26,progress)*(1.0-smoothstep(0.64,1.0,progress))
	turn_bone("spine_01_x",Vector3.FORWARD,head_tilt_direction*0.045*tilt)
	turn_bone("head_x",Vector3.FORWARD,head_tilt_direction*0.16*tilt)
	# Both eyes blink together after the curious tilt settles into its hold.
	var blink = 0.0
	for start in [0.34,0.49]:
		var phase = (progress-start)*action_total
		blink = maxf(blink,smoothstep(0.0,0.055,phase)*(1.0-smoothstep(0.085,0.19,phase)))
	close_eyes(blink)

func look_around(elapsed: float):
	var progress = clampf(elapsed/action_total,0,1)
	var attention = smoothstep(0.0,0.28,progress)*(1.0-smoothstep(0.68,1.0,progress))
	var lift = smoothstep(0.18,0.40,progress)*(1.0-smoothstep(0.64,0.91,progress))
	turn_bone("spine_01_x",Vector3.UP,look_direction*0.13*attention)
	turn_bone("head_x",Vector3.UP,look_direction*0.38*attention)
	turn_bone("spine_01_x",Vector3.RIGHT,-0.035*lift)
	turn_bone("head_x",Vector3.RIGHT,-0.10*lift)
	# A small, held wing lift supports the curious pose without becoming a wave.
	turn_flipper("l",Vector3.FORWARD,-0.14*attention)
	turn_flipper("r",Vector3.FORWARD,0.14*attention)
	# A small spine extension lifts the upper body while both feet stay planted.
	# Convert model-up to parent space, without stretching the mesh or its clothes.
	var spine = skeleton.find_bone("spine_01_x")
	var parent = skeleton.get_bone_parent(spine)
	var up_in_parent = skeleton.get_bone_global_pose(parent).basis.inverse()*Vector3.UP
	skeleton.set_bone_pose_position(spine,skeleton.get_bone_pose_position(spine)+up_in_parent*0.006*lift)
	var blink = 0.0
	for start in [0.40,0.48,0.56]:
		var phase = (progress-start)*action_total
		blink = maxf(blink,smoothstep(0.0,0.055,phase)*(1.0-smoothstep(0.085,0.19,phase)))
	close_eyes(blink)

func yawn_and_stretch(elapsed: float):
	var progress = clampf(elapsed/action_total,0,1)
	var yawn = sin(PI*progress)
	var stretch = smoothstep(0.07,0.32,progress)*(1.0-smoothstep(0.61,0.94,progress))
	# Preserve the original yawn's head and matching facial morphs.
	turn_bone("head_x",Vector3.RIGHT,-yawn*0.1)
	close_eyes(yawn*0.9)
	open_mouth(yawn*0.85)
	turn_flipper("l",Vector3.FORWARD,-1.85*stretch)
	turn_flipper("r",Vector3.FORWARD,1.85*stretch)
	turn_bone("spine_01_x",Vector3.RIGHT,-0.045*stretch)
	# Extend the upper body slightly; feet, model scale and clothing scale stay fixed.
	var spine = skeleton.find_bone("spine_01_x")
	var parent = skeleton.get_bone_parent(spine)
	var up_in_parent = skeleton.get_bone_global_pose(parent).basis.inverse()*Vector3.UP
	skeleton.set_bone_pose_position(spine,skeleton.get_bone_pose_position(spine)+up_in_parent*0.018*stretch)

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
	var guiding = task_kind == "work" and task_id == "idol"
	guide_blend = move_toward(guide_blend,1.0 if guiding else 0.0,delta/0.65)
	if guiding and action.is_empty() and guide_blend>=1.0:
		guide_clock += delta
		guide_step_clock += delta*guide_march_amount()
	var answering_calls = task_kind == "work" and task_id == "waiter"
	phone_blend = move_toward(phone_blend,1.0 if answering_calls else 0.0,delta/0.65)
	if answering_calls and action.is_empty() and phone_blend>=1.0:
		phone_clock += delta
		if phone_clock>=phone_cycle:
			var remainder = phone_clock-phone_cycle
			next_phone_call()
			phone_clock = remainder
	var programming = task_kind == "work" and task_id == "code"
	code_blend = move_toward(code_blend,1.0 if programming else 0.0,delta/0.65)
	if programming and action.is_empty() and code_blend>=1.0: code_clock += delta
	var proofreading = task_kind == "work" and task_id == "library"
	proof_blend = move_toward(proof_blend,1.0 if proofreading else 0.0,delta/0.65)
	if proofreading and action.is_empty() and proof_blend>=1.0: proof_clock += delta
	var guarding = task_kind == "work" and task_id == "guard"
	guard_blend = move_toward(guard_blend,1.0 if guarding else 0.0,delta/0.65)
	if guarding and action.is_empty() and guard_blend>=1.0: guard_clock += delta
	var carrying = task_kind == "work" and task_id == "carry"
	carry_blend = move_toward(carry_blend,1.0 if carrying else 0.0,delta/0.65)
	if carrying and action.is_empty() and carry_blend>=1.0: carry_clock += delta
	var distributing_flyers = task_kind == "work" and task_id == "flyer"
	flyer_blend = move_toward(flyer_blend,1.0 if distributing_flyers else 0.0,delta/0.65)
	if distributing_flyers and action.is_empty() and flyer_blend>=1.0: flyer_clock += delta
	var writing_lyrics = task_kind == "study" and task_id == "stage"
	lyrics_blend = move_toward(lyrics_blend,1.0 if writing_lyrics else 0.0,delta/0.65)
	if writing_lyrics and action.is_empty() and lyrics_blend>=1.0: lyrics_clock += delta
	var singing = task_kind == "study" and task_id == "music"
	music_blend = move_toward(music_blend,1.0 if singing else 0.0,delta/0.65)
	if singing and action.is_empty() and music_blend>=1.0: music_clock += delta
	var practicing_manners = task_kind == "study" and task_id == "manners"
	manners_blend = move_toward(manners_blend,1.0 if practicing_manners else 0.0,delta/0.65)
	if practicing_manners and action.is_empty() and manners_blend>=1.0: manners_clock += delta
	var researching = task_kind == "study" and task_id == "science"
	science_blend = move_toward(science_blend,1.0 if researching else 0.0,delta/0.65)
	if researching and action.is_empty() and science_blend>=1.0: science_clock += delta
	var calculating = task_kind == "study" and task_id == "math"
	math_blend = move_toward(math_blend,1.0 if calculating else 0.0,delta/0.65)
	if calculating and action.is_empty() and math_blend>=1.0: math_clock += delta
	var reading = task_kind == "study" and task_id == "read"
	reading_blend = move_toward(reading_blend,1.0 if reading else 0.0,delta/0.65)
	var training_combat = task_kind == "study" and task_id == "combat"
	combat_blend = move_toward(combat_blend,1.0 if training_combat else 0.0,delta/0.65)
	if training_combat and action.is_empty() and combat_blend>=1.0: combat_clock += delta
	update_training_bag(delta,training_combat)
	var practicing_martial = task_kind == "study" and task_id == "martial"
	martial_blend = move_toward(martial_blend,1.0 if practicing_martial else 0.0,delta/0.65)
	if practicing_martial and action.is_empty() and martial_blend>=1.0: martial_clock += delta
	var playing_basketball = task_kind == "study" and task_id == "sport"
	basketball_blend = move_toward(basketball_blend,1.0 if playing_basketball else 0.0,delta/(0.65 if playing_basketball else 0.50))
	if playing_basketball and action.is_empty() and basketball_blend>=1.0:
		basketball_clock += delta
	action_left = maxf(0,action_left-delta)
	if action_left == 0: action = ""
	idle_left -= delta
	if autonomous_idle and idle_left <= 0 and task_kind.is_empty() and action.is_empty():
		idle_left = rng.randf_range(8,15)
		if not try_unlocked_idle():
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
	torso.position = Vector3(0,sin(time*2)*0.009,0)
	# Keep both wing segments straight, slanting down outside the body.
	# Larger frozen performances keep their held poses and blend back to this
	# corrected rest. Small gestures and feeding keep the wings clear throughout.
	var rest_clearance = 1.0
	if action in ["yawn","hop","feet","celebrate","angry","spin","dance"]:
		var rest_elapsed = action_total-action_left
		rest_clearance -= smoothstep(0.0,0.30,rest_elapsed)*(1.0-smoothstep(action_total-0.30,action_total,rest_elapsed))
	turn_flipper("l",Vector3.FORWARD,1.25-REST_WING_CLEARANCE*rest_clearance)
	turn_flipper("r",Vector3.FORWARD,-1.25+REST_WING_CLEARANCE*rest_clearance)
	# Move only the independent hinges slightly outside the round torso. This
	# allows a steeper straight wing without bending the tip or moving the chest.
	for side in ["l","r"]:
		var arm = skeleton.find_bone("arm_stretch_"+side)
		var parent_basis = skeleton.get_bone_global_pose(skeleton.get_bone_parent(arm)).basis
		var offset = Vector3(REST_WING_OFFSET*rest_clearance*(1 if side == "l" else -1),0,0)
		skeleton.set_bone_pose_position(arm,skeleton.get_bone_pose_position(arm)+parent_basis.inverse()*offset)
	turn_bone("head_x",Vector3.RIGHT,sin(time*1.4)*0.018)
	if moving:
		var walk = sin(time*8)
		turn_bone("leftthigh",Vector3.RIGHT,walk*0.22)
		turn_bone("rightthigh",Vector3.RIGHT,-walk*0.22)
		turn_flipper("l",Vector3.RIGHT,walk*0.12)
		turn_flipper("r",Vector3.RIGHT,-walk*0.12)
		turn_bone("spine_01_x",Vector3.FORWARD,walk*0.035)
		torso.position.y += absf(walk)*0.025
	book.position = Vector3(0,1.0,0.48)
	book.rotation = Vector3(-0.25,0,0)
	book.visible = task_kind == "study" and task_id not in ["sport","martial","combat","stage","read","math","science","manners","music"]
	props.visible = task_kind == "work" and task_id not in ["flyer","carry","guard","idol","library","code","waiter"]
	var elapsed = action_total-action_left
	if is_instance_valid(food_root): food_root.visible = false
	if is_instance_valid(basketball): basketball.visible = false
	if is_instance_valid(combat_root): combat_root.visible = false
	if is_instance_valid(abacus): abacus.visible = false
	if is_instance_valid(magnifier): magnifier.visible = false
	if is_instance_valid(microphone): microphone.visible = false
	if is_instance_valid(lyric_notebook): lyric_notebook.visible = false
	if is_instance_valid(lyric_pen): lyric_pen.visible = false
	if is_instance_valid(flyer_stack): flyer_stack.visible = false
	if is_instance_valid(flyer_single): flyer_single.visible = false
	if is_instance_valid(carry_box): carry_box.visible = false
	if is_instance_valid(guide_flag): guide_flag.visible = false
	if is_instance_valid(phone_root): phone_root.visible = false
	if is_instance_valid(phone_receiver): phone_receiver.visible = false
	if is_instance_valid(laptop_root): laptop_root.visible = false
	if is_instance_valid(proof_root): proof_root.visible = false
	if is_instance_valid(proof_stamp): proof_stamp.visible = false
	for note in music_notes: note.visible = false
	# This two-handed reaction briefly puts away task props. Blend only the pose;
	# task_kind/id and the real-time task in main/game_state keep running.
	var task_pose_weight = 1.0
	if action == "angry":
		var anger_phase = clampf((action_total-action_left)/action_total,0,1)*ANGRY_DURATION
		task_pose_weight -= smoothstep(0.0,0.22,anger_phase)*(1.0-smoothstep(4.05,4.8,anger_phase))
	elif action == "feed" or (action == "wash" and wash_task_transition):
		task_pose_weight -= smoothstep(0.0,CARE_BLEND_IN,elapsed)*(1.0-smoothstep(action_total-CARE_BLEND_OUT,action_total,elapsed))
	elif action == "spin":
		var spin_phase = clampf(elapsed/action_total,0,1)*SPIN_DURATION
		task_pose_weight -= smoothstep(0.0,0.38,spin_phase)*(1.0-smoothstep(4.22,4.6,spin_phase))
	if (playing_basketball or practicing_martial or training_combat or reading or calculating or researching or practicing_manners or singing or writing_lyrics or distributing_flyers or carrying or guarding or proofreading or programming or answering_calls or guiding) and not action.is_empty():
		task_pose_weight *= 1.0-smoothstep(0.0,0.22,elapsed)*(1.0-smoothstep(action_total-0.30,action_total,elapsed))
	book.scale = Vector3.ONE*maxf(task_pose_weight,0.001)
	props.scale = Vector3.ONE*maxf(task_pose_weight,0.001)
	if task_kind != "":
		if book.visible:
			book.visible = true
			turn_bone("head_x",Vector3.RIGHT,(0.1+sin(time*2.5)*0.035)*task_pose_weight)
			turn_flipper("l",Vector3.RIGHT,-0.45*task_pose_weight)
			turn_flipper("r",Vector3.RIGHT,-0.45*task_pose_weight)
		elif task_id not in ["sport","martial","combat","read","math","science","manners","music","stage","flyer","carry","guard","library","code","waiter","idol"]:
			turn_flipper("l",Vector3.FORWARD,(-0.35+sin(time*3)*0.2)*task_pose_weight)
			turn_bone("head_x",Vector3.FORWARD,sin(time*2)*0.045*task_pose_weight)
	if basketball_blend>0.0:
		basketball_dribble(smoothstep(0.0,1.0,basketball_blend)*task_pose_weight)
	if martial_blend>0.0:
		martial_routine(smoothstep(0.0,1.0,martial_blend)*task_pose_weight)
	if combat_blend>0.0:
		punch_training_bag(smoothstep(0.0,1.0,combat_blend)*task_pose_weight)
	if reading_blend>0.0:
		hold_reading_book(smoothstep(0.0,1.0,reading_blend)*task_pose_weight)
	if math_blend>0.0:
		count_with_abacus(smoothstep(0.0,1.0,math_blend)*task_pose_weight)
	if science_blend>0.0:
		scan_with_magnifier(smoothstep(0.0,1.0,science_blend)*task_pose_weight)
	if manners_blend>0.0:
		practice_manners(smoothstep(0.0,1.0,manners_blend)*task_pose_weight)
	if music_blend>0.0:
		sing_with_microphone(smoothstep(0.0,1.0,music_blend)*task_pose_weight)
	if lyrics_blend>0.0:
		write_lyrics(smoothstep(0.0,1.0,lyrics_blend)*task_pose_weight)
	if flyer_blend>0.0:
		hand_out_flyer(smoothstep(0.0,1.0,flyer_blend)*task_pose_weight)
	if carry_blend>0.0:
		carry_and_step(smoothstep(0.0,1.0,carry_blend)*task_pose_weight)
	if guard_blend>0.0:
		salute_and_stand(smoothstep(0.0,1.0,guard_blend)*task_pose_weight)
	if proof_blend>0.0:
		proofread_and_stamp(smoothstep(0.0,1.0,proof_blend)*task_pose_weight)
	if code_blend>0.0:
		type_on_laptop(smoothstep(0.0,1.0,code_blend)*task_pose_weight)
	if guide_blend>0.0:
		lead_tour(smoothstep(0.0,1.0,guide_blend)*task_pose_weight)
	if phone_blend>0.0:
		answer_telephone(smoothstep(0.0,1.0,phone_blend)*task_pose_weight)
	var wave = sin(elapsed*10)
	var envelope = sin(PI*clampf(action_left/action_total,0,1))
	var expression_envelope = smoothstep(0.0,0.12,elapsed)*smoothstep(0.0,0.18,action_left)
	match action:
		"head": tilt_head_and_blink(elapsed)
		"look": look_around(elapsed)
		"yawn": yawn_and_stretch(elapsed)
		"pet":
			turn_bone("head_x",Vector3.FORWARD,sin(time*4.5)*0.08)
			turn_bone("spine_01_x",Vector3.FORWARD,sin(time*4.5)*0.025)
			close_eyes(expression_envelope)
			smile(0.4*expression_envelope)
		"belly": smile_and_wiggle(elapsed)
		"wing_l": turn_flipper("r",Vector3.FORWARD,envelope*(1.2+wave*0.2))
		"wing_r": turn_flipper("l",Vector3.FORWARD,-envelope*(1.2+wave*0.2))
		"hop","feet","celebrate":
			torso.position.y = absf(sin(elapsed*5))*0.23*envelope
			turn_bone("leftthigh",Vector3.RIGHT,-envelope*0.15)
			turn_bone("rightthigh",Vector3.RIGHT,-envelope*0.15)
			turn_flipper("l",Vector3.FORWARD,-envelope*0.6)
			turn_flipper("r",Vector3.FORWARD,envelope*0.6)
			smile(envelope*0.8)
		"feed": feed_with_food(elapsed)
		"wash":
			var wash_elapsed = elapsed-(CARE_BLEND_IN if wash_task_transition else 0.0)
			var wash_left = action_left-(CARE_BLEND_OUT if wash_task_transition else 0.0)
			if wash_elapsed>=0.0 and wash_left>0.0:
				var wash_expression = smoothstep(0.0,0.12,wash_elapsed)*smoothstep(0.0,0.18,wash_left)
				turn_bone("spine_01_x",Vector3.FORWARD,sin(wash_elapsed*10)*0.045)
				close_eyes(wash_expression)
				smile(0.35*wash_expression)
		"angry": angry_hops_and_hands_on_hips(elapsed)
		"spin": step_and_spin(elapsed)
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
	if guide_blend>0.0: attach_guide_flag()
	if phone_blend>0.0:
		attach_phone_receiver()
		update_phone_cord()
	if lyrics_blend>0.0: attach_lyric_tools()
	if flyer_blend>0.0: attach_flyers()
	if carry_blend>0.0: attach_carry_box()
	if proof_blend>0.0: attach_proof_stamp()
	if music_blend>0.0: update_music_notes(smoothstep(0.0,1.0,music_blend)*task_pose_weight)
	for i in bubbles.size():
		var bubble = bubbles[i]
		bubble.visible = action == "wash" and (not wash_task_transition or (elapsed>=CARE_BLEND_IN and action_left>CARE_BLEND_OUT))
		if bubble.visible:
			var a = float(i)*2.4+time
			bubble.position = Vector3(sin(a)*0.72,0.4+fmod(time*0.65+i*0.19,2),cos(a)*0.55)
			bubble.scale = Vector3.ONE*(0.09+0.04*sin(i*3.1))

# Refine close reaches on the actual distal point; shared task IK stays frozen.
func aim_phone_tip(side: String, target: Vector3, weight: float):
	var arm = skeleton.find_bone("arm_stretch_"+side)
	var elbow = skeleton.find_bone("forearm_stretch_"+side)
	var hand = skeleton.find_bone("hand_"+side)
	var originals = [skeleton.get_bone_pose_rotation(arm),skeleton.get_bone_pose_rotation(elbow)]
	var tip_local = FLYER_WING_TIP*Vector3(1 if side == "l" else -1,1,1)
	aim_proof_tip(side,target,1.0)
	for iteration in 18:
		skeleton.force_update_all_bone_transforms()
		if (skeleton.get_bone_global_pose(hand)*tip_local).distance_to(target)<0.00005: break
		for bone in [elbow,arm]:
			var current = skeleton.get_bone_global_pose(bone)
			var tip = skeleton.get_bone_global_pose(hand)*tip_local
			var rotation = Basis(Quaternion((tip-current.origin).normalized(),(target-current.origin).normalized()))*current.basis
			var local_basis = skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis.inverse()*rotation
			skeleton.set_bone_pose_rotation(bone,local_basis.orthonormalized().get_rotation_quaternion())
			skeleton.force_update_all_bone_transforms()
	if weight<1.0:
		skeleton.set_bone_pose_rotation(arm,originals[0].slerp(skeleton.get_bone_pose_rotation(arm),weight))
		skeleton.set_bone_pose_rotation(elbow,originals[1].slerp(skeleton.get_bone_pose_rotation(elbow),weight))
