extends "res://tests/test_ui.gd"

func expect_compact(control: Control, title: String, max_height: float=0.60):
	var rect=control.get_global_rect()
	expect(rect.size.x<=app.ui.size.x*0.84,title+" leaves horizontal margins")
	expect(rect.size.y<=app.ui.size.y*max_height,title+" leaves vertical margins")
	expect(rect.get_center().distance_to(app.ui.size/2)<1,title+" stays centered")

func run():
	app=load("res://main.tscn").instantiate()
	app.game.path="res://tests/output/portrait-penguin.json"
	app.settings_path="res://tests/output/portrait-settings.cfg"
	app.game.autosave=false
	root.add_child(app)
	app.game.data=app.game.fresh(app.now())
	app.game.adopt("小嘎嘎",app.now())
	app.adopt_box.hide()
	app.pet.autonomous_idle=false
	app.pet.idle_left=1000000
	app.pet.target=Vector3.ZERO
	app.pet.position=Vector3.ZERO
	app.pet.perform("",1)
	app.pet.action_left=0
	app.game.data.level=7
	app.game.data.xp=126
	app.game.data.food=82
	app.game.data.clean=91
	app.game.data.mood=96
	app.refresh()
	app.toast.text=""
	app.toast_time=0
	await wait(0.5)
	expect(app.portrait and root.size.x<root.size.y,"portrait platform selected")
	expect(app.statuses.get_global_rect().end.y<app.info.position.y,"status row precedes identity")
	expect(app.toolbar.get_child(0).size.x>=84,"care controls have finger sized widths")
	expect(app.stage.size.y>app.ui.size.y*0.45,"pet retains primary display space")
	await capture("portrait-home")
	await tap(app.info)
	await wait(0.3)
	expect(app.preview_pane.get_global_rect().end.y<=app.tabs.get_global_rect().position.y,"preview above tabs")
	expect(app.preview_pane.size.y>=120,"compact preview has useful height")
	expect_compact(app.panel,"profile")
	expect(app.panel.get_global_rect().end.x<=app.ui.size.x,"profile fits portrait width")
	expect(app.panel_close.get_global_rect().end.x<=app.ui.size.x,"close stays on screen")
	await capture("portrait-profile")
	var preview_rect=app.preview_pane.get_global_rect()
	var tabs_rect=app.tabs.get_global_rect()
	var close_rect=app.panel_close.get_global_rect()
	# Desktop exercises the scrolling region with a wheel; actual finger input
	# is exercised separately through ADB on the Android preview package.
	await wheel(app.panel_scroll,6)
	expect(app.panel_scroll.scroll_vertical>0,"lower profile content scrolls")
	expect(app.preview_pane.get_global_rect()==preview_rect,"model area stays fixed while content scrolls")
	expect(app.tabs.get_global_rect()==tabs_rect,"profile tabs stay fixed while content scrolls")
	expect(app.panel_close.get_global_rect()==close_rect,"close stays fixed while content scrolls")
	await capture("portrait-profile-scrolled")
	app.game.start_task("study","read",app.now())
	var elapsed=app.game.data.task.elapsed
	var spin=find_button(app.panel_body,"转圈")
	app.panel_scroll.ensure_control_visible(spin)
	await wait()
	await tap(spin)
	expect(app.preview_pet.action=="spin" and app.pet.task_id=="read","portrait preview leaves task running")
	await wait(0.7)
	expect(app.game.data.task.elapsed>elapsed,"preview does not pause real time")
	await tap(app.tab_buttons.dress)
	await wait(0.2)
	await tap(find_button(app.panel_body,"小红帽"))
	expect(app.game.data.head=="redhat" and app.preview_pet.red_hood.visible,"outfit updates stacked preview")
	await capture("portrait-dress")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	expect(not app.modal.visible,"Android back dismisses profile before exiting")
	await wait(0.2)
	await capture("portrait-task")
	app.request_end()
	await wait(0.3)
	expect_compact(app.panel,"end task",0.36)
	await capture("portrait-end")
	app.close_panel()
	app.game.end_task(app.now())
	for mode in ["shop","study","work","settings"]:
		app.open_panel(mode)
		await wait(0.3)
		expect_compact(app.panel,mode,0.50)
		await capture("portrait-"+mode)
		if mode=="settings":
			expect(not app.panel_body.find_child("WindowSize",true,false),"mobile settings omit PC window size")
			app.set_settings_tab("about")
			await wait(0.2)
			expect_compact(app.panel,"about",0.50)
			await capture("portrait-about")
		app.close_panel()
	for mode in ["food","clean"]:
		app.toggle_menu(mode)
		await wait(0.3)
		expect_compact(app.item_menu,mode,0.55)
		await capture("portrait-"+mode)
		var item="fish" if mode=="food" else "soap"
		app.game.data["food" if mode=="food" else "clean"]=60.0
		var stock=app.game.data.inventory[item]
		await tap(app.item_buttons[item])
		expect(app.game.data.inventory[item]==stock-1 and app.item_menu.visible,mode+" stays open after use")
		await click(Vector2(20,app.ui.size.y/2))
		expect(not app.item_menu.visible,mode+" closes on outside tap")
	for size_ in [Vector2i(360,640),Vector2i(432,960),Vector2i(600,960)]:
		root.size=size_
		await wait(0.3)
		app.open_panel("profile")
		await wait(0.2)
		expect(app.panel.get_global_rect().position.x>=0 and app.panel.get_global_rect().end.x<=app.ui.size.x,"profile fits "+str(size_))
		expect(app.panel.get_global_rect().end.y<=app.ui.size.y,"profile height fits "+str(size_))
		await capture("portrait-profile-"+str(size_.x)+"x"+str(size_.y))
		app.close_panel()
	print("PORTRAIT_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed==0 else 1)
