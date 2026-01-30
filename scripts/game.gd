extends Node2D

@onready var grid_container: GridContainer = $GridContainer
@onready var timer: Timer = $Timer
@onready var label_score: Label = $GUI/score
@onready var label_timer: Label = $GUI/timer

var score = 0 

const TOTAL_DURATION_SECONDS = 100
const ROWS = 8 
const COLS = 8 
const TYPES = 6 

var tiles = []
var selected: Node = null

func _ready():
	randomize()
	_create_board()
	_ensure_no_initial_matches()
	reset_timer()
	set_score(0)

func _create_board():
	tiles = []
	grid_container.columns = COLS
	var tile_scene = preload("res://scenes/tile.tscn")
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			var tile = tile_scene.instantiate()
			tile.set_type(
				randi() % TYPES, r, c
			)
			tile.connect(
				"clicked_tile", 
				Callable(self, "_on_tile_clicked")
			)
			grid_container.add_child(tile)
			row.append(tile)
		tiles.append(row)
		
func _on_tile_clicked(tile):
	# when no tile is selected 
	if selected == null:
		selected = tile 
		tile.highlight(true)
	else:
	# when tile is already selected, selecting the 2nd tile for swap 
		
		# if user selects same tile, then deselect it 
		if tile == selected:
			tile.highlight(false)
			selected = null
			return
		
		# check adjacent 
		if _is_adjacent(selected, tile):
			selected.highlight(false)
			try_swap(selected, tile)
			selected = null
		else:
			selected.highlight(false)
			selected = tile  
			selected.highlight(true)

func _is_adjacent(a, b):
	#check if tile a is left/up/down/right of tile b
	return (
		(a.row == b.row and abs(a.col - b.col) == 1)
		or
		(a.col == b.col and abs(a.row - b.row) == 1)
	)

func try_swap(a, b):
	await swap(a, b)
	var matches = find_matches()
	if len(matches) == 0:
		# undo swap as there was no match found 
		await swap(a, b)
	else:
		await remove_matches(matches, true)
		await refill()
		# make sure to remove matches until board is stable 
		while true:
			matches = find_matches()
			if len(matches) == 0:
				break 
			await remove_matches(matches, true)
			await refill()

func swap(a, b):
	
	# swap tile types and do animation 
	var t = a.tile_type 
	a.change_type(b.tile_type)
	b.change_type(t)
	
	var tween = create_tween()
	# swap animation
	tween.tween_property(a, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(b, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#tween.tween_property(a, "scale", Vector2(1.08, 1.08), 0.10) \
		#.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#tween.parallel().tween_property(a, "scale", Vector2(1.08, 1.08), 0.10) \
		#.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# back to normal 
	tween.tween_property(a, "scale", Vector2.ONE, 0.10)
	tween.parallel().tween_property(b, "scale", Vector2.ONE, 0.10)
	#tween.tween_property(a, "scale", Vector2.ONE, 0.10)
	#tween.parallel().tween_property(a, "scale", Vector2.ONE, 0.10)
	await tween.finished

func find_matches():
	# returns array containing {r, c} indicating positions remove 
	var remove = []
	
	#check horizontal matches 
	for r in range(ROWS):
		var run_type = -1 
		var run_start = 0 
		var run_len = 0 
		
		for c in range(COLS):
			var t = tiles[r][c].tile_type
			if t == run_type:
				run_len += 1
			else:
				if run_len >= 3:
					for i in range(run_start, run_start + run_len):
						remove.append({"r": r, "c": i})
				run_type = t 
				run_start = c
				run_len = 1 
		if run_len >= 3:
			for i in range(run_start, run_start + run_len):
				remove.append({"r": r, "c": i})
	
	#check vertical matches 
	for c in range(COLS):
		var run_type = -1 
		var run_start = 0 
		var run_len = 0 
		
		for r in range(ROWS):
			var t = tiles[r][c].tile_type
			if t == run_type:
				run_len += 1
			else:
				if run_len >= 3:
					for i in range(run_start, run_start + run_len):
						remove.append({"r": i, "c": c})
				run_type = t 
				run_start = r
				run_len = 1 
		if run_len >= 3:
			for i in range(run_start, run_start + run_len):
				remove.append({"r": i, "c": c})
	
	# remove duplicates between 2 searches 
	var uniq = {}
	var out = []
	for p in remove:
		var key = str(p['r']) + "." + str(p['c'])
		if not uniq.has(key):
			uniq[key] = true 
			out.append(p)
	return out 

func remove_matches(matches, update_score: bool = false):
	#delete matches tiles 
	for p in matches:
		var r = p['r']
		var c = p['c']
		tiles[r][c].set_type(-1, r, c)
	if update_score:
		set_score(len(matches))
	
func refill():
	# animation settings 
	var pop_duration := 0.22
	var pop_stagger := 0.03
	
	var new_tiles = []
	
	for c in range(COLS):
		var stack = []
		# find rows which are not empty so they can be moved to bottom 
		for r in range(ROWS - 1, -1, -1):
			if tiles[r][c].tile_type != -1:
				stack.append(tiles[r][c].tile_type)
		
		# write non-empty tiles into location of empty tiles
		var idx = 0
		for r in range(ROWS -1, -1, -1):
			if idx < stack.size():
				var ttype = stack[idx]
				tiles[r][c].set_type(ttype, r, c)
				tiles[r][c].scale = Vector2.ONE
				idx += 1
			else:
				# if no tiles are there to remove, then empty the top
				tiles[r][c].set_type(-1, r, c)
		
		# next fill the top empty cells with new type 
		for r in range(0, ROWS):
			if tiles[r][c].tile_type == -1:
				var new_type = randi() % TYPES
				tiles[r][c].set_type(new_type, r, c)
				tiles[r][c].scale = Vector2(0.2, 0.2)
				new_tiles.append(tiles[r][c])
	
	#pop animation 
	if new_tiles.size() > 0:
		var tween = create_tween()
		for i in range(new_tiles.size()):
			if i > 0:
				tween.tween_interval(pop_stagger)
			tween.tween_property(
				new_tiles[i], "scale", Vector2.ONE, pop_duration
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tween.finished

func _ensure_no_initial_matches():
	while true:
		var matches = find_matches()
		if matches.size() == 0:
			break 
		for p in matches:
			tiles[p['r']][p['c']].set_type(
				randi() % TYPES,
				p['r'],
				p['c']
			)

func set_score(increment):
	score += increment 
	label_score.text = "SCORE: " + str(score)

func reset_timer():
	score = 0 
	if not timer.is_stopped():
		timer.stop()
	timer.wait_time = TOTAL_DURATION_SECONDS
	timer.start()
	
func _on_timer_timeout() -> void:
	if score < 100:
		# Player did not reach minimum score
		print("Game Over! You needed at least 100 points. Final score: " + str(score))
		get_tree().paused = true
	else:
		# Player reached the minimum score
		print("Congratulations! You reached " + str(score) + " points!")
		# You can trigger a win screen or next level here

func _process(delta: float) -> void:
	label_timer.text = "TIME: " + str(int(timer.time_left))
