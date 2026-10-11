extends RefCounted
const ACTIONS = [["spin","转圈",2],["dance","跳舞",5],["celebrate","庆祝",10]]

const ATTR_NAMES = {"power":"武力", "mind":"智力", "charm":"魅力"}
const ITEMS = [
	{"id":"bread", "name":"小面包", "price":10, "food":20, "clean":0, "mood":0},
	{"id":"fish", "name":"小鱼干", "price":20, "food":40, "clean":0, "mood":5},
	{"id":"steak", "name":"豪华鱼排", "price":40, "food":70, "clean":0, "mood":15},
	{"id":"soap", "name":"普通肥皂", "price":10, "food":0, "clean":25, "mood":0},
	{"id":"bath", "name":"香香沐浴露", "price":25, "food":0, "clean":60, "mood":10},
	{"id":"snack", "name":"快乐零食", "price":15, "food":5, "clean":0, "mood":25}
]
const COURSES = [
	["sport","体育课","power",0,900,5,10,8,2],
	["read","识字课","mind",0,900,5,5,3,2],
	["manners","礼仪课","charm",0,900,5,6,5,2],
	["martial","武术课","power",20,1800,15,15,10,5],
	["math","数学课","mind",20,1800,15,9,5,5],
	["music","音乐课","charm",20,1800,15,10,7,5],
	["combat","格斗训练","power",60,3600,35,25,18,12],
	["science","科学研究","mind",60,3600,35,17,9,12],
	["stage","作词课","charm",60,3600,35,20,14,12]
]
const JOBS = [
	["flyer","发传单","power",0,900,20,8,5,0],
	["carry","搬运工","power",20,1800,50,20,15,0],
	["library","图书校对员","mind",20,1800,50,12,5,0],
	["waiter","远程客服","charm",20,1800,50,15,10,0],
	["guard","保安","power",60,3600,120,25,20,0],
	["code","程序员","mind",60,3600,120,15,8,0],
	["idol","导游","charm",60,3600,120,20,14,0]
]
# Total Lv.20 EXP = 27930: 52 days at 1.5h/day using intermediate activities.
static func next_xp(level: int) -> float:
	return 80.0 + 35.0 * level + 8.0 * level * level
static func task(kind: String, id: String) -> Dictionary:
	for row in COURSES if kind == "study" else JOBS:
		if row[0] == id:
			return {"id":row[0], "name":row[1], "attr":row[2], "need":row[3], "duration":float(row[4]), "money":float(row[5]), "food":float(row[6]), "clean":float(row[7]), "gain":float(row[8]), "xp":float(row[4])/60.0 * (4.0 if row[3] == 0 else (6.0 if row[3] == 20 else 8.0))}
	return {}
static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id: return it
	return {}
const ACHIEVEMENTS = [
	["adopt","初次见面","完成领养",30],
	["feed","干饭企鹅","累计喂食 10 次",50],
	["wash","美容大师","累计洗澡 30 次",100],
	["pet","摸摸头大师","有效抚摸 100 次 · 爱心表情",0],
	["happy","幸福企鹅","三项生活状态同时达到 100",80],
	["first_study","开学第一课","完整完成首次学习",30],
	["attr30","学霸养成中","任一成长属性达到 30",80],
	["all60","三好学生","三属性全部达到 60 · 学士帽",0],
	["study50","学无止境","累计有效学习 50 小时",200],
	["first_work","第一桶金","完整完成首次打工",30],
	["work10","劳动最光荣","累计有效打工 10 小时",100],
	["jobs","职场达人","解锁全部职业 · 小领带",0],
	["income","打工皇帝","累计打工收入 10000 金币",300],
	["lv5","茁壮成长","达到 Lv.5",50],
	["lv10","青春企鹅","达到 Lv.10",100],
	["lv15","成长达人","达到 Lv.15",150],
	["lv20","企鹅传奇","达到 Lv.20 · 传奇企鹅称号",0],
	["poke","别戳啦！","4 秒内连续点击企鹅 10 次",20],
	["watch","企鹅观察员","目睹 20 次随机待机动作",50],
	["night","夜猫子","00:00～05:00 与企鹅互动",30]
]
const ACCESSORIES = [
	["none","不佩戴","head",1,""],
	["redhat","小红帽","head",3,""],
	["graduate","学士帽","head",1,"all60"],
	["crown","小皇冠","head",15,""],
	["none","不佩戴","neck",1,""],
	["scarf","小围巾","neck",7,""],
	["bow","小领结","neck",12,""],
	["tie","小领带","neck",1,"jobs"]
]
