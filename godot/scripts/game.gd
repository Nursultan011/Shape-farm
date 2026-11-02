extends Node
## Autoload «Game»: монеты, статистика, улучшения, сохранение и оффлайн-доход.

signal coins_changed(coins: int)
signal stats_changed
signal upgrades_changed

const SAVE_PATH := "user://shape_farm_save.json"
const SAVE_VERSION := 1
const BASE_KINDS := 6
const MIN_KINDS := 3
const OFFLINE_CAP_SEC := 8 * 3600

## Описание улучшений. Стоимость = base_cost * growth^level.
const UPGRADES := {
	"value": {"name": "Ценность", "desc": "+1 монета за каждую фигурку", "base_cost": 25, "growth": 1.55, "max": 60},
	"combo": {"name": "Комбо", "desc": "+1 монета за каждую фигурку сверх двух", "base_cost": 60, "growth": 1.65, "max": 40},
	"gold": {"name": "Золото", "desc": "+1% шанс золотой фигурки (x5)", "base_cost": 150, "growth": 1.5, "max": 30},
	"auto": {"name": "Авто-молот", "desc": "Сам разбивает группы; каждый уровень быстрее", "base_cost": 200, "growth": 1.8, "max": 20},
	"kinds": {"name": "Меньше видов", "desc": "На один вид фигурок меньше — группы крупнее", "base_cost": 800, "growth": 4.0, "max": BASE_KINDS - MIN_KINDS},
}
const UPGRADE_ORDER := ["value", "combo", "gold", "auto", "kinds"]

var coins := 0
var total_coins := 0
var total_broken := 0
var taps := 0
var best_group := 0
var levels := {"value": 0, "combo": 0, "gold": 0, "auto": 0, "kinds": 0}
var last_seen := 0
var pending_offline_reward := 0
var pending_offline_seconds := 0

var _save_pending := false


func _ready() -> void:
	load_game()
	_apply_offline()
	last_seen = int(Time.get_unix_time_from_system())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		save_game()


# ---------- параметры, зависящие от улучшений ----------

func kind_count() -> int:
	return clamp(BASE_KINDS - levels["kinds"], MIN_KINDS, BASE_KINDS)


func gold_chance() -> float:
	return levels["gold"] * 0.01


func per_tile() -> int:
	return 1 + levels["value"]


func combo_bonus() -> int:
	return levels["combo"]


## Интервал авто-молота в секундах; 0 — выключен.
func auto_interval() -> float:
	var lvl: int = levels["auto"]
	if lvl <= 0:
		return 0.0
	return max(0.8, 6.0 * pow(0.82, lvl - 1))


func reward_for(count: int, gold: int) -> int:
	var base := count * per_tile()
	var combo: int = maxi(0, count - 2) * combo_bonus()
	var gold_bonus := gold * per_tile() * 4
	return base + combo + gold_bonus


## Приблизительный доход в секунду от авто-молота (для оффлайн-начисления).
func auto_rate_per_sec() -> float:
	var interval := auto_interval()
	if interval <= 0.0:
		return 0.0
	return reward_for(3, 0) / interval


# ---------- действия ----------

func add_coins(n: int) -> void:
	if n == 0:
		return
	coins += n
	if n > 0:
		total_coins += n
	coins_changed.emit(coins)
	_mark_dirty()


func register_break(count: int, by_player: bool) -> void:
	total_broken += count
	if by_player:
		taps += 1
	best_group = max(best_group, count)
	stats_changed.emit()
	_mark_dirty()


func upgrade_cost(id: String) -> int:
	var def: Dictionary = UPGRADES[id]
	return int(round(def["base_cost"] * pow(def["growth"], levels[id])))


func upgrade_level(id: String) -> int:
	return levels.get(id, 0)


func is_maxed(id: String) -> bool:
	return levels[id] >= UPGRADES[id]["max"]


func can_buy(id: String) -> bool:
	if not UPGRADES.has(id) or is_maxed(id):
		return false
	return coins >= upgrade_cost(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	coins -= upgrade_cost(id)
	levels[id] += 1
	coins_changed.emit(coins)
	upgrades_changed.emit()
	save_game()
	return true


func reset() -> void:
	coins = 0
	total_coins = 0
	total_broken = 0
	taps = 0
	best_group = 0
	for k in levels.keys():
		levels[k] = 0
	pending_offline_reward = 0
	coins_changed.emit(coins)
	stats_changed.emit()
	upgrades_changed.emit()
	save_game()


# ---------- сериализация ----------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": coins,
		"total_coins": total_coins,
		"total_broken": total_broken,
		"taps": taps,
		"best_group": best_group,
		"levels": levels.duplicate(),
		"last_seen": int(Time.get_unix_time_from_system()),
	}


## Состояние для React Native (всё, что нужно HUD и магазину).
func to_public_dict() -> Dictionary:
	var ups := []
	for id in UPGRADE_ORDER:
		var def: Dictionary = UPGRADES[id]
		ups.append({
			"id": id,
			"name": def["name"],
			"desc": def["desc"],
			"level": levels[id],
			"max": def["max"],
			"cost": upgrade_cost(id),
			"can_buy": can_buy(id),
		})
	return {
		"coins": coins,
		"total_coins": total_coins,
		"total_broken": total_broken,
		"taps": taps,
		"best_group": best_group,
		"per_tile": per_tile(),
		"combo_bonus": combo_bonus(),
		"gold_chance": gold_chance(),
		"auto_interval": auto_interval(),
		"kinds": kind_count(),
		"upgrades": ups,
	}


func from_dict(d: Dictionary) -> void:
	coins = int(d.get("coins", 0))
	total_coins = int(d.get("total_coins", 0))
	total_broken = int(d.get("total_broken", 0))
	taps = int(d.get("taps", 0))
	best_group = int(d.get("best_group", 0))
	last_seen = int(d.get("last_seen", 0))
	var saved_levels: Dictionary = d.get("levels", {})
	for k in levels.keys():
		levels[k] = clamp(int(saved_levels.get(k, 0)), 0, UPGRADES[k]["max"])


func save_game() -> void:
	_save_pending = false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Не удалось сохранить: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(to_dict()))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		from_dict(parsed)


func _apply_offline() -> void:
	if last_seen <= 0:
		return
	var now := int(Time.get_unix_time_from_system())
	var dt: int = clamp(now - last_seen, 0, OFFLINE_CAP_SEC)
	# Оффлайн авто-молот работает вполсилы.
	var earned := int(auto_rate_per_sec() * dt * 0.5)
	if earned > 0:
		pending_offline_reward = earned
		pending_offline_seconds = dt
		add_coins(earned)


func _mark_dirty() -> void:
	if _save_pending or not is_inside_tree():
		return
	_save_pending = true
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if _save_pending:
			save_game()
	)
