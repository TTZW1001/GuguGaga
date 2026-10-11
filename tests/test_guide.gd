extends "res://tests/test_ui.gd"

func run():
	app = load("res://main.tscn").instantiate()
	app.game.path = "res://tests/output/guide-penguin.json"
	app.game.autosave = false
	root.add_child(app)
	app.game.data = app.game.fresh(app.now())
	app.game.adopt("导游检查",app.now())
	app.game.data.charm = 60.0
	app.game.data.food = 70.0
	app.game.data.clean = 70.0
	app.game.check_achievements()
	app.adopt_box.hide()
	app.refresh()
	app.pet.idle_left = 10000
	var starting_coins = app.game.data.coins
	app.open_panel("work")
	var work_button = app.panel_body.find_child("idol",true,false)
	var work_title = work_button.get_parent().get_child(0).get_child(0)
	expect("导游" in work_title.text,"work menu shows the guide job")
	work_button.pressed.emit()
	expect(app.game.data.task.id == "idol","guide job starts through the real work UI with the existing charm requirement")
	expect(app.game.valid(app.game.data),"existing guide task ID remains valid in saves")
	var resumed = load("res://scripts/state.gd").new()
	resumed.autosave = false
	resumed.data = app.game.parse_json(JSON.stringify(app.game.data))
	resumed.advance(app.now()+1.0,true)
	expect(resumed.data.task.id == "idol" and resumed.data.task.elapsed>=1.0,"saved work resumes under the existing ID")
	await wait(1.5)
	expect(app.pet.guide_blend == 1.0 and not app.pet.props.visible,"real game raises a red flag and marches")
	var clock = app.pet.guide_clock
	await wait(0.6)
	expect(app.pet.guide_blend == 1.0,"regular UI refresh does not reset the guide pose")
	expect(app.pet.guide_clock>clock+0.3,"regular UI refresh preserves the marching cycle")
	var elapsed = app.game.data.task.elapsed
	app.toggle_menu("food")
	var fish = app.game.data.inventory.fish
	clock = app.pet.guide_clock
	app.item_buttons.fish.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "feed","feeding pauses the guide pose before lifting food")
	expect(is_equal_approx(app.pet.guide_clock,clock),"feeding preserves the current marching phase")
	expect(app.game.data.inventory.fish == fish-1,"feeding consumes one item")
	await wait(5.2)
	expect(app.pet.action.is_empty() and app.pet.guide_blend == 1.0,"feeding restores the guide pose")
	expect(app.game.data.task.id == "idol" and app.game.data.task.elapsed>elapsed+5,"work timer continues through feeding")
	elapsed = app.game.data.task.elapsed
	app.close_menu()
	app.toggle_menu("clean")
	app.item_buttons.soap.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "wash","bathing temporarily replaces the guide pose")
	await wait(3.2)
	expect(app.pet.action.is_empty() and app.pet.guide_blend == 1.0,"bathing restores the guide pose")
	expect(app.game.data.task.id == "idol" and app.game.data.task.elapsed>elapsed+3,"work timer continues through bathing")
	app.close_menu()
	clock = app.pet.guide_clock
	app.pet.perform("wing_l",1.8)
	await wait(0.5)
	expect(is_equal_approx(app.pet.guide_clock,clock),"wing interaction pauses the guide pose")
	await wait(1.7)
	expect(app.pet.action.is_empty(),"wing interaction returns to the guide pose")
	app.game.end_task(app.now())
	await wait(0.8)
	expect(app.game.data.task.is_empty() and is_zero_approx(app.pet.guide_blend),"ending the work returns to idle")
	var worked = app.game.data.stats.work
	expect(app.game.data.power == 0.0 and app.game.data.mind == 0.0 and app.game.data.charm == 60.0,"work does not change attribute requirements or rewards")
	expect(absf(app.game.data.coins-(starting_coins+120.0*worked/3600.0))<0.00001,"wage settlement still uses real work time")
	if DisplayServer.get_name() != "headless": await capture("guide_game_finished")
	print("GUIDE_GAME_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed == 0 else 1)
