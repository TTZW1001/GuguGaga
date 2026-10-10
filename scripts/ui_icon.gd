extends Control
var kind = "food"
func _ready(): mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw():
	var ink=Color("677d70")
	if kind=="food":
		draw_arc(Vector2(15,13),8,0,TAU,24,ink,1.8,true)
		draw_polyline(PackedVector2Array([Vector2(7,13),Vector2(1,7),Vector2(1,19),Vector2(7,13)]),ink,1.8,true)
		draw_circle(Vector2(18,11),1.5,ink)
	elif kind=="clean":
		draw_polyline(PackedVector2Array([Vector2(14,2),Vector2(5,15),Vector2(6,21),Vector2(10,25),Vector2(18,25),Vector2(23,21),Vector2(23,15),Vector2(14,2)]),ink,1.8,true)
		draw_arc(Vector2(15,18),4,0.2,1.6,12,ink,1.6,true)
	elif kind=="shop":
		draw_polyline(PackedVector2Array([Vector2(3,10),Vector2(6,25),Vector2(23,25),Vector2(26,10),Vector2(3,10)]),ink,1.8,true)
		draw_line(Vector2(8,10),Vector2(12,2),ink,1.8,true)
		draw_line(Vector2(21,10),Vector2(17,2),ink,1.8,true)
		for x in [10,15,20]:draw_line(Vector2(x,14),Vector2(x,21),ink,1.4,true)
