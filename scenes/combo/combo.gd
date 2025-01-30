extends HBoxContainer

func _ready() -> void:
	$Glossary.get_node("%Sort").selected = Database.GlossarySearchQuery.SortMode.FREQUENCY
	$Glossary._on_query_text_submitted("")
