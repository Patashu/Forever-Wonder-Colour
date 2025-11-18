extends Node2D
class_name CoolCircle

var timer = 0;
var timer_max = 1.0;

func _process(delta: float) -> void:
	timer += delta;
	if (timer > timer_max):
		queue_free();
	update();

func _draw():
	var color = Color("#FF7F00");
	color.a = (timer_max-timer)/timer_max;
	draw_circle(Vector2.ZERO, (timer)*300, color);
