extends "res://tests/test_ui.gd"

func run():
	app=load("res://main.tscn").instantiate()
	app.settings_path="res://tests/output/preferences.cfg"
	if FileAccess.file_exists(app.settings_path):DirAccess.remove_absolute(app.settings_path)
	app.game.path="res://tests/output/preferences-penguin.json"
	app.game.autosave=false
	root.add_child(app)
	app.game.data=app.game.fresh(app.now())
	app.game.adopt("预览小嘎嘎",app.now())
	app.adopt_box.hide()
	app.pet.idle_left=1000000
	app.pet.perform("",1)
	app.pet.action_left=0
	await wait(0.4)
	app.game.data.level=7
	app.game.data.xp=126
	app.refresh()
	expect(app.xp_label.text=="126 / 717","header shows current and required XP")
	expect(app.info.text=="预览小嘎嘎","name has no extra arrow")
	await capture("xp_header")
	app.game.data.level=20
	app.refresh()
	expect(app.xp_label.text=="已满级" and app.xp_bar.value==100,"max level avoids invalid next XP")
	app.open_panel("settings")
	await wait(0.3)
	expect(app.settings_tabs.visible and not app.tabs.visible and not app.preview_pane.visible,"settings has its own tabs")
	expect(app.settings_buttons.general.button_pressed and not app.settings_buttons.about.button_pressed,"general selected initially")
	expect(app.panel.size==Vector2(760,520),"settings keeps standard modal size")
	await capture("settings_general")
	var fps=app.panel_body.find_child("FrameLimit",true,false)
	var saving=app.panel_body.find_child("BackgroundSaving",true,false)
	app.window_focused=true
	fps.select(0)
	fps.item_selected.emit(0)
	expect(Engine.max_fps==30 and app.preferences.fps==30,"frame cap changes immediately")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(Engine.max_fps==15,"background saving lowers frame cap")
	saving.button_pressed=false
	expect(Engine.max_fps==30 and not app.preferences.background_saving,"background saving can be disabled")
	saving.button_pressed=true
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(Engine.max_fps==30,"returning to foreground restores chosen cap")
	fps.select(1)
	fps.item_selected.emit(1)
	var sizes=app.panel_body.find_child("WindowSize",true,false)
	for i in range(1,sizes.item_count):
		var width=sizes.get_item_id(i)
		sizes.select(i)
		sizes.item_selected.emit(i)
		await wait(0.2)
		expect(root.size==Vector2i(width,width*9/16),"window preset applies "+str(width))
		break
	var reloaded=load("res://main.tscn").instantiate()
	reloaded.settings_path=app.settings_path
	reloaded.load_preferences()
	expect(reloaded.preferences==app.preferences,"settings reload without touching pet save")
	reloaded.free()
	await tap(find_button(app.panel_body,"恢复默认窗口"))
	await wait(0.3)
	expect(app.preferences.window_width==0 and root.size.x*9==root.size.y*16,"reset restores adaptive 16:9 default")
	var close_rect=app.panel_close.get_global_rect()
	await tap(app.settings_buttons.about)
	await wait()
	await capture("settings_about")
	var urls=[]
	for child in app.panel_body.get_children():
		if child is LinkButton:urls.append(child.tooltip_text)
	expect("https://github.com/TTZW1001/GuguGaga" in urls,"about links to actual repository")
	expect("https://www.bilibili.com/video/BV15WD9BPEPR/" in urls,"about includes user supplied model source")
	expect("https://www.deviantart.com/bunglescrungle/art/BanG-Dream-MyGO-FBX-and-PMX-DL-1036304336" in urls,"about credits original head model source separately")
	expect("https://creativecommons.org/licenses/by/4.0/" in urls,"about includes body license")
	expect("https://godotengine.org/license/" in urls,"about includes engine license")
	await wheel(app.panel_scroll,40)
	expect(app.panel_scroll.scroll_vertical>0 and not app.panel_scroll.get_v_scroll_bar().visible,"about credits scroll without explicit bar")
	expect(app.panel_close.get_global_rect()==close_rect,"settings close stays fixed across tabs and scroll")
	await capture("settings_credits")
	await click(Vector2(10,350))
	expect(not app.modal.visible,"outside click closes settings")
	app.game.data.food=90
	app.game.data.clean=90
	app.game.data.coins=1000
	app.refresh()
	expect(app.game.start_task("study","read",app.now()).is_empty(),"study fixture starts")
	app.open_panel("profile")
	app.set_profile_tab("profile")
	await wait(0.3)
	var stats=app.game.data.stats.duplicate(true)
	var inventory=app.game.data.inventory.duplicate(true)
	var achievements=app.game.data.achievements.duplicate()
	var elapsed=app.game.data.task.elapsed
	var preview_events={"count":0}
	app.preview_pet.idle_seen.connect(func():preview_events.count+=1)
	app.preview_pet.view_yaw=0.7
	for action in app.C.ACTIONS:
		var action_button=find_button(app.panel_body,action[1])
		app.panel_scroll.ensure_control_visible(action_button)
		await wait()
		await tap(action_button)
		expect(app.modal.visible and app.preview_pet.action==action[0],"preview plays "+action[0])
		expect(app.pet.action.is_empty() and app.pet.task_kind=="study" and app.pet.task_id=="read","main study stays active during "+action[0])
		await wait(0.4)
	await capture("profile_action_preview")
	app.preview_pet.idle_left=0
	await wait(app.preview_pet.action_left+0.3)
	expect(app.preview_pet.action.is_empty() and preview_events.count==0,"preview finishes once and never starts autonomous actions")
	var after_stats=app.game.data.stats.duplicate(true)
	# Study time should increase; preview itself must not award any counters.
	stats.erase("study")
	after_stats.erase("study")
	expect(after_stats==stats and app.game.data.inventory==inventory and app.game.data.achievements==achievements,"preview leaves interaction counters and rewards unchanged")
	expect(app.game.data.task.elapsed>elapsed+3,"real task continues during preview")
	expect(is_equal_approx(app.preview_pet.view_yaw,0.7),"preview playback preserves viewing angle")
	app.preview_action("spin",2)
	await tap(app.tab_buttons.dress)
	expect(app.preview_pet.action.is_empty() and is_equal_approx(app.preview_pet.view_yaw,0.7),"tab change stops action and retains angle")
	app.set_profile_tab("profile")
	app.preview_action("dance",5)
	app.close_panel()
	expect(app.preview_pet.action.is_empty() and app.preview_pet.process_mode==Node.PROCESS_MODE_DISABLED,"closing cancels preview and suspends it")
	app.game.end_task(app.now())
	var pools={1:[],2:["spin"],5:["spin","dance"],10:["spin","dance","celebrate"]}
	for level in pools:
		app.game.data.level=level
		app.refresh()
		expect(app.pet.unlocked_idle_actions==pools[level],"idle pool honors level "+str(level))
		app.pet.rng.seed=713
		var found=[]
		var only_unlocked=true
		for i in 180:
			app.pet.perform("",1)
			app.pet.action_left=0
			app.pet.idle_left=0
			app.pet._process(0.001)
			if app.pet.action in ["spin","dance","celebrate"]:
				only_unlocked=only_unlocked and app.pet.action in pools[level]
				if not app.pet.action in found:found.append(app.pet.action)
		expect(only_unlocked,"random idle never picks a locked action at level "+str(level))
		for id in pools[level]:expect(id in found,"unlocked action can occur naturally: "+id)
	app.pet.perform("feed",5)
	app.pet.idle_left=0
	app.pet._process(0.01)
	expect(app.pet.action=="feed","random idle does not replace a care action")
	app.pet.perform("",1)
	app.pet.action_left=0
	app.pet.update_task("study","read")
	app.pet.idle_left=0
	app.pet._process(0.01)
	expect(app.pet.action.is_empty() and app.pet.task_kind=="study" and app.pet.task_id=="read","random idle does not interrupt a task")
	app.pet.update_task("","")
	app.pet.idle_left=1000000
	root.size=Vector2i(960,540)
	app.open_panel("settings")
	app.set_settings_tab("about")
	await wait(0.3)
	expect(app.panel.get_global_rect().end.x<=app.ui.size.x and app.panel.get_global_rect().end.y<=app.ui.size.y,"settings fits minimum window")
	await capture("small_settings")
	app.close_panel()
	print("PREFERENCES_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed==0 else 1)
