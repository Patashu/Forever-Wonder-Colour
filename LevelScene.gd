extends Node2D
class_name LevelScene

onready var gamelogic : GameLogic = self.get_node("GameLogic");
var last_delta = 0;

func _process(delta: float) -> void:
	last_delta = delta;
	update();

func _draw():
	if gamelogic.SuperScaling != null:
		draw_rect(Rect2(0, 0, gamelogic.pixel_width, gamelogic.pixel_height), gamelogic.current_sky, true);
	
	if (gamelogic.undo_effect_strength > 0):
		var color = Color(gamelogic.undo_effect_color);
		color.a = gamelogic.undo_effect_strength;
		draw_rect(Rect2(0, 0, gamelogic.pixel_width, gamelogic.pixel_height), color, true);
	gamelogic.undo_effect_strength -= gamelogic.undo_effect_per_second*last_delta;
	
	#if (gamelogic.currently_fast_replay()):
	#	return;
	
	# directional input debugger
#	var color_l = Color(1, 0, 0);
#	var color_d = Color(1, 0, 0);
#	var color_u = Color(1, 0, 0);
#	var color_r = Color(1, 0, 0);
#	if (Input.get_action_strength("ui_left") > 0.0):
#		color_l = Color(0, 1, 0);
#	if (Input.get_action_strength("ui_right") > 0.0):
#		color_r = Color(0, 1, 0);
#	if (Input.get_action_strength("ui_up") > 0.0):
#		color_u = Color(0, 1, 0);
#	if (Input.get_action_strength("ui_down") > 0.0):
#		color_d = Color(0, 1, 0);
#
#	draw_rect(Rect2(0, 0, Input.get_action_raw_strength("ui_left")*100, 24), color_l);
#	draw_rect(Rect2(0, 24, Input.get_action_raw_strength("ui_right")*100, 24), color_r);
#	draw_rect(Rect2(0, 48, Input.get_action_raw_strength("ui_up")*100, 24), color_u);
#	draw_rect(Rect2(0, 72, Input.get_action_raw_strength("ui_down")*100, 24), color_d);
