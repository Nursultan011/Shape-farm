class_name BoardLogic
extends RefCounted
## Чистая логика поля без узлов и анимаций — её удобно тестировать headless.
## grid[c][r]: c — колонка (0 слева), r — ряд (0 сверху). EMPTY = -1.

const EMPTY := -1

var cols: int
var rows: int
var kinds: int
var gold_chance := 0.0
var grid: Array = []
var golden: Array = []
var rng := RandomNumberGenerator.new()


func _init(p_cols: int, p_rows: int, p_kinds: int, seed_value: int = -1) -> void:
	cols = p_cols
	rows = p_rows
	kinds = max(2, p_kinds)
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	fill_all()


func fill_all() -> void:
	grid = []
	golden = []
	for c in cols:
		var col: Array = []
		var gcol: Array = []
		for r in rows:
			col.append(_random_kind())
			gcol.append(_roll_gold())
		grid.append(col)
		golden.append(gcol)
	if not has_moves():
		shuffle()


func set_kinds(p_kinds: int) -> void:
	kinds = max(2, p_kinds)


func in_bounds(c: int, r: int) -> bool:
	return c >= 0 and c < cols and r >= 0 and r < rows


func get_kind(c: int, r: int) -> int:
	if not in_bounds(c, r):
		return EMPTY
	return grid[c][r]


func is_gold(c: int, r: int) -> bool:
	return in_bounds(c, r) and golden[c][r]


## Поиск связной группы одинаковых фигурок (4 соседа) вокруг клетки.
func find_group(c: int, r: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var kind := get_kind(c, r)
	if kind == EMPTY:
		return result
	var visited := {}
	var stack: Array[Vector2i] = [Vector2i(c, r)]
	visited[Vector2i(c, r)] = true
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		result.append(cell)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + d
			if visited.has(n):
				continue
			if get_kind(n.x, n.y) == kind:
				visited[n] = true
				stack.append(n)
	return result


## Убирает группу. Возвращает {"count": int, "gold": int, "kind": int}.
func remove_group(cells: Array[Vector2i]) -> Dictionary:
	var gold := 0
	var kind := EMPTY
	for cell in cells:
		if not in_bounds(cell.x, cell.y):
			continue
		if kind == EMPTY:
			kind = grid[cell.x][cell.y]
		if golden[cell.x][cell.y]:
			gold += 1
		grid[cell.x][cell.y] = EMPTY
		golden[cell.x][cell.y] = false
	return {"count": cells.size(), "gold": gold, "kind": kind}


## Гравитация: фигурки падают вниз. Возвращает список перемещений {"from": Vector2i, "to": Vector2i}.
func collapse() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for c in cols:
		var write := rows - 1
		for r in range(rows - 1, -1, -1):
			if grid[c][r] == EMPTY:
				continue
			if r != write:
				grid[c][write] = grid[c][r]
				golden[c][write] = golden[c][r]
				grid[c][r] = EMPTY
				golden[c][r] = false
				moves.append({"from": Vector2i(c, r), "to": Vector2i(c, write)})
			write -= 1
	return moves


## Заполняет пустые клетки новыми фигурками. Возвращает список новых клеток.
func refill() -> Array[Vector2i]:
	var created: Array[Vector2i] = []
	for c in cols:
		for r in rows:
			if grid[c][r] == EMPTY:
				grid[c][r] = _random_kind()
				golden[c][r] = _roll_gold()
				created.append(Vector2i(c, r))
	return created


func has_moves() -> bool:
	for c in cols:
		for r in rows:
			var k: int = grid[c][r]
			if k == EMPTY:
				continue
			if get_kind(c + 1, r) == k or get_kind(c, r + 1) == k:
				return true
	return false


## Все группы размером >= 2 (для авто-молота).
func all_groups(min_size: int = 2) -> Array:
	var groups := []
	var seen := {}
	for c in cols:
		for r in rows:
			var cell := Vector2i(c, r)
			if seen.has(cell) or grid[c][r] == EMPTY:
				continue
			var g := find_group(c, r)
			for x in g:
				seen[x] = true
			if g.size() >= min_size:
				groups.append(g)
	return groups


func largest_group() -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for g in all_groups():
		if g.size() > best.size():
			best = g
	return best


## Перемешивает существующие фигурки так, чтобы ход точно был.
func shuffle() -> void:
	for attempt in 20:
		var flat: Array = []
		for c in cols:
			for r in rows:
				flat.append([grid[c][r], golden[c][r]])
		for i in range(flat.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = flat[i]
			flat[i] = flat[j]
			flat[j] = tmp
		var idx := 0
		for c in cols:
			for r in rows:
				grid[c][r] = flat[idx][0]
				golden[c][r] = flat[idx][1]
				idx += 1
		if has_moves():
			return
	# Крайний случай: заполняем заново.
	for c in cols:
		for r in rows:
			grid[c][r] = _random_kind()
	if not has_moves():
		grid[0][0] = grid[0][1]


func count_empty() -> int:
	var n := 0
	for c in cols:
		for r in rows:
			if grid[c][r] == EMPTY:
				n += 1
	return n


func _random_kind() -> int:
	return rng.randi_range(0, kinds - 1)


func _roll_gold() -> bool:
	return gold_chance > 0.0 and rng.randf() < gold_chance
