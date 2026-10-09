extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var canvas=SubViewport.new()
	canvas.size=Vector2i(1280,1620)
	canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var layout = GridContainer.new()
	layout.columns=8
	layout.add_theme_constant_override("h_separation",0)
	layout.add_theme_constant_override("v_separation",0)
	canvas.add_child(layout)
	var source = load("res://assets/tomori/penguin.glb")
	var probe = source.instantiate()
	var head = probe.find_children("Tomori_mesh","MeshInstance3D",true,false)[0]
	var count = head.mesh.get_blend_shape_count()
	print("MORPHS ",count)
	for i in range(-1,count):
		var cell=VBoxContainer.new()
		cell.custom_minimum_size=Vector2(160,180)
		layout.add_child(cell)
		var name_=Label.new()
		name_.text="Baseline" if i<0 else head.mesh.get_blend_shape_name(i).replace("body_Base_obj_morph","Body ").replace("face_Base_obj_morph","Base ").replace("face_NoOutline_obj_morph","Line ").replace("face_Offset_obj_morph","Offset ")
		name_.add_theme_font_size_override("font_size",12)
		cell.add_child(name_)
		var surface=SubViewportContainer.new()
		cell.add_child(surface)
		var v=SubViewport.new()
		v.size=Vector2i(160,156)
		v.own_world_3d=true
		surface.add_child(v)
		var w=Node3D.new()
		v.add_child(w)
		var model=source.instantiate()
		model.scale=Vector3.ONE*2.7
		w.add_child(model)
		if i>=0:model.find_children("Tomori_mesh","MeshInstance3D",true,false)[0].set_blend_shape_value(i,1)
		var env=WorldEnvironment.new()
		env.environment=Environment.new()
		env.environment.background_mode=Environment.BG_COLOR
		env.environment.background_color=Color("eee7da")
		env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_energy=0.75
		w.add_child(env)
		var key=DirectionalLight3D.new()
		key.rotation_degrees=Vector3(-30,-25,0)
		key.light_energy=0.65
		w.add_child(key)
		var cam=Camera3D.new()
		cam.projection=Camera3D.PROJECTION_ORTHOGONAL
		cam.size=1.16
		cam.position=Vector3(0,2.18,6)
		w.add_child(cam)
		cam.look_at(Vector3(0,2.08,0))
		cam.current=true
	probe.free()
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png("res://tests/output/tomori_morphs.png")
	quit()
