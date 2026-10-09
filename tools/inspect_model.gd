extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var scene = load("res://assets/nicoma/scene.gltf").instantiate()
	root.add_child(scene)
	inspect(scene)
	quit()
func inspect(n):
	if n is Skeleton3D:
		print("BONES: ", n.get_bone_count(), " transform ",n.global_transform)
		for i in n.get_bone_count(): print(i, " ", n.get_bone_name(i), " ", n.get_bone_global_rest(i).origin)
	if n is AnimationPlayer:
		print("ANIMATIONS: ", n.get_animation_list())
		for a in n.get_animation_list(): print(a," length ",n.get_animation(a).length)
	if n is MeshInstance3D: print("MESH: ", n.name, " ", n.get_aabb(), " global ",n.global_transform)
	for c in n.get_children(): inspect(c)
