extends "res://tests/test_ui.gd"

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
	expect(app.preview_pane.size.y>=180,"preview has useful height")
	expect(app.panel.get_global_rect().end.x<=app.ui.size.x,"profile fits portrait width")
	expect(app.panel_close.get_global_rect().end.x<=app.ui.size.x,"close stays on screen")
	await capture("portrait-profile")
	app.game.start_task("study","read",app.now())
	var elapsed=app.game.data.task.elapsed
	await tap(find_button(app.panel_body,"转圈"))
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
