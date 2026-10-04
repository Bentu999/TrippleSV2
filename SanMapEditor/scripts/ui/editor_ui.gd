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
var _map_menu_open: bool = false


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
	_wire_tool_button(%BtnMeasure, EditorState.Tool.MEASURE_HEIGHT)
	_wire_tool_button(%BtnPaint, EditorState.Tool.PAINT_TEXTURE)
	_wire_tool_button(%BtnLine, EditorState.Tool.SHAPE_LINE)
	_wire_tool_button(%BtnCircle, EditorState.Tool.SHAPE_CIRCLE)
	_wire_tool_button(%BtnArc, EditorState.Tool.SHAPE_ARC)
	_wire_tool_button(%BtnPlateau, EditorState.Tool.SHAPE_PLATEAU)
	_wire_tool_button(%BtnRamp, EditorState.Tool.SHAPE_RAMP)
	_wire_tool_button(%BtnPathing, EditorState.Tool.PATHING)
	_wire_tool_button(%BtnSpawn, EditorState.Tool.MARKER_SPAWN)
	_wire_tool_button(%BtnAlloys, EditorState.Tool.MARKER_ALLOYS)
	_wire_tool_button(%BtnProp, EditorState.Tool.PLACE_PROP)
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
	%BtnUndo.pressed.connect(func() -> void: EditorState.undo())
	%BtnRedo.pressed.connect(func() -> void: EditorState.redo())
	EditorState.history_changed.connect(_sync_history_buttons)
	%BtnApplySize.pressed.connect(_on_apply_size)
	%PlayableXSpin.value_changed.connect(_on_playable_changed)
	%PlayableYSpin.value_changed.connect(_on_playable_changed)
	%PlayableWSpin.value_changed.connect(_on_playable_size_changed)
	%PlayableHSpin.value_changed.connect(_on_playable_size_changed)
	%BtnPlayableCenter.pressed.connect(func() -> void: EditorState.center_playable_area())
	%BtnPlayableFull.pressed.connect(func() -> void: EditorState.reset_playable_to_full())
	%FadeStartSpin.value_changed.connect(_on_fade_start_changed)
	%FadeDistSpin.value_changed.connect(_on_fade_dist_changed)
	%BtnClearSpawns.pressed.connect(func() -> void: EditorState.clear_markers(SanMapData.MARKER_SPAWN))
	%BtnClearAlloys.pressed.connect(func() -> void: EditorState.clear_markers(SanMapData.MARKER_ALLOYS))
	_populate_prop_blueprints()
	%PropBlueprint.item_selected.connect(_on_prop_blueprint_selected)
	%PropPathEdit.text_submitted.connect(_on_prop_path_submitted)
	%PropPathEdit.focus_exited.connect(_on_prop_path_focus_exited)
	%PropScale.value_changed.connect(_on_prop_scale)
	%PropRandomYaw.toggled.connect(func(on: bool) -> void: EditorState.set_prop_random_yaw(on))
	%BtnClearPropType.pressed.connect(func() -> void: EditorState.clear_props_of_type(EditorState.prop_blueprint))
	%BtnClearProps.pressed.connect(func() -> void: EditorState.clear_props())
	EditorState.props_changed.connect(_sync_prop_count)
	EditorState.prop_settings_changed.connect(_sync_prop_settings)
	%BtnMirrorX.toggle_mode = true
	%BtnMirrorZ.toggle_mode = true
	%BtnMirrorX.toggled.connect(func(on: bool) -> void: EditorState.set_mirror_x(on))
	%BtnMirrorZ.toggled.connect(func(on: bool) -> void: EditorState.set_mirror_z(on))
	EditorState.mirror_changed.connect(_sync_mirror_buttons)

	brush_radius.value_changed.connect(_on_brush_radius)
	brush_strength.value_changed.connect(_on_brush_strength)
	set_height_slider.value_changed.connect(_on_set_height)
	%RampAngleSlider.value_changed.connect(_on_ramp_angle)
	%RampLengthSlider.value_changed.connect(_on_ramp_length)
	%BtnRampRotLeft.pressed.connect(func() -> void: _on_ramp_rotate(15.0))
	%BtnRampRotRight.pressed.connect(func() -> void: _on_ramp_rotate(-15.0))
	%PathAngleSlider.value_changed.connect(_on_path_angle)
	_populate_shape_height_modes()
	%ShapeHeightMode.item_selected.connect(_on_shape_height_mode_selected)
	water_check.toggled.connect(_on_water_toggled)
	water_level.value_changed.connect(_on_water_level)
	%ScaleGuidesCheck.toggled.connect(_on_scale_guides_toggled)
	EditorState.scale_guides_changed.connect(_sync_scale_guides_check)
	water_level.drag_started.connect(func() -> void: EditorState.begin_stroke("Water level"))
	water_level.drag_ended.connect(func(_value_changed: bool) -> void: EditorState.end_stroke())
	name_edit.text_changed.connect(_on_name_changed)

	open_dialog.file_selected.connect(_on_open_selected)
	save_dialog.file_selected.connect(_on_save_selected)

	EditorState.map_changed.connect(_sync_from_state)
	EditorState.dirty_changed.connect(_update_status)
	EditorState.tool_changed.connect(_on_tool_changed)
	EditorState.view_changed.connect(_on_view_changed)
	EditorState.measurement_changed.connect(_update_status)
	EditorState.pathing_changed.connect(_sync_pathing_status)

	%BtnMapMenu.toggled.connect(_on_map_menu_toggled)
	%MapMenuPanel.visible = false
	_map_menu_open = false

	_play_intro_motion()
	_sync_from_state()
	_highlight_views()
	_sync_history_buttons()
	_update_tool_context_panels()
	_update_status()


func _on_map_menu_toggled(pressed: bool) -> void:
	_map_menu_open = pressed
	%MapMenuPanel.visible = pressed
	%BtnMapMenu.text = "Karte ▴" if pressed else "Karte ▾"
	if pressed:
		_position_map_menu_panel()


func _position_map_menu_panel() -> void:
	## Anchor the dropdown under the Karte button (left of 3D).
	var btn: Control = %BtnMapMenu
	var panel: Control = %MapMenuPanel
	var btn_rect := btn.get_global_rect()
	var root := get_node("Root") as Control
	var root_rect: Rect2 = root.get_global_rect()
	var local_x := btn_rect.position.x - root_rect.position.x
	var local_y := btn_rect.end.y - root_rect.position.y + 6.0
	panel.offset_left = local_x
	panel.offset_top = local_y
	panel.offset_right = local_x + 366.0
	panel.offset_bottom = local_y + 618.0


func _input(event: InputEvent) -> void:
	## Close map dropdown when clicking outside it.
	if not _map_menu_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel: Control = %MapMenuPanel
		var btn: Control = %BtnMapMenu
		var mouse := panel.get_global_mouse_position()
		if not panel.get_global_rect().has_point(mouse) and not btn.get_global_rect().has_point(mouse):
			%BtnMapMenu.set_pressed_no_signal(false)
			_on_map_menu_toggled(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit or focus is SpinBox
	if not typing and key.ctrl_pressed and key.keycode == KEY_Z and not key.shift_pressed:
		EditorState.undo()
		_update_status()
		get_viewport().set_input_as_handled()
		return
	if not typing and key.ctrl_pressed and (key.keycode == KEY_Y or (key.keycode == KEY_Z and key.shift_pressed)):
		EditorState.redo()
		_update_status()
		get_viewport().set_input_as_handled()
		return
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
	_update_tool_context_panels()
	_update_status()


func _update_tool_context_panels() -> void:
	## Show only settings that belong to the active tool.
	var tool := EditorState.active_tool
	var is_raise := tool == EditorState.Tool.RAISE or tool == EditorState.Tool.LOWER
	var is_smooth := tool == EditorState.Tool.SMOOTH
	var is_set_h := tool == EditorState.Tool.SET_HEIGHT
	var is_paint := tool == EditorState.Tool.PAINT_TEXTURE
	var is_measure := tool == EditorState.Tool.MEASURE_HEIGHT
	var is_geom := tool == EditorState.Tool.SHAPE_LINE \
		or tool == EditorState.Tool.SHAPE_CIRCLE \
		or tool == EditorState.Tool.SHAPE_ARC \
		or tool == EditorState.Tool.SHAPE_PLATEAU
	var is_ramp := tool == EditorState.Tool.SHAPE_RAMP
	var is_path := tool == EditorState.Tool.PATHING
	var is_marker := tool == EditorState.Tool.MARKER_SPAWN or tool == EditorState.Tool.MARKER_ALLOYS
	var is_prop := tool == EditorState.Tool.PLACE_PROP
	var uses_radius := is_raise or is_smooth or is_set_h or is_paint or is_geom or is_ramp
	var uses_strength := is_raise or is_smooth or is_paint
	var uses_height := is_set_h or is_measure or is_geom or is_ramp
	var uses_mirror := is_raise or is_smooth or is_set_h or is_paint or is_geom or is_ramp or is_prop
	var show_brush := uses_radius or uses_strength or uses_height
	var show_tool_extra := is_geom or is_ramp or is_path
	var show_terrain := is_paint

	%SectionTerrain.visible = show_terrain
	%SepTerrain.visible = show_brush
	%SectionBrush.visible = show_brush
	%BrushHeader.text = _tool_settings_header(tool)
	%RadiusRow.visible = uses_radius
	%BrushRadius.visible = uses_radius
	%RadiusLabel.text = "Breite (m)" if (is_geom or is_ramp) else "Radius (m)"
	%StrengthRow.visible = uses_strength
	%BrushStrength.visible = uses_strength
	%SetHeightRow.visible = uses_height
	%SetHeightSlider.visible = uses_height
	%SetHeightLabel.text = "Höhe (m)" if is_ramp else "Zielhöhe (m)"
	%SetHeightHint.visible = uses_height
	if is_ramp:
		%SetHeightHint.text = "Endhöhe der fertigen Rampe. Shift+Klick: Höhe vom Terrain. Breite = Pinselradius."
	elif is_geom:
		%SetHeightHint.text = "Zielhöhe für Formen. Form+Höhe: Setzen / Anheben / Absenken. Shift+Klick sampelt."
	elif is_set_h or is_measure:
		%SetHeightHint.text = "Zielhöhe für Ebnen. Shift+Klick oder Measure-Pin übernimmt Terrainhöhe."
	else:
		%SetHeightHint.text = "Zielhöhe."

	%SepShapes.visible = show_tool_extra
	%SectionShapes.visible = show_tool_extra
	%ShapesHeader.text = _tool_settings_header(tool)
	%ShapeHeightLabel.visible = is_geom
	%ShapeHeightMode.visible = is_geom
	%RampAngleRow.visible = is_ramp
	%RampAngleSlider.visible = is_ramp
	%RampLengthRow.visible = is_ramp
	%RampLengthSlider.visible = is_ramp
	%RampRotateRow.visible = is_ramp
	%PathAngleRow.visible = is_path
	%PathAngleSlider.visible = is_path
	%PathStatusLabel.visible = is_path
	%ShapesHint.visible = show_tool_extra
	if is_ramp:
		%ShapesHint.text = "Hover zeigt die Rampe. Drehen-Buttons ändern die Richtung. LMB bestätigt die Platzierung."
	elif is_geom:
		%ShapesHint.text = "Ziehen zum Zeichnen. Bogen: 3 Klicks. Esc/RMB bricht ab."
	elif is_path:
		%ShapesHint.text = "Rot = zu steil. Zwei Klicks prüfen einen Pfad."
	else:
		%ShapesHint.text = ""

	%SepMirror.visible = uses_mirror
	%SectionMirror.visible = uses_mirror
	%Sep3.visible = is_marker
	%SectionMarkers.visible = is_marker
	%SepProps.visible = is_prop
	%SectionProps.visible = is_prop


func _tool_settings_header(tool: EditorState.Tool) -> String:
	match tool:
		EditorState.Tool.RAISE:
			return "ANHEBEN"
		EditorState.Tool.LOWER:
			return "ABSENKEN"
		EditorState.Tool.SMOOTH:
			return "GLÄTTEN"
		EditorState.Tool.SET_HEIGHT:
			return "HÖHE SETZEN"
		EditorState.Tool.MEASURE_HEIGHT:
			return "MESSEN"
		EditorState.Tool.PAINT_TEXTURE:
			return "MALEN"
		EditorState.Tool.SHAPE_LINE:
			return "LINIE"
		EditorState.Tool.SHAPE_CIRCLE:
			return "KREIS"
		EditorState.Tool.SHAPE_ARC:
			return "BOGEN"
		EditorState.Tool.SHAPE_PLATEAU:
			return "PLATEAU"
		EditorState.Tool.SHAPE_RAMP:
			return "RAMPE"
		EditorState.Tool.PATHING:
			return "PATHING"
		EditorState.Tool.MARKER_SPAWN:
			return "SPAWN"
		EditorState.Tool.MARKER_ALLOYS:
			return "ALLOYS"
		EditorState.Tool.PLACE_PROP:
			return "PROP"
		_:
			return "WERKZEUG"


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
	_sync_playable_spins()
	_sync_fade_spins()
	brush_radius.set_value_no_signal(EditorState.brush_radius)
	brush_strength.set_value_no_signal(EditorState.brush_strength)
	brush_radius_value.text = "%.0f m" % EditorState.brush_radius
	brush_strength_value.text = "%.2f/s" % EditorState.brush_strength
	set_height_slider.max_value = float(m.height)
	EditorState.set_height_world = clampf(EditorState.set_height_world, 0.0, float(m.height))
	set_height_slider.set_value_no_signal(EditorState.set_height_world)
	set_height_value.text = "%.1f m" % EditorState.set_height_world
	%RampAngleSlider.set_value_no_signal(EditorState.ramp_angle_deg)
	%RampAngleValue.text = "%.1f°" % EditorState.ramp_angle_deg
	%RampLengthSlider.set_value_no_signal(EditorState.ramp_length_m)
	%RampLengthValue.text = "%.0f m" % EditorState.ramp_length_m
	_sync_shape_height_mode()
	%PathAngleSlider.set_value_no_signal(EditorState.pathing_max_angle_deg)
	%PathAngleValue.text = "%.1f°" % EditorState.pathing_max_angle_deg
	_sync_pathing_status()
	water_check.set_pressed_no_signal(m.has_water)
	water_level.max_value = float(m.height)
	water_level.set_value_no_signal(m.water_level)
	water_level_value.text = "%.1f m" % m.water_level
	_sync_scale_guides_check()
	_highlight_tools()
	_highlight_views()
	_sync_mirror_buttons()
	_sync_terrain_preset_selection()
	_sync_paint_layers()
	_sync_prop_settings()
	_sync_prop_count()
	_update_status()
	_syncing = false


func _populate_prop_blueprints() -> void:
	var btn: OptionButton = %PropBlueprint
	btn.clear()
	var paths := PropCatalog.all_blueprints()
	for i in paths.size():
		var path := paths[i]
		btn.add_item(PropCatalog.display_name(path), i)
		btn.set_item_metadata(i, path)
		btn.set_item_tooltip(i, path)
	_sync_prop_blueprint_selection()


func _sync_prop_blueprint_selection() -> void:
	var btn: OptionButton = %PropBlueprint
	var target := EditorState.prop_blueprint
	for i in btn.item_count:
		if str(btn.get_item_metadata(i)) == target:
			btn.select(i)
			return
	# Custom path not in catalog — keep selection, show in path edit.
	if btn.item_count > 0 and target.is_empty():
		btn.select(0)
		EditorState.set_prop_blueprint(str(btn.get_item_metadata(0)))


func _sync_prop_settings() -> void:
	# May be called from inside _sync_from_state (_syncing already true).
	var nested := _syncing
	_syncing = true
	_sync_prop_blueprint_selection()
	%PropPathEdit.text = EditorState.prop_blueprint
	%PropScale.set_value_no_signal(EditorState.prop_scale)
	%PropScaleValue.text = "%.2f" % EditorState.prop_scale
	%PropRandomYaw.set_pressed_no_signal(EditorState.prop_random_yaw)
	_syncing = nested


func _sync_prop_count() -> void:
	var n := EditorState.prop_instance_count()
	var groups := EditorState.map.props.size()
	%PropCountLabel.text = "%d Props · %d Typen" % [n, groups]
	# Maps may introduce new blueprints; refresh list without losing selection.
	var btn: OptionButton = %PropBlueprint
	var known := {}
	for i in btn.item_count:
		known[str(btn.get_item_metadata(i))] = true
	var needs_refresh := false
	for group in EditorState.map.props:
		if typeof(group) != TYPE_DICTIONARY:
			continue
		var bp := str(group.get("blueprintPath", ""))
		if not bp.is_empty() and not known.has(bp):
			needs_refresh = true
			break
	if needs_refresh:
		PropCatalog.merge_from_map(EditorState.map)
		_populate_prop_blueprints()
		_sync_prop_settings()


func _on_prop_blueprint_selected(index: int) -> void:
	if _syncing:
		return
	var path := str(%PropBlueprint.get_item_metadata(index))
	EditorState.set_prop_blueprint(path)
	%PropPathEdit.text = path
	_update_status()


func _on_prop_path_submitted(text: String) -> void:
	_apply_prop_path_edit(text)


func _on_prop_path_focus_exited() -> void:
	_apply_prop_path_edit(%PropPathEdit.text)


func _apply_prop_path_edit(text: String) -> void:
	if _syncing:
		return
	var path := text.strip_edges().replace("\\", "/")
	if path.is_empty():
		%PropPathEdit.text = EditorState.prop_blueprint
		return
	EditorState.set_prop_blueprint(path)
	# Add custom path to dropdown if missing.
	var btn: OptionButton = %PropBlueprint
	var found := -1
	for i in btn.item_count:
		if str(btn.get_item_metadata(i)) == path:
			found = i
			break
	if found < 0:
		var idx := btn.item_count
		btn.add_item(PropCatalog.display_name(path), idx)
		btn.set_item_metadata(idx, path)
		btn.set_item_tooltip(idx, path)
		btn.select(idx)
	else:
		btn.select(found)
	_update_status()


func _on_prop_scale(value: float) -> void:
	if _syncing:
		return
	EditorState.set_prop_scale(value)
	%PropScaleValue.text = "%.2f" % EditorState.prop_scale
	_update_status()


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
		EditorState.Tool.MEASURE_HEIGHT: "Höhe messen",
		EditorState.Tool.PAINT_TEXTURE: "Textur malen",
		EditorState.Tool.SHAPE_LINE: "Linie",
		EditorState.Tool.SHAPE_CIRCLE: "Kreis",
		EditorState.Tool.SHAPE_ARC: "Bogen",
		EditorState.Tool.SHAPE_PLATEAU: "Plateau",
		EditorState.Tool.SHAPE_RAMP: "Rampe",
		EditorState.Tool.PATHING: "Pathing",
		EditorState.Tool.MARKER_SPAWN: "Spawn setzen",
		EditorState.Tool.MARKER_ALLOYS: "Alloys setzen",
		EditorState.Tool.PLACE_PROP: "Prop setzen",
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
	var measure_txt := _measure_status_text()
	status_label.text = "%s  ·  %s  ·  %s%s%s  ·  %d × %d m" % [
		path.get_file() if EditorState.current_path != "" else path,
		view_names.get(EditorState.view_mode, "?"),
		tool_name,
		mirror_txt,
		measure_txt,
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
			return "LMB: auf %.1f m setzen · Shift+Klick: Höhe sampeln" % EditorState.set_height_world
		EditorState.Tool.MEASURE_HEIGHT:
			if EditorState.measure_live_valid:
				return "Live %.1f m · Klick: pinnen + Zielhöhe im Pinsel setzen" % EditorState.measure_live_height
			return "Cursor über Terrain: Höhe lesen · Klick: pinnen + Zielhöhe im Pinsel setzen"
		EditorState.Tool.PAINT_TEXTURE:
			return "LMB halten: Schicht %d malen · Mirror gilt auch hier" % (EditorState.paint_layer + 1)
		EditorState.Tool.MARKER_SPAWN:
			return "LMB: Spawn-Marker setzen"
		EditorState.Tool.MARKER_ALLOYS:
			return "LMB: Alloy-Marker setzen"
		EditorState.Tool.PLACE_PROP:
			return "LMB: %s setzen · Scale %.2f%s" % [
				PropCatalog.display_name(EditorState.prop_blueprint),
				EditorState.prop_scale,
				" · Mirror" if (EditorState.mirror_x_enabled or EditorState.mirror_z_enabled) else "",
			]
		EditorState.Tool.SHAPE_LINE:
			return "Ziehen: Linie · %s → %.1f m · Breite = Pinselradius" % [
				_shape_height_mode_label(),
				EditorState.set_height_world,
			]
		EditorState.Tool.SHAPE_CIRCLE:
			return "Zentrum → Radius: Kreis · %s → %.1f m" % [
				_shape_height_mode_label(),
				EditorState.set_height_world,
			]
		EditorState.Tool.SHAPE_ARC:
			return "3 Klicks: Bogen · %s → %.1f m · Breite = Pinselradius" % [
				_shape_height_mode_label(),
				EditorState.set_height_world,
			]
		EditorState.Tool.SHAPE_PLATEAU:
			return "Ziehen: Plateau · %s → %.1f m" % [
				_shape_height_mode_label(),
				EditorState.set_height_world,
			]
		EditorState.Tool.SHAPE_RAMP:
			return "Hover-Vorschau · Drehen-Buttons · LMB platziert · %.1f m · %.1f° · %.0f m" % [
				EditorState.set_height_world,
				EditorState.ramp_angle_deg,
				EditorState.ramp_length_m,
			]
		EditorState.Tool.PATHING:
			if not EditorState.pathing_status.is_empty():
				return EditorState.pathing_status
			return "Rot = zu steil (>%.0f°) · zwei Klicks: Pfad prüfen · Esc bricht ab" % EditorState.pathing_max_angle_deg
		_:
			return ""


func _measure_status_text() -> String:
	if EditorState.measure_pinned:
		var p := EditorState.measure_pinned_pos
		return "  ·  Pin %.1f m @ %.0f,%.0f (%.0f%%)" % [
			EditorState.measure_pinned_height,
			p.x,
			p.z,
			EditorState.measure_normalized(EditorState.measure_pinned_height) * 100.0,
		]
	if EditorState.active_tool == EditorState.Tool.MEASURE_HEIGHT and EditorState.measure_live_valid:
		var p2 := EditorState.measure_live_pos
		return "  ·  H %.1f m @ %.0f,%.0f (%.0f%%)" % [
			EditorState.measure_live_height,
			p2.x,
			p2.z,
			EditorState.measure_normalized(EditorState.measure_live_height) * 100.0,
		]
	return ""


func _on_brush_radius(v: float) -> void:
	if _syncing:
		return
	EditorState.brush_radius = v
	brush_radius_value.text = "%.0f m" % v


func _on_brush_strength(v: float) -> void:
	if _syncing:
		return
	EditorState.brush_strength = v
	brush_strength_value.text = "%.2f/s" % v


func _on_set_height(v: float) -> void:
	if _syncing:
		return
	if EditorState.active_tool == EditorState.Tool.SHAPE_RAMP:
		EditorState.set_ramp_end_height(v)
		_sync_ramp_linked_spins()
	else:
		EditorState.set_height_world = v
	set_height_value.text = "%.1f m" % EditorState.set_height_world
	_update_status()


func _on_ramp_angle(v: float) -> void:
	if _syncing:
		return
	EditorState.set_ramp_angle_deg(v)
	_sync_ramp_linked_spins()
	_update_status()


func _on_ramp_length(v: float) -> void:
	if _syncing:
		return
	EditorState.set_ramp_length_m(v)
	_sync_ramp_linked_spins()
	_update_status()


func _on_ramp_rotate(yaw_deg: float) -> void:
	EditorState.rotate_ramp_aim_deg(yaw_deg)
	_update_status()


func _sync_ramp_linked_spins() -> void:
	_syncing = true
	%RampAngleSlider.set_value_no_signal(EditorState.ramp_angle_deg)
	%RampAngleValue.text = "%.1f°" % EditorState.ramp_angle_deg
	%RampLengthSlider.set_value_no_signal(EditorState.ramp_length_m)
	%RampLengthValue.text = "%.0f m" % EditorState.ramp_length_m
	set_height_slider.set_value_no_signal(EditorState.set_height_world)
	set_height_value.text = "%.1f m" % EditorState.set_height_world
	_syncing = false


func _populate_shape_height_modes() -> void:
	var btn: OptionButton = %ShapeHeightMode
	btn.clear()
	btn.add_item("Setzen (absolut)", TerrainShapes.HeightMode.SET)
	btn.add_item("Anheben → Zielhöhe", TerrainShapes.HeightMode.RAISE)
	btn.add_item("Absenken → Zielhöhe", TerrainShapes.HeightMode.LOWER)


func _sync_shape_height_mode() -> void:
	var btn: OptionButton = %ShapeHeightMode
	var mode := EditorState.shape_height_mode
	for i in btn.item_count:
		if btn.get_item_id(i) == mode:
			btn.select(i)
			return
	if btn.item_count > 0:
		btn.select(0)


func _on_shape_height_mode_selected(index: int) -> void:
	if _syncing:
		return
	var btn: OptionButton = %ShapeHeightMode
	EditorState.set_shape_height_mode(btn.get_item_id(index))
	_update_status()


func _shape_height_mode_label() -> String:
	match EditorState.shape_height_mode:
		TerrainShapes.HeightMode.RAISE:
			return "Anheben"
		TerrainShapes.HeightMode.LOWER:
			return "Absenken"
		_:
			return "Setzen"


func _on_path_angle(v: float) -> void:
	if _syncing:
		return
	EditorState.set_pathing_max_angle_deg(v)
	%PathAngleValue.text = "%.1f°" % EditorState.pathing_max_angle_deg
	_update_status()


func _sync_pathing_status() -> void:
	var label: Label = %PathStatusLabel
	if EditorState.pathing_status.is_empty():
		label.text = "Path-Tool: rote Steigungen über Limit · zwei Klicks = Pfadprüfung"
	else:
		label.text = EditorState.pathing_status
	_update_status()


func _on_scale_guides_toggled(pressed: bool) -> void:
	if _syncing:
		return
	EditorState.set_show_scale_guides(pressed)


func _sync_scale_guides_check() -> void:
	%ScaleGuidesCheck.set_pressed_no_signal(EditorState.show_scale_guides)


func sync_set_height_from_state() -> void:
	## Called when terrain height is sampled with Shift+Click.
	_syncing = true
	set_height_slider.max_value = float(EditorState.map.height)
	set_height_slider.set_value_no_signal(EditorState.set_height_world)
	set_height_value.text = "%.1f m" % EditorState.set_height_world
	if EditorState.active_tool == EditorState.Tool.SHAPE_RAMP:
		%RampAngleSlider.set_value_no_signal(EditorState.ramp_angle_deg)
		%RampAngleValue.text = "%.1f°" % EditorState.ramp_angle_deg
		%RampLengthSlider.set_value_no_signal(EditorState.ramp_length_m)
		%RampLengthValue.text = "%.0f m" % EditorState.ramp_length_m
	_syncing = false
	_update_status()


func _on_new() -> void:
	EditorState.new_map(int(width_spin.value), int(length_spin.value), int(height_spin.value), int(res_spin.value))


func _on_apply_size() -> void:
	EditorState.new_map(int(width_spin.value), int(length_spin.value), int(height_spin.value), int(res_spin.value))


func _sync_playable_spins() -> void:
	var m := EditorState.map
	var area := m.get_playable_area()
	%PlayableXSpin.max_value = float(m.width)
	%PlayableYSpin.max_value = float(m.length)
	%PlayableWSpin.max_value = float(m.width)
	%PlayableHSpin.max_value = float(m.length)
	%PlayableXSpin.set_value_no_signal(area["x"])
	%PlayableYSpin.set_value_no_signal(area["y"])
	%PlayableWSpin.set_value_no_signal(area["width"])
	%PlayableHSpin.set_value_no_signal(area["height"])


func _sync_fade_spins() -> void:
	var m := EditorState.map
	%FadeStartSpin.set_value_no_signal(m.fade_start_distance)
	%FadeDistSpin.set_value_no_signal(m.fade_distance)


func _on_playable_changed(_value: float = 0.0) -> void:
	if _syncing:
		return
	EditorState.set_playable_area(
		%PlayableXSpin.value,
		%PlayableYSpin.value,
		%PlayableWSpin.value,
		%PlayableHSpin.value
	)
	# Reflect clamped values after EditorState applies bounds.
	_syncing = true
	_sync_playable_spins()
	_syncing = false


func _on_playable_size_changed(_value: float = 0.0) -> void:
	## Width/Length changes keep the playable rect centered on the map.
	if _syncing:
		return
	var m := EditorState.map
	var w: float = %PlayableWSpin.value
	var h: float = %PlayableHSpin.value
	var x := (float(m.width) - w) * 0.5
	var y := (float(m.length) - h) * 0.5
	EditorState.set_playable_area(x, y, w, h)
	_syncing = true
	_sync_playable_spins()
	_syncing = false


func _on_fade_start_changed(value: float) -> void:
	if _syncing:
		return
	EditorState.set_fade_start_distance(value)


func _on_fade_dist_changed(value: float) -> void:
	if _syncing:
		return
	EditorState.set_fade_distance(value)


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
	EditorState.set_water_enabled(pressed)


func _on_water_level(value: float) -> void:
	if _syncing:
		return
	EditorState.set_water_level(value)
	water_level_value.text = "%.1f m" % value


func _sync_history_buttons() -> void:
	%BtnUndo.disabled = not EditorState.can_undo()
	%BtnRedo.disabled = not EditorState.can_redo()
