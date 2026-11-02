# Shape Farm — фармилка на Godot внутри React Native

Тапаешь по группе из 2+ одинаковых соседних фигурок — они разбиваются, падают новые, капают монеты.
Монеты тратятся на улучшения: ценность фигурки, комбо, золотые фигурки (x5), авто-молот (idle-доход,
работает и оффлайн), уменьшение числа видов фигурок. Прогресс сохраняется.

```
shape-farm/
├── godot/        Игра на Godot 4 (GDScript). Запускается и сама по себе.
│   ├── scenes/main.tscn
│   ├── scripts/
│   │   ├── board_logic.gd   чистая логика поля (группы, гравитация, перемешивание) — покрыта тестами
│   │   ├── board.gd         узел поля: ввод, анимации, авто-молот
│   │   ├── tile.gd          фигурка (рисуется процедурно, без текстур)
│   │   ├── game.gd          autoload Game: монеты, улучшения, сохранение, оффлайн-доход
│   │   ├── bridge.gd        autoload Bridge: мост к React Native
│   │   ├── hud.gd           встроенный HUD/магазин (скрывается, когда HUD рисует RN)
│   │   └── main.gd
│   ├── tests/               headless-тесты
│   └── export_presets.cfg   пресет iOS для сборки .pck
└── app/          React Native 0.88 (bare). Встраивает Godot через react-native-godot.
    ├── App.tsx
    ├── src/GameScreen.tsx         GodotView + HUD + магазин
    ├── src/bridge.ts              типы сообщений Godot <-> RN
    ├── src/components/            Hud.tsx, ShopModal.tsx
    ├── scripts/gen-pck.sh         собирает godot/ -> app/assets/game.pck
    └── assets/game.pck            (генерируется, в git не хранится)
```

## 1. Запустить игру отдельно в Godot

1. Открыть папку `godot/` в Godot 4.5+ (Project → Import).
2. Нажать F5. Мышь эмулирует тап.

Тесты (без окна):

```bash
godot --headless --path godot --script tests/test_board_logic.gd
```

```bash
godot --headless --path godot tests/smoke_scene.tscn --quit-after 600
```

Второй тест загружает реальную сцену, разбивает группы напрямую и через событие тапа,
покупает улучшения и проверяет, что поле сходится с логикой. **Он сбрасывает сохранение.**
Со `SHAPE_FARM_SCREENSHOT=/path/shot.png` и без `--headless` он ещё и сохраняет скриншот.

## 1a. Запустить в браузере

В `export_presets.cfg` есть пресет **Web** (без потоков, поэтому не нужны COOP/COEP-заголовки).
Нужны установленные шаблоны экспорта для твоей версии Godot.

```bash
godot --headless --path godot --export-release "Web" godot/export/web/index.html
```

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory godot/export/web
```

Открыть http://127.0.0.1:8765/index.html. Папка `godot/export/` в git не хранится.

## 2. Запустить внутри React Native (iOS)

Требования [react-native-godot](https://github.com/calico-games/react-native-godot) 0.0.13:
**Godot 4.5.x** для экспорта .pck, React Native ≥ 0.78, iOS 15.1+, **только реальное устройство**
(iOS Simulator не поддерживается, Android «скоро»).

```bash
cd app && npm install
```

Собрать .pck (укажи бинарник Godot 4.5, если по умолчанию стоит другая версия):

```bash
GODOT_BIN=/Applications/Godot45.app/Contents/MacOS/Godot npm run pck
```

Установить поды и собрать на устройство:

```bash
cd ios && pod install && cd .. && npx react-native run-ios --device
```

Один ручной шаг: в Xcode перетащить `app/assets/project.godot` в проект ShapeFarm
(галочка Copy Bundle Resources) — библиотека читает его из бандла при старте движка.

Проверить TypeScript и Jest:

```bash
npm run typecheck && npm test
```

## Протокол сообщений Godot ↔ React Native

Godot-сторона — `godot/scripts/bridge.gd`, RN — `app/src/bridge.ts`.

| Направление | type | Поля |
|---|---|---|
| Godot → RN | `ready`, `state` | coins, total_coins, total_broken, taps, best_group, per_tile, combo_bonus, gold_chance, auto_interval, kinds, upgrades[] |
| Godot → RN | `break` | count, shape, gold, coins, by_player |
| Godot → RN | `upgrade_result` | id, ok, level |
| Godot → RN | `shuffle`, `offline` | — / coins, seconds |
| RN → Godot | `get_state` | — |
| RN → Godot | `buy_upgrade` | id: value, combo, gold, auto, kinds |
| RN → Godot | `set_hud` | visible — скрыть встроенный HUD Godot, когда HUD рисует RN |
| RN → Godot | `reset`, `toast` | — / text |

Экономика живёт в Godot: RN только отправляет команды и отрисовывает присланное состояние,
поэтому игра одинаково работает и без оболочки.

## Экономика

| Улучшение | Эффект | Базовая цена | Рост |
|---|---|---|---|
| Ценность | +1 монета за фигурку | 25 | ×1.55 |
| Комбо | +1 монета за каждую фигурку сверх двух | 60 | ×1.65 |
| Золото | +1% шанс золотой фигурки (x5) | 150 | ×1.5 |
| Авто-молот | сам разбивает группу раз в 6с → быстрее с уровнем (мин. 0.8с); оффлайн вполсилы, до 8 ч | 200 | ×1.8 |
| Меньше видов | 6 → 3 видов фигурок, группы крупнее | 800 | ×4 |

Награда за группу: `count × per_tile + (count − 2) × combo + gold × per_tile × 4`.
Если ходов нет, поле перемешивается — фарм никогда не останавливается.
