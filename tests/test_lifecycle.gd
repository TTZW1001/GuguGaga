extends "res://tests/test_ui.gd"

class ClockApp:
	extends "res://scripts/main.gd"
	var clock=1800000000.0
	func now() -> float:return clock

func run():
	app=ClockApp.new()
	app.game.path="res://tests/output/lifecycle-penguin.json"
	app.settings_path="res://tests/output/lifecycle-settings.cfg"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(app.game.path+suffix):DirAccess.remove_absolute(app.game.path+suffix)
	root.add_child(app)
	app.game.adopt("后台小嘎嘎",app.now())
	app.adopt_box.hide()
	app.game.start_task("study","read",app.now())
	app.clock+=300
	app.pressing=true
	app.rotating=true
	app.preview_dragging=true
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	expect(app.application_paused and Engine.max_fps==15,"pause lowers frame cap even before focus-out")
	expect(not app.pressing and not app.rotating and not app.preview_dragging,"pause cancels unfinished gestures")
	expect(is_equal_approx(app.game.data.task.elapsed,300),"pause saves current task progress")
	var saved=app.State.new()
	saved.path=app.game.path
	expect(saved.load_game(app.now()) and is_equal_approx(saved.data.task.elapsed,300),"pause persisted a valid save")
	app.update_mobile_activity()
	expect(app.pet.process_mode==Node.PROCESS_MODE_DISABLED and app.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"mobile pause suspends model and 3D rendering")
	app.clock+=601
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	app.update_mobile_activity()
	expect(not app.application_paused and Engine.max_fps==app.preferences.fps,"resume restores chosen frame cap")
	expect(app.pet.process_mode==Node.PROCESS_MODE_INHERIT and app.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"mobile resume restores main model and rendering")
	expect(app.game.data.task.is_empty() and app.game.data.stats.full_study==1 and is_equal_approx(app.game.data.mind,2),"resume settles completed course once")
	var coins=app.game.data.coins
	var xp=app.game.data.xp
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	expect(app.game.data.coins==coins and app.game.data.xp==xp and app.game.data.stats.full_study==1,"duplicate resume/focus notifications never repeat rewards")
	expect(saved.load_game(app.now()) and saved.data.coins==coins and saved.data.task.is_empty(),"resume persists settlement before another process restart")
	app.open_panel("profile")
	app.name_edit.text="恢复小嘎嘎"
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(saved.load_game(app.now()) and saved.data.name=="恢复小嘎嘎","backgrounding saves an unsubmitted nickname")
	app.update_mobile_activity()
	expect(app.preview_pet.process_mode==Node.PROCESS_MODE_DISABLED,"background suspends visible profile preview")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app.update_mobile_activity()
	expect(app.preview_pet.process_mode==Node.PROCESS_MODE_INHERIT,"foreground restores visible profile preview")
	app.close_panel()
	app.update_mobile_activity()
	expect(app.preview_pet.process_mode==Node.PROCESS_MODE_DISABLED,"closed preview stays suspended")
	# Preserve 1.3.2's distinction between a running session and a closed game.
	app.game.data.food=100
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.clock+=43200
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	expect(is_equal_approx(app.game.data.food,64),"long paused session preserves existing real-time decay")
	app.game.data.food=100
	app.game.save()
	expect(saved.load_game(app.now()+43200) and is_equal_approx(saved.data.food,76),"process restart preserves eight-hour offline decay cap")
	print("LIFECYCLE_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed==0 else 1)
