extends Node2D
class_name LevelEditor

# keep in sync with GameLogic
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

onready var gamelogic = get_tree().get_root().find_node("LevelScene", true, false).gamelogic;
onready var menubutton : Button = get_node("MenuButton");
onready var tilemaps : Node2D = get_node("TileMaps");
onready var pen : Sprite = get_node("Pen");
onready var pickerbackground : ColorRect = get_node("PickerBackground");
onready var picker : TileMap = get_node("Picker");
onready var pickertooltip : Node2D = get_node("PickerTooltip");
onready var layerlabel : Label = get_node("LayerLabel");
onready var searchbox : LineEdit = get_node("Picker/SearchBox");
var custom_string = "";
var level_info : LevelInfo = null;
var pen_tile = Tiles.Wall;
var pen_layer = 0;
var terrain_layers = [];
var pen_xy = Vector2.ZERO;
var picker_mode = false;
var picker_array = [];
var just_picked = false;
var show_tooltips = false;
var searchbox_has_mouse = false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menubutton.connect("pressed", self, "_menubutton_pressed");
	searchbox.connect("focus_entered", self, "_searchbox_focus_entered");
	searchbox.connect("focus_exited", self, "_searchbox_focus_exited");
	searchbox.connect("text_changed", self, "_searchbox_text_changed");
	searchbox.connect("text_entered", self, "_searchbox_text_entered");
	searchbox.connect("mouse_entered", self, "_searchbox_mouse_entered");
	searchbox.connect("mouse_exited", self, "_searchbox_mouse_exited");
	
	gamelogic.tile_changes(true);
	
	if (gamelogic.test_mode):
		custom_string = gamelogic.custom_string;
		gamelogic.test_mode = false;
	else:
		custom_string = gamelogic.serialize_current_level();
	deserialize_custom_level(custom_string);
	if (gamelogic.test_mode):
		var test_level_info = gamelogic.terrainmap.get_node_or_null("LevelInfo");
		if (test_level_info != null and test_level_info.level_replay != null and test_level_info.level_replay != ""):
			level_info.level_replay = test_level_info.level_replay;
			
	change_pen_tile(); # must happen after level setup
	
	initialize_picker_array();
	pickertooltip.squish_mode();
	
	for sl in pickertooltip.shadow_labels:
		sl.add_color_override("font_color_shadow", Color(0, 0, 0, 1));
		sl.add_constant_override("shadow_offset_x", 1)
		sl.add_constant_override("shadow_offset_y", 1)
	
func _searchbox_focus_entered() -> void:
	searchbox.text = "";
	searchbox.editable = true;
	gamelogic.no_mute_pwease = true;
	search_picker("");
	
func _searchbox_focus_exited() -> void:
	searchbox.text = "Search...";
	searchbox.editable = false;
	gamelogic.no_mute_pwease = false;
	search_picker("");
	
func _searchbox_text_changed(new_text: String) -> void:
	if (searchbox.editable):
		search_picker(searchbox.text);
	else:
		search_picker("");
	
func search_picker(text: String) -> void:
	text = text.to_lower();
	for i in range(picker_array.size()):
		var x = i % 21;
		var y = i / 21;
		var tile = picker_array[i];
		if ((text == "") or text in tooltip_for_tile(tile).to_lower()):
			picker.set_cellv(Vector2(x, y), tile);
		else:
			picker.set_cellv(Vector2(x, y), -1);
	picker.update_bitmask_region();
	
func _searchbox_text_entered(new_text: String) -> void:
	pass
	
func _searchbox_mouse_entered() -> void:
	searchbox_has_mouse = true;

func _searchbox_mouse_exited() -> void:
	searchbox_has_mouse = false;
	
func initialize_picker_array() -> void:
	# always true now
	show_tooltips = true;
		
	picker_array.append(-1);
	picker_array.append(Tiles.Floor);
	picker_array.append(Tiles.Wall);
	picker_array.append(Tiles.Player);
	picker_array.append(Tiles.Win);
	picker_array.append(Tiles.Star);
	picker_array.append(Tiles.DirtBlock);
	picker_array.append(Tiles.IceBlock);
	picker_array.append(Tiles.Hole);
	picker_array.append(Tiles.BottomlessPit);
	picker_array.append(Tiles.Water);
	picker_array.append(Tiles.Ice);
	picker_array.append(Tiles.MagicBarrier);
	picker_array.append(Tiles.CrackedStar);
	picker_array.append(Tiles.DarkStar);
	picker_array.append(Tiles.GreenAura);
	picker_array.append(Tiles.OneWayWest);
	picker_array.append(Tiles.OneWaySouth);
	picker_array.append(Tiles.OneWayNorth);
	picker_array.append(Tiles.OneWayEast);
	
	for i in range(picker_array.size()):
		var x = i % 21;
		var y = i / 21;
		picker.set_cellv(Vector2(x, y), picker_array[i]);
	picker.update_bitmask_region();

func deserialize_custom_level(custom_string: String) -> void:
	var level = gamelogic.deserialize_custom_level(custom_string);
	if (level == null):
		floating_text("Invalid level")
		return;
	
	for child in tilemaps.get_children():
		tilemaps.remove_child(child);
		child.queue_free();
	terrain_layers.clear();
	
	tilemaps.add_child(level);
	level_info = level.get_node("LevelInfo");
	
	if (level_info.map_x_max > gamelogic.map_x_max_max or level_info.map_y_max > gamelogic.map_y_max_max+2):
		if (tilemaps.scale == Vector2(1, 1)):
			toggle_zoom();

	terrain_layers.append(level);
	for child in level.get_children():
		if child is TileMap:
			terrain_layers.push_front(child);
			level.remove_child(child);
			tilemaps.add_child(child);
	change_layer(0);

func serialize_current_level() -> String:
	# keep in sync with GameLogic.gd serialize_current_level()
	
	# 0) change to layer 0 just in case of weirdness
	change_layer(0);
	
	# 1) trim empty layers
	#var new_array = [];
	var empties = [];
	for layer in terrain_layers:
		if layer.get_used_cells().size() > 0:
			#new_array.append(layer);
			pass
		else:
			empties.append(layer);
	if (empties.size() == terrain_layers.size()):
		floating_text("It's empty, Jim.")
		return "";
	for layer in empties:
		terrain_layers.erase(layer);
		layer.get_parent().remove_child(layer);
		layer.queue_free();
	
	# 2) trim tiles at negative co-ordinates
	for layer in terrain_layers:
		var cells = layer.get_used_cells();
		for cell in cells:
			if cell.x < 0 or cell.y < 0:
				layer.set_cellv(cell, -1);
	
	# 3) squash horizontally and vertically
	var min_x = 999999;
	var min_y = 999999;
	for layer in terrain_layers:
		var rect = layer.get_used_rect();
		min_x = min(rect.position.x, min_x);
		min_y = min(rect.position.y, min_y);
	shift_all_layers(Vector2(-min_x, -min_y));
	
	# 4) set map_x_max and map_y_max
	level_info.map_x_max = 0;
	level_info.map_y_max = 0;
	for layer in terrain_layers:
		var rect = layer.get_used_rect();
		level_info.map_x_max = max(level_info.map_x_max, rect.size.x + rect.position.x - 1);
		level_info.map_y_max = max(level_info.map_y_max, rect.size.y + rect.position.y - 1);

	var result = "UnwinPuzzleStart: " + level_info.level_name + " by " + level_info.level_author + "\n";
	var level_metadata = {};
	var metadatas = ["level_name", "level_author", "level_replay",
	"map_x_max", "map_y_max", #"target_sky"
	];
	for metadata in metadatas:
		level_metadata[metadata] = level_info.get(metadata);
	level_metadata["target_sky"] = level_info.target_sky.to_html(false);
		
	var layers = terrain_layers;
			
	level_metadata["layers"] = layers.size();
			
	result += to_json(level_metadata);
	
	for i in layers.size():
		result += "\nLAYER " + str(i) + ":\n";
		var layer = layers[layers.size() - 1 - i];
		for y in range(level_metadata["map_y_max"]+1):
			for x in range(level_metadata["map_x_max"]+1):
				if (x > 0):
					result += ",";
				var tile = layer.get_cell(x, y);
				if tile >= 0 and tile <= 9:
					result += "0" + str(tile);
				else:
					result += str(tile);
			result += "\n";
	
	result += "UnwinPuzzleEnd"
	return result.split("\n").join("`\n");

func copy_level() -> void:
	var result = serialize_current_level();
	if (result != ""):
		floating_text("Ctrl+C: Level copied to clipboard!");
		OS.set_clipboard(result);
		
func save_as_tscn() -> void:
	var a = serialize_current_level();
	if (a != ""):
		var deserialized = gamelogic.deserialize_custom_level(a);
		for node in deserialized.get_children():
			node.owner = deserialized
			
		var scene = PackedScene.new();
		var result = scene.pack(deserialized)
		
		if result == OK:
			var path = "res://levels/custom/" + level_info.level_name.replace("?", "-").replace(":", "-") + ".tscn";
			var error = ResourceSaver.save(path, scene);
			if error != OK:
				floating_text("An error occurred while saving the scene to disk.")
			else:
				floating_text("Saved to " + path);
		deserialized.queue_free();
	
func paste_level() -> void:
	var clipboard = OS.get_clipboard();
	if (!gamelogic.looks_like_level(clipboard)):
		floating_text("Ctrl+V: Invalid level");
		return
	else:
		deserialize_custom_level(clipboard);
		floating_text("Ctrl+V: Level pasted from clipboard!");

func new_level() -> void:
	change_layer(0);
	for layer in terrain_layers:
		layer.clear();
	floating_text("Level reset");

func shift_all_layers(shift: Vector2) -> void:
	for layer in terrain_layers:
		shift_layer(layer, shift);
		
func shift_layer(layer: TileMap, shift: Vector2) -> void:
	var rect = null;
	# do x shift
	
	if (shift.x < 0):
		rect = layer.get_used_rect();
		for i in range(rect.size.x):
			var x = rect.position.x + i;
			for j in range(rect.size.y):
				var y = rect.position.y + j;
				layer.set_cellv(Vector2(x+shift.x, y), layer.get_cellv(Vector2(x, y)));
				layer.update_bitmask_area(Vector2(x+shift.x, y));
				layer.set_cellv(Vector2(x, y), -1);
				layer.update_bitmask_area(Vector2(x, y));
	elif (shift.x > 0):
		rect = layer.get_used_rect();
		for i in range(rect.size.x):
			var x = rect.position.x + rect.size.x - 1 - i;
			for j in range(rect.size.y):
				var y = rect.position.y + j;
				layer.set_cellv(Vector2(x+shift.x, y), layer.get_cellv(Vector2(x, y)));
				layer.update_bitmask_area(Vector2(x+shift.x, y));
				layer.set_cellv(Vector2(x, y), -1);
				layer.update_bitmask_area(Vector2(x, y));
	
	# do y shift
	if (shift.y < 0):
		rect = layer.get_used_rect();
		for i in range(rect.size.x):
			var x = rect.position.x + i;
			for j in range(rect.size.y):
				var y = rect.position.y + j;
				layer.set_cellv(Vector2(x, y+shift.y), layer.get_cellv(Vector2(x, y)));
				layer.update_bitmask_area(Vector2(x, y+shift.y));
				layer.set_cellv(Vector2(x, y), -1);
				layer.update_bitmask_area(Vector2(x, y));
	elif (shift.y > 0):	
		rect = layer.get_used_rect();
		for i in range(rect.size.x):
			var x = rect.position.x + i;
			for j in range(rect.size.y):
				var y = rect.position.y + rect.size.y - 1 - j;
				layer.set_cellv(Vector2(x, y+shift.y), layer.get_cellv(Vector2(x, y)));
				layer.update_bitmask_area(Vector2(x, y+shift.y));
				layer.set_cellv(Vector2(x, y), -1);
				layer.update_bitmask_area(Vector2(x, y));

func layer_index() -> int:
	return terrain_layers.size() - 1 - pen_layer;

func change_pen_tile() -> void:
	var tile_set = tilemaps.get_child(0).tile_set;
	if (pen_tile >= 0):
		pen.texture = tile_set.tile_get_texture(pen_tile);
		pen.offset = Vector2.ZERO;
	else:
		pen.texture = preload("res://assets/targeter.png");
		pen.offset = Vector2(-1, -1);
	# handle auto-tile wall icon
	if (pen_tile == Tiles.Wall):
		var coord = tile_set.autotile_get_icon_coordinate(pen_tile);
		pen.region_enabled = true;
		pen.region_rect = Rect2(coord*gamelogic.cell_size, Vector2(gamelogic.cell_size, gamelogic.cell_size));
	else:
		pen.region_enabled = false;

func picker_click() -> void:
	if searchbox_has_mouse:
		return;
	
	pen_tile = picker.get_cellv(pen_xy);
	change_pen_tile();
	toggle_picker_mode();
	just_picked = true;

func lmb() -> void:
	if (picker_mode):
		picker_click();
		return;
		
	if (just_picked):
		return;
	
	terrain_layers[layer_index()].set_cellv(pen_xy, pen_tile);
	terrain_layers[layer_index()].update_bitmask_area(pen_xy);
	if (level_info.map_x_max < pen_xy.x):
		level_info.map_x_max = pen_xy.x;
	if (level_info.map_y_max < pen_xy.y):
		level_info.map_y_max = pen_xy.y;

func rmb() -> void:
	if (picker_mode):
		picker_click();
		return;
		
	if (just_picked):
		return;
	
	pen_tile = terrain_layers[layer_index()].get_cellv(pen_xy);
	change_pen_tile();

func _menubutton_pressed() -> void:
	if (gamelogic.ui_stack.size() > 0 and gamelogic.ui_stack[gamelogic.ui_stack.size() - 1] != self):
		return;
	
	var a = preload("res://level_editor/LevelEditorMenu.tscn").instance();
	gamelogic.add_to_ui_stack(a, self);

func destroy() -> void:
	gamelogic.no_mute_pwease = false;
	gamelogic.tile_changes(false);
	self.queue_free();
	gamelogic.ui_stack.erase(self);

func floating_text(text: String) -> void:
	var label = preload("res://FloatingText.tscn").instance();
	var existing_labels = 0;
	for i in self.get_children():
		if i is FloatingText:
			existing_labels += 1;
	self.add_child(label);
	label.rect_position.x = 0;
	label.rect_size.x = gamelogic.pixel_width;
	label.rect_position.y = gamelogic.pixel_height/2-16 + 8*existing_labels;
	label.text = text;
	
func generate_layer() -> void:
	var layer = TileMap.new();
	layer.tile_set = terrain_layers[0].tile_set;
	layer.cell_size = terrain_layers[0].cell_size;
	terrain_layers.push_front(layer);
	tilemaps.add_child(layer);
	
func change_layer(layer: int) -> void:
	pen_layer = layer;
	while (terrain_layers.size() < (pen_layer + 1)):
		generate_layer();
	for i in range(terrain_layers.size()):
		if i == layer_index():
			terrain_layers[i].modulate = Color(1, 1, 1, 1);
		else:
			terrain_layers[i].modulate = Color(1, 1, 1, 0.5);
	layerlabel.text = "Layer: " + str(pen_layer);

func toggle_picker_mode() -> void:
	if !picker_mode:
		picker_mode = true;
		pickerbackground.visible = true;
		picker.visible = true;
		pickertooltip.visible = show_tooltips;
		searchbox.grab_focus();
	else:
		picker_mode = false;
		pickerbackground.visible = false;
		picker.visible = false;
		pickertooltip.visible = false;

func picker_cycle(impulse: int) -> void:
	var current_index = picker_array.find(pen_tile);
	if (current_index == -1):
		current_index = 0;
	current_index += impulse;
	if (current_index < 0):
		current_index += picker_array.size();
	elif (current_index >= picker_array.size()):
		current_index -= picker_array.size();
	pen_tile = picker_array[current_index];
	change_pen_tile();
	
func tooltip_for_tile(tile: int) -> String:
	var text = "";
	match tile:
		-1:
			text = "";
		Tiles.Floor:
			text = "Floor: Ice Blocks slide along this."
		Tiles.Wall:
			text = "Wall: Solid."
		Tiles.Player:
			text = "Player: Lyrebirds are imbued with the power of Song. They can recall past memories so vividly it was like they hadn't happened yet, and through singing, they can be experienced again, and reinforced in the process. (In practice, you're a Sokoban player who can Unwin Stars.)"
		Tiles.Win:
			text = "Win: If the Player is on Win and all Stars are collected: You win the puzzle."
		Tiles.Star:
			text = "Star: Can push and be pushed by Dirt Blocks and Ice Blocks if uncollected. Intangible if collected. Can be collected by being stepped on by the Player. When they do, release a 3x3 burst that melts Ice. Must collect all Stars to Win the puzzle. Floats above Holes and Bottomless Pits."
		Tiles.DirtBlock:
			text = "Dirt Block: An ordinary Sokoban block. Falls into Holes (filling them) and into Bottomless Pits (vanishing)."
		Tiles.IceBlock:
			text = "Ice Block: As per Dirt Block, but additionally: 1) Melted by collecting a Star in the 3x3 neighbourhood. 2) After moving, if it moved onto Floor, attempts to move again in the same direction."
		Tiles.Hole:
			text = "Hole: Stars float above Hole, but the Player and Blocks will fall in and fill the Hole (turning it into Floor)."
		Tiles.BottomlessPit:
			text = "Bottomless Pit: A Hole that cannot be filled."
		Tiles.Water:
			text = "Water: Solid to Players."
		Tiles.Ice:
			text = "Ice: Solid to Blocks."
		Tiles.MagicBarrier:
			text = "Magic Barrier: Solid to Stars."
		Tiles.CrackedStar:
			text = "Cracked Star: A Star that does not create an Unwin event."
		Tiles.DarkStar:
			text = "Dark Star: A Star that prevents the player from Unwinning past where it was collected."
		Tiles.GreenAura:
			text = "Green: Colour. (Attaches to the first actor to enter or start in its tile it can modify.) Immune to Undo events."
		Tiles.OneWayWest:
			text = "One Way: Solid to moves entering its tile."
		Tiles.OneWaySouth:
			text = "One Way: Solid to moves entering its tile."
		Tiles.OneWayNorth:
			text = "One Way: Solid to moves entering its tile."
		Tiles.OneWayEast:
			text = "One Way: Solid to moves entering its tile."
	return text;
	
func picker_tooltip() -> void:
	var tile = picker.get_cellv(pen_xy);
	var text = tooltip_for_tile(tile);
	pickertooltip.set_rect_size(Vector2(200, 0));
	pickertooltip.change_text(text);
	
	pickertooltip.set_rect_position(gamelogic.adjusted_mouse_position() + Vector2(8, 8));
	pickertooltip.set_rect_size(Vector2(200, pickertooltip.get_rect_size().y));
	if (pickertooltip.get_rect_position().x + 200 > 512):
		pickertooltip.set_rect_size(Vector2(max(100, 512 - pickertooltip.get_rect_position().x), pickertooltip.get_rect_size().y));
	if (pickertooltip.get_rect_position().x + 100 > 512):
		pickertooltip.set_rect_position(Vector2(512-100, pickertooltip.get_rect_position().y));
	if (pickertooltip.get_rect_position().y + pickertooltip.get_rect_size().y > 300):
		pickertooltip.set_rect_position(Vector2(pickertooltip.get_rect_position().x, 300-pickertooltip.get_rect_size().y));
	
func test_level() -> void:
	var result = serialize_current_level();
	if (result != ""):
		gamelogic.end_replay();
		gamelogic.load_custom_level(result);
		gamelogic.test_mode = true;
	destroy();

func toggle_zoom() -> void:
	if (tilemaps.scale == Vector2(1, 1)):
		tilemaps.scale = Vector2(0.5, 0.5);
	else:
		tilemaps.scale = Vector2(1, 1);
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (level_info != null):
		$ColorRect.color = level_info.target_sky;
	
	if (gamelogic.ui_stack.size() > 0 and gamelogic.ui_stack[gamelogic.ui_stack.size() - 1] != self):
		return;
	
	if (Input.is_action_just_pressed("escape")):
		if (picker_mode and searchbox.editable):
			menubutton.grab_focus();
		else:
			_menubutton_pressed();
		
	var mouse_position = gamelogic.adjusted_mouse_position();
	if (picker_mode):
		pen.scale = Vector2(1, 1);
	else:
		pen.scale = tilemaps.scale;
	var cell_size = gamelogic.cell_size*pen.scale.x;
	mouse_position.x = cell_size*round((mouse_position.x-cell_size/2)/float(cell_size));
	mouse_position.y = cell_size*round((mouse_position.y-cell_size/2)/float(cell_size));
	pen.position = mouse_position;
	pen_xy = Vector2(round(mouse_position.x/float(cell_size)), round(mouse_position.y/float(cell_size)));
	
	if (picker_mode and searchbox_has_mouse):
		pen.visible = false;
	else:
		pen.visible = true;
	
	if (picker_mode and show_tooltips):
		picker_tooltip();
		
	if (picker_mode and !searchbox.editable):
		if (Input.is_action_just_pressed("start_search")):
			searchbox.visible = true;
			searchbox.grab_focus();
	
	var over_menu_button = false;
	var draw_mode = menubutton.get_draw_mode();
	if (draw_mode == 1 or draw_mode == 3 or draw_mode == 4):
		over_menu_button = true;
	if (!Input.is_mouse_button_pressed(1) and !Input.is_mouse_button_pressed(2)):
		just_picked = false;
	if (Input.is_mouse_button_pressed(1)):
		if !over_menu_button:
			lmb();
	if (Input.is_mouse_button_pressed(2)):
		if !over_menu_button:
			rmb();
	if (Input.is_action_just_released("mouse_wheel_up")):
		picker_cycle(-1);
	if (Input.is_action_just_released("mouse_wheel_down")):
		picker_cycle(1);
		
	if (Input.is_action_just_pressed("tab") and !Input.is_mouse_button_pressed(1) and !Input.is_mouse_button_pressed(2)):
		toggle_picker_mode();
		
	if (!picker_mode):
		if (Input.is_action_just_pressed("copy") and Input.is_action_pressed("ctrl")):
			copy_level();
		if (Input.is_action_just_pressed("paste") and Input.is_action_pressed("ctrl")):
			paste_level();
		if (Input.is_action_just_pressed("test_level")):
			test_level();
		if (Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("nonaxis_left")):
			if (Input.is_action_pressed("shift")):
				shift_layer(terrain_layers[layer_index()], Vector2.LEFT);
			else:
				shift_all_layers(Vector2.LEFT);
		if (Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("nonaxis_right")):
			if (Input.is_action_pressed("shift")):
				shift_layer(terrain_layers[layer_index()], Vector2.RIGHT);
			else:
				shift_all_layers(Vector2.RIGHT);
		if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("nonaxis_up")):
			if (Input.is_action_pressed("shift")):
				shift_layer(terrain_layers[layer_index()], Vector2.UP);
			else:
				shift_all_layers(Vector2.UP);
		if (Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("nonaxis_down")):
			if (Input.is_action_pressed("shift")):
				shift_layer(terrain_layers[layer_index()], Vector2.DOWN);
			else:
				shift_all_layers(Vector2.DOWN);
		if (Input.is_action_just_pressed("0")):
			change_layer(9);
		if (Input.is_action_just_pressed("1")):
			change_layer(0);
		if (Input.is_action_just_pressed("2")):
			change_layer(1);
		if (Input.is_action_just_pressed("3")):
			change_layer(2);
		if (Input.is_action_just_pressed("4")):
			change_layer(3);
		if (Input.is_action_just_pressed("5")):
			change_layer(4);
		if (Input.is_action_just_pressed("6")):
			change_layer(5);
		if (Input.is_action_just_pressed("7")):
			change_layer(6);
		if (Input.is_action_just_pressed("8")):
			change_layer(7);
		if (Input.is_action_just_pressed("9")):
			change_layer(8);
		if (Input.is_action_just_pressed("zoom")):
			toggle_zoom();
