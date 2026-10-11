extends "res://tests/test_ui.gd"

func run():
	app = load("res://main.tscn").instantiate()
	app.game.path = "res://tests/output/math-penguin.json"
	app.game.autosave = false
	root.add_child(app)
	app.game.data = app.game.fresh(app.now())
	app.game.adopt("算盘检查",app.now())
	app.game.data.mind = 20.0
	app.game.check_achievements()
	app.game.data.food = 40.0
	app.game.data.clean = 40.0
	app.adopt_box.hide()
	app.refresh()
	app.pet.idle_left = 10000
	var starting_coins = app.game.data.coins
	app.open_panel("study")
	app.panel_body.find_child("math",true,false).pressed.emit()
	expect(app.game.data.task.id == "math","math course starts through the real course UI")
	await wait(1.5)
	expect(app.pet.math_blend == 1.0 and app.pet.abacus.visible and app.pet.abacus.position.z>0.25,"real game raises both wings and holds the abacus farther from the belly")
	var book_position = app.pet.abacus.position
	var clock = app.pet.math_clock
	await wait(0.6)
	expect(app.pet.abacus.position.is_equal_approx(book_position),"regular UI refresh does not reset the abacus pose")
	expect(app.pet.math_clock>clock+0.3,"regular UI refresh preserves the bead sequence")
	var elapsed = app.game.data.task.elapsed
	app.toggle_menu("food")
	var fish = app.game.data.inventory.fish
	clock = app.pet.math_clock
	app.item_buttons.fish.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "feed" and not app.pet.abacus.visible,"feeding pauses the abacus pose before lifting food")
	expect(is_equal_approx(app.pet.math_clock,clock),"feeding preserves the current calculation phase")
	expect(app.game.data.inventory.fish == fish-1,"feeding consumes one item")
	await wait(5.2)
	expect(app.pet.action.is_empty() and app.pet.math_blend == 1.0 and app.pet.abacus.visible,"feeding restores the abacus pose")
	expect(app.game.data.task.id == "math" and app.game.data.task.elapsed>elapsed+5,"course timer continues through feeding")
	elapsed = app.game.data.task.elapsed
	app.close_menu()
	app.toggle_menu("clean")
	app.item_buttons.soap.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "wash","bathing temporarily replaces the abacus pose")
	await wait(3.2)
	expect(app.pet.action.is_empty() and app.pet.math_blend == 1.0 and app.pet.abacus.visible,"bathing restores the abacus pose")
	expect(app.game.data.task.id == "math" and app.game.data.task.elapsed>elapsed+3,"course timer continues through bathing")
	app.close_menu()
	app.pet.perform("wing_l",1.8)
	await wait(0.5)
	expect(not app.pet.abacus.visible,"wing interaction pauses the abacus pose")
	await wait(1.7)
	expect(app.pet.action.is_empty() and app.pet.abacus.visible,"wing interaction returns to the abacus pose")
	app.game.end_task(app.now())
	await wait(0.8)
	expect(app.game.data.task.is_empty() and is_zero_approx(app.pet.math_blend) and not app.pet.abacus.visible,"ending the course returns to idle")
	var studied = app.game.data.stats.study
	expect(absf(app.game.data.mind-(20.0+5.0*studied/1800.0))<0.00001,"intelligence gain still uses real study time")
	expect(absf(app.game.data.coins-(starting_coins-15.0*studied/1800.0))<0.00001,"tuition settlement still uses real study time")
	await capture("math_game_finished")
	print("MATH_GAME_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed == 0 else 1)
