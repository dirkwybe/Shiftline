extends Control

const DEFAULT_WIDTH := 8
const DEFAULT_HEIGHT := 8
const DEFAULT_PALETTE := [
	"#3C78DC",
	"#E65050",
	"#50BE78",
	"#E6C846"
]

@export var tile_texture: Texture2D
@export var wall_texture: Texture2D
@export var background_texture: Texture2D
@export var cell_size := 64
@export var default_save_path := "res://levels/level_custom.json"

@onready var background: TextureRect = $Background
@onready var title_label: RichTextLabel = $Layout/Title
@onready var tool_option: OptionButton = $Layout/ControlsBar/ControlsRow1/ToolOption
@onready var color_option: OptionButton = $Layout/ControlsBar/ControlsRow1/ColorOption
@onready var bouncer_option: OptionButton = $Layout/ControlsBar/ControlsRow1/BouncerOption
@onready var width_spin: SpinBox = $Layout/ControlsBar/ControlsRow2/WidthSpin
@onready var height_spin: SpinBox = $Layout/ControlsBar/ControlsRow2/HeightSpin
@onready var resize_button: Button = $Layout/ControlsBar/ControlsRow2/ResizeButton
@onready var path_line: LineEdit = $Layout/PathBar/PathLine
@onready var browse_load: Button = $Layout/PathBar/BrowseLoad
@onready var browse_save: Button = $Layout/PathBar/BrowseSave
@onready var grid_container: GridContainer = $Layout/GridCenter/Grid
@onready var new_button: Button = $Layout/ButtonBar/NewButton
@onready var load_button: Button = $Layout/ButtonBar/LoadButton
@onready var save_button: Button = $Layout/ButtonBar/SaveButton
@onready var test_button: Button = $Layout/ButtonBar/TestButton
@onready var home_button: Button = $Layout/ButtonBar/HomeButton
@onready var status_label: Label = $Layout/StatusLabel
@onready var load_dialog: FileDialog = $LoadDialog
@onready var save_dialog: FileDialog = $SaveDialog

var width := DEFAULT_WIDTH
var height := DEFAULT_HEIGHT
var palette: Array[Color] = []
var walls: Dictionary = {}
var holes: Dictionary = {}
var blocks: Dictionary = {}
var bouncers: Dictionary = {}
var cells: Array = []
var pending_test := false

enum ToolType { BLOCK, HOLE, WALL, BOUNCER, ERASE }

func _ready() -> void:
	if background != null and background_texture != null:
		background.texture = background_texture
	if background != null:
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_setup_controls()
	_new_level()
	_check_return_level()

func _setup_controls() -> void:
	tool_option.clear()
	tool_option.add_item("Block", ToolType.BLOCK)
	tool_option.add_item("Hole", ToolType.HOLE)
	tool_option.add_item("Wall", ToolType.WALL)
	tool_option.add_item("Bouncer", ToolType.BOUNCER)
	tool_option.add_item("Erase", ToolType.ERASE)

	bouncer_option.clear()
	bouncer_option.add_item("Reverse", 0)

	width_spin.min_value = 3
	width_spin.max_value = 12
	width_spin.step = 1
	height_spin.min_value = 3
	height_spin.max_value = 12
	height_spin.step = 1

	resize_button.pressed.connect(_on_resize_pressed)
	new_button.pressed.connect(_new_level)
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	test_button.pressed.connect(_on_test_pressed)
	home_button.pressed.connect(_on_home_pressed)
	browse_load.pressed.connect(_on_browse_load_pressed)
	browse_save.pressed.connect(_on_browse_save_pressed)
	load_dialog.file_selected.connect(_on_load_file_selected)
	save_dialog.file_selected.connect(_on_save_file_selected)

	_set_palette_from_strings(DEFAULT_PALETTE)
	_refresh_color_option()
	path_line.text = default_save_path

func _set_palette_from_strings(values: Array) -> void:
	palette.clear()
	for value in values:
		if value is String:
			palette.append(Color.from_string(value, Color.WHITE))

func _refresh_color_option() -> void:
	color_option.clear()
	for i in range(palette.size()):
		color_option.add_item("Color %d" % i, i)

func _new_level() -> void:
	width = int(width_spin.value) if width_spin != null else DEFAULT_WIDTH
	height = int(height_spin.value) if height_spin != null else DEFAULT_HEIGHT
	walls.clear()
	holes.clear()
	blocks.clear()
	bouncers.clear()
	_build_grid()
	_update_cells()
	_set_status("New level ready")

func _on_resize_pressed() -> void:
	width = int(width_spin.value)
	height = int(height_spin.value)
	_trim_out_of_bounds()
	_build_grid()
	_update_cells()
	_set_status("Resized to %dx%d" % [width, height])

func _trim_out_of_bounds() -> void:
	for pos in walls.keys():
		var p: Vector2i = pos
		if not _in_bounds(p):
			walls.erase(p)
	for pos in holes.keys():
		var p: Vector2i = pos
		if not _in_bounds(p):
			holes.erase(p)
	for pos in blocks.keys():
		var p: Vector2i = pos
		if not _in_bounds(p):
			blocks.erase(p)
	for pos in bouncers.keys():
		var p: Vector2i = pos
		if not _in_bounds(p):
			bouncers.erase(p)

func _build_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	grid_container.columns = width
	grid_container.add_theme_constant_override("hseparation", 1)
	grid_container.add_theme_constant_override("vseparation", 1)
	grid_container.custom_minimum_size = Vector2(cell_size * width, cell_size * height)
	cells = []
	for y in height:
		var row: Array = []
		for x in width:
			var cell := Control.new()
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.gui_input.connect(_on_cell_input.bind(Vector2i(x, y)))
			grid_container.add_child(cell)

			var base := ColorRect.new()
			base.color = Color8(45, 45, 55)
			base.set_anchors_preset(Control.PRESET_FULL_RECT)
			base.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(base)

			var hole_outer := ColorRect.new()
			hole_outer.color = Color(0, 0, 0, 0)
			hole_outer.set_anchors_preset(Control.PRESET_FULL_RECT)
			hole_outer.offset_left = 8
			hole_outer.offset_top = 8
			hole_outer.offset_right = -8
			hole_outer.offset_bottom = -8
			hole_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(hole_outer)

			var hole_inner := ColorRect.new()
			hole_inner.color = Color(0, 0, 0, 0)
			hole_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			hole_inner.offset_left = 16
			hole_inner.offset_top = 16
			hole_inner.offset_right = -16
			hole_inner.offset_bottom = -16
			hole_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(hole_inner)

			var block := TextureRect.new()
			block.texture = tile_texture
			block.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			block.stretch_mode = TextureRect.STRETCH_SCALE
			block.set_anchors_preset(Control.PRESET_FULL_RECT)
			block.offset_left = 10
			block.offset_top = 10
			block.offset_right = -10
			block.offset_bottom = -10
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(block)

			var wall := TextureRect.new()
			wall.texture = wall_texture
			wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			wall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			wall.set_anchors_preset(Control.PRESET_FULL_RECT)
			wall.offset_left = 6
			wall.offset_top = 6
			wall.offset_right = -6
			wall.offset_bottom = -6
			wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(wall)

			var bouncer_label := Label.new()
			bouncer_label.text = "R"
			bouncer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bouncer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			bouncer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			bouncer_label.add_theme_font_size_override("font_size", 18)
			bouncer_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.95))
			bouncer_label.visible = false
			cell.add_child(bouncer_label)

			row.append({
				"base": base,
				"hole_outer": hole_outer,
				"hole_inner": hole_inner,
				"block": block,
				"wall": wall,
				"bouncer": bouncer_label
			})
		cells.append(row)

func _update_cells() -> void:
	for y in height:
		for x in width:
			_update_cell(Vector2i(x, y))

func _update_cell(pos: Vector2i) -> void:
	if not _in_bounds(pos):
		return
	var cell: Dictionary = cells[pos.y][pos.x]
	var hole_outer: ColorRect = cell["hole_outer"]
	var hole_inner: ColorRect = cell["hole_inner"]
	var block: TextureRect = cell["block"]
	var wall: TextureRect = cell["wall"]
	var bouncer_label: Label = cell["bouncer"]

	var has_wall := walls.has(pos)
	wall.visible = has_wall
	if has_wall:
		block.visible = false
		hole_outer.visible = false
		hole_inner.visible = false
		bouncer_label.visible = false
		return

	if holes.has(pos):
		var hole_color := palette[int(holes[pos]) % palette.size()]
		hole_outer.color = hole_color.darkened(0.3)
		hole_inner.color = hole_color.darkened(0.1)
		hole_outer.visible = true
		hole_inner.visible = true
	else:
		hole_outer.visible = false
		hole_inner.visible = false

	if blocks.has(pos):
		var color := palette[int(blocks[pos]) % palette.size()]
		block.modulate = color
		block.visible = true
	else:
		block.visible = false

	if bouncers.has(pos):
		bouncer_label.visible = true
	else:
		bouncer_label.visible = false

func _on_cell_input(event: InputEvent, pos: Vector2i) -> void:
	if event is InputEventMouseButton and event.pressed:
		_apply_tool(pos)
	elif event is InputEventScreenTouch and event.pressed:
		_apply_tool(pos)

func _apply_tool(pos: Vector2i) -> void:
	var tool_id := tool_option.get_selected_id()
	if tool_id == ToolType.BLOCK:
		blocks[pos] = color_option.get_selected_id()
		walls.erase(pos)
		holes.erase(pos)
		bouncers.erase(pos)
	elif tool_id == ToolType.HOLE:
		holes[pos] = color_option.get_selected_id()
		walls.erase(pos)
		blocks.erase(pos)
		bouncers.erase(pos)
	elif tool_id == ToolType.WALL:
		walls[pos] = true
		holes.erase(pos)
		blocks.erase(pos)
		bouncers.erase(pos)
	elif tool_id == ToolType.BOUNCER:
		bouncers[pos] = {"type": "reverse"}
		walls.erase(pos)
		holes.erase(pos)
		blocks.erase(pos)
	elif tool_id == ToolType.ERASE:
		walls.erase(pos)
		holes.erase(pos)
		blocks.erase(pos)
		bouncers.erase(pos)
	_update_cell(pos)

func _on_browse_load_pressed() -> void:
	load_dialog.current_dir = "res://levels"
	load_dialog.popup_centered()

func _on_browse_save_pressed() -> void:
	save_dialog.current_dir = "res://levels"
	save_dialog.current_file = "level_custom.json"
	save_dialog.popup_centered()

func _on_load_file_selected(path: String) -> void:
	path_line.text = path
	_load_from_path(path)

func _on_save_file_selected(path: String) -> void:
	path_line.text = path
	if pending_test:
		pending_test = false
		_save_to_path(path)
		get_tree().set_meta("editor_preview_path", path)
		get_tree().set_meta("editor_return_path", path)
		get_tree().change_scene_to_file("res://main.tscn")
		return
	_save_to_path(path)

func _on_load_pressed() -> void:
	_load_from_path(path_line.text)

func _on_save_pressed() -> void:
	_save_to_path(path_line.text)

func _load_from_path(path: String) -> void:
	if path.strip_edges() == "":
		_set_status("Choose a file to load.")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Failed to open %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("Invalid JSON.")
		return
	var data: Dictionary = parsed
	width = int(data.get("width", DEFAULT_WIDTH))
	height = int(data.get("height", DEFAULT_HEIGHT))
	width_spin.value = width
	height_spin.value = height
	_set_palette_from_strings(data.get("palette", DEFAULT_PALETTE))
	_refresh_color_option()

	walls.clear()
	holes.clear()
	blocks.clear()
	bouncers.clear()

	for value in data.get("walls", []):
		var pos := _pos_from_value(value)
		if _in_bounds(pos):
			walls[pos] = true
	for value in data.get("holes", []):
		if value is Dictionary:
			var pos := _pos_from_value(value.get("pos", []))
			if _in_bounds(pos):
				holes[pos] = int(value.get("color", 0))
	for value in data.get("blocks", []):
		if value is Dictionary:
			var pos := _pos_from_value(value.get("pos", []))
			if _in_bounds(pos):
				blocks[pos] = int(value.get("color", 0))
	for value in data.get("bouncers", []):
		if value is Dictionary:
			var pos := _pos_from_value(value.get("pos", []))
			if _in_bounds(pos):
				bouncers[pos] = {"type": String(value.get("type", "reverse"))}

	_build_grid()
	_update_cells()
	_set_status("Loaded %s" % path)

func _save_to_path(path: String) -> void:
	if path.strip_edges() == "":
		_set_status("Choose a file to save.")
		return
	var data := _build_level_data()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("Failed to write %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	_set_status("Saved %s" % path)

func _build_level_data() -> Dictionary:
	var palette_out: Array = []
	for color in palette:
		palette_out.append(color.to_html(false))

	var walls_out: Array = []
	for pos in walls.keys():
		var p: Vector2i = pos
		walls_out.append([p.x, p.y])

	var holes_out: Array = []
	for pos in holes.keys():
		var p: Vector2i = pos
		holes_out.append({"pos": [p.x, p.y], "color": int(holes[pos])})

	var blocks_out: Array = []
	for pos in blocks.keys():
		var p: Vector2i = pos
		blocks_out.append({"pos": [p.x, p.y], "color": int(blocks[pos])})

	var bouncers_out: Array = []
	for pos in bouncers.keys():
		var p: Vector2i = pos
		bouncers_out.append({"pos": [p.x, p.y], "type": "reverse"})

	return {
		"width": width,
		"height": height,
		"palette": palette_out,
		"walls": walls_out,
		"blocks": blocks_out,
		"holes": holes_out,
		"bouncers": bouncers_out
	}

func _on_test_pressed() -> void:
	pending_test = true
	save_dialog.current_dir = "res://levels"
	save_dialog.current_file = "level_custom.json"
	save_dialog.popup_centered()

func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _check_return_level() -> void:
	if not get_tree().has_meta("editor_return_path"):
		return
	var path := str(get_tree().get_meta("editor_return_path"))
	get_tree().remove_meta("editor_return_path")
	if path.strip_edges() == "":
		return
	path_line.text = path
	_load_from_path(path)

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func _pos_from_value(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)
