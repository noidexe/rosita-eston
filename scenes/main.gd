extends Control

enum Tools { GLOSSARY, SOURCES } 

const tool_scenes : Dictionary[Tools, Dictionary] = {
	Tools.GLOSSARY: { "name": "Glossary", "scene": preload("uid://bm4obkucf6pvo")},
	Tools.SOURCES: { "name": "Source Explorer", "scene": preload("uid://cm7nt1r5rwjrc")},
}

var tool_instances : Dictionary[Tools, Node] = {}

func _ready() -> void:
	_set_ui_scale()
	
	$saving.hide()
	Database.save_started.connect($saving.show)
	Database.save_complete.connect($saving.hide)
	
	
	for node in %ToolBar.get_children():
		%ToolBar.remove_child(node)

	var button := Button.new()
	var bgroup := ButtonGroup.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in tool_scenes.keys():
		var tool_button : Button = button.duplicate()
		tool_button.name = tool_scenes[key].name
		tool_button.text = tool_scenes[key].name
		tool_button.pressed.connect(_on_tool_selected.bind(key))
		tool_button.button_group = bgroup
		%ToolBar.add_child(tool_button)
		var tool_scene : Node = (tool_scenes[key].scene as PackedScene).instantiate()
		tool_instances[key] = tool_scene
	
	(tool_instances[Tools.GLOSSARY] as Glossary).glyph_selected.connect((tool_instances[Tools.SOURCES] as SourceExplorer)._on_glyph_selected)

func _set_ui_scale():
	get_window().content_scale_factor = DisplayServer.screen_get_dpi() / 96.0


func _on_tool_selected( tool : Tools):
	for node in %Content.get_children():
		%Content.remove_child(node)
	%Content.add_child(tool_instances[tool])
