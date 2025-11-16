extends Node2D
class_name WaitForDraw

var gamelogic = null

func _process(delta: float) -> void:
	update();

func _draw():
	gamelogic.time_to_start();
	queue_free();
