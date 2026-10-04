extends CanvasLayer
## Polished editor chrome: top bar, tool rail, inspector dock, status bar.

const TOOL_META := "editor_tool"

@onready var brand_label: Label = %BrandLabel
@onready var map_title: Label = %MapTitle
@onready var status_label: Label = %StatusLabel
@onready var tool_hint: Label = %ToolHint
@onready var dirty_badge: Control = %DirtyBadge
@onready var name_edit: LineEdit = %NameEdit
@onready var width_spin: SpinBox = %WidthSpin
@onready var length_spin: SpinBox = %LengthSpin
@onready var height_spin: SpinBox = %HeightSpin
@onready var res_spin: SpinBox = %ResSpin
@onready var brush_radius: HSlider = %BrushRadius
@onready var brush_strength: HSlider = %BrushStrength
@onready var brush_radius_value: Label = %BrushRadiusValue
@onready var brush_strength_value: Label = %BrushStrengthValue
@onready var set_height_slider: HSlider = %SetHeightSlider
@onready var set_height_value: Label = %SetHeightValue
@onready var water_check: CheckBox = %WaterCheck
@onready var water_level: HSlider = %WaterLevel
@onready var water_level_value: Label = %WaterLevelValue
@onready var open_dialog: FileDialog = %OpenDialog
@onready var save_dialog: FileDialog = %SaveDialog
@onready var top_bar: Control = %TopBar
@onready var tool_rail: Control = %ToolRail
@onready var side_dock: Control = %SideDock
@onready var status_bar: Control = %StatusBar
@onready var accent_line: ColorRect = %AccentLine

var _tool_buttons: Array[Button] = []
var _tool_group: ButtonGroup
var _view_group: ButtonGroup
var _anim_tween: Tween
var _syncing: bool = false


func _ready() -> void:
	_tool_group = ButtonGroup.new()
	_tool_group.allow_unpress = false
	_view_group = ButtonGroup.new()
	_view_group.allow_unpress = false
	_wire_tool_button(%BtnOrbit, EditorState.Tool.ORBIT)
	_wire_tool_button(%BtnRaise, EditorState.Tool.RAISE)
	_wire_tool_button(%BtnLower, EditorState.Tool.LOWER)
	_wire_tool_button(%BtnSmooth, EditorState.Tool.SMOOTH)
	_wire_tool_button(%BtnFlatten, EditorState.Tool.SET_HEIGHT)
	_wire_tool_button(%BtnPaint, EditorState.Tool.PAINT_TEXTURE)
	_wire_tool_button(%BtnSpawn, EditorState.Tool.MARKER_SPAWN)
	_wire_tool_button(%BtnAlloys, EditorState.Tool.MARKER_ALLOYS)
	_wire_view_button(%BtnView3D, EditorState.ViewMode.VIEW_3D)
	_wire_view_button(%BtnView2D, EditorState.ViewMode.VIEW_2D)
	_wire_view_button(%BtnViewHM, EditorState.ViewMode.VIEW_HEIGHTMAP)

	_populate_terrain_presets()
	%TerrainPreset.item_selected.connect(_on_terrain_preset_selected)
	%PaintLayer.item_selected.connect(_on_paint_layer_selected)
	EditorState.materials_changed.connect(_sync_paint_layers)
	EditorState.paint_layer_changed.connect(_sync_paint_layer_selection)

	%BtnNew.pressed.connect(_on_new)
	%BtnOpen.pressed.connect(func() -> void: open_dialog.popup_centered_ratio(0.65))
	%BtnSave.pressed.connect(_on_save)
	%BtnSaveAs.pressed.connect(func() -> void:
		_prepare_save_dialog()
		save_dialog.popup_centered_ratio(0.65)
	)
	%BtnApplySize.pressed.connect(_on_apply_size)
	%BtnClearSpawns.pressed.connect(func() -> void: EditorState.clear_markers(SanMapData.MARKER_SPAWN))
	%BtnClearAlloys.pressed.connect(func() -> void: EditorState.clear_markers(SanMapData.MARKER_ALLOYS))
	%BtnMirrorX.toggle_mode = true
	%BtnMirrorZ.toggle_mode = true
	%BtnMirrorX.toggled.connect(func(on: bool) -> void: EditorState.set_mirror_x(on))
	%BtnMirrorZ.toggled.connect(func(on: bool) -> void: EditorState.set_mirror_z(on))
	EditorState.mirror_changed.connect(_sync_mirror_buttons)

	brush_radius.value_changed.connect(_on_brush_radius)
	brush_strength.value_changed.connect(_on_brush_strength)
	set_height_slider.value_changed.connect(_on_set_height)
	water_check.toggled.connect(_on_water_toggled)
	water_level.value_changed.connect(_on_water_level)
	name_edit.text_changed.connect(_on_name_changed)

	open_dialog.file_selected.connect(_on_open_selected)
	save_dialog.file_selected.connect(_on_save_selected)

	EditorState.map_changed.connect(_sync_from_state)
	EditorState.dirty_changed.connect(_update_status)
	EditorState.tool_changed.connect(_on_tool_changed)
	EditorState.view_changed.connect(_on_view_changed)

	_play_intro_motion()
	_sync_from_state()
	_highlight_views()
	_update_status()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_F1:
			EditorState.set_view_mode(EditorState.ViewMode.VIEW_3D)
			_update_status()
			get_viewport().set_input_as_handled()
		KEY_F2:
			EditorState.set_view_mode(EditorState.ViewMode.VIEW_2D)
			_update_status()
			get_viewport().set_input_as_handled()
		KEY_F3:
			EditorState.set_view_mode(EditorState.ViewMode.VIEW_HEIGHTMAP)
			_update_status()
			get_viewport().set_input_as_handled()
		KEY_F5:
			EditorState.toggle_mirror_x()
			get_viewport().set_input_as_handled()
		KEY_F6:
			EditorState.toggle_mirror_z()
			get_viewport().set_input_as_handled()


func _play_intro_motion() -> void:
	top_bar.modulate.a = 0.0
	tool_rail.modulate.a = 0.0
	side_dock.modulate.a = 0.0
	status_bar.modulate.a = 0.0
	if accent_line:
		accent_line.scale = Vector2(1.0, 0.05)

	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.set_trans(Tween.TRANS_CUBIC)
	_anim_tween.tween_property(top_bar, "modulate:a", 1.0, 0.4)
	_anim_tween.tween_property(tool_rail, "modulate:a", 1.0, 0.45).set_delay(0.06)
	_anim_tween.tween_property(side_dock, "modulate:a", 1.0, 0.5).set_delay(0.1)
	_anim_tween.tween_property(status_bar, "modulate:a", 1.0, 0.4).set_delay(0.14)
	if accent_line:
		_anim_tween.tween_property(accent_line, "scale", Vector2.ONE, 0.5).set_delay(0.12)


func _wire_tool_button(btn: Button, tool: EditorState.Tool) -> void:
	_tool_buttons.append(btn)
	btn.toggle_mode = true
	btn.button_group = _tool_group
	btn.set_meta(TOOL_META, tool)
	# Use toggled(true) so deselect/spam clicks cannot clear the active tool.
	btn.toggled.connect(func(pressed: bool) -> void:
		if not pressed:
			return
		EditorState.set_tool(tool)
		_update_status()
	)


func _wire_view_button(btn: Button, mode: EditorState.ViewMode) -> void:
	btn.toggle_mode = true
	btn.button_group = _view_group
	btn.set_meta("view_mode", mode)
	btn.toggled.connect(func(pressed: bool) -> void:
		if not pressed:
			return
		EditorState.set_view_mode(mode)
		_update_status()
	)


func _highlight_tools() -> void:
	for btn in _tool_buttons:
		var tool: EditorState.Tool = btn.get_meta(TOOL_META)
		var should_press := tool == EditorState.active_tool
		if btn.button_pressed != should_press:
			btn.set_pressed_no_signal(should_press)


func _highlight_views() -> void:
	var buttons := [%BtnView3D, %BtnView2D, %BtnViewHM]
	for btn in buttons:
		var mode: EditorState.ViewMode = btn.get_meta("view_mode")
		var should_press := mode == EditorState.view_mode
		if btn.button_pressed != should_press:
			btn.set_pressed_no_signal(should_press)


func _on_tool_changed() -> void:
	_highlight_tools()
	_update_status()


func _on_view_changed() -> void:
	_highlight_views()
	_update_status()


func _sync_from_state() -> void:
	if _syncing:
		return
	_syncing = true
	var m := EditorState.map
	name_edit.text = m.name
	map_title.text = m.name if m.name != "" else "Untitled Map"
	width_spin.value = m.width
	length_spin.value = m.length
	height_spin.value = m.height
	res_spin.value = m.heightmap_resolution
	brush_radius.set_value_no_signal(EditorState.brush_radius)
	brush_strength.set_value_no_signal(EditorState.brush_strength)
	brush_radius_value.text = "%.0f" % EditorState.brush_radius
	brush_strength_value.text = "%.2f/s" % EditorState.brush_strength
	set_height_slider.max_value = float(m.height)
	EditorState.set_height_world = clampf(EditorState.set_height_world, 0.0, float(m.height))
	set_height_slider.set_value_no_signal(EditorState.set_height_world)
	set_height_value.text = "%.1f" % EditorState.set_height_world
	water_check.set_pressed_no_signal(m.has_water)
	water_level.max_value = float(m.height)
	water_level.set_value_no_signal(m.water_level)
	water_level_value.text = "%.1f" % m.water_level
	_highlight_tools()
	_highlight_views()
	_sync_mirror_buttons()
	_sync_terrain_preset_selection()
	_sync_paint_layers()
	_update_status()
	_syncing = false


func _populate_terrain_presets() -> void:
	var btn: OptionButton = %TerrainPreset
	btn.clear()
	var ids := TerrainPresets.preset_ids()
	for i in ids.size():
		var id := ids[i]
		btn.add_item(TerrainPresets.preset_label(id), i)
		btn.set_item_metadata(i, id)


func _sync_terrain_preset_selection() -> void:
	var btn: OptionButton = %TerrainPreset
	var target := EditorState.terrain_preset_id
	for i in btn.item_count:
		if str(btn.get_item_metadata(i)) == target:
			btn.select(i)
			return
	if btn.item_count > 0:
		btn.select(0)


func _sync_paint_layers() -> void:
	var btn: OptionButton = %PaintLayer
	var prev := EditorState.paint_layer
	btn.clear()
	for i in 8:
		btn.add_item(TerrainPresets.layer_display_name(EditorState.map, i), i)
	btn.select(clampi(prev, 0, maxi(btn.item_count - 1, 0)))


func _sync_paint_layer_selection() -> void:
	var btn: OptionButton = %PaintLayer
	if btn.item_count <= 0:
		return
	btn.select(clampi(EditorState.paint_layer, 0, btn.item_count - 1))


func _on_terrain_preset_selected(index: int) -> void:
	if _syncing:
		return
	var id := str(%TerrainPreset.get_item_metadata(index))
	EditorState.set_terrain_preset(id)
	_sync_paint_layers()
	_update_status()


func _on_paint_layer_selected(index: int) -> void:
	if _syncing:
		return
	EditorState.set_paint_layer(index)
	_update_status()


func _sync_mirror_buttons() -> void:
	%BtnMirrorX.set_pressed_no_signal(EditorState.mirror_x_enabled)
	%BtnMirrorZ.set_pressed_no_signal(EditorState.mirror_z_enabled)
	_update_status()


func _update_status() -> void:
	var dirty := EditorState.is_dirty
	dirty_badge.visible = dirty
	var path := EditorState.current_path if EditorState.current_path != "" else "Nicht gespeichert"
	var tool_names := {
		EditorState.Tool.ORBIT: "Orbit",
		EditorState.Tool.RAISE: "Anheben",
		EditorState.Tool.LOWER: "Absenken",
		EditorState.Tool.SMOOTH: "Glätten",
		EditorState.Tool.SET_HEIGHT: "Höhe setzen",
		EditorState.Tool.PAINT_TEXTURE: "Textur malen",
		EditorState.Tool.MARKER_SPAWN: "Spawn setzen",
		EditorState.Tool.MARKER_ALLOYS: "Alloys setzen",
	}
	var tool_name: String = tool_names.get(EditorState.active_tool, "?")
	var view_names := {
		EditorState.ViewMode.VIEW_3D: "3D",
		EditorState.ViewMode.VIEW_2D: "2D",
		EditorState.ViewMode.VIEW_HEIGHTMAP: "Heightmap",
	}
	var mirror_bits: PackedStringArray = []
	if EditorState.mirror_x_enabled:
		mirror_bits.append("MX")
	if EditorState.mirror_z_enabled:
		mirror_bits.append("MZ")
	var mirror_txt := ("  ·  Mirror " + " ".join(mirror_bits)) if not mirror_bits.is_empty() else ""
	status_label.text = "%s  ·  %s  ·  %s%s  ·  %d × %d" % [
		path.get_file() if EditorState.current_path != "" else path,
		view_names.get(EditorState.view_mode, "?"),
		tool_name,
		mirror_txt,
		EditorState.map.width,
		EditorState.map.length,
	]
	tool_hint.text = _hint_for_tool(EditorState.active_tool)
	map_title.text = ("%s*" % EditorState.map.name) if dirty and EditorState.map.name != "" else (EditorState.map.name if EditorState.map.name != "" else "Untitled Map")


func _hint_for_tool(tool: EditorState.Tool) -> String:
	match tool:
		EditorState.Tool.ORBIT:
			return "RMB Orbit · MMB Pan · Rad Zoom"
		EditorState.Tool.RAISE:
			return "LMB halten: Terrain anheben"
		EditorState.Tool.LOWER:
			return "LMB halten: Terrain absenken"
		EditorState.Tool.SMOOTH:
			return "LMB halten: Kanten glätten"
		EditorState.Tool.SET_HEIGHT:
			return "LMB: auf %.1f setzen · Shift+Klick: Höhe sampeln" % EditorState.set_height_world
		EditorState.Tool.PAINT_TEXTURE:
			return "LMB halten: Schicht %d malen · Mirror gilt auch hier" % EditorState.paint_layer
		EditorState.Tool.MARKER_SPAWN:
			return "LMB: Spawn-Marker setzen"
		EditorState.Tool.MARKER_ALLOYS:
			return "LMB: Alloy-Marker setzen"
		_:
			return ""


func _on_brush_radius(v: float) -> void:
	if _syncing:
		return
	EditorState.brush_radius = v
	brush_radius_value.text = "%.0f" % v


func _on_brush_strength(v: float) -> void:
	if _syncing:
		return
	EditorState.brush_strength = v
	brush_strength_value.text = "%.2f/s" % v


func _on_set_height(v: float) -> void:
	if _syncing:
		return
	EditorState.set_height_world = v
	set_height_value.text = "%.1f" % v
	_update_status()


func sync_set_height_from_state() -> void:
	## Called when terrain height is sampled with Shift+Click.
	_syncing = true
	set_height_slider.max_value = float(EditorState.map.height)
	set_height_slider.set_value_no_signal(EditorState.set_height_world)
	set_height_value.text = "%.1f" % EditorState.set_height_world
	_syncing = false
	_update_status()


func _on_new() -> void:
	EditorState.new_map(int(width_spin.value), int(length_spin.value), int(height_spin.value), int(res_spin.value))


func _on_apply_size() -> void:
	EditorState.new_map(int(width_spin.value), int(length_spin.value), int(height_spin.value), int(res_spin.value))


func _on_save() -> void:
	if EditorState.current_path == "":
		_prepare_save_dialog()
		save_dialog.popup_centered_ratio(0.65)
	else:
		_do_save(EditorState.current_path)


func _prepare_save_dialog() -> void:
	var suggested := SanMapIO.sanitize_map_name(name_edit.text if name_edit.text.strip_edges() != "" else EditorState.map.name)
	save_dialog.current_file = suggested + ".sanmap"


func _on_open_selected(path: String) -> void:
	var err := EditorState.load_from_path(path)
	if err != OK:
		status_label.text = "Öffnen fehlgeschlagen"


func _on_save_selected(path: String) -> void:
	_do_save(path)


func _do_save(path: String) -> void:
	EditorState.map.name = name_edit.text
	var err := EditorState.save_to_path(path)
	if err != OK:
		status_label.text = "Speichern fehlgeschlagen (%s)" % error_string(err)
	else:
		_sync_from_state()
		status_label.text = "Gespeichert: %s" % EditorState.current_path.get_base_dir()
		_update_status()


func _on_name_changed(text: String) -> void:
	if _syncing:
		return
	EditorState.map.name = text
	EditorState.mark_dirty()
	_update_status()


func _on_water_toggled(pressed: bool) -> void:
	if _syncing:
		return
	EditorState.map.has_water = pressed
	EditorState.mark_dirty()
	EditorState.map_changed.emit()


func _on_water_level(value: float) -> void:
	if _syncing:
		return
	EditorState.map.water_level = value
	water_level_value.text = "%.1f" % value
	EditorState.mark_dirty()
	EditorState.map_changed.emit()
