extends Node
class_name GameLogic

onready var levelscene : Node2D = get_node("/root/LevelScene"); #this one runs before SuperScaling so it's safe!
onready var underterrainfolder : Node2D = levelscene.get_node("UnderTerrainFolder");
onready var actorsfolder : Node2D = levelscene.get_node("ActorsFolder");
onready var levelfolder : Node2D = levelscene.get_node("LevelFolder");
onready var terrainmap : TileMap = levelfolder.get_node("TerrainMap");
onready var overactorsparticles : Node2D = levelscene.get_node("OverActorsParticles");
onready var underactorsparticles : Node2D = levelscene.get_node("UnderActorsParticles");
onready var menubutton : Button = levelscene.get_node("MenuButton");
onready var levellabel : Label = levelscene.get_node("LevelLabel");
onready var levelstar : Sprite = levelscene.get_node("LevelStar");
onready var starbar : StarBar = levelscene.get_node("StarBar");
onready var winlabel : Node2D = levelscene.get_node("WinLabel");
onready var metainfolabel : Label = levelscene.get_node("MetaInfoLabel");
onready var tutoriallabel : RichTextLabel = levelscene.get_node("TutorialLabel");
onready var downarrow : Sprite = levelscene.get_node("DownArrow");
onready var leftarrow : Sprite = levelscene.get_node("LeftArrow");
onready var rightarrow : Sprite = levelscene.get_node("RightArrow");
onready var Shade : Node2D = levelscene.get_node("Shade");
onready var checkerboard : TextureRect = levelscene.get_node("Checkerboard");
onready var rng : RandomNumberGenerator = RandomNumberGenerator.new();
onready var virtualbuttons : Node2D = levelscene.get_node("VirtualButtons");
onready var replaybuttons : Node2D = levelscene.get_node("ReplayButtons");
onready var replayturnlabel : Label = levelscene.get_node("ReplayButtons/ReplayTurn/ReplayTurnLabel");
onready var replayturnslider : HSlider = levelscene.get_node("ReplayButtons/ReplayTurn/ReplayTurnSlider");
onready var replayspeedlabel : Label = levelscene.get_node("ReplayButtons/ReplaySpeed/ReplaySpeedLabel");
onready var replayspeedslider : HSlider = levelscene.get_node("ReplayButtons/ReplaySpeed/ReplaySpeedSlider");
var replayturnsliderset : bool = false;
var replayspeedsliderset : bool = false;
onready var metaredobutton : Button = virtualbuttons.get_node("Verbs/MetaRedoButton");
onready var metaredobuttonlabel : Label = metaredobutton.get_node("MetaRedoLabel");

# distinguish between temporal layers when a move or state change happens
# ghosts is for undo trail ghosts
enum Chrono {
	MOVE
	CHAR_UNDO
	META_UNDO
	TIMELESS
	GHOSTS
}

# distinguish between different strengths of movement. Gravity is also special in that it won't try to make
# 'voluntary' movements like going past thin platforms.
enum Strength {
	NONE
	CRYSTAL
	WOODEN
	LIGHT
	HEAVY
	GRAVITY
}

# distinguish between different heaviness. Light is IRON and Heavy is STEEL.
enum Heaviness {
	NONE
	CRYSTAL
	WOODEN
	IRON
	STEEL
	SUPERHEAVY
	INFINITE
}

# yes means 'do the thing you intended'. no means 'cancel it and this won't cause time to pass'.
# surprise means 'cancel it but there was a side effect so time passes'.
enum Success {
	Yes,
	No,
	Surprise,
}

# types of undo events

enum Undo {
	move, #0
	set_actor_var, #1
	red_turn, #2
	blue_turn, #3
	red_undo_event_add, #4
	blue_undo_event_add, #5
	red_undo_event_remove, #6
	blue_undo_event_remove, #7
	animation_substep, #8
	change_terrain, #9
	sfx, #10
	time_bubble, #11
}

# and same for animations
enum Anim {
	move, #0
	bump, #1
	set_next_texture, #2
	sfx, #3
	afterimage_at, #4
	fade, #5
	stall, #6
	melt, #7
	unmelt, #8
	starget, #9
	starunget, #10
	sing, #11
	fall, #12
	intro, #13
	outro, #14
	time_bubble, #15
}

enum Greenness {
	Mundane,
	Green,
	Void
}

# attempted performance optimization - have an enum of all tile ids and assert at startup that they're right
# order SEEMS to be the same as in DefaultTiles
# keep in sync with LevelEditor
enum Tiles {
	Floor,
	Wall,
	Player,
	Win,
	Star,
	DirtBlock,
	IceBlock,
	Hole,
	BottomlessPit,
	Water,
	Ice,
	MagicBarrier,
	CrackedStar,
	DarkStar,
	GreenAura,
	OneWayWest,
	OneWaySouth,
	OneWayNorth,
	OneWayEast,
}

# information about the level
var is_custom : bool = false;
var test_mode : bool = false;
var custom_string : String = "";
var chapter : int = 0;
var level_in_chapter : int = 0;
var level_is_extra : bool = false;
var in_insight_level : bool = false;
var has_insight_level : bool = false;
var insight_level_scene = null;
var level_number : int = 0
var level_name : String = "Blah Blah Blah";
var level_replay : String = "";
var annotated_authors_replay : String = "";
var authors_replay : String = "";
var level_author : String = "";
var map_x_max : int = 0;
var map_y_max : int = 0;
var map_x_max_max : int = 31; # can change these if I want to adjust hori/vertical scrolling
var map_y_max_max : int = 15;
var terrain_layers : Array = []
var voidlike_puzzle : bool = false;

# information about the actors and their state
var player : Actor = null
var actors : Array = []
var goals : Array = []
var hole_sprites : Dictionary = {}
# red is for 'undo', blue is for 'unwin', meta/green is for 'really undo'
var red_turn : int = 0;
var red_undo_buffer : Array = [];
var blue_turn : int = 0;
var blue_undo_buffer : Array = [];
var meta_turn : int = 0;
var meta_undo_buffer : Array = [];

# for afterimages
var afterimage_server : Dictionary = {}

# save file, ooo!
var save_file : Dictionary = {}
var puzzles_completed : int = 0;
var advanced_puzzles_completed : int = 0;
var specific_puzzles_completed : Array = [];

# song-and-dance state
var sounds : Dictionary = {}
var music_tracks : Array = [];
var music_info : Array = [];
var music_db : Array = [];
var now_playing = null;
var speakers : Array = [];
var target_track : int = -1;
var current_track : int = -1;
var fadeout_timer : float = 0.0;
var fadeout_timer_max : float = 0.0;
var fanfare_duck_db : float = 0.0;
var music_discount : float = -10.0;
var music_speaker = null;
var lost_speaker = null;
var lost_speaker_volume_tween;
var won_speaker = null;
var sounds_played_this_frame : Dictionary = {};
var muted : bool = false;
var won : bool = false;
var won_cooldown : float = 0.0;
var lost : bool = false;
var won_fade_started : bool = false;
var cell_size : int = 16;
var undo_effect_strength : float = 0;
var undo_effect_per_second : float = 0;
var undo_effect_color : Color = Color(0, 0, 0, 0);
var red_color : Color = Color("CF6A4F");
var blue_color : Color = Color("E0B94A");
var meta_color : Color = Color("B2AF5C");
var ui_stack : Array = [];
var ready_done : bool = false;
var using_controller : bool = false;

#UI defaults
var win_label_default_y : float = 113.0;
var pixel_width : int = ProjectSettings.get("display/window/size/width"); #512
var pixel_height : int = ProjectSettings.get("display/window/size/height"); #300

# animation server
var animation_server : Array = []
var animation_substep : int = 0;
var animation_nonce_fountain : int = 0;

#replay system
var replay_timer : float = 0.0;
var user_replay : String  = "";
var user_replay_before_restarts : Array = [];
var meta_redo_inputs : String = "";
var preserving_meta_redo_inputs : bool = false;
var doing_replay : bool = false;
var replay_paused : bool = false;
var replay_turn : int = 0;
var replay_interval : float = 0.5;
var next_replay : float = -1.0;
var unit_test_mode : bool = false;
var meta_undo_a_restart_mode : bool = false;

# list of levels in the game
var level_list : Array = [];
var level_filenames : Array = [];
var level_names : Array = [];
var level_extraness : Array = [];
var has_remix : Dictionary = {};
var insight_level_names : Dictionary = {};
var chapter_names : Array = [];
var chapter_skies : Array = [];
var chapter_tracks : Array = [];
var chapter_replacements : Dictionary = {};
var level_replacements : Dictionary = {};
var target_sky : Color = Color("25272a");
var old_sky : Color = Color("25272a");
var current_sky : Color = Color("25272a");
var sky_timer : float = 0.0;
var sky_timer_max : float = 0.0;
var chapter_standard_starting_levels : Array = [];
var chapter_advanced_starting_levels : Array = [];
var chapter_standard_unlock_requirements : Array = [];
var chapter_advanced_unlock_requirements : Array = [];
var save_file_string : String = "user://unwin.sav";

var is_web : bool = false;

var starticipation_timer : float = 0.0;
var starticipation_timer_max : float = 1.0;

# tutorial system
var z_shown : bool = false;
var z_used : bool = false;
var x_shown : bool = false;
var x_used : bool = false;
var c_shown : bool = false;
var c_used : bool = false;

func save_game():
	var file = File.new()
	file.open(save_file_string, File.WRITE)
	file.store_line(to_json(save_file))
	file.close()
	if (player != null):
		update_info_labels();

func default_save_file() -> void:
	if (save_file == null or typeof(save_file) != TYPE_DICTIONARY):
		save_file = {};
	if (!save_file.has("level_number")):
		save_file["level_number"] = 0
	if (!save_file.has("levels")):
		save_file["levels"] = {}
	if (!save_file.has("version")):
		save_file["version"] = 0
	if (!save_file.has("music_volume")):
		save_file["music_volume"] = 0.0;
	if (!save_file.has("sfx_volume")):
		save_file["sfx_volume"] = 0.0;
	if (!save_file.has("fanfare_volume")):
		save_file["fanfare_volume"] = 0.0;
	if (!save_file.has("master_volume")):
		save_file["master_volume"] = 0.0;
	if (!save_file.has("resolution")):
		var value = 2;
		if (save_file.has("pixel_scale")):
			value = save_file["pixel_scale"];
		save_file["resolution"] = str(pixel_width*value) + "x" + str(pixel_height*value);
		save_file.erase("pixel_scale");
	if (!save_file.has("fps")):
		save_file["fps"] = 60;
	if (!save_file.has("virtual_buttons")):
		save_file["virtual_buttons"] = 1
		setup_virtual_buttons()

func load_game():
	var file = File.new()
	if not file.file_exists(save_file_string):
		return default_save_file();
		
	file.open(save_file_string, File.READ)
	var json_parse_result = JSON.parse(file.get_as_text())
	file.close();
	
	if json_parse_result.error == OK:
		var data = json_parse_result.result;
		if typeof(data) == TYPE_DICTIONARY:
			save_file = data;
		else:
			return default_save_file();
	else:
		return default_save_file();
	
	default_save_file();
	
	react_to_save_file_update();

func _ready() -> void:
	var os_name = OS.get_name();
	if (os_name == "HTML5" or os_name == "Android" or os_name == "iOS"):
		is_web = true;
	
	# Call once when the game is booted up.
	menubutton.connect("pressed", self, "escape");
	winlabel.call_deferred("change_text", "You have won!\n\n[" + human_readable_input("ui_accept", 1) + "]: Continue\nWatch Replay: Menu -> Your Replay");
	connect_virtual_buttons();
	prepare_audio();
	call_deferred("adjust_winlabel");
	call_deferred("setup_gui_holder");
	load_game();
	initialize_level_list();
	tile_changes();
	initialize_shaders();
	if (OS.is_debug_build()):
		assert_tile_enum();
	
	# Load the first map.
	load_level(0);
	ready_done = true;
	# But mute the music until we're ready.
	current_track = -1;
	
	var already_won = false;
	var levels_save_data = save_file["levels"];
	if (!levels_save_data.has(level_name)):
		levels_save_data[level_name] = {};
	var level_save_data = levels_save_data[level_name];
	if (level_save_data.has("won") and level_save_data["won"]):
		already_won = true;
	
	if (is_web or !already_won):
		var a = preload("res://WebStartup.tscn").instance();
		call_deferred("add_to_ui_stack", a)
	else:
		var timetostart = Node2D.new();
		timetostart.script = preload("res://WaitForDraw.gd");
		timetostart.gamelogic = self;
		self.get_parent().call_deferred("add_child", timetostart);

func time_to_start() -> void:
	play_sound("intro");
	current_track = -1;
	target_track = 0;
	fadeout_timer = 0.0;
	fadeout_timer_max = 6.8;
	intro_hop();

var GuiHolder : CanvasLayer;

func setup_gui_holder() -> void:
	GuiHolder = CanvasLayer.new();
	GuiHolder.name = "GuiHolder";
	get_parent().get_parent().add_child(GuiHolder);
	var ui_elements = [levelstar, levellabel, replaybuttons, virtualbuttons, winlabel, tutoriallabel, metainfolabel, menubutton];
	for ui_element in ui_elements:
		ui_element.get_parent().remove_child(ui_element);
		GuiHolder.add_child(ui_element);

func add_to_ui_stack(node: Node, parent: Node = null) -> void:
	ui_stack.push_back(node);
	if (parent != null):
		parent.add_child(node);
	else:
		GuiHolder.add_child(node);

func connect_virtual_buttons() -> void:
	virtualbuttons.get_node("Verbs/UndoButton").connect("button_down", self, "_undobutton_pressed");
	virtualbuttons.get_node("Verbs/UndoButton").connect("button_up", self, "_undobutton_released");
	virtual_button_name_to_action["UndoButton"] = "character_undo";
	virtualbuttons.get_node("Verbs/UnwinButton").connect("button_down", self, "_unwinbutton_pressed");
	virtualbuttons.get_node("Verbs/UnwinButton").connect("button_up", self, "_unwinbutton_released");
	virtual_button_name_to_action["UnwinButton"] = "character_unwin";
	virtualbuttons.get_node("Verbs/MetaUndoButton").connect("button_down", self, "_metaundobutton_pressed");
	virtualbuttons.get_node("Verbs/MetaUndoButton").connect("button_up", self, "_metaundobutton_released");
	virtual_button_name_to_action["MetaUndoButton"] = "meta_undo";
	virtualbuttons.get_node("Verbs/MetaRedoButton").connect("button_down", self, "_metaredobutton_pressed");
	virtualbuttons.get_node("Verbs/MetaRedoButton").connect("button_up", self, "_metaredobutton_released");
	virtual_button_name_to_action["MetaRedoButton"] = "meta_redo";
	virtualbuttons.get_node("Dirs/LeftButton").connect("button_down", self, "_leftbutton_pressed");
	virtualbuttons.get_node("Dirs/LeftButton").connect("button_up", self, "_leftbutton_released");
	virtual_button_name_to_action["LeftButton"] = "ui_left";
	virtualbuttons.get_node("Dirs/DownButton").connect("button_down", self, "_downbutton_pressed");
	virtualbuttons.get_node("Dirs/DownButton").connect("button_up", self, "_downbutton_released");
	virtual_button_name_to_action["DownButton"] = "ui_down";
	virtualbuttons.get_node("Dirs/RightButton").connect("button_down", self, "_rightbutton_pressed");
	virtualbuttons.get_node("Dirs/RightButton").connect("button_up", self, "_rightbutton_released");
	virtual_button_name_to_action["RightButton"] = "ui_right";
	virtualbuttons.get_node("Dirs/UpButton").connect("button_down", self, "_upbutton_pressed");
	virtualbuttons.get_node("Dirs/UpButton").connect("button_up", self, "_upbutton_released");
	virtual_button_name_to_action["UpButton"] = "ui_up";
	virtualbuttons.get_node("Others/EnterButton").connect("button_down", self, "_enterbutton_pressed");
	virtualbuttons.get_node("Others/EnterButton").connect("button_up", self, "_enterbutton_released");
	replaybuttons.get_node("ReplaySpeed/F9Button").connect("button_down", self, "_f9button_pressed");
	replaybuttons.get_node("ReplaySpeed/F9Button").connect("button_up", self, "_f9button_released");
	virtual_button_name_to_action["F9Button"] = "slowdown_replay";
	replaybuttons.get_node("ReplaySpeed/F10Button").connect("button_down", self, "_f10button_pressed");
	replaybuttons.get_node("ReplaySpeed/F10Button").connect("button_up", self, "_f10button_released");
	virtual_button_name_to_action["F10Button"] = "speedup_replay";
	replaybuttons.get_node("ReplayTurn/PrevTurnButton").connect("button_down", self, "_prevturnbutton_pressed");
	replaybuttons.get_node("ReplayTurn/PrevTurnButton").connect("button_up", self, "_prevturnbutton_released");
	virtual_button_name_to_action["PrevTurnButton"] = "replay_back1";
	replaybuttons.get_node("ReplayTurn/NextTurnButton").connect("button_down", self, "_nextturnbutton_pressed");
	replaybuttons.get_node("ReplayTurn/NextTurnButton").connect("button_up", self, "_nextturnbutton_released");
	virtual_button_name_to_action["NextTurnButton"] = "replay_fwd1";
	replaybuttons.get_node("ReplayTurn/PauseButton").connect("button_down", self, "_pausebutton_pressed");
	replaybuttons.get_node("ReplayTurn/PauseButton").connect("button_up", self, "_pausebutton_released");
	virtual_button_name_to_action["PauseButton"] = "replay_pause";
	replaybuttons.get_node("ReplayTurn/ReplayTurnSlider").connect("value_changed", self, "_replayturnslider_value_changed");
	replaybuttons.get_node("ReplayTurn/ReplayTurnSlider").connect("drag_started", self, "_replayturnslider_drag_started");
	replaybuttons.get_node("ReplayTurn/ReplayTurnSlider").connect("drag_ended", self, "_replayturnslider_drag_ended");
	replaybuttons.get_node("ReplaySpeed/ReplaySpeedSlider").connect("value_changed", self, "_replayspeedslider_value_changed");
	
func virtual_button_pressed(action: String) -> void:
	if (ui_stack.size() > 0 and ui_stack[ui_stack.size() - 1] != self):
		return;
	Input.action_press(action);
	menubutton.grab_focus();
	menubutton.release_focus();
	if (virtual_button_held_dict.has(action)):
		virtual_button_held_dict[action] = true;
	
func virtual_button_released(action: String) -> void:
	if (ui_stack.size() > 0 and ui_stack[ui_stack.size() - 1] != self):
		return;
	Input.action_release(action);
	menubutton.grab_focus();
	menubutton.release_focus();
	if (virtual_button_held_dict.has(action)):
		virtual_button_held_dict[action] = false;
	
func _undobutton_pressed() -> void:
	virtual_button_pressed("character_undo");
	
func _unwinbutton_pressed() -> void:
	virtual_button_pressed("character_unwin");
	
func _metaundobutton_pressed() -> void:
	virtual_button_pressed("meta_undo");
	
func _metaredobutton_pressed() -> void:
	virtual_button_pressed("meta_redo");
	
func _leftbutton_pressed() -> void:
	virtual_button_pressed("ui_left");
	
func _rightbutton_pressed() -> void:
	virtual_button_pressed("ui_right");
	
func _upbutton_pressed() -> void:
	virtual_button_pressed("ui_up");

func _downbutton_pressed() -> void:
	virtual_button_pressed("ui_down");
	
func _enterbutton_pressed() -> void:
	virtual_button_pressed("ui_accept");
	
func _f9button_pressed() -> void:
	virtual_button_pressed("slowdown_replay");
	
func _f10button_pressed() -> void:
	virtual_button_pressed("speedup_replay");
	
func _prevturnbutton_pressed() -> void:
	virtual_button_pressed("replay_back1");

func _nextturnbutton_pressed() -> void:
	virtual_button_pressed("replay_fwd1");
	
func _pausebutton_pressed() -> void:
	virtual_button_pressed("replay_pause");
	
func _undobutton_released() -> void:
	virtual_button_released("character_undo");
	
func _unwinbutton_released() -> void:
	virtual_button_released("character_unwin");
	
func _metaundobutton_released() -> void:
	virtual_button_released("meta_undo");
	
func _metaredobutton_released() -> void:
	virtual_button_released("meta_redo");
	
func _leftbutton_released() -> void:
	virtual_button_released("ui_left");
	
func _rightbutton_released() -> void:
	virtual_button_released("ui_right");
	
func _upbutton_released() -> void:
	virtual_button_released("ui_up");

func _downbutton_released() -> void:
	virtual_button_released("ui_down");
	
func _enterbutton_released() -> void:
	virtual_button_released("ui_accept");
	
func _f9button_released() -> void:
	virtual_button_released("slowdown_replay");
	
func _f10button_released() -> void:
	virtual_button_released("speedup_replay");
	
func _prevturnbutton_released() -> void:
	virtual_button_released("replay_back1");

func _nextturnbutton_released() -> void:
	virtual_button_released("replay_fwd1");
	
func _pausebutton_released() -> void:
	virtual_button_released("replay_pause");
	
func _replayturnslider_value_changed(value: int) -> void:
	if !doing_replay:
		return;
	if (replayturnsliderset):
		return;
	var differential = value - replay_turn;
	if (differential != 0):
		replay_advance_turn(differential);
	
var replayturnslider_in_drag : bool = false;
func _replayturnslider_drag_started() -> void:
	replayturnslider_in_drag = true;
	
func _replayturnslider_drag_ended(_value_changed: bool) -> void:
	replayturnslider_in_drag = false;
	
func _replayspeedslider_value_changed(value: int) -> void:
	if !doing_replay:
		return;
	if (replayspeedsliderset):
		return;
	var old_replay_interval = replay_interval;
	replay_interval = (100-value) * 0.01;
	adjust_next_replay_time(old_replay_interval);
	update_info_labels();

func react_to_save_file_update() -> void:
	#save_file["gain_insight"] = false;
	#save_file["authors_replay"] = false;
	
	level_number = save_file["level_number"];
	if (save_file.has("puzzle_checkerboard") and save_file["puzzle_checkerboard"] == true):
		checkerboard.visible = true;
	else:
		checkerboard.visible = false;
	call_deferred("setup_resolution");
	setup_volume();
	setup_animation_speed();
	setup_virtual_buttons();
	deserialize_bindings();
	setup_deadzone();
	refresh_puzzles_completed();
	
var actions = ["ui_accept", "ui_cancel", "escape", "ui_left", "ui_right", "ui_up", "ui_down",
"character_undo", "meta_undo", "meta_redo", "character_unwin", "restart",
"mute",
"toggle_replay", "start_replay", "start_saved_replay",
"speedup_replay", "slowdown_replay", "replay_pause", "replay_back1", "replay_fwd1"];
	
func setup_deadzone() -> void:
	if (!save_file.has("deadzone")):
		save_file["deadzone"] = InputMap.action_get_deadzone("ui_up");
	else:
		InputMap.action_set_deadzone("ui_up", save_file["deadzone"]);
		InputMap.action_set_deadzone("ui_down", save_file["deadzone"]);
		InputMap.action_set_deadzone("ui_left", save_file["deadzone"]);
		InputMap.action_set_deadzone("ui_right", save_file["deadzone"]);
	
func deserialize_bindings() -> void:
	if save_file.has("keyboard_bindings"):
		for action in actions:
			if (save_file["keyboard_bindings"].has(action)):
				var events = InputMap.get_action_list(action);
				for event in events:
					if (event is InputEventKey):
						InputMap.action_erase_event(action, event);
				for new_event_str in save_file["keyboard_bindings"][action]:
					var parts = new_event_str.split(",");
					var new_event = InputEventKey.new();
					new_event.scancode = int(parts[0]);
					new_event.physical_scancode = int(parts[1]);
					InputMap.action_add_event(action, new_event);
	if save_file.has("controller_bindings"):
		for action in actions:
			if (save_file["controller_bindings"].has(action)):
				var events = InputMap.get_action_list(action);
				for event in events:
					if (event is InputEventJoypadButton):
						InputMap.action_erase_event(action, event);
				for new_event_int in save_file["controller_bindings"][action]:
					var new_event = InputEventJoypadButton.new();
					new_event.button_index = new_event_int;
					InputMap.action_add_event(action, new_event);
					
	setup_udlr();

func serialize_bindings() -> void:
	if !save_file.has("keyboard_bindings"):
		save_file["keyboard_bindings"] = {};
	else:
		save_file["keyboard_bindings"].clear();
	if !save_file.has("controller_bindings"):
		save_file["controller_bindings"] = {};
	else:
		save_file["controller_bindings"].clear();
	
	for action in actions:
		if (action.find("nonaxis") >= 0):
			pass
		var events = InputMap.get_action_list(action);
		save_file["keyboard_bindings"][action] = [];
		save_file["controller_bindings"][action] = [];
		for event in events:
			if (event is InputEventKey):
				save_file["keyboard_bindings"][action].append(str(event.scancode) + "," +str(event.physical_scancode));
			elif (event is InputEventJoypadButton):
				save_file["controller_bindings"][action].append(event.button_index);
				
	setup_udlr();
	
func setup_udlr() -> void:
	if !save_file.has("keyboard_bindings") or  !save_file.has("controller_bindings"):
		serialize_bindings();
	
	var a = ["ui_left", "ui_right", "ui_up", "ui_down"];
	var b = ["nonaxis_left", "nonaxis_right", "nonaxis_up", "nonaxis_down"];
	for i in range(4):
		var ia = a[i];
		var ib = b[i];
		var events = InputMap.get_action_list(ib);
		for event in events:
			InputMap.action_erase_event(ib, event);
		for new_event_str in save_file["keyboard_bindings"][ia]:
			var parts = new_event_str.split(",");
			var new_event = InputEventKey.new();
			new_event.scancode = int(parts[0]);
			new_event.physical_scancode = int(parts[1]);
			InputMap.action_add_event(ib, new_event);
		for new_event_int in save_file["controller_bindings"][ia]:
			var new_event = InputEventJoypadButton.new();
			new_event.button_index = new_event_int;
			InputMap.action_add_event(ib, new_event);
	
func setup_virtual_buttons() -> void:
	var value = 1;
	if (save_file.has("virtual_buttons")):
		value = int(save_file["virtual_buttons"]);
	if (value > 0):
		for folder in virtualbuttons.get_children():
			for button in folder.get_children():
				button.disabled = false;
		virtualbuttons.visible = true;
		match value:
			1:
				virtualbuttons.get_node("Verbs").position = Vector2(0, 0);
				virtualbuttons.get_node("Dirs").position = Vector2(0, 0);
				replaybuttons.get_node("ReplayTurn").position = Vector2(0, 0);
				replaybuttons.get_node("ReplaySpeed").position = Vector2(0, 0);
			2:
				virtualbuttons.get_node("Verbs").position = Vector2(0, 0);
				virtualbuttons.get_node("Dirs").position = Vector2(-108, 0);
				replaybuttons.get_node("ReplayTurn").position = Vector2(0, 0);
				replaybuttons.get_node("ReplaySpeed").position = Vector2(138, 0);
			3:
				virtualbuttons.get_node("Verbs").position = Vector2(128, 0);
				virtualbuttons.get_node("Dirs").position = Vector2(0, 0);
				replaybuttons.get_node("ReplayTurn").position = Vector2(-128, 0);
				replaybuttons.get_node("ReplaySpeed").position = Vector2(0, 0);
			4:
				virtualbuttons.get_node("Verbs").position = Vector2(128, 0);
				virtualbuttons.get_node("Dirs").position = Vector2(-108, 0);
				replaybuttons.get_node("ReplayTurn").position = Vector2(-128, 0);
				replaybuttons.get_node("ReplaySpeed").position = Vector2(138, 0);
			5:
				virtualbuttons.get_node("Verbs").position = Vector2(0, 0);
				virtualbuttons.get_node("Dirs").position = Vector2(-300, 0);
				replaybuttons.get_node("ReplayTurn").position = Vector2(160, 0);
				replaybuttons.get_node("ReplaySpeed").position = Vector2(138, 0);
			6:
				virtualbuttons.get_node("Verbs").position = Vector2(300, 0);
				virtualbuttons.get_node("Dirs").position = Vector2(0, 0);
				replaybuttons.get_node("ReplayTurn").position = Vector2(-128, 0);
				replaybuttons.get_node("ReplaySpeed").position = Vector2(-150, 0);
	else:
		replaybuttons.get_node("ReplayTurn").position = Vector2(0, 0);
		replaybuttons.get_node("ReplaySpeed").position = Vector2(0, 0);
		for folder in virtualbuttons.get_children():
			for button in folder.get_children():
				button.disabled = true;
		virtualbuttons.visible = false;
	if (player != null):
		update_info_labels();

var is_steam_deck: bool = false;
func steam_deck_check() -> bool:
	if is_steam_deck:
		return true;
	if OS.get_name() == "X11":
		if get_largest_monitor().x == 1280:
			is_steam_deck = true;
			save_file["resolution"] = "1280x800";
			save_file["fullscreen"] = true;
			#setup_resolution(); #will be called by startup
			controller_hrns[0] = "A";
			controller_hrns[1] = "B";
			controller_hrns[2] = "X";
			controller_hrns[3] = "Y";
			return true;
	return false;

func get_largest_monitor() -> Vector2:
	var result = Vector2(-1, -1);
	var monitors = OS.get_screen_count();
	for i in range(monitors):
		var monitor = OS.get_screen_size(i);
		if (result.x < monitor.x):
			result.x = monitor.x;
		if (result.y < monitor.y):
			result.y = monitor.y;
	return result;

#https://gist.github.com/hiulit/772b8784436898fd7f942750ad99e33e
func get_all_files(path: String, file_ext := "", files := []):
	var dir = Directory.new()

	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)

		var file_name = dir.get_next()

		while file_name != "":
			if dir.current_is_dir():
				files = get_all_files(dir.get_current_dir().plus_file(file_name), file_ext, files)
			else:
				if file_ext and file_name.get_extension() != file_ext:
					file_name = dir.get_next()
					continue

				files.append(dir.get_current_dir().plus_file(file_name))

			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access %s." % path)

	return files

var SuperScaling = null;

func move_viewport() -> void:
	var viewport = get_parent().get_parent();
	var root = get_tree().get_root();
	root.move_child(viewport, 0);

func filter_all_sprites(yes: bool) -> void:	
	if (SuperScaling != null):
		var viewport = get_parent().get_parent();
		var root = get_tree().get_root();
		for node in viewport.get_children():
			viewport.remove_child(node);
			root.add_child(node);
		SuperScaling.get_parent().remove_child(SuperScaling);
		SuperScaling.queue_free();
		viewport.queue_free();
		SuperScaling = null;
	
	if (yes and SuperScaling == null):
		SuperScaling = load("res://SuperScaling/SuperScaling.tscn").instance();
		SuperScaling.enable_on_play = true;
		SuperScaling.ui_nodes = [get_parent().get_path_to(GuiHolder)] #path must be ../GuiHolder
		SuperScaling.usage = 1; #2D
		SuperScaling.shadow_atlas = 1;
		SuperScaling.scale_factor = 2.0;
		SuperScaling.smoothness = 0.25;
		self.get_parent().get_parent().add_child(SuperScaling);
		call_deferred("move_viewport");
	else:
		pass
	load("res://standardfont.tres").use_filter = yes; #still need to filter this or it looks gross lol
	
func setup_resolution() -> void:
	steam_deck_check();
	
	Engine.target_fps = int(save_file["fps"]);
	if (is_web):
		return;
	if (save_file.has("fullscreen")):
		OS.window_fullscreen = save_file["fullscreen"];
	if (save_file.has("resolution")):
		var value = save_file["resolution"];
		value = value.split("x");
		var size = Vector2(int(value[0]), int(value[1]));
		var monitor = get_largest_monitor();
		if (monitor.x > 0 and size.x > monitor.x):
			size.x = monitor.x;
		if (monitor.y > 0 and size.y > monitor.y):
			size.y = monitor.y;
		if (OS.get_window_size() != size):
			OS.set_window_size(size);
			OS.center_window();
	var size = OS.get_window_size();
	if (float(size.x) / float(pixel_width) != round(float(size.x) / float(pixel_width))):
		call_deferred("filter_all_sprites", true);
	else:
		call_deferred("filter_all_sprites", false);

	if (save_file.has("vsync_enabled")):
		OS.vsync_enabled = save_file["vsync_enabled"];
		
func setup_volume() -> void:
	var master_volume = save_file["master_volume"];
	if (save_file.has("sfx_volume")):
		var value = save_file["sfx_volume"];
		for speaker in speakers:
			speaker.volume_db = value + master_volume;
	if (save_file.has("music_volume")):
		var value = save_file["music_volume"];
		music_speaker.volume_db = value + master_volume;
		music_speaker.volume_db = music_speaker.volume_db + music_discount;
	if (save_file.has("fanfare_volume")):
		var value = save_file["fanfare_volume"];
		won_speaker.volume_db = value + master_volume;
	
func setup_animation_speed() -> void:
	if (save_file.has("animation_speed")):
		var value = save_file["animation_speed"];
		Engine.time_scale = value;

func initialize_shaders() -> void:
	#each thing that uses a shader has to compile the first time it's used, so... use it now!
	var afterimage = preload("Afterimage.tscn").instance();
	afterimage.initialize(levelstar, blue_color);
	levelscene.call_deferred("add_child", afterimage);
	afterimage.position = Vector2(-99, -99);
	
func tile_changes(level_editor: bool = false) -> void:
	pass
	
func assert_tile_enum() -> void:
	for i in range (Tiles.size()):
		var expected_tile_name = Tiles.keys()[i];
		if (expected_tile_name == "Lock"):
			continue
		var expected_tile_id = Tiles.values()[i];
		var actual_tile_id = terrainmap.tile_set.find_tile_by_name(expected_tile_name);
		var actual_tile_name = terrainmap.tile_set.tile_get_name(expected_tile_id);
		if (actual_tile_name != expected_tile_name):
			print(expected_tile_name, ", ", expected_tile_id, ", ", actual_tile_name, ", ", actual_tile_id);
		elif (actual_tile_id != expected_tile_id):
			print(expected_tile_name, ", ", expected_tile_id, ", ", actual_tile_name, ", ", actual_tile_id);

func initialize_level_list() -> void:
	
	chapter_names.push_back("Unwin");
	chapter_standard_starting_levels.push_back(level_filenames.size());
	chapter_standard_unlock_requirements.push_back(0);
	chapter_skies.push_back(Color("25272A"));
	chapter_tracks.push_back(0);
	level_filenames.push_back("Unwin")
	chapter_advanced_starting_levels.push_back(level_filenames.size());
	chapter_advanced_unlock_requirements.push_back(8);
	
	# sentinel to make overflow checks easy
	chapter_standard_starting_levels.push_back(level_filenames.size());
	chapter_advanced_starting_levels.push_back(level_filenames.size());

#	if (OS.is_debug_build()):
#		OS.set_clipboard(str(level_filenames));

	var current_standard_index = 0;
	var current_advanced_index = 0;
	var currently_extra = false;
	var next_flip = chapter_advanced_starting_levels[current_advanced_index];
	for i in range(level_filenames.size()):
		if (i >= next_flip):
			if currently_extra:
				currently_extra = false;
				current_advanced_index += 1;
				next_flip = chapter_advanced_starting_levels[current_advanced_index];
			else:
				currently_extra = true;
				current_standard_index += 1;
				next_flip = chapter_standard_starting_levels[current_standard_index];
		level_extraness.push_back(currently_extra);
	
	for level_filename in level_filenames:
		level_list.push_back(load("res://levels/" + level_filename + ".tscn"));
	
	for level_prototype in level_list:
		var level = level_prototype.instance();
		var level_name = level.get_node("LevelInfo").level_name;
		level_names.push_back(level_name);
		level.queue_free();
		
	for i in range(level_list.size()):
		var level_name = level_names[i];
		var level_filename = level_filenames[i];
		
		# also learn which puzzles are remixes
		var insight_path = "res://levels/insight/" + level_filename + "Insight.tscn";
		if (ResourceLoader.exists(insight_path)):
			var insight_level = load(insight_path).instance();
			var insight_level_name = insight_level.get_node("LevelInfo").level_name;
			if (insight_level_name.find("(Insight)")) >= 0:
				pass
			elif insight_level_name.find("(Remix)") >= 0 or insight_level_name.find("World's Smallest Puzzle") >= 0 or insight_level_name.find("Theory of Everything") >= 0 or insight_level_name.find("Board Ring B") >= 0:
				has_remix[level_name] = true;
				has_remix[insight_level_name] = true;
			insight_level_names[level_name] = insight_level_name;
			insight_level.queue_free();
		
	refresh_puzzles_completed();
		
func refresh_puzzles_completed() -> void:
	puzzles_completed = 0;
	advanced_puzzles_completed = 0;
	specific_puzzles_completed = [];
	for i in range(level_list.size()):
		var level_name = level_names[i];
		if save_file["levels"].has(level_name) and save_file["levels"][level_name].has("won") and save_file["levels"][level_name]["won"]:
			specific_puzzles_completed.push_back(true);
			puzzles_completed += 1;
			if (level_extraness[i]):
				advanced_puzzles_completed += 1;
		else:
			specific_puzzles_completed.push_back(false);

func ready_map() -> void:
	won = false;
	end_lose();
	lost_speaker.stop();
	for actor in actors:
		actor.queue_free();
	actors.clear();
	for goal in goals:
		goal.queue_free();
	goals.clear();
	for hole_sprite in hole_sprites.values():
		hole_sprite.queue_free();
	hole_sprites.clear();
	for whatever in underterrainfolder.get_children():
		whatever.queue_free();
	for whatever in actorsfolder.get_children():
		whatever.queue_free();
	for whatever in underactorsparticles.get_children():
		whatever.queue_free();
	for whatever in overactorsparticles.get_children():
		whatever.queue_free();
	red_turn = 0;
	red_undo_buffer.clear();
	blue_turn = 0;
	blue_undo_buffer.clear();
	meta_turn = 0;
	meta_undo_buffer.clear();
	user_replay = "";
	meta_redo_inputs = "";
	preserving_meta_redo_inputs = false;
	
	var level_info = terrainmap.get_node_or_null("LevelInfo");
	if (level_info != null): # might be a custom puzzle
		level_name = level_info.level_name;
		level_author = level_info.level_author;
		annotated_authors_replay = level_info.level_replay;
		if ("$" in annotated_authors_replay):
			var authors_replay_parts = annotated_authors_replay.split("$");
			authors_replay = authors_replay_parts[authors_replay_parts.size()-1];
		else:
			authors_replay = annotated_authors_replay;
			
	has_insight_level = false;
	insight_level_scene = null;
	if (!is_custom):
		var insight_path = "res://levels/insight/" + level_filenames[level_number] + "Insight.tscn";
		if (ResourceLoader.exists(insight_path)):
			has_insight_level = true;
			insight_level_scene = load(insight_path);

	calculate_map_size();
	make_shadows();
	make_actors();
	
	initialize_starbar();
	
	finish_animations(Chrono.TIMELESS);
	update_info_labels();
	check_won(Chrono.TIMELESS);
	
	ready_tutorial();
	update_level_label();
	intro_hop();

func initialize_starbar() -> void:
	if (ready_done):
		var num_stars = 0;
		for actor in actors:
			if actor.is_star:
				num_stars += 1;
		starbar.initialize(num_stars);
	else:
		call_deferred("initialize_starbar");

var first_intro = false;

func intro_hop() -> void:
	if (!ready_done):
		player.texture = null;
		return;
	if (!first_intro):
		first_intro = true;
		player.texture = null;
		add_to_animation_server(player, [Anim.stall, 0.7]);
		add_to_animation_server(player, [Anim.intro, 2.8]);
		add_to_animation_server(player, [Anim.sing]);
		add_to_animation_server(player, [Anim.sing]);
	else:
		add_to_animation_server(player, [Anim.intro, 0.5]);

func tutorial_complete() -> void:
	show_button(virtualbuttons.get_node("Verbs/UndoButton"))
	show_button(virtualbuttons.get_node("Verbs/UnwinButton"))
	show_button(virtualbuttons.get_node("Verbs/MetaUndoButton"))
	z_shown = true;
	x_shown = true;
	c_shown = true;
	z_used = true;
	x_used = true;
	c_used = true;
	tutoriallabel.visible = false;
	metainfolabel.visible = true;

func show_button(button: Button) -> void:
	if (!button.visible):
		button.visible = true;
		var sparklespawner = Node2D.new();
		sparklespawner.script = preload("res://SparkleSpawner.gd");
		button.add_child(sparklespawner);
		sparklespawner.color = button.get_child(0).get_color("font_color");

func ready_tutorial() -> void:
	if (tutoriallabel.visible):
		tutoriallabel.bbcode_text = "";
		if z_shown and !z_used:
			tutoriallabel.bbcode_text += human_readable_input("character_undo") + ": [color=#CF6A4F]Undo[/color]\n"
		if x_shown and !x_used:
			tutoriallabel.bbcode_text += human_readable_input("character_unwin") + ": [color=#E0B94A]Unwin[/color]\n"
		if c_shown and !c_used:
			tutoriallabel.bbcode_text += "\n" + human_readable_input("meta_undo") + ": [color=#B2AF5C]Really Undo[/color]"
		
func translate_tutorial_inputs() -> void:
	if tutoriallabel.visible:
		pass
#		if (meta_redo_inputs != "" and (level_number == 6 or level_number == 7)):
#			tutoriallabel.bbcode_text = "$META-UNDO: [color=#A9F05F]Undo[/color]\n$RESTART: Restart\n$META-REDO: [color=#A9F05F]Redo[/color]";
#			tutoriallabel.bbcode_text = "[center]" + tutoriallabel.bbcode_text + "[/center]";
#
#		if using_controller:
#			tutoriallabel.bbcode_text = tutoriallabel.bbcode_text.replace("$MOVE", "D-Pad/Either Stick");
#		else:
#			tutoriallabel.bbcode_text = tutoriallabel.bbcode_text.replace("$MOVE", "Arrows");
#		tutoriallabel.bbcode_text = tutoriallabel.bbcode_text.replace("$SWAP", human_readable_input("character_switch"));
#		tutoriallabel.bbcode_text = tutoriallabel.bbcode_text.replace("$UNDO", human_readable_input("character_undo"));
#		tutoriallabel.bbcode_text = tutoriallabel.bbcode_text.replace("$META-UNDO", human_readable_input("meta_undo"));
#		tutoriallabel.bbcode_text = tutoriallabel.bbcode_text.replace("$META-REDO", human_readable_input("meta_redo"));
#		tutoriallabel.bbcode_text = tutoriallabel.bbcode_text.replace("$RESTART", human_readable_input("restart"));
#		tutoriallabel.bbcode_text = tutoriallabel.bbcode_text.replace("$TOGGLE-REPLAY", human_readable_input("toggle_replay"));
	
var controller_hrns = [
	"Bottom Face Button",
	"Right Face Button",
	"Left Face Button",
	"Top Face Button",
	"LB",
	"RB",
	"LT",
	"RT",
	"L3",
	"R3",
	"Select",
	"Start",
	"Up",
	"Down",
	"Left",
	"Right",
	"Home",
	"Share",
	"Paddle 1",
	"Paddle 2",
	"Paddle 3",
	"Paddle 4",
	"Touchpad",
];
	
func human_readable_input(action: String, entries: int = 3) -> String:
	var result = "";
	var events = InputMap.get_action_list(action);
	var entry = 0;
	for event in events:
		if ((!using_controller and event is InputEventKey) or (using_controller and event is InputEventJoypadButton)):
			entry += 1;
			if (result != ""):
				result += " or ";
			if (event is InputEventKey):
				result += event.as_text();
			else:
				if (event.button_index < controller_hrns.size()):
					result += controller_hrns[event.button_index];
				else:
					result += event.as_text();
		if (entry >= entries):
			return result;
	if (result == ""):
		result = "[UNBOUND]";
	return result;

func get_used_cells_by_id_all_layers(id: int) -> Array:
	var results = []
	for layer in terrain_layers:
		results.append(layer.get_used_cells_by_id(id));
	return results;
	
func get_used_cells_by_id_one_array(id: int) -> Array:
	var results = []
	for layer in terrain_layers:
		results.append_array(layer.get_used_cells_by_id(id));
	return results;

func any_layer_has_this_tile(id: int) -> bool:
	for layer in terrain_layers:
		if (layer.get_used_cells_by_id(id).size() > 0):
			return true;
	return false;

func make_shadows() -> void:
	# it'd probably be smarter to come up with some sort of like, tilemap, but sprites to be quick-and-dirty
	# and if it's a problem I'll fix it later
	var floor_layers = get_used_cells_by_id_all_layers(Tiles.Floor);
	for i in range(floor_layers.size()):
		var layer = floor_layers[i];
		for tile in layer:
			var wall_to_left = terrain_in_tile(tile + Vector2.LEFT).has(Tiles.Wall);
			var wall_to_north = terrain_in_tile(tile + Vector2.UP).has(Tiles.Wall);
			var wall_to_nw = terrain_in_tile(tile + Vector2.UP + Vector2.LEFT).has(Tiles.Wall);
			var bitfield = 0;
			if (wall_to_left):
				bitfield += 1;
			if (wall_to_north):
				bitfield += 2;
			if (wall_to_nw):
				bitfield += 4;
			var frame = 0;
			match bitfield:
				0:
					frame = -1;
				1:
					frame = 6;
				2:
					frame = 7;
				3:
					frame = 2;
				4:
					frame = 4;
				5:
					frame = 3;
				6:
					frame = 1;
				7:
					frame = 0;
			if (frame >= 0):
				var sprite = Sprite.new();
				terrain_layers[i].add_child(sprite);
				sprite.texture = preload("res://assets/wall_shadow.png");
				sprite.centered = false;
				sprite.hframes = 3;
				sprite.vframes = 3;
				sprite.frame = frame;
				sprite.position = tile * cell_size;
				if (i == terrain_layers.size() - 1):
					terrain_layers[i].move_child(sprite, terrain_layers[i-1].get_index());

func make_actors() -> void:
	voidlike_puzzle = false;
	
	# find goals and goal-ify them
	find_goals();
	
	var where_are_actors = {};
	
	#stars first, so they draw behind the player on the same layer
	extract_actors(Tiles.Star, Actor.Name.Star, Heaviness.CRYSTAL, Strength.HEAVY, true);
	extract_actors(Tiles.DarkStar, Actor.Name.DarkStar, Heaviness.CRYSTAL, Strength.HEAVY, true);
	extract_actors(Tiles.CrackedStar, Actor.Name.CrackedStar, Heaviness.CRYSTAL, Strength.HEAVY, true);
	
	# find the player
	player = null;
	var layers_tiles = get_used_cells_by_id_all_layers(Tiles.Player);
	var found_one = false;
	var count = 0;
	for i in range(layers_tiles.size()):
		var tiles = layers_tiles[i];
		if (tiles.size() > 0):
			found_one = true;
	if !found_one:
		layers_tiles = [[Vector2(0, 0)]];
	for i in range(layers_tiles.size()):
		var tiles = layers_tiles[i];
		for player_tile in tiles:
			terrain_layers[i].set_cellv(player_tile, -1);
			var old_player_actor = player;
			player = make_actor(Actor.Name.Player, Vector2(-99, -99), true, i);
			where_are_actors[player] = player_tile;
			player.heaviness = Heaviness.IRON;
			player.strength = Strength.LIGHT;
			player.update_graphics();
			count += 1;
	
	# HACK: move actors to where they are, so now that is_main_character and so on is determined,
	# they correctly ding/don't ding different kinds of goals
	for actor in where_are_actors.keys():
		move_actor_to(actor, where_are_actors[actor], Chrono.TIMELESS, false, false);
	
	# crates
	extract_actors(Tiles.DirtBlock, Actor.Name.DirtBlock, Heaviness.IRON, Strength.WOODEN, false);
	extract_actors(Tiles.IceBlock, Actor.Name.IceBlock, Heaviness.IRON, Strength.WOODEN, false);
	
	find_colours();
	
func find_goals() -> void:
	var layers = get_used_cells_by_id_all_layers(Tiles.Win);
	for i in range(layers.size()):
		var goal_tiles = layers[i];
		for tile in goal_tiles:
			var goal = Goal.new();
			goal.gamelogic = self;
			goal.actorname = Actor.Name.Goal;
			goal.texture = preload("res://assets/win.png");
			goal.centered = true;
			goal.pos = tile;
			goal.position = terrainmap.map_to_world(goal.pos) + Vector2(cell_size/2, cell_size/2);
			goal.starbar = starbar;
			goals.append(goal);
			add_actor_or_goal_at_appropriate_layer(goal, i);
			goal.update_graphics();
	
func add_actor_or_goal_at_appropriate_layer(thing: Node2D, i: int) -> void:
	terrain_layers[i].add_child(thing);
	if (i == terrain_layers.size() - 1):
		terrain_layers[i].move_child(thing, terrain_layers[i-1].get_index());

func add_actor_or_goal_at_appropriate_layer_at_back(thing: Node2D, i: int) -> void:
	terrain_layers[i].add_child(thing);
	terrain_layers[i].move_child(thing, 0);

func extract_actors(id: int, actorname: int, heaviness: int, strength: int, is_star: bool) -> void:
	var layers_tiles = get_used_cells_by_id_all_layers(id);
	var count = 0;
	for i in range(layers_tiles.size()):
		var tiles = layers_tiles[i];
		for tile in tiles:
			terrain_layers[i].set_cellv(tile, -1);
			var actor = make_actor(actorname, tile, false, i);
			actor.heaviness = heaviness;
			actor.strength = strength;
			actor.is_star = is_star;
			actor.is_character = false;
			actor.update_graphics();

func find_colours() -> void:
	var layers_tiles = get_used_cells_by_id_all_layers(Tiles.GreenAura);
	for i in range(layers_tiles.size()):
		var tiles = layers_tiles[i];
		for tile in tiles:
			var found = false;
			# get first actor with the same pos and native colour and change their time_colour
			for actor in actors:
				if actor.pos == tile and !actor.is_green:
					actor.is_green = true;
					actor.update_time_bubble();
					terrain_layers[i].set_cellv(tile, -1);
					break;

func calculate_map_size() -> void:
	map_x_max = 0;
	map_y_max = 0;
	for layer in terrain_layers:
		var tiles = layer.get_used_cells();
		for tile in tiles:
			if tile.x > map_x_max:
				map_x_max = tile.x;
			if tile.y > map_y_max:
				map_y_max = tile.y;
	if ((map_x_max) < map_x_max_max/2 and (map_y_max) < map_y_max_max/2):
		terrainmap.scale = Vector2(2.0, 2.0);
	elif (map_x_max > map_x_max_max or map_y_max > map_y_max_max+2):
		terrainmap.scale = Vector2(0.5, 0.5);
	else:
		terrainmap.scale = Vector2(1.0, 1.0);
	underterrainfolder.scale = terrainmap.scale;
	actorsfolder.scale = terrainmap.scale;
	underactorsparticles.scale = terrainmap.scale;
	overactorsparticles.scale = terrainmap.scale;
	checkerboard.rect_scale = terrainmap.scale;
	if (terrainmap.scale == Vector2(2.0, 2.0)):
		terrainmap.position.x = (map_x_max_max-map_x_max*2)*(cell_size/2)-8;
		terrainmap.position.y = (map_y_max_max-map_y_max*2)*(cell_size/2)+12;
	elif (terrainmap.scale == Vector2(0.5, 0.5)):
		terrainmap.position.x = (map_x_max_max-map_x_max*0.5)*(cell_size/2)-8;
		terrainmap.position.y = (map_y_max_max-map_y_max*0.5)*(cell_size/2)+12;
	else:
		terrainmap.position.x = (map_x_max_max-map_x_max)*(cell_size/2)-8;
		terrainmap.position.y = (map_y_max_max-map_y_max)*(cell_size/2)+12;
	underterrainfolder.position = terrainmap.position;
	actorsfolder.position = terrainmap.position;
	underactorsparticles.position = terrainmap.position;
	overactorsparticles.position = terrainmap.position;
	checkerboard.rect_position = terrainmap.position;
	checkerboard.rect_size = cell_size*Vector2(map_x_max+1, map_y_max+1);
	# hack for World's Smallest Puzzle!
	if (map_y_max == 0):
		checkerboard.rect_position.y -= cell_size;
		
func update_targeter() -> void:
	pass
		
func prepare_audio() -> void:
	# TODO: I could automate this if I can iterate the folder
	# TODO: replace this with an enum and assert on startup like tiles
	
	#new SFX
	sounds["crashland"] = preload("res://sfx/crashland.ogg");
	sounds["goalclosing"] = preload("res://sfx/goalclosing.ogg");
	sounds["goalopening"] = preload("res://sfx/goalopening.ogg");
	sounds["melt"] = preload("res://sfx/melt.ogg");
	sounds["outro"] = preload("res://sfx/outro.ogg");
	sounds["plummet"] = preload("res://sfx/plummet.ogg");
	sounds["slide"] = preload("res://sfx/slide.ogg");
	sounds["starget"] = preload("res://sfx/starget.ogg");
	sounds["unmelt"] = preload("res://sfx/unmelt.ogg");
	sounds["unwin"] = preload("res://sfx/unwin.ogg");	
	
	#old SFX still in use (afaik
	sounds["involuntarybumpother"] = preload("res://sfx/involuntarybumpother.ogg");
	sounds["bump"] = preload("res://sfx/bump.ogg");
	sounds["usegreenality"] = preload("res://sfx/usegreenality.ogg");
	sounds["intro"] = preload("res://sfx/intro.ogg");
	sounds["unpush"] = preload("res://sfx/unpush.ogg");
	sounds["push"] = preload("res://sfx/push.ogg");
	sounds["unfall"] = preload("res://sfx/unfall.ogg");
	sounds["undostrong"] = preload("res://sfx/undostrong.ogg");
	sounds["metaredo"] = preload("res://sfx/metaredo.ogg");
	sounds["metarestart"] = preload("res://sfx/metarestart.ogg");
	sounds["metaundo"] = preload("res://sfx/metaundo.ogg");
	sounds["restart"] = preload("res://sfx/restart.ogg");
	sounds["heavystep"] = preload("res://sfx/heavystep.ogg");
	sounds["voidundo"] = preload("res://sfx/voidundo.ogg");
	sounds["switch"] = preload("res://sfx/switch.ogg");

	music_tracks.append(preload("res://music/Mind Palace.ogg"));
	music_info.append("Patashu - Mind Palace");
	music_db.append(0.0);
	
	for i in range (8):
		var speaker = AudioStreamPlayer.new();
		self.add_child(speaker);
		speakers.append(speaker);
	lost_speaker = AudioStreamPlayer.new();
	#lost_speaker.stream = sounds["lose"];
	lost_speaker_volume_tween = Tween.new();
	self.add_child(lost_speaker_volume_tween);
	self.add_child(lost_speaker);
	won_speaker = AudioStreamPlayer.new();
	self.add_child(won_speaker);
	music_speaker = AudioStreamPlayer.new();
	self.add_child(music_speaker);

func fade_in_lost():
	if (Shade.on):
		return;
	winlabel.visible = true;
	call_deferred("adjust_winlabel");
	Shade.on = true;
	
	if muted or (doing_replay and meta_undo_a_restart_mode):
		return;
	var db = save_file["fanfare_volume"];
	var master_volume = save_file["master_volume"];
	if (db <= -30 or master_volume <= -30):
		return;
	db += master_volume;
	lost_speaker.volume_db = -40 + db;
	lost_speaker_volume_tween.interpolate_property(lost_speaker, "volume_db", -40 + db, -10 + db, 3.00, 1, Tween.EASE_IN, 0)
	lost_speaker_volume_tween.start();
	lost_speaker.play();

func cut_sound() -> void:
	if (doing_replay and meta_undo_a_restart_mode):
		return;
	for speaker in speakers:
		speaker.stop();
	lost_speaker.stop();
	won_speaker.stop();

func play_sound(sound: String) -> void:
	if muted or (doing_replay and meta_undo_a_restart_mode):
		return;
	if (sounds_played_this_frame.has(sound)):
		return;
	if (save_file["sfx_volume"] <= -30 or save_file["master_volume"] <= -30):
		return;
	for speaker in speakers:
		if !speaker.playing:
			speaker.stream = sounds[sound];
			sounds_played_this_frame[sound] = true;
			speaker.play();
			return;

func play_won(sound: String) -> void:
	if muted or (doing_replay and meta_undo_a_restart_mode):
		return;
	if (sounds_played_this_frame.has(sound)):
		return;
	var speaker = won_speaker;
	if save_file["fanfare_volume"] <= -30 or save_file["master_volume"] <= -30:
		return;
	if speaker.playing:
		speaker.stop();
	speaker.stream = sounds[sound];
	sounds_played_this_frame[sound] = true;
	speaker.play();
	return;

func toggle_mute() -> void:
	if (!muted):
		floating_text("M: Muted");
	else:
		floating_text("M: Unmuted");
	muted = !muted;
	music_speaker.stream_paused = muted;
	cut_sound();

func make_actor(actorname: int, pos: Vector2, is_character: bool, i: int, chrono: int = Chrono.TIMELESS) -> Actor:
	var actor = Actor.new();
	actors.append(actor);
	actor.actorname = actorname;
	actor.is_character = is_character;
	actor.gamelogic = self;
	actor.offset = Vector2(cell_size/2, cell_size/2);
	add_actor_or_goal_at_appropriate_layer(actor, i);
	move_actor_to(actor, pos, chrono, false, false);
	if (chrono < Chrono.META_UNDO):
		print("TODO")
	return actor;

var wants_to_move_again: Dictionary = {};

func move_actor_initiate(actor: Actor, dir: Vector2, chrono: int, hypothetical: bool,
is_retro: bool = false, pushers_list: Array = [],  was_push = false,
is_move: bool = false, can_push: bool = true) -> int:
	var result = move_actor_to(actor, actor.pos + dir, chrono, hypothetical, is_retro,
	pushers_list, was_push, is_move, can_push);
	
	# Ice blocks that successfully non-retro non-hypothetical move slide.
	while (wants_to_move_again.size() > 0):
		animation_substep(chrono);
		var temp = wants_to_move_again.duplicate();
		wants_to_move_again.clear();
		for w in temp:
			# slide and unslide sfx - it's conveniently its own reverse
			add_to_animation_server(w, [Anim.sfx, "slide"]);
			add_undo_event([Undo.sfx, w, "slide"], chrono);
			var r = move_actor_relative(w, temp[w], chrono, hypothetical, false, pushers_list);
			
	return result;

func move_actor_relative(actor: Actor, dir: Vector2, chrono: int, hypothetical: bool,
is_retro: bool = false, pushers_list: Array = [],  was_push = false,
is_move: bool = false, can_push: bool = true) -> int:
	var result = move_actor_to(actor, actor.pos + dir, chrono, hypothetical, is_retro,
	pushers_list, was_push, is_move, can_push);
	
	# Ice blocks that successfully non-retro non-hypothetical move slide (when move_actor_initiate next ticks).
	if (!is_retro and !hypothetical and result == Success.Yes and actor.actorname == Actor.Name.IceBlock):
		var terrain = terrain_in_tile(actor.pos, actor, chrono);
		if terrain.has(Tiles.Floor) and !terrain.has(Tiles.Hole) and !terrain.has(Tiles.BottomlessPit):
			wants_to_move_again[actor] = dir;
	return result;

func move_actor_to(actor: Actor, pos: Vector2, chrono: int, hypothetical: bool,
is_retro: bool = false, pushers_list: Array = [], was_push: bool = false,
is_move: bool = false, can_push: bool = true) -> int:
	var dir = pos - actor.pos;
	var old_pos = actor.pos;
	
	var success = Success.No;

	success = try_enter(actor, dir, chrono, can_push, hypothetical, was_push, is_retro, pushers_list);
	
	if (success == Success.Yes and !hypothetical):
		
		if (!is_retro):
			was_push = pushers_list.size() > 0;
		actor.pos = pos;
		
		# do facing change now before move happens
		if (is_move and actor.is_character):
			set_actor_var(actor, "facing_dir", dir, Chrono.MOVE);
		
		add_undo_event([Undo.move, actor, dir, was_push],
		chrono_for_maybe_green_actor(actor, chrono));
		
		# green aura
		
		if (!actor.is_green and chrono < Chrono.META_UNDO):
			var terrain = terrain_in_tile(actor.pos);
			for i in range(terrain.size()):
				var tile = terrain[i];
				if (tile == Tiles.GreenAura):
					actor.is_green = true;
					add_undo_event([Undo.time_bubble, actor],
						chrono_for_maybe_green_actor(actor, Chrono.CHAR_UNDO));
					add_to_animation_server(actor, [Anim.time_bubble]);
					maybe_change_terrain(actor, actor.pos, i, false, Greenness.Green, chrono, -1);
					break;

		#do sound effects for special moves and their undoes
		if (was_push and is_retro):
			add_to_animation_server(actor, [Anim.sfx, "unpush"]);
		if (was_push and !is_retro):
			add_to_animation_server(actor, [Anim.sfx, "push"]);
			# dirty hack - we would really rather have some way to send this information to their Anim.move event
			if (pushers_list.has(player)):
				player.exerting = true;
		
		add_to_animation_server(actor, [Anim.move, dir, is_retro]);

		return success;
	elif (success != Success.Yes):
		if (!hypothetical):
			# involuntary bump sfx (atm this plays when an ice block slide ends)
			if (actor.actorname == Actor.Name.IceBlock or is_retro):
				add_to_animation_server(actor, [Anim.sfx, "involuntarybumpother"], false);
		# bump animation always happens, I think?
		# unlike in Entwined Time, let's try NOT adding the bump at the start
		add_to_animation_server(actor, [Anim.bump, dir], false);
	
	return success;

func adjust_turn(is_winunwin: bool, amount: int, chrono : int) -> void:
	if (is_winunwin):
		add_undo_event([Undo.blue_turn, amount], chrono, amount > 0);
		blue_turn += amount;
	else:
		add_undo_event([Undo.red_turn, amount], chrono, is_winunwin);
		red_turn += amount;
		
func actors_in_tile(pos: Vector2) -> Array:
	var result = [];
	for actor in actors:
		if actor.pos == pos:
			result.append(actor);
	return result;

func terrain_in_tile(pos: Vector2, actor: Actor = null, chrono: int = Chrono.TIMELESS) -> Array:
	var result = [];
	for layer in terrain_layers:
		result.append(layer.get_cellv(pos));
	return result;

func chrono_for_maybe_green_actor(actor: Actor, chrono: int) -> int:
	if (chrono >= Chrono.META_UNDO):
		return chrono;
	if (actor.is_green):
		return Chrono.CHAR_UNDO;
	return chrono;

func set_cellv_maybe_rotation(id: int, tile: Vector2, layer: int) -> void:
	terrain_layers[layer].set_cellv(tile, id);

func maybe_break_actor(actor: Actor, hypothetical: bool, green_terrain: int, chrono: int) -> int:
	# AD04: being broken makes you immune to breaking :D
	if (!actor.broken):
		if (!hypothetical):
			if (green_terrain == Greenness.Green and chrono < Chrono.CHAR_UNDO):
				chrono = Chrono.CHAR_UNDO;
			if (green_terrain == Greenness.Void and chrono < Chrono.META_UNDO):
				chrono = Chrono.META_UNDO;
			if (actor.is_crystal and chrono < Chrono.CHAR_UNDO):
				chrono = Chrono.CHAR_UNDO;
			set_actor_var(actor, "broken", true, chrono);
		return Success.Surprise;
	else:
		return Success.No;

func find_or_create_layer_having_this_tile(pos: Vector2, assumed_old_tile: int) -> int:
	for layer in range(terrain_layers.size()):
		var terrain_layer = terrain_layers[layer];
		var old_tile = terrain_layer.get_cellv(pos);
		if (old_tile == assumed_old_tile):
			return layer;
	# create a new one.
	var new_layer = TileMap.new();
	new_layer.tile_set = terrainmap.tile_set;
	new_layer.cell_size = terrainmap.cell_size;
	# new layer will have to be at the back (first child, last terrain_layer), so I don't desync existing memories of layers.
	terrainmap.add_child(new_layer);
	terrainmap.move_child(new_layer, 0);
	terrain_layers.push_back(new_layer);
	return terrain_layers.size() - 1;

func maybe_change_terrain(actor: Actor, pos: Vector2, layer: int, hypothetical: bool, green_terrain: int,
chrono: int, new_tile: int, assumed_old_tile: int = -2, animation_nonce: int = -1) -> int:
	if (!hypothetical):
		var terrain_layer = terrain_layers[layer];
		var old_tile = terrain_layer.get_cellv(pos);
		if (assumed_old_tile != -2 and assumed_old_tile != old_tile):
			# desync (probably due to fuzz doubled glass mechanic). find or create the first layer where assumed_old_tile is correct.
			layer = find_or_create_layer_having_this_tile(pos, assumed_old_tile);
			terrain_layer = terrain_layers[layer];
			# set old_tile again (I guess it'll always be -1 at this point but just to be explicit about it)
			old_tile = terrain_layer.get_cellv(pos);
		set_cellv_maybe_rotation(new_tile, pos, layer);
		if (green_terrain == Greenness.Green and chrono < Chrono.CHAR_UNDO):
			chrono = Chrono.CHAR_UNDO;
		if (green_terrain == Greenness.Void and chrono < Chrono.META_UNDO):
			chrono = Chrono.META_UNDO;

		add_undo_event([Undo.change_terrain, actor, pos, layer, old_tile, new_tile, animation_nonce], chrono);
		
	return Success.Surprise;

func no_if_true_yes_if_false(input: bool) -> int:
	if (input):
		return Success.No;
	return Success.Yes;

#helper variable for 'did we just bonk on something that should flash'
var flash_terrain = -1;
var flash_colour = Color(1, 1, 1, 1);
# infinite loop variable
var bumper_counter: int = 0;

func try_enter_terrain(actor: Actor, pos: Vector2, chrono: int) -> int:
	var result = Success.Yes;
	flash_terrain = -1;
	
	var terrain = terrain_in_tile(pos, actor, chrono);
	for i in range(terrain.size()):
		var id = terrain[i];
		match id:
			Tiles.Wall:
				result = Success.No;
			Tiles.OneWaySouth:
				result = no_if_true_yes_if_false(pos.y < actor.pos.y);
			Tiles.OneWayWest:
				result = no_if_true_yes_if_false(pos.x > actor.pos.x);
			Tiles.OneWayEast:
				result = no_if_true_yes_if_false(pos.x < actor.pos.x);
			Tiles.OneWayNorth:
				result = no_if_true_yes_if_false(pos.y > actor.pos.y);
			Tiles.Water:
				result = no_if_true_yes_if_false(actor.actorname == Actor.Name.Player);
			Tiles.Ice:
				result = no_if_true_yes_if_false(actor.actorname != Actor.Name.Player && !actor.is_star);
			Tiles.MagicBarrier:
				result = no_if_true_yes_if_false(actor.is_star);
		if result != Success.Yes:
			return result;
	return result;
	
func strength_check(strength: int, heaviness: int) -> bool:
	if (heaviness == Heaviness.NONE):
		return strength >= Strength.NONE;
	if (heaviness == Heaviness.CRYSTAL):
		return strength >= Strength.CRYSTAL;
	if (heaviness == Heaviness.WOODEN):
		return strength >= Strength.WOODEN;
	if (heaviness == Heaviness.IRON):
		return strength >= Strength.LIGHT;
	if (heaviness == Heaviness.STEEL):
		return strength >= Strength.HEAVY;
	if (heaviness == Heaviness.SUPERHEAVY):
		return strength >= Strength.GRAVITY;
	return false;
	
func try_enter(actor: Actor, dir: Vector2, chrono: int, can_push: bool, hypothetical: bool, was_push: bool, is_retro: bool = false, pushers_list: Array = []) -> int:
	var dest = actor.pos + dir;
	if (chrono >= Chrono.TIMELESS):
		return Success.Yes;
	if (chrono >= Chrono.META_UNDO and is_retro):
		# assuming no bugs, if it was overlapping in the meta-past, then it must have been valid to reach then
		return Success.Yes;
	# Also, for Unwin in particular, retro moves don't desync (though they might do other things in the future...)
	if (chrono >= Chrono.CHAR_UNDO and is_retro):
		return Success.Yes;
	
	var solidity_check = try_enter_terrain(actor, dest, chrono);
	if (solidity_check != Success.Yes):
		return solidity_check;
	
	# handle pushing
	var actors_there = actors_in_tile(dest);
	var pushables_there = [];
	for actor_there in actors_there:
		if actor_there.pushable(actor):
			pushables_there.push_back(actor_there);
	
	if (pushables_there.size() > 0):
		if (!can_push):
			return Success.No;
		# check if the current actor COULD push the next actor, then give them a push and return the result
		# Multi Push Rule: Multipushes are allowed (even multiple things in a tile and etc) unless another rule prohibits it.
		var strength_modifier = 0;
		pushers_list.append(actor);
		for actor_there in pushables_there:
			# Strength Rule
			if !strength_check(actor.strength + strength_modifier, actor_there.heaviness):
				pushers_list.pop_back();
				return Success.No;
		var result = Success.Yes;

		var surprises = [];
		result = Success.Yes;
		for actor_there in pushables_there:
			var actor_there_result = move_actor_relative(actor_there, dir, chrono, true, false, pushers_list);
			if actor_there_result == Success.No:
				pushers_list.pop_back();
				return Success.No;
			if actor_there_result == Success.Surprise:
				result = Success.Surprise;
				surprises.append(actor_there);
		
		if (!hypothetical):
			if (result == Success.Surprise):
				for actor_there in surprises:
					move_actor_relative(actor_there, dir, chrono, hypothetical, false, pushers_list);
			else:
				for actor_there in pushables_there:
					actor_there.just_moved = true;
					move_actor_relative(actor_there, dir, chrono, hypothetical, false, pushers_list);
				for actor_there in pushables_there:
					actor_there.just_moved = false;
		
		pushers_list.pop_back();
		
		return result;
	
	return Success.Yes;

func lose(reason: String, lose_instantly: bool = false, music: String = "lose") -> void:
	lost = true;
	winlabel.change_text(reason + "\n\nReally Undo or Restart to continue.")
	lost_speaker.stream = sounds[music];
	if (lose_instantly):
		fade_in_lost();
	
func end_lose() -> void:
	lost = false;
	lost_speaker.stop();
	winlabel.visible = false;
	Shade.on = false;
	if won_fade_started:
		won_fade_started = false;
		player.modulate.a = 1;

func add_hole_sprite(actor: ActorBase, layer: int) -> void:
	var sprite = Sprite.new();
	hole_sprites[actor.pos] = sprite;
	sprite.position = actor.pos*cell_size + Vector2(cell_size/2, cell_size/2);
	sprite.texture = preload("res://assets/pit_filling.png");
	sprite.hframes = 5;
	sprite.vframes = 3;
	add_actor_or_goal_at_appropriate_layer_at_back(sprite, layer);

func set_actor_var(actor: ActorBase, prop: String, value, chrono: int,
is_retro: bool = false, _retro_old_value = null) -> void:
	var old_value = actor.get(prop);
	
	# sanity check: prevent, for example, spotlight from making a broken->broken event
	if (old_value == value):
		return
	actor.set(prop, value);
	
	var is_winunwin = false;
	if (prop == "broken"):
		# for now, uncollecting a star is not is_winunwin, because there's no way to non-retro do it.
		# TODO: I think we actually check is_retro, but I need star revival to care about this first
		if (actor.is_star):
			if (value == true):
				starbar.star_get();
				is_winunwin = true;
			else:
				starbar.star_unget();
			if (actor.actorname == Actor.Name.CrackedStar):
				if chrono == Chrono.MOVE:
					chrono = Chrono.CHAR_UNDO;
					is_winunwin = false;
		if actor.post_mortem == Actor.PostMortems.Collect:
			if (value == true):
				for goal in goals:
					add_to_animation_server(goal, [Anim.starget]);
				add_to_animation_server(actor, [Anim.starget]);
				add_to_animation_server(player, [Anim.stall, 0.8*Engine.time_scale]);
				add_to_animation_server(player, [Anim.sing]);
			else:
				for goal in goals:
					add_to_animation_server(goal, [Anim.starunget]);
				add_to_animation_server(actor, [Anim.starunget]);
				add_to_animation_server(player, [Anim.sing]);
		elif actor.post_mortem == Actor.PostMortems.Fall:
			if (value == true):
				add_to_animation_server(actor, [Anim.fall]);
			else:
				add_to_animation_server(actor, [Anim.sfx, "unfall"]);
		elif actor.post_mortem == Actor.PostMortems.Melt:
			if (value == true):
				add_to_animation_server(actor, [Anim.melt]);
			else:
				add_to_animation_server(actor, [Anim.unmelt]);
	
	add_undo_event([Undo.set_actor_var, actor, prop, old_value, value], chrono_for_maybe_green_actor(actor, chrono), is_winunwin);
	
	add_to_animation_server(actor, [Anim.set_next_texture, actor.get_next_texture(), actor.facing_dir])
			
	# stall certain animations
#	if (prop == "broken"):
#		add_to_animation_server(actor, [Anim.stall, 0.14]);

func add_undo_event(event: Array, chrono: int = Chrono.MOVE, is_winunwin: bool = false) -> void:
	#if (debug_prints and chrono < Chrono.META_UNDO):
	# print("add_undo_event", " ", event, " ", chrono, " ", is_winunwin);
	
	if is_winunwin:
		if chrono >= Chrono.META_UNDO:
			pass
		else:
			while (blue_undo_buffer.size() <= blue_turn):
				blue_undo_buffer.append([]);
			blue_undo_buffer[blue_turn].push_front(event);
			add_undo_event([Undo.blue_undo_event_add, blue_turn], Chrono.CHAR_UNDO);
	else:
		if (chrono == Chrono.MOVE):
			while (red_undo_buffer.size() <= red_turn):
				red_undo_buffer.append([]);
			red_undo_buffer[red_turn].push_front(event);
			add_undo_event([Undo.red_undo_event_add, red_turn], Chrono.CHAR_UNDO);

	if (chrono <= Chrono.CHAR_UNDO):
		while (meta_undo_buffer.size() <= meta_turn):
			meta_undo_buffer.append([]);
		meta_undo_buffer[meta_turn].push_front(event);

func append_replay(move: String) -> void:
	if (!preserving_meta_redo_inputs):
		meta_redo_inputs = "";
	user_replay += move;
	
func meta_undo_replay() -> bool:
	if (voidlike_puzzle):
		user_replay += "c";
	else:
		meta_redo_inputs += user_replay[user_replay.length() - 1]
		user_replay = user_replay.left(user_replay.length() - 1);
	return true;

func character_undo(is_silent: bool = false) -> bool:
	var chrono = Chrono.CHAR_UNDO;
	if (won or lost): return false;
	# check if we can undo
	if (red_turn <= 0):
		if !is_silent:
			play_sound("bump");
		return false;
	finish_animations(Chrono.CHAR_UNDO);
	#the undo itself
	var events = red_undo_buffer.pop_at(red_turn - 1);
	for event in events:
		undo_one_event(event, chrono);
		add_undo_event([Undo.red_undo_event_remove, red_turn, event], Chrono.CHAR_UNDO);
	
	time_passes(chrono);
	
	append_replay("z");
	
	if (z_shown):
		z_used = true;
	
	if anything_happened_char(false):
		adjust_turn(false, 1, Chrono.MOVE);
	if anything_happened_char(true):
		adjust_turn(true, 1, Chrono.MOVE);
	
	adjust_meta_turn(1, chrono);
	
	if (!is_silent):
		play_sound("undostrong");
		if (!currently_fast_replay()):
			undo_effect_strength = 0.12;
			undo_effect_per_second = undo_effect_strength*(1/0.4);
			undo_effect_color = red_color;
	return true;

func character_unwin(is_silent: bool = false) -> bool:
	var chrono = Chrono.CHAR_UNDO;
	if (won or lost): return false;
	# check if we can unwin
	if (blue_turn <= 0):
		if !is_silent:
			play_sound("bump");
		return false;
		
	# check for dark stars
	for event in blue_undo_buffer[blue_turn - 1]:
		if event[0] == Undo.set_actor_var and event[1].actorname == Actor.Name.DarkStar:
			floating_text("Cannot Unwin a Dark Star.");
			if !is_silent:
				play_sound("bump");
			return false;
		
	finish_animations(Chrono.CHAR_UNDO);
	#the unwin itself
	var events = blue_undo_buffer.pop_at(blue_turn - 1);
	for event in events:
		undo_one_event(event, chrono);
		add_undo_event([Undo.blue_undo_event_remove, blue_turn, event], Chrono.CHAR_UNDO);
	
	time_passes(chrono);

	append_replay("x");
	
	if (x_shown):
		x_used = true;
		if (!c_shown):
			c_shown = true;
			show_button(virtualbuttons.get_node("Verbs/MetaUndoButton"));
	
	if anything_happened_char(false):
		adjust_turn(false, 1, Chrono.MOVE);
	if anything_happened_char(true):
		adjust_turn(true, 1, Chrono.MOVE);
	
	adjust_meta_turn(1, chrono);
	
	if (!is_silent):
		play_sound("undostrong");
		if (!currently_fast_replay()):
			undo_effect_strength = 0.12;
			undo_effect_per_second = undo_effect_strength*(1/0.4);
			undo_effect_color = blue_color;
	return true;

func finish_animations(chrono: int) -> void:
	undo_effect_color = Color.transparent;
	
	if (chrono >= Chrono.META_UNDO):
		for actor in actors:
			actor.animation_timer = 0;
			actor.animations.clear();
		for actor in goals:
			actor.animation_timer = 0;
			actor.animations.clear();
	else:
		# new logic instead of clearing animations - run animations over and over until we're done
		# this should get rid of all bugs of the form 'if an animation is skipped over some side effect never completes' 5ever
		while true:
			update_animation_server(true);
			for actor in actors:
				while (actor.animations.size() > 0):
					actor.animation_timer = 99;
					actor._process(0);
				actor.animation_timer = 0;
			for actor in goals:
				while (actor.animations.size() > 0):
					actor.animation_timer = 99;
					actor._process(0);
				actor.animation_timer = 0;
			if animation_server.size() <= 0:
				break;
			
	for actor in actors:
		actor.position = terrainmap.map_to_world(actor.pos);
		actor.update_graphics();
	for goal in goals:
		goal.calculate_speed();
	animation_server.clear();
	animation_substep = 0;
	
	for hole_sprite in hole_sprites.values():
		hole_sprite.queue_free();
	hole_sprites.clear();

func adjust_meta_turn(amount: int, chrono: int) -> void:
	meta_turn += amount;
	#if (debug_prints):
	# print("=== IT IS NOW META TURN " + str(meta_turn) + " ===");
	if (won or lost or amount >= 0):
		check_won(chrono);
	
var seen_goal : bool = false;
	
func check_won(chrono: int) -> void:
	won = false;
	var locked = false;
	
	if (lost):
		return
	Shade.on = false;
	
	#check stars
	for actor in actors:
		if actor.is_star and !actor.broken:
			locked = true;
			break;
	
	var on_goal = !player.broken and terrain_in_tile(player.pos, player, chrono).has(Tiles.Win);
	
	if (locked and on_goal and !is_custom and !doing_replay and !seen_goal):
		floating_text("Collect more Stars (%d/%d)" % [starbar.collected, starbar.collected_max] )
		seen_goal = true;
	
	if (!locked and on_goal):
		won = true;
		if (won and test_mode):
			var level_info = terrainmap.get_node_or_null("LevelInfo");
			if (level_info != null):
				level_info.level_replay = annotate_replay(user_replay);
				if (custom_string != ""):
					#HACK: time to do surgery on a string lol
					custom_string = custom_string.replace("\"level_replay\":\"\"", "\"level_replay\":\"" + level_info.level_replay + "\"")
					custom_string = custom_string.replace(annotated_authors_replay, level_info.level_replay);
				floating_text("Test successful, recorded replay!");
		if (won == true and !doing_replay):
			play_won("outro");
			var levels_save_data = save_file["levels"];
			if (!levels_save_data.has(level_name)):
				levels_save_data[level_name] = {};
			var level_save_data = levels_save_data[level_name];
			if (level_save_data.has("won") and level_save_data["won"]):
				pass
			else:
				level_save_data["won"] = true;
				levelstar.previous_modulate = Color(1, 1, 1, 0);
				levelstar.flash();
				if (!in_insight_level):
					if (!is_custom):
						puzzles_completed += 1;
						if (level_is_extra):
							advanced_puzzles_completed += 1;
					specific_puzzles_completed[level_number] = true;
			if (!level_save_data.has("replay")):
				level_save_data["replay"] = annotate_replay(user_replay);
			else:
				var old_replay = level_save_data["replay"];
				var old_replay_parts = old_replay.split("$");
				var old_replay_data = old_replay_parts[old_replay_parts.size()-2];
				var old_replay_mturn_parts = old_replay_data.split("=");
				var old_replay_mturn = int(old_replay_mturn_parts[1]);
				if (old_replay_mturn > meta_turn):
					level_save_data["replay"] = annotate_replay(user_replay);
				elif (old_replay_mturn == meta_turn):
					# same meta-turn but shorter replay also wins
					var old_replay_payload = old_replay_parts[old_replay_parts.size()-1];
					if (len(user_replay) <= len(old_replay_payload)):
						level_save_data["replay"] = annotate_replay(user_replay);
			update_level_label();
			save_game();
	
	winlabel.visible = won;
	virtualbuttons.get_node("Others/EnterButton").visible = won and virtualbuttons.visible;
	virtualbuttons.get_node("Others/EnterButton").disabled = !won or !virtualbuttons.visible;
	if (won):
		won_cooldown = 0;
		var then = "Watch Replay"
		if (in_insight_level):
			then = "Lose Insight"
		elif !(doing_replay):
			then += "\nOr try custom puzzles! (link in itch.io description)";
		if !doing_replay:
			winlabel.change_text("You have won!\nProgramming: Patashu\nGraphics: Teal Knight\n[" + human_readable_input("ui_accept", 1) + "]: " + then);
		elif doing_replay:
			winlabel.change_text("You have won!\n\n[" + human_readable_input("ui_accept", 1) + "]: " + then)
		won_fade_started = false;
		tutoriallabel.visible = false;
		call_deferred("adjust_winlabel_deferred");
	elif won_fade_started:
		won_fade_started = false;
		player.modulate.a = 1;
	
func adjust_winlabel_deferred() -> void:
	call_deferred("adjust_winlabel");
	
func adjust_winlabel() -> void:
	var winlabel_rect_size = winlabel.get_rect_size();
	winlabel.set_rect_position(Vector2(pixel_width/2 - int(floor(winlabel_rect_size.x/2)), win_label_default_y));
	var tries = 1;
	var player_rect = player.get_rect();
	var label_rect = Rect2(winlabel.get_rect_position(), winlabel_rect_size);
	player_rect.position = terrainmap.map_to_world(player.pos) + terrainmap.global_position;
	while (tries < 99):
		if player_rect.intersects(label_rect):
			var polarity = 1;
			if (tries % 2 == 0):
				polarity = -1;
			winlabel.set_rect_position(Vector2(winlabel.get_rect_position().x, winlabel.get_rect_position().y + 8*tries*polarity));
			label_rect.position.y += 8*tries*polarity;
		else:
			break;
		tries += 1;
	
func undo_one_event(event: Array, chrono : int) -> void:
	#if (debug_prints):
	# print("undo_one_event", " ", event, " ", chrono);

	match event[0]:
		Undo.move:
			var actor = event[1];
			var dir = event[2];
			var was_push = event[3];
			if (chrono >= Chrono.META_UNDO or !actor.is_green):
				move_actor_relative(actor, -event[2], chrono, false, true, [], event[3]);
		Undo.set_actor_var:
			var actor = event[1];
			var retro_old_value = event[4];
			var is_retro = true;
			if (chrono >= Chrono.META_UNDO or !actor.is_green):
				set_actor_var(actor, event[2], event[3], chrono, is_retro, retro_old_value);
		Undo.change_terrain:
			var actor = event[1];
			var pos = event[2];
			var layer = event[3];
			var old_tile = event[4];
			var new_tile = event[5];
			maybe_change_terrain(actor, pos, layer, false, false, chrono, old_tile, new_tile);
		Undo.sfx:
			var actor = event[1];
			var sfx = event[2];
			add_to_animation_server(actor, [Anim.sfx, sfx]);
	
	match event[0]:
		Undo.red_turn:
			adjust_turn(false, -event[1], chrono);
		Undo.blue_turn:
			adjust_turn(true, -event[1], chrono);
		Undo.red_undo_event_add:
			while (red_undo_buffer.size() <= event[1]):
				red_undo_buffer.append([]);
			red_undo_buffer[event[1]].pop_front();
		Undo.blue_undo_event_add:
			while (blue_undo_buffer.size() <= event[1]):
				blue_undo_buffer.append([]);
			blue_undo_buffer[event[1]].pop_front();
		Undo.red_undo_event_remove:
			# meta undo an undo creates a char undo event but not a meta undo event, it's special!
			while (red_undo_buffer.size() <= event[1]):
				red_undo_buffer.append([]);
			red_undo_buffer[event[1]].push_front(event[2]);
		Undo.blue_undo_event_remove:
			while (blue_undo_buffer.size() <= event[1]):
				blue_undo_buffer.append([]);
			blue_undo_buffer[event[1]].push_front(event[2]);
		Undo.animation_substep:
			# don't need to emit a new event as meta undoing and beyond is a teleport
			animation_substep += 1;
		Undo.time_bubble:
			var actor = event[1];
			actor.is_green = false;
			actor.update_time_bubble();

func meta_undo_a_restart() -> bool:
	var meta_undo_a_restart_type = 2;
	if (save_file.has("meta_undo_a_restart")):
		meta_undo_a_restart_type = int(save_file["meta_undo_a_restart"]);
	if (meta_undo_a_restart_type == 4): #No
		return false;
	
	if (user_replay_before_restarts.size() > 0):
		user_replay = "";
		end_replay();
		toggle_replay();
		level_replay = user_replay_before_restarts.pop_back();
		cut_sound();
		play_sound("metarestart");
		match meta_undo_a_restart_type:
			0: # Yes
				meta_undo_a_restart_mode = true;
				replay_advance_turn(level_replay.length());
				end_replay();
				finish_animations(Chrono.TIMELESS);
				meta_undo_a_restart_mode = false;
			1: # Replay (Instant)
				meta_undo_a_restart_mode = true;
				replay_advance_turn(level_replay.length());
				finish_animations(Chrono.TIMELESS);
				meta_undo_a_restart_mode = false;
			2: # Replay (Fast)
				meta_undo_a_restart_mode = true;
				next_replay = -1;
			3: # Replay
				pass
		return true;
	return false;

func meta_undo(is_silent: bool = false) -> bool:
	preserving_meta_redo_inputs = true;
	if (meta_turn <= 0):
		if (user_replay == ""):
			if !key_repeat_this_frame_dict["meta_undo"]:
				if (!doing_replay):
					if (meta_undo_a_restart()):
						#preserving_meta_redo_inputs = false; #done in ready_map()
						return true;
		if !is_silent:
			play_sound("bump");
		preserving_meta_redo_inputs = false;
		return false;
	
	end_lose();
	finish_animations(Chrono.MOVE);
	
	if (!c_shown):
		c_shown = true;
		show_button(virtualbuttons.get_node("Verbs/MetaUndoButton"));
	c_used = true;
	if (z_used and x_used):
		tutoriallabel.visible = false;
		metainfolabel.visible = true;

	var events = meta_undo_buffer.pop_back();
	for event in events:
		undo_one_event(event, Chrono.META_UNDO);
	if (!is_silent):
		cut_sound();
		play_sound("metaundo");
	just_did_meta();
	starbar.finish_animations();
	adjust_meta_turn(-1, Chrono.META_UNDO);
	var result = meta_undo_replay();
	preserving_meta_redo_inputs = false;
	return result;

func just_did_meta() -> void:
	if (!currently_fast_replay()):
		undo_effect_strength = 0.08;
		undo_effect_per_second = undo_effect_strength*(1/0.2);
	for whatever in underactorsparticles.get_children():
		whatever.queue_free();
	for whatever in overactorsparticles.get_children():
		whatever.queue_free();
	finish_animations(Chrono.META_UNDO);
	undo_effect_color = meta_color;
	# void things experience time when you undo
	time_passes(Chrono.META_UNDO);

func meta_redo() -> bool:
	if (won or lost):
		return false;
	if (meta_redo_inputs == ""):
		if !key_repeat_this_frame_dict["meta_redo"]:
			play_sound("bump");
		return false;
	preserving_meta_redo_inputs = true;
	var letter = meta_redo_inputs[meta_redo_inputs.length() - 1];
	meta_redo_inputs = meta_redo_inputs.left(meta_redo_inputs.length() - 1);
	do_one_letter(letter);
	#cut_sound();
	play_sound("metaredo");
	#just_did_meta();
	preserving_meta_redo_inputs = false;
	metaredobuttonlabel.visible = false;
	return true;

func do_one_letter(replay_char: String) -> void:
	match replay_char:
		"w":
			character_move(Vector2.UP);
		"a":
			character_move(Vector2.LEFT);
		"s":
			character_move(Vector2.DOWN);
		"d":
			character_move(Vector2.RIGHT);
		"z":
			character_undo();
		"x":
			character_unwin();
		"c":
			meta_undo();

func restart(_is_silent: bool = false) -> void:
	# because it's so long and you might restart/gain insight/level editor/replay mode early
	if (fadeout_timer_max > 2.0):
		fadeout_timer = 0.0;
		fadeout_timer_max = 1.0;
	
	load_level(0);
	cut_sound();
	play_sound("restart");
	undo_effect_strength = 0.3;
	undo_effect_per_second = undo_effect_strength*(1/0.5);
	#finish_animations(Chrono.TIMELESS);
	undo_effect_color = meta_color;
	
func escape() -> void:
	if (test_mode and won):
		level_editor();
		test_mode = false;
		return;
	
	if (ui_stack.size() > 0):
		# can happen if we click the button directly
		var topmost_ui = ui_stack.pop_front();
		topmost_ui.queue_free();
		return;
	var a = preload("res://Menu.tscn").instance();
	add_to_ui_stack(a);

func level_editor() -> void:
	var a = preload("res://level_editor/LevelEditor.tscn").instance();
	add_to_ui_stack(a);

func how_many_standard_puzzles_are_solved_in_chapter(chapter: int) -> Array:
	var x = 0;
	var y = -1;
	var start = chapter_standard_starting_levels[chapter];
	var end = chapter_advanced_starting_levels[chapter];
	for i in range(start, end):
		y += 1;
		if (specific_puzzles_completed[i]):
			x += 1;
	if (y > 8):
		y = 8;
	return [x, y];
	
func trying_to_load_locked_level(level_number: int, is_custom: bool) -> bool:
	return false;
	
func setup_chapter_etc() -> void:
	if (is_custom):
		return;
	chapter = 0;
	level_is_extra = false;
	for i in range(chapter_names.size()):
		if level_number < chapter_standard_starting_levels[i + 1]:
			chapter = i;
			if level_number >= chapter_advanced_starting_levels[i]:
				level_is_extra = true;
				level_in_chapter = level_number - chapter_advanced_starting_levels[i];
			else:
				level_in_chapter = level_number - chapter_standard_starting_levels[i];
			break;
	var target_target_track = chapter_tracks[chapter]
	var target_target_sky = chapter_skies[chapter];
#	if (chapter >= custom_past_here):
#		var level_info = terrainmap.get_node_or_null("LevelInfo");
#		if (level_info != null):
#			target_target_sky = level_info.target_sky;
#			target_target_track = level_info.target_track;
	if (target_sky != target_target_sky):
		sky_timer = 0;
		sky_timer_max = 3.0;
		old_sky = current_sky;
		target_sky = target_target_sky;
	if (target_track != target_target_track):
		target_track = target_target_track;
		if (current_track == -1):
			play_next_song();
		else:
			fadeout_timer = max(fadeout_timer, 0); #so if we're in the middle of a fadeout it doesn't reset
			fadeout_timer_max = 3.0;
	
func play_next_song() -> void:
	if (!ready_done):
		return;
	
	current_track = target_track;
	fadeout_timer = 0;
	fadeout_timer_max = 0;
	if (is_instance_valid(now_playing)):
		now_playing.queue_free();
	now_playing = null;
	
	if (current_track > -1 and current_track < music_tracks.size() and current_track < music_info.size()):
		music_speaker.stream = music_tracks[current_track];
		music_speaker.play();
		var value = save_file["music_volume"];
		var master_volume = save_file["master_volume"];
		if (value > -30 and master_volume > -30 and !muted): #music is not muted
			if (ui_stack.size() == 0 or (ui_stack[0].name != "TitleScreen" and ui_stack[0].name != "EndingCutscene1" and ui_stack[0].name != "EndingCutscene2")):
				now_playing = preload("res://NowPlaying.tscn").instance();
				GuiHolder.call_deferred("add_child", now_playing);
				#self.get_parent().add_child(now_playing);
				now_playing.initialize(music_info[current_track]);
	else:
		music_speaker.stop();

func load_level_direct(new_level: int) -> void:
	is_custom = false;
	end_replay();
	in_insight_level = false;
	has_insight_level = false;
	var impulse = new_level - self.level_number;
	load_level(impulse, true);
	
func load_level(impulse: int, ignore_locked: bool = false) -> void:
	if (impulse != 0 and test_mode):
		level_editor();
		test_mode = false;
		return;
	
	if (impulse != 0):
		is_custom = false; # at least until custom campaigns :eyes:
	level_number = posmod(int(level_number), level_list.size());
	
	if (impulse != 0):
		user_replay_before_restarts.clear();
	elif user_replay.length() > 0:
		user_replay_before_restarts.push_back(user_replay);
	
	if (impulse != 0):
		level_number += impulse;
		level_number = posmod(int(level_number), level_list.size());
	
	# we might try to F1/F2 onto a level we don't have access to. if so, back up then show level select.
	if impulse != 0 and !ignore_locked and trying_to_load_locked_level(level_number, is_custom):
		impulse *= -1;
		if (impulse == 0):
			impulse = -1;
		for _i in range(999):
			level_number += impulse;
			level_number = posmod(int(level_number), level_list.size());
			setup_chapter_etc();
			if !trying_to_load_locked_level(level_number, is_custom):
				break;
			
	if (impulse != 0):
		in_insight_level = false;
		save_file["level_number"] = level_number;
		level_replay = "";
		save_game();
	
	var level = null;
	if (is_custom):
		load_custom_level(custom_string);
		return;
	if (impulse == 0 and has_insight_level and in_insight_level and insight_level_scene != null):
		level = insight_level_scene.instance();
	else:
		level = level_list[level_number].instance();
	levelfolder.remove_child(terrainmap);
	terrainmap.queue_free();
	levelfolder.add_child(level);
	terrainmap = level;
	terrain_layers.clear();
	terrain_layers.append(terrainmap);
	for child in terrainmap.get_children():
		if child is TileMap:
			terrain_layers.push_front(child);
	
	setup_chapter_etc();
	ready_map();

func character_move(dir: Vector2) -> bool:
	if (won or lost): return false;
	var chr = "";
	match dir:
		Vector2.UP:
			chr = "w";
		Vector2.DOWN:
			chr = "s";
		Vector2.LEFT:
			chr = "a";
		Vector2.RIGHT:
			chr = "d";
	var result = false;
	if true:
		var pos = player.pos;
		if (player.broken):
			play_sound("bump");
			return false;
		finish_animations(Chrono.MOVE);
		result = move_actor_initiate(player, dir, Chrono.MOVE,
		false, false, [], false, true);
	
	if (result == Success.Yes):
		play_sound("heavystep");

	if (result != Success.No):
		time_passes(Chrono.MOVE);
		if anything_happened_char(false):
			adjust_turn(false, 1, Chrono.MOVE);
		if anything_happened_char(true):
			adjust_turn(true, 1, Chrono.MOVE);
	if (result != Success.No):
		append_replay(chr);
	if (result != Success.Yes):
		play_sound("bump")
	if (result != Success.No):
		if (!z_shown):
			show_button(virtualbuttons.get_node("Verbs/UndoButton"));
			z_shown = true;
		adjust_meta_turn(1, Chrono.MOVE);
	return result != Success.No;

func anything_happened_char(is_winunwin: bool, destructive: bool = true) -> bool:
	if (!is_winunwin):
		var turn = red_turn;
		while (red_undo_buffer.size() <= turn):
			red_undo_buffer.append([]);
		for event in red_undo_buffer[turn]:
			if event[0] != Undo.animation_substep:
				return true;
		#clear out now unnecessary animation_substeps if nothing else happened
		if (destructive):
			red_undo_buffer.pop_at(turn);
	else:
		var turn = blue_turn;
		while (blue_undo_buffer.size() <= turn):
			blue_undo_buffer.append([]);
		for event in blue_undo_buffer[turn]:
			if event[0] != Undo.animation_substep:
				return true;
		#clear out now unnecessary animation_substeps if nothing else happened
		if (destructive):
			blue_undo_buffer.pop_at(turn);
	return false;

func time_passes(chrono: int) -> void:
	animation_substep(chrono);
	
	# Fall into holes and bottomless pits. (Having this happen before star collect is INTERESTING...)
	if (chrono < Chrono.META_UNDO):
		for actor in actors:
			if actor.broken or actor.is_star:
				continue
			var terrain = terrain_in_tile(actor.pos, actor, chrono);
			for i in range(terrain.size()):
				var tile = terrain[i];
				if tile == Tiles.Hole:
					actor.post_mortem = Actor.PostMortems.Fall;
					add_hole_sprite(actor, i);
					set_actor_var(actor, "broken", true, chrono);
					maybe_change_terrain(actor, actor.pos, i, false, Greenness.Mundane, chrono, -1);
					break;
				elif tile == Tiles.BottomlessPit:
					actor.post_mortem = Actor.PostMortems.Fall;
					set_actor_var(actor, "broken", true, chrono);
					break;
	
	animation_substep(chrono);
	
	# Collect stars. (Going to experiment with collecting happening during undo/unwin.)
	if (chrono < Chrono.META_UNDO and !player.broken):
		for actor in actors:
			if actor.is_star and !actor.broken and actor.pos == player.pos:
				# 'it's a blue event' will be handled inside of set_actor_var.
				actor.post_mortem = Actor.PostMortems.Collect;
				set_actor_var(actor, "broken", true, chrono);
				
				if (!x_shown):
					x_shown = true;
					show_button(virtualbuttons.get_node("Verbs/UnwinButton"));
				
				# Melt all surrounding ice.
				# Notably this happens at Chrono.MOVE speed so it can't be 'forgotten'.
				# ... Actually that might be a problem after all. Hmm.
				# Like, if you collect a star during an undo, where does the ice melting GO.
				# Idk, maybe it's okay? I'll try it and see if it's too buggy.
				for actor2 in actors:
					if actor2.actorname == Actor.Name.IceBlock and !actor2.broken:
						if abs(actor2.pos.x - actor.pos.x) <= 1 and abs(actor2.pos.y - actor.pos.y) <= 1:
							actor2.post_mortem = Actor.PostMortems.Melt;
							set_actor_var(actor2, "broken", true, Chrono.MOVE);
	
func currently_fast_replay() -> bool:
	if (!doing_replay):
		return false;
	if (replayturnslider_in_drag):
		return true;
	if replay_interval() > 0.05:
		return false;
	if (replay_paused):
		return false;
	if (replay_turn >= (level_replay.length())):
		return false;
	return true;
	
func replay_interval() -> float:
	if unit_test_mode:
		return 0.01;
	if meta_undo_a_restart_mode:
		return 0.01;
	return replay_interval;
	
func authors_replay() -> void:
	if (ui_stack.size() > 0):
		return;
	
	if (!doing_replay):
		if (!unit_test_mode):
			if (!save_file.has("authors_replay") or save_file["authors_replay"] != true):
				var modal = preload("res://AuthorsReplayModalPrompt.tscn").instance();
				add_to_ui_stack(modal);
				return;
	
	toggle_replay();
	level_replay = authors_replay;
	if (level_replay.find("c") >= 0):
		voidlike_puzzle = true;
	
func toggle_replay() -> void:
	tutorial_complete();
	meta_undo_a_restart_mode = false;
	unit_test_mode = false;
	if (doing_replay):
		end_replay();
		return;
	doing_replay = true;
	replaybuttons.visible = true;
	restart();
	replay_paused = false;
	replay_turn = 0;
	next_replay = replay_timer + replay_interval();
	unit_test_mode = OS.is_debug_build() and Input.is_action_pressed(("shift"));
	
var double_unit_test_mode : bool = false;
var unit_test_mode_do_second_pass : bool = false;
var unit_test_blacklist = {}
	
func do_one_replay_turn() -> void:
	if (!doing_replay):
		return;
	if replay_turn >= level_replay.length():
		meta_undo_a_restart_mode = false;
		if (unit_test_mode and won and level_number < (level_list.size() - 1)):
			doing_replay = true;
			replaybuttons.visible = true;
			if (double_unit_test_mode):
				if unit_test_mode_do_second_pass:
					unit_test_mode_do_second_pass = false;
					var replay = user_replay;
					load_level(0);
					level_replay = replay;
				else:
					unit_test_mode_do_second_pass = true;
					if (has_insight_level and !in_insight_level):
						gain_insight();
					else:
						load_level(1);
						while (unit_test_blacklist.has(level_name)):
							load_level(1);
			else:
				if (has_insight_level and !in_insight_level):
					gain_insight();
				else:
					load_level(1);
					while (unit_test_blacklist.has(level_name)):
						load_level(1);
			replay_turn = 0;
			level_replay = authors_replay;
			next_replay = replay_timer + replay_interval();
			return;
		else:
			if (unit_test_mode):
				floating_text("Tested up to level: " + str(level_number) + " (This is 0 indexed lol)" );
				end_replay();
				if (level_number == level_filenames.size() - 1):
					load_level_direct(0); # Patashu anti-spoiler protection :3;
			return;
	next_replay = replay_timer+replay_interval();
	var replay_char = level_replay[replay_turn];
	var old_meta_turn = meta_turn;
	replay_turn += 1;
	do_one_letter(replay_char);
	if replay_char == "x":
		return
	elif old_meta_turn == meta_turn and !voidlike_puzzle:
		replay_turn -= 1;
		# replay contains a bump - silently delete the bump so we don't desync when trying to meta-undo it
		level_replay = level_replay.left(replay_turn) + level_replay.right(replay_turn + 1)
	
func end_replay() -> void:
	doing_replay = false;
	update_level_label();
	
func pause_replay() -> void:
	if replay_paused:
		replay_paused = false;
		floating_text("Replay unpaused");
		replay_timer = next_replay;
	else:
		replay_paused = true;
		floating_text("Replay paused");
	update_info_labels();
	
func replay_advance_turn(amount: int) -> void:
	if amount > 0:
		for _i in range(amount):
			if (replay_turn < (level_replay.length())):
				do_one_replay_turn();
			else:
				play_sound("bump");
				break;
	elif (replay_turn <= 0):
		play_sound("bump");
	else:
		var target_turn = replay_turn + amount;
		if (target_turn < 0):
			target_turn = 0;
		
		# Restart and advance the puzzle from the start if:
		# 1) voidlike_puzzle (contains void elements or the replay contains a meta undo)
		# 2) it's a long jump, and going forward from the start would be quicker
		# (currently assuming an undo is 2.1x as fast as a forward move, which seems roughly right)
		var restart_and_advance = false;
		if (voidlike_puzzle):
			restart_and_advance = true;
		elif amount < -50 and target_turn*2.1 < -amount:
			restart_and_advance = true;
			
		if (restart_and_advance):
			var replay = level_replay;
			user_replay = ""; #to not pollute meta undo a restart buffer
			var old_muted = muted;
			muted = true;
			var old_replay_interval = replay_interval;
			replay_interval = 0.001;
			load_level(0);
			start_specific_replay(replay);
			for _i in range(target_turn):
				do_one_replay_turn();
			finish_animations(Chrono.TIMELESS);

			replay_interval = old_replay_interval;
			muted = old_muted;
			# weaker and slower than meta-undo
			undo_effect_strength = 0.04;
			undo_effect_per_second = undo_effect_strength*(1/0.4);
			play_sound("voidundo");
			for child in levelscene.get_children():
				if child is FloatingText:
					child.queue_free();
		else:
			var iterations = replay_turn - target_turn;
			for _i in range(iterations):
				meta_undo();
				replay_turn -= 1;
	replay_paused = true;
	update_info_labels();
			
func update_level_label() -> void:
	var levelnumberastext = ""
	if (is_custom):
		levelnumberastext = "CUSTOM";
	else:
		pass
#		var chapter_string = str(chapter);
#		if chapter_replacements.has(chapter):
#			chapter_string = chapter_replacements[chapter];
#		var level_string = str(level_in_chapter);
#		if (level_replacements.has(level_number)):
#			level_string = level_replacements[level_number];
#		levelnumberastext = chapter_string + "-" + level_string;
#		if (level_is_extra):
#			levelnumberastext += "X";
	#levellabel.text = levelnumberastext + " - " + level_name;
	levellabel.text = level_name;
	if (level_author != "" and (level_author != "Patashu" or is_custom)):
		levellabel.text += " (By " + level_author + ")"
	if (doing_replay):
		levellabel.text += " (REPLAY)"
		if using_controller:
			var info = "";
			for i in ["replay_fwd1", "replay_back1", "replay_pause", "speedup_replay", "slowdown_replay"]:
				var next_info = human_readable_input(i, 1);
				if (next_info != "[UNBOUND]"):
					if (info != ""):
						info += "|";
					info += next_info;
			levellabel.text += " (" + info + ")";
	if save_file["levels"].has(level_name) and save_file["levels"][level_name].has("won") and save_file["levels"][level_name]["won"]:
		if (levelstar.next_modulates.size() > 0):
			# in the middle of a flash from just having won
			pass
		else:
			levelstar.modulate = Color(1, 1, 1, 1);
		var string_size = preload("res://standardfont.tres").get_string_size(levellabel.text);
		#var label_middle = levellabel.rect_position.x + int(floor(levellabel.rect_size.x / 2));
		#var string_left = label_middle - int(floor(string_size.x/2));
		#levelstar.position = Vector2(string_left-19, levellabel.rect_position.y);
	else:
		levelstar.finish_animations();
		levelstar.modulate = Color(1, 1, 1, 0);
	
func do_all_stylebox_overrides(button: Button, stylebox: StyleBox) -> void:
	button.add_stylebox_override("hover", stylebox);
	button.add_stylebox_override("pressed", stylebox);
	button.add_stylebox_override("focus", stylebox);
	button.add_stylebox_override("disabled", stylebox);
	button.add_stylebox_override("normal", stylebox);
	
func update_info_labels() -> void:
	# also disable/enable and shade verb buttons here
	if (virtualbuttons.visible):
		var meta_undo_button = virtualbuttons.get_node("Verbs/MetaUndoButton");
		var meta_undo_a_restart_type = 2;
		if (save_file.has("meta_undo_a_restart")):
			meta_undo_a_restart_type = save_file["meta_undo_a_restart"];
		if (meta_turn == 0 and (user_replay != "" or user_replay_before_restarts.size() == 0 or meta_undo_a_restart_type >= 4)):
			meta_undo_button.modulate = Color(0.5, 0.5, 0.5, 1);
		else:
			meta_undo_button.modulate = Color(1, 1, 1, 1);
		var dirs = [virtualbuttons.get_node("Dirs/LeftButton"),
		virtualbuttons.get_node("Dirs/DownButton"),
		virtualbuttons.get_node("Dirs/RightButton"),
		virtualbuttons.get_node("Dirs/UpButton")];
		var undo_button = virtualbuttons.get_node("Verbs/UndoButton");
		var unwin_button = virtualbuttons.get_node("Verbs/UnwinButton");
		if (red_turn == 0):
			undo_button.modulate = Color(0.5, 0.5, 0.5, 1);
		else:
			undo_button.modulate = Color(1.0, 1.0, 1.0, 1);
		if (blue_turn == 0):
			unwin_button.modulate = Color(0.5, 0.5, 0.5, 1);
		else:
			unwin_button.modulate = Color(1.0, 1.0, 1.0, 1);
		if player.broken:
			for button in dirs:
				button.modulate = Color(0.5, 0.5, 0.5, 1);
		else:
			for button in dirs:
				button.modulate = Color(1.0, 1.0, 1.0, 1);
#		if (heavy_selected):
#			for button in dirs:
#				button.get_node("Label").add_color_override("font_color", Color("#ff7459"));
#				do_all_stylebox_overrides(button, preload("res://heavy_styleboxtexture.tres"));
#				if (heavy_actor.broken or heavy_turn >= heavy_max_moves):
#					button.modulate = Color(0.5, 0.5, 0.5, 1);
#				else:
#					button.modulate = Color(1, 1, 1, 1);
#			undo_button.get_node("Label").add_color_override("font_color", Color("#ff7459"));
#			do_all_stylebox_overrides(undo_button, preload("res://heavy_styleboxtexture.tres"));
#			if (heavy_turn == 0):
#				undo_button.modulate = Color(0.5, 0.5, 0.5, 1);
#			else:
#				undo_button.modulate = Color(1, 1, 1, 1);
#			swap_button.get_node("Label").add_color_override("font_color", Color("#7fc9ff"));
#			do_all_stylebox_overrides(swap_button, preload("res://light_styleboxtexture.tres"));
#		else:
#			for button in dirs:
#				button.get_node("Label").add_color_override("font_color", Color("#7fc9ff"));
#				do_all_stylebox_overrides(button, preload("res://light_styleboxtexture.tres"));
#				if (light_actor.broken or light_turn >= light_max_moves):
#					button.modulate = Color(0.5, 0.5, 0.5, 1);
#				else:
#					button.modulate = Color(1, 1, 1, 1);
#			undo_button.get_node("Label").add_color_override("font_color", Color("#7fc9ff"));
#			do_all_stylebox_overrides(undo_button, preload("res://light_styleboxtexture.tres"));
#			if (light_turn == 0):
#				undo_button.modulate = Color(0.5, 0.5, 0.5, 1);
#			else:
#				undo_button.modulate = Color(1, 1, 1, 1);
#			swap_button.get_node("Label").add_color_override("font_color", Color("#ff7459"));
#			do_all_stylebox_overrides(swap_button, preload("res://heavy_styleboxtexture.tres"));
	
	metaredobutton.visible = meta_redo_inputs != "";

	metainfolabel.text = "Turn: " + str(red_turn) + " | Inputs: " + str(meta_turn);
	
	if (doing_replay):
		replaybuttons.visible = true;
		replayturnlabel.text = "Input " + str(replay_turn) + "/" + str(level_replay.length());
		replayturnsliderset = true;
		replayturnslider.max_value = level_replay.length();
		replayturnslider.value = replay_turn;
		replayturnsliderset = false;
		if (replay_paused):
			replayspeedlabel.text = "Replay Paused";
		else:
			replayspeedlabel.text = "Speed: " + "%0.2f" % (replay_interval) + "s";
	else:
		replaybuttons.visible = false;
	
	if (!is_custom):
		ready_tutorial();

func animation_substep(chrono: int) -> void:
	animation_substep += 1;
	add_undo_event([Undo.animation_substep], chrono);

func add_to_animation_server(actor: ActorBase, animation: Array, with_priority: bool = false) -> void:
	while animation_server.size() <= animation_substep:
		animation_server.push_back([]);
	if (with_priority):
		animation_server[animation_substep].push_front([actor, animation]);
	else:
		animation_server[animation_substep].push_back([actor, animation]);

func remove_one_from_animation_server(actor: ActorBase, event: int):
	for i in range(animation_server[animation_substep].size()):
		var thing = animation_server[animation_substep][i];
		if thing[0] == actor and thing[1][0] == event:
			animation_server[animation_substep].remove(i);
			return;
			
func copy_one_from_animation_server(actor: ActorBase, event: int, second_actor: ActorBase):
	for i in range(animation_server[animation_substep].size()):
		var thing = animation_server[animation_substep][i];
		if thing[0] == actor and thing[1][0] == event:
			add_to_animation_server(second_actor, thing[1], true);
			return;

func handle_global_animation(animation: Array) -> void:
	pass

func update_animation_server(skip_globals: bool = false) -> void:
	# don't interrupt ongoing animations
	for actor in actors:
		if actor.animations.size() > 0:
			return;
	
	# look for new animations to playwon_fade_started
	while animation_server.size() > 0 and animation_server[0].size() == 0:
		animation_server.pop_front();
	if animation_server.size() == 0:
		# won_fade starts here
		if ((won or lost) and !won_fade_started):
			won_fade_started = true;
			if (lost):
				fade_in_lost();
				add_to_animation_server(player, [Anim.fade, 1.0, 0.0, 3.0]);
			else:
				Shade.on = true;
				add_to_animation_server(player, [Anim.sing]);
				add_to_animation_server(player, [Anim.outro, 2.2]);
		return;
	
	# we found new animations - give them to everyone at once
	var animations = animation_server.pop_front();
	for animation in animations:
		if animation[0] == null:
			if !skip_globals:
				handle_global_animation(animation[1]);
		else:
			animation[0].animations.push_back(animation[1]);

func floating_text(text: String, reverse: bool = false) -> void:
	if (!ready_done):
		return
	var label = preload("res://FloatingText.tscn").instance();
	var existing_labels = 0;
	for i in levelscene.get_children():
		if i is FloatingText:
			existing_labels += 1;
	levelscene.add_child(label);
	label.rect_position.x = 0;
	label.rect_size.x = pixel_width;
	label.rect_position.y = pixel_height/2-16 + 8*existing_labels;
	label.text = text;
	if (reverse):
		label.rect_position.y -= 60;
		label.reversed = true;
		label.modulate = Color(1, 1, 1, 0);

func is_valid_replay(replay: String) -> bool:
	var replay_parts = replay.split("$");
	replay = replay_parts[replay_parts.size()-1];
	replay = replay.strip_edges();
	replay = replay.to_lower();
	if replay.length() <= 0:
		return false;
	for letter in replay:
		if !(letter in "wasdzxcy"):
			return false;
	return true;

func start_specific_replay(replay: String) -> void:
	var replay_parts = replay.split("$");
	replay = replay_parts[replay_parts.size()-1];
	replay = replay.strip_edges();
	replay = replay.to_lower();
	if (!is_valid_replay(replay)):
		floating_text("Ctrl+V: Invalid replay");
		return;
	end_replay();
	toggle_replay();
	level_replay = replay;
	if (level_replay.find("c") >= 0):
		voidlike_puzzle = true;
	update_info_labels();

func user_pressed_toggle_replay() -> void:
	meta_undo_a_restart_mode = false;
	unit_test_mode = false;
	if (doing_replay):
		end_replay();
		update_info_labels();
		return;
	if (!level_replay.begins_with(user_replay)):
		level_replay = user_replay;
	doing_replay = true;
	replaybuttons.visible = true;
	replay_paused = true;
	replay_turn = user_replay.length();
	update_info_labels();

func start_saved_replay() -> void:
	if (doing_replay):
		end_replay();
		return;
	
	var levels_save_data = save_file["levels"];
	if (!levels_save_data.has(level_name)):
		floating_text("F11: Level not beaten");
		return;
	var level_save_data = levels_save_data[level_name];
	if (!level_save_data.has("replay")):
		floating_text("F11: Level not beaten");
		return;
	var replay = level_save_data["replay"];
	start_specific_replay(replay);

func annotate_replay(replay: String) -> String:
	return level_name + "$" + "mturn=" + str(meta_turn) + "$" + replay;

func get_afterimage_material_for(color: Color) -> Material:
	if (afterimage_server.has(color)):
		return afterimage_server[color];
	var new_material = preload("res://afterimage_shadermaterial.tres").duplicate();
	new_material.set_shader_param("color", color);
	afterimage_server[color] = new_material;
	return new_material;

func afterimage(actor: Actor) -> void:
	if (currently_fast_replay()):
		return;
	if undo_effect_color == Color.transparent:
		return;
	# ok, we're mid undo.
	var afterimage = preload("res://Afterimage.tscn").instance();
	afterimage.actor = actor;
	afterimage.set_material(get_afterimage_material_for(undo_effect_color));
	underactorsparticles.add_child(afterimage);
	
func afterimage_terrain(texture: Texture, position: Vector2, color: Color) -> Node2D:
	if (currently_fast_replay()):
		return null;
	var afterimage = preload("res://Afterimage.tscn").instance();
	afterimage.texture = texture;
	afterimage.position = position;
	afterimage.set_material(get_afterimage_material_for(color));
	overactorsparticles.add_child(afterimage);
	return afterimage;
		
func last_level_of_section() -> bool:
	var chapter_standard_starting_level = chapter_standard_starting_levels[chapter+1];
	var chapter_advanced_starting_level = chapter_advanced_starting_levels[chapter];
	if (level_number+1 == chapter_standard_starting_level or level_number+1 == chapter_advanced_starting_level):
		return true;
	return false;
		
func unwin() -> void:
	floating_text("Ctrl+F11: Unwin");
	if (save_file["levels"].has(level_name) and save_file["levels"][level_name].has("won") and save_file["levels"][level_name]["won"]):
		puzzles_completed -= 1;
	if (save_file["levels"].has(level_name)):
		save_file["levels"][level_name]["won"] = false;
	save_game();
	update_level_label();
	
func adjusted_mouse_position() -> Vector2:
	var result = get_parent().get_global_mouse_position();
	if (SuperScaling != null):
		result.x *= 2*pixel_width/OS.get_window_size().x;
		result.y *= 2*pixel_height/OS.get_window_size().y;
	return result;

func any_ui_element_hovered(mouse_position: Vector2) -> bool:
	return any_ui_element_hovered_core(menubutton, mouse_position) or any_ui_element_hovered_core(replaybuttons, mouse_position) or any_ui_element_hovered_core(virtualbuttons, mouse_position);

func any_ui_element_hovered_core(node, mouse_position: Vector2) -> bool:
	if !node.visible:
		return false;
	if node is BaseButton or node is Range:
		var rect = Rect2(node.rect_global_position, node.rect_size);
		if rect.has_point(mouse_position):
			return true;
	for child in node.get_children():
		var result = any_ui_element_hovered_core(child, mouse_position);
		if (result):
			return true;
	return false;
	
func _input(event: InputEvent) -> void:
	if (ui_stack.size() > 0):
		return;
	
	if event is InputEventMouseButton:
		replayturnslider.release_focus();
		replayspeedslider.release_focus();
	elif event is InputEventKey:
		if (!is_web and event.alt and event.scancode == KEY_ENTER):
			if (!save_file.has("fullscreen") or !save_file["fullscreen"]):
				save_file["fullscreen"] = true;
			else:
				save_file["fullscreen"] = false;
			setup_resolution();

func gain_insight() -> void:
	if (ui_stack.size() > 0):
		return;
	
	if (has_insight_level and !unit_test_mode):
		if (!save_file.has("gain_insight") or save_file["gain_insight"] != true):
			var modal = preload("res://GainInsightModalPrompt.tscn").instance();
			add_to_ui_stack(modal);
			return;
	
	if (has_insight_level):
		end_replay(); #not sure why Unwin needs this but ET didn't?
		if (in_insight_level):
			in_insight_level = false;
		else:
			in_insight_level = true;
		level_replay = "";
		load_level(0);
		cut_sound();
		play_sound("usegreenality");
		undo_effect_strength = 0.5;
		undo_effect_per_second = undo_effect_strength*(1/0.5);
		finish_animations(Chrono.TIMELESS);
		undo_effect_color = meta_color;

func serialize_current_level() -> String:
	if (is_custom):
		return custom_string;
	
	# keep in sync with LevelEditor.gd serialize_current_level()
	var result = "UnwinPuzzleStart: " + level_name + " by " + level_author + "\n";
	var level_metadata = {};
	var metadatas = ["level_name", "level_author", #"level_replay",
	"map_x_max", "map_y_max", 
	];
	for metadata in metadatas:
		level_metadata[metadata] = self.get(metadata);
	level_metadata["target_sky"] = target_sky.to_html(false);
	
	# we now have to grab the original values for: terrain_layers, heavy_max_moves, light_max_moves
	# has to be kept in sync with load_level/ready_map and any custom level logic we end up adding
	var level = null;
	if (has_insight_level and in_insight_level and insight_level_scene != null):
		level = insight_level_scene.instance();
	else:
		level = level_list[level_number].instance();
		
	var level_info = level.get_node("LevelInfo");
	level_metadata["level_replay"] = level_info.level_replay;
		
	var layers = [];
	layers.append(level);
	for child in level.get_children():
		if child is TileMap:
			layers.push_front(child);
			
	level_metadata["layers"] = layers.size();
			
	result += to_json(level_metadata);
	
	for i in layers.size():
		result += "\nLAYER " + str(i) + ":\n";
		var layer = layers[layers.size() - 1 - i];
		for y in range(map_y_max+1):
			for x in range(map_x_max+1):
				if (x > 0):
					result += ",";
				var tile = layer.get_cell(x, y);
				if tile >= 0 and tile <= 9:
					result += "0" + str(tile);
				else:
					result += str(tile);
			result += "\n";
	
	result += "UnwinPuzzleEnd"
	level.queue_free();
	return result.split("\n").join("`\n");
	
func copy_level() -> void:
	var result = serialize_current_level();
	floating_text("Ctrl+Shift+C: Level copied to clipboard!");
	OS.set_clipboard(result);
	
func looks_like_level(custom: String) -> bool:
	custom = custom.strip_edges();
	if custom.find("UnwinPuzzleStart") >= 0 and custom.find("UnwinPuzzleEnd") >= 0:
		return true;
	return false;
	
func deserialize_custom_level(custom: String) -> Node:
	custom = custom.strip_edges();
	if custom.find("\n") >= 0:
		custom = custom.replace("`", "");
	else:
		custom = custom.replace("`", "\n");
	
	var lines = custom.split("\n");
	for i in range(lines.size()):
		lines[i] = lines[i].strip_edges();
	
	if (lines[0].find("UnwinPuzzleStart") == -1):
		floating_text("Assert failed: Line 1 should start UnwinPuzzleStart");
		return null;
	if (lines[(lines.size() - 1)] != "UnwinPuzzleEnd"):
		floating_text("Assert failed: Last line should be UnwinPuzzleEnd");
		return null;
	var json_parse_result = JSON.parse(lines[1])
	
	var result = null;
	
	if json_parse_result.error == OK:
		var data = json_parse_result.result;
		if typeof(data) == TYPE_DICTIONARY:
			result = data;
	
	if (result == null):
		floating_text("Assert failed: Line 2 should be a valid dictionary")
		return null;
	
	var metadatas = ["level_name", "level_author", "level_replay",
	"map_x_max", "map_y_max", "target_sky", "layers",];
	
	for metadata in metadatas:
		if (!result.has(metadata)):
			floating_text("Assert failed: Line 2 is missing " + metadata);
			return null;
	
	var layers = result["layers"];
	var xx = 2;
	var xxx = result["map_y_max"] + 1 + 1 + 1; #1 for the header, 1 for the off-by-one, 1 for the blank line
	var terrain_layers = [];
	var terrainmap = null;
	for i in range(layers):
		var tile_map = TileMap.new();
		tile_map.tile_set = preload("res://DefaultTiles.tres");
		tile_map.cell_size = Vector2(cell_size, cell_size);
		var a = xx + xxx*i;
		var header = lines[a];
		if (header != "LAYER " + str(i) + ":"):
			floating_text("Assert failed: Line " + str(a) + " should be 'LAYER " + str(i) + ":'.");
			return null;
		for j in range(result["map_y_max"] + 1):
			var layer_line = lines[a + 1 + j];
			var layer_cells = layer_line.split(",");
			for k in range(layer_cells.size()):
				var layer_cell = layer_cells[k];
				tile_map.set_cell(k, j, int(layer_cell));
		terrain_layers.append(tile_map);
		tile_map.update_bitmask_region();
	terrainmap = terrain_layers[0];
	for i in range(layers - 1):
		terrainmap.add_child(terrain_layers[i + 1]);
	
	var level_info = Node.new();
	level_info.set_script(preload("res://levels/LevelInfo.gd"));
	level_info.name = "LevelInfo";
	for metadata in metadatas:
		level_info.set(metadata, result[metadata]);
	terrainmap.add_child(level_info);
			
	return terrainmap;
	
func load_custom_level(custom: String) -> void:
	var level = deserialize_custom_level(custom);
	if level == null:
		return;
	
	tutorial_complete();
	
	is_custom = true;
	in_insight_level = false;
	custom_string = custom;
	var level_info = level.get_node("LevelInfo");
	level_name = level_info["level_name"];
	level_author = level_info["level_author"];
	level_replay = level_info["level_replay"];
	map_x_max = int(level_info["map_x_max"]);
	map_y_max = int(level_info["map_y_max"]);
	sky_timer = 0;
	sky_timer_max = 3.0;
	old_sky = current_sky;
	target_sky = Color(level_info["target_sky"]);
	
	levelfolder.remove_child(terrainmap);
	terrainmap.queue_free();
	levelfolder.add_child(level);
	terrainmap = level;
	terrain_layers.clear();
	terrain_layers.append(terrainmap);
	for child in terrainmap.get_children():
		if child is TileMap:
			terrain_layers.push_front(child);
	
	ready_map();
	
func give_up_and_restart() -> void:
	is_custom = false;
	custom_string = "";
	restart();
	
func paste_level(clipboard: String) -> void:
	clipboard = clipboard.strip_edges();
	end_replay();
	load_custom_level(clipboard);
	
func adjust_next_replay_time(old_replay_interval: float) -> void:
	next_replay += replay_interval - old_replay_interval;
	
var virtual_button_name_to_action = {};
	
func shade_virtual_button(b: Button) -> void:
	var label = b.get_node_or_null("Label");
	if (label == null):
		return;
	if (b.name == "PauseButton"):
		if replay_paused:
			label.text = "|>";
		else:
			label.text = "||";
	if (Input.is_action_just_pressed(virtual_button_name_to_action[b.name])):
		label.modulate = Color(1.5, 1.5, 1.5, 1);
		return;
	elif (Input.is_action_pressed(virtual_button_name_to_action[b.name])):
		label.modulate = Color(0.8, 0.8, 0.8, 1);
		return;
	var draw_mode = b.get_draw_mode();
	if draw_mode == 0:
		label.modulate = Color(1, 1, 1, 1);
	elif draw_mode == 1 or draw_mode == 3:
		label.modulate = Color(0.5, 0.5, 0.5, 1);
	elif draw_mode == 2 or draw_mode == 4:
		if (Input.is_mouse_button_pressed(1)):
			label.modulate = Color(0.8, 0.8, 0.8, 1);
		else:
			label.modulate = Color(1.5, 1.5, 1.5, 1);
	
func shade_virtual_buttons() -> void:
	if (virtualbuttons.visible):
		for a in virtualbuttons.get_children():
			for b in a.get_children():
				if (b is Button):
					shade_virtual_button(b);
	if (replaybuttons.visible):
		for a in replaybuttons.get_children():
			for b in a.get_children():
				if (b is Button):
					shade_virtual_button(b);
	
var last_dir_release_times = [0, 0, 0, 0];
var key_repeat_timer_dict = {};
var key_repeat_timer_max_dict = {};
var virtual_button_held_dict = {"meta_undo": false, "meta_redo": false,
"character_undo": false,
"ui_left": false, "ui_right": false, "ui_up": false, "ui_down": false,
"replay_back1": false, "replay_fwd1": false, "speedup_replay": false, "slowdown_replay": false};
var key_repeat_this_frame_dict = {};
var most_recent_direction_held = "";
var covered_cooldown_timer = 0.0;
var no_mute_pwease = false;
var just_key_repeated_a_dir_cooldown_timer = 0.0;
	
func pressed_or_key_repeated(action: String) -> bool:
	return Input.is_action_just_pressed(action) or (key_repeat_this_frame_dict.has(action) and key_repeat_this_frame_dict[action]);
	
func _process(delta: float) -> void:
	shade_virtual_buttons();
	var will_set_just_key_repeated_a_dir_cooldown_timer = false;
	
	# key repeat
	just_key_repeated_a_dir_cooldown_timer -= delta;
	for action in virtual_button_held_dict.keys():
		var is_dir = action.find("ui_") == 0;
		if (Input.is_action_just_pressed(action)):
			key_repeat_timer_dict[action] = 0.0;
			if (is_dir):
				key_repeat_timer_max_dict[action] = 0.19;
				most_recent_direction_held = action;
			else:
				key_repeat_timer_max_dict[action] = 0.5;
			key_repeat_this_frame_dict[action] = false;
		if (Input.is_action_pressed(action) or virtual_button_held_dict[action]) and (!is_dir or action == most_recent_direction_held or most_recent_direction_held == ""):
			key_repeat_this_frame_dict[action] = false;
			key_repeat_timer_dict[action] += delta;
			if (key_repeat_timer_dict[action] > key_repeat_timer_max_dict[action]):
				key_repeat_this_frame_dict[action] = true;
				if (is_dir):
					# we basically want to solve the following:
					# If we're key repeating in a direction, and then tap another direction,
					# we don't want it to happen too quickly (feels like we moved on consecutive frames)
					# but we also don't want to wait the full maximum of 0.2 seconds in such a case (feels too sluggish)
					# so let's try this: we'll prevent an input within 0.05 seconds but it will happen immediately after if still held.)
					will_set_just_key_repeated_a_dir_cooldown_timer = true;
					if (just_key_repeated_a_dir_cooldown_timer > 0.0 and key_repeat_timer_dict[action] < 0.10):
						key_repeat_timer_dict[action] = 0.19 - just_key_repeated_a_dir_cooldown_timer;
				key_repeat_timer_dict[action] -= key_repeat_timer_max_dict[action];
				if (key_repeat_timer_max_dict[action] == 0.5):
					key_repeat_timer_max_dict[action] = 0.19;
				elif !is_dir:
					key_repeat_timer_max_dict[action] = max(0.05, key_repeat_timer_max_dict[action] * 0.91);
				else:
					key_repeat_timer_max_dict[action] = 0.19;
		else:
			if (most_recent_direction_held == action):
				most_recent_direction_held = "";
			key_repeat_timer_dict[action] = 0.0;
			key_repeat_timer_max_dict[action] = 0.0;
			key_repeat_this_frame_dict[action] = false;
	
	if (Input.is_action_just_pressed("any_controller") or Input.is_action_just_pressed("any_controller_2")) and !using_controller:
		using_controller = true;
		menubutton.text = "Menu (" + human_readable_input("escape", 1).left(5) + ")";
		menubutton.rect_position.x = 222;
		update_info_labels();
	
	if Input.is_action_just_pressed("any_keyboard") and using_controller:
		using_controller = false;
		menubutton.text = "Menu (" + human_readable_input("escape", 1).left(3) + ")";
		menubutton.rect_position.x = 226;
		menubutton.rect_size.x = 60;
		update_info_labels();
	
	#hysteresis: dynamically update dead zone based on if a direction is currently held or not
	#(this should happen even when ui_stack is filled so it applies to menus as well)
	#debouncing: if the player uses a controller to re-press a direction within (debounce_ms) ms,
	#allow it but in gameplay code ignore movement this frame
	#(this means debouncing doesn't work in menus since I don't control focus logic.)
	#(maybe it's somehow possible another way?)
	var get_debounced = false;
	if (using_controller):
		if (!save_file.has("deadzone")):
			save_file["deadzone"] = InputMap.action_get_deadzone("ui_up");
		if (!save_file.has("debounce")):
			save_file["debounce"] = 40;
		
		var normal = save_file["deadzone"];
		var debounce_ms = save_file["debounce"];
		var held = normal*0.95;
		var dirs = ["ui_up", "ui_down", "ui_left", "ui_right"];
		for i in range(dirs.size()):
			
			var dir = dirs[i];
			var current_time = Time.get_ticks_msec();
			
			if Input.is_action_just_pressed(dir):
				if ((current_time - debounce_ms) < last_dir_release_times[i]):
					get_debounced = true;
					#floating_text("get debounced " + str(int(current_time - last_dir_release_times[i])) + "ms");
			elif Input.is_action_just_released(dir):
				last_dir_release_times[i] = current_time;
				
			if Input.is_action_pressed(dir):
				InputMap.action_set_deadzone(dir, held);
			else:
				InputMap.action_set_deadzone(dir, normal);
				
		#tutoriallabel.text = str(Input.get_action_raw_strength("ui_up"));
			
	sounds_played_this_frame.clear();
	
	if (won):
		won_cooldown += delta;
	
	if (doing_replay and !replay_paused):
		replay_timer += delta;
		
	# handle current music volume
	var value = save_file["music_volume"];
	var master_volume = save_file["master_volume"];
	if (value <= -30 or master_volume <= -30):
		if (!music_speaker.stream_paused):
			music_speaker.stream_paused = true;
	elif !muted:
		if (music_speaker.stream_paused):
			music_speaker.stream_paused = false;
	music_speaker.volume_db = value + master_volume + music_discount;
	if (current_track >= 0):
		music_speaker.volume_db += music_db[current_track];
	if fadeout_timer < fadeout_timer_max:
		fadeout_timer += delta;
		if (fadeout_timer >= fadeout_timer_max):
			play_next_song();
			# recalculate this now because the current song just changed...
			music_speaker.volume_db = value + master_volume +music_discount;
			if (current_track >= 0):
				music_speaker.volume_db += music_db[current_track];
		else:
			music_speaker.volume_db = music_speaker.volume_db - 30*(fadeout_timer/fadeout_timer_max);
		
	# duck when a fanfare is playing. this might need tweaking...
	var new_fanfare_duck_db = 0;
	if (lost_speaker.playing and lost_speaker.volume_db > -30):
		new_fanfare_duck_db += lost_speaker.volume_db + 30;
	if (won_speaker.playing and won_speaker.volume_db > -30):
		new_fanfare_duck_db += won_speaker.volume_db + 10; # try ducking less for won
	if (new_fanfare_duck_db > 0):
		fanfare_duck_db = new_fanfare_duck_db;
	else:
		fanfare_duck_db -= delta*100;
	if (fanfare_duck_db < 0):
		fanfare_duck_db = 0;
	music_speaker.volume_db = music_speaker.volume_db - fanfare_duck_db;
	
	#starticipation - most recently won star(s) sparkle subtly
	starticipation_timer += delta;
	if (starticipation_timer > starticipation_timer_max):
		starticipation_timer -= starticipation_timer_max;
		if (blue_turn > 0):
			var buffer = blue_undo_buffer[blue_turn - 1];
			for event in buffer:
				if event[0] == Undo.set_actor_var:
					var star = event[1];
					var c = Color("A7A79E");
					# one sparkle, slightly different position logic
					var sprite = Sprite.new();
					sprite.set_script(preload("res://FadingSprite.gd"));
					sprite.texture = preload("res://assets/Sparkle.png")
					sprite.position = star.offset + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6));
					sprite.centered = true;
					sprite.scale = Vector2(0.25, 0.25);
					sprite.modulate = c;
					star.add_child(sprite)
	
	if (sky_timer < sky_timer_max):
		sky_timer += delta;
		if (sky_timer > sky_timer_max):
			sky_timer = sky_timer_max;
		# rgb lerp (I tried hsv lerp but the hue changing feels super nonlinear)
		var current_r = lerp(old_sky.r, target_sky.r, sky_timer/sky_timer_max);
		var current_g = lerp(old_sky.g, target_sky.g, sky_timer/sky_timer_max);
		var current_b = lerp(old_sky.b, target_sky.b, sky_timer/sky_timer_max);
		current_sky = Color(current_r, current_g, current_b);
		VisualServer.set_default_clear_color(current_sky);
		
	# allow mute to happen even when in menus
	if (Input.is_action_just_pressed("mute") and !no_mute_pwease):
		# hack: no muting in LevelInfoEdit where the player might type M
		if (ui_stack.size() == 0 or ui_stack[ui_stack.size() -1].name != "LevelInfoEdit"):
			toggle_mute();
	
	if (ui_stack.size() > 0):
		covered_cooldown_timer = 2.0;
	elif covered_cooldown_timer > 0.0:
		covered_cooldown_timer -= 1.0;
	
	if ui_stack.size() == 0 and covered_cooldown_timer <= 0.0:
		var dir = Vector2.ZERO;
		
		if (doing_replay and replay_timer > next_replay and !replay_paused):
			do_one_replay_turn();
			update_info_labels();
		
		if (won and Input.is_action_just_pressed("ui_accept")):
			# only thing you really can do for a one puzzle game
			if (in_insight_level):
				gain_insight();
			else:
				start_saved_replay();
			update_info_labels();
		elif (Input.is_action_just_pressed("escape")):
			#end_replay(); #done in escape();
			escape();
		elif (Input.is_action_just_pressed("toggle_replay")):
			user_pressed_toggle_replay();
		elif (doing_replay and pressed_or_key_repeated("replay_back1")):
			replay_advance_turn(-1);
		elif (doing_replay and pressed_or_key_repeated("replay_fwd1")):
			replay_advance_turn(1);
		elif (doing_replay and Input.is_action_just_pressed("replay_pause")):
			pause_replay();
		elif (pressed_or_key_repeated("speedup_replay")):
			var old_replay_interval = replay_interval;
			if (Input.is_action_pressed("shift")):
				replay_interval = 0.015;
			else:
				replay_interval *= (2.0/3.0);
			replayspeedsliderset = true;
			replayspeedslider.value = 100 - floor(replay_interval * 100);
			replayspeedsliderset = false;
			adjust_next_replay_time(old_replay_interval);
			update_info_labels();
		elif (pressed_or_key_repeated("slowdown_replay")):
			var old_replay_interval = replay_interval;
			if (Input.is_action_pressed("shift")):
				replay_interval = 0.5;
			elif replay_interval < 0.015:
				replay_interval = 0.015;
			else:
				replay_interval /= (2.0/3.0);
			if (replay_interval > 2.0):
				replay_interval = 2.0;
			replayspeedsliderset = true;
			replayspeedslider.value = 100 - floor(replay_interval * 100);
			replayspeedsliderset = false;
			adjust_next_replay_time(old_replay_interval);
			update_info_labels();
		elif (Input.is_action_just_pressed("start_saved_replay")):
			if (Input.is_action_pressed("shift")):
				# must be kept in sync with Menu
				if (user_replay != ""):
					if (!save_file["levels"].has(level_name)):
						save_file["levels"][level_name] = {};
					save_file["levels"][level_name]["replay"] = annotate_replay(user_replay);
					save_game();
					floating_text("Shift+F11: Replay force saved!");
			elif (Input.is_action_pressed("ctrl")):
				unwin();
			else:
				# must be kept in sync with Menu
				start_saved_replay();
				update_info_labels();
		elif (Input.is_action_just_pressed("start_replay")):
			# must be kept in sync with Menu
			authors_replay();
			update_info_labels();
		elif (Input.is_action_pressed("ctrl") and Input.is_action_just_pressed("copy")):
			if (Input.is_action_pressed("shift")):
				copy_level();
			else:
				# must be kept in sync with Menu
				if (len(user_replay) > 0):
					OS.set_clipboard(annotate_replay(user_replay));
					floating_text("Ctrl+C: Replay copied");
				else:
					floating_text("Ctrl+C: Make some moves first!");
		elif (Input.is_action_pressed("ctrl") and Input.is_action_just_pressed("paste")):
			# must be kept in sync with Menu
			var clipboard = OS.get_clipboard();
			if (looks_like_level(clipboard)):
				paste_level(clipboard);
			else:
				start_specific_replay(clipboard);
		elif (pressed_or_key_repeated("character_undo")):
			end_replay();
			character_undo();
			update_info_labels();
		elif (pressed_or_key_repeated("meta_undo")):
			end_replay();
			meta_undo();
			update_info_labels();
		elif (pressed_or_key_repeated("meta_redo")):
			end_replay();
			meta_redo();
			update_info_labels();
		elif (Input.is_action_just_pressed("restart")):
			# must be kept in sync with Menu "restart"
			end_replay();
			restart();
			update_info_labels();
		elif (pressed_or_key_repeated("character_unwin")):
			end_replay();
			character_unwin();
			update_info_labels();
		elif (Input.is_action_just_pressed("ui_accept")): #so enter can open the menu but only if it's closed
			#end_replay(); #done in escape();
			escape();
		elif (!get_debounced and just_key_repeated_a_dir_cooldown_timer <= 0.0):
			# and !replayspeedslider.has_focus() and !replayturnslider.has_focus()
			# (not necessary right now as they auto-unfocus in _input)
			if (pressed_or_key_repeated("ui_left") or pressed_or_key_repeated("nonaxis_left")):
				dir = Vector2.LEFT;
			if (pressed_or_key_repeated("ui_right") or pressed_or_key_repeated("nonaxis_right")):
				dir = Vector2.RIGHT;
			if (pressed_or_key_repeated("ui_up") or pressed_or_key_repeated("nonaxis_up")):
				dir = Vector2.UP;
			if (pressed_or_key_repeated("ui_down") or pressed_or_key_repeated("nonaxis_down")):
				dir = Vector2.DOWN;
				
			if dir != Vector2.ZERO:
				end_replay();
				character_move(dir);
				update_info_labels();
		
	update_targeter();
	update_animation_server();
	if (will_set_just_key_repeated_a_dir_cooldown_timer):
		just_key_repeated_a_dir_cooldown_timer = 0.049;

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_FOCUS_OUT:
			if (save_file.has("mute_in_background") and save_file["mute_in_background"]):
				AudioServer.set_bus_mute(0, true) # 0 = master bus, probably
		NOTIFICATION_WM_FOCUS_IN:
			AudioServer.set_bus_mute(0, false)
