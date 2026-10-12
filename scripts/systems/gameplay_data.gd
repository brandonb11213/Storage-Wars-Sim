class_name GameplayData
extends RefCounted

static var config: Dictionary = {}

static func get_config() -> Dictionary:
	if config.is_empty():
		config = JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay.json"))
	return config
