extends Sprite
class_name FadingSprite

var fadeout_timer = 0;
var fadeout_timer_max = 1;
var velocity = Vector2.ZERO;

# sine jiggle
var sine_timer = 0.0;
var sine_mult = 0.0;
var sine_offset = 0.0;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (velocity != Vector2.ZERO):
		position += velocity * delta;
	if (sine_mult != 0.0):
		sine_timer += delta;
		self.offset.x = sin(sine_timer*sine_mult)*sine_offset;
	fadeout_timer += delta;
	if (fadeout_timer > fadeout_timer_max):
		queue_free();
	else:
		self.modulate.a = 1-fadeout_timer/fadeout_timer_max;
