extends Control

const SWIPE_THRESHOLD := 20.0
const DEFAULT_CELL_SIZE := 72
const STAGE_COUNT := 10
const LEVELS_PER_STAGE := 20
const STAGE_CARD_HEIGHT := 140
const STAGE_GRID_COLUMNS := 2
const LEVEL_GRID_COLUMNS := 4
const LEVEL_BUTTON_WIDTH := 96
const LEVEL_BUTTON_HEIGHT := 78
const ANIM_DURATION := 0.18
const SAVE_PATH := "user://progress.json"
const TILE_TEXTURE_PATH := "res://assets/tiles/tile_base.svg"
const WALL_TEXTURE_PATH := "res://assets/tiles/wall_block3.svg"
const DIFFICULTY_LABELS := ["easy", "fun", "challenging", "hard"]
const DIFFICULTY_VALUES := {
	"easy": 1,
	"fun": 2,
	"challenging": 3,
	"hard": 4
}
const THEME_TEXTURES := [
	"res://assets/bg/bg_gameplay.png",
	"res://assets/bg/bg_gameplay.png",
	"res://assets/bg/bg_gameplay.png",
	"res://assets/bg/bg_gameplay.png",
	"res://assets/bg/bg_gameplay.png",
	"res://assets/bg/bg_gameplay.png",
	"res://assets/bg/bg_gameplay.png",
	"res://assets/bg/bg_gameplay.png",
	"res://assets/bg/bg_gameplay.png",
	"res://assets/bg/bg_gameplay.png",
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
const HINT_STEPS_PER_FRAME := 200
const HINT_MAX_STATES := 8000
const FREE_HINTS_PER_LEVEL := 1
const FREE_HINTS_PER_DAY := 1
const FREE_HINTS_STAGE := 1
const UI_PRESS_SCALE := 0.96
const UI_PRESS_TIME := 0.06
const UI_RELEASE_TIME := 0.12
const UI_GLOW_MULT := 1.08

@export var sfx_move: AudioStream
@export var sfx_lock: AudioStream
@export var sfx_win: AudioStream
@export var sfx_no_solution: AudioStream
@export var sfx_ui_click: AudioStream
@export var sfx_ui_success: AudioStream
@export var tile_texture: Texture2D
@export var wall_texture: Texture2D
@export var dev_mode := false
@export var sound_enabled := true
@export var music_enabled := true
@export var music_volume_db := -8.0
@export var diagnostics_enabled := false
@export_multiline var about_text: String = "Shiftline is a sliding puzzle about\nmatching colors and finding order.\nMade for iOS."
@export_multiline var howto_text: String = "[center][b]How to Play[/b][/center]\n\n- Swipe a row or column to slide blocks.\n- Blocks slide until they hit a wall or another locked block.\n- Match blocks to same-colored holes to lock them.\n- Lock all blocks to win.\n\nTip: Use Hint if you get stuck."
@export var button_font: Font
@export var wall_tint: Color = Color(1, 1, 1, 1)
@export var wall_tint_contrast: Color = Color(1, 1, 1, 1)
@export var hints_unlocked := false
@export var iap_hint_product_id: String = ""

@onready var background_rect: TextureRect = $Background
@onready var safe_area: MarginContainer = $SafeArea
@onready var game_panel: Control = $SafeArea/VBoxContainer
@onready var header_label: RichTextLabel = $SafeArea/VBoxContainer/TopBarCard/TopBar/HeaderLabel
@onready var subheader_label: Label = $SafeArea/VBoxContainer/TopBarCard/TopBar/SubHeaderLabel
@onready var grid_container: GridContainer = $SafeArea/VBoxContainer/CenterContainer/GridContainer
@onready var moves_label: Label = $SafeArea/VBoxContainer/TopBarCard/TopBar/SubHeaderLabel
@onready var status_label: Label = $SafeArea/VBoxContainer/StatusLabel
@onready var hbox: HBoxContainer = $SafeArea/VBoxContainer/HBoxContainer
@onready var new_level_button: Button = $SafeArea/VBoxContainer/NextLevelWrap/NewLevelButton
@onready var restart_button: Button = $SafeArea/VBoxContainer/HBoxContainer/RestartButton
@onready var solve_button: Button = _ensure_hbox_button("SolveButton", "Solve")
@onready var hint_button: Button = _ensure_hbox_button("HintButton", "Hint")
@onready var stages_button: Button = _ensure_hbox_button("StagesButton", "Stages")
@onready var options_button: Button = _ensure_hbox_button("OptionsButton", "Options")
@onready var home_button: Button = _ensure_hbox_button("HomeButton", "Home")
@onready var editor_back_button: Button = _ensure_hbox_button("BackToEditorButton", "Back to Editor")
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
@onready var sfx_ui_player: AudioStreamPlayer = _ensure_sfx_player("SfxUI")
@onready var sfx_ui_success_player: AudioStreamPlayer = _ensure_sfx_player("SfxUISuccess")
@onready var music_player: AudioStreamPlayer = _ensure_music_player("MusicPlayer")

var width := 8
var height := 8
var palette: Array[Color] = []
var grid: Array = []
var walls: Dictionary = {}
var holes: Dictionary = {}
var bouncers: Dictionary = {}
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
var hint_job_active := false
var hint_job_token := 0
var hint_job_start_key: String = ""
var hint_job: Dictionary = {}
var hint_consume_pending := false
var hint_consume_key: String = ""
var hint_uses_by_level: Dictionary = {}
var daily_hint_date: String = ""
var daily_hint_used := 0
var iap_singleton: Object = null
var iap_provider: String = ""
var iap_hint_display_price: String = ""
var iap_poll_timer: Timer = null

func _is_ios() -> bool:
	return OS.get_name() == "iOS"

func _find_iap_singleton() -> void:
	iap_singleton = null
	iap_provider = ""
	var candidates: PackedStringArray = PackedStringArray(["InAppStore", "IOSInAppPurchase", "InAppPurchase"])
	for name in candidates:
		if Engine.has_singleton(name):
			iap_singleton = Engine.get_singleton(name)
			iap_provider = name
			return
	var singletons: PackedStringArray = Engine.get_singleton_list()
	for name in singletons:
		var lower := name.to_lower()
		if lower.find("app") != -1 and (lower.find("store") != -1 or lower.find("inapp") != -1 or lower.find("purchase") != -1):
			iap_singleton = Engine.get_singleton(name)
			iap_provider = name
			return
var music_tracks: Array = []
var music_track_paths: Array = []
var current_music_index := -1
var about_body_label: RichTextLabel = null
var howto_body_label: RichTextLabel = null
var glow_textures: Dictionary = {}
var sparkle_rng := RandomNumberGenerator.new()
var win_rng := RandomNumberGenerator.new()
var ui_rng := RandomNumberGenerator.new()
var music_rng := RandomNumberGenerator.new()
var level_stats: Dictionary = {}
var level_start_time_msec: int = 0
var current_level_min_moves: int = -1
var hide_blocks_for_anim := false
var editor_preview_active := false
var editor_preview_path := ""
var next_level_countdown_active := false
var next_level_countdown_left := 0
var next_level_countdown_token := 0
var level_intro_running := false

var swipe_active := false
var swipe_start_pos := Vector2.ZERO
var swipe_start_cell := Vector2i(-1, -1)

func _ready() -> void:
	sparkle_rng.randomize()
	win_rng.randomize()
	ui_rng.randomize()
	music_rng.randomize()
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
	if editor_back_button != null:
		editor_back_button.pressed.connect(_on_back_to_editor_pressed)
	_style_ui()
	if background_rect != null:
		_apply_background_cover(background_rect)
	_setup_dev_ui()
	_ensure_tile_texture()
	_ensure_wall_texture()
	_ensure_ui_sfx()
	_update_about_text()
	_update_howto_text()
	_load_settings()
	_setup_music()
	_setup_iap()
	_build_level_paths()
	_load_progress()
	_update_stage_buttons()
	_check_editor_preview()
	if editor_preview_active:
		load_level(editor_preview_path)
		return
	_show_start_screen()

func _style_ui() -> void:
	var top_bar_card := get_node_or_null("SafeArea/VBoxContainer/TopBarCard") as PanelContainer
	if top_bar_card != null:
		_apply_glass_panel_compact(top_bar_card)
	if header_label != null:
		header_label.bbcode_enabled = true
		header_label.fit_content = true
		header_label.scroll_active = false
		header_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header_label.add_theme_font_size_override("normal_font_size", 46)
	if subheader_label != null:
		subheader_label.add_theme_font_size_override("font_size", 18)
	if status_label != null:
		status_label.add_theme_font_size_override("font_size", 20)
	if new_level_button != null:
		new_level_button.custom_minimum_size = Vector2(220, 60)
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
			btn.add_theme_font_size_override("font_size", 18)
			btn.custom_minimum_size = Vector2(0, 58)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_start_button(btn, button_colors[color_index % button_colors.size()])
			color_index += 1
	if editor_back_button != null:
		_style_start_button(editor_back_button, Color8(183, 109, 255))
	if solve_button != null:
		solve_button.visible = dev_mode
	if hint_button != null:
		hint_button.visible = true
	if editor_back_button != null:
		editor_back_button.visible = false
	if options_button != null:
		options_button.visible = false

func _get_glow_texture(size: int, color: Color) -> Texture2D:
	var key: String = "%d_%s" % [size, color.to_html()]
	if glow_textures.has(key):
		return glow_textures[key]
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var radius: float = center.x
	for y in size:
		for x in size:
			var dist: float = Vector2(x, y).distance_to(center) / radius
			var alpha: float = clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha * color.a))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	glow_textures[key] = tex
	return tex

func _ensure_start_twinkles() -> void:
	if start_panel == null:
		return
	var layer := start_panel.get_node_or_null("StartTwinkleLayer") as Control
	if layer == null:
		layer = Control.new()
		layer.name = "StartTwinkleLayer"
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_panel.add_child(layer)
		var backdrop := start_panel.get_node_or_null("StartBackdrop") as CanvasItem
		if backdrop != null:
			var idx: int = backdrop.get_index()
			start_panel.move_child(layer, idx + 1)
		_create_twinkle(layer, Vector2(0.22, 0.28), 260, Color(0.42, 0.9, 1.0, 0.95))
		_create_twinkle(layer, Vector2(0.7, 0.18), 220, Color(0.75, 0.6, 1.0, 0.85))
		_create_twinkle(layer, Vector2(0.6, 0.82), 280, Color(1.0, 0.85, 0.5, 0.85))

func _create_twinkle(layer: Control, pos_ratio: Vector2, size: float, color: Color) -> void:
	var node := TextureRect.new()
	node.texture = _get_glow_texture(128, color)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size = Vector2(size, size)
	node.pivot_offset = node.size * 0.5
	var view_size: Vector2 = start_panel.size
	if view_size == Vector2.ZERO:
		view_size = get_viewport_rect().size
	node.position = Vector2(view_size.x * pos_ratio.x, view_size.y * pos_ratio.y) - node.pivot_offset
	node.modulate = Color(1, 1, 1, 1.0)
	node.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	layer.add_child(node)
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var low: float = color.a * 0.55
	var high: float = min(color.a * 1.2, 1.0)
	var t1: float = sparkle_rng.randf_range(0.9, 1.5)
	var t2: float = sparkle_rng.randf_range(0.9, 1.5)
	tween.tween_property(node, "modulate:a", high, t1).from(low)
	tween.tween_property(node, "modulate:a", low, t2)

func _play_start_sparkles() -> void:
	if start_panel == null:
		return
	var layer := start_panel.get_node_or_null("StartTwinkleLayer") as Control
	if layer == null:
		return
	for i in range(16):
		var size := sparkle_rng.randf_range(22.0, 48.0)
		var color := Color(1, 1, 1, sparkle_rng.randf_range(0.7, 1.0))
		var sparkle := TextureRect.new()
		sparkle.texture = _get_glow_texture(64, color)
		sparkle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sparkle.stretch_mode = TextureRect.STRETCH_SCALE
		sparkle.size = Vector2(size, size)
		sparkle.pivot_offset = sparkle.size * 0.5
		var view_size: Vector2 = start_panel.size
		if view_size == Vector2.ZERO:
			view_size = get_viewport_rect().size
		var px := sparkle_rng.randf_range(view_size.x * 0.15, view_size.x * 0.85)
		var py := sparkle_rng.randf_range(view_size.y * 0.15, view_size.y * 0.55)
		sparkle.position = Vector2(px, py) - sparkle.pivot_offset
		sparkle.modulate = Color(1, 1, 1, 0.0)
		layer.add_child(sparkle)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var rise := sparkle_rng.randf_range(0.4, 0.8)
		tween.tween_property(sparkle, "modulate:a", color.a, 0.9).from(0.0)
		tween.tween_property(sparkle, "modulate:a", 0.0, 1.5).set_delay(0.15)
		tween.tween_property(sparkle, "scale", Vector2(1.35, 1.35), rise * 3.0).from(Vector2.ONE)
		tween.finished.connect(sparkle.queue_free)

func _apply_background_cover(rect: TextureRect) -> void:
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

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
	var target_label := _normalize_difficulty_label(current_difficulty_label)
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
	current_level_data["difficulty"] = int(DIFFICULTY_VALUES.get(label, index + 1))
	current_level_data["difficulty_label"] = label
	current_level_data["difficulty_manual"] = true
	_save_current_level_data()
	_apply_difficulty_from_level(current_level_data, 2500)
	_sync_dev_difficulty_ui()

func _on_sound_toggled(pressed: bool) -> void:
	sound_enabled = pressed
	_save_settings()
	_sync_settings_ui()

func _setup_iap() -> void:
	if not _is_ios():
		iap_singleton = null
		iap_provider = ""
		iap_hint_display_price = ""
		if iap_poll_timer != null:
			iap_poll_timer.stop()
		_update_start_panel_unlock_button()
		_update_start_panel_restore_button()
		_update_diagnostics_label()
		return
	_find_iap_singleton()
	if iap_singleton == null:
		iap_hint_display_price = ""
		if iap_poll_timer != null:
			iap_poll_timer.stop()
		_update_start_panel_unlock_button()
		_update_start_panel_restore_button()
		_update_diagnostics_label()
		return
	if iap_provider == "InAppStore":
		var callable_store := Callable(self, "_on_iap_event")
		if iap_singleton.has_signal("in_app_store") and not iap_singleton.is_connected("in_app_store", callable_store):
			iap_singleton.connect("in_app_store", callable_store)
		if iap_singleton.has_method("set_auto_finish_transaction"):
			iap_singleton.set_auto_finish_transaction(true)
		_ensure_iap_poll_timer()
		_iap_request_products()
		_iap_restore_purchases()
	elif iap_provider == "IOSInAppPurchase":
		if iap_poll_timer != null:
			iap_poll_timer.stop()
		var callable_plugin := Callable(self, "_on_iap_response")
		if iap_singleton.has_signal("response") and not iap_singleton.is_connected("response", callable_plugin):
			iap_singleton.connect("response", callable_plugin)
		_iap_request("startUpdateTask", {})
		_iap_request_products()
		_iap_restore_purchases()
	_update_start_panel_unlock_button()
	_update_start_panel_restore_button()
	_update_diagnostics_label()

func _ensure_iap_poll_timer() -> void:
	if iap_poll_timer != null:
		iap_poll_timer.start()
		return
	iap_poll_timer = Timer.new()
	iap_poll_timer.name = "IapPollTimer"
	iap_poll_timer.wait_time = 0.5
	iap_poll_timer.one_shot = false
	iap_poll_timer.autostart = true
	iap_poll_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(iap_poll_timer)
	iap_poll_timer.timeout.connect(_poll_iap_events)

func _poll_iap_events() -> void:
	if iap_singleton == null:
		return
	if iap_provider != "InAppStore":
		return
	if not iap_singleton.has_method("get_pending_event_count"):
		return
	while int(iap_singleton.get_pending_event_count()) > 0:
		var ev: Variant = iap_singleton.pop_pending_event()
		if typeof(ev) == TYPE_DICTIONARY:
			_on_iap_event(ev)

func _iap_request_products() -> void:
	if iap_hint_product_id.strip_edges() == "":
		return
	if iap_singleton == null:
		return
	if iap_provider == "InAppStore":
		iap_singleton.request_product_info({"product_ids": [iap_hint_product_id]})
	elif iap_provider == "IOSInAppPurchase":
		_iap_request("products", {"productIDs": [iap_hint_product_id]})

func _iap_restore_purchases() -> void:
	if iap_singleton == null:
		return
	if iap_provider == "InAppStore":
		iap_singleton.restore_purchases()
	elif iap_provider == "IOSInAppPurchase":
		_iap_request("transactionCurrentEntitlements", {})

func _iap_request(name: String, data: Dictionary) -> void:
	if iap_singleton == null:
		return
	iap_singleton.request(name, data)

func _on_iap_response(response_name: String, data: Dictionary) -> void:
	if response_name == "products":
		if String(data.get("result", "")) == "success":
			var products: Variant = data.get("products", [])
			if typeof(products) == TYPE_ARRAY:
				for entry in products:
					if typeof(entry) != TYPE_DICTIONARY:
						continue
					var pid := String(entry.get("id", ""))
					if pid == iap_hint_product_id:
						iap_hint_display_price = String(entry.get("displayPrice", ""))
						break
		_update_start_panel_unlock_button()
		_update_diagnostics_label()
	elif response_name == "purchase":
		if String(data.get("result", "")) == "success":
			var pid := String(data.get("productID", ""))
			if pid == iap_hint_product_id:
				_unlock_hints_from_iap()
	elif response_name == "transactionCurrentEntitlements":
		if String(data.get("result", "")) == "success":
			var transactions: Variant = data.get("transactions", [])
			if typeof(transactions) == TYPE_ARRAY:
				for entry in transactions:
					if typeof(entry) == TYPE_DICTIONARY and String(entry.get("productID", "")) == iap_hint_product_id:
						_unlock_hints_from_iap()
						break

func _on_iap_event(data: Dictionary) -> void:
	var event_type := String(data.get("type", ""))
	match event_type:
		"product_info":
			if String(data.get("result", "")) == "ok":
				var pid := String(data.get("product_id", ""))
				if pid == iap_hint_product_id:
					var price := String(data.get("price", ""))
					var locale := String(data.get("price_locale", ""))
					if price != "" and locale != "":
						iap_hint_display_price = "%s %s" % [locale, price]
					elif price != "":
						iap_hint_display_price = price
			_update_start_panel_unlock_button()
			_update_diagnostics_label()
		"purchase":
			if String(data.get("result", "")) == "ok":
				var pid := String(data.get("product_id", ""))
				if pid == iap_hint_product_id:
					_unlock_hints_from_iap()
		"restore_purchases":
			if String(data.get("result", "")) == "ok":
				var pid := String(data.get("product_id", ""))
				if pid == iap_hint_product_id:
					_unlock_hints_from_iap()

func _unlock_hints_from_iap() -> void:
	if hints_unlocked:
		return
	hints_unlocked = true
	_save_settings()
	_update_start_panel_unlock_button()

func _on_unlock_hints_pressed() -> void:
	if hints_unlocked:
		return
	if iap_singleton == null or iap_hint_product_id.strip_edges() == "":
		return
	if iap_provider == "InAppStore":
		iap_singleton.purchase({"product_id": iap_hint_product_id})
	elif iap_provider == "IOSInAppPurchase":
		_iap_request("purchase", {"productID": iap_hint_product_id})

func _on_restore_purchases_pressed() -> void:
	if iap_singleton == null:
		return
	if iap_provider == "InAppStore":
		iap_singleton.restore_purchases()
	elif iap_provider == "IOSInAppPurchase":
		_iap_request("appStoreSync", {})
		_iap_restore_purchases()

func _update_start_panel_unlock_button() -> void:
	if start_panel == null:
		return
	var unlock := start_panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartUnlockHintsButton") as Button
	if unlock == null:
		return
	if hints_unlocked:
		unlock.text = "Hints Unlocked"
		unlock.disabled = true
	else:
		if iap_hint_display_price.strip_edges() != "":
			unlock.text = "Unlock Hints (%s)" % iap_hint_display_price
		else:
			unlock.text = "Unlock Hints"
		unlock.disabled = (iap_singleton == null or iap_hint_product_id.strip_edges() == "")

func _update_start_panel_restore_button() -> void:
	if start_panel == null:
		return
	var restore := start_panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartRestoreButton") as Button
	if restore == null:
		return
	restore.text = "Restore Purchases"
	restore.disabled = (iap_singleton == null)

func _update_diagnostics_label() -> void:
	if not diagnostics_enabled:
		return
	if options_panel == null:
		return
	var diag := options_panel.get_node_or_null("OptionsLayout/OptionsCenter/OptionsBox/OptionsVBox/DiagnosticsLabel") as Label
	if diag == null:
		return
	var iap_loaded := iap_singleton != null
	var platform := OS.get_name()
	var iap_status := ""
	if not _is_ios():
		iap_status = "missing (not iOS)"
	else:
		iap_status = "loaded" if iap_loaded else "missing"
	var provider := iap_provider if iap_provider != "" else "(none)"
	var singletons: PackedStringArray = Engine.get_singleton_list()
	var iap_candidates: PackedStringArray = PackedStringArray()
	for name in singletons:
		var lower := name.to_lower()
		if lower.find("app") != -1 and (lower.find("store") != -1 or lower.find("inapp") != -1 or lower.find("purchase") != -1):
			iap_candidates.append(name)
	var candidates_text := "none"
	if iap_candidates.size() > 0:
		candidates_text = ", ".join(iap_candidates)
	var music_count := music_track_paths.size()
	var manifest_path := "res://assets/music/music_list.json"
	var manifest_exists := FileAccess.file_exists(manifest_path)
	var assets_music_dir := DirAccess.open("res://assets/music") != null
	var root_music_dir := DirAccess.open("res://music") != null
	diag.text = "Diagnostics:\n- Platform: %s\n- IAP plugin: %s (%s)\n- IAP candidates: %s\n- Product ID: %s\n- Music tracks: %d (assets: %s, root: %s, manifest: %s, music %s)" % [
		platform,
		iap_status,
		provider,
		candidates_text,
		iap_hint_product_id if iap_hint_product_id.strip_edges() != "" else "(not set)",
		music_count,
		"ok" if assets_music_dir else "missing",
		"ok" if root_music_dir else "missing",
		"found" if manifest_exists else "missing",
		"on" if music_enabled else "off"
	]

func _setup_music() -> void:
	if music_player == null:
		return
	music_player.volume_db = music_volume_db
	if not music_player.finished.is_connected(_on_music_finished):
		music_player.finished.connect(_on_music_finished)
	_refresh_music_tracks()
	_start_music_if_needed()
	_update_diagnostics_label()

func _refresh_music_tracks() -> void:
	music_tracks.clear()
	music_track_paths.clear()
	var dirs := ["res://assets/music", "res://music"]
	for base in dirs:
		var dir := DirAccess.open(base)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir():
				var ext := name.get_extension().to_lower()
				var load_path := ""
				if ext == "import":
					var base_name := name.substr(0, name.length() - 7)
					var inner_ext := base_name.get_extension().to_lower()
					if inner_ext in ["mp3", "ogg", "wav"]:
						load_path = "%s/%s" % [base, base_name]
				elif ext in ["mp3", "ogg", "wav"]:
					load_path = "%s/%s" % [base, name]
				if load_path != "" and not music_track_paths.has(load_path):
					var stream: AudioStream = load(load_path) as AudioStream
					if stream != null:
						music_tracks.append(stream)
						music_track_paths.append(load_path)
			name = dir.get_next()
		dir.list_dir_end()
	if music_track_paths.is_empty():
		_load_music_manifest("res://assets/music/music_list.json")
	_update_diagnostics_label()

func _load_music_manifest(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return
	var items: Array = parsed
	for entry in items:
		if typeof(entry) != TYPE_STRING:
			continue
		var rel: String = String(entry)
		var load_path := "res://assets/music/%s" % rel
		if music_track_paths.has(load_path):
			continue
		var stream: AudioStream = load(load_path) as AudioStream
		if stream != null:
			music_tracks.append(stream)
			music_track_paths.append(load_path)

func _start_music_if_needed() -> void:
	if not music_enabled:
		_stop_music()
		return
	if music_tracks.is_empty():
		return
	if music_player != null and music_player.playing:
		return
	_play_next_track()

func _stop_music() -> void:
	if music_player != null and music_player.playing:
		music_player.stop()

func _play_next_track() -> void:
	if music_player == null or music_tracks.is_empty():
		return
	var count := music_tracks.size()
	var next_index := music_rng.randi_range(0, count - 1)
	if count > 1 and next_index == current_music_index:
		next_index = (next_index + 1 + music_rng.randi_range(0, count - 2)) % count
	current_music_index = next_index
	music_player.stream = music_tracks[next_index]
	music_player.play()

func _on_music_finished() -> void:
	if not music_enabled:
		return
	_play_next_track()

func _on_music_toggled(pressed: bool) -> void:
	music_enabled = pressed
	_save_settings()
	_sync_settings_ui()
	if pressed:
		_refresh_music_tracks()
		_start_music_if_needed()
	else:
		_stop_music()
	_update_diagnostics_label()

func _current_day_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	if date.is_empty():
		return ""
	return "%04d-%02d-%02d" % [int(date.get("year", 0)), int(date.get("month", 0)), int(date.get("day", 0))]

func _refresh_daily_hint() -> void:
	var today := _current_day_key()
	if today == "":
		return
	if daily_hint_date != today:
		daily_hint_date = today
		daily_hint_used = 0
		_save_settings()

func _hint_available() -> bool:
	if dev_mode or hints_unlocked:
		return true
	if current_stage <= FREE_HINTS_STAGE:
		return true
	_refresh_daily_hint()
	var key := _level_key(current_stage, current_level_in_stage)
	var used := int(hint_uses_by_level.get(key, 0))
	if used < FREE_HINTS_PER_LEVEL:
		return true
	if daily_hint_used < FREE_HINTS_PER_DAY:
		return true
	return false

func _consume_hint() -> void:
	if dev_mode or hints_unlocked:
		return
	if current_stage <= FREE_HINTS_STAGE:
		return
	_refresh_daily_hint()
	var key := _level_key(current_stage, current_level_in_stage)
	var used := int(hint_uses_by_level.get(key, 0))
	if used < FREE_HINTS_PER_LEVEL:
		hint_uses_by_level[key] = used + 1
		_save_progress()
		return
	if daily_hint_used < FREE_HINTS_PER_DAY:
		daily_hint_used += 1
		_save_settings()

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
	level_stats = {}
	hint_uses_by_level = {}
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
	var tex := load(WALL_TEXTURE_PATH) as Texture2D
	if tex != null:
		wall_texture = tex

func _ensure_ui_sfx() -> void:
	if sfx_ui_click == null:
		sfx_ui_click = load("res://assets/sounds/ui_click.wav") as AudioStream
	if sfx_ui_success == null:
		sfx_ui_success = load("res://assets/sounds/ui_success.wav") as AudioStream

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

func _start_hint_job(start_key: String, max_states: int) -> void:
	_cancel_hint_job("")
	hint_job_active = true
	hint_job_token += 1
	hint_job_start_key = start_key
	if hint_button != null:
		hint_button.disabled = true
	status_label.text = "Searching for hint..."
	var open: Array = []
	var parent: Dictionary = {}
	var move_from: Dictionary = {}
	var g_score: Dictionary = {}
	var visited: Dictionary = {}
	var start := _clone_grid(grid)
	parent[start_key] = ""
	g_score[start_key] = 0
	_pq_push(open, {
		"grid": start,
		"key": start_key,
		"g": 0,
		"f": _heuristic(start)
	})
	hint_job = {
		"open": open,
		"parent": parent,
		"move_from": move_from,
		"g_score": g_score,
		"visited": visited,
		"expanded": 0,
		"max_states": max_states
	}
	call_deferred("_process_hint_job", hint_job_token)

func _process_hint_job(token: int) -> void:
	if not hint_job_active or token != hint_job_token:
		return
	if _grid_key(grid) != hint_job_start_key:
		_cancel_hint_job("Puzzle changed")
		return
	var open: Array = hint_job.get("open", [])
	var parent: Dictionary = hint_job.get("parent", {})
	var move_from: Dictionary = hint_job.get("move_from", {})
	var g_score: Dictionary = hint_job.get("g_score", {})
	var visited: Dictionary = hint_job.get("visited", {})
	var expanded: int = int(hint_job.get("expanded", 0))
	var max_states: int = int(hint_job.get("max_states", 0))
	var steps := 0
	while steps < HINT_STEPS_PER_FRAME and not open.is_empty():
		var node: Dictionary = _pq_pop(open)
		if node.is_empty():
			break
		var current: Array = node.get("grid", [])
		var current_key: String = String(node.get("key", ""))
		if current_key == "":
			continue
		if visited.has(current_key):
			continue
		visited[current_key] = true
		expanded += 1
		if expanded >= max_states:
			hint_job["expanded"] = expanded
			_finish_hint_job([], true, hint_job_start_key)
			return
		for is_row in [true, false]:
			var limit := height if is_row else width
			for index in range(limit):
				for dir in [-1, 1]:
					var result := _simulate_slide(current, is_row, index, dir)
					if not result.get("moved", false):
						continue
					var next_grid: Array = result["grid"]
					var key := _grid_key(next_grid)
					var new_g: int = int(node.get("g", 0)) + 1
					if g_score.has(key) and new_g >= int(g_score[key]):
						continue
					parent[key] = current_key
					move_from[key] = {"is_row": is_row, "index": index, "dir": dir}
					if _grid_is_win(next_grid):
						var path := _reconstruct_path(hint_job_start_key, key, parent, move_from)
						_finish_hint_job(path, false, hint_job_start_key)
						return
					g_score[key] = new_g
					var h: int = _heuristic(next_grid)
					_pq_push(open, {
						"grid": next_grid,
						"key": key,
						"g": new_g,
						"f": new_g + h
					})
		steps += 1
	hint_job["expanded"] = expanded
	if open.is_empty():
		_finish_hint_job([], false, hint_job_start_key)
		return
	call_deferred("_process_hint_job", token)

func _finish_hint_job(path: Array, capped: bool, start_key: String) -> void:
	hint_job_active = false
	hint_job = {}
	if hint_button != null:
		hint_button.disabled = false
	if _grid_key(grid) != start_key:
		hint_consume_pending = false
		hint_consume_key = ""
		return
	if path.is_empty():
		cached_hint_key = start_key
		cached_hint_path.clear()
		cached_hint_capped = capped
		cached_hint_unsolvable = not capped
		if capped:
			status_label.text = "Hint search limit reached. Try Restart."
		else:
			status_label.text = "No solution found. Press Restart."
			_play_sfx(sfx_no_solution, sfx_no_solution_player)
		hint_consume_pending = false
		hint_consume_key = ""
		return
	cached_hint_key = start_key
	cached_hint_path = path.duplicate()
	cached_hint_capped = false
	cached_hint_unsolvable = false
	var move: Dictionary = path[0]
	_show_debug_line(move["is_row"], move["index"], int(move["dir"]), 0.8)
	status_label.text = "Hint shown"
	if hint_consume_pending and hint_consume_key == start_key:
		_consume_hint()
	hint_consume_pending = false
	hint_consume_key = ""

func _cancel_hint_job(message: String) -> void:
	if not hint_job_active:
		return
	hint_job_active = false
	hint_job = {}
	hint_job_token += 1
	if hint_button != null:
		hint_button.disabled = false
	hint_consume_pending = false
	hint_consume_key = ""
	if message != "":
		status_label.text = message

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
	if not _hint_available():
		status_label.text = "No free hints left. Unlock hints on Home."
		return
	var current_key := _grid_key(grid)
	if hint_job_active:
		status_label.text = "Searching for hint..."
		return
	if current_key == cached_hint_key:
		if not cached_hint_path.is_empty():
			var cached_move: Dictionary = cached_hint_path[0]
			_show_debug_line(cached_move["is_row"], cached_move["index"], int(cached_move["dir"]), 0.8)
			status_label.text = "Hint shown"
			_consume_hint()
			return
		if cached_hint_capped:
			status_label.text = "Hint search limit reached. Try Restart."
			return
		if cached_hint_unsolvable:
			status_label.text = "No solution found. Press Restart."
			_play_sfx(sfx_no_solution, sfx_no_solution_player)
			return
	hint_consume_pending = true
	hint_consume_key = current_key
	_start_hint_job(current_key, HINT_MAX_STATES)

func _on_options_pressed() -> void:
	start_panel.visible = false
	about_panel.visible = false
	options_panel.visible = true
	if background_rect != null:
		background_rect.visible = false

func _on_high_contrast_toggled(pressed: bool) -> void:
	high_contrast = pressed
	_update_tiles()

func _on_large_tiles_toggled(pressed: bool) -> void:
	large_tiles = pressed
	_apply_accessibility()

func _wire_options_panel(panel: Control) -> void:
	var backdrop: TextureRect = panel.get_node_or_null("OptionsBackdrop") as TextureRect
	if backdrop != null and backdrop.texture == null:
		backdrop.texture = load("res://assets/bg/bg_options.png") as Texture2D
	if backdrop != null:
		_apply_background_cover(backdrop)

	var top_bar: Control = panel.get_node_or_null("OptionsLayout/OptionsTopBar") as Control
	if top_bar != null:
		top_bar.visible = false
		top_bar.custom_minimum_size = Vector2.ZERO
		top_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var title_wrap: Control = panel.get_node_or_null("OptionsLayout/OptionsTitleWrap") as Control
	if title_wrap != null:
		title_wrap.visible = false
		title_wrap.custom_minimum_size = Vector2(0, 0)

	var title: RichTextLabel = panel.get_node_or_null("OptionsLayout/OptionsTitleWrap/OptionsTitle") as RichTextLabel
	if title != null and title.text.strip_edges() == "":
		title.bbcode_enabled = true
		title.fit_content = true
		title.scroll_active = false
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.text = ""

	var center_wrap: Control = panel.get_node_or_null("OptionsLayout/OptionsCenter") as Control
	if center_wrap != null:
		center_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var spacer: Control = panel.get_node_or_null("OptionsLayout/OptionsSpacer") as Control
	if spacer != null:
		spacer.visible = false
		spacer.custom_minimum_size = Vector2.ZERO
		spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var options_box: PanelContainer = panel.get_node_or_null("OptionsLayout/OptionsCenter/OptionsBox") as PanelContainer
	if options_box != null:
		options_box.custom_minimum_size = Vector2(300, 200)
		_apply_glass_panel(options_box)

	var sound: CheckButton = panel.get_node_or_null("OptionsLayout/OptionsCenter/OptionsBox/OptionsVBox/SoundCheck") as CheckButton
	if sound != null:
		sound.button_pressed = sound_enabled
		if not sound.toggled.is_connected(_on_sound_toggled):
			sound.toggled.connect(_on_sound_toggled)

	var music: CheckButton = panel.get_node_or_null("OptionsLayout/OptionsCenter/OptionsBox/OptionsVBox/MusicCheck") as CheckButton
	if music != null:
		music.button_pressed = music_enabled
		if not music.toggled.is_connected(_on_music_toggled):
			music.toggled.connect(_on_music_toggled)

	var reset: Button = panel.get_node_or_null("OptionsLayout/OptionsCenter/OptionsBox/OptionsVBox/ResetProgressButton") as Button
	if reset != null:
		if not reset.pressed.is_connected(_on_reset_progress_pressed):
			reset.pressed.connect(_on_reset_progress_pressed)
		if not reset.has_theme_stylebox_override("normal"):
			_style_start_button(reset, Color8(255, 184, 107))

	var diag: Label = panel.get_node_or_null("OptionsLayout/OptionsCenter/OptionsBox/OptionsVBox/DiagnosticsLabel") as Label
	if diag != null:
		diag.visible = diagnostics_enabled
		diag.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		diag.autowrap_mode = TextServer.AUTOWRAP_WORD
		_update_diagnostics_label()

	var home: Button = panel.get_node_or_null("OptionsHomeBar/OptionsHomeWrap/OptionsHomeButton") as Button
	if home != null:
		if not home.pressed.is_connected(_on_home_pressed):
			home.pressed.connect(_on_home_pressed)
		if not home.has_theme_stylebox_override("normal"):
			_style_start_button(home, Color8(83, 201, 255))

func _ensure_options_panel() -> Control:
	var existing := get_node_or_null("OptionsPanel")
	if existing != null and existing is Control:
		var panel_existing := existing as Control
		_wire_options_panel(panel_existing)
		return panel_existing

	var panel := Control.new()
	panel.name = "OptionsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "OptionsBackdrop"
	backdrop.texture = load("res://assets/bg/bg_options.png") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_background_cover(backdrop)
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
	title_wrap.custom_minimum_size = Vector2(0, 140)
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
	title.add_theme_font_size_override("normal_font_size", 46)
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
	center.custom_minimum_size = Vector2(300, 240)
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

	var sound := CheckButton.new()
	sound.name = "SoundCheck"
	sound.text = "Sound"
	sound.button_pressed = sound_enabled
	sound.toggled.connect(_on_sound_toggled)
	vbox.add_child(sound)

	var music := CheckButton.new()
	music.name = "MusicCheck"
	music.text = "Music"
	music.button_pressed = music_enabled
	music.toggled.connect(_on_music_toggled)
	vbox.add_child(music)

	var reset := Button.new()
	reset.name = "ResetProgressButton"
	reset.text = "Reset Progress"
	reset.pressed.connect(_on_reset_progress_pressed)
	_style_start_button(reset, Color8(255, 184, 107))
	vbox.add_child(reset)

	var diag := Label.new()
	diag.name = "DiagnosticsLabel"
	diag.text = ""
	diag.autowrap_mode = TextServer.AUTOWRAP_WORD
	diag.add_theme_font_size_override("font_size", 16)
	diag.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	diag.visible = diagnostics_enabled
	vbox.add_child(diag)

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
	home.name = "OptionsHomeButton"
	home.text = "Home"
	home.custom_minimum_size = Vector2(160, 44)
	home.pressed.connect(_on_home_pressed)
	_style_start_button(home, Color8(83, 201, 255))
	home_wrap.add_child(home)

	_wire_options_panel(panel)
	return panel

func _ensure_start_panel() -> Control:
	var existing := get_node_or_null("StartPanel")
	if existing != null and existing is Control:
		var panel := existing as Control
		var backdrop := panel.get_node_or_null("StartBackdrop") as TextureRect
		if backdrop != null:
			if backdrop.texture == null:
				backdrop.texture = load("res://assets/bg/bg_main.png") as Texture2D
			_apply_background_cover(backdrop)
		var title := panel.get_node_or_null("StartLayout/StartTitle") as RichTextLabel
		if title != null:
			title.add_theme_font_size_override("normal_font_size", 72)
			title.custom_minimum_size = Vector2(0, 200)
		var current := panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartCurrentButton") as Button
		if current != null:
			if not current.pressed.is_connected(_start_current_level):
				current.pressed.connect(_start_current_level)
			_style_start_button(current, Color8(109, 255, 160))
		var play := panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartPlayButton") as Button
		if play != null:
			if not play.pressed.is_connected(_show_stage_select):
				play.pressed.connect(_show_stage_select)
			_style_start_button(play, Color8(83, 201, 255))
		var unlock := panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartUnlockHintsButton") as Button
		if unlock != null:
			if not unlock.pressed.is_connected(_on_unlock_hints_pressed):
				unlock.pressed.connect(_on_unlock_hints_pressed)
			_style_start_button(unlock, Color8(255, 122, 122))
			_update_start_panel_unlock_button()
		var restore := panel.get_node_or_null("StartLayout/StartBox/StartVBox/StartRestoreButton") as Button
		if restore != null:
			if not restore.pressed.is_connected(_on_restore_purchases_pressed):
				restore.pressed.connect(_on_restore_purchases_pressed)
			_style_start_button(restore, Color8(83, 201, 255))
			_update_start_panel_restore_button()
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
			box.custom_minimum_size = Vector2(360, 500)
			_apply_glass_panel(box)
		var top_spacer := panel.get_node_or_null("StartLayout/StartSpacer") as Control
		if top_spacer != null:
			top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var bottom_spacer := panel.get_node_or_null("StartLayout/StartBottomSpacer") as Control
		if bottom_spacer != null:
			bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		return panel

	var panel := Control.new()
	panel.name = "StartPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "StartBackdrop"
	backdrop.texture = load("res://assets/bg/bg_main.png") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_background_cover(backdrop)
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
	title.add_theme_font_size_override("normal_font_size", 72)
	title.custom_minimum_size = Vector2(0, 200)
	layout.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var center := PanelContainer.new()
	center.name = "StartBox"
	center.custom_minimum_size = Vector2(360, 500)
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_glass_panel(center)
	layout.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "StartVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var current := Button.new()
	current.name = "StartCurrentButton"
	current.text = "Play"
	current.custom_minimum_size = Vector2(0, 60)
	current.pressed.connect(_start_current_level)
	_style_start_button(current, Color8(109, 255, 160))
	vbox.add_child(current)

	var play := Button.new()
	play.text = "Select Stage"
	play.custom_minimum_size = Vector2(0, 60)
	play.pressed.connect(_show_stage_select)
	_style_start_button(play, Color8(83, 201, 255))
	vbox.add_child(play)

	var unlock := Button.new()
	unlock.name = "StartUnlockHintsButton"
	unlock.text = "Unlock Hints"
	unlock.custom_minimum_size = Vector2(0, 54)
	unlock.pressed.connect(_on_unlock_hints_pressed)
	_style_start_button(unlock, Color8(255, 122, 122))
	vbox.add_child(unlock)

	var restore := Button.new()
	restore.name = "StartRestoreButton"
	restore.text = "Restore Purchases"
	restore.custom_minimum_size = Vector2(0, 48)
	restore.pressed.connect(_on_restore_purchases_pressed)
	_style_start_button(restore, Color8(83, 201, 255))
	vbox.add_child(restore)

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
	if button_font != null:
		btn.add_theme_font_override("font", button_font)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.25))
	btn.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r, color.g, color.b, 0.24)
	normal.border_color = Color(1, 1, 1, 0.55)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	normal.shadow_color = Color(0, 0, 0, 0.25)
	normal.shadow_size = 10
	normal.shadow_offset = Vector2(0, 4)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = Color(color.r, color.g, color.b, 0.32)
	hover.border_color = Color(1, 1, 1, 0.7)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(color.r, color.g, color.b, 0.18)
	pressed.border_color = Color(1, 1, 1, 0.45)
	var focus := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	_attach_button_feedback(btn)

func _attach_button_feedback(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	if btn.has_meta("feedback_attached"):
		return
	btn.set_meta("feedback_attached", true)
	btn.button_down.connect(_on_button_down.bind(btn))
	btn.button_up.connect(_on_button_up.bind(btn))
	btn.pressed.connect(_on_button_pressed.bind(btn))

func _on_button_down(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	if btn.disabled:
		return
	btn.pivot_offset = btn.size * 0.5
	if not btn.has_meta("orig_scale"):
		btn.set_meta("orig_scale", btn.scale)
	if not btn.has_meta("orig_modulate"):
		btn.set_meta("orig_modulate", btn.modulate)
	if btn.has_meta("press_tween"):
		var old: Variant = btn.get_meta("press_tween")
		if old is Tween:
			old.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(UI_PRESS_SCALE, UI_PRESS_SCALE), UI_PRESS_TIME)
	tween.parallel().tween_property(btn, "modulate", Color(UI_GLOW_MULT, UI_GLOW_MULT, UI_GLOW_MULT, 1.0), UI_PRESS_TIME)
	btn.set_meta("press_tween", tween)

func _on_button_up(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var orig_scale: Vector2 = btn.get_meta("orig_scale", Vector2.ONE)
	var orig_modulate: Color = btn.get_meta("orig_modulate", Color(1, 1, 1, 1))
	if btn.has_meta("press_tween"):
		var old: Variant = btn.get_meta("press_tween")
		if old is Tween:
			old.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", orig_scale, UI_RELEASE_TIME)
	tween.parallel().tween_property(btn, "modulate", orig_modulate, UI_RELEASE_TIME)
	btn.set_meta("press_tween", tween)

func _on_button_pressed(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	_play_ui_click()
	haptic_light()

func _play_ui_click() -> void:
	if sfx_ui_click == null or sfx_ui_player == null or not sound_enabled:
		return
	var pitch := 1.0
	if ui_rng != null:
		pitch += ui_rng.randf_range(-0.04, 0.04)
	sfx_ui_player.pitch_scale = pitch
	_play_sfx(sfx_ui_click, sfx_ui_player)

func _play_ui_success() -> void:
	if sfx_ui_success == null or sfx_ui_success_player == null or not sound_enabled:
		return
	sfx_ui_success_player.pitch_scale = 1.0
	_play_sfx(sfx_ui_success, sfx_ui_success_player)

func _apply_glass_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.96, 1.0, 0.18)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.28)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)

func _apply_glass_panel_compact(panel: PanelContainer) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.96, 1.0, 0.2)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.3)
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)

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

func _style_stage_card(btn: Button, theme_index: int, locked: bool, unplayed: bool) -> void:
	var accent: Color = THEME_ACCENTS[clampi(theme_index, 0, THEME_ACCENTS.size() - 1)]
	if locked:
		accent = accent.darkened(0.55)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.35)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 4)
	normal.border_width_left = 3
	normal.border_width_right = 3
	normal.border_width_top = 3
	normal.border_width_bottom = 3
	if unplayed:
		normal.border_color = Color(1, 1, 1, 0.6 if locked else 0.95)
	else:
		normal.border_color = accent.lightened(0.2)
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
	btn.add_theme_stylebox_override("disabled", normal)
	_attach_button_feedback(btn)

func _style_level_button(btn: Button, theme_index: int, locked: bool) -> void:
	var accent: Color = THEME_ACCENTS[clampi(theme_index, 0, THEME_ACCENTS.size() - 1)]
	if locked:
		accent = accent.darkened(0.6)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.55) if locked else Color(1, 1, 1, 0.95))
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.35)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 4)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = accent.lightened(0.2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = accent.darkened(0.25)
	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.45)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	_attach_button_feedback(btn)

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

func _wire_about_panel(panel: Control) -> void:
	var backdrop: TextureRect = panel.get_node_or_null("AboutBackdrop") as TextureRect
	if backdrop != null and backdrop.texture == null:
		backdrop.texture = load("res://assets/bg/bg_about.png") as Texture2D
	if backdrop != null:
		_apply_background_cover(backdrop)

	var top_bar: Control = panel.get_node_or_null("AboutLayout/AboutTopBar") as Control
	if top_bar != null:
		top_bar.visible = false
		top_bar.custom_minimum_size = Vector2.ZERO
		top_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var title_wrap: Control = panel.get_node_or_null("AboutLayout/AboutTitleWrap") as Control
	if title_wrap != null:
		title_wrap.visible = false
		title_wrap.custom_minimum_size = Vector2(0, 0)

	var title: RichTextLabel = panel.get_node_or_null("AboutLayout/AboutTitleWrap/AboutTitle") as RichTextLabel
	if title != null and title.text.strip_edges() == "":
		title.bbcode_enabled = true
		title.fit_content = true
		title.scroll_active = false
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.text = ""

	var center_wrap: Control = panel.get_node_or_null("AboutLayout/AboutCenter") as Control
	if center_wrap != null:
		center_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var spacer: Control = panel.get_node_or_null("AboutLayout/AboutSpacer") as Control
	if spacer != null:
		spacer.visible = false
		spacer.custom_minimum_size = Vector2.ZERO
		spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var about_box: PanelContainer = panel.get_node_or_null("AboutLayout/AboutCenter/AboutBox") as PanelContainer
	if about_box != null:
		_apply_glass_panel(about_box)

	var body: RichTextLabel = panel.get_node_or_null("AboutLayout/AboutCenter/AboutBox/AboutVBox/AboutBody") as RichTextLabel
	if body != null:
		about_body_label = body
		body.add_theme_font_size_override("normal_font_size", 22)
		_update_about_text()

	var home: Button = panel.get_node_or_null("AboutHomeBar/AboutHomeWrap/AboutHomeButton") as Button
	if home != null:
		if not home.pressed.is_connected(_on_home_pressed):
			home.pressed.connect(_on_home_pressed)
		if not home.has_theme_stylebox_override("normal"):
			_style_start_button(home, Color8(255, 184, 107))

func _ensure_about_panel() -> Control:
	var existing := get_node_or_null("AboutPanel")
	if existing != null and existing is Control:
		var panel_existing := existing as Control
		_wire_about_panel(panel_existing)
		return panel_existing

	var panel := Control.new()
	panel.name = "AboutPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "AboutBackdrop"
	backdrop.texture = load("res://assets/bg/bg_about.png") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_background_cover(backdrop)
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
	title_wrap.custom_minimum_size = Vector2(0, 140)
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
	title.add_theme_font_size_override("normal_font_size", 46)
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
	center.custom_minimum_size = Vector2(360, 320)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(1, 1, 1, 0.5)
	card_style.corner_radius_top_left = 16
	card_style.corner_radius_top_right = 16
	card_style.corner_radius_bottom_left = 16
	card_style.corner_radius_bottom_right = 16
	card_style.content_margin_left = 18
	card_style.content_margin_right = 18
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0, 0, 0, 0.08)
	center.add_theme_stylebox_override("panel", card_style)
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
	body.name = "AboutBody"
	body.bbcode_enabled = true
	body.text = about_text
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("normal_font_size", 20)
	body.add_theme_constant_override("line_separation", 8)
	body.add_theme_color_override("default_color", Color(0, 0, 0, 1))
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
	home.name = "AboutHomeButton"
	home.text = "Home"
	home.custom_minimum_size = Vector2(160, 44)
	home.pressed.connect(_on_home_pressed)
	_style_start_button(home, Color8(255, 184, 107))
	home_wrap.add_child(home)

	_wire_about_panel(panel)
	return panel

func _wire_howto_panel(panel: Control) -> void:
	var backdrop: TextureRect = panel.get_node_or_null("HowToBackdrop") as TextureRect
	if backdrop != null and backdrop.texture == null:
		backdrop.texture = load("res://assets/bg/bg_howtoplay.png") as Texture2D
	if backdrop != null:
		_apply_background_cover(backdrop)

	var top_bar: Control = panel.get_node_or_null("HowToLayout/HowToTopBar") as Control
	if top_bar != null:
		top_bar.visible = false
		top_bar.custom_minimum_size = Vector2.ZERO
		top_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var title_wrap: Control = panel.get_node_or_null("HowToLayout/HowToTitleWrap") as Control
	if title_wrap != null:
		title_wrap.visible = false
		title_wrap.custom_minimum_size = Vector2(0, 0)

	var title: RichTextLabel = panel.get_node_or_null("HowToLayout/HowToTitleWrap/HowToTitle") as RichTextLabel
	if title != null and title.text.strip_edges() == "":
		title.bbcode_enabled = true
		title.fit_content = true
		title.scroll_active = false
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.text = ""

	var center_wrap: Control = panel.get_node_or_null("HowToLayout/HowToCenter") as Control
	if center_wrap != null:
		center_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var spacer: Control = panel.get_node_or_null("HowToLayout/HowToSpacer") as Control
	if spacer != null:
		spacer.visible = false
		spacer.custom_minimum_size = Vector2.ZERO
		spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var howto_box: PanelContainer = panel.get_node_or_null("HowToLayout/HowToCenter/HowToBox") as PanelContainer
	if howto_box != null:
		_apply_glass_panel(howto_box)

	var body: RichTextLabel = panel.get_node_or_null("HowToLayout/HowToCenter/HowToBox/HowToVBox/HowToBody") as RichTextLabel
	if body != null:
		howto_body_label = body
		body.add_theme_font_size_override("normal_font_size", 22)
		_update_howto_text()

	var home: Button = panel.get_node_or_null("HowToHomeBar/HowToHomeWrap/HowToHomeButton") as Button
	if home != null:
		if not home.pressed.is_connected(_on_home_pressed):
			home.pressed.connect(_on_home_pressed)
		if not home.has_theme_stylebox_override("normal"):
			_style_start_button(home, Color8(255, 184, 107))

func _ensure_howto_panel() -> Control:
	var existing := get_node_or_null("HowToPanel")
	if existing != null and existing is Control:
		var panel_existing := existing as Control
		_wire_howto_panel(panel_existing)
		return panel_existing

	var panel := Control.new()
	panel.name = "HowToPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "HowToBackdrop"
	backdrop.texture = load("res://assets/bg/bg_howtoplay.png") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_background_cover(backdrop)
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
	title_wrap.custom_minimum_size = Vector2(0, 140)
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
	title.add_theme_font_size_override("normal_font_size", 46)
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
	center.custom_minimum_size = Vector2(360, 320)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(1, 1, 1, 0.5)
	card_style.corner_radius_top_left = 16
	card_style.corner_radius_top_right = 16
	card_style.corner_radius_bottom_left = 16
	card_style.corner_radius_bottom_right = 16
	card_style.content_margin_left = 18
	card_style.content_margin_right = 18
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0, 0, 0, 0.08)
	center.add_theme_stylebox_override("panel", card_style)
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
	body.name = "HowToBody"
	body.bbcode_enabled = true
	body.text = howto_text
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("normal_font_size", 20)
	body.add_theme_constant_override("line_separation", 8)
	body.add_theme_color_override("default_color", Color(0, 0, 0, 1))
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
	home.name = "HowToHomeButton"
	home.text = "Home"
	home.custom_minimum_size = Vector2(160, 44)
	home.pressed.connect(_on_home_pressed)
	_style_start_button(home, Color8(255, 184, 107))
	home_wrap.add_child(home)

	_wire_howto_panel(panel)
	return panel

func _wire_reset_confirm_popup(panel: Control) -> void:
	var yes: Button = panel.get_node_or_null("ResetConfirmCenter/ResetConfirmCard/ResetConfirmVBox/ResetConfirmButtons/ResetConfirmYes") as Button
	if yes != null:
		if not yes.pressed.is_connected(_on_reset_confirm_yes):
			yes.pressed.connect(_on_reset_confirm_yes)
		if not yes.has_theme_stylebox_override("normal"):
			_style_start_button(yes, Color8(109, 255, 160))

	var no: Button = panel.get_node_or_null("ResetConfirmCenter/ResetConfirmCard/ResetConfirmVBox/ResetConfirmButtons/ResetConfirmNo") as Button
	if no != null:
		if not no.pressed.is_connected(_on_reset_confirm_no):
			no.pressed.connect(_on_reset_confirm_no)
		if not no.has_theme_stylebox_override("normal"):
			_style_start_button(no, Color8(255, 122, 122))

func _ensure_reset_confirm_popup() -> Control:
	var existing := get_node_or_null("ResetConfirmPopup")
	if existing != null and existing is Control:
		var panel_existing := existing as Control
		_wire_reset_confirm_popup(panel_existing)
		return panel_existing

	var panel := Control.new()
	panel.name = "ResetConfirmPopup"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var dim := ColorRect.new()
	dim.name = "ResetConfirmDim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(dim)

	var center := CenterContainer.new()
	center.name = "ResetConfirmCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var card := PanelContainer.new()
	card.name = "ResetConfirmCard"
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
	vbox.name = "ResetConfirmVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var label := Label.new()
	label.name = "ResetConfirmLabel"
	label.text = "Reset progress?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.name = "ResetConfirmButtons"
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	var yes := Button.new()
	yes.name = "ResetConfirmYes"
	yes.text = "Yes"
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_on_reset_confirm_yes)
	_style_start_button(yes, Color8(109, 255, 160))
	buttons.add_child(yes)

	var no := Button.new()
	no.name = "ResetConfirmNo"
	no.text = "No"
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_on_reset_confirm_no)
	_style_start_button(no, Color8(255, 122, 122))
	buttons.add_child(no)

	_wire_reset_confirm_popup(panel)
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

func _hide_all_blocks() -> void:
	for y in height:
		for x in width:
			var cell: Dictionary = cells[y][x]
			var block: TextureRect = cell["block"]
			var tint := block.modulate
			tint.a = 0.0
			block.modulate = tint
			block.visible = false

func _start_swipe(is_row: bool, index: int, dir: int) -> void:
	if is_animating or not input_enabled:
		return
	_cancel_hint_job("")
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
	_clear_animation_layer()
	_prepare_animation_layer()
	var hidden_map: Dictionary = {}
	var max_duration := 0.0
	var pending := {"count": moves.size()}
	for move in moves:
		var from: Vector2i = move["from"]
		var to: Vector2i = move["to"]
		var from_block: TextureRect = cells[from.y][from.x]["block"]
		if is_instance_valid(from_block) and not hidden_map.has(from_block):
			var start_pos: Vector2 = from_block.global_position
			hidden_map[from_block] = true
			hidden_blocks.append({
				"block": from_block,
				"top_level": from_block.top_level,
				"z_index": from_block.z_index,
				"position": from_block.position
			})
			from_block.top_level = true
			from_block.z_index = 1000
			from_block.global_position = start_pos
		var mover: TextureRect = from_block
		var color_id: int = int(move.get("color", -1))
		if color_id >= 0 and palette.size() > 0:
			mover.modulate = palette[color_id % palette.size()]
			mover.self_modulate = Color(1, 1, 1, 1)
		var path_var: Variant = move.get("path", [])
		var path: Array = []
		if typeof(path_var) == TYPE_ARRAY:
			path = path_var
		var points: Array = []
		if path.size() > 1:
			points = path
		else:
			points = [from, to]
		var waypoints: Array = []
		var seg_cells: Array = []
		var total_cells := 0
		for i in range(1, points.size()):
			var p0: Vector2i = points[i - 1]
			var p1: Vector2i = points[i]
			waypoints.append(cells[p1.y][p1.x]["block"].global_position)
			var dist: int = abs(p1.x - p0.x) + abs(p1.y - p0.y)
			seg_cells.append(dist)
			total_cells += dist
		if waypoints.is_empty():
			waypoints.append(cells[to.y][to.x]["block"].global_position)
			seg_cells.append(1)
			total_cells = 1
		var straight_cells: int = abs(to.x - from.x) + abs(to.y - from.y)
		if straight_cells <= 0:
			straight_cells = 1
		if total_cells <= 0:
			total_cells = 1
		var per_cell := ANIM_DURATION / float(total_cells)
		var move_duration := per_cell * float(total_cells)
		if move_duration > max_duration:
			max_duration = move_duration
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		for i in range(waypoints.size()):
			var wp: Vector2 = waypoints[i]
			var dist_cells := int(seg_cells[i])
			if dist_cells <= 0:
				dist_cells = 1
			var seg_duration := per_cell * float(dist_cells)
			tween.tween_property(mover, "global_position", wp, seg_duration)
		tween.finished.connect(_on_swipe_tween_finished.bind(pending, hidden_blocks, ghosts, next_grid, next_locked))
	var safety_delay := maxf(ANIM_DURATION, max_duration) + 0.06
	var timer := get_tree().create_timer(safety_delay)
	timer.timeout.connect(_on_swipe_timeout.bind(pending, hidden_blocks, ghosts, next_grid, next_locked))

func _finalize_swipe(hidden_blocks: Array, ghosts: Array, next_grid: Array, next_locked: Dictionary) -> void:
	for block in hidden_blocks:
		if block is Dictionary and block.has("block"):
			var node: TextureRect = block["block"]
			if is_instance_valid(node):
				node.top_level = bool(block.get("top_level", false))
				node.z_index = int(block.get("z_index", 0))
				node.position = block.get("position", Vector2.ZERO)
		elif is_instance_valid(block):
			block.visible = true
	for ghost in ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
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
		_record_level_stats()
		_update_hud()
		_mark_level_complete()
		if current_level_in_stage >= LEVELS_PER_STAGE:
			_show_stage_complete()
		else:
			_start_next_level_countdown()
	is_animating = false
	if solving:
		_continue_solution()

func _on_swipe_tween_finished(pending: Dictionary, hidden_blocks: Array, ghosts: Array, next_grid: Array, next_locked: Dictionary) -> void:
	pending["count"] = int(pending.get("count", 0)) - 1
	if int(pending["count"]) <= 0:
		_finalize_swipe(hidden_blocks, ghosts, next_grid, next_locked)

func _on_swipe_timeout(pending: Dictionary, hidden_blocks: Array, ghosts: Array, next_grid: Array, next_locked: Dictionary) -> void:
	if not is_animating:
		return
	if int(pending.get("count", 0)) <= 0:
		return
	_finalize_swipe(hidden_blocks, ghosts, next_grid, next_locked)

func new_level() -> void:
	moves_made = 0
	if grid_container != null:
		grid_container.visible = true
	_clear_animation_layer()
	_cancel_hint_job("")
	_stop_next_level_countdown()
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
	if grid_container != null:
		grid_container.visible = true
	_clear_animation_layer()
	_cancel_hint_job("")
	_stop_next_level_countdown()
	input_enabled = true
	status_label.text = ""
	is_animating = false
	solving = false
	solve_queue.clear()
	_clear_hint_cache()
	_hide_debug()
	load_level(_level_path_for(current_stage, current_level_in_stage))

func load_level(path: String) -> void:
	if editor_preview_active and editor_preview_path != "" and path != editor_preview_path:
		editor_preview_active = false
		editor_preview_path = ""
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
	_clear_animation_layer()
	_invalidate_par_if_needed(data)
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
	bouncers.clear()
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

	for bouncer_value in data.get("bouncers", []):
		if typeof(bouncer_value) != TYPE_DICTIONARY:
			continue
		var pos := _pos_from_value(bouncer_value.get("pos", []))
		var btype := String(bouncer_value.get("type", "reverse"))
		if _in_bounds(pos) and not walls.has(pos):
			var entry := {
				"type": btype
			}
			if bouncer_value.has("strength"):
				entry["strength"] = int(bouncer_value.get("strength", 0))
			bouncers[pos] = entry

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
	level_start_time_msec = Time.get_ticks_msec()
	_ensure_level_par_moves(20000)
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
	call_deferred("_animate_level_intro")

func _slide_with_bouncers(start: Vector2i, dir: Vector2i, occupied: Dictionary) -> Vector2i:
	var pos := start
	var current_dir := dir
	var visited: Dictionary = {}
	var safety := 0
	while true:
		var next := pos + current_dir
		if not _in_bounds(next):
			break
		if occupied.has(next):
			break
		pos = next
		safety += 1
		if safety > width * height * 4:
			break
		var state_key := "%d,%d,%d,%d" % [pos.x, pos.y, current_dir.x, current_dir.y]
		if visited.has(state_key):
			break
		visited[state_key] = true
		if bouncers.has(pos):
			var entry: Variant = bouncers[pos]
			var btype := "reverse"
			if typeof(entry) == TYPE_DICTIONARY:
				btype = String(entry.get("type", "reverse"))
			elif typeof(entry) == TYPE_STRING:
				btype = String(entry)
			if btype == "reverse":
				current_dir = -current_dir
	return pos

func _slide_with_bouncers_path(start: Vector2i, dir: Vector2i, occupied: Dictionary) -> Dictionary:
	var pos := start
	var current_dir := dir
	var points: Array = [start]
	var visited: Dictionary = {}
	var safety := 0
	while true:
		var next := pos + current_dir
		if not _in_bounds(next):
			break
		if occupied.has(next):
			break
		pos = next
		safety += 1
		if safety > width * height * 4:
			break
		var state_key := "%d,%d,%d,%d" % [pos.x, pos.y, current_dir.x, current_dir.y]
		if visited.has(state_key):
			break
		visited[state_key] = true
		if bouncers.has(pos):
			if points.back() != pos:
				points.append(pos)
			var entry: Variant = bouncers[pos]
			var btype := "reverse"
			if typeof(entry) == TYPE_DICTIONARY:
				btype = String(entry.get("type", "reverse"))
			elif typeof(entry) == TYPE_STRING:
				btype = String(entry)
			if btype == "reverse":
				current_dir = -current_dir
	if points.back() != pos:
		points.append(pos)
	return {"target": pos, "points": points}

func _compute_slide(is_row: bool, index: int, dir: int) -> Dictionary:
	var grid_copy := _clone_grid(grid)
	var locked_copy := locked.duplicate()
	var moves: Array = []
	var moved := false
	if is_row:
		if index < 0 or index >= height:
			return {"moved": false, "moves": moves, "grid": grid_copy, "locked": locked_copy}
		var occupied: Dictionary = {}
		for x in width:
			var pos := Vector2i(x, index)
			if walls.has(pos) or locked_copy.has(pos) or grid_copy[index][x] != -1:
				occupied[pos] = true
		var order := range(width - 1, -1, -1) if dir > 0 else range(0, width)
		for x in order:
			var pos := Vector2i(x, index)
			var color_id: int = grid_copy[index][x]
			if color_id == -1 or locked_copy.has(pos):
				continue
			occupied.erase(pos)
			var slide: Dictionary = _slide_with_bouncers_path(pos, Vector2i(dir, 0), occupied)
			var target_pos: Vector2i = slide["target"]
			var points: Array = slide["points"]
			if target_pos != pos:
				grid_copy[index][x] = -1
				grid_copy[target_pos.y][target_pos.x] = color_id
				moves.append({"from": pos, "to": target_pos, "color": color_id, "path": points})
				moved = true
			elif points.size() > 1:
				moves.append({"from": pos, "to": target_pos, "color": color_id, "path": points})
				moved = true
			occupied[target_pos] = true
			if holes.has(target_pos) and holes[target_pos] == color_id and not locked_copy.has(target_pos):
				locked_copy[target_pos] = true
				moved = true
	else:
		if index < 0 or index >= width:
			return {"moved": false, "moves": moves, "grid": grid_copy, "locked": locked_copy}
		var occupied: Dictionary = {}
		for y in height:
			var pos := Vector2i(index, y)
			if walls.has(pos) or locked_copy.has(pos) or grid_copy[y][index] != -1:
				occupied[pos] = true
		var order := range(height - 1, -1, -1) if dir > 0 else range(0, height)
		for y in order:
			var pos := Vector2i(index, y)
			var color_id: int = grid_copy[y][index]
			if color_id == -1 or locked_copy.has(pos):
				continue
			occupied.erase(pos)
			var slide: Dictionary = _slide_with_bouncers_path(pos, Vector2i(0, dir), occupied)
			var target_pos: Vector2i = slide["target"]
			var points: Array = slide["points"]
			if target_pos != pos:
				grid_copy[y][index] = -1
				grid_copy[target_pos.y][target_pos.x] = color_id
				moves.append({"from": pos, "to": target_pos, "color": color_id, "path": points})
				moved = true
			elif points.size() > 1:
				moves.append({"from": pos, "to": target_pos, "color": color_id, "path": points})
				moved = true
			occupied[target_pos] = true
			if holes.has(target_pos) and holes[target_pos] == color_id and not locked_copy.has(target_pos):
				locked_copy[target_pos] = true
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
			var bouncer_bg := _make_rect(cell, Color8(70, 120, 150), 10)
			bouncer_bg.visible = false
			var block := _make_tile(cell, 6)
			var bouncer_label := Label.new()
			bouncer_label.text = "R"
			bouncer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bouncer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			bouncer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			bouncer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bouncer_label.add_theme_font_size_override("font_size", 20)
			bouncer_label.add_theme_constant_override("outline_size", 2)
			bouncer_label.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0, 0.9))
			bouncer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
			bouncer_label.visible = false
			cell.add_child(bouncer_label)
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
			var frame := _make_frame(cell, Color(0.45, 0.6, 0.95, 0.35), 1)
			grid_container.add_child(cell)
			row.append({
				"base": base,
				"hole_outer": hole_outer,
				"hole_inner": hole_inner,
				"bouncer_bg": bouncer_bg,
				"bouncer_label": bouncer_label,
				"decal": decal,
				"block": block,
				"wall": wall,
				"frame": frame,
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
			var frame: Panel = cell["frame"]
			var hole_outer: ColorRect = cell["hole_outer"]
			var hole_inner: ColorRect = cell["hole_inner"]
			var bouncer_bg: ColorRect = cell["bouncer_bg"]
			var bouncer_label: Label = cell["bouncer_label"]
			var decal: Label = cell["decal"]
			var block: TextureRect = cell["block"]
			var wall: TextureRect = cell["wall"]
			if walls.has(pos):
				wall.visible = true
				wall.modulate = wall_tint_contrast if high_contrast else wall_tint
				wall.self_modulate = Color(1, 1, 1, 1)
				base.visible = false
				frame.visible = false
				hole_outer.visible = false
				hole_inner.visible = false
				bouncer_bg.visible = false
				bouncer_label.visible = false
				block.visible = false
				decal.visible = false
				continue
			wall.visible = false
			base.visible = true
			frame.visible = true
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
			if bouncers.has(pos):
				bouncer_bg.visible = true
				bouncer_label.visible = true
				var entry: Variant = bouncers[pos]
				var btype := "reverse"
				if typeof(entry) == TYPE_DICTIONARY:
					btype = String(entry.get("type", "reverse"))
				elif typeof(entry) == TYPE_STRING:
					btype = String(entry)
				if btype == "reverse":
					bouncer_label.text = "R"
				else:
					bouncer_label.text = "B"
			else:
				bouncer_bg.visible = false
				bouncer_label.visible = false
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
	if editor_preview_active:
		level_text = "Editor Preview"
	if header_label != null:
		header_label.text = _rainbow_title(level_text)
	if subheader_label != null:
		if editor_preview_active:
			var elapsed_ms: int = 0
			if level_start_time_msec > 0:
				elapsed_ms = maxi(0, Time.get_ticks_msec() - level_start_time_msec)
			var par_text := "-"
			if current_level_min_moves >= 0:
				par_text = str(current_level_min_moves)
			subheader_label.text = "Moves: %d | Time: %s | Par: %s" % [
				moves_made,
				_format_time_ms(elapsed_ms),
				par_text
			]
			if new_level_button != null:
				new_level_button.visible = false
			if home_button != null:
				home_button.visible = false
			if editor_back_button != null:
				editor_back_button.visible = true
			if stages_button != null:
				stages_button.visible = false
			return
		var key: String = _level_key(current_stage, current_level_in_stage)
		var entry: Dictionary = _get_level_stats_entry(key)
		var best_moves: int = 0
		if entry.has("best_moves"):
			best_moves = int(entry["best_moves"])
		var best_time_ms: int = 0
		if entry.has("best_time_ms"):
			best_time_ms = int(entry["best_time_ms"])
		var elapsed_ms: int = 0
		if level_start_time_msec > 0:
			elapsed_ms = maxi(0, Time.get_ticks_msec() - level_start_time_msec)
		var time_text: String = _format_time_ms(elapsed_ms)
		var best_time_text := "--:--"
		if best_time_ms > 0:
			best_time_text = _format_time_ms(best_time_ms)
		var par_text := "-"
		if current_level_min_moves >= 0:
			par_text = str(current_level_min_moves)
		var best_moves_text := "-"
		if best_moves > 0:
			best_moves_text = str(best_moves)
		subheader_label.text = "%s - %s\nMoves: %d | Time: %s | Par: %s | Best: %s/%s" % [
			current_level_name,
			current_theme_name,
			moves_made,
			time_text,
			par_text,
			best_moves_text,
			best_time_text
		]
	if new_level_button != null:
		var can_advance := _can_advance_level()
		new_level_button.disabled = not can_advance
		new_level_button.visible = can_advance

func _reset_next_level_button() -> void:
	if new_level_button != null:
		new_level_button.text = "Next Level"

func _update_next_level_button_text() -> void:
	if new_level_button != null:
		var value := maxi(0, next_level_countdown_left)
		new_level_button.text = "Next Level (%d)" % value

func _stop_next_level_countdown() -> void:
	next_level_countdown_active = false
	next_level_countdown_left = 0
	next_level_countdown_token += 1
	_reset_next_level_button()

func _animate_level_intro() -> void:
	if grid_container == null or cells.is_empty():
		return
	_show_grid_intro_flash()
	var blocks: Array = []
	for y in height:
		for x in width:
			if grid[y][x] == -1:
				continue
			var cell: Dictionary = cells[y][x]
			var base: ColorRect = cell["base"]
			var block: TextureRect = cell["block"]
			if not is_instance_valid(block) or not block.visible:
				continue
			if base != null:
				block.pivot_offset = base.size * 0.5
			block.scale = Vector2(0.7, 0.7)
			var color := block.modulate
			color.a = 0.0
			block.modulate = color
			blocks.append({"block": block, "pos": Vector2i(x, y)})
	level_intro_running = true
	input_enabled = false
	var tween: Tween = create_tween()
	tween.set_parallel()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for entry in blocks:
		var block: TextureRect = entry["block"]
		var pos: Vector2i = entry["pos"]
		var delay := float(pos.x + pos.y) * 0.015
		tween.tween_property(block, "scale", Vector2.ONE, 0.6).set_delay(delay)
		tween.tween_property(block, "modulate:a", 1.0, 0.6).set_delay(delay)
	tween.finished.connect(func() -> void:
		level_intro_running = false
		if not is_animating:
			input_enabled = true
	)

func _show_grid_intro_flash() -> void:
	if grid_container == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_prepare_animation_layer()
	var rect := _grid_bounds_rect_snapped()
	if rect.size == Vector2.ZERO:
		return
	var flash := ColorRect.new()
	flash.name = "GridIntroFlash"
	flash.color = Color(0.08, 0.12, 0.2, 0.75)
	flash.top_level = false
	flash.z_index = 1200
	flash.position = rect.position
	flash.size = rect.size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation_layer.add_child(flash)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "color:a", 0.0, 1.1)
	tween.finished.connect(flash.queue_free)

func _grid_bounds_rect_snapped() -> Rect2:
	if cells.is_empty():
		return Rect2()
	var first: Dictionary = cells[0][0]
	var base: ColorRect = first["base"]
	if base == null:
		return Rect2()
	var rect: Rect2 = base.get_global_rect()
	for y in height:
		for x in width:
			var cell: Dictionary = cells[y][x]
			var cell_base: ColorRect = cell["base"]
			if cell_base == null:
				continue
			rect = rect.merge(cell_base.get_global_rect())
	var pos := Vector2(floor(rect.position.x), floor(rect.position.y))
	var end := Vector2(floor(rect.position.x + rect.size.x), floor(rect.position.y + rect.size.y))
	rect.position = pos
	rect.size = Vector2(maxf(0.0, end.x - pos.x), maxf(0.0, end.y - pos.y))
	return rect

func _pq_push(heap: Array, item: Dictionary) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if int(heap[parent]["f"]) <= int(item["f"]):
			break
		heap[i] = heap[parent]
		i = parent
	heap[i] = item

func _pq_pop(heap: Array) -> Dictionary:
	if heap.is_empty():
		return {}
	var root: Dictionary = heap[0]
	var last: Variant = heap.pop_back()
	if heap.is_empty():
		return root
	var item: Dictionary = {}
	if typeof(last) == TYPE_DICTIONARY:
		item = last
	var i := 0
	var size := heap.size()
	while true:
		var left := i * 2 + 1
		if left >= size:
			break
		var right := left + 1
		var smallest := left
		if right < size and int(heap[right]["f"]) < int(heap[left]["f"]):
			smallest = right
		if int(item["f"]) <= int(heap[smallest]["f"]):
			break
		heap[i] = heap[smallest]
		i = smallest
	heap[i] = item
	return root

func _start_next_level_countdown() -> void:
	if editor_preview_active:
		return
	if current_level_in_stage >= LEVELS_PER_STAGE:
		return
	if not _can_advance_level():
		return
	if new_level_button == null:
		return
	_stop_next_level_countdown()
	next_level_countdown_active = true
	next_level_countdown_left = 5
	next_level_countdown_token += 1
	var token: int = next_level_countdown_token
	new_level_button.visible = true
	_update_next_level_button_text()
	_schedule_next_level_tick(token)

func _schedule_next_level_tick(token: int) -> void:
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func() -> void:
		if token != next_level_countdown_token:
			return
		if not next_level_countdown_active:
			return
		next_level_countdown_left -= 1
		if next_level_countdown_left <= 0:
			next_level_countdown_active = false
			_reset_next_level_button()
			_on_new_level_pressed()
			return
		_update_next_level_button_text()
		_schedule_next_level_tick(token)
	)

func _level_key(stage: int, level: int) -> String:
	return "%d-%d" % [stage, level]

func _get_level_stats_entry(key: String) -> Dictionary:
	var entry: Dictionary = {}
	if level_stats.has(key):
		var entry_value: Variant = level_stats[key]
		if typeof(entry_value) == TYPE_DICTIONARY:
			entry = entry_value
	return entry

func _format_time_ms(ms: int) -> String:
	var safe_ms: int = maxi(0, ms)
	var total_sec := int(safe_ms / 1000)
	var minutes := int(total_sec / 60)
	var seconds := int(total_sec % 60)
	return "%02d:%02d" % [minutes, seconds]

func _ensure_level_par_moves(max_states: int) -> void:
	current_level_min_moves = -1
	var key: String = _level_key(current_stage, current_level_in_stage)
	var entry: Dictionary = _get_level_stats_entry(key)
	if entry.has("par_moves"):
		current_level_min_moves = int(entry["par_moves"])
		return
	var result: Dictionary = _solve_level_status(max_states)
	var capped_var: Variant = result.get("capped", false)
	var capped := bool(capped_var)
	var path_var: Variant = result.get("path", [])
	var path: Array = []
	if typeof(path_var) == TYPE_ARRAY:
		path = path_var
	if not capped and _grid_is_win(grid):
		current_level_min_moves = 0
		entry["par_moves"] = current_level_min_moves
		entry["par_version"] = 1
		level_stats[key] = entry
		_save_progress()
	elif not capped and not path.is_empty():
		current_level_min_moves = path.size()
		entry["par_moves"] = current_level_min_moves
		entry["par_version"] = 1
		level_stats[key] = entry
		_save_progress()

func _invalidate_par_if_needed(data: Dictionary) -> void:
	var bval: Variant = data.get("bouncers", [])
	if typeof(bval) != TYPE_ARRAY or bval.is_empty():
		return
	var key: String = _level_key(current_stage, current_level_in_stage)
	if not level_stats.has(key):
		return
	var entry_var: Variant = level_stats[key]
	if typeof(entry_var) != TYPE_DICTIONARY:
		return
	var entry: Dictionary = entry_var
	if not entry.has("par_moves"):
		return
	var version := int(entry.get("par_version", 0))
	if version >= 1:
		return
	entry.erase("par_moves")
	entry.erase("par_version")
	level_stats[key] = entry
	_save_progress()

func _record_level_stats() -> void:
	var key: String = _level_key(current_stage, current_level_in_stage)
	var entry: Dictionary = _get_level_stats_entry(key)
	var elapsed_ms: int = 0
	if level_start_time_msec > 0:
		elapsed_ms = maxi(0, Time.get_ticks_msec() - level_start_time_msec)
	entry["last_moves"] = moves_made
	entry["last_time_ms"] = elapsed_ms
	if current_level_min_moves >= 0:
		entry["par_moves"] = current_level_min_moves
	var best_moves: int = 0
	if entry.has("best_moves"):
		best_moves = int(entry["best_moves"])
	if best_moves <= 0 or moves_made < best_moves:
		entry["best_moves"] = moves_made
	var best_time_ms: int = 0
	if entry.has("best_time_ms"):
		best_time_ms = int(entry["best_time_ms"])
	if best_time_ms <= 0 or elapsed_ms < best_time_ms:
		entry["best_time_ms"] = elapsed_ms
	level_stats[key] = entry
	_save_progress()

func _can_advance_level() -> bool:
	var completed: int = int(stage_progress.get(str(current_stage), 0))
	var max_unlocked: int = min(completed + 1, LEVELS_PER_STAGE)
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

func _make_frame(parent: Control, color: Color, thickness: int) -> Panel:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.border_width_left = thickness
	style.border_width_right = thickness
	style.border_width_top = thickness
	style.border_width_bottom = thickness
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

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
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
		current_difficulty_label = _normalize_difficulty_label(String(manual_label))
		level_difficulty_text = "Diff: %s" % current_difficulty_label
		return
	var analysis := _analyze_difficulty(max_states)
	if analysis.has("label"):
		current_difficulty_label = _normalize_difficulty_label(String(analysis["label"]))
		level_difficulty_text = "Diff: %s" % current_difficulty_label

func _simulate_slide(source: Array, is_row: bool, index: int, dir: int) -> Dictionary:
	var grid_copy := _clone_grid(source)
	var locked_copy := _locked_from_grid(grid_copy)
	var moved := false
	if is_row:
		if index < 0 or index >= height:
			return {"moved": false, "grid": grid_copy}
		var occupied: Dictionary = {}
		for x in width:
			var pos := Vector2i(x, index)
			if walls.has(pos) or locked_copy.has(pos) or grid_copy[index][x] != -1:
				occupied[pos] = true
		var order := range(width - 1, -1, -1) if dir > 0 else range(0, width)
		for x in order:
			var pos := Vector2i(x, index)
			var color_id: int = grid_copy[index][x]
			if color_id == -1 or locked_copy.has(pos):
				continue
			occupied.erase(pos)
			var target_pos := _slide_with_bouncers(pos, Vector2i(dir, 0), occupied)
			if target_pos != pos:
				grid_copy[index][x] = -1
				grid_copy[target_pos.y][target_pos.x] = color_id
				moved = true
			occupied[target_pos] = true
			if holes.has(target_pos) and holes[target_pos] == color_id and not locked_copy.has(target_pos):
				locked_copy[target_pos] = true
				moved = true
	else:
		if index < 0 or index >= width:
			return {"moved": false, "grid": grid_copy}
		var occupied: Dictionary = {}
		for y in height:
			var pos := Vector2i(index, y)
			if walls.has(pos) or locked_copy.has(pos) or grid_copy[y][index] != -1:
				occupied[pos] = true
		var order := range(height - 1, -1, -1) if dir > 0 else range(0, height)
		for y in order:
			var pos := Vector2i(index, y)
			var color_id: int = grid_copy[y][index]
			if color_id == -1 or locked_copy.has(pos):
				continue
			occupied.erase(pos)
			var target_pos := _slide_with_bouncers(pos, Vector2i(0, dir), occupied)
			if target_pos != pos:
				grid_copy[y][index] = -1
				grid_copy[target_pos.y][target_pos.x] = color_id
				moved = true
			occupied[target_pos] = true
			if holes.has(target_pos) and holes[target_pos] == color_id and not locked_copy.has(target_pos):
				locked_copy[target_pos] = true
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

func _clear_animation_layer() -> void:
	if animation_layer == null:
		return
	hide_blocks_for_anim = false
	for child in animation_layer.get_children():
		child.queue_free()

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
	ghost.material = tile.material
	ghost.use_parent_material = tile.use_parent_material
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

func _ensure_music_player(node_name: String) -> AudioStreamPlayer:
	var existing := get_node_or_null(node_name)
	if existing != null and existing is AudioStreamPlayer:
		return existing as AudioStreamPlayer
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.volume_db = music_volume_db
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
	if grid_container != null:
		grid_container.visible = false
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1100
	overlay.z_as_relative = false
	animation_layer.add_child(overlay)

	var tiles_layer := Control.new()
	tiles_layer.name = "WinTiles"
	tiles_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tiles_layer.z_index = 1090
	tiles_layer.z_as_relative = false
	overlay.add_child(tiles_layer)

	var grid_rect: Rect2 = grid_container.get_global_rect()
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
	tween.tween_interval(2.2)
	tween.tween_property(banner_box, "modulate", Color(1, 1, 1, 0), 0.45)

	var effect_duration: float = _play_win_grid_effect(tiles_layer)
	var overlay_duration: float = maxf(effect_duration + 1.0, 3.2)
	var cleanup_timer := get_tree().create_timer(overlay_duration)
	cleanup_timer.timeout.connect(overlay.queue_free)

func _spawn_confetti(parent: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rect: Rect2 = grid_container.get_global_rect()
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

func _play_win_grid_effect(layer: Control) -> float:
	if cells.is_empty():
		return 0.0
	var tiles: Array[Control] = _collect_win_tiles(layer)
	if tiles.is_empty():
		return 0.0
	var effect: int = win_rng.randi_range(0, 3)
	if effect == 0:
		return _win_vortex(tiles)
	if effect == 1:
		return _win_shatter(tiles)
	if effect == 2:
		return _win_drop(tiles)
	return _win_wave(tiles)

func _collect_win_tiles(layer: Control) -> Array[Control]:
	var out: Array[Control] = []
	for y in height:
		for x in width:
			var cell: Dictionary = cells[y][x]
			var base: ColorRect = cell["base"]
			var block: TextureRect = cell["block"]
			var wall: TextureRect = cell["wall"]
			if base == null:
				continue
			var color: Color = base.color
			if wall.visible:
				color = wall_tint
			elif block.visible:
				color = block.modulate
			var tile := ColorRect.new()
			tile.color = color
			tile.size = base.size
			tile.custom_minimum_size = base.size
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.z_index = 1090
			tile.z_as_relative = false
			layer.add_child(tile)
			tile.global_position = base.global_position
			tile.pivot_offset = base.size * 0.5
			out.append(tile)
	return out

func _win_vortex(tiles: Array[Control]) -> float:
	var rect: Rect2 = grid_container.get_global_rect()
	var center: Vector2 = rect.position + rect.size * 0.5
	var max_span: float = maxf(rect.size.x, rect.size.y)
	var max_delay: float = 0.0
	for tile in tiles:
		var dist: float = tile.global_position.distance_to(center)
		var delay: float = (dist / max_span) * 0.35
		max_delay = maxf(max_delay, delay)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var target := center - tile.size * 0.5
		tween.tween_property(tile, "global_position", target, 1.0).set_delay(delay)
		tween.parallel().tween_property(tile, "scale", Vector2(0.05, 0.05), 1.0).set_delay(delay)
		tween.parallel().tween_property(tile, "modulate:a", 0.0, 1.0).set_delay(delay)
		tween.parallel().tween_property(tile, "rotation", win_rng.randf_range(-PI, PI), 1.0).set_delay(delay)
		tween.finished.connect(tile.queue_free)
	return 1.0 + max_delay

func _win_shatter(tiles: Array[Control]) -> float:
	var max_delay: float = 0.0
	for tile in tiles:
		var delay: float = win_rng.randf_range(0.0, 0.3)
		max_delay = maxf(max_delay, delay)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "scale", Vector2(1.25, 1.25), 0.3).from(Vector2.ONE).set_delay(delay)
		tween.parallel().tween_property(tile, "modulate:a", 0.0, 0.7).set_delay(delay + 0.15)
		tween.parallel().tween_property(tile, "scale", Vector2(0.0, 0.0), 0.7).set_delay(delay + 0.15)
		tween.finished.connect(tile.queue_free)
	return 1.0 + max_delay

func _win_drop(tiles: Array[Control]) -> float:
	var rect: Rect2 = grid_container.get_global_rect()
	var max_delay: float = 0.0
	for tile in tiles:
		var row_ratio: float = clampf((tile.global_position.y - rect.position.y) / rect.size.y, 0.0, 1.0)
		var delay: float = row_ratio * 0.4
		max_delay = maxf(max_delay, delay)
		var target := tile.global_position + Vector2(win_rng.randf_range(-40.0, 40.0), rect.size.y + 160.0)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(tile, "global_position", target, 1.1).set_delay(delay)
		tween.parallel().tween_property(tile, "modulate:a", 0.0, 1.1).set_delay(delay)
		tween.finished.connect(tile.queue_free)
	return 1.1 + max_delay

func _win_wave(tiles: Array[Control]) -> float:
	var rect: Rect2 = grid_container.get_global_rect()
	var max_delay: float = 0.0
	for tile in tiles:
		var row_ratio: float = clampf((tile.global_position.y - rect.position.y) / rect.size.y, 0.0, 1.0)
		var delay: float = row_ratio * 0.5
		max_delay = maxf(max_delay, delay)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(tile, "modulate:a", 0.0, 0.9).set_delay(delay)
		tween.parallel().tween_property(tile, "scale", Vector2(0.7, 0.7), 0.9).set_delay(delay)
		tween.finished.connect(tile.queue_free)
	return 0.9 + max_delay
func _show_debug_line(is_row: bool, index: int, dir: int = 0, duration: float = 0.25) -> void:
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
	if dir != 0:
		_add_debug_chevrons(is_row, index, dir)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(_hide_debug)

func _add_debug_chevrons(is_row: bool, index: int, dir: int) -> void:
	if cells.is_empty():
		return
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.78, 0.9, 1.0, 0.2)
	glass.border_color = Color(1, 1, 1, 0.4)
	glass.border_width_left = 2
	glass.border_width_right = 2
	glass.border_width_top = 2
	glass.border_width_bottom = 2
	glass.corner_radius_top_left = 14
	glass.corner_radius_top_right = 14
	glass.corner_radius_bottom_left = 14
	glass.corner_radius_bottom_right = 14
	glass.shadow_color = Color(0, 0, 0, 0.3)
	glass.shadow_size = 10
	glass.shadow_offset = Vector2(0, 4)
	var grid_rect: Rect2 = grid_container.get_global_rect()
	if is_row:
		if index < 0 or index >= height:
			return
		var cell: Dictionary = cells[index][0]
		var panel := PanelContainer.new()
		panel.size = Vector2(grid_rect.size.x, cell_size)
		panel.custom_minimum_size = panel.size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", glass)
		panel.z_index = 905
		debug_layer.add_child(panel)
		panel.global_position = Vector2(grid_rect.position.x, cell["base"].global_position.y)
		var label := Label.new()
		var chevrons := ">" if dir > 0 else "<"
		label.text = chevrons.repeat(3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.95))
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.35, 0.7))
		panel.add_child(label)
	else:
		if index < 0 or index >= width:
			return
		var cell: Dictionary = cells[0][index]
		var arrow := "v" if dir > 0 else "^"
		var lines: Array[String] = []
		for _i in 3:
			lines.append(arrow)
		var panel := PanelContainer.new()
		panel.size = Vector2(cell_size, grid_rect.size.y)
		panel.custom_minimum_size = panel.size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", glass)
		panel.z_index = 905
		debug_layer.add_child(panel)
		panel.global_position = Vector2(cell["base"].global_position.x, grid_rect.position.y)
		var label := Label.new()
		label.text = "\n".join(lines)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.95))
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.35, 0.7))
		panel.add_child(label)

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
	for i in range(1, STAGE_COUNT * LEVELS_PER_STAGE + 1):
		level_paths.append("res://levels/level_%03d.json" % i)

func _level_path_for(stage: int, level_in_stage: int) -> String:
	var index := (stage - 1) * LEVELS_PER_STAGE + (level_in_stage - 1)
	if index < 0 or index >= level_paths.size():
		return ""
	return level_paths[index]

func _mark_level_complete() -> void:
	var key := str(current_stage)
	var current_max := int(stage_progress.get(key, 0))
	var unlocked := current_level_in_stage > current_max
	if unlocked:
		stage_progress[key] = current_level_in_stage
	_save_progress()
	if current_level_in_stage >= LEVELS_PER_STAGE and current_stage == unlocked_stage and current_stage < STAGE_COUNT:
		unlocked_stage += 1
	_save_progress()
	if unlocked:
		_play_ui_success()
	_update_stage_buttons()
	_update_hud()

func _load_progress() -> void:
	stage_progress = {}
	level_stats = {}
	hint_uses_by_level = {}
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
	var stats: Variant = data.get("level_stats", {})
	if typeof(stats) == TYPE_DICTIONARY:
		for key in stats.keys():
			var entry: Variant = stats[key]
			if typeof(entry) == TYPE_DICTIONARY:
				level_stats[str(key)] = entry
	var hints: Variant = data.get("hint_uses", {})
	if typeof(hints) == TYPE_DICTIONARY:
		for key in hints.keys():
			hint_uses_by_level[str(key)] = int(hints[key])

func _save_progress() -> void:
	var data := {
		"unlocked_stage": unlocked_stage,
		"stage_progress": stage_progress,
		"level_stats": level_stats,
		"hint_uses": hint_uses_by_level
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
	music_enabled = bool(data.get("music_enabled", true))
	music_volume_db = float(data.get("music_volume_db", music_volume_db))
	hints_unlocked = bool(data.get("hints_unlocked", hints_unlocked))
	daily_hint_date = String(data.get("daily_hint_date", ""))
	daily_hint_used = int(data.get("daily_hint_used", 0))
	_refresh_daily_hint()
	_sync_settings_ui()

func _sync_settings_ui() -> void:
	var sound := options_panel.get_node_or_null("OptionsLayout/OptionsCenter/OptionsBox/OptionsVBox/SoundCheck") as CheckButton
	if sound != null:
		sound.button_pressed = sound_enabled
	var music := options_panel.get_node_or_null("OptionsLayout/OptionsCenter/OptionsBox/OptionsVBox/MusicCheck") as CheckButton
	if music != null:
		music.button_pressed = music_enabled

func _save_settings() -> void:
	var data := {
		"sound_enabled": sound_enabled,
		"music_enabled": music_enabled,
		"music_volume_db": music_volume_db,
		"hints_unlocked": hints_unlocked,
		"daily_hint_date": daily_hint_date,
		"daily_hint_used": daily_hint_used
	}
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))

func _wire_stage_panel(panel: Control) -> void:
	var backdrop: TextureRect = panel.get_node_or_null("StageBackdrop") as TextureRect
	if backdrop != null and backdrop.texture == null:
		backdrop.texture = load("res://assets/bg/bg_stageselect.png") as Texture2D
	if backdrop != null:
		_apply_background_cover(backdrop)

	var title: RichTextLabel = panel.get_node_or_null("StagePanelVBox/StageTitleWrap/StageTitle") as RichTextLabel
	if title != null and title.text.strip_edges() == "":
		title.bbcode_enabled = true
		title.fit_content = true
		title.scroll_active = false
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.text = _rainbow_title("Select Stage")

	var grid := panel.get_node_or_null("StagePanelVBox/StageGridMargin/StageGrid") as GridContainer
	if grid == null:
		grid = panel.get_node_or_null("StagePanelVBox/StageGridMargin/StageGridScroll/StageGrid") as GridContainer
	if grid != null:
		_populate_stage_grid(grid)

	var home: Button = panel.get_node_or_null("StageHomeBar/StageHomeWrap/StageHomeButton") as Button
	if home != null:
		if not home.pressed.is_connected(_on_home_pressed):
			home.pressed.connect(_on_home_pressed)
		if not home.has_theme_stylebox_override("normal"):
			_style_start_button(home, Color8(83, 201, 255))

func _populate_stage_grid(grid: GridContainer) -> void:
	if grid.get_child_count() > 0:
		return
	if grid.columns <= 0:
		grid.columns = STAGE_GRID_COLUMNS
	for i in range(1, 11):
		var btn := Button.new()
		btn.name = "StageButton%d" % i
		btn.text = ""
		btn.flat = false
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(STAGE_CARD_HEIGHT, STAGE_CARD_HEIGHT)
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
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(name_label)

		var theme_label := Label.new()
		theme_label.name = "StageTheme%d" % i
		theme_label.text = ""
		theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		theme_label.add_theme_font_size_override("font_size", 16)
		theme_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		theme_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(theme_label)

		var progress := ProgressBar.new()
		progress.name = "StageProgress%d" % i
		progress.min_value = 0
		progress.max_value = LEVELS_PER_STAGE
		progress.value = 0
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		progress.custom_minimum_size = Vector2(0, 14)
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(progress)

		var lock_label := Label.new()
		lock_label.name = "StageLocked%d" % i
		lock_label.text = "Locked"
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.add_theme_font_size_override("font_size", 14)
		lock_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		lock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock_label.visible = false
		content.add_child(lock_label)

func _ensure_stage_panel() -> Control:
	var existing := get_node_or_null("StagePanel")
	if existing != null and existing is Control:
		var panel_existing := existing as Control
		_wire_stage_panel(panel_existing)
		return panel_existing

	var panel := Control.new()
	panel.name = "StagePanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "StageBackdrop"
	backdrop.texture = load("res://assets/bg/bg_stageselect.png") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_background_cover(backdrop)
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
	vbox.add_theme_constant_override("separation", 18)
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
	title_wrap.custom_minimum_size = Vector2(0, 140)
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
	title.add_theme_font_size_override("normal_font_size", 46)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.add_child(title)

	var grid_spacer := Control.new()
	grid_spacer.name = "StageGridSpacer"
	grid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_spacer)

	var grid_margin := MarginContainer.new()
	grid_margin.name = "StageGridMargin"
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid_margin.add_theme_constant_override("margin_left", 16)
	grid_margin.add_theme_constant_override("margin_right", 16)
	grid_margin.add_theme_constant_override("margin_top", 32)
	grid_margin.add_theme_constant_override("margin_bottom", 32)
	vbox.add_child(grid_margin)

	var grid := GridContainer.new()
	grid.name = "StageGrid"
	grid.columns = STAGE_GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hsep := 48
	var vsep := 40
	grid.add_theme_constant_override("hseparation", hsep)
	grid.add_theme_constant_override("vseparation", vsep)
	var rows := int(ceil(float(STAGE_COUNT) / float(grid.columns)))
	var col_gaps := maxi(0, STAGE_GRID_COLUMNS - 1)
	var row_gaps := maxi(0, rows - 1)
	var grid_width: float = float(STAGE_GRID_COLUMNS * STAGE_CARD_HEIGHT + col_gaps * hsep)
	var grid_height: float = float(rows * STAGE_CARD_HEIGHT + row_gaps * vsep)
	grid.custom_minimum_size = Vector2(grid_width, grid_height)
	grid_margin.add_child(grid)

	_populate_stage_grid(grid)
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
	_wire_stage_panel(panel)
	return panel

func _update_stage_buttons() -> void:
	var grid := stage_panel.get_node_or_null("StagePanelVBox/StageGridMargin/StageGrid") as GridContainer
	if grid == null:
		grid = stage_panel.get_node_or_null("StagePanelVBox/StageGridMargin/StageGridScroll/StageGrid") as GridContainer
	if grid == null:
		return
	for i in range(1, STAGE_COUNT + 1):
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
		progress.max_value = LEVELS_PER_STAGE
		progress.value = completed
		var locked := i > unlocked_stage
		var unplayed := completed == 0
		btn.disabled = locked
		_style_stage_card(btn, theme_index, locked, unplayed)
		if lock_label != null:
			lock_label.visible = locked
			lock_label.text = "Locked" if locked else ""

func _wire_level_panel(panel: Control) -> void:
	var backdrop: TextureRect = panel.get_node_or_null("LevelBackdrop") as TextureRect
	if backdrop != null and backdrop.texture == null:
		backdrop.texture = load("res://assets/bg/bg_levelselect.png") as Texture2D
	if backdrop != null:
		_apply_background_cover(backdrop)

	var title: RichTextLabel = panel.get_node_or_null("LevelPanelVBox/LevelTitleWrap/LevelTitle") as RichTextLabel
	if title != null and title.text.strip_edges() == "":
		title.bbcode_enabled = true
		title.fit_content = true
		title.scroll_active = false
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.text = _rainbow_title("Select Level")

	var grid := panel.get_node_or_null("LevelPanelVBox/LevelGridRow/LevelGridMargin/LevelGrid") as GridContainer
	if grid != null:
		grid.columns = LEVEL_GRID_COLUMNS
		grid.add_theme_constant_override("hseparation", 18)
		grid.add_theme_constant_override("vseparation", 16)
		_populate_level_grid(grid)

	var home: Button = panel.get_node_or_null("LevelHomeBar/LevelHomeWrap/LevelHomeButton") as Button
	if home != null:
		if not home.pressed.is_connected(_on_home_pressed):
			home.pressed.connect(_on_home_pressed)
		if not home.has_theme_stylebox_override("normal"):
			_style_start_button(home, Color8(83, 201, 255))

func _populate_level_grid(grid: GridContainer) -> void:
	if grid.get_child_count() > 0:
		return
	if grid.columns <= 0:
		grid.columns = LEVEL_GRID_COLUMNS
	for i in range(1, LEVELS_PER_STAGE + 1):
		var btn := Button.new()
		btn.name = "LevelButton%d" % i
		btn.text = ""
		btn.custom_minimum_size = Vector2(LEVEL_BUTTON_WIDTH, LEVEL_BUTTON_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_on_level_pressed.bind(i))
		grid.add_child(btn)

		var content := HBoxContainer.new()
		content.name = "LevelContent%d" % i
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 8)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(content)

		var label := Label.new()
		label.name = "LevelLabel%d" % i
		label.text = "Level %d" % i
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		content.add_child(label)

		var tick := Label.new()
		tick.name = "LevelTick%d" % i
		tick.text = ""
		tick.add_theme_font_size_override("font_size", 16)
		tick.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		content.add_child(tick)

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
	_clear_animation_layer()
	_cancel_hint_job("")
	_stop_next_level_countdown()
	status_label.text = ""
	_apply_menu_theme(current_stage)
	if background_rect != null:
		background_rect.visible = false

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
	if background_rect != null:
		background_rect.visible = true
		_apply_background_cover(background_rect)

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
	var existing := get_node_or_null("LevelPanel")
	if existing != null and existing is Control:
		var panel_existing := existing as Control
		_wire_level_panel(panel_existing)
		return panel_existing

	var panel := Control.new()
	panel.name = "LevelPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	var backdrop := TextureRect.new()
	backdrop.name = "LevelBackdrop"
	backdrop.texture = load("res://assets/bg/bg_levelselect.png") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_background_cover(backdrop)
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
	vbox.add_theme_constant_override("separation", 18)
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
	title_wrap.custom_minimum_size = Vector2(0, 140)
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
	title.add_theme_font_size_override("normal_font_size", 46)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_wrap.add_child(title)

	var grid_spacer := Control.new()
	grid_spacer.name = "LevelGridSpacer"
	grid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_spacer)

	var grid_row := HBoxContainer.new()
	grid_row.name = "LevelGridRow"
	grid_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_row.add_theme_constant_override("separation", 0)
	vbox.add_child(grid_row)

	var left_spacer := Control.new()
	left_spacer.name = "LevelGridLeftSpacer"
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_row.add_child(left_spacer)

	var grid_margin := MarginContainer.new()
	grid_margin.name = "LevelGridMargin"
	grid_margin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid_margin.add_theme_constant_override("margin_left", 16)
	grid_margin.add_theme_constant_override("margin_right", 16)
	grid_margin.add_theme_constant_override("margin_top", 32)
	grid_margin.add_theme_constant_override("margin_bottom", 32)
	grid_row.add_child(grid_margin)

	var right_spacer := Control.new()
	right_spacer.name = "LevelGridRightSpacer"
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_row.add_child(right_spacer)

	var grid := GridContainer.new()
	grid.name = "LevelGrid"
	grid.columns = LEVEL_GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hsep := 18
	var vsep := 16
	grid.add_theme_constant_override("hseparation", hsep)
	grid.add_theme_constant_override("vseparation", vsep)
	grid_margin.add_child(grid)

	_populate_level_grid(grid)
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
	_wire_level_panel(panel)
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
	_clear_animation_layer()
	_cancel_hint_job("")
	_stop_next_level_countdown()
	var title := level_panel.get_node_or_null("LevelPanelVBox/LevelTitleWrap/LevelTitle") as RichTextLabel
	if title != null:
		title.text = _rainbow_title("Stage %d" % current_stage)
	_update_level_buttons()
	_apply_menu_theme(current_stage)
	if background_rect != null:
		background_rect.visible = false

func _update_level_buttons() -> void:
	var grid := level_panel.get_node("LevelPanelVBox/LevelGridRow/LevelGridMargin/LevelGrid") as GridContainer
	if grid == null:
		return
	var completed := int(stage_progress.get(str(current_stage), 0))
	var theme_index: int = clampi(current_stage - 1, 0, THEME_ACCENTS.size() - 1)
	var unlocked_limit: int = max(completed + 1, current_level_in_stage)
	for i in range(1, LEVELS_PER_STAGE + 1):
		var btn := grid.get_node("LevelButton%d" % i) as Button
		if btn == null:
			continue
		if not btn.has_meta("level_connected"):
			btn.pressed.connect(_on_level_pressed.bind(i))
			btn.set_meta("level_connected", true)
		var label := btn.get_node_or_null("LevelContent%d/LevelLabel%d" % [i, i]) as Label
		if label != null:
			label.text = "Level %d" % i
		var tick := btn.get_node_or_null("LevelContent%d/LevelTick%d" % [i, i]) as Label
		if tick != null:
			tick.text = "✓" if i <= completed else ""
		var locked: bool = i > min(unlocked_limit, LEVELS_PER_STAGE)
		btn.disabled = locked
		_style_level_button(btn, theme_index, locked)

func _on_level_pressed(level_in_stage: int) -> void:
	current_level_in_stage = level_in_stage
	new_level()

func _wire_stage_complete_popup(panel: Control) -> void:
	panel.z_index = 2000
	panel.z_as_relative = false
	panel.set_as_top_level(true)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := panel.get_node_or_null("StageCompleteDim") as ColorRect
	if dim == null:
		dim = ColorRect.new()
		dim.name = "StageCompleteDim"
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0, 0, 0, 0.35)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_child(dim)
		panel.move_child(dim, 0)
	var back: Button = panel.get_node_or_null("StageCompleteCenter/StageCompletePanel/StageCompleteVBox/StageCompleteButtons/StageCompleteButton") as Button
	if back != null:
		if not back.pressed.is_connected(_on_stage_complete_pressed):
			back.pressed.connect(_on_stage_complete_pressed)
		if not back.has_theme_stylebox_override("normal"):
			_style_start_button(back, Color8(83, 201, 255))

	var next: Button = panel.get_node_or_null("StageCompleteCenter/StageCompletePanel/StageCompleteVBox/StageCompleteButtons/StageCompleteNextButton") as Button
	if next != null:
		if not next.pressed.is_connected(_on_stage_complete_next_pressed):
			next.pressed.connect(_on_stage_complete_next_pressed)
		if not next.has_theme_stylebox_override("normal"):
			_style_start_button(next, Color8(109, 255, 160))

func _ensure_stage_complete_popup() -> Control:
	var existing := get_node_or_null("StageCompletePopup")
	if existing != null and existing is Control:
		var panel_existing := existing as Control
		_wire_stage_complete_popup(panel_existing)
		return panel_existing

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
	_wire_stage_complete_popup(panel)
	return panel

func _show_stage_complete() -> void:
	stage_complete_popup.visible = true
	game_panel.visible = true
	input_enabled = false
	var label := stage_complete_popup.get_node_or_null("StageCompleteCenter/StageCompletePanel/StageCompleteVBox/StageCompleteLabel") as Label
	var next := stage_complete_popup.get_node_or_null("StageCompleteCenter/StageCompletePanel/StageCompleteVBox/StageCompleteButtons/StageCompleteNextButton") as Button
	if current_stage >= STAGE_COUNT:
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
	if current_stage < STAGE_COUNT:
		current_stage += 1
		current_level_in_stage = 1
		new_level()

func _show_start_screen() -> void:
	editor_preview_active = false
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
	_clear_animation_layer()
	_cancel_hint_job("")
	_stop_next_level_countdown()
	status_label.text = ""
	_update_start_panel_unlock_button()
	_update_start_panel_restore_button()
	call_deferred("_start_home_fx")
	if background_rect != null:
		background_rect.visible = false

func _on_home_pressed() -> void:
	editor_preview_active = false
	if editor_preview_path != "":
		get_tree().set_meta("editor_return_path", editor_preview_path)
		get_tree().change_scene_to_file("res://LevelEditor.tscn")
		return
	_show_start_screen()

func _on_back_to_editor_pressed() -> void:
	if editor_preview_path != "":
		get_tree().set_meta("editor_return_path", editor_preview_path)
	get_tree().change_scene_to_file("res://LevelEditor.tscn")

func _open_level_editor() -> void:
	get_tree().change_scene_to_file("res://LevelEditor.tscn")

func _check_editor_preview() -> void:
	if not get_tree().has_meta("editor_preview_path"):
		return
	var path := str(get_tree().get_meta("editor_preview_path"))
	get_tree().remove_meta("editor_preview_path")
	if path.strip_edges() == "":
		return
	editor_preview_active = true
	editor_preview_path = path

func _start_home_fx() -> void:
	_ensure_start_twinkles()
	_play_start_sparkles()

func _start_current_level() -> void:
	var target := _next_unlocked_level()
	current_stage = target.x
	current_level_in_stage = target.y
	new_level()

func _next_unlocked_level() -> Vector2i:
	var stage := clampi(unlocked_stage, 1, STAGE_COUNT)
	var completed := int(stage_progress.get(str(stage), 0))
	var level := clampi(completed + 1, 1, LEVELS_PER_STAGE)
	return Vector2i(stage, level)

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

func _normalize_difficulty_label(label: String) -> String:
	var trimmed := label.strip_edges().to_lower()
	if trimmed == "very easy":
		return "easy"
	if trimmed == "very hard":
		return "hard"
	return trimmed

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
	_stop_next_level_countdown()
	if not _can_advance_level():
		status_label.text = "Unlock the next level first"
		return
	current_level_in_stage += 1
	new_level()

func _on_restart_pressed() -> void:
	restart_level()
