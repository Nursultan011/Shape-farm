extends Node
## Autoload «Bridge»: мост к React Native через singleton «ReactNative» из react-native-godot.
## Если игра запущена отдельно (без RN), мост молчит и всё работает как обычно.
##
## Godot -> RN:  {"type": "ready"|"state"|"break"|"upgrade_result"|"shuffle"|"offline", ...}
## RN -> Godot:  {"type": "get_state"} | {"type": "buy_upgrade", "id": "value"}
##               | {"type": "set_hud", "visible": false} | {"type": "reset"}

signal message_received(msg: Dictionary)

var _rn = null
var hud_visible := true


func _ready() -> void:
	if Engine.has_singleton("ReactNative"):
		_rn = Engine.get_singleton("ReactNative")
		_rn.on_message(_on_message)
		print("[Bridge] ReactNative singleton подключён")
	Game.coins_changed.connect(func(_c: int) -> void: send_state())
	Game.upgrades_changed.connect(send_state)
	Game.stats_changed.connect(send_state)


func is_embedded() -> bool:
	return _rn != null


func send(type: String, data: Dictionary = {}) -> void:
	if _rn == null:
		return
	var payload := data.duplicate()
	payload["type"] = type
	_rn.emit_message(payload)


func send_state() -> void:
	send("state", Game.to_public_dict())


func _on_message(msg) -> void:
	var d: Dictionary = msg if msg is Dictionary else {}
	var type := String(d.get("type", ""))
	match type:
		"get_state":
			send_state()
		"buy_upgrade":
			var id := String(d.get("id", ""))
			var ok := Game.buy(id)
			send("upgrade_result", {"id": id, "ok": ok, "level": Game.upgrade_level(id) if Game.UPGRADES.has(id) else 0})
		"set_hud":
			hud_visible = bool(d.get("visible", true))
			message_received.emit(d)
		"reset":
			Game.reset()
			message_received.emit(d)
		_:
			message_received.emit(d)
