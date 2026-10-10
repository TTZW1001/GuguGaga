extends RefCounted
const C = preload("res://scripts/catalog.gd")
signal changed
signal message(text: String)
var data: Dictionary = {}
var path = "user://penguin.json"
var autosave = true
var save_error = false
var load_error = false
var clicks: Array[float] = []

func fresh(now: float) -> Dictionary:
	return {"save_version":1,"adopted":false,"name":"小企鹅","coins":500.0,"food":100.0,"clean":100.0,"mood":100.0,"power":0.0,"mind":0.0,"charm":0.0,"level":1,"xp":0.0,"inventory":{"fish":3,"soap":2},"task":{},"achievements":[],"head":"none","neck":"none","gold":false,"last":now,"pet_at":0.0,"care_at":0.0,"stats":{"feed":0,"wash":0,"pet":0,"study":0.0,"work":0.0,"income":0.0,"full_study":0,"full_work":0,"watch":0,"poke":0,"night":0}}

func adopt(pet_name: String, now: float):
	if data.get("adopted",false): return
	data = fresh(now)
	data.adopted = true
	data.name = clean_name(pet_name)
	check_achievements()
	commit()

func clean_name(value: String) -> String:
	var result = value.strip_edges().replace("\n", " ").replace("\r", " ").substr(0,12)
	return "小企鹅" if result.is_empty() else result

func rename(value: String):
	data.name = clean_name(value)
	commit()

func load_game(now: float) -> bool:
	data = fresh(now)
	var exists = false
	for suffix in ["", ".bak", ".tmp"]:
		if not FileAccess.file_exists(path + suffix): continue
		exists = true
		var envelope = parse_json(FileAccess.get_file_as_string(path + suffix))
		if not envelope is Dictionary or not envelope.get("payload") is String: continue
		if envelope.get("sha256", "") != envelope.payload.sha256_text(): continue
		var saved = parse_json(envelope.payload)
		if not valid(saved): continue
		data = saved
		if suffix != "": message.emit("已恢复备份存档。")
		advance(now,true)
		commit()
		return true
	if exists:
		load_error = true
		message.emit("存档无法读取，原文件已保留。")
	return false

func parse_json(content: String):
	var parser = JSON.new()
	return parser.data if parser.parse(content) == OK else null

func valid(d) -> bool:
	if not d is Dictionary or d.get("save_version") != 1: return false
	for key in fresh(0):
		if not d.has(key): return false
	for key in ["coins","food","clean","mood","power","mind","charm","level","xp","last","pet_at","care_at"]:
		if not (d[key] is float or d[key] is int): return false
		if not is_finite(float(d[key])) or d[key] < 0 or d[key] > 1.0e12: return false
	if d.level < 1 or d.level > 20: return false
	for key in ["food","clean","mood"]:
		if d[key] > 100: return false
	if not d.name is String or not d.adopted is bool: return false
	if not d.head is String or not d.neck is String or not d.gold is bool: return false
	if not d.achievements is Array or not d.inventory is Dictionary or not d.stats is Dictionary or not d.task is Dictionary: return false
	for key in fresh(0).stats:
		if not d.stats.has(key) or not (d.stats[key] is int or d.stats[key] is float): return false
		if not is_finite(float(d.stats[key])) or d.stats[key] < 0: return false
	for key in d.inventory:
		if C.item(key).is_empty() or not (d.inventory[key] is int or d.inventory[key] is float): return false
		if d.inventory[key] < 0 or d.inventory[key] != floor(d.inventory[key]): return false
	if not d.task.is_empty():
		for key in ["kind","id","elapsed","start","end","escrow"]:
			if not d.task.has(key): return false
		if d.task.kind not in ["study","work"]: return false
		var cfg = C.task(d.task.kind,d.task.id)
		if cfg.is_empty(): return false
		for key in ["elapsed","start","end","escrow"]:
			if not (d.task[key] is int or d.task[key] is float): return false
			if not is_finite(float(d.task[key])) or d.task[key] < 0: return false
		if d.task.elapsed > cfg.duration or d.task.escrow > cfg.money: return false
	return true

func save() -> bool:
	if not autosave or not data.get("adopted",false) or load_error: return false
	var payload = JSON.stringify(data)
	var file = FileAccess.open(path+".tmp", FileAccess.WRITE)
	if file == null:
		report_save_error()
		return false
	file.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
	file.flush()
	file.close()
	# Keep the previous completed transaction until the next atomic replacement.
	var old = parse_json(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if old is Dictionary and old.get("payload") is String and old.get("sha256","") == old.payload.sha256_text() and valid(parse_json(old.payload)):
		var err = DirAccess.copy_absolute(path,path+".bak")
		if err != OK:
			report_save_error()
			return false
	var error = DirAccess.rename_absolute(path+".tmp",path)
	if error != OK:
		report_save_error()
		return false
	save_error = false
	return true

func report_save_error():
	if not save_error: message.emit("保存失败，请检查存档目录权限。")
	save_error = true

func commit():
	save()
	changed.emit()

func advance(now: float, offline: bool = false):
	if not data.get("adopted",false): return
	var delta = now - float(data.last)
	if delta < 0:
		# Rebase deadlines and cooldowns; a backwards clock never grants progress.
		if not data.task.is_empty():
			var cfg = C.task(data.task.kind,data.task.id)
			data.task.start = maxf(0,now-data.task.elapsed)
			data.task.end = now+cfg.duration-data.task.elapsed
		data.pet_at = minf(data.pet_at,now)
		data.care_at = minf(data.care_at,now)
		delta = 0.0
	var natural = minf(delta, 28800.0) if offline else delta
	# Implausible jumps are bounded for natural decay, tasks still settle once.
	if natural > 604800.0: natural = 28800.0
	data.last = now
	for key in ["food","clean","mood"]:
		var rate = {"food":3.0,"clean":2.0,"mood":1.0}[key]
		data[key] = clampf(data[key] - natural * rate / 3600.0,0,100)
	if not data.task.is_empty():
		var t = data.task
		var cfg = C.task(t.kind,t.id)
		var step = minf(delta, cfg.duration - float(t.elapsed))
		t.elapsed += step
		data.food = maxf(0,data.food - cfg.food * step/cfg.duration)
		data.clean = maxf(0,data.clean - cfg.clean * step/cfg.duration)
		data.stats[t.kind] += step
		if t.elapsed >= cfg.duration - 0.000001: settle_task(false)
	changed.emit()

func start_task(kind: String, id: String, now: float) -> String:
	advance(now)
	if not data.task.is_empty(): return "请先完成或结束当前任务。"
	var cfg = C.task(kind,id)
	if cfg.is_empty(): return "找不到这项任务。"
	var missing: Array[String] = []
	if data[cfg.attr]+0.00001 < cfg.need: missing.append("%s还差 %.1f" % [C.ATTR_NAMES[cfg.attr],cfg.need-data[cfg.attr]])
	if data.food+0.00001 < cfg.food: missing.append("饱食还差 %.1f" % (cfg.food-data.food))
	if data.clean+0.00001 < cfg.clean: missing.append("清洁还差 %.1f" % (cfg.clean-data.clean))
	if kind == "study" and data.coins+0.00001 < cfg.money: missing.append("金币还差 %.1f" % (cfg.money-data.coins))
	if not missing.is_empty(): return "、".join(missing)
	var escrow = cfg.money if kind == "study" else 0.0
	data.coins -= escrow
	data.task = {"kind":kind,"id":id,"elapsed":0.0,"start":now,"end":now+cfg.duration,"escrow":escrow}
	commit()
	return ""

func end_task(now: float):
	advance(now)
	if data.task.is_empty(): return
	settle_task(true)

func settle_task(early: bool):
	if data.task.is_empty(): return
	var t = data.task.duplicate(true)
	var cfg = C.task(t.kind,t.id)
	var ratio = clampf(float(t.elapsed)/cfg.duration,0,1)
	data.task = {} # Clear before awarding: repeated completion is a no-op.
	var summary: String
	if t.kind == "study":
		data.coins += t.escrow * (1.0-ratio)
		data[cfg.attr] += cfg.gain*ratio
		if not early: data.stats.full_study += 1
		summary = "%s +%.2f · 学费 %.2f" % [C.ATTR_NAMES[cfg.attr],cfg.gain*ratio,cfg.money*ratio]
	else:
		data.coins += cfg.money*ratio
		data.stats.income += cfg.money*ratio
		if not early: data.stats.full_work += 1
		summary = "金币 +%.2f" % (cfg.money*ratio)
	add_xp(cfg.xp*ratio)
	check_achievements()
	message.emit("%s%s：%s · 经验 +%.2f" % [cfg.name,"提前结束" if early else "完成",summary,cfg.xp*ratio])
	commit()

func buy(id: String, now: float) -> String:
	advance(now)
	var item = C.item(id)
	if item.is_empty(): return "找不到商品。"
	if data.coins+0.00001 < item.price: return "可用金币不足。"
	data.coins -= item.price
	data.inventory[id] = data.inventory.get(id,0)+1
	commit()
	return ""

func use_item(id: String, now: float) -> String:
	advance(now)
	var item = C.item(id)
	if item.is_empty() or data.inventory.get(id,0) < 1: return "库存不足，去商店补充吧。"
	var effective = false
	for key in ["food","clean","mood"]:
		if item[key] > 0 and data[key] < 99.999: effective = true
	if not effective: return "状态已满。"
	data.inventory[id] -= 1
	for key in ["food","clean","mood"]: data[key] = minf(100,data[key]+item[key])
	data.stats["wash" if item.clean > 0 else "feed"] += 1
	care_xp(now)
	check_achievements()
	commit()
	return ""

func care_xp(now: float):
	if now - float(data.care_at) >= 60:
		data.care_at = now
		add_xp(1.0)

func interact(petting: bool, now: float, local_hour: int) -> bool:
	advance(now)
	if local_hour >= 0 and local_hour < 5: data.stats.night = 1
	var rewarded = false
	if petting:
		if now - float(data.pet_at) >= 20:
			data.pet_at = now
			data.mood = minf(100,data.mood+2)
			data.stats.pet += 1
			care_xp(now)
			rewarded = true
	else:
		clicks.append(now)
		while not clicks.is_empty() and now-clicks[0] > 4: clicks.pop_front()
		if clicks.size() >= 10: data.stats.poke = 1
	check_achievements()
	commit()
	return rewarded

func witness_idle():
	if not data.adopted: return
	data.stats.watch += 1
	check_achievements()
	commit()

func add_xp(value: float):
	if data.level >= 20: return
	data.xp += value
	while data.level < 20 and data.xp+0.000001 >= C.next_xp(int(data.level)):
		data.xp = maxf(0,data.xp-C.next_xp(int(data.level)))
		data.level += 1
		data.coins += 10+int(data.level)*2
		message.emit("Lv.%d！ +%d 金币" % [data.level,10+int(data.level)*2])
	if data.level == 20: data.xp = 0.0

func achievement_values() -> Array:
	var s = data.stats
	var smallest = minf(data.power,minf(data.mind,data.charm))
	var biggest = maxf(data.power,maxf(data.mind,data.charm))
	return [[1,1],[s.feed,10],[s.wash,30],[s.pet,100],[1 if minf(data.food,minf(data.clean,data.mood)) >= 99.999 else 0,1],[s.full_study,1],[biggest,30],[smallest,60],[s.study/3600.0,50],[s.full_work,1],[s.work/3600.0,10],[smallest,60],[s.income,10000],[data.level,5],[data.level,10],[data.level,15],[data.level,20],[s.poke,1],[s.watch,20],[s.night,1]]

func check_achievements():
	if not data.adopted: return
	var progress = achievement_values()
	for i in C.ACHIEVEMENTS.size():
		var a = C.ACHIEVEMENTS[i]
		if a[0] not in data.achievements and progress[i][0]+0.00001 >= progress[i][1]:
			data.achievements.append(a[0])
			data.coins += a[3]
			message.emit("成就解锁 · " + a[1] + ("  +%d 金币" % a[3] if a[3] > 0 else ""))

func accessory_unlocked(a: Array) -> bool:
	return data.level >= a[3] and (a[4] == "" or a[4] in data.achievements)

func equip(a: Array):
	if not accessory_unlocked(a): return
	data[a[2]] = a[0]
	data.gold = false
	commit()

func set_suit(enabled: bool):
	if enabled and data.level < 20: return
	# Keep the legacy field and previous accessory choices for existing saves.
	# Rendering hides both slots while the suit is active.
	data.gold = enabled
	commit()
