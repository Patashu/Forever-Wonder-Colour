extends ActorBase
class_name Goal

var gamelogic = null;
var actorname : int = -1;
var pos = Vector2.ZERO
var dinged = false;
var animations = [];
var animation_timer = 0;
var animation_timer_max = 1.0;
var particle_timer_max = 1.5;
var particle_timer = particle_timer_max;
var last_particle_angle = 0.0;

enum State {
	Closed,
	Opening,
	Closing,
	Open
}

func update_graphics() -> void:
	pass
	
func get_next_texture() -> Texture:
	return texture
	
func set_next_texture(tex: Texture) -> void:
	pass

func _process(delta: float) -> void:
	pass
