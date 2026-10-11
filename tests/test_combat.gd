extends "res://tests/test_ui.gd"

func run():
	app = load("res://main.tscn").instantiate()
	app.game.path = "res://tests/output/combat-penguin.json"
	app.game.autosave = false
	root.add_child(app)
	app.game.data = app.game.fresh(app.now())
	app.game.adopt("沙袋检查",app.now())
	app.game.data.power = 60.0
	app.game.check_achievements()
	app.game.data.food = 40.0
	app.game.data.clean = 40.0
	app.adopt_box.hide()
	app.refresh()
	app.pet.idle_left = 10000
	var starting_coins = app.game.data.coins
	app.open_panel("study")
	app.panel_body.find_child("combat",true,false).pressed.emit()
	expect(app.game.data.task.id == "combat","combat course starts through the real course UI")
	await wait(1.5)
	expect(app.pet.combat_blend == 1.0 and app.pet.combat_root.visible and not app.pet.book.visible,"real game starts the combat routine without a floating book")
	expect(app.pet.bag_angle.length()>0.0001,"bag responds to actual alternating strikes")
	var clock = app.pet.combat_clock
	await wait(0.6)
	expect(app.pet.combat_clock>clock+0.3,"regular UI refresh does not reset the routine")
	var elapsed = app.game.data.task.elapsed
	app.toggle_menu("food")
	var fish = app.game.data.inventory.fish
	clock = app.pet.combat_clock
	app.item_buttons.fish.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "feed" and not app.pet.combat_root.visible and is_equal_approx(app.pet.combat_clock,clock),"feeding pauses the combat choreography before lifting food")
	expect(app.game.data.inventory.fish == fish-1,"feeding consumes one item")
	await wait(5.2)
	expect(app.pet.action.is_empty() and app.pet.combat_blend == 1.0 and app.pet.combat_root.visible,"feeding restores the combat routine")
	expect(app.game.data.task.id == "combat" and app.game.data.task.elapsed>elapsed+5,"course timer continues through feeding")
	elapsed = app.game.data.task.elapsed
	app.close_menu()
	app.toggle_menu("clean")
	app.item_buttons.soap.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "wash","bathing temporarily replaces the routine")
	await wait(3.2)
	expect(app.pet.action.is_empty() and app.pet.combat_blend == 1.0 and app.pet.combat_root.visible,"bathing restores the combat routine")
	expect(app.game.data.task.id == "combat" and app.game.data.task.elapsed>elapsed+3,"course timer continues through bathing")
	app.close_menu()
	app.pet.perform("wing_l",1.8)
	clock = app.pet.combat_clock
	await wait(0.5)
	expect(is_equal_approx(app.pet.combat_clock,clock),"wing interaction pauses the routine")
	await wait(1.7)
	expect(app.pet.action.is_empty() and app.pet.combat_clock>clock,"wing interaction returns to the routine")
	app.game.end_task(app.now())
	await wait(0.8)
	expect(app.game.data.task.is_empty() and is_zero_approx(app.pet.combat_blend) and not app.pet.combat_root.visible,"ending the course returns to idle")
	var studied = app.game.data.stats.study
	expect(absf(app.game.data.power-(60.0+12.0*studied/3600.0))<0.00001,"power gain still uses real study time")
	expect(absf(app.game.data.coins-(starting_coins-35.0*studied/3600.0))<0.00001,"tuition settlement still uses real study time")
	await capture("combat_game_finished")
	print("COMBAT_GAME_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed == 0 else 1)
