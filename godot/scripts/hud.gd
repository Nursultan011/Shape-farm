extends CanvasLayer
## HUD внутри Godot: монеты, доход, магазин улучшений, всплывающие «+N».
## В режиме React Native оболочка может скрыть его сообщением {"type":"set_hud","visible":false}
## и показать свой интерфейс.

var coins_label: Label
var income_label: Label
var stats_label: Label
var shop_button: Button
var shop_panel: PanelContainer
var shop_rows := {}
var toast_label: Label
var _root: Control


func _ready() -> void:
	_build()
	Game.coins_changed.connect(func(_c: int) -> void: refresh())
	Game.upgrades_changed.connect(refresh)
	Game.stats_changed.connect(refresh)
	refresh()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Верхняя панель.
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 48
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	var title := Label.new()
	title.text = "SHAPE FARM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	top.add_child(title)

	coins_label = Label.new()
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_label.add_theme_font_size_override("font_size", 64)
	coins_label.add_theme_color_override("font_color", Color("#ffe066"))
	top.add_child(coins_label)

	income_label = Label.new()
	income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	income_label.add_theme_font_size_override("font_size", 22)
	income_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	top.add_child(income_label)

	# Нижняя панель.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -170
	bottom.offset_bottom = -36
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.add_theme_constant_override("separation", 14)
	_root.add_child(bottom)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	bottom.add_child(stats_label)

	shop_button = Button.new()
	shop_button.text = "🛒  Улучшения"
	shop_button.custom_minimum_size = Vector2(0, 72)
	shop_button.add_theme_font_size_override("font_size", 28)
	shop_button.pressed.connect(toggle_shop)
	bottom.add_child(shop_button)

	# Тост.
	toast_label = Label.new()
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 210
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 26)
	toast_label.modulate.a = 0.0
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(toast_label)

	_build_shop()


func _build_shop() -> void:
	shop_panel = PanelContainer.new()
	shop_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shop_panel.custom_minimum_size = Vector2(640, 0)
	shop_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#242a4d")
	style.set_corner_radius_all(24)
	style.set_content_margin_all(24)
	shop_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(shop_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	shop_panel.add_child(vbox)

	var header := Label.new()
	header.text = "Улучшения"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 34)
	vbox.add_child(header)

	for id in Game.UPGRADE_ORDER:
		var def: Dictionary = Game.UPGRADES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		vbox.add_child(row)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 24)
		text.add_child(name_label)

		var desc := Label.new()
		desc.text = def["desc"]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 17)
		desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		text.add_child(desc)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(170, 60)
		buy.add_theme_font_size_override("font_size", 20)
		buy.pressed.connect(func() -> void:
			if Game.buy(id):
				toast("Куплено: %s" % def["name"])
		)
		row.add_child(buy)
		shop_rows[id] = {"name": name_label, "buy": buy}

	var close := Button.new()
	close.text = "Закрыть"
	close.custom_minimum_size = Vector2(0, 60)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(toggle_shop)
	vbox.add_child(close)


func toggle_shop() -> void:
	shop_panel.visible = not shop_panel.visible
	refresh()


func refresh() -> void:
	coins_label.text = _fmt(Game.coins)
	var income := "+%d за фигурку" % Game.per_tile()
	if Game.combo_bonus() > 0:
		income += "  ·  комбо +%d" % Game.combo_bonus()
	if Game.auto_interval() > 0.0:
		income += "  ·  авто %.1fс" % Game.auto_interval()
	income_label.text = income
	stats_label.text = "Разбито: %s   ·   Лучшая группа: %d   ·   Видов: %d" % [
		_fmt(Game.total_broken), Game.best_group, Game.kind_count()]
	for id in shop_rows.keys():
		var def: Dictionary = Game.UPGRADES[id]
		var r: Dictionary = shop_rows[id]
		r["name"].text = "%s  (ур. %d/%d)" % [def["name"], Game.upgrade_level(id), def["max"]]
		if Game.is_maxed(id):
			r["buy"].text = "MAX"
			r["buy"].disabled = true
		else:
			r["buy"].text = "%s 🪙" % _fmt(Game.upgrade_cost(id))
			r["buy"].disabled = not Game.can_buy(id)


func show_float(world_pos: Vector2, text: String, color := Color("#ffe066")) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	l.position = world_pos - l.get_minimum_size() * 0.5
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 90, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	t.chain().tween_callback(l.queue_free)


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var t := toast_label.create_tween()
	t.tween_interval(1.4)
	t.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _fmt(n: int) -> String:
	if n >= 1_000_000_000:
		return "%.2fB" % (n / 1_000_000_000.0)
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 10_000:
		return "%.1fK" % (n / 1000.0)
	return str(n)
