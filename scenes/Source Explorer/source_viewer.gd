extends Node2D
class_name SourceViewer

enum Mode { SELECT, CREATE, REMOVE }
var mode = Mode.SELECT

var drag_start_pos := Vector2()
var drag_end_pos := Vector2()
var dragging := false
var selected := 0
var hide_annotations := false

var source : Database.Source
var center : Vector2 = Vector2.ZERO

@export var font : Font

signal rect_selected(rect : Rect2, id : bool)
signal glyph_selected(id : int)
signal glyph_location_removed(id : int, rect: Rect2)

func get_aspect_ratio():
	return $source.get_rect().size.aspect()

func set_source( p_source : Database.Source ):
	source = p_source
	$source.texture = Database.get_texture(p_source.path)
	var texture_rect : Rect2 = $source.get_rect()
	get_viewport().size_2d_override = texture_rect.size
	center = texture_rect.get_center()
	$camera.position = center
	_update_display()

func _ready() -> void:
	Database.definition_added.connect(_update_display.unbind(2))
	Database.definition_removed.connect(_update_display.unbind(2))

func _input(event: InputEvent) -> void:
	if not source:
		return
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SHIFT:
		hide_annotations = event.is_pressed()
		_update_display()

	var texture_pos = $source.to_local(get_global_mouse_position())
	if event.is_pressed() and event is InputEventMouseButton:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var old_mouse_pos = get_global_mouse_position()
			$camera.zoom *= 0.9
			# Undo mouse drift
			$camera.position -= get_global_mouse_position() - old_mouse_pos
			if $camera.zoom.x < 1:
				$camera.zoom = Vector2.ONE
				$camera.position = center
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
			var old_mouse_pos = get_global_mouse_position()
			$camera.zoom *= 1.1
			# Undo mouse drift
			$camera.position -= get_global_mouse_position() - old_mouse_pos
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion_event := (event as InputEventMouseMotion)
		$camera.position -= motion_event.relative / $camera.zoom
	
	if mode == Mode.CREATE:
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				drag_start_pos = texture_pos
				drag_end_pos = texture_pos
				dragging = true
			else:
				dragging = false
				var rect := Rect2()
				rect.position = drag_start_pos
				rect.end = texture_pos
				var repeat_id := Input.is_physical_key_pressed(KEY_CTRL)
				if rect.has_area():
					rect_selected.emit(rect, selected if repeat_id else 0)
				_update_display()
		if event is InputEventMouseMotion:
			if dragging:
				drag_end_pos = texture_pos
				_update_display()

	elif mode == Mode.REMOVE:
		Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
		if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			for rect in source.rects:
				if rect.has_point(texture_pos):
					glyph_location_removed.emit(source.rects[rect], rect)
					_update_display()
					break
		
	elif mode == Mode.SELECT:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			for rect in source.rects:
				if rect.has_point(texture_pos):
					select(source.rects[rect])
					break

func _update_display():
	queue_redraw()

func select(id: int):
	selected = id
	glyph_selected.emit(selected)
	_update_display()

func _draw() -> void:
	if source and not hide_annotations:
		for rect in source.rects.keys():
			var _rect = rect
			var id = source.rects[rect]
			_rect.position += Vector2i(1,1)
			draw_rect(_rect, Color.BLACK, false, 1)
			_rect.position -= Vector2i(1,1)
			draw_rect(_rect, Color.RED if id == selected else Color.WHITE, false, 1)
			var text_pos = _rect.position + Vector2i(4,12)
			draw_string(font, text_pos, str(id),HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.BLACK )
			text_pos += Vector2i(-1,-1)
			draw_string(font, text_pos, str(id),HORIZONTAL_ALIGNMENT_LEFT, -1, 8 )
			var glyph = Database.glyph_get(id)
			if not glyph:
				continue
			var definition = glyph.definitions.front() if not glyph.definitions.is_empty() else null
			if not definition:
				continue
			text_pos += Vector2i(0, -13)
			draw_string(font, text_pos, str(glyph.definitions.front()),HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK )
			text_pos += Vector2i(-1, -1)
			draw_string(font, text_pos, str(glyph.definitions.front()),HORIZONTAL_ALIGNMENT_LEFT, -1, 10 )
	if dragging:
		draw_rect( Rect2(drag_start_pos, drag_end_pos - drag_start_pos), Color.YELLOW, false, 1 )
