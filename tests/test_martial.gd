extends "res://tests/test_ui.gd"

func run():
	app = load("res://main.tscn").instantiate()
	app.game.path = "res://tests/output/martial-penguin.json"
	app.game.autosave = false
	root.add_child(app)
	app.game.data = app.game.fresh(app.now())
	app.game.adopt("五步拳检查",app.now())
	app.game.data.power = 20.0
	app.game.data.food = 40.0
	app.game.data.clean = 40.0
	app.adopt_box.hide()
	app.refresh()
	app.pet.idle_left = 10000
	var starting_coins = app.game.data.coins
	app.open_panel("study")
	app.panel_body.find_child("martial",true,false).pressed.emit()
	expect(app.game.data.task.id == "martial","martial course starts through the real course UI")
	await wait(1.5)
	expect(app.pet.martial_blend == 1.0 and not app.pet.book.visible,"real game starts the martial routine without a floating book")
	var clock = app.pet.martial_clock
	await wait(0.6)
	expect(app.pet.martial_clock>clock+0.3,"regular UI refresh does not reset the routine")
	var elapsed = app.game.data.task.elapsed
	app.toggle_menu("food")
	var fish = app.game.data.inventory.fish
	clock = app.pet.martial_clock
	app.item_buttons.fish.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "feed" and is_equal_approx(app.pet.martial_clock,clock),"feeding pauses the martial choreography before lifting food")
	expect(app.game.data.inventory.fish == fish-1,"feeding consumes one item")
	await wait(5.2)
	expect(app.pet.action.is_empty() and app.pet.martial_blend == 1.0,"feeding restores the martial routine")
	expect(app.game.data.task.id == "martial" and app.game.data.task.elapsed>elapsed+5,"course timer continues through feeding")
	elapsed = app.game.data.task.elapsed
	app.close_menu()
	app.toggle_menu("clean")
	app.item_buttons.soap.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "wash","bathing temporarily replaces the routine")
	await wait(3.2)
	expect(app.pet.action.is_empty() and app.pet.martial_blend == 1.0,"bathing restores the martial routine")
	expect(app.game.data.task.id == "martial" and app.game.data.task.elapsed>elapsed+3,"course timer continues through bathing")
	app.close_menu()
	app.pet.perform("wing_l",1.8)
	clock = app.pet.martial_clock
	await wait(0.5)
	expect(is_equal_approx(app.pet.martial_clock,clock),"wing interaction pauses the routine")
	await wait(1.7)
	expect(app.pet.action.is_empty() and app.pet.martial_clock>clock,"wing interaction returns to the routine")
	app.game.end_task(app.now())
	await wait(0.8)
	expect(app.game.data.task.is_empty() and is_zero_approx(app.pet.martial_blend),"ending the course returns to idle")
	var studied = app.game.data.stats.study
	expect(absf(app.game.data.power-(20.0+5.0*studied/1800.0))<0.00001,"power gain still uses real study time")
	expect(absf(app.game.data.coins-(starting_coins-15.0*studied/1800.0))<0.00001,"tuition settlement still uses real study time")
	await capture("martial_game_finished")
	print("MARTIAL_GAME_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed == 0 else 1)
