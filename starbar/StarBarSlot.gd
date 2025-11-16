extends Sprite
class_name StarBarSlot

# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"
var star : Sprite = null;
var collecting = false;
var animation_timer = 0.0;
var animation_timer_max = 1.0;
var uncollecting = false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	texture = preload("res://assets/star_bar.png");
	hframes = 3;
	frame = 1;
	star = Sprite.new();
	star.texture = preload("res://assets/star_spritesheet.png");
	star.hframes = 6;
	star.frame = 3;
	self.add_child(star);

func star_get() -> void:
	uncollecting = false;
	collecting = true;
	animation_timer = 0.0;

func star_unget() -> void:
	uncollecting = true;
	collecting = false;
	animation_timer = 0.0;
	
func finish_animations() -> void:
	if (collecting):
		star.frame = 0;
		collecting = false;
	if uncollecting:
		star.frame = 3;
		uncollecting = false;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (uncollecting):
		animation_timer += delta;
		star.frame = clamp(round((animation_timer / animation_timer_max)*3), 0, 3);
		if (animation_timer > animation_timer_max):
			star.frame = 3;
			uncollecting = false;
	elif (collecting):
		animation_timer += delta;
		star.frame = clamp(3 + round((animation_timer / animation_timer_max)*2), 3, 5);
		if (animation_timer > animation_timer_max):
			star.frame = 0;
			uncollecting = false;
