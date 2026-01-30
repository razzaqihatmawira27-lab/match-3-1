extends Button

signal clicked_tile(tile)

var row: int = -1 
var col: int = -1 
var tile_type: int = 0 

@onready var color_rect: ColorRect = $ColorRect

func _ready():
	color_rect.hide()

func set_type(t: int, r:int, c:int):
	row = r
	col = c 
	tile_type = t
	update_visual()

func change_type(t: int):
	tile_type = t 
	update_visual()

func update_visual():
	var color 
	match tile_type:
		0: color = Color.AQUAMARINE
		1: color = Color.TOMATO
		2: color = Color.DARK_GREEN
		3: color = Color.REBECCA_PURPLE 
		4: color = Color.ORANGE 
		5: color = Color.SADDLE_BROWN
		_: color = Color.TRANSPARENT
	modulate = color 


func _on_pressed() -> void:
	emit_signal("clicked_tile", self)

func highlight(on: bool):
	color_rect.visible = on 
	
