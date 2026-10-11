extends "res://tests/test_ui.gd"

func run():
	app = load("res://main.tscn").instantiate()
	app.game.path = "res://tests/output/manners-penguin.json"
	app.game.autosave = false
	root.add_child(app)
	app.game.data = app.game.fresh(app.now())
	app.game.adopt("礼仪检查",app.now())
	app.game.data.charm = 0.0
	app.game.check_achievements()
	app.game.data.food = 40.0
	app.game.data.clean = 40.0
	app.adopt_box.hide()
	app.refresh()
	app.pet.idle_left = 10000
	var starting_coins = app.game.data.coins
	app.open_panel("study")
	app.panel_body.find_child("manners",true,false).pressed.emit()
	expect(app.game.data.task.id == "manners","manners course starts through the real course UI")
	await wait(1.5)
	expect(app.pet.manners_blend == 1.0 and not app.pet.book.visible and app.pet.expression_weights.get("face_Base_obj_morph3",0.0)>0.5,"real game smiles and hides the old book")
	var clock = app.pet.manners_clock
	await wait(0.6)
	expect(app.pet.manners_blend == 1.0,"regular UI refresh does not reset the manners routine")
	expect(app.pet.manners_clock>clock+0.3,"regular UI refresh preserves the observation sequence")
	var elapsed = app.game.data.task.elapsed
	app.toggle_menu("food")
	var fish = app.game.data.inventory.fish
	clock = app.pet.manners_clock
	app.item_buttons.fish.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "feed" and app.pet.expression_weights.get("face_Base_obj_morph3",0.0)<0.01,"feeding pauses the manners routine before lifting food")
	expect(is_equal_approx(app.pet.manners_clock,clock),"feeding preserves the current observation phase")
	expect(app.game.data.inventory.fish == fish-1,"feeding consumes one item")
	await wait(5.2)
	expect(app.pet.action.is_empty() and app.pet.manners_blend == 1.0 ,"feeding restores the manners routine")
	expect(app.game.data.task.id == "manners" and app.game.data.task.elapsed>elapsed+5,"course timer continues through feeding")
	elapsed = app.game.data.task.elapsed
	app.close_menu()
	app.toggle_menu("clean")
	app.item_buttons.soap.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "wash","bathing temporarily replaces the manners routine")
	await wait(3.2)
	expect(app.pet.action.is_empty() and app.pet.manners_blend == 1.0 ,"bathing restores the manners routine")
	expect(app.game.data.task.id == "manners" and app.game.data.task.elapsed>elapsed+3,"course timer continues through bathing")
	app.close_menu()
	app.pet.perform("wing_l",1.8)
	await wait(0.5)
	expect(app.pet.expression_weights.get("face_Base_obj_morph3",0.0)<0.01,"wing interaction pauses the manners routine")
	await wait(1.7)
	expect(app.pet.action.is_empty() ,"wing interaction returns to the manners routine")
	app.game.end_task(app.now())
	await wait(0.8)
	expect(app.game.data.task.is_empty() and is_zero_approx(app.pet.manners_blend) and app.pet.expression_weights.get("face_Base_obj_morph3",0.0)<0.01,"ending the course returns to idle")
	var studied = app.game.data.stats.study
	expect(absf(app.game.data.charm-(2.0*studied/900.0))<0.00001,"charm gain still uses real study time")
	expect(absf(app.game.data.coins-(starting_coins-5.0*studied/900.0))<0.00001,"tuition settlement still uses real study time")
	await capture("manners_game_finished")
	print("MANNERS_GAME_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed == 0 else 1)
