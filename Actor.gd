extends ActorBase
class_name Actor

var gamelogic = null
var actorname : int = -1
var stored_position : Vector2 = Vector2.ZERO
var pos : Vector2 = Vector2.ZERO
var home_pos : Vector2 = Vector2.ZERO;
var home_broken: bool = false;
var broken : bool = false
var strength : int = 0
var heaviness : int = 0
var durability : int = 0
var is_character : bool = false
var door_depth: int = 0
# sparkles
var sparkle_timer : float = 0.0;
var sparkle_timer_max : float = 1.2;
# splice flower ripple
var ripple = null;
var ripple_timer : float = 0.0;
var ripple_timer_max : float = 2.0;
# animation system logic
var animation_timer : float = 0.0;
var animation_timer_max : float = 0.05;
var base_frame = 0;
var animation_frame = 0;
var animations : Array = [];
var facing_dir : Vector2 = Vector2.RIGHT;
# animated sprites logic
var slow_mo = 1.3;
var bump_slowdown = 1.0;
var frame_timer : float = 0.0;
var frame_timer_max : float = 0.033*slow_mo;
var moving : Vector2 = Vector2.ZERO;
var exerting : bool = false;
var blink_timer = 0.0;
var blink_timer_max = 2.0;
var double_blinking = false;
var movement_parity = false;
# transient multi-push/multi-fall state:
# basically, things that move become non-colliding until the end of the multi-push/fall tick they're
# a part of, so other things that shared their tile can move with them
var just_moved : bool = false;
var fade_tween = null;

# faster than string comparisons
enum Name {
	Player,
	Goal,
	StoneBlock,
	WonderBlock,
	DepthDoor,
}

func update_graphics() -> void:
	var tex = get_next_texture();
	set_next_texture(tex, facing_dir);

func get_next_texture() -> Texture:
	if (fade_tween != null):
		fade_tween.queue_free();
		fade_tween = null;

	# airborne, broken
	match actorname:
		Name.Player:
			if broken:
				return null;
			else:
				return preload("res://assets/player_spritesheet.png");
		
		Name.StoneBlock:
			if broken:
				return null;
			else:
				return preload("res://assets/stone_block.png");
				
		Name.WonderBlock:
			if broken:
				return null;
			else:
				return preload("res://assets/wonder_block.png");
				
		Name.DepthDoor:
			if broken:
				return null;
			else:
				return preload("res://assets/depth_door_1.png");
	
	return null;

func set_next_texture(tex: Texture, facing_dir_at_the_time: Vector2) -> void:		
	if tex == null:
		visible = false;
	elif self.texture == null:
		visible = true;
		
	self.texture = tex;
	self.modulate.a = 1.0;
	
	frame_timer = 0;
	#frame = 0;
	match texture:
		preload("res://assets/player_spritesheet.png"):
			hframes = 10;
			vframes = 3;
			match (facing_dir_at_the_time):
				Vector2.DOWN:
					frame = 0;
					flip_h = false;
				Vector2.UP:
					frame = hframes;
					flip_h = false;
				Vector2.LEFT:
					frame = hframes*2;
					flip_h = true;
				Vector2.RIGHT:
					frame = hframes*2;
					flip_h = false;
			base_frame = frame;
			animation_frame = 0;

func pushable(by_actor: Actor) -> bool:
	if (just_moved):
		return false;
	return !broken;
		
func phases_into_terrain() -> bool:
	return false;
	
func phases_into_actors() -> bool:
	return false;

func afterimage() -> void:
	gamelogic.afterimage(self);

func set_door_depth(door_depth: int) -> void:
	self.door_depth = door_depth;
	if (self.door_depth < 0):
		self.broken = true;
		update_graphics();
	# TODO: thought bubble number
#	thought_bubble = Sprite.new();
#	thought_bubble.set_script(preload("res://ThoughtBubble.gd"));
#	thought_bubble.initialize(self.time_colour, self.ticks);
#	thought_bubble.position = Vector2(12, -12);
#	self.add_child(thought_bubble);

func _process(delta: float) -> void:
	# sparkles
	if (actorname == Name.WonderBlock):
		sparkle_timer += delta;
		if (sparkle_timer >= sparkle_timer_max):
			sparkle_timer -= sparkle_timer_max*gamelogic.rng.randf_range(0.9, 1.1);
			# one sparkle
			var sprite = Sprite.new();
			sprite.set_script(preload("res://FadingSprite.gd"));
			sprite.texture = preload("res://assets/Sparkle.png")
			sprite.position = self.offset + Vector2(gamelogic.rng.randf_range(-6, 6), gamelogic.rng.randf_range(-6, 6));
			sprite.frame = 0;
			sprite.centered = true;
			sprite.scale = Vector2(0.25, 0.25);
			sprite.modulate = Color("FF7F00");
			if (gamelogic.rng.randi_range(0, 1) == 1):
				sprite.modulate = Color("FFEBD8");
			self.add_child(sprite)
	
	#splice flower ripple
	if (ripple != null):
		ripple_timer += delta;
		if (ripple_timer > ripple_timer_max):
			ripple.queue_free();
			ripple = null;
		else:
			ripple.get_material().set_shader_param("height", ((ripple_timer_max-ripple_timer)/ripple_timer_max)*0.003);
			#child.get_material().set_shader_param("color", undo_color);
			#child.get_material().set_shader_param("mixture", 1.0);
	
	
	#animated sprites
	if actorname == Name.Player:
		if moving != Vector2.ZERO:
			frame_timer += delta;
			# ping pong logic
			if (frame_timer > frame_timer_max*bump_slowdown):
				frame_timer -= frame_timer_max*bump_slowdown;
				animation_frame += 1;
				if (animation_frame > 3):
					animation_frame = 0;
			var adjusted_frame = animation_frame;
			if (adjusted_frame == 0):
				adjusted_frame = 2;
			if (exerting):
				adjusted_frame += 6;
			frame = base_frame + adjusted_frame;
		else:
			animation_frame = 0;
			frame = base_frame;
			# blinking logic
			blink_timer += delta;
			if (blink_timer > blink_timer_max):
				blink_timer = 0;
				if (!double_blinking and gamelogic.rng.randf_range(0.0, 1.0) < 0.2):
					blink_timer_max = 0.2;
					double_blinking = true;
				else:
					double_blinking = false;
					blink_timer_max = gamelogic.rng.randf_range(1.5, 2.5);
			elif (blink_timer_max - blink_timer < 0.1):
				frame += 4;
			
	elif actorname == Name.WonderBlock:
		if moving != Vector2.ZERO:
			frame_timer += delta;
			if (frame_timer > frame_timer_max):
				frame_timer -= frame_timer_max;
				# spawn an ice puff
				var sprite = Sprite.new();
				sprite.set_script(preload("res://FadingSprite.gd"));
				sprite.texture = preload("res://assets/Sparkle.png");
				sprite.fadeout_timer_max = 0.8;
				sprite.velocity = (-moving*gamelogic.rng.randf_range(8, 16)).rotated(gamelogic.rng.randf_range(-0.5, 0.5));
				sprite.position = position + Vector2(gamelogic.rng.randf_range(gamelogic.cell_size*1/4, gamelogic.cell_size*3/4), gamelogic.rng.randf_range(gamelogic.cell_size*1/4, gamelogic.cell_size*3/4));
				sprite.centered = true;
				sprite.scale = Vector2(0.25, 0.25);
				sprite.modulate = Color("FF7F00");
				if (gamelogic.rng.randi_range(0, 1) == 1):
					sprite.modulate = Color("FFEBD8");
				gamelogic.overactorsparticles.add_child(sprite);
	elif actorname == Name.StoneBlock:
		if moving != Vector2.ZERO:
			frame_timer += delta;
			if (frame_timer > frame_timer_max):
				frame_timer -= frame_timer_max;
				# spawn a dust cloud
				var sprite = Sprite.new();
				sprite.set_script(preload("res://FadingSprite.gd"));
				sprite.texture = preload("res://assets/dust.png")
				sprite.fadeout_timer_max = 0.8;
				sprite.velocity = (-moving*gamelogic.rng.randf_range(8, 16)).rotated(gamelogic.rng.randf_range(-0.5, 0.5));
				sprite.position = position + Vector2(gamelogic.rng.randf_range(gamelogic.cell_size*1/4, gamelogic.cell_size*3/4), gamelogic.rng.randf_range(gamelogic.cell_size*1/4, gamelogic.cell_size*3/4));
				sprite.hframes = 7;
				sprite.frame = gamelogic.rng.randi_range(0, 6);
				sprite.centered = true;
				sprite.scale = Vector2(1.0, 1.0);
				sprite.modulate = Color("FFEBD8");
				gamelogic.underterrainfolder.add_child(sprite);
		
	
	# animation system stuff
	moving = Vector2.ZERO;
	if (animations.size() > 0):
		var current_animation = animations[0];
		var is_done = true;
		match current_animation[0]:
			0: #move
				moving = current_animation[1];
				var wonder = current_animation[3];
				# afterimage if it was a retro move
				if (animation_timer == 0):
					frame_timer = 0;
					if (movement_parity):
						animation_frame = 2;
						movement_parity = false;
					else:
						movement_parity = true;
					if current_animation[2]:
						afterimage();
				animation_timer_max = 0.09*slow_mo;
				position -= current_animation[1]*(animation_timer/animation_timer_max)*gamelogic.cell_size;
				animation_timer += delta;
				if (wonder):
					animation_timer = 99;
				if (animation_timer > animation_timer_max):
					position += current_animation[1]*1*gamelogic.cell_size;
					# no rounding errors here! get rounded sucker!
					position.x = round(position.x); position.y = round(position.y);
					exerting = false;
				else:
					is_done = false;
					position += current_animation[1]*(animation_timer/animation_timer_max)*gamelogic.cell_size;
			1: #bump
				if (animation_timer == 0):
					# let's try some exertion bumps again?
					if (self.actorname == Name.Player):
						exerting = true;
						bump_slowdown = 2.0;
						if (movement_parity):
							animation_frame = 2;
							movement_parity = false;
						else:
							movement_parity = true;
						set_next_texture(get_next_texture(), current_animation[1]);
					frame_timer = 0;
				moving = facing_dir;
				animation_timer_max = 0.095*2*slow_mo;
				var bump_amount = (animation_timer/animation_timer_max);
				if (bump_amount > 0.5):
					bump_amount = 1-bump_amount;
				bump_amount *= 0.2;
				position -= current_animation[1]*bump_amount*gamelogic.cell_size;
				animation_timer += delta;
				if (animation_timer > animation_timer_max):
					position.x = round(position.x); position.y = round(position.y);
					exerting = false;
					bump_slowdown = 1.0;
				else:
					is_done = false;
					bump_amount = (animation_timer/animation_timer_max);
					if (bump_amount > 0.5):
						bump_amount = 1-bump_amount;
					bump_amount *= 0.2;
					position += current_animation[1]*bump_amount*gamelogic.cell_size;
			2: #set_next_texture
				set_next_texture(current_animation[1], current_animation[2]);
			3: #sfx
				gamelogic.play_sound(current_animation[1]);
			4: #afterimage_at
				gamelogic.afterimage_terrain(current_animation[1], current_animation[2], current_animation[3]);
			5: #fade
					if (fade_tween != null):
						fade_tween.queue_free();
					fade_tween = Tween.new();
					self.add_child(fade_tween);
					fade_tween.interpolate_property(self, "modulate:a", current_animation[1], current_animation[2], current_animation[3]);
					fade_tween.start();
			6: #stall
				animation_timer_max = current_animation[1];
				animation_timer += delta;
				if (animation_timer > animation_timer_max):
					is_done = true;
				else:
					is_done = false;
			7: #intro
				is_done = true;
			8: #outro
				is_done = true;
			9: #spliceflower
				gamelogic.play_sound("spliceflower");
				if (animation_timer < 99): #don't make ripples while a replay is going fast
					# particles
					for i in range(8):
						var sprite = Sprite.new();
						sprite.set_script(preload("res://FadingSprite.gd"));
						sprite.texture = preload("res://assets/SpliceFlowerTexture.tres");
						sprite.position = Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
						sprite.centered = true;
						sprite.fadeout_timer_max = 2.0;
						sprite.velocity = Vector2(16, 0).rotated(i*PI/4);
						self.add_child(sprite);
					ripple = preload("res://Ripple.tscn").instance();
					ripple_timer = 0;
					ripple.rect_position += Vector2(12, 12);
					self.add_child(ripple);
			10: #wonderchange
				gamelogic.play_sound("wonderchange");
				if (animation_timer < 99): #my eyes
					gamelogic.undo_effect_strength = 0.4;
					gamelogic.undo_effect_per_second = gamelogic.undo_effect_strength*(1);
					gamelogic.undo_effect_color = gamelogic.red_color;
					var node2d = Node2D.new();
					node2d.set_script(preload("res://CoolCircle.gd"));
					node2d.position = self.position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
					gamelogic.overactorsparticles.add_child(node2d);
			11:
				var text = current_animation[1];
				gamelogic.floating_text(text,
				self.global_position + Vector2(gamelogic.cell_size/2, -gamelogic.cell_size/2))
				if (text == "!"):
					gamelogic.play_sound("surpriseblock");
				elif (text == "?"):
					gamelogic.play_sound("whereblock");
		if (is_done):
			animations.pop_front();
			animation_timer = 0;
		
