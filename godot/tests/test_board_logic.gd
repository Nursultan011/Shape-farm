extends SceneTree
## Headless-тест логики поля:
##   godot --headless --path godot --script tests/test_board_logic.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _init() -> void:
	print("BoardLogic tests")
	var L := BoardLogic.new(4, 4, 3, 7)

	# Задаём поле вручную (grid[c][r]).
	#  r0: A A B C
	#  r1: A B B C
	#  r2: C C A A
	#  r3: B C A B
	var rowsdef := [[0, 0, 1, 2], [0, 1, 1, 2], [2, 2, 0, 0], [1, 2, 0, 1]]
	for r in 4:
		for c in 4:
			L.grid[c][r] = rowsdef[r][c]
			L.golden[c][r] = false
	L.golden[2][2] = true

	var g := L.find_group(0, 0)
	check(g.size() == 3, "группа A в углу = 3 (%d)" % g.size())
	check(L.find_group(2, 0).size() == 3, "группа B = 3")
	check(L.find_group(3, 0).size() == 2, "группа C справа = 2")
	check(L.find_group(2, 2).size() == 3, "группа A внизу = 3 (диагонали не считаются)")
	check(L.find_group(0, 3).size() == 1, "одиночка B = 1")
	check(L.has_moves(), "ходы есть")

	var res := L.remove_group(L.find_group(2, 2))
	check(res["count"] == 3 and res["gold"] == 1 and res["kind"] == 0, "remove_group возвращает count/gold/kind")
	check(L.count_empty() == 3, "после удаления 3 пустых")

	var moves := L.collapse()
	check(moves.size() > 0, "collapse вернул перемещения (%d)" % moves.size())
	# В колонке 2 внизу должны оказаться B(r0), B(r1) → r2, r3; верх пустой.
	check(L.grid[2][3] == 1 and L.grid[2][2] == 1 and L.grid[2][0] == BoardLogic.EMPTY, "гравитация в колонке 2")
	for c in 4:
		var seen_filled := false
		for r in 4:
			if L.grid[c][r] != BoardLogic.EMPTY:
				seen_filled = true
			elif seen_filled:
				failures += 1
				printerr("  FAIL пустая клетка под фигуркой в колонке %d" % c)

	var created := L.refill()
	check(created.size() == 3, "refill создал 3 фигурки")
	check(L.count_empty() == 0, "пустых не осталось")
	var in_range := true
	for c in 4:
		for r in 4:
			if L.grid[c][r] < 0 or L.grid[c][r] >= 3:
				in_range = false
	check(in_range, "все виды в диапазоне [0,3)")

	# Shuffle всегда оставляет ход.
	var L2 := BoardLogic.new(3, 3, 9, 1)
	for c in 3:
		for r in 3:
			L2.grid[c][r] = c * 3 + r
	check(not L2.has_moves(), "шахматка без ходов")
	L2.shuffle()
	check(L2.has_moves(), "после shuffle ходы есть")

	# Случайное поле никогда не создаётся без ходов.
	for s in 30:
		var L3 := BoardLogic.new(7, 9, 6, s)
		if not L3.has_moves():
			failures += 1
			printerr("  FAIL поле без ходов, seed %d" % s)
	print("  ok   30 случайных полей с ходами")

	# all_groups не пересекаются и покрывают только группы >= 2.
	var groups := L.all_groups()
	var total := 0
	for grp in groups:
		check(grp.size() >= 2, "группа >= 2")
		total += grp.size()
	check(total <= 16, "группы не пересекаются")

	print("")
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("%d FAILURES" % failures)
	quit(0 if failures == 0 else 1)
