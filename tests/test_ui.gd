extends SceneTree
var app: Node
var checks=0
var failed=0
func _initialize():call_deferred("run")
func expect(ok: bool, description: String):
	checks+=1
	if not ok:
		failed+=1
		printerr("UI FAIL: ",description)
	else:print("UI OK: ",description)
func wait(seconds: float=0.15):await create_timer(seconds).timeout
func capture(name_: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/"+name_+".png")
func mouse(pos: Vector2, down: bool):
	var e=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.position=pos
	e.global_position=pos
	e.pressed=down
	root.push_input(e,true)
	await wait(0.03)
func click(pos: Vector2):
	await mouse(pos,true)
	await mouse(pos,false)
func motion(pos: Vector2, relative: Vector2):
	var e=InputEventMouseMotion.new()
	e.position=pos
	e.relative=relative
	e.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(e,true)
	await wait(0.03)
func press_escape():
	var e=InputEventKey.new()
	e.keycode=KEY_ESCAPE
	e.pressed=true
	root.push_input(e,true)
	await wait()
func find_button(node: Node, text_: String) -> Button:
	if node is Button and node.text.begins_with(text_):return node
	for child in node.get_children():
		var result=find_button(child,text_)
		if result:return result
	return null
func tap(node: Control):await click(node.get_global_rect().get_center())
func wheel(node: Control, times: int):
	for i in times:
		var e=InputEventMouseButton.new()
		e.button_index=MOUSE_BUTTON_WHEEL_DOWN
		e.position=node.get_global_rect().get_center()
		e.pressed=true
		root.push_input(e,true)
		e=e.duplicate()
		e.pressed=false
		root.push_input(e,true)
	await wait()

func run():
	app=load("res://main.tscn").instantiate()
	# Keep UI exercises isolated from the player's save, including _ready/load.
	app.game.path="res://tests/output/ui-penguin.json"
	app.game.autosave=false
	root.add_child(app)
	app.game.data=app.game.fresh(app.now())
	app.refresh()
	app.adopt_box.show()
	await wait(0.5)
	expect(root.size.x*9==root.size.y*16,"initial window is 16:9")
	expect(ProjectSettings.get_setting("application/config/name")=="养一只咕咕嘎嘎吧！","new game title")
	expect(ProjectSettings.get_setting("application/config/version")=="1.3.0","release version 1.3.0")
	expect(ProjectSettings.globalize_path("user://").replace("\\","/").contains("Godot/app_userdata/企鹅小日子/"),"renamed game keeps original save directory")
	await capture("adoption")
	await tap(find_button(app.ui,"领养"))
	expect(app.game.data.adopted and not app.adopt_box.visible,"adoption through viewport input")
	app.pet.target=Vector3.ZERO
	app.pet.idle_left=10000
	app.pet.perform("",0)
	await wait(0.25)
	await capture("home")
	var centers={}
	var hits={}
	var ground=Vector2.ZERO
	for y in range(50,int(app.stage.size.y),5):
		for x in range(330,950,5):
			var local=Vector2(x,y)
			var p=app.stage_point(local)
			var part=app.hit_part(p)
			if part!="":
				if not hits.has(part):hits[part]=[]
				hits[part].append(local+app.stage.position)
			if ground==Vector2.ZERO and part.is_empty() and app.is_ground(p):ground=local+app.stage.position
	for part in hits:
		# Feet are two separate islands; averaging both picks their inner edges.
		if part=="feet":hits[part]=hits[part].filter(func(p):return p.x<app.stage.size.x/2)
		var mean=Vector2.ZERO
		for p in hits[part]:mean+=p
		mean/=hits[part].size()
		centers[part]=hits[part][0]
		for p in hits[part]:
			if p.distance_to(mean)<centers[part].distance_to(mean):centers[part]=p
	for part in ["head","belly","wing_l","wing_r","feet"]:
		expect(centers.has(part),"reachable body region "+part)
		if centers.has(part):
			await click(centers[part])
			expect(app.pet.action==part,"body click feedback "+part)
			await wait(1.9)
	var head_pos=centers.head
	await mouse(head_pos,true)
	await wait(0.35)
	for i in 6:await motion(head_pos+Vector2(4 if i%2==0 else 0,0),Vector2(4 if i%2==0 else -4,0))
	expect(app.game.data.stats.pet==1 and app.pet.action=="pet","head gesture rewards one petting interaction")
	await mouse(head_pos,false)
	expect(app.pet.action=="pet","petting release does not trigger click")
	await wait(2.3)
	expect(ground!=Vector2.ZERO,"rotation area reachable outside body")
	var before=app.game.data.stats.duplicate(true)
	await mouse(ground,true)
	await motion(ground+Vector2(70,0),Vector2(70,0))
	await mouse(ground+Vector2(70,0),false)
	expect(absf(app.pet.view_yaw)>0.5,"ground drag rotates presentation")
	expect(app.game.data.stats==before,"rotation does not count as interaction")
	await capture("rotation")
	app.rotate_idle=9.9
	await wait(0.4)
	expect(app.return_tween!=null and app.return_tween.is_running(),"idle rotation begins smooth return")
	await mouse(ground,true)
	expect(not app.return_tween.is_running(),"new drag interrupts return")
	await mouse(ground,false)
	app.rotate_idle=10
	await wait(2.3)
	expect(absf(app.pet.view_yaw)<0.005,"rotation returns to front")
	app.game.data.food=5
	app.game.data.clean=20
	app.game.data.mood=50
	app.refresh()
	await tap(find_button(app.hud,"喂食"))
	expect(app.item_menu.visible and not app.modal.visible,"feeding uses unblurred popout")
	await capture("food_menu")
	await tap(app.item_buttons.fish)
	await tap(app.item_buttons.fish)
	expect(app.item_menu.visible and app.game.data.inventory.fish==1,"repeat feeding keeps menu open and deducts each item")
	expect(app.pet.feed_food_id=="fish","feeding menu selects the matching held food model")
	expect(app.item_buttons.fish.get_node("Copy/Name").text.ends_with("×1"),"menu quantity refreshes immediately")
	await tap(app.item_buttons.bread)
	expect(app.item_menu.visible and not app.menu_error.text.is_empty(),"missing stock reports error in menu")
	before=app.game.data.stats.duplicate(true)
	await click(centers.head)
	expect(not app.item_menu.visible and app.game.data.stats==before,"outside click dismisses without pet interaction")
	await tap(find_button(app.hud,"洗澡"))
	await tap(app.item_buttons.soap)
	expect(app.item_menu.visible and app.game.data.inventory.soap==1 and app.pet.action=="wash","bathing uses item and keeps menu")
	await tap(find_button(app.hud,"洗澡"))
	expect(not app.item_menu.visible,"same trigger closes menu")
	await tap(find_button(app.hud,"商店"))
	await wait(0.3)
	expect(app.modal.visible and app.panel_mode=="shop","shop modal opens")
	expect(app.panel.get_global_rect().get_center().distance_to(app.ui.size/2)<1,"ordinary modal centered")
	var close_pos=app.panel_close.get_global_rect()
	await capture("shop")
	await wheel(app.panel_scroll,14)
	expect(app.panel_scroll.scroll_vertical>0,"wheel scrolls long modal")
	expect(not app.panel_scroll.get_v_scroll_bar().visible,"scrollbar hidden")
	expect(app.panel_close.get_global_rect()==close_pos,"close button fixed while scrolling")
	await tap(app.panel_close)
	expect(not app.modal.visible,"top right close works")
	await tap(find_button(app.hud,"学习"))
	await wait(0.2)
	await capture("courses")
	app.game.data.food=0
	await tap(app.panel_body.find_child("sport",true,false))
	expect(app.modal.visible and app.panel_error.text.contains("饱食"),"failed task remains open with deficit")
	app.game.data.food=80
	app.game.data.clean=80
	await tap(app.panel_body.find_child("read",true,false))
	expect(not app.modal.visible and app.game.data.task.get("id")=="read","successful course selection closes modal")
	expect(app.task_box.visible and not app.idle_actions.visible,"task replaces study and work controls")
	await capture("active_task")
	await tap(find_button(app.hud,"喂食"))
	await tap(app.item_buttons.fish)
	expect(app.game.data.task.get("id")=="read" and app.pet.action=="feed","care does not interrupt task")
	var care_elapsed=app.game.data.task.elapsed
	await press_escape()
	await wait(app.pet.action_left+0.2)
	expect(app.pet.book.visible and app.pet.action.is_empty(),"care returns to study animation")
	expect(app.game.data.task.elapsed>care_elapsed+3,"study timer continues throughout feeding")
	await tap(find_button(app.hud,"洗澡"))
	await tap(app.item_buttons.soap)
	expect(app.game.data.task.get("id")=="read" and app.pet.action=="wash","bathing retains the active study task")
	await press_escape()
	await wait(app.pet.action_left+0.2)
	expect(app.pet.book.visible and app.pet.book.scale.is_equal_approx(Vector3.ONE) and app.pet.action.is_empty(),"bathing restores the original study pose and props")
	var original_level=app.game.data.level
	app.game.data.level=2
	await tap(app.info)
	await wait(0.3)
	await tap(find_button(app.panel_body,"转圈"))
	expect(not app.modal.visible and app.pet.action=="spin" and app.game.data.task.get("id")=="read","manual Lv2 spin starts without ending the task")
	var spin_elapsed=app.game.data.task.elapsed
	await wait(app.pet.action_left+0.2)
	expect(app.pet.action.is_empty() and app.pet.book.visible and app.pet.book.scale.is_equal_approx(Vector3.ONE),"stepping spin returns to the study pose")
	expect(app.game.data.task.elapsed>spin_elapsed+3,"study timer continues throughout the stepping spin")
	app.game.data.level=original_level
	var elapsed=app.game.data.task.elapsed
	await mouse(ground,true)
	await motion(ground+Vector2(60,0),Vector2(60,0))
	await mouse(ground+Vector2(60,0),false)
	await wait(0.6)
	expect(app.game.data.task.elapsed>elapsed and app.pet.book.visible,"task keeps running while rotated")
	app.pet.view_yaw=0
	app.game.data.task.elapsed=300
	await tap(app.task_end)
	await capture("end_task")
	await tap(find_button(app.panel_body,"确认结束"))
	expect(app.game.data.task.is_empty() and app.idle_actions.visible and not app.task_box.visible,"settlement restores action buttons")
	await tap(app.info)
	await wait(0.3)
	app.game.autosave=true
	expect(app.preview_pane.visible and app.tabs.visible and app.panel.size.x==1000,"profile has wider split layout")
	app.name_edit.grab_focus()
	app.name_edit.text="咕咕嘎嘎"
	app.name_edit.text_submitted.emit(app.name_edit.text)
	expect(app.game.data.name=="咕咕嘎嘎" and app.info.text.begins_with("咕咕嘎嘎"),"name saves on Enter")
	app.name_edit.grab_focus()
	app.name_edit.text="新名字"
	app.name_edit.release_focus()
	expect(app.game.data.name=="新名字","name saves on focus loss")
	app.name_edit.text="咕咕嘎嘎"
	await click(Vector2(10,350))
	expect(not app.modal.visible and app.game.data.name=="咕咕嘎嘎","outside closes profile and saves name")
	await tap(app.info)
	before=app.game.data.stats.duplicate(true)
	var preview_pos=app.preview_pane.get_global_rect().get_center()
	await mouse(preview_pos,true)
	await motion(preview_pos+Vector2(65,0),Vector2(65,0))
	await mouse(preview_pos+Vector2(65,0),false)
	expect(absf(app.preview_pet.view_yaw)>0.5 and is_zero_approx(app.pet.view_yaw),"preview rotates independently")
	expect(app.game.data.stats==before,"preview drag does not count as interaction")
	await tap(app.tab_buttons.achieve)
	await capture("achievements")
	await wheel(app.panel_scroll,30)
	expect(app.panel_scroll.scroll_vertical>0,"achievements scroll without visible bar")
	app.game.data.level=15
	app.refresh()
	await tap(app.tab_buttons.dress)
	await wait()
	await tap(find_button(app.panel_body,"小红帽"))
	expect(app.game.data.head=="redhat","dressing applies immediately")
	var saved=JSON.parse_string(JSON.parse_string(FileAccess.get_file_as_string(app.game.path)).payload)
	expect(saved.head=="redhat" and saved.name=="咕咕嘎嘎","name and dressing persist without confirmation")
	expect(absf(app.preview_pet.view_yaw)>0.5,"tab and dressing retain preview rotation")
	await capture("dress_preview")
	var suit=find_button(app.panel_body,"高雅人士")
	expect(suit.disabled and suit.text.contains("Lv.20"),"Lv20 suit shows unlock requirement")
	var section=false
	for child in app.panel_body.get_children():
		if child is Label and child.text=="套装":section=true
	expect(section,"dress page has suit section heading")
	app.game.data.level=20
	app.game.data.achievements.append("all60")
	app.game.data.achievements.append("jobs")
	app.set_profile_tab("dress")
	await wait()
	await wheel(app.panel_scroll,40)
	await tap(find_button(app.panel_body,"高雅人士"))
	await wait()
	expect(app.game.data.gold and app.pet.elegant_suit.visible and app.preview_pet.elegant_suit.visible,"suit updates main pet and preview instantly")
	expect(not app.pet.red_hood.visible and not app.preview_pet.red_hood.visible,"suit hides remembered headwear in both views")
	saved=JSON.parse_string(JSON.parse_string(FileAccess.get_file_as_string(app.game.path)).payload)
	expect(saved.gold and saved.head=="redhat","suit selection auto-saves with remembered accessory")
	expect(find_button(app.panel_body,"高雅人士").text.ends_with("✓"),"active suit marked selected")
	await capture("v120_suit_profile")
	await tap(find_button(app.panel_body,"高雅人士"))
	await wait()
	expect(not app.game.data.gold and app.pet.red_hood.visible and app.preview_pet.red_hood.visible,"clicking suit again restores accessories in both views")
	await tap(find_button(app.panel_body,"高雅人士"))
	await wait()
	app.panel_scroll.scroll_vertical=0
	await wait()
	await tap(find_button(app.panel_body,"小皇冠"))
	await wait()
	expect(not app.game.data.gold and not app.pet.elegant_suit.visible and not app.preview_pet.elegant_suit.visible,"headwear selection exits suit in both views")
	await wheel(app.panel_scroll,40)
	await tap(find_button(app.panel_body,"高雅人士"))
	await wait()
	app.panel_scroll.scroll_vertical=0
	await wait()
	await wheel(app.panel_scroll,6)
	await tap(find_button(app.panel_body,"小领结"))
	await wait()
	expect(not app.game.data.gold and app.pet.red_bow.visible and app.preview_pet.red_bow.visible,"neckwear selection exits suit in both views")
	await wheel(app.panel_scroll,40)
	await tap(find_button(app.panel_body,"高雅人士"))
	await wait()
	await press_escape()
	expect(not app.modal.visible and app.preview_pet.process_mode==Node.PROCESS_MODE_DISABLED,"Esc closes profile and suspends preview")
	await capture("v120_suit_home")
	await tap(find_button(app.hud,"打工"))
	await wait()
	await capture("jobs")
	await tap(app.panel_body.find_child("flyer",true,false))
	expect(app.game.data.task.get("id")=="flyer" and not app.modal.visible,"successful work selection closes modal")
	app.request_end()
	app.game.data.task.elapsed=900
	app.game.advance(app.now())
	expect(app.game.data.task.is_empty() and not app.modal.visible and app.idle_actions.visible,"natural completion dismisses stale end confirmation")
	root.size=Vector2i(960,540)
	await wait(0.3)
	await tap(app.info)
	await wait(0.3)
	expect(app.panel.get_global_rect().position.x>=0 and app.panel.get_global_rect().end.x<=app.ui.size.x,"profile fits minimum width")
	expect(app.panel.get_global_rect().position.y>=0 and app.panel.get_global_rect().end.y<=app.ui.size.y,"profile fits minimum height")
	await capture("small_profile")
	await press_escape()
	await tap(find_button(app.hud,"喂食"))
	expect(app.item_menu.get_global_rect().end.y<=app.ui.size.y,"item menu fits minimum height")
	await capture("small_menu")
	await press_escape()
	root.size=Vector2i(1000,800)
	await wait(0.3)
	await tap(find_button(app.hud,"商店"))
	await wait(0.3)
	await capture("letterbox_shop")
	expect(app.modal.visible,"UI works with non 16:9 window")
	print("UI_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed==0 else 1)
