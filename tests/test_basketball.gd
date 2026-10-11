extends "res://tests/test_ui.gd"

func run():
	app = load("res://main.tscn").instantiate()
	app.game.path = "res://tests/output/basketball-penguin.json"
	app.game.autosave = false
	root.add_child(app)
	app.game.data = app.game.fresh(app.now())
	app.game.adopt("篮球检查",app.now())
	app.game.data.food = 40.0
	app.game.data.clean = 40.0
	app.adopt_box.hide()
	app.refresh()
	app.pet.idle_left = 10000
	app.open_panel("study")
	app.panel_body.find_child("sport",true,false).pressed.emit()
	expect(app.game.data.task.id == "sport","sports starts through the real course UI")
	await wait(1.5)
	expect(app.pet.basketball.visible and not app.pet.book.visible,"real game shows basketball instead of a floating book")
	var clock = app.pet.basketball_clock
	await wait(0.6)
	expect(app.pet.basketball_clock>clock+0.3,"regular UI refresh does not reset the dribble")
	var elapsed = app.game.data.task.elapsed
	app.toggle_menu("food")
	var fish = app.game.data.inventory.fish
	app.item_buttons.fish.pressed.emit()
	await wait(0.6)
	expect(not app.pet.basketball.visible and app.pet.action == "feed","feeding puts away the basketball before lifting food")
	expect(app.game.data.inventory.fish == fish-1,"feeding consumes one item")
	await wait(5.2)
	expect(app.pet.basketball.visible and app.pet.action.is_empty(),"feeding restores basketball")
	expect(app.game.data.task.id == "sport" and app.game.data.task.elapsed>elapsed+5,"sports timer continues through feeding")
	elapsed = app.game.data.task.elapsed
	app.close_menu()
	app.toggle_menu("clean")
	app.item_buttons.soap.pressed.emit()
	await wait(0.6)
	expect(not app.pet.basketball.visible and app.pet.action == "wash","bathing puts away the basketball")
	await wait(3.2)
	expect(app.pet.basketball.visible and app.pet.action.is_empty(),"bathing restores basketball")
	expect(app.game.data.task.id == "sport" and app.game.data.task.elapsed>elapsed+3,"sports timer continues through bathing")
	app.close_menu()
	app.pet.perform("wing_l",1.8)
	await wait(0.5)
	expect(not app.pet.basketball.visible,"wing interaction clears the ball")
	await wait(1.7)
	expect(app.pet.basketball.visible,"wing interaction returns to dribbling")
	app.game.end_task(app.now())
	await wait(0.8)
	expect(app.game.data.task.is_empty() and not app.pet.basketball.visible,"ending the course removes the prop and returns to idle")
	var studied = app.game.data.stats.study
	expect(absf(app.game.data.power-2.0*studied/900.0)<0.00001,"power gain still uses real study time")
	expect(absf(app.game.data.coins-(610.0-5.0*studied/900.0))<0.00001,"tuition settlement still uses real study time")
	await capture("basketball_game_finished")
	print("BASKETBALL_GAME_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed == 0 else 1)
