extends Node
## Smoke-тест всей сцены: загружает main.tscn, разбивает группы (напрямую и через тап),
## покупает улучшение, проверяет целостность поля. Запускается как сцена, чтобы работали автозагрузки:
##   godot --headless --path godot tests/smoke_scene.tscn
## С переменной окружения SHAPE_FARM_SCREENSHOT=path.png (без --headless) сохраняет скриншот.
## ВНИМАНИЕ: тест сбрасывает сохранение (user://shape_farm_save.json), чтобы быть детерминированным.

var frame := 0
var board: Board
var failures := 0
var coins_before := 0
var screenshot_path := ""
var game: Node


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _ready() -> void:
	screenshot_path = OS.get_environment("SHAPE_FARM_SCREENSHOT")
	game = Game
	game.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	board = main.get_node("Board")
	print("Scene smoke test")


func _process(_delta: float) -> void:
	frame += 1
	match frame:
		5:
			check(board != null and board.tiles.size() == board.cols, "поле создано")
			check(_count_tiles() == board.cols * board.rows, "все клетки заполнены")
			coins_before = game.coins
			var g := board.logic.largest_group()
			check(g.size() >= 2, "есть группа для разбивания (%d)" % g.size())
			board.break_group(g, true)
		70:
			check(game.coins > coins_before, "монеты начислены (%d -> %d)" % [coins_before, game.coins])
			check(_count_tiles() == board.cols * board.rows, "после разбивания поле снова полное")
			check(board.logic.count_empty() == 0, "в логике нет пустых клеток")
			check(_tiles_match_logic(), "узлы совпадают с логикой")
			check(not board.busy, "поле снова принимает ввод")
			# Тап через событие ввода.
			coins_before = game.coins
			var g := board.logic.largest_group()
			var ev := InputEventScreenTouch.new()
			ev.pressed = true
			ev.index = 0
			# В headless окно 0x0 — переводим координаты канвы в экранные явно.
			ev.position = board.get_viewport().get_screen_transform() * board.to_global(board.cell_to_pos(g[0].x, g[0].y))
			Input.parse_input_event(ev)
		140:
			check(game.coins > coins_before, "тап по экрану разбил группу (%d -> %d)" % [coins_before, game.coins])
			check(_tiles_match_logic(), "узлы совпадают с логикой после тапа")
			# Покупка улучшения.
			game.add_coins(10_000)
			var lvl: int = game.upgrade_level("value")
			check(game.buy("value"), "покупка «Ценность» прошла")
			check(game.upgrade_level("value") == lvl + 1, "уровень вырос")
			check(game.per_tile() == 1 + game.upgrade_level("value"), "доход за фигурку обновился")
			check(game.buy("kinds"), "покупка «Меньше видов» прошла")
			check(board.logic.kinds == game.kind_count(), "поле подхватило новое число видов")
			check(game.buy("auto"), "покупка «Авто-молот» прошла")
			check(board._auto_timer.is_stopped() == false, "авто-молот запущен")
			var state: Dictionary = game.to_public_dict()
			check(state["upgrades"].size() == 5 and state.has("coins"), "состояние для RN сформировано")
			game.save_game()
			check(FileAccess.file_exists(game.SAVE_PATH), "сохранение записано")
		170:
			if screenshot_path != "":
				var img := get_viewport().get_texture().get_image()
				img.save_png(screenshot_path)
				print("  screenshot -> ", screenshot_path)
		190:
			print("")
			if failures == 0:
				print("SMOKE TEST PASSED")
			else:
				printerr("%d FAILURES" % failures)
			get_tree().quit(0 if failures == 0 else 1)


func _count_tiles() -> int:
	var n := 0
	for col in board.tiles:
		for t in col:
			if t != null:
				n += 1
	return n


func _tiles_match_logic() -> bool:
	for c in board.cols:
		for r in board.rows:
			var t: Tile = board.tiles[c][r]
			if t == null or t.kind != board.logic.get_kind(c, r):
				return false
	return true
