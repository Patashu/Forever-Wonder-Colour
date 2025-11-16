extends Node2D
class_name SparkleSpawner

var sparkle_timer = 0;
var sparkle_timer_max = 0.1;
var end = 1;
var color = Color("DBC1AF");
onready var gamelogic = get_tree().get_root().find_node("LevelScene", true, false).gamelogic;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var parent = self.get_parent();
	var old_times = floor(sparkle_timer/sparkle_timer_max);
	sparkle_timer += delta;
	var new_times = floor(sparkle_timer/sparkle_timer_max);
	if (old_times != new_times):
		# one sparkle
		var sprite = Sprite.new();
		sprite.set_script(preload("res://FadingSprite.gd"));
		sprite.texture = preload("res://assets/Sparkle.png")
		if (parent is Control):
			sprite.position = parent.rect_size / 2 + Vector2(gamelogic.rng.randf_range(-12, 12), gamelogic.rng.randf_range(-12, 12));
		elif (parent is Sprite):
			sprite.position = parent.offset + Vector2(gamelogic.rng.randf_range(-12, 12), gamelogic.rng.randf_range(-12, 12));
		else:
			sprite.position = self.position + Vector2(gamelogic.rng.randf_range(-12, 12), gamelogic.rng.randf_range(-12, 12));
		sprite.frame = 0;
		sprite.centered = true;
		sprite.scale = Vector2(0.25, 0.25);
		sprite.modulate = color;
		parent.add_child(sprite)
	if (sparkle_timer > end):
		queue_free();
