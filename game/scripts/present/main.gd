extends Node2D
## The game's first screen. For now a title card; the grey-box street replaces it in Stage 1.

const Version := preload("res://scripts/sim/version.gd")


func _ready() -> void:
	$Title.text = "%s\n%s" % [Version.TITLE, Version.STAGE]
