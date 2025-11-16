extends Sprite
class_name TimeBubble

var timer = 0;
var time_colour = Color("B2AF5C");
var label = null;


func time_bubble_colour() -> void:
	var c = time_colour;
	var coeff = 0.5+(1+sin(timer*2.5))/4;
	var current_r = lerp(0, c.r, coeff);
	var current_g = lerp(0, c.g, coeff);
	var current_b = lerp(0, c.b, coeff);
	self.modulate = Color(current_r, current_g, current_b);

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	timer += delta;
	time_bubble_colour();
