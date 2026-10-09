extends SceneTree
var app: Node
var checks = 0
var failed = 0
var centers: Dictionary = {}

func _initialize(): call_deferred("run")
func expect(ok: bool, description: String):
	checks += 1
	if not ok:
		failed += 1
		printerr("UI FAIL: ",description)
	else: print("UI OK: ",description)

func wait(seconds: float = 0.15): await create_timer(seconds).timeout

func capture(name_: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/"+name_+".png")

func click(pos: Vector2):
	for pressed_ in [true,false]:
		var e = InputEventMouseButton.new()
		e.button_index=MOUSE_BUTTON_LEFT
		e.position=pos
		e.global_position=pos
		e.pressed=pressed_
		root.push_input(e,true)
		await wait(0.03)

func part_click(part: String):
	await click(app.stage.position+centers[part])

func find_button(node: Node, text_: String) -> Button:
	if node is Button and node.text==text_: return node
	for child in node.get_children():
		var result = find_button(child,text_)
		if result: return result
	return null

func find_item_button(item_name: String) -> Button:
	for row in app.panel_body.get_children():
		if row is HBoxContainer and row.get_child(0).get_child(0).text.begins_with(item_name):
			return row.get_child(1)
	return null

func run():
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	app.game.autosave=false
	app.game.data=app.game.fresh(app.now())
	app.refresh()
	app.adopt_box.show()
	await wait(0.4)
	await capture("adoption")
	var adoption=find_button(app.ui,"开始领养")
	await click(adoption.get_global_rect().get_center())
	expect(app.game.data.adopted and not app.adopt_box.visible,"adoption button through viewport input")
	app.pet.target=Vector3.ZERO
	app.pet.idle_left=1000
	app.pet.perform("",0)
	await wait(0.3)
	await capture("home")
	# Scan physics hit regions in the actual rendered viewport.
	var pixels={}
	for y in range(70,int(app.viewport.size.y),4):
		for x in range(250,710,4):
			var p=Vector2(x,y)
			var part=app.hit_part(p)
			if part!="":
				if not pixels.has(part):pixels[part]=[]
				pixels[part].append(p)
	for part in ["head","belly","wing_l","wing_r","feet"]:
		expect(pixels.has(part),"raycast region "+part)
		if not pixels.has(part):continue
		var mean=Vector2.ZERO
		for p in pixels[part]:mean+=p
		mean/=pixels[part].size()
		var best=pixels[part][0]
		for p in pixels[part]:
			if p.distance_to(mean)<best.distance_to(mean):best=p
		centers[part]=best
		await part_click(part)
		expect(app.pet.action==part,"distinct part action "+part)
		await wait(1.9)
	expect(centers.size()==5,"all five body regions reachable")
	if centers.has("head"):
		var pos=app.stage.position+centers.head
		var down=InputEventMouseButton.new()
		down.button_index=MOUSE_BUTTON_LEFT
		down.position=pos
		down.pressed=true
		root.push_input(down,true)
		await wait(0.35)
		for i in 6:
			var e=InputEventMouseMotion.new()
			e.position=pos+Vector2(4 if i%2==0 else 0,0)
			e.relative=Vector2(4 if i%2==0 else -4,0)
			e.button_mask=MOUSE_BUTTON_MASK_LEFT
			root.push_input(e,true)
			await wait(0.04)
		expect(app.game.data.stats.pet==1 and app.pet.action=="pet","head movement counts pet once")
		var up=InputEventMouseButton.new()
		up.button_index=MOUSE_BUTTON_LEFT
		up.position=pos
		up.pressed=false
		root.push_input(up,true)
		expect(app.pet.action=="pet","pet release does not trigger click")
		await capture("petting")
		await wait(2.3)
	app.game.data.food=60
	app.game.data.clean=60
	app.game.start_task("study","read",app.now())
	await wait(0.2)
	await click(find_button(app.ui,"喂食").get_global_rect().get_center())
	expect(app.panel.visible and app.panel_mode=="food","feeding panel opens during task")
	var use=find_item_button("小鱼干")
	await click(use.get_global_rect().get_center())
	expect(app.game.data.task.id=="read" and app.pet.action=="feed","feeding keeps study task")
	await click(find_button(app.panel,"关闭").get_global_rect().get_center())
	await wait(2.6)
	expect(app.pet.action.is_empty() and app.pet.book.visible,"returns to study animation")
	await click(find_button(app.ui,"洗澡").get_global_rect().get_center())
	await click(find_button(app.panel_body,"使用").get_global_rect().get_center())
	expect(app.game.data.task.id=="read" and app.pet.action=="wash","bathing keeps study task")
	await click(find_button(app.panel,"关闭").get_global_rect().get_center())
	await capture("bath")
	await wait(2.6)
	app.game.data.task.elapsed=300
	app.request_end()
	await wait()
	expect(find_button(app.panel_body,"确认提前结束").get_global_rect().end.y<root.size.y-116,"end confirmation visible without scrolling")
	await click(find_button(app.panel_body,"确认提前结束").get_global_rect().get_center())
	expect(app.game.data.task.is_empty(),"early finish through UI")
	app.game.data.level=15
	app.game.data.achievements.append("all60")
	app.game.data.head="redhat"
	app.game.data.neck="scarf"
	app.refresh()
	await wait()
	await capture("accessories")
	app.game.data.head="graduate"
	app.game.data.neck="bow"
	app.refresh()
	await wait()
	await capture("graduate")
	app.game.data.head="crown"
	app.game.data.neck="tie"
	app.game.data.level=20
	app.game.data.gold=true
	app.refresh()
	await wait()
	await capture("crown")
	root.size=Vector2i(760,600)
	await wait(0.3)
	await click(find_button(app.ui,"商店").get_global_rect().get_center())
	expect(app.panel.get_global_rect().end.y<app.hint.get_global_rect().position.y,"panel and navigation separated at minimum size")
	await capture("small_shop")
	print("UI_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed==0 else 1)
