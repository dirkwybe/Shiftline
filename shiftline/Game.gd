extends Control

const SWIPE_THRESHOLD := 20.0
const DEFAULT_CELL_SIZE := 72
const STAGE_CARD_HEIGHT := 110
const STAGE_GRID_COLUMNS := 2
const ANIM_DURATION := 0.18
const SAVE_PATH := "user://progress.json"
const TILE_TEXTURE_PATH := "res://assets/tiles/tile_base.svg"
const WALL_TEXTURE_PATH := "res://assets/tiles/wall_block.svg"
const DIFFICULTY_LABELS := ["very easy", "easy", "challenging", "hard", "very hard"]
const THEME_TEXTURES := [
	"res://assets/themes/theme_01.svg",
	"res://assets/themes/theme_02.svg",
	"res://assets/themes/theme_03.svg",
	"res://assets/themes/theme_04.svg",
	"res://assets/themes/theme_05.svg",
	"res://assets/themes/theme_06.svg",
	"res://assets/themes/theme_07.svg",
	"res://assets/themes/theme_08.svg",
	"res://assets/themes/theme_09.svg",
	"res://assets/themes/theme_10.svg",
]
const THEME_NAMES := [
	"Crystal Coast",
	"Velvet Dunes",
	"Emerald Grove",
	"Amber Hollow",
	"Moonlit Arch",
	"Cedar Rise",
	"Ember Field",
	"Tideglass",
	"Gilded Plains",
	"Slate Harbor",
]
const THEME_ACCENTS := [
	Color8(62, 124, 177),
	Color8(140, 95, 178),
	Color8(109, 178, 124),
	Color8(194, 123, 94),
	Color8(95, 125, 178),
	Color8(139, 178, 95),
	Color8(178, 95, 95),
	Color8(95, 178, 178),
	Color8(178, 168, 95),
	Color8(120, 120, 120),
]
const LEVEL_NAMES := [
	"First Step",
	"Soft Shift",
	"Hidden Line",
	"Crosswind",
	"Quiet Lock",
	"Midnight Slide",
	"Steel Drift",
	"Echo Turn",
	"Final Gate",
	"Last Light",
]
const TILE_OFFSET_BIAS := Vector2(-2, -2)

@export var sfx_move: AudioStream
@export var sfx_lock: AudioStream
@export var sfx_win: AudioStream
@export var sfx_no_solution: AudioStream
@export var tile_texture: Texture2D
@export var wall_texture: Texture2D
@export var dev_mode := false
@export var sound_enabled := true
@export_multiline var about_text: String = "Shiftline is a sliding puzzle about\nmatching colors and finding order.\nMade for iOS."
@export_multiline var howto_text: String = "[center][b]How to Play[/b][/center]\n\n- Swipe a row or column to slide blocks.\n- Blocks slide until they hit a wall or another locked block.\n- Match blocks to same-colored holes to lock them.\n- Lock all blocks to win.\n\nTip: Use Hint if you get stuck."
@export var wall_tint: Color = Color(0.35, 0.35, 0.4, 1.0)
@export var wall_tint_contrast: Color = Color(0.3, 0.3, 0.35, 1.0)

@onready var background_rect: TextureRect = $Background
@onready var safe_area: MarginContainer = $SafeArea
@onready var game_panel: Control = $SafeArea/VBoxContainer
@onready var header_label: Label = $SafeArea/VBoxContainer/TopBar/HeaderLabel
@onready var subheader_label: Label = $SafeArea/VBoxContainer/TopBar/SubHeaderLabel
@onready var grid_container: GridContainer = $SafeArea/VBoxContainer/CenterContainer/GridContainer
@onready var moves_label: Label = $SafeArea/VBoxContainer/TopBar/SubHeaderLabel
@onready var status_label: Label = $SafeArea/VBoxContainer/StatusLabel
@onready var hbox: HBoxContainer = $SafeArea/VBoxContainer/HBoxContainer
@onready var new_level_button: Button = $SafeArea/VBoxContainer/NextLevelWrap/NewLevelButton
@onready var restart_button: Button = $SafeArea/VBoxContainer/HBoxContainer/RestartButton
@onready var solve_button: Button = _ensure_hbox_button("SolveButton", "Solve")
@onready var hint_button: Button = _ensure_hbox_button("HintButton", "Hint")
@onready var stages_button: Button = _ensure_hbox_button("StagesButton", "Stages")
@onready var options_button: Button = _ensure_hbox_button("OptionsButton", "Options")
@onready var home_button: Button = _ensure_hbox_button("HomeButton", "Home")
@onready var animation_layer: Control = _ensure_animation_layer()
@onready var debug_layer: Control = _ensure_debug_layer()
@onready var stage_panel: Control = _ensure_stage_panel()
@onready var level_panel: Control = _ensure_level_panel()
@onready var stage_complete_popup: Control = _ensure_stage_complete_popup()
@onready var options_panel: Control = _ensure_options_panel()
@onready var start_panel: Control = _ensure_start_panel()
@onready var about_panel: Control = _ensure_about_panel()
@onready var howto_panel: Control = _ensure_howto_panel()
@onready var reset_confirm_popup: Control = _ensure_reset_confirm_popup()
@onready var sfx_move_player: AudioStreamPlayer = _ensure_sfx_player("SfxMove")
@onready var sfx_lock_player: AudioStreamPlayer = _ensure_sfx_player("SfxLock")
@onready var sfx_win_player: AudioStreamPlayer = _ensure_sfx_player("SfxWin")
@onready var sfx_no_solution_player: AudioStreamPlayer = _ensure_sfx_player("SfxNoSolution")

var width := 8
var height := 8
var palette: Array[Color] = []
var grid: Array = []
var walls: Dictionary = {}
var holes: Dictionary = {}
var locked: Dictionary = {}
var cells: Array = []

var moves_made := 0
var input_enabled := true
var is_animating := false
var debug_enabled := true
var debug_validation_text := ""
var solve_queue: Array = []
var solving := false
var level_difficulty_text := ""
var current_difficulty_label: String = ""
var level_paths: Array = []
var current_stage := 1
var current_level_in_stage := 1
var unlocked_stage := 1
var stage_progress: Dictionary = {}
var current_theme_name := ""
var current_level_name := ""
var cell_size := DEFAULT_CELL_SIZE
var high_contrast := false
var large_tiles := false
var settings_path := "user://settings.json"
var current_level_path: String = ""
var current_level_data: Dictionary = {}
var cached_hint_key: String = ""
var cached_hint_path: Array = []
var cached_hint_capped := false
var cached_hint_unsolvable := false
var about_body_label: RichTextLabel = null
var howto_body_label: RichTextLabel = null

var swipe_active := false
var swipe_start_pos := Vector2.ZERO
var swipe_start_cell := Vector2i(-1, -1)

func _ready() -> void:
	new_level_button.pressed.connect(_on_new_level_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	if solve_button != null:
		solve_button.pressed.connect(_on_solve_pressed)
	if hint_button != null:
		hint_button.pressed.connect(_on_hint_pressed)
	if stages_button != null:
		stages_button.pressed.connect(_on_stages_pressed)
	if options_button != null:
		options_button.pressed.connect(_on_options_pressed)
	if home_button != null:
		home_button.pressed.connect(_on_home_pressed)
	_style_ui()
	_setup_dev_ui()
	_ensure_tile_texture()
	_ensure_wall_texture()
	_update_about_text()
	_update_howto_text()
	_load_settings()
	_build_level_paths()
	_load_progress()
	_update_stage_buttons()
	_show_start_screen()

func _style_ui() -> void:
	if header_label != null:
		header_label.add_theme_font_size_override("font_size", 22)
	if subheader_label != null:
		subheader_label.add_theme_font_size_override("font_size", 14)
	if status_label != null:
		status_label.add_theme_font_size_override("font_size", 18)
	if new_level_button != null:
		new_level_button.custom_minimum_size = Vector2(180, 48)
		_style_start_button(new_level_button, Color8(83, 201, 255))
	var button_colors: Array[Color] = [
		Color8(83, 201, 255),
		Color8(109, 255, 160),
		Color8(255, 184, 107),
		Color8(255, 122, 122),
		Color8(183, 109, 255),
		Color8(83, 201, 255),
		Color8(109, 255, 160),
	]
	var color_index := 0
	for child in hbox.get_children():
		if child is Button:
			var btn := child as Button
			btn.add_theme_font_size_override("font_size", 16)
			btn.custom_minimum_size = Vector2(0, 48)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_start_button(btn, button_colors[color_index % button_colors.size()])
			color_index += 1
	if solve_button != null:
		solve_button.visible = dev_mode
	if hint_button != null:
		hint_button.visible = true
	if options_button != null:
		options_button.visible = false

func _setup_dev_ui() -> void:
	var dev_panel := get_node_or_null("SafeArea/VBoxContainer/DevPanel") as Control
	if dev_panel == null:
		return
	dev_panel.visible = dev_mode
	if not dev_mode:
		return
	var dropdown := dev_panel.get_node_or_null("DevPanelHBox/DevDifficultyOption") as OptionButton
	if dropdown == null:
		return
	dropdown.clear()
	for label in DIFFICULTY_LABELS:
		dropdown.add_item(label)
	dropdown.item_selected.connect(_on_dev_difficulty_selected)

func _sync_dev_difficulty_ui() -> void:
	if not dev_mode:
		return
	var dev_panel := get_node_or_null("SafeArea/VBoxContainer/DevPanel") as Control
	if dev_panel == null:
		return
	var dropdown := dev_panel.get_node_or_null("DevPanelHBox/DevDifficultyOption") as OptionButton
	if dropdown == null:
		return
	var target_label := current_difficulty_label
	if target_label == "":
		target_label = DIFFICULTY_LABELS[0]
	var idx := DIFFICULTY_LABELS.find(target_label)
	if idx < 0:
		idx = 0
	dropdown.select(idx)

func _on_dev_difficulty_selected(index: int) -> void:
	if not dev_mode:
		return
	if current_level_path == "":
		return
	var label: String = DIFFICULTY_LABELS[clampi(index, 0, DIFFICULTY_LABELS.size() - 1)]
	current_level_data["difficulty"] = index + 1
	current_level_data["difficulty_label"] = label
	current_level_data["difficulty_manual"] = true
	_save_current_level_data()
	_apply_difficulty_from_level(current_level_data, 2500)
	_sync_dev_difficulty_ui()

func _on_sound_toggled(pressed: bool) -> void:
	sound_enabled = pressed
	_save_settings()
	_sync_settings_ui()

func _on_reset_progress_pressed() -> void:
	_show_reset_confirm()

func _show_reset_confirm() -> void:
	if reset_confirm_popup != null:
		reset_confirm_popup.visible = true

func _hide_reset_confirm() -> void:
	if reset_confirm_popup != null:
		reset_confirm_popup.visible = false

func _on_reset_confirm_yes() -> void:
	_hide_reset_confirm()
	stage_progress = {}
	unlocked_stage = 1
	current_stage = 1
	current_level_in_stage = 1
	_save_progress()
	_update_stage_buttons()
	_show_start_screen()

func _on_reset_confirm_no() -> void:
	_hide_reset_confirm()

func _ensure_tile_texture() -> void:
	if tile_texture == null:
		tile_texture = load(TILE_TEXTURE_PATH) as Texture2D

func _ensure_wall_texture() -> void:
	if wall_texture == null:
		wall_texture = load(WALL_TEXTURE_PATH) as Texture2D

func _update_about_text() -> void:
	if about_body_label != null:
		about_body_label.text = about_text

func _update_howto_text() -> void:
	if howto_body_label != null:
		howto_body_label.text = howto_text

func _clear_hint_cache() -> void:
	cached_hint_key = ""
	cached_hint_path.clear()
	cached_hint_capped = false
	cached_hint_unsolvable = false

func _apply_theme_from_level(data: Dictionary) -> void:
	var theme_index: int = clampi(current_stage - 1, 0, THEME_TEXTURES.size() - 1)
	var theme_name: String = String(data.get("theme_name", ""))
	var level_name: String = String(data.get("level_name", ""))
	if theme_name == "":
		theme_name = THEME_NAMES[theme_index] if theme_index < THEME_NAMES.size() else "Shiftline"
	if level_name == "":
		var level_idx: int = clampi(current_level_in_stage - 1, 0, LEVEL_NAMES.size() - 1)
		level_name = LEVEL_NAMES[level_idx] if level_idx < LEVEL_NAMES.size() else "Shift"
	current_theme_name = theme_name
	current_level_name = level_name
	_set_theme_background(theme_index, data)

func _set_theme_background(theme_index: int, data: Dictionary) -> void:
	if background_rect == null:
		return
	var custom_path: String = String(data.get("theme_texture", ""))
	var path := custom_path
	if path == "":
		if theme_index >= 0 and theme_index < THEME_TEXTURES.size():
			path = THEME_TEXTURES[theme_index]
	if path == "":
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		background_rect.texture = tex

func _apply_menu_theme(stage_index: int) -> void:
	var theme_index: int = clampi(stage_index - 1, 0, THEME_ACCENTS.size() - 1)
	var accent: Color = THEME_ACCENTS[theme_index]
	var stage_back := stage_panel.get_node_or_null("StageBackdrop") as ColorRect
	var stage_vignette := stage_panel.get_node_or_null("StageVignette") as ColorRect
	if stage_back != null:
		var stage_color := accent.darkened(0.55)
		stage_color.a = 0.85
		stage_back.color = stage_color
	if stage_vignette != null:
		stage_vignette.color = Color(0, 0, 0, 0.2)
	var level_back := level_panel.get_node_or_null("LevelBackdrop") as ColorRect
	var level_vignette := level_panel.get_node_or_null("LevelVignette") as ColorRect
	if level_back != null:
		var level_color := accent.darkened(0.55)
		level_color.a = 0.85
		level_back.color = level_color
	if level_vignette != null:
		level_vignette.color = Color(0, 0, 0, 0.2)

func _apply_accessibility() -> void:
	cell_size = 80 if large_tiles else DEFAULT_CELL_SIZE
	_build_grid_nodes()
	_update_tiles()
	_update_hud()

func _on_hint_pressed() -> void:
	if is_animating or not input_enabled:
		return
	if _is_win():
		status_label.text = "Already solved"
		return
	var current_key := _grid_key(grid)
	if current_key == cached_hint_key:
		if not cached_hint_path.is_empty():
			var cached_move: Dictionary = cached_hint_path[0]
			_show_debug_line(cached_move["is_row"], cached_move["index"])
			status_label.text = "Hint shown"
			return
		if cached_hint_capped:
			status_label.text = "Hint search limit reached. Try Restart."
			return
		if cached_hint_unsolvable:
			status_label.text = "No solution found. Press Restart."
			_play_sfx(sfx_no_solution, sfx_no_solution_player)
			return
	var result := _solve_level_status(12000)
	var path: Array = result["path"]
	if path.is_empty():
		cached_hint_key = current_key
		cached_hint_path.clear()
		cached_hint_capped = bool(result.get("capped", false))
		cached_hint_unsolvable = not cached_hint_capped
		if cached_hint_capped:
			status_label.text = "Hint search limit reached. Try Restart."
		else:
			status_label.text = "No solution found. Press Restart."
			_play_sfx(sfx_no_solution, sfx_no_solution_player)
		return
	cached_hint_key = current_key
	cached_hint_path = path.duplicate()
	cached_hint_capped = false
	cached_hint_unsolvable = false
	var move: Dictionary = path[0]
	_show_debug_line(move["is_row"], move["index"])
	status_label.text = "Hint shown"

func _on_options_pressed() -> void:
	start_panel.visible = false
	about_panel.visible = false
	options_panel.visible = true

func _ensure_options_panel() -> Control:
	var panel := Control.new()
	panel.name = "OptionsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "OptionsBackdrop"
	backdrop.texture = load("res://assets/themes/home_screen.svg") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backdrop)

	var layout := VBoxContainer.new()
	layout.name = "OptionsLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var top := HBoxContainer.new()
	top.name = "OptionsTopBar"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	layout.add_child(top)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)

	var title_wrap := CenterContainer.new()
	title_wrap.name = "OptionsTitleWrap"
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.custom_minimum_size = Vector2(0, 70)
	layout.add_child(title_wrap)

	var title := RichTextLabel.new()
	title.name = "OptionsTitle"
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = _rainbow_title("Options")
	title.add_theme_font_size_override("normal_font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.add_child(title)

	var center_wrap := CenterContainer.new()
	center_wrap.name = "OptionsCenter"
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center_wrap)

	var center := PanelContainer.new()
	center.name = "OptionsBox"
	center.custom_minimum_size = Vector2(300, 200)
	center.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center_wrap.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "OptionsVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var contrast := CheckButton.new()
	contrast.name = "HighContrastCheck"
	contrast.text = "High Contrast"
	contrast.toggled.connect(func(pressed: bool) -> void:
		high_contrast = pressed
		_update_tiles()
	)
	vbox.add_child(contrast)

	var large := CheckButton.new()
	large.name = "LargeTilesCheck"
	large.text = "Large Tiles"
	large.toggled.connect(func(pressed: bool) -> void:
		large_tiles = pressed
		_apply_accessibility()
	)
	vbox.add_child(large)

	var sound := CheckButton.new()
	sound.name = "SoundCheck"
	sound.text = "Sound"
	sound.button_pressed = sound_enabled
	sound.toggled.connect(_on_sound_toggled)
	vbox.add_child(sound)

	var reset := Button.new()
	reset.name = "ResetProgressButton"
	reset.text = "Reset Progress"
	reset.pressed.connect(_on_reset_progress_pressed)
	_style_start_button(reset, Color8(255, 184, 107))
	vbox.add_child(reset)

	var spacer := Control.new()
	spacer.name = "OptionsSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var home_bar := Control.new()
	home_bar.name = "OptionsHomeBar"
	home_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	home_bar.offset_left = 12
	home_bar.offset_right = -12
	home_bar.offset_top = -72
	home_bar.offset_bottom = -12
	panel.add_child(home_bar)

	var home_wrap := CenterContainer.new()
	home_wrap.name = "OptionsHomeWrap"
	home_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	home_bar.add_child(home_wrap)

	var home := Button.new()
	home.text = "Home"
	home.custom_minimum_size = Vector2(160, 44)
	home.pressed.connect(func() -> void:
		_show_start_screen()
	)
	_style_start_button(home, Color8(83, 201, 255))
	home_wrap.add_child(home)

	return panel

func _ensure_start_panel() -> Control:
	var existing := get_node_or_null("StartPanel")
	if existing != null and existing is Control:
		var panel := existing as Control
		var backdrop := panel.get_node_or_null("StartBackdrop") as TextureRect
		if backdrop != null:
			backdrop.texture = load("res://assets/themes/home_screen.svg") as Texture2D
		var title := panel.get_node_or_null("StartLayout/StartTitle") as RichTextLabel
		if title != null:
			title.add_theme_font_size_override("normal_font_size", 64)
			title.custom_minimum_size = Vector2(0, 180)
		var play := panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartPlayButton") as Button
		if play != null:
			play.pressed.connect(_show_stage_select)
			_style_start_button(play, Color8(83, 201, 255))
		var options := panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartOptionsButton") as Button
		if options != null:
			options.pressed.connect(func() -> void:
				options_panel.visible = true
			)
			_style_start_button(options, Color8(109, 255, 160))
		var about := panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartAboutButton") as Button
		if about != null:
			about.pressed.connect(func() -> void:
				start_panel.visible = false
				about_panel.visible = true
			)
			_style_start_button(about, Color8(255, 184, 107))
		var howto := panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartHowToButton") as Button
		if howto != null:
			howto.pressed.connect(func() -> void:
				start_panel.visible = false
				howto_panel.visible = true
			)
			_style_start_button(howto, Color8(109, 255, 160))
		var box := panel.get_node_or_null("StartLayout/StartBox") as PanelContainer
		if box != null:
			box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return panel

	var panel := Control.new()
	panel.name = "StartPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "StartBackdrop"
	backdrop.texture = load("res://assets/themes/home_screen.svg") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backdrop)

	var layout := VBoxContainer.new()
	layout.name = "StartLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.text = "[center][color=#6ED3FF]S[/color][color=#6BFFA0]h[/color][color=#F9D56E]i[/color][color=#FF7A7A]f[/color][color=#B76DFF]t[/color][color=#6ED3FF]l[/color][color=#6BFFA0]i[/color][color=#F9D56E]n[/color][color=#FF7A7A]e[/color][/center]"
	title.add_theme_font_size_override("font_size", 52)
	title.custom_minimum_size = Vector2(0, 140)
	layout.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var center := PanelContainer.new()
	center.name = "StartBox"
	center.custom_minimum_size = Vector2(300, 260)
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var transparent := StyleBoxEmpty.new()
	center.add_theme_stylebox_override("panel", transparent)
	layout.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "StartVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var play := Button.new()
	play.text = "Play"
	play.custom_minimum_size = Vector2(0, 52)
	play.pressed.connect(_show_stage_select)
	_style_start_button(play, Color8(83, 201, 255))
	vbox.add_child(play)

	var options := Button.new()
	options.text = "Options"
	options.custom_minimum_size = Vector2(0, 48)
	options.pressed.connect(func() -> void:
		options_panel.visible = true
	)
	_style_start_button(options, Color8(109, 255, 160))
	vbox.add_child(options)

	var about := Button.new()
	about.text = "About"
	about.custom_minimum_size = Vector2(0, 48)
	about.pressed.connect(func() -> void:
		start_panel.visible = false
		about_panel.visible = true
	)
	_style_start_button(about, Color8(255, 184, 107))
	vbox.add_child(about)

	var howto := Button.new()
	howto.text = "How To Play"
	howto.custom_minimum_size = Vector2(0, 48)
	howto.pressed.connect(func() -> void:
		start_panel.visible = false
		howto_panel.visible = true
	)
	_style_start_button(howto, Color8(109, 255, 160))
	vbox.add_child(howto)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(bottom_spacer)

	return panel

func _style_start_button(btn: Button, color: Color) -> void:
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_color_override("font_outline_color", Color8(255, 220, 120))
	btn.add_theme_color_override("font_color", Color8(12, 32, 74))
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.08)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

func _rainbow_title(text: String) -> String:
	var colors: PackedStringArray = PackedStringArray(["#6ED3FF", "#6BFFA0", "#F9D56E", "#FF7A7A", "#B76DFF"])
	var result := "[center]"
	var length := text.length()
	for i in range(length):
		var ch := text.substr(i, 1)
		if ch == " ":
			result += " "
		else:
			var color := colors[i % colors.size()]
			result += "[color=%s]%s[/color]" % [color, ch]
	result += "[/center]"
	return result

func _style_stage_card(btn: Button, theme_index: int, locked: bool) -> void:
	var accent: Color = THEME_ACCENTS[clampi(theme_index, 0, THEME_ACCENTS.size() - 1)]
	if locked:
		accent = accent.darkened(0.55)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.35)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate()
	hover.bg_color = accent.darkened(0.25)
	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.45)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

func _style_level_button(btn: Button, theme_index: int, locked: bool) -> void:
	var accent: Color = THEME_ACCENTS[clampi(theme_index, 0, THEME_ACCENTS.size() - 1)]
	if locked:
		accent = accent.darkened(0.6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.35)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate()
	hover.bg_color = accent.darkened(0.25)
	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.45)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

func _clear_pulses() -> void:
	for row in cells:
		if row is Array:
			for cell in row:
				if cell is Dictionary and cell.has("pulse_tween"):
					var tween: Tween = cell["pulse_tween"]
					if tween is Tween:
						tween.kill()

func _start_solved_pulse(cell: Dictionary) -> void:
	var block: TextureRect = cell["block"]
	block.self_modulate = Color(0.78, 0.78, 0.78, 1.0)
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(block, "self_modulate", Color(1.25, 1.25, 1.25, 1.0), 0.6)
	tween.tween_property(block, "self_modulate", Color(0.78, 0.78, 0.78, 1.0), 0.6)
	cell["pulse_tween"] = tween
	cell["pulse_active"] = true

func _stop_solved_pulse(cell: Dictionary) -> void:
	if cell.has("pulse_tween"):
		var tween: Tween = cell["pulse_tween"]
		if tween is Tween:
			tween.kill()
	cell["pulse_tween"] = null
	cell["pulse_active"] = false
	var block: TextureRect = cell["block"]
	block.self_modulate = Color(1, 1, 1, 1.0)

func _ensure_about_panel() -> Control:
	var panel := Control.new()
	panel.name = "AboutPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "AboutBackdrop"
	backdrop.texture = load("res://assets/themes/home_screen.svg") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backdrop)

	var layout := VBoxContainer.new()
	layout.name = "AboutLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var top := HBoxContainer.new()
	top.name = "AboutTopBar"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	layout.add_child(top)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)

	var title_wrap := CenterContainer.new()
	title_wrap.name = "AboutTitleWrap"
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.custom_minimum_size = Vector2(0, 70)
	layout.add_child(title_wrap)

	var title := RichTextLabel.new()
	title.name = "AboutTitle"
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = _rainbow_title("About")
	title.add_theme_font_size_override("normal_font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.add_child(title)

	var center_wrap := CenterContainer.new()
	center_wrap.name = "AboutCenter"
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center_wrap)

	var center := PanelContainer.new()
	center.name = "AboutBox"
	center.custom_minimum_size = Vector2(320, 220)
	center.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center_wrap.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "AboutVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = about_text
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body)
	about_body_label = body

	var spacer := Control.new()
	spacer.name = "AboutSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var home_bar := Control.new()
	home_bar.name = "AboutHomeBar"
	home_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	home_bar.offset_left = 12
	home_bar.offset_right = -12
	home_bar.offset_top = -72
	home_bar.offset_bottom = -12
	panel.add_child(home_bar)

	var home_wrap := CenterContainer.new()
	home_wrap.name = "AboutHomeWrap"
	home_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	home_bar.add_child(home_wrap)

	var home := Button.new()
	home.text = "Home"
	home.custom_minimum_size = Vector2(160, 44)
	home.pressed.connect(func() -> void:
		_show_start_screen()
	)
	_style_start_button(home, Color8(255, 184, 107))
	home_wrap.add_child(home)

	return panel

func _ensure_howto_panel() -> Control:
	var panel := Control.new()
	panel.name = "HowToPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "HowToBackdrop"
	backdrop.texture = load("res://assets/themes/home_screen.svg") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backdrop)

	var layout := VBoxContainer.new()
	layout.name = "HowToLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var top := HBoxContainer.new()
	top.name = "HowToTopBar"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	layout.add_child(top)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)

	var title_wrap := CenterContainer.new()
	title_wrap.name = "HowToTitleWrap"
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.custom_minimum_size = Vector2(0, 70)
	layout.add_child(title_wrap)

	var title := RichTextLabel.new()
	title.name = "HowToTitle"
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = _rainbow_title("How To Play")
	title.add_theme_font_size_override("normal_font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.add_child(title)

	var center_wrap := CenterContainer.new()
	center_wrap.name = "HowToCenter"
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center_wrap)

	var center := PanelContainer.new()
	center.name = "HowToBox"
	center.custom_minimum_size = Vector2(320, 260)
	center.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center_wrap.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "HowToVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = howto_text
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body)
	howto_body_label = body

	var spacer := Control.new()
	spacer.name = "HowToSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var home_bar := Control.new()
	home_bar.name = "HowToHomeBar"
	home_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	home_bar.offset_left = 12
	home_bar.offset_right = -12
	home_bar.offset_top = -72
	home_bar.offset_bottom = -12
	panel.add_child(home_bar)

	var home_wrap := CenterContainer.new()
	home_wrap.name = "HowToHomeWrap"
	home_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	home_bar.add_child(home_wrap)

	var home := Button.new()
	home.text = "Home"
	home.custom_minimum_size = Vector2(160, 44)
	home.pressed.connect(_on_home_pressed)
	_style_start_button(home, Color8(255, 184, 107))
	home_wrap.add_child(home)

	return panel

func _ensure_reset_confirm_popup() -> Control:
	var panel := Control.new()
	panel.name = "ResetConfirmPopup"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 170)
	center.add_child(card)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0, 0, 0, 0.55)
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_left = 14
	card_style.corner_radius_bottom_right = 14
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var label := Label.new()
	label.text = "Reset progress?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	var yes := Button.new()
	yes.text = "Yes"
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_on_reset_confirm_yes)
	_style_start_button(yes, Color8(109, 255, 160))
	buttons.add_child(yes)

	var no := Button.new()
	no.text = "No"
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_on_reset_confirm_no)
	_style_start_button(no, Color8(255, 122, 122))
	buttons.add_child(no)

	return panel

func _input(event: InputEvent) -> void:
	if not input_enabled or is_animating:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		if debug_enabled:
			debug_validation_text = _validate_level(4000)
			_update_hud()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_press(event.position)
		else:
			_handle_release(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_press(event.position)
		else:
			_handle_release(event.position)

func _handle_press(pos: Vector2) -> void:
	var cell := _cell_from_global_pos(pos)
	if cell.x < 0 or cell.y < 0:
		return
	swipe_active = true
	swipe_start_pos = pos
	swipe_start_cell = cell

func _handle_release(pos: Vector2) -> void:
	if not swipe_active:
		return
	swipe_active = false
	var delta := pos - swipe_start_pos
	if delta.length() < SWIPE_THRESHOLD:
		return
	if abs(delta.x) > abs(delta.y):
		var dir := 1 if delta.x > 0.0 else -1
		if debug_enabled:
			_show_debug_line(true, swipe_start_cell.y)
		_start_swipe(true, swipe_start_cell.y, dir)
	else:
		var dir := 1 if delta.y > 0.0 else -1
		if debug_enabled:
			_show_debug_line(false, swipe_start_cell.x)
		_start_swipe(false, swipe_start_cell.x, dir)

func _start_swipe(is_row: bool, index: int, dir: int) -> void:
	if is_animating or not input_enabled:
		return
	var result: Dictionary = _compute_slide(is_row, index, dir)
	if not result.get("moved", false):
		return
	_on_move_feedback()
	is_animating = true
	var moves: Array = result.get("moves", [])
	var next_grid: Array = result.get("grid", [])
	var next_locked: Dictionary = result.get("locked", {})
	var hidden_blocks: Array = []
	var ghosts: Array = []
	if moves.is_empty():
		_finalize_swipe(hidden_blocks, ghosts, next_grid, next_locked)
		return
	_prepare_animation_layer()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for move in moves:
		var from: Vector2i = move["from"]
		var to: Vector2i = move["to"]
		var from_block: TextureRect = cells[from.y][from.x]["block"]
		var ghost := _ghost_from_tile(from_block)
		ghost.global_position = from_block.global_position
		tween.parallel().tween_property(ghost, "global_position", cells[to.y][to.x]["block"].global_position, ANIM_DURATION)
		ghosts.append(ghost)
		hidden_blocks.append(from_block)
		from_block.visible = false
	tween.finished.connect(_finalize_swipe.bind(hidden_blocks, ghosts, next_grid, next_locked))

func _finalize_swipe(hidden_blocks: Array, ghosts: Array, next_grid: Array, next_locked: Dictionary) -> void:
	for ghost in ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	for block in hidden_blocks:
		if is_instance_valid(block):
			block.visible = true
	var newly_locked: Array = []
	for pos in next_locked.keys():
		if not locked.has(pos):
			newly_locked.append(pos)
	grid = next_grid
	locked = next_locked
	_clear_hint_cache()
	moves_made += 1
	_update_tiles()
	if not newly_locked.is_empty():
		_play_sfx(sfx_lock, sfx_lock_player)
	_animate_solved_positions(newly_locked)
	_update_hud()
	if _is_win():
		status_label.text = "Win!"
		_play_sfx(sfx_win, sfx_win_player)
		haptic_success()
		_show_win_celebration()
		input_enabled = false
		_mark_level_complete()
		if current_level_in_stage >= 10:
			_show_stage_complete()
	is_animating = false
	if solving:
		_continue_solution()

func new_level() -> void:
	moves_made = 0
	input_enabled = true
	status_label.text = ""
	is_animating = false
	solving = false
	solve_queue.clear()
	_clear_hint_cache()
	_hide_debug()
	load_level(_level_path_for(current_stage, current_level_in_stage))

func restart_level() -> void:
	moves_made = 0
	input_enabled = true
	status_label.text = ""
	is_animating = false
	solving = false
	solve_queue.clear()
	_clear_hint_cache()
	_hide_debug()
	load_level(_level_path_for(current_stage, current_level_in_stage))

func load_level(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open level: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON level: %s" % path)
		return
	var data: Dictionary = parsed
	current_level_path = path
	current_level_data = data
	_clear_hint_cache()
	_apply_theme_from_level(data)
	width = int(data.get("width", 8))
	height = int(data.get("height", 8))
	palette = _parse_palette(data.get("palette", []))
	if palette.is_empty():
		palette = _default_palette()
	grid = []
	for y in height:
		var row: Array = []
		for x in width:
			row.append(-1)
		grid.append(row)
	walls.clear()
	holes.clear()
	locked.clear()

	for wall_value in data.get("walls", []):
		var pos := _pos_from_value(wall_value)
		if _in_bounds(pos):
			walls[pos] = true

	for hole_value in data.get("holes", []):
		if typeof(hole_value) != TYPE_DICTIONARY:
			continue
		var pos := _pos_from_value(hole_value.get("pos", []))
		var color_id := int(hole_value.get("color", 0))
		if _in_bounds(pos):
			holes[pos] = color_id

	for block_value in data.get("blocks", []):
		if typeof(block_value) != TYPE_DICTIONARY:
			continue
		var pos := _pos_from_value(block_value.get("pos", []))
		var color_id := int(block_value.get("color", 0))
		if _in_bounds(pos) and not walls.has(pos):
			grid[pos.y][pos.x] = color_id

	_refresh_locked()
	_build_grid_nodes()
	_update_tiles()
	if debug_enabled:
		var depth := _solve_depth(2500)
		if depth >= 0:
			debug_validation_text = "ok (%d)" % depth
		else:
			debug_validation_text = "unknown"
	else:
		debug_validation_text = ""
	_apply_difficulty_from_level(data, 2500)
	_update_hud()
	_sync_dev_difficulty_ui()
	_show_game()

func _compute_slide(is_row: bool, index: int, dir: int) -> Dictionary:
	var grid_copy := _clone_grid(grid)
	var locked_copy := locked.duplicate()
	var moves: Array = []
	var moved := false
	if is_row:
		if index < 0 or index >= height:
			return {"moved": false, "moves": moves, "grid": grid_copy, "locked": locked_copy}
		var occupied := {}
		for x in width:
			var pos := Vector2i(x, index)
			if walls.has(pos) or locked_copy.has(pos):
				occupied[x] = true
		var order := range(width - 1, -1, -1) if dir > 0 else range(0, width)
		for x in order:
			var pos := Vector2i(x, index)
			var color_id: int = grid_copy[index][x]
			if color_id == -1 or locked_copy.has(pos):
				continue
			var target: int = x
			while true:
				var next := target + dir
				if next < 0 or next >= width:
					break
				if occupied.has(next):
					break
				target = next
			if target != x:
				grid_copy[index][x] = -1
				grid_copy[index][target] = color_id
				moves.append({"from": pos, "to": Vector2i(target, index), "color": color_id})
				moved = true
			occupied[target] = true
			var tpos := Vector2i(target, index)
			if holes.has(tpos) and holes[tpos] == color_id and not locked_copy.has(tpos):
				locked_copy[tpos] = true
				moved = true
	else:
		if index < 0 or index >= width:
			return {"moved": false, "moves": moves, "grid": grid_copy, "locked": locked_copy}
		var occupied := {}
		for y in height:
			var pos := Vector2i(index, y)
			if walls.has(pos) or locked_copy.has(pos):
				occupied[y] = true
		var order := range(height - 1, -1, -1) if dir > 0 else range(0, height)
		for y in order:
			var pos := Vector2i(index, y)
			var color_id: int = grid_copy[y][index]
			if color_id == -1 or locked_copy.has(pos):
				continue
			var target: int = y
			while true:
				var next := target + dir
				if next < 0 or next >= height:
					break
				if occupied.has(next):
					break
				target = next
			if target != y:
				grid_copy[y][index] = -1
				grid_copy[target][index] = color_id
				moves.append({"from": pos, "to": Vector2i(index, target), "color": color_id})
				moved = true
			occupied[target] = true
			var tpos := Vector2i(index, target)
			if holes.has(tpos) and holes[tpos] == color_id and not locked_copy.has(tpos):
				locked_copy[tpos] = true
				moved = true
	return {"moved": moved, "moves": moves, "grid": grid_copy, "locked": locked_copy}

func _refresh_locked() -> void:
	for pos in holes.keys():
		var p: Vector2i = pos
		if not locked.has(p) and grid[p.y][p.x] == holes[p]:
			locked[p] = true

func _is_win() -> bool:
	for pos in holes.keys():
		var p: Vector2i = pos
		if grid[p.y][p.x] != holes[p]:
			return false
		if not locked.has(p):
			return false
	return true

func _build_grid_nodes() -> void:
	_clear_pulses()
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
			cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var base := _make_rect(cell, Color8(45, 45, 55), 0)
			var hole_outer := _make_rect(cell, Color8(80, 80, 90), 12)
			var hole_inner := _make_rect(cell, Color8(90, 90, 100), 18)
			var block := _make_tile(cell, 6)
			var decal := Label.new()
			decal.text = "★"
			decal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			decal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			decal.set_anchors_preset(Control.PRESET_FULL_RECT)
			decal.mouse_filter = Control.MOUSE_FILTER_IGNORE
			decal.add_theme_font_size_override("font_size", 30)
			decal.add_theme_constant_override("outline_size", 4)
			decal.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			decal.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))
			decal.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			decal.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			decal.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			decal.visible = false
			cell.add_child(decal)
			var wall := _make_wall(cell, 0)
			grid_container.add_child(cell)
			row.append({
				"base": base,
				"hole_outer": hole_outer,
				"hole_inner": hole_inner,
				"decal": decal,
				"block": block,
				"wall": wall,
				"pulse_active": false,
				"pulse_tween": null
			})
		cells.append(row)

func _update_tiles() -> void:
	if cells.is_empty():
		return
	if grid.is_empty() or grid.size() < height:
		return
	if palette.is_empty():
		palette = _default_palette()
	for y in height:
		for x in width:
			var pos := Vector2i(x, y)
			var cell: Dictionary = cells[y][x]
			var base: ColorRect = cell["base"]
			var hole_outer: ColorRect = cell["hole_outer"]
			var hole_inner: ColorRect = cell["hole_inner"]
			var decal: Label = cell["decal"]
			var block: TextureRect = cell["block"]
			var wall: TextureRect = cell["wall"]
			if walls.has(pos):
				wall.visible = true
				wall.modulate = wall_tint_contrast if high_contrast else wall_tint
				hole_outer.visible = false
				hole_inner.visible = false
				block.visible = false
				decal.visible = false
				continue
			wall.visible = false
			if high_contrast:
				base.color = Color8(32, 32, 40)
			else:
				base.color = Color8(45, 45, 55)
			if holes.has(pos):
				var hole_color := palette[holes[pos] % palette.size()]
				hole_outer.color = hole_color.darkened(0.45) if high_contrast else hole_color.darkened(0.3)
				hole_inner.color = hole_color.darkened(0.2) if high_contrast else hole_color.darkened(0.12)
				hole_outer.visible = true
				hole_inner.visible = true
			else:
				hole_outer.visible = false
				hole_inner.visible = false
			var color_id: int = grid[y][x]
			if color_id != -1:
				block.modulate = palette[color_id % palette.size()]
				block.visible = true
				block.self_modulate = Color(1, 1, 1, 1)
				if locked.has(pos):
					decal.visible = true
					decal.modulate = Color(1.5, 1.5, 1.5, 1.0)
					if not bool(cell.get("pulse_active", false)):
						_start_solved_pulse(cell)
				else:
					decal.visible = false
					if bool(cell.get("pulse_active", false)):
						_stop_solved_pulse(cell)
			else:
				block.visible = false
				decal.visible = false
				if bool(cell.get("pulse_active", false)):
					_stop_solved_pulse(cell)
	if debug_enabled:
		_update_debug_overlay()

func _update_hud() -> void:
	var level_text := "Stage %d-%d" % [current_stage, current_level_in_stage]
	if header_label != null:
		header_label.text = current_theme_name
	if subheader_label != null:
		subheader_label.text = "%s - %s | Moves: %d" % [current_level_name, level_text, moves_made]
	if new_level_button != null:
		var can_advance := _can_advance_level()
		new_level_button.disabled = not can_advance
		new_level_button.visible = can_advance

func _can_advance_level() -> bool:
	var completed: int = int(stage_progress.get(str(current_stage), 0))
	var max_unlocked: int = min(completed + 1, 10)
	return current_level_in_stage < max_unlocked

func _cell_from_global_pos(pos: Vector2) -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	for y in height:
		for x in width:
			var cell: Dictionary = cells[y][x]
			var base: ColorRect = cell["base"]
			if base.get_global_rect().has_point(pos):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func _pos_from_value(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)

func _parse_palette(value: Variant) -> Array[Color]:
	var out: Array[Color] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for item in value:
		if typeof(item) == TYPE_STRING:
			out.append(Color.from_string(item, Color.WHITE))
		elif typeof(item) == TYPE_ARRAY and item.size() >= 3:
			out.append(Color8(int(item[0]), int(item[1]), int(item[2])))
	return out

func _default_palette() -> Array[Color]:
	return [
		Color8(60, 120, 220),
		Color8(230, 80, 80),
		Color8(80, 190, 120),
		Color8(230, 200, 70)
	]

func _make_rect(parent: Control, color: Color, padding: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = padding
	rect.offset_top = padding
	rect.offset_right = -padding
	rect.offset_bottom = -padding
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _make_tile(parent: Control, padding: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tile_texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = padding + TILE_OFFSET_BIAS.x
	rect.offset_top = padding + TILE_OFFSET_BIAS.y
	rect.offset_right = -(padding - TILE_OFFSET_BIAS.x)
	rect.offset_bottom = -(padding - TILE_OFFSET_BIAS.y)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _make_wall(parent: Control, padding: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = wall_texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = padding
	rect.offset_top = padding
	rect.offset_right = -padding
	rect.offset_bottom = -padding
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _clone_grid(source: Array) -> Array:
	var out: Array = []
	for row in source:
		out.append(row.duplicate())
	return out

func _validate_level(max_states: int) -> String:
	var start := _clone_grid(grid)
	if _grid_is_win(start):
		return "ok (0)"
	var queue: Array = [start]
	var depth_queue: Array = [0]
	var visited: Dictionary = {}
	visited[_grid_key(start)] = true
	while queue.size() > 0:
		var current: Array = queue.pop_front()
		var depth: int = depth_queue.pop_front()
		for is_row in [true, false]:
			var limit := height if is_row else width
			for index in range(limit):
				for dir in [-1, 1]:
					var result := _simulate_slide(current, is_row, index, dir)
					if not result["moved"]:
						continue
					var next_grid: Array = result["grid"]
					var key := _grid_key(next_grid)
					if visited.has(key):
						continue
					if _grid_is_win(next_grid):
						return "ok (%d)" % (depth + 1)
					visited[key] = true
					if visited.size() >= max_states:
						return "unknown"
					queue.append(next_grid)
					depth_queue.append(depth + 1)
	return "unsolved"

func _solve_depth(max_states: int) -> int:
	var start := _clone_grid(grid)
	if _grid_is_win(start):
		return 0
	var queue: Array = [start]
	var depth_queue: Array = [0]
	var visited: Dictionary = {}
	visited[_grid_key(start)] = true
	while queue.size() > 0:
		var current: Array = queue.pop_front()
		var depth: int = depth_queue.pop_front()
		for is_row in [true, false]:
			var limit := height if is_row else width
			for index in range(limit):
				for dir in [-1, 1]:
					var result := _simulate_slide(current, is_row, index, dir)
					if not result["moved"]:
						continue
					var next_grid: Array = result["grid"]
					var key := _grid_key(next_grid)
					if visited.has(key):
						continue
					if _grid_is_win(next_grid):
						return depth + 1
					visited[key] = true
					if visited.size() >= max_states:
						return -1
					queue.append(next_grid)
					depth_queue.append(depth + 1)
	return -1

func _apply_difficulty_from_level(data: Dictionary, max_states: int) -> void:
	level_difficulty_text = ""
	current_difficulty_label = ""
	var manual_label: Variant = data.get("difficulty_label", null)
	if manual_label is String and String(manual_label) != "":
		current_difficulty_label = String(manual_label)
		level_difficulty_text = "Diff: %s" % current_difficulty_label
		return
	var analysis := _analyze_difficulty(max_states)
	if analysis.has("label"):
		current_difficulty_label = String(analysis["label"])
		level_difficulty_text = "Diff: %s" % current_difficulty_label

func _simulate_slide(source: Array, is_row: bool, index: int, dir: int) -> Dictionary:
	var grid_copy := _clone_grid(source)
	var locked_copy := _locked_from_grid(grid_copy)
	var moved := false
	if is_row:
		if index < 0 or index >= height:
			return {"moved": false, "grid": grid_copy}
		var occupied := {}
		for x in width:
			var pos := Vector2i(x, index)
			if walls.has(pos) or locked_copy.has(pos):
				occupied[x] = true
		var order := range(width - 1, -1, -1) if dir > 0 else range(0, width)
		for x in order:
			var pos := Vector2i(x, index)
			var color_id: int = grid_copy[index][x]
			if color_id == -1 or locked_copy.has(pos):
				continue
			var target: int = x
			while true:
				var next := target + dir
				if next < 0 or next >= width:
					break
				if occupied.has(next):
					break
				target = next
			if target != x:
				grid_copy[index][x] = -1
				grid_copy[index][target] = color_id
				moved = true
			occupied[target] = true
			var tpos := Vector2i(target, index)
			if holes.has(tpos) and holes[tpos] == color_id and not locked_copy.has(tpos):
				locked_copy[tpos] = true
				moved = true
	else:
		if index < 0 or index >= width:
			return {"moved": false, "grid": grid_copy}
		var occupied := {}
		for y in height:
			var pos := Vector2i(index, y)
			if walls.has(pos) or locked_copy.has(pos):
				occupied[y] = true
		var order := range(height - 1, -1, -1) if dir > 0 else range(0, height)
		for y in order:
			var pos := Vector2i(index, y)
			var color_id: int = grid_copy[y][index]
			if color_id == -1 or locked_copy.has(pos):
				continue
			var target: int = y
			while true:
				var next := target + dir
				if next < 0 or next >= height:
					break
				if occupied.has(next):
					break
				target = next
			if target != y:
				grid_copy[y][index] = -1
				grid_copy[target][index] = color_id
				moved = true
			occupied[target] = true
			var tpos := Vector2i(index, target)
			if holes.has(tpos) and holes[tpos] == color_id and not locked_copy.has(tpos):
				locked_copy[tpos] = true
				moved = true
	return {"moved": moved, "grid": grid_copy}

func _locked_from_grid(source: Array) -> Dictionary:
	var out: Dictionary = {}
	for pos in holes.keys():
		var p: Vector2i = pos
		if source[p.y][p.x] == holes[p]:
			out[p] = true
	return out

func _grid_is_win(source: Array) -> bool:
	for pos in holes.keys():
		var p: Vector2i = pos
		if source[p.y][p.x] != holes[p]:
			return false
	return true

func _grid_key(source: Array) -> String:
	var parts: Array[String] = []
	parts.resize(width * height)
	var i := 0
	for y in height:
		for x in width:
			parts[i] = str(source[y][x])
			i += 1
	return ",".join(parts)

func _analyze_difficulty(max_states: int) -> Dictionary:
	var start := _clone_grid(grid)
	var queue: Array = [start]
	var depth_queue: Array = [0]
	var visited: Dictionary = {}
	visited[_grid_key(start)] = true
	var hole_positions: Array = holes.keys()
	var min_moves: Dictionary = {}
	var min_other_locked: Dictionary = {}

	while queue.size() > 0:
		var current: Array = queue.pop_front()
		var depth: int = depth_queue.pop_front()
		var locked_now := _locked_from_grid(current)
		for pos in hole_positions:
			var p: Vector2i = pos
			if not min_moves.has(p) and locked_now.has(p):
				min_moves[p] = depth
				min_other_locked[p] = max(0, locked_now.size() - 1)
		if min_moves.size() == hole_positions.size():
			break
		for is_row in [true, false]:
			var limit := height if is_row else width
			for index in range(limit):
				for dir in [-1, 1]:
					var result := _simulate_slide(current, is_row, index, dir)
					if not result["moved"]:
						continue
					var next_grid: Array = result["grid"]
					var key := _grid_key(next_grid)
					if visited.has(key):
						continue
					visited[key] = true
					if visited.size() >= max_states:
						return {"label": "unknown"}
					queue.append(next_grid)
					depth_queue.append(depth + 1)

	if min_moves.is_empty():
		return {"label": "unknown"}

	var max_min_moves := 0
	var deps := 0
	for pos in hole_positions:
		var p: Vector2i = pos
		var mv := int(min_moves.get(p, 999))
		max_min_moves = max(max_min_moves, mv)
		if int(min_other_locked.get(p, 0)) > 0:
			deps += 1

	if deps == 0:
		if max_min_moves <= 1:
			return {"label": "very easy"}
		return {"label": "easy"}
	if deps == 1:
		if max_min_moves <= 2:
			return {"label": "challenging"}
		return {"label": "hard"}
	return {"label": "very hard"}

func _ensure_animation_layer() -> Control:
	var layer := Control.new()
	layer.name = "AnimationLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_as_top_level(true)
	layer.z_index = 1000
	add_child(layer)
	return layer

func _ensure_debug_layer() -> Control:
	var layer := Control.new()
	layer.name = "DebugLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_as_top_level(true)
	layer.z_index = 900
	add_child(layer)
	return layer

func _prepare_animation_layer() -> void:
	animation_layer.size = get_viewport_rect().size
	animation_layer.position = Vector2.ZERO

func _prepare_debug_layer() -> void:
	debug_layer.size = get_viewport_rect().size
	debug_layer.position = Vector2.ZERO

func _ghost_from_block(block: ColorRect) -> ColorRect:
	var ghost := ColorRect.new()
	ghost.color = block.color
	ghost.size = block.size
	ghost.custom_minimum_size = block.size
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 1000
	ghost.z_as_relative = false
	animation_layer.add_child(ghost)
	return ghost

func _ghost_from_tile(tile: TextureRect) -> TextureRect:
	var ghost := TextureRect.new()
	ghost.texture = tile.texture
	ghost.stretch_mode = TextureRect.STRETCH_SCALE
	ghost.size = tile.size
	ghost.custom_minimum_size = tile.size
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 1000
	ghost.z_as_relative = false
	ghost.modulate = tile.modulate
	ghost.self_modulate = tile.self_modulate
	animation_layer.add_child(ghost)
	return ghost

func _ensure_sfx_player(node_name: String) -> AudioStreamPlayer:
	var existing := get_node_or_null(node_name)
	if existing != null and existing is AudioStreamPlayer:
		return existing as AudioStreamPlayer
	var player := AudioStreamPlayer.new()
	player.name = node_name
	add_child(player)
	return player

func _on_move_feedback() -> void:
	_play_sfx(sfx_move, sfx_move_player)
	haptic_light()

func _play_sfx(stream: AudioStream, player: AudioStreamPlayer) -> void:
	if stream == null or player == null or not sound_enabled:
		return
	player.stream = stream
	player.play()

func haptic_light() -> void:
	var os_name := OS.get_name()
	if os_name == "iOS" or os_name == "Android":
		Input.vibrate_handheld(20)

func haptic_success() -> void:
	var os_name := OS.get_name()
	if os_name == "iOS" or os_name == "Android":
		Input.vibrate_handheld(60)

func _animate_solved_positions(positions: Array) -> void:
	if positions.is_empty():
		return
	_prepare_animation_layer()
	for pos in positions:
		var p: Vector2i = pos
		if not _in_bounds(p):
			continue
		var cell: Dictionary = cells[p.y][p.x]
		var block: TextureRect = cell["block"]
		if not is_instance_valid(block):
			continue
		var pulse := ColorRect.new()
		pulse.color = block.modulate.lightened(0.15)
		pulse.size = block.size
		pulse.custom_minimum_size = block.size
		pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pulse.z_index = 1000
		pulse.z_as_relative = false
		pulse.pivot_offset = block.size * 0.5
		animation_layer.add_child(pulse)
		pulse.global_position = block.global_position
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(pulse, "scale", Vector2(1.25, 1.25), 0.18).from(Vector2(1, 1))
		tween.parallel().tween_property(pulse, "modulate", Color(1, 1, 1, 0), 0.2).from(Color(1, 1, 1, 0.9))
		tween.finished.connect(pulse.queue_free)

func _show_win_celebration() -> void:
	_prepare_animation_layer()
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1100
	overlay.z_as_relative = false
	animation_layer.add_child(overlay)

	var grid_rect := grid_container.get_global_rect()
	var banner_box := PanelContainer.new()
	banner_box.name = "WinBanner"
	banner_box.size = Vector2(grid_rect.size.x * 0.8, 64)
	banner_box.position = grid_rect.position + (grid_rect.size - banner_box.size) * 0.5
	banner_box.modulate = Color(1, 1, 1, 0)
	banner_box.z_index = 1101
	banner_box.z_as_relative = false
	overlay.add_child(banner_box)

	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0, 0, 0, 0.4)
	banner_style.corner_radius_top_left = 14
	banner_style.corner_radius_top_right = 14
	banner_style.corner_radius_bottom_left = 14
	banner_style.corner_radius_bottom_right = 14
	banner_box.add_theme_stylebox_override("panel", banner_style)

	var banner := Label.new()
	banner.text = "Stage Clear!"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_theme_font_size_override("font_size", 36)
	banner_box.add_child(banner)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner_box, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.parallel().tween_property(banner, "scale", Vector2(1.05, 1.05), 0.2).from(Vector2(0.9, 0.9))
	tween.tween_interval(1.4)
	tween.tween_property(banner_box, "modulate", Color(1, 1, 1, 0), 0.45)
	tween.finished.connect(overlay.queue_free)

	_spawn_confetti(overlay)
	var timer1 := get_tree().create_timer(0.35)
	timer1.timeout.connect(_spawn_confetti.bind(overlay))
	var timer2 := get_tree().create_timer(0.7)
	timer2.timeout.connect(_spawn_confetti.bind(overlay))
	var timer3 := get_tree().create_timer(1.05)
	timer3.timeout.connect(_spawn_confetti.bind(overlay))

func _spawn_confetti(parent: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rect := grid_container.get_global_rect()
	for i in range(45):
		var piece := ColorRect.new()
		piece.color = palette[i % palette.size()] if palette.size() > 0 else Color8(220, 220, 220)
		piece.size = Vector2(8, 8)
		piece.custom_minimum_size = Vector2(8, 8)
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.z_index = 1100
		piece.z_as_relative = false
		parent.add_child(piece)
		piece.global_position = Vector2(
			rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
			rect.position.y - 12.0
		)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var fall := piece.global_position + Vector2(rng.randf_range(-40, 40), rng.randf_range(120, 220))
		tween.tween_property(piece, "global_position", fall, 0.9)
		tween.parallel().tween_property(piece, "modulate", Color(1, 1, 1, 0), 0.9).from(Color(1, 1, 1, 1))
		tween.finished.connect(piece.queue_free)

func _show_debug_line(is_row: bool, index: int) -> void:
	_prepare_debug_layer()
	_clear_children(debug_layer)
	if is_row:
		for x in width:
			var pos := Vector2i(x, index)
			_add_debug_cell(pos)
	else:
		for y in height:
			var pos := Vector2i(index, y)
			_add_debug_cell(pos)
	var timer := get_tree().create_timer(0.25)
	timer.timeout.connect(_hide_debug)

func _add_debug_cell(pos: Vector2i) -> void:
	var cell: Dictionary = cells[pos.y][pos.x]
	var rect := ColorRect.new()
	rect.color = _debug_color_for(pos)
	rect.size = cell["base"].size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 900
	debug_layer.add_child(rect)
	rect.global_position = cell["base"].global_position

func _debug_color_for(pos: Vector2i) -> Color:
	if walls.has(pos):
		return Color(0.85, 0.15, 0.15, 0.45)
	if locked.has(pos):
		return Color(0.9, 0.7, 0.2, 0.35)
	if grid[pos.y][pos.x] != -1:
		return Color(0.2, 0.6, 0.9, 0.25)
	return Color(0.1, 0.9, 0.4, 0.15)

func _hide_debug() -> void:
	if debug_layer != null and is_instance_valid(debug_layer):
		_clear_children(debug_layer)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _update_debug_overlay() -> void:
	# placeholder so we can extend later if needed
	pass

func _build_level_paths() -> void:
	level_paths = []
	for i in range(1, 101):
		level_paths.append("res://levels/level_%02d.json" % i)

func _level_path_for(stage: int, level_in_stage: int) -> String:
	var index := (stage - 1) * 10 + (level_in_stage - 1)
	if index < 0 or index >= level_paths.size():
		return ""
	return level_paths[index]

func _mark_level_complete() -> void:
	var key := str(current_stage)
	var current_max := int(stage_progress.get(key, 0))
	if current_level_in_stage > current_max:
		stage_progress[key] = current_level_in_stage
	_save_progress()
	if current_level_in_stage >= 10 and current_stage == unlocked_stage and current_stage < 10:
		unlocked_stage += 1
	_save_progress()
	_update_stage_buttons()
	_update_hud()

func _load_progress() -> void:
	stage_progress = {}
	unlocked_stage = 1
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	unlocked_stage = int(data.get("unlocked_stage", 1))
	var prog: Variant = data.get("stage_progress", {})
	if typeof(prog) == TYPE_DICTIONARY:
		for key in prog.keys():
			stage_progress[str(key)] = int(prog[key])

func _save_progress() -> void:
	var data := {
		"unlocked_stage": unlocked_stage,
		"stage_progress": stage_progress
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))

func _save_current_level_data() -> void:
	if current_level_path == "":
		return
	var file := FileAccess.open(current_level_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(current_level_data, "  "))

func _load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	sound_enabled = bool(data.get("sound_enabled", true))
	_sync_settings_ui()

func _sync_settings_ui() -> void:
	var sound := options_panel.get_node_or_null("OptionsLayout/OptionsCenter/OptionsBox/OptionsVBox/SoundCheck") as CheckButton
	if sound != null:
		sound.button_pressed = sound_enabled

func _save_settings() -> void:
	var data := {
		"sound_enabled": sound_enabled
	}
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))

func _ensure_stage_panel() -> Control:
	var panel := Control.new()
	panel.name = "StagePanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var backdrop := ColorRect.new()
	backdrop.name = "StageBackdrop"
	backdrop.color = Color(0.08, 0.1, 0.14, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backdrop)

	var vignette := ColorRect.new()
	vignette.name = "StageVignette"
	vignette.color = Color(0, 0, 0, 0.18)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vignette)

	var vbox := VBoxContainer.new()
	vbox.name = "StagePanelVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.name = "StageTopBar"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	vbox.add_child(top)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)

	var title_wrap := CenterContainer.new()
	title_wrap.name = "StageTitleWrap"
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.custom_minimum_size = Vector2(0, 70)
	vbox.add_child(title_wrap)

	var title := RichTextLabel.new()
	title.name = "StageTitle"
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = _rainbow_title("Select Stage")
	title.add_theme_font_size_override("normal_font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.add_child(title)

	var grid_margin := MarginContainer.new()
	grid_margin.name = "StageGridMargin"
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid_margin.add_theme_constant_override("margin_left", 12)
	grid_margin.add_theme_constant_override("margin_right", 12)
	grid_margin.add_theme_constant_override("margin_top", 28)
	grid_margin.add_theme_constant_override("margin_bottom", 84)
	vbox.add_child(grid_margin)

	var grid := GridContainer.new()
	grid.name = "StageGrid"
	grid.columns = STAGE_GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hsep := 32
	var vsep := 32
	grid.add_theme_constant_override("hseparation", hsep)
	grid.add_theme_constant_override("vseparation", vsep)
	var rows := int(ceil(10.0 / float(grid.columns)))
	grid.custom_minimum_size = Vector2(0, rows * STAGE_CARD_HEIGHT + max(0, rows - 1) * vsep)
	grid_margin.add_child(grid)

	for i in range(1, 11):
		var btn := Button.new()
		btn.name = "StageButton%d" % i
		btn.text = ""
		btn.flat = false
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(0, STAGE_CARD_HEIGHT)
		btn.pressed.connect(_on_stage_pressed.bind(i))
		grid.add_child(btn)

		var content := VBoxContainer.new()
		content.name = "StageContent%d" % i
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 8)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		btn.add_child(content)

		var name_label := Label.new()
		name_label.name = "StageName%d" % i
		name_label.text = "Stage %d" % i
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(name_label)

		var theme_label := Label.new()
		theme_label.name = "StageTheme%d" % i
		theme_label.text = ""
		theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		theme_label.add_theme_font_size_override("font_size", 14)
		theme_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(theme_label)

		var progress := ProgressBar.new()
		progress.name = "StageProgress%d" % i
		progress.min_value = 0
		progress.max_value = 10
		progress.value = 0
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		progress.custom_minimum_size = Vector2(0, 12)
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(progress)

		var lock_label := Label.new()
		lock_label.name = "StageLocked%d" % i
		lock_label.text = "Locked"
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.add_theme_font_size_override("font_size", 12)
		lock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock_label.visible = false
		content.add_child(lock_label)
	var spacer := Control.new()
	spacer.name = "StageSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var home_bar := Control.new()
	home_bar.name = "StageHomeBar"
	home_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	home_bar.offset_left = 12
	home_bar.offset_right = -12
	home_bar.offset_top = -72
	home_bar.offset_bottom = -12
	panel.add_child(home_bar)

	var home_wrap := CenterContainer.new()
	home_wrap.name = "StageHomeWrap"
	home_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	home_bar.add_child(home_wrap)

	var home := Button.new()
	home.name = "StageHomeButton"
	home.text = "Home"
	home.custom_minimum_size = Vector2(160, 44)
	home.pressed.connect(_on_home_pressed)
	_style_start_button(home, Color8(83, 201, 255))
	home_wrap.add_child(home)
	return panel

func _update_stage_buttons() -> void:
	var grid := stage_panel.get_node_or_null("StagePanelVBox/StageGridMargin/StageGrid") as GridContainer
	if grid == null:
		grid = stage_panel.get_node_or_null("StagePanelVBox/StageGridMargin/StageGridScroll/StageGrid") as GridContainer
	if grid == null:
		return
	for i in range(1, 11):
		var completed := int(stage_progress.get(str(i), 0))
		var btn := grid.get_node("StageButton%d" % i) as Button
		var name_label := grid.get_node("StageButton%d/StageContent%d/StageName%d" % [i, i, i]) as Label
		var theme_label := grid.get_node("StageButton%d/StageContent%d/StageTheme%d" % [i, i, i]) as Label
		var progress := grid.get_node("StageButton%d/StageContent%d/StageProgress%d" % [i, i, i]) as ProgressBar
		var lock_label := grid.get_node("StageButton%d/StageContent%d/StageLocked%d" % [i, i, i]) as Label
		var theme_index: int = clampi(i - 1, 0, THEME_NAMES.size() - 1)
		if btn == null or name_label == null or progress == null:
			continue
		name_label.text = "Stage %d" % i
		if theme_label != null:
			theme_label.text = THEME_NAMES[theme_index]
		progress.value = completed
		var locked := i > unlocked_stage
		btn.disabled = locked
		_style_stage_card(btn, theme_index, locked)
		if lock_label != null:
			lock_label.visible = locked
			lock_label.text = "Locked" if locked else ""

func _show_stage_select() -> void:
	stage_panel.visible = true
	level_panel.visible = false
	stage_complete_popup.visible = false
	start_panel.visible = false
	about_panel.visible = false
	options_panel.visible = false
	game_panel.visible = false
	safe_area.visible = false
	input_enabled = false
	status_label.text = ""
	_apply_menu_theme(current_stage)

func _show_game() -> void:
	stage_panel.visible = false
	level_panel.visible = false
	stage_complete_popup.visible = false
	start_panel.visible = false
	about_panel.visible = false
	options_panel.visible = false
	game_panel.visible = true
	safe_area.visible = true
	input_enabled = true

func _on_stage_pressed(stage: int) -> void:
	current_stage = stage
	_show_level_select()

func _on_stages_pressed() -> void:
	_show_stage_select()

func _ensure_hbox_button(node_name: String, text_value: String) -> Button:
	var existing := hbox.get_node_or_null(node_name)
	if existing != null:
		return existing
	var btn := Button.new()
	btn.name = node_name
	btn.text = text_value
	btn.size_flags_horizontal = Control.SIZE_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn)
	return btn

func _ensure_level_panel() -> Control:
	var panel := Control.new()
	panel.name = "LevelPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := ColorRect.new()
	backdrop.name = "LevelBackdrop"
	backdrop.color = Color(0.08, 0.1, 0.14, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backdrop)

	var vignette := ColorRect.new()
	vignette.name = "LevelVignette"
	vignette.color = Color(0, 0, 0, 0.18)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vignette)

	var vbox := VBoxContainer.new()
	vbox.name = "LevelPanelVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.name = "LevelTopBar"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	vbox.add_child(top)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)

	var title_wrap := CenterContainer.new()
	title_wrap.name = "LevelTitleWrap"
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.custom_minimum_size = Vector2(0, 70)
	vbox.add_child(title_wrap)

	var title := RichTextLabel.new()
	title.name = "LevelTitle"
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = _rainbow_title("Select Level")
	title.add_theme_font_size_override("normal_font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.add_child(title)

	var grid := GridContainer.new()
	grid.name = "LevelGrid"
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("hseparation", 10)
	grid.add_theme_constant_override("vseparation", 10)
	vbox.add_child(grid)

	for i in range(1, 11):
		var btn := Button.new()
		btn.name = "LevelButton%d" % i
		btn.text = "Level %d" % i
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_on_level_pressed.bind(i))
		grid.add_child(btn)

		var badge := Label.new()
		badge.name = "LevelBadge%d" % i
		badge.text = ""
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	var spacer := Control.new()
	spacer.name = "LevelSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var home_bar := Control.new()
	home_bar.name = "LevelHomeBar"
	home_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	home_bar.offset_left = 12
	home_bar.offset_right = -12
	home_bar.offset_top = -72
	home_bar.offset_bottom = -12
	panel.add_child(home_bar)

	var home_wrap := CenterContainer.new()
	home_wrap.name = "LevelHomeWrap"
	home_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	home_bar.add_child(home_wrap)

	var home := Button.new()
	home.name = "LevelHomeButton"
	home.text = "Home"
	home.custom_minimum_size = Vector2(160, 44)
	home.pressed.connect(_on_home_pressed)
	_style_start_button(home, Color8(83, 201, 255))
	home_wrap.add_child(home)
	return panel

func _show_level_select() -> void:
	stage_panel.visible = false
	level_panel.visible = true
	game_panel.visible = false
	stage_complete_popup.visible = false
	start_panel.visible = false
	about_panel.visible = false
	options_panel.visible = false
	safe_area.visible = false
	input_enabled = false
	var title := level_panel.get_node("LevelPanelVBox/LevelTitleWrap/LevelTitle") as RichTextLabel
	if title != null:
		title.text = _rainbow_title("Stage %d" % current_stage)
	_update_level_buttons()
	_apply_menu_theme(current_stage)

func _update_level_buttons() -> void:
	var grid := level_panel.get_node("LevelPanelVBox/LevelGrid") as GridContainer
	if grid == null:
		return
	var completed := int(stage_progress.get(str(current_stage), 0))
	var theme_index: int = clampi(current_stage - 1, 0, THEME_ACCENTS.size() - 1)
	for i in range(1, 11):
		var btn := grid.get_node("LevelButton%d" % i) as Button
		if btn == null:
			continue
		btn.text = "Level %d" % i
		var locked: bool = i > min(completed + 1, 10)
		btn.disabled = locked
		_style_level_button(btn, theme_index, locked)
		var badge := btn.get_node_or_null("LevelBadge%d" % i) as Label
		if badge != null:
			badge.text = "✓" if i <= completed else ""

func _on_level_pressed(level_in_stage: int) -> void:
	current_level_in_stage = level_in_stage
	new_level()

func _ensure_stage_complete_popup() -> Control:
	var panel := Control.new()
	panel.name = "StageCompletePopup"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var center := CenterContainer.new()
	center.name = "StageCompleteCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(center)

	var card := PanelContainer.new()
	card.name = "StageCompletePanel"
	card.custom_minimum_size = Vector2(320, 170)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.name = "StageCompleteVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var label := Label.new()
	label.name = "StageCompleteLabel"
	label.text = "Stage Complete!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.name = "StageCompleteButtons"
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)

	var back := Button.new()
	back.name = "StageCompleteButton"
	back.text = "Back to Stages"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_on_stage_complete_pressed)
	_style_start_button(back, Color8(83, 201, 255))
	buttons.add_child(back)

	var next := Button.new()
	next.name = "StageCompleteNextButton"
	next.text = "Next Stage"
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(_on_stage_complete_next_pressed)
	_style_start_button(next, Color8(109, 255, 160))
	buttons.add_child(next)
	return panel

func _show_stage_complete() -> void:
	stage_complete_popup.visible = true
	game_panel.visible = true
	input_enabled = false
	var label := stage_complete_popup.get_node_or_null("StageCompleteCenter/StageCompletePanel/StageCompleteVBox/StageCompleteLabel") as Label
	var next := stage_complete_popup.get_node_or_null("StageCompleteCenter/StageCompletePanel/StageCompleteVBox/StageCompleteButtons/StageCompleteNextButton") as Button
	if current_stage >= 10:
		if label != null:
			label.text = "All Stages Complete!"
		if next != null:
			next.visible = false
	else:
		if label != null:
			label.text = "Stage Complete!"
		if next != null:
			next.visible = true

func _on_stage_complete_pressed() -> void:
	_show_stage_select()

func _on_stage_complete_next_pressed() -> void:
	if current_stage < 10:
		current_stage += 1
		current_level_in_stage = 1
		new_level()

func _show_start_screen() -> void:
	stage_panel.visible = false
	level_panel.visible = false
	stage_complete_popup.visible = false
	if reset_confirm_popup != null:
		reset_confirm_popup.visible = false
	about_panel.visible = false
	howto_panel.visible = false
	options_panel.visible = false
	game_panel.visible = false
	start_panel.visible = true
	safe_area.visible = false
	input_enabled = false
	status_label.text = ""

func _on_home_pressed() -> void:
	_show_start_screen()

func _on_solve_pressed() -> void:
	if is_animating:
		return
	var result := _solve_level_status(20000)
	var path: Array = result["path"]
	if path.is_empty():
		if bool(result.get("capped", false)):
			status_label.text = "Search limit reached"
		else:
			status_label.text = "No solution found"
		return
	solving = true
	solve_queue = path
	status_label.text = "Solving..."
	_continue_solution()

func _continue_solution() -> void:
	if not solving:
		return
	if is_animating:
		return
	if solve_queue.is_empty():
		solving = false
		status_label.text = ""
		return
	var move: Dictionary = solve_queue.pop_front()
	_start_swipe(move["is_row"], move["index"], move["dir"])

func _solve_level_status(max_states: int) -> Dictionary:
	var start := _clone_grid(grid)
	var start_key := _grid_key(start)
	if _grid_is_win(start):
		return {"path": [], "capped": false}
	var open: Array = []
	var parent: Dictionary = {}
	var move_from: Dictionary = {}
	var g_score: Dictionary = {}
	parent[start_key] = ""
	g_score[start_key] = 0
	open.append({
		"grid": start,
		"key": start_key,
		"g": 0,
		"f": _heuristic(start)
	})
	var visited: Dictionary = {}
	var expanded := 0

	while open.size() > 0:
		open.sort_custom(Callable(self, "_open_sort"))
		var node: Dictionary = open.pop_front()
		var current: Array = node["grid"]
		var current_key: String = node["key"]
		if visited.has(current_key):
			continue
		visited[current_key] = true
		expanded += 1
		if expanded >= max_states:
			return {"path": [], "capped": true}
		for is_row in [true, false]:
			var limit := height if is_row else width
			for index in range(limit):
				for dir in [-1, 1]:
					var result := _simulate_slide(current, is_row, index, dir)
					if not result["moved"]:
						continue
					var next_grid: Array = result["grid"]
					var key := _grid_key(next_grid)
					var new_g: int = int(node["g"]) + 1
					if g_score.has(key) and new_g >= int(g_score[key]):
						continue
					parent[key] = current_key
					move_from[key] = {"is_row": is_row, "index": index, "dir": dir}
					if _grid_is_win(next_grid):
						return {"path": _reconstruct_path(start_key, key, parent, move_from), "capped": false}
					g_score[key] = new_g
					var h: int = _heuristic(next_grid)
					open.append({
						"grid": next_grid,
						"key": key,
						"g": new_g,
						"f": new_g + h
					})
	return {"path": [], "capped": false}

func _open_sort(a: Dictionary, b: Dictionary) -> bool:
	return int(a["f"]) < int(b["f"])

func _heuristic(state: Array) -> int:
	var total := 0
	for pos in holes.keys():
		var p: Vector2i = pos
		var color_id: int = holes[p]
		var best := 2
		for y in height:
			for x in width:
				if state[y][x] != color_id:
					continue
				if x == p.x and y == p.y:
					best = 0
					break
				if x == p.x or y == p.y:
					best = min(best, 1)
			if best == 0:
				break
		total += best
	return total

func _reconstruct_path(start_key: String, end_key: String, parent: Dictionary, move_from: Dictionary) -> Array:
	var path: Array = []
	var key := end_key
	while key != start_key:
		if not move_from.has(key):
			break
		path.append(move_from[key])
		key = parent[key]
	path.reverse()
	return path

func _on_new_level_pressed() -> void:
	if not _can_advance_level():
		status_label.text = "Unlock the next level first"
		return
	current_level_in_stage += 1
	new_level()

func _on_restart_pressed() -> void:
	restart_level()
