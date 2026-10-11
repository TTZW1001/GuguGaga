extends "res://tests/test_ui.gd"

func run():
	app = load("res://main.tscn").instantiate()
	app.game.path = "res://tests/output/lyrics-penguin.json"
	app.game.autosave = false
	root.add_child(app)
	app.game.data = app.game.fresh(app.now())
	app.game.adopt("作词检查",app.now())
	app.game.data.charm = 60.0
	app.game.check_achievements()
	app.game.data.food = 40.0
	app.game.data.clean = 40.0
	app.adopt_box.hide()
	app.refresh()
	app.pet.idle_left = 10000
	var starting_coins = app.game.data.coins
	app.open_panel("study")
	var course_button = app.panel_body.find_child("stage",true,false)
	var course_title = course_button.get_parent().get_child(0).get_child(0)
	expect("作词课" in course_title.text,"course menu shows the new name")
	course_button.pressed.emit()
	expect(app.game.data.task.id == "stage","lyric course starts through the real course UI")
	expect(app.game.valid(app.game.data),"existing stage task ID remains valid in saves")
	var resumed = load("res://scripts/state.gd").new()
	resumed.autosave = false
	resumed.data = app.game.parse_json(JSON.stringify(app.game.data))
	resumed.advance(app.now()+1.0,true)
	expect(resumed.data.task.id == "stage" and resumed.data.task.elapsed>=1.0,"saved course resumes under the existing ID")
	await wait(1.5)
	expect(app.pet.lyrics_blend == 1.0 and app.pet.lyric_notebook.visible and app.pet.lyric_pen.visible and not app.pet.book.visible,"real game holds a notebook and writes with the other wing")
	var clock = app.pet.lyrics_clock
	await wait(0.6)
	expect(app.pet.lyric_notebook.visible and app.pet.lyrics_blend == 1.0,"regular UI refresh does not reset the lyric_notebook pose")
	expect(app.pet.lyrics_clock>clock+0.3,"regular UI refresh preserves the writing sequence")
	var elapsed = app.game.data.task.elapsed
	app.toggle_menu("food")
	var fish = app.game.data.inventory.fish
	clock = app.pet.lyrics_clock
	app.item_buttons.fish.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "feed" and not app.pet.lyric_notebook.visible and not app.pet.lyric_pen.visible,"feeding pauses the lyric_notebook pose before lifting food")
	expect(is_equal_approx(app.pet.lyrics_clock,clock),"feeding preserves the current writing phase")
	expect(app.game.data.inventory.fish == fish-1,"feeding consumes one item")
	await wait(5.2)
	expect(app.pet.action.is_empty() and app.pet.lyrics_blend == 1.0 and app.pet.lyric_notebook.visible,"feeding restores the lyric_notebook pose")
	expect(app.game.data.task.id == "stage" and app.game.data.task.elapsed>elapsed+5,"course timer continues through feeding")
	elapsed = app.game.data.task.elapsed
	app.close_menu()
	app.toggle_menu("clean")
	app.item_buttons.soap.pressed.emit()
	await wait(0.6)
	expect(app.pet.action == "wash","bathing temporarily replaces the lyric_notebook pose")
	await wait(3.2)
	expect(app.pet.action.is_empty() and app.pet.lyrics_blend == 1.0 and app.pet.lyric_notebook.visible,"bathing restores the lyric_notebook pose")
	expect(app.game.data.task.id == "stage" and app.game.data.task.elapsed>elapsed+3,"course timer continues through bathing")
	app.close_menu()
	app.pet.perform("wing_l",1.8)
	await wait(0.5)
	expect(not app.pet.lyric_notebook.visible,"wing interaction pauses the lyric_notebook pose")
	await wait(1.7)
	expect(app.pet.action.is_empty() and app.pet.lyric_notebook.visible,"wing interaction returns to the lyric_notebook pose")
	app.game.end_task(app.now())
	await wait(0.8)
	expect(app.game.data.task.is_empty() and is_zero_approx(app.pet.lyrics_blend) and not app.pet.lyric_notebook.visible and not app.pet.lyric_pen.visible,"ending the course returns to idle")
	var studied = app.game.data.stats.study
	expect(absf(app.game.data.charm-(60.0+12.0*studied/3600.0))<0.00001,"charm gain still uses real study time")
	expect(absf(app.game.data.coins-(starting_coins-35.0*studied/3600.0))<0.00001,"tuition settlement still uses real study time")
	await capture("lyrics_game_finished")
	print("LYRICS_GAME_TESTS ",checks," checks, ",failed," failures")
	quit(0 if failed == 0 else 1)
