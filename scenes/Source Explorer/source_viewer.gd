extends Node2D
class_name SourceViewer

var drag_start_pos := Vector2()
var drag_end_pos := Vector2()
var dragging := false

var source : Database.Source

signal rect_selected(rect : Rect2)

func set_source( p_source : Database.Source ):
	source = p_source
	$source.texture = Database.texture_cache.get_texture(p_source.path)
	get_viewport().size_2d_override = $source.texture.get_size()
	_update_display()

func _input(event: InputEvent) -> void:
	var texture_pos = $source.to_local(get_global_mouse_position())
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
			rect_selected.emit(rect)
			_update_display()
	if event is InputEventMouseMotion:
		if dragging:
			drag_end_pos = texture_pos
			_update_display()

func _update_display():
	queue_redraw()

func _draw() -> void:
	if source:
		for rect in source.rects.keys():
			draw_rect(rect, Color.RED, false, 3)
	if dragging:
		draw_rect( Rect2(drag_start_pos, drag_end_pos - drag_start_pos), Color.YELLOW, false, 1 )
