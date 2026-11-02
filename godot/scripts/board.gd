class_name Board
extends Node2D
## Игровое поле: тап по группе из 2+ одинаковых соседних фигурок разбивает её.

signal group_broken(count: int, kind: int, gold: int, coins: int, by_player: bool, world_pos: Vector2)
signal board_shuffled

@export var cols := 7
@export var rows := 9

var logic: BoardLogic
var tiles: Array = []
var tile_size := 90.0
var busy := false
var last_tap_world := Vector2.ZERO

var _auto_timer: Timer
var _board_px := Vector2.ZERO


func _ready() -> void:
	_auto_timer = Timer.new()
	_auto_timer.one_shot = false
	_auto_timer.timeout.connect(_on_auto_tick)
	add_child(_auto_timer)
	Game.upgrades_changed.connect(_on_upgrades_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	setup_fresh()


func setup_fresh() -> void:
	busy = false
	logic = BoardLogic.new(cols, rows, Game.kind_count())
	logic.gold_chance = Game.gold_chance()
	_layout()
	_spawn_all(true)
	_update_auto_timer()


# ---------- геометрия ----------

func _layout() -> void:
	var vp := get_viewport_rect().size
	var avail_w := vp.x * 0.94
	var avail_h := vp.y * 0.62
	tile_size = floor(min(avail_w / cols, avail_h / rows))
	_board_px = Vector2(cols, rows) * tile_size
	# Поле по центру экрана, чуть ниже середины (сверху HUD).
	position = Vector2((vp.x - _board_px.x) * 0.5, vp.y * 0.53 - _board_px.y * 0.5)


func board_size_px() -> Vector2:
	return _board_px


func cell_to_pos(c: int, r: int) -> Vector2:
	return Vector2(c + 0.5, r + 0.5) * tile_size


func pos_to_cell(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x / tile_size), floori(local.y / tile_size))


func _on_viewport_resized() -> void:
	_layout()
	for c in cols:
		for r in rows:
			var t: Tile = tiles[c][r]
			if t:
				t.setup(t.kind, t.is_gold, tile_size, Vector2i(c, r))
				t.position = cell_to_pos(c, r)


# ---------- фигурки ----------

func _spawn_all(animated: bool) -> void:
	for col in tiles:
		for t in col:
			if t:
				t.queue_free()
	tiles = []
	for c in cols:
		var col: Array = []
		for r in rows:
			var t := _make_tile(c, r)
			if animated:
				t.appear((rows - r) * 0.025 + c * 0.015)
			col.append(t)
		tiles.append(col)


func _make_tile(c: int, r: int) -> Tile:
	var t := Tile.new()
	t.setup(logic.get_kind(c, r), logic.is_gold(c, r), tile_size, Vector2i(c, r))
	t.position = cell_to_pos(c, r)
	add_child(t)
	return t


# ---------- ввод ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_tap(make_input_local(event).position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(make_input_local(event).position)
		get_viewport().set_input_as_handled()


func _tap(local: Vector2) -> void:
	if busy:
		return
	var cell := pos_to_cell(local)
	if not logic.in_bounds(cell.x, cell.y):
		return
	var group := logic.find_group(cell.x, cell.y)
	if group.size() < 2:
		var t: Tile = tiles[cell.x][cell.y]
		if t:
			t.shake()
		return
	last_tap_world = to_global(cell_to_pos(cell.x, cell.y))
	break_group(group, true)


# ---------- разбивание ----------

func break_group(group: Array[Vector2i], by_player: bool) -> void:
	if busy or group.size() < 2:
		return
	busy = true
	var center := Vector2.ZERO
	for cell in group:
		center += cell_to_pos(cell.x, cell.y)
	center /= group.size()
	var world_pos := to_global(center)

	var result := logic.remove_group(group)
	var coins := Game.reward_for(result["count"], result["gold"])
	for cell in group:
		var t: Tile = tiles[cell.x][cell.y]
		if t:
			_burst(t.position, t.color(), t.is_gold)
			t.pop()
		tiles[cell.x][cell.y] = null

	Game.add_coins(coins)
	Game.register_break(result["count"], by_player)
	group_broken.emit(result["count"], result["kind"], result["gold"], coins, by_player, world_pos)

	await get_tree().create_timer(0.1).timeout

	for m in logic.collapse():
		var from: Vector2i = m["from"]
		var to: Vector2i = m["to"]
		var t: Tile = tiles[from.x][from.y]
		tiles[from.x][from.y] = null
		tiles[to.x][to.y] = t
		if t:
			t.cell = to
			t.slide_to(cell_to_pos(to.x, to.y))

	for cell in logic.refill():
		var t := _make_tile(cell.x, cell.y)
		t.position = cell_to_pos(cell.x, -1 - (rows - 1 - cell.y) * 0.3)
		t.slide_to(cell_to_pos(cell.x, cell.y), 0.26)
		tiles[cell.x][cell.y] = t

	await get_tree().create_timer(0.24).timeout

	if not logic.has_moves():
		logic.shuffle()
		_spawn_all(true)
		board_shuffled.emit()
	busy = false


func _burst(pos: Vector2, color: Color, gold: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = 14 if not gold else 26
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, 900)
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = tile_size * 0.05
	p.scale_amount_max = tile_size * 0.11
	p.color = Tile.GOLD if gold else color
	add_child(p)
	get_tree().create_timer(0.7).timeout.connect(p.queue_free)


# ---------- авто-молот ----------

func _update_auto_timer() -> void:
	var interval := Game.auto_interval()
	if interval <= 0.0:
		_auto_timer.stop()
	else:
		_auto_timer.wait_time = interval
		if _auto_timer.is_stopped():
			_auto_timer.start()


func _on_auto_tick() -> void:
	if busy:
		return
	var groups := logic.all_groups()
	if groups.is_empty():
		return
	var g: Array[Vector2i] = groups[randi() % groups.size()]
	break_group(g, false)


func _on_upgrades_changed() -> void:
	_update_auto_timer()
	logic.gold_chance = Game.gold_chance()
	if logic.kinds != Game.kind_count():
		logic.set_kinds(Game.kind_count())
		# Старые фигурки лишнего вида заменяем, чтобы поле соответствовало новому числу видов.
		var changed := false
		for c in cols:
			for r in rows:
				if logic.grid[c][r] >= logic.kinds:
					logic.grid[c][r] = logic.rng.randi_range(0, logic.kinds - 1)
					changed = true
		if changed:
			if not logic.has_moves():
				logic.shuffle()
			_spawn_all(true)
