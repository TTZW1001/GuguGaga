extends SceneTree
const State = preload("res://scripts/state.gd")
const C = preload("res://scripts/catalog.gd")
var checks = 0
var failures: Array[String] = []
const T = 1800000000.0

func _initialize():
	call_deferred("run")

func expect(ok: bool, title: String):
	checks += 1
	if not ok:
		failures.append(title)
		printerr("FAIL ",title)

func near(a: float,b: float,title: String):
	expect(absf(a-b)<0.00001,title+" got="+str(a)+" expected="+str(b))

func make() -> RefCounted:
	var s = State.new()
	s.autosave = false
	s.data = s.fresh(T)
	s.adopt("团团",T)
	return s

func run():
	var s = make()
	expect(s.data.name=="团团" and s.data.level==1 and s.data.adopted,"adoption")
	near(s.data.coins,610,"500 initial plus two automatic achievements")
	expect(s.data.inventory.fish==3 and s.data.inventory.soap==2,"initial inventory")
	s.adopt("new",T)
	expect(s.data.name=="团团","adoption idempotence")
	s.check_achievements()
	near(s.data.coins,610,"achievement idempotence")
	expect(s.use_item("fish",T)!="","full stats do not waste item")
	s.data.food=40
	expect(s.use_item("fish",T)=="","feeding")
	near(s.data.food,80,"food restore")
	expect(s.data.inventory.fish==2 and s.data.stats.feed==1,"feeding inventory/count")
	s.data.clean=50
	s.use_item("soap",T)
	near(s.data.clean,75,"wash restore")
	expect(s.data.stats.wash==1 and s.data.inventory.soap==1,"bath inventory/count")
	var money = s.data.coins
	s.buy("bread",T)
	near(s.data.coins,money-10,"purchase charge")
	expect(s.data.inventory.bread==1,"purchase inventory")
	s.data.coins=0
	expect(s.buy("bread",T)!="" and s.data.inventory.bread==1,"no overspending")
	s = make()
	s.data.food=0
	s.data.clean=0
	var missing = s.start_task("study","combat",T)
	expect("武力" in missing and "饱食" in missing and "清洁" in missing,"specific missing requirements")
	s = make()
	s.data.coins=5
	expect(s.start_task("study","read",T)=="","escrow course starts")
	near(s.data.coins,0,"full escrow reserved")
	expect(s.buy("bread",T)!="","escrow cannot be spent")
	s.advance(T+300)
	near(s.data.task.elapsed,300,"1/3 task progress")
	near(s.data.food,100-0.25-5.0/3,"gradual food spending")
	near(s.data.clean,100-1.0/6-1,"gradual clean spending")
	s.end_task(T+300)
	near(s.data.coins,10.0/3,"unused tuition refunded")
	near(s.data.mind,2.0/3,"partial attribute reward")
	near(s.data.xp,20,"partial XP")
	near(s.data.stats.study,300,"partial effective time")
	expect(s.data.stats.full_study==0,"partial study does not count full completion")
	var snapshot = s.data.duplicate(true)
	s.end_task(T+300)
	expect(s.data==snapshot,"double settlement no-op")
	s = make()
	s.start_task("work","flyer",T)
	s.end_task(T+300)
	near(s.data.stats.income,20.0/3,"partial wage")
	near(s.data.coins,610+20.0/3,"partial wage credited")
	s = make()
	for i in 30:
		var start = T+i
		s.start_task("study","read",start)
		s.end_task(start+1)
	near(s.data.mind,2.0/30,"tiny-task fractions cannot inflate rewards")
	near(s.data.coins,610-5.0/30,"tiny-task fractional fees")
	for kind in ["study","work"]:
		for row in C.COURSES if kind=="study" else C.JOBS:
			s=make()
			for a in C.ATTR_NAMES: s.data[a]=60.0
			s.check_achievements()
			var cfg=C.task(kind,row[0])
			var before=s.data.coins
			expect(s.start_task(kind,cfg.id,T)=="","start "+cfg.name)
			expect(s.start_task(kind,cfg.id,T)!="","single task "+cfg.name)
			s.advance(T+cfg.duration)
			expect(s.data.task.is_empty(),"completion "+cfg.name)
			near(s.data.food,100-3*cfg.duration/3600-cfg.food,"complete food "+cfg.name)
			near(s.data.clean,100-2*cfg.duration/3600-cfg.clean,"complete clean "+cfg.name)
			near(s.data.stats[kind],cfg.duration,"effective time "+cfg.name)
			near(s.data.coins,before+(-cfg.money if kind=="study" else cfg.money)+30+(14 if cfg.xp>=123 else 0)+(16 if cfg.xp>=305 else 0),"complete money plus achievement/level "+cfg.name)
			var coin_snapshot=s.data.coins
			s.advance(T+cfg.duration+10)
			near(s.data.coins,coin_snapshot,"no repeat wage "+cfg.name)
	s=make()
	s.start_task("study","read",T)
	s.advance(T+43200,true)
	near(s.data.food,100-24-5,"12h offline capped food plus activity")
	near(s.data.clean,100-16-3,"12h offline capped clean plus activity")
	near(s.data.mood,92,"12h offline capped mood")
	near(s.data.mind,2,"offline full task reward")
	expect(s.data.task.is_empty(),"offline fixed task ended")
	s=make()
	s.advance(T+43200,false)
	near(s.data.food,64,"online 12h is not capped")
	near(s.data.clean,76,"online 12h clean")
	near(s.data.mood,88,"online 12h mood")
	s=make()
	s.start_task("work","flyer",T)
	s.advance(T+300)
	s.advance(T-1000)
	near(s.data.task.elapsed,300,"backwards time no progress")
	s.advance(T-400)
	expect(s.data.task.is_empty(),"rebased task finishes after remaining duration")
	near(s.data.stats.income,20,"backwards clock single full wage")
	s=make()
	s.start_task("work","flyer",T)
	s.advance(T+900000000,true)
	expect(s.data.task.is_empty() and s.data.food>=0 and s.data.clean>=0,"extreme future clock bounded")
	near(s.data.stats.income,20,"extreme future one wage")
	s=make()
	s.data.food=20
	s.data.clean=20
	s.start_task("work","flyer",T)
	s.use_item("fish",T+100)
	s.use_item("soap",T+110)
	s.interact(true,T+120,12)
	expect(s.data.task.id=="flyer","care does not cancel activity")
	s.advance(T+900)
	near(s.data.stats.income,20,"care does not reduce task reward")
	s=make()
	s.data.mood=50
	expect(s.interact(true,T,12),"first effective pet")
	expect(not s.interact(true,T+1,12),"pet reward cooldown")
	expect(s.interact(true,T+20,12),"pet reward after cooldown")
	expect(s.data.stats.pet==2,"effective pet achievement count")
	for i in 10: s.interact(false,T+21+i*0.1,12)
	expect("poke" in s.data.achievements,"frequent-click hidden achievement")
	s.interact(false,T+30,2)
	expect("night" in s.data.achievements,"local-night achievement")
	for i in 20: s.witness_idle()
	expect("watch" in s.data.achievements,"observed idle achievement")
	s=make()
	s.data.stats.feed=10
	s.data.stats.wash=30
	s.data.stats.pet=100
	s.data.stats.study=180000
	s.data.stats.work=36000
	s.data.stats.income=10000
	s.data.stats.full_study=1
	s.data.stats.full_work=1
	s.data.stats.watch=20
	s.data.stats.poke=1
	s.data.stats.night=1
	for a in C.ATTR_NAMES:s.data[a]=60.0
	s.add_xp(100000)
	s.check_achievements()
	expect(s.data.level==20 and s.data.achievements.size()==20,"all 20 achievements")
	var capcoins=s.data.coins
	s.add_xp(100000)
	s.check_achievements()
	near(s.data.coins,capcoins,"level cap and reward idempotence")
	for a in C.ACCESSORIES: expect(s.accessory_unlocked(a),"accessory "+a[1])
	var total=0.0
	for lv in range(1,20):total+=C.next_xp(lv)
	print("Lv20 EXP=",total,"; days at 1.5h/day intermediate=",total/(90*6))
	expect(total/(90*6)>=30 and total/(90*6)<=60,"growth 1-2 months simulation")
	test_persistence()
	test_long_term()
	print("STATE_TESTS ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func test_persistence():
	var s=make()
	s.path="res://tests/runtime/state-test.json"
	s.autosave=true
	expect(s.save(),"atomic initial save")
	s.start_task("study","read",T)
	s.advance(T+300)
	expect(s.save(),"save task checkpoint")
	var other=State.new()
	other.path=s.path
	expect(other.load_game(T+43200),"load and offline settlement")
	expect(other.data.task.is_empty(),"persisted task completes offline")
	near(other.data.mind,2,"saved task reward full once")
	var previous=other.data.coins
	var third=State.new()
	third.path=s.path
	expect(third.load_game(T+43200),"reload saved settlement")
	near(third.data.coins,previous,"reload no repeat reward")
	near(third.data.mind,2,"reload no repeat attribute")
	# Corrupted primary must recover the previous committed transaction.
	var file=FileAccess.open(s.path,FileAccess.WRITE)
	file.store_string("broken json")
	file.close()
	var recovered=State.new()
	recovered.path=s.path
	expect(recovered.load_game(T+43200),"corrupt primary recovers backup")
	near(recovered.data.mind,2,"recovered settled reward remains once")
	var malformed=s.data.duplicate(true)
	malformed.food=NAN
	expect(not s.valid(malformed),"NaN rejected")
	malformed=s.data.duplicate(true)
	malformed.erase("inventory")
	expect(not s.valid(malformed),"missing structure rejected")
	for suffix in ["", ".bak", ".tmp"]:
		file=FileAccess.open(s.path+suffix,FileAccess.WRITE)
		file.store_string("bad")
		file.close()
	var damaged=State.new()
	damaged.path=s.path
	expect(not damaged.load_game(T),"fully corrupt save not adopted anew")
	expect(damaged.load_error and not damaged.save(),"fully corrupt original retained")

func test_long_term():
	# A daily 1-2h session: one hour of work plus 30-60 minutes of study.
	# Top up supplies only as needed; include the offline decay of each day.
	var s=make()
	var clock=T
	var reached=0
	var lowest=s.data.coins
	for day in range(1,61):
		clock=T+(day-1)*86400
		s.advance(clock,true)
		var attr="power"
		for key in C.ATTR_NAMES:
			if s.data[key]<s.data[attr]:attr=key
		var course=C.task("study",C.COURSES[0][0])
		for row in C.COURSES:
			if row[2]==attr and s.data[attr]>=row[3]:course=C.task("study",row[0])
		var work=C.task("work","flyer")
		for row in C.JOBS:
			if s.data[row[2]]>=row[3] and row[3]>=work.need:work=C.task("work",row[0])
		var schedule=[]
		for i in int(3600/work.duration):schedule.append(["work",work])
		for i in (2 if course.duration==900 else 1):schedule.append(["study",course])
		for entry in schedule:
			var cfg=entry[1]
			while s.data.food<maxf(40,cfg.food+5):
				if s.data.inventory.get("fish",0)<1:
					if s.buy("fish",clock)!="":
						expect(false,"economy can afford food on day "+str(day));return
				s.use_item("fish",clock)
			while s.data.clean<maxf(35,cfg.clean+5):
				if s.data.inventory.get("soap",0)<1:
					if s.buy("soap",clock)!="":
						expect(false,"economy can afford soap on day "+str(day));return
				s.use_item("soap",clock)
			if s.start_task(entry[0],cfg.id,clock)!="":
				expect(false,"daily routine can afford tasks on day "+str(day));return
			clock+=cfg.duration
			s.advance(clock)
			lowest=minf(lowest,s.data.coins)
		if s.data.level==20:
			reached=day
			break
	print("Daily routine simulation: Lv20 day=",reached,"; minimum coins=",lowest,"; final coins=",s.data.coins)
	expect(reached>=30 and reached<=60,"complete daily routine reaches Lv20 in 1-2 months")
	expect(lowest>=0,"daily economy funds supplies and tuition")
