extends ActorBase
class_name Actor

var gamelogic = null
var actorname : int = -1
var stored_position : Vector2 = Vector2.ZERO
var pos : Vector2 = Vector2.ZERO
var broken : bool = false
var post_mortem : int = -1;
var strength : int = 0
var heaviness : int = 0
var durability : int = 0
var is_star : bool = false
var is_character : bool = false
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
# green
var is_green = false;
var time_bubble = null;

enum PostMortems {
	Fall,
	Melt,
	Collect
}

# faster than string comparisons
enum Name {
	Player,
	Star,
	DirtBlock,
	IceBlock,
	Goal,
	CrackedStar,
	DarkStar,
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
		
		Name.Star:
			return preload("res://assets/star_spritesheet.png");
		
		Name.DirtBlock:
			if broken:
				return null;
			else:
				return preload("res://assets/dirt_block.png");
				
		Name.IceBlock:
			if broken:
				return null;
			else:
				frame = 0;
				return preload("res://assets/ice_melt_spritesheet.png");
				
		Name.CrackedStar:
			if broken:
				return null;
			else:
				return preload("res://assets/cracked_star.png");
				
		Name.DarkStar:
			if broken:
				return null;
			else:
				return preload("res://assets/dark_star.png");
		
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
		preload("res://assets/star_spritesheet.png"):
			hframes = 6;
			vframes = 1;
			if (broken):
				frame = 3;
			else:
				frame = 0;
		preload("res://assets/ice_melt_spritesheet.png"):
			hframes = 8;
			vframes = 1;
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
	if (is_star and by_actor.actorname == Name.Player):
		return false;
	if (just_moved):
		return false;
	return !broken;
		
func phases_into_terrain() -> bool:
	return false;
	
func phases_into_actors() -> bool:
	return false;

func afterimage() -> void:
	gamelogic.afterimage(self);
	
func update_time_bubble():
	if time_bubble != null:
		time_bubble.queue_free();
		time_bubble = null;
	if is_green:
		if (time_bubble == null):
			time_bubble = Sprite.new();
			time_bubble.set_script(preload("res://TimeBubble.gd"));
			time_bubble.texture = preload("res://assets/time_bubble.png");
			time_bubble.centered = true;
			time_bubble.position = Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
			self.add_child(time_bubble);

func _process(delta: float) -> void:
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
			
	elif actorname == Name.IceBlock:
		if moving != Vector2.ZERO:
			frame_timer += delta;
			if (frame_timer > frame_timer_max):
				frame_timer -= frame_timer_max;
				# spawn an ice puff
				var sprite = Sprite.new();
				sprite.set_script(preload("res://FadingSprite.gd"));
				sprite.texture = preload("res://assets/pixel.png");
				sprite.fadeout_timer_max = 0.8;
				sprite.velocity = (-moving*gamelogic.rng.randf_range(8, 16)).rotated(gamelogic.rng.randf_range(-0.5, 0.5));
				sprite.position = position + Vector2(gamelogic.rng.randf_range(gamelogic.cell_size*1/4, gamelogic.cell_size*3/4), gamelogic.rng.randf_range(gamelogic.cell_size*1/4, gamelogic.cell_size*3/4));
				sprite.centered = true;
				sprite.scale = Vector2(2, 2);
				gamelogic.overactorsparticles.add_child(sprite);
	
	# animation system stuff
	moving = Vector2.ZERO;
	if (animations.size() > 0):
		var current_animation = animations[0];
		var is_done = true;
		match current_animation[0]:
			0: #move
				moving = current_animation[1];
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
			7: #melt
				if (animation_timer == 0):
					gamelogic.play_sound("melt");
				animation_timer_max = 0.4;
				var old_animation_timer_tick = int(animation_timer*10);
				animation_timer += delta;
				var new_animation_timer_tick = int(animation_timer*10);
				if (old_animation_timer_tick != new_animation_timer_tick):
					for i in range(3):
						var sprite = Sprite.new();
						sprite.set_script(preload("res://FadingSprite.gd"));
						if (gamelogic.rng.randi_range(0, 1) == 1):
							sprite.texture = preload("res://assets/ice_melt_spritesheet.png")
							sprite.hframes = 8;
							sprite.vframes = 1;
							sprite.frame = 5;
							sprite.fadeout_timer_max = 0.4;
							sprite.velocity = Vector2(gamelogic.rng.randf_range(16, 32), 0).rotated(gamelogic.rng.randf_range(0, PI*2));
						else:
							sprite.texture = preload("res://assets/dust.png")
							sprite.hframes = 8;
							sprite.vframes = 1;
							sprite.frame = gamelogic.rng.randi_range(0, sprite.hframes - 1);
							sprite.fadeout_timer_max = 0.8;
							sprite.velocity = Vector2(0, -gamelogic.rng.randf_range(16, 32)).rotated(gamelogic.rng.randf_range(-0.5, 0.5));
						sprite.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
						sprite.centered = true;
						gamelogic.overactorsparticles.add_child(sprite);
				frame = clamp(round((animation_timer / animation_timer_max)*(hframes-1)), 0, hframes - 1); #or floor or ceil
				if (animation_timer > animation_timer_max):
					is_done = true;
				else:
					is_done = false;
			8: #unmelt
				# since it's currently invisible due to being 'broken'
				texture = preload("res://assets/ice_melt_spritesheet.png");
				visible = true;
				if (animation_timer == 0):
					gamelogic.play_sound("unmelt");
				animation_timer_max = 0.4;
				var old_animation_timer_tick = int(animation_timer*10);
				animation_timer += delta;
				var new_animation_timer_tick = int(animation_timer*10);
				if (old_animation_timer_tick != new_animation_timer_tick):
					for i in range(4):
						var sprite = null;
						if (gamelogic.rng.randi_range(0, 1) == 1):
							sprite = gamelogic.afterimage_terrain(preload("res://assets/ice_melt_spritesheet.png"), position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2), gamelogic.red_color);
							if (sprite != null):
								var child = sprite.get_child(0);
								child.centered = true;
								child.hframes = 8;
								child.vframes = 1;
								child.frame = 4;
								sprite.timer_max = 0.4;
								sprite.velocity = Vector2(gamelogic.rng.randf_range(16, 32), 0).rotated(gamelogic.rng.randf_range(0, PI*2));
								sprite.position -= sprite.velocity*sprite.timer_max;
				frame = clamp(round((animation_timer / animation_timer_max)*(hframes-1)), 0, hframes - 1); #or floor or ceil
				frame = (hframes-1)-frame;
				if (animation_timer > animation_timer_max):
					is_done = true;
				else:
					is_done = false;
			9: #starget
				var c = Color("E0B94A");
				if (animation_timer == 0):
					if (!gamelogic.currently_fast_replay()):
						gamelogic.play_sound("starget");
						var sparklespawner = Node2D.new();
						sparklespawner.script = preload("res://SparkleSpawner.gd");
						sparklespawner.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
						gamelogic.overactorsparticles.add_child(sparklespawner);
						sparklespawner.color = c;
						gamelogic.undo_effect_strength = 0.12;
						gamelogic.undo_effect_per_second = 0.12;
						gamelogic.undo_effect_color = c;
						gamelogic.floating_text("You got a Star!");
				animation_timer_max = 1.0;
				var old_animation_timer_tick = int(animation_timer*5);
				animation_timer += delta;
				var new_animation_timer_tick = int(animation_timer*5);
				if (old_animation_timer_tick != new_animation_timer_tick):
					for i in range(2):
						var sprite = Sprite.new();
						sprite.set_script(preload("res://FadingSprite.gd"));
						if (i == 0):
							sprite.texture = preload("res://assets/star_particle_smaller.png")
							sprite.modulate = c;
							sprite.fadeout_timer_max = 1.6;
							sprite.velocity = Vector2(gamelogic.rng.randf_range(8, 16), 0).rotated(gamelogic.rng.randf_range(0, PI*2));
							sprite.rotation = gamelogic.rng.randf_range(0, PI*2);
						else:
							sprite.texture = preload("res://assets/action_line.png")
							sprite.modulate = c;
							sprite.fadeout_timer_max = 1.6;
							sprite.rotation = gamelogic.rng.randf_range(0, PI*2);
							sprite.velocity = Vector2(0, -gamelogic.rng.randf_range(8, 16)).rotated(sprite.rotation);
							sprite.scale = Vector2(2.0, 2.0);
						sprite.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
						sprite.position += sprite.velocity;
						sprite.centered = true;
						gamelogic.overactorsparticles.add_child(sprite);
				if (self.actorname == Name.Star):
					frame = clamp(round((animation_timer / animation_timer_max)*3), 0, 3);
				if (animation_timer > animation_timer_max):
					if (self.actorname == Name.Star):
						frame = 3;
					is_done = true;
				else:
					is_done = false;
				
			10: #starunget
				var c = Color("A7A79E");
				if (animation_timer == 0):
					if (!gamelogic.currently_fast_replay()):
						gamelogic.play_sound("unwin");
						var sparklespawner = Node2D.new();
						sparklespawner.script = preload("res://SparkleSpawner.gd");
						sparklespawner.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
						gamelogic.overactorsparticles.add_child(sparklespawner);
						sparklespawner.color = c;
						gamelogic.undo_effect_strength = 0.12;
						gamelogic.undo_effect_per_second = 0.12;
						gamelogic.undo_effect_color = c;
						gamelogic.floating_text("You recall not having that Star...", true);
				animation_timer_max = 1.0;
				var old_animation_timer_tick = int(animation_timer*5);
				animation_timer += delta;
				var new_animation_timer_tick = int(animation_timer*5);
				if (old_animation_timer_tick != new_animation_timer_tick):
					for i in range(2):
						var sprite = Sprite.new();
						sprite.set_script(preload("res://FadingSprite.gd"));
						if (i == 0):
							sprite.texture = preload("res://assets/star_particle_smaller.png")
							sprite.modulate = c;
							sprite.fadeout_timer_max = 1.6;
							sprite.velocity = Vector2(gamelogic.rng.randf_range(8, 16), 0).rotated(gamelogic.rng.randf_range(0, PI*2));
							sprite.rotation = gamelogic.rng.randf_range(0, PI*2);
						else:
							sprite.texture = preload("res://assets/action_line.png")
							sprite.modulate = c;
							sprite.fadeout_timer_max = 1.6;
							sprite.rotation = gamelogic.rng.randf_range(0, PI*2);
							sprite.velocity = Vector2(0, -gamelogic.rng.randf_range(8, 16)).rotated(sprite.rotation);
							sprite.scale = Vector2(2.0, 2.0);
						sprite.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
						sprite.position -= sprite.velocity*2;
						sprite.centered = true;
						gamelogic.overactorsparticles.add_child(sprite);
				if (self.actorname == Name.Star):
					frame = clamp(3 + round((animation_timer / animation_timer_max)*2), 3, 5);
				if (animation_timer > animation_timer_max):
					if (self.actorname == Name.Star):
						frame = 0;
					is_done = true;
				else:
					is_done = false;
			11: #sing
				animation_timer_max = 1.0;
				var old_animation_timer_tick = int(animation_timer*5);
				var old_animation_timer = animation_timer;
				animation_timer += delta;
				var new_animation_timer_tick = int(animation_timer*5);
				if (old_animation_timer == 0 or old_animation_timer_tick != new_animation_timer_tick):
					var sprite = Sprite.new();
					sprite.set_script(preload("res://FadingSprite.gd"));
					sprite.texture = preload("res://assets/note_particle.png")
					sprite.hframes = 2;
					sprite.vframes = 1;
					sprite.frame = gamelogic.rng.randi_range(0, sprite.hframes - 1);
					sprite.fadeout_timer_max = 0.8;
					sprite.velocity = Vector2(0, -gamelogic.rng.randf_range(16, 32)).rotated(gamelogic.rng.randf_range(-0.5, 0.5));
					sprite.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
					sprite.position += sprite.velocity*0.4;
					sprite.position.x += gamelogic.rng.randf_range(-8, 8);
					sprite.centered = true;
					sprite.sine_mult = 7.0;
					sprite.sine_offset = 3.0;
					sprite.sine_timer = gamelogic.rng.randf_range(0.0, 100.0);
					gamelogic.overactorsparticles.add_child(sprite);
				if animation_timer > animation_timer_max:
					is_done = true;
				else:
					is_done = false;
					var adjusted_frame = 5 + new_animation_timer_tick % 2;
					frame = base_frame + adjusted_frame;
			12: #fall
				if (animation_timer == 0):
					gamelogic.play_sound("plummet");
				animation_timer_max = 0.5;
				var old_animation_timer_tick = int(animation_timer*10);
				animation_timer += delta;
				var new_animation_timer_tick = int(animation_timer*10);
				var hole = null;
				if (gamelogic.hole_sprites.has(pos)):
					hole = gamelogic.hole_sprites[pos];
				if (hole != null):
					if actorname == Name.Player:
						hole.frame = hole.hframes;
						# TODO: do player kick here
					elif (actorname == Name.IceBlock):
						hole.frame = hole.hframes*2;
					else:
						hole.frame = 0;
					hole.frame += clamp(floor((animation_timer/animation_timer_max)*hole.hframes), 0, hole.hframes-1);
				if (old_animation_timer_tick != new_animation_timer_tick):
					var sprite = Sprite.new();
					sprite.set_script(preload("res://FadingSprite.gd"));
					sprite.texture = preload("res://assets/action_line.png")
					sprite.modulate = Color("A7A79E")
					sprite.fadeout_timer_max = 0.4;
					sprite.velocity = Vector2(0, -32)
					sprite.position = position;
					sprite.position.x += gamelogic.rng.randf_range(gamelogic.cell_size*0.25, gamelogic.cell_size*0.75);
					sprite.centered = true;
					gamelogic.overactorsparticles.add_child(sprite);
				self.modulate.a = 1.0-(animation_timer/animation_timer_max);
				if animation_timer > animation_timer_max:
					is_done = true;
					gamelogic.play_sound("crashland");
					if (hole != null):
						hole.queue_free();
						gamelogic.hole_sprites.erase(pos);
					for i in range(10):
						var sprite = Sprite.new();
						sprite.set_script(preload("res://FadingSprite.gd"));
						sprite.texture = preload("res://assets/dust.png")
						sprite.hframes = 8;
						sprite.vframes = 1;
						sprite.frame = gamelogic.rng.randi_range(0, sprite.hframes - 1);
						sprite.fadeout_timer_max = 0.4;
						sprite.velocity = Vector2(gamelogic.rng.randf_range(16, 32), 0).rotated(gamelogic.rng.randf_range(0, PI*2));
						sprite.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
						sprite.centered = true;
						gamelogic.overactorsparticles.add_child(sprite);
				else:
					if (actorname == Name.Player):
						var adjusted_frame = 1 + (new_animation_timer_tick % 2)*2;
						frame = base_frame + adjusted_frame;
					is_done = false;
			13: #intro
				facing_dir = Vector2.RIGHT;
				base_frame = 0;
				animation_frame = 0;
				self.texture = preload("res://assets/intro_spritesheet.png");
				self.hframes = 17;
				self.vframes = 1;
				animation_timer_max = current_animation[1];
				var old_animation_timer_tick = int(animation_timer*10);
				animation_timer += delta;
				var new_animation_timer_tick = int(animation_timer*10);
				if (old_animation_timer_tick != new_animation_timer_tick):
					var sprite = Sprite.new();
					sprite.set_script(preload("res://FadingSprite.gd"));
					sprite.texture = preload("res://assets/intro_particle.png")
					sprite.hframes = 2;
					sprite.vframes = 1;
					sprite.frame = gamelogic.rng.randi_range(0, sprite.hframes - 1);
					sprite.fadeout_timer_max = 0.8;
					sprite.velocity = Vector2(0, -gamelogic.rng.randf_range(16, 32)).rotated(gamelogic.rng.randf_range(-0.5, 0.5));
					sprite.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
					sprite.position += sprite.velocity*0.4;
					sprite.position.x += gamelogic.rng.randf_range(-8, 8);
					sprite.position.y += (1.0-(animation_timer/animation_timer_max))*gamelogic.cell_size*2;
					sprite.centered = true;
					sprite.sine_mult = 7.0;
					sprite.sine_offset = 3.0;
					sprite.sine_timer = gamelogic.rng.randf_range(0.0, 100.0);
					gamelogic.overactorsparticles.add_child(sprite);
				self.frame = clamp(floor((animation_timer/animation_timer_max)*hframes), 0, hframes - 1);
				if animation_timer > animation_timer_max:
					if (animation_timer_max >= 2.0):
						gamelogic.undo_effect_color = gamelogic.meta_color;
						gamelogic.afterimage(self);
						for i in range(10):
							var sprite = Sprite.new();
							sprite.set_script(preload("res://FadingSprite.gd"));
							sprite.texture = preload("res://assets/intro_particle.png")
							sprite.hframes = 2;
							sprite.vframes = 1;
							sprite.frame = gamelogic.rng.randi_range(0, sprite.hframes - 1);
							sprite.fadeout_timer_max = 1.6;
							sprite.scale = Vector2(1.0, 1.0);
							sprite.velocity = Vector2(gamelogic.rng.randf_range(16, 32), 0).rotated(gamelogic.rng.randf_range(0, PI*2));
							sprite.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2) + sprite.velocity*0.25;
							sprite.centered = true;
							gamelogic.overactorsparticles.add_child(sprite);
					is_done = true;
					update_graphics();
				else:
					is_done = false;
			14: #outro
				#same code as intro but with anim reversed
				facing_dir = Vector2.RIGHT;
				base_frame = 0;
				animation_frame = 0;
				self.texture = preload("res://assets/intro_spritesheet.png");
				self.hframes = 17;
				self.vframes = 1;
				animation_timer_max = current_animation[1];
				var old_animation_timer_tick = int(animation_timer*10);
				animation_timer += delta;
				var new_animation_timer_tick = int(animation_timer*10);
				if (old_animation_timer_tick != new_animation_timer_tick):
					var sprite = Sprite.new();
					sprite.set_script(preload("res://FadingSprite.gd"));
					sprite.texture = preload("res://assets/intro_particle.png")
					sprite.hframes = 3;
					sprite.vframes = 1;
					sprite.frame = gamelogic.rng.randi_range(0, sprite.hframes - 1);
					sprite.fadeout_timer_max = 0.8;
					sprite.velocity = Vector2(0, -gamelogic.rng.randf_range(16, 32)).rotated(gamelogic.rng.randf_range(-0.5, 0.5));
					sprite.position = position + Vector2(gamelogic.cell_size/2, gamelogic.cell_size/2);
					sprite.position += sprite.velocity*0.4;
					sprite.position.x += gamelogic.rng.randf_range(-8, 8);
					sprite.position.y += ((animation_timer/animation_timer_max))*gamelogic.cell_size*2;
					sprite.centered = true;
					sprite.sine_mult = 7.0;
					sprite.sine_offset = 3.0;
					sprite.sine_timer = gamelogic.rng.randf_range(0.0, 100.0);
					gamelogic.overactorsparticles.add_child(sprite);
				self.frame = clamp(floor((1.0-animation_timer/animation_timer_max)*hframes), 0, hframes - 1);
				if animation_timer > animation_timer_max:
					is_done = true;
					texture = null;
				else:
					is_done = false;
			15: #time_bubble
				update_time_bubble();
				gamelogic.play_sound("usegreenality");
				gamelogic.undo_effect_strength = 0.4;
				gamelogic.undo_effect_per_second = gamelogic.undo_effect_strength*(1);
				gamelogic.undo_effect_color = gamelogic.meta_color;
		if (is_done):
			animations.pop_front();
			animation_timer = 0;
		
