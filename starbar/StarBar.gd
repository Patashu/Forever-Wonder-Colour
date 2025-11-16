extends Node2D
class_name StarBar

# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"
var slots: Array = [];
var collected = 0;
var collected_max = 5;

func initialize(num: int) -> void:
	collected_max = num;
	collected = 0;
	for slot in slots:
		slot.queue_free();
	slots.clear();
	for i in range(num):
		var slot = Sprite.new();
		slot.script = preload("res://starbar/StarBarSlot.gd");
		self.add_child(slot);
		slot.position = Vector2(-16*(i), 0);
		slots.append(slot);
		if (i == 0):
			slot.frame = 2;
		elif (i == num - 1):
			slot.frame = 0;

func star_get() -> void:
	slots[collected].star_get();
	collected += 1;

func star_unget() -> void:
	collected -= 1;
	slots[collected].star_unget();
	
func finish_animations() -> void:
	for slot in slots:
		slot.finish_animations();

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
