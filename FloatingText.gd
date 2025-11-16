extends Label
class_name FloatingText

var timer = 0;
var reversed = false;

func _process(delta: float) -> void:
	timer += delta;
	if (reversed):
		rect_position.y += delta*30;
	else:
		rect_position.y -= delta*30;
	modulate = Color(1, 1, 1, (2-timer)/2);
	if (timer > 2):
		queue_free();
	update();
