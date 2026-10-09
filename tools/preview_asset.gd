extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(960,700)
	var world = Node3D.new()
	root.add_child(world)
	var model = load("res://assets/tomori/penguin.glb").instantiate()
	model.scale = Vector3.ONE*2.7
	world.add_child(model)
	for n in model.find_children("*","Skeleton3D",true,false):
		print("SKELETON ",n.name," transform ",n.global_transform)
		for i in n.get_bone_count():print(i," ",n.get_bone_name(i)," ",n.get_bone_global_rest(i))
	for n in model.find_children("*","MeshInstance3D",true,false):print("MESH ",n.name," ",n.get_aabb()," ",n.global_transform)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("eee7da")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff4df")
	env.environment.ambient_light_energy = 0.65
	world.add_child(env)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35,-25,0)
	key.light_energy = 0.8
	world.add_child(key)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.25
	camera.position = Vector3(0,2.3,7)
	world.add_child(camera)
	camera.look_at(Vector3(0,1.28,0))
	camera.current = true
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/tomori_raw.png")
	quit()
