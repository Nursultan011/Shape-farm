extends Node2D
## Корневая сцена: фон, поле, HUD и связь с React Native.

@onready var board: Board = $Board
@onready var hud: CanvasLayer = $HUD
@onready var background: ColorRect = $Background


func _ready() -> void:
	_fit_background()
	get_viewport().size_changed.connect(_fit_background)

	board.group_broken.connect(_on_group_broken)
	board.board_shuffled.connect(func() -> void:
		hud.toast("Ходов нет — перемешиваем!")
		Bridge.send("shuffle")
	)
	Bridge.message_received.connect(_on_bridge_message)

	hud.visible = Bridge.hud_visible
	if Game.pending_offline_reward > 0:
		hud.toast("Пока вас не было: +%d 🪙" % Game.pending_offline_reward)
		Bridge.send("offline", {"coins": Game.pending_offline_reward, "seconds": Game.pending_offline_seconds})
		Game.pending_offline_reward = 0
	Bridge.send("ready", Game.to_public_dict())


func _fit_background() -> void:
	background.size = get_viewport_rect().size


func _on_group_broken(count: int, kind: int, gold: int, coins: int, by_player: bool, world_pos: Vector2) -> void:
	var text := "+%d" % coins
	if count >= 6:
		text += "  🔥"
	hud.show_float(world_pos, text, Tile.GOLD if gold > 0 else Tile.COLORS[kind % Tile.COLORS.size()])
	Bridge.send("break", {
		"count": count,
		"shape": Tile.SHAPE_NAMES[kind % Tile.SHAPE_NAMES.size()],
		"gold": gold,
		"coins": coins,
		"by_player": by_player,
	})


func _on_bridge_message(d: Dictionary) -> void:
	match String(d.get("type", "")):
		"set_hud":
			hud.visible = Bridge.hud_visible
		"reset":
			board.setup_fresh()
		"toast":
			hud.toast(String(d.get("text", "")))
