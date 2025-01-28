extends Node2D
class_name SourceViewer

enum Mode { SELECT, CREATE, REMOVE }
var mode = Mode.SELECT

var drag_start_pos := Vector2()
var drag_end_pos := Vector2()
var dragging := false
var selected := 0

var source : Database.Source
var center : Vector2 = Vector2.ZERO

@export var font : Font

signal rect_selected(rect : Rect2)
signal glyph_selected(id : int)
signal glyph_removed(id : int)

func get_aspect_ratio():
	return $source.get_rect().size.aspect()

func set_source( p_source : Database.Source ):
	source = p_source
	$source.texture = Database.texture_cache.get_texture(p_source.path)
	get_viewport().size_2d_override = $source.texture.get_size()
	center = $source.get_rect().get_center()
	$camera.position = center
	_update_display()

func _input(event: InputEvent) -> void:
	var texture_pos = $source.to_local(get_global_mouse_position())
	if event.is_pressed() and event is InputEventMouseButton:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$camera.zoom *= 0.9
			$camera.position = $camera.position.lerp(center, 0.05)
			if $camera.zoom.x < 1:
				$camera.zoom = Vector2.ONE
				$camera.position = center
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
			$camera.zoom *= 1.1
			$camera.position = $camera.position.lerp(get_global_mouse_position(), 0.2)
	
	if mode == Mode.CREATE:
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
				if rect.has_area():
					rect_selected.emit(rect)
				_update_display()
		if event is InputEventMouseMotion:
			if dragging:
				drag_end_pos = texture_pos
				_update_display()

	elif mode == Mode.REMOVE:
		if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			for rect in source.rects:
				if rect.has_point(texture_pos):
					glyph_removed.emit(source.rects[rect])
					_update_display()
					break
		
	elif mode == Mode.SELECT:
		if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			for rect in source.rects:
				if rect.has_point(texture_pos):
					selected = source.rects[rect]
					glyph_selected.emit(selected)
					_update_display()
					break

func _update_display():
	queue_redraw()

func _draw() -> void:
	if source:
		for rect in source.rects.keys():
			var _rect = rect
			var id = source.rects[rect]
			_rect.position += Vector2i(2,2)
			draw_rect(_rect, Color.BLACK, false, 2)
			_rect.position -= Vector2i(2,2)
			draw_rect(_rect, Color.RED if id == selected else Color.WHITE, false, 2)
			var text_pos = _rect.position + Vector2i(10,25)
			draw_string(font, text_pos, str(id),HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.BLACK )
			text_pos += Vector2i(-1,-2)
			draw_string(font, text_pos, str(id),HORIZONTAL_ALIGNMENT_LEFT, -1, 20 )
			var glyph = Database.glyph_get(id)
			if not glyph:
				continue
			var definition = glyph.definitions.front() if not glyph.definitions.is_empty() else null
			if not definition:
				continue
			text_pos += Vector2i(0, -30)
			draw_string(font, text_pos, str(glyph.definitions.front()),HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.BLACK )
			text_pos += Vector2i(-2, -2)
			draw_string(font, text_pos, str(glyph.definitions.front()),HORIZONTAL_ALIGNMENT_LEFT, -1, 20 )
	if dragging:
		draw_rect( Rect2(drag_start_pos, drag_end_pos - drag_start_pos), Color.YELLOW, false, 3 )
