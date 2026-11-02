#!/usr/bin/env bash
# Собирает godot/ в app/assets/game.pck.
# react-native-godot 0.0.x собран на Godot 4.5 — .pck должен быть экспортирован тем же мажором/минором,
# иначе движок внутри приложения его не прочитает. Путь к нужному бинарнику можно задать через GODOT_BIN.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(cd "$HERE/.." && pwd)"
GODOT_DIR="$(cd "$APP_DIR/../godot" && pwd)"
OUT="$APP_DIR/assets/game.pck"
GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot не найден. Укажи путь: GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot $0" >&2
  exit 1
fi

VERSION="$("$GODOT_BIN" --version | head -1)"
echo "Godot: $VERSION"
case "$VERSION" in
  4.5.*) ;;
  *) echo "ВНИМАНИЕ: react-native-godot ожидает Godot 4.5.x, а у тебя $VERSION. .pck может не загрузиться в приложении." >&2 ;;
esac

mkdir -p "$APP_DIR/assets"
echo "Импорт ресурсов…"
"$GODOT_BIN" --headless --path "$GODOT_DIR" --import >/dev/null 2>&1 || true
echo "Экспорт .pck → $OUT"
"$GODOT_BIN" --headless --path "$GODOT_DIR" --export-pack "iOS" "$OUT"
cp "$GODOT_DIR/project.godot" "$APP_DIR/assets/project.godot"
ls -la "$OUT"
echo "Готово. Не забудь добавить assets/project.godot в бандл Xcode (Copy Bundle Resources)."
