extends ActorBase
class_name Goal

var gamelogic = null;
var actorname : int = -1;
var pos = Vector2.ZERO
var dinged = false;
var animations = [];
var animation_timer = 0;
var animation_timer_max = 1.0;
var particle_timer_max = 0.8;
var particle_timer = particle_timer_max;

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
	particle_timer += delta;
	if (particle_timer >= particle_timer_max):
		particle_timer -= particle_timer_max*gamelogic.rng.randf_range(0.9, 1.1);
		# one mote
		var sprite = Sprite.new();
		sprite.set_script(preload("res://FadingSprite.gd"));
		sprite.texture = preload("res://assets/pixel.png");
		sprite.modulate = Color("FFEBD8");
		sprite.fadeout_timer_max = 2.0;
		sprite.velocity = (Vector2.UP*gamelogic.rng.randf_range(8, 10)).rotated(gamelogic.rng.randf_range(-0.2, 0.2));
		sprite.position = position + Vector2(gamelogic.rng.randf_range(-gamelogic.cell_size*1/4, gamelogic.cell_size*1/4), gamelogic.cell_size/2);
		sprite.centered = true;
		sprite.scale = Vector2(2, 2);
		gamelogic.overactorsparticles.add_child(sprite);
