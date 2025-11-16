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
var unwinning = false;
var starbar = null;
var state : int = State.Closed;
var state_timer = 0;
var state_timer_max = 0.5;

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
	
func calculate_speed() -> void:
	unwinning = false;
	if (starbar.collected >= starbar.collected_max or starbar.collected_max < 1):
		particle_timer_max = 0.5;
		dinged = true;
	else:
		particle_timer_max = (3.0-2.0*(float(starbar.collected)/float(starbar.collected_max)))/2;
		dinged = false;
	
	if (dinged and state != State.Open and state != State.Opening):
		state = State.Opening;
		state_timer = 0;
		gamelogic.play_sound("goalopening");
	elif (!dinged and state != State.Closed and state != State.Closing):
		state = State.Closing;
		state_timer = 0;
		gamelogic.play_sound("goalclosing");

func _process(delta: float) -> void:
	match state:
		State.Open:
			self.texture = preload("res://assets/win_spritesheet.png");
			self.hframes = 8;
			state_timer += delta;
			state_timer_max = 1.0;
			if (state_timer >= state_timer_max):
				state_timer -= state_timer_max;
			self.frame = clamp(floor((state_timer/state_timer_max)*hframes), 0, hframes - 1);
		State.Closed:
			self.texture = preload("res://assets/win.png");
			self.hframes = 1;
			self.frame = 0;
		State.Opening:
			self.texture = preload("res://assets/win_open_spritesheet.png");
			self.hframes = 4;
			state_timer_max = 0.5;
			state_timer += delta;
			self.frame = clamp(floor((state_timer/state_timer_max)*self.hframes), 0, hframes - 1);
			if (state_timer >= state_timer_max):
				state_timer -= state_timer_max;
				state = State.Open;
		State.Closing:
			self.texture = preload("res://assets/win_open_spritesheet.png");
			self.hframes = 4;
			self.frame = clamp(floor((1.0-(state_timer/state_timer_max))*self.hframes), 0, hframes - 1);
			state_timer_max = 0.5;
			state_timer += delta;
			if (state_timer >= state_timer_max):
				state_timer -= state_timer_max;
				state = State.Closed;
				
	
	particle_timer += delta;
	if (particle_timer > particle_timer_max):
		var underactorsparticles = gamelogic.underactorsparticles;
		particle_timer -= particle_timer_max;
		var sprite = Sprite.new();
		sprite.set_script(preload("res://GoalParticle.gd"));
		sprite.texture = preload("res://assets/win_particle.png");
		sprite.hframes = 3;
		sprite.frame = gamelogic.rng.randi_range(0, 2);
		sprite.position = self.position;
		sprite.centered = true;
		sprite.alpha_max = 1.0;
		sprite.modulate = Color(modulate.r, modulate.g, modulate.b, 0);
		sprite.parent = self;
		var next_particle_angle = last_particle_angle + 2*PI/6 + gamelogic.rng.randf_range(0, 2*PI*4/6)
		last_particle_angle = next_particle_angle;
		sprite.fadeout_timer_max = 4;
		sprite.velocity = Vector2(0, 6).rotated(next_particle_angle);
		sprite.position -= sprite.velocity*sprite.fadeout_timer_max;
		underactorsparticles.add_child(sprite);
	
	if (animations.size() > 0):
		var current_animation = animations[0];
		var is_done = true;
		if (current_animation[0] == 9): #starget
			if (animation_timer == 0.0):
				particle_timer = 0.25;
			animation_timer_max = 1.0;
			particle_timer_max = 0.25;
			dinged = true;
			animation_timer += delta;
			if (animation_timer >= animation_timer_max):
				calculate_speed();
			else:
				is_done = false;
		elif (current_animation[0] == 10): #starunget
			if (animation_timer == 0.0):
				particle_timer = -1.0;
			animation_timer_max = 1.0;
			unwinning = true;
			animation_timer += delta;
			if (animation_timer >= animation_timer_max):
				calculate_speed();
			else:
				is_done = false;
		if (is_done):
			animations.pop_front();
			animation_timer = 0;
