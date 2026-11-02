import React, { useCallback, useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { GodotView, GodotViewRef } from 'react-native-godot';
import { EMPTY_STATE, GameState, GodotMessage, RnMessage, UpgradeId, isGodotMessage } from './bridge';
import { Hud } from './components/Hud';
import { ShopModal } from './components/ShopModal';
import { colors, shapeColors } from './theme';

// .pck собирается из ../godot скриптом `npm run pck` (scripts/gen-pck.sh).
const GAME_PCK = require('../assets/game.pck');
const MAIN_SCENE = 'res://scenes/main.tscn';

interface Toast {
  id: number;
  text: string;
  color: string;
}

/**
 * Экран игры: Godot рисует поле и обрабатывает тапы, React Native — HUD и магазин.
 * Состояние (монеты, улучшения) живёт в Godot и приходит сообщениями "state".
 */
export function GameScreen() {
  const insets = useSafeAreaInsets();
  const godot = useRef<GodotViewRef>(null);
  const [ready, setReady] = useState(false);
  const [state, setState] = useState<GameState>(EMPTY_STATE);
  const [shopOpen, setShopOpen] = useState(false);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const toastId = useRef(0);

  const send = useCallback((msg: RnMessage) => {
    godot.current?.emitMessage(msg);
  }, []);

  const pushToast = useCallback((text: string, color: string = colors.gold) => {
    const id = ++toastId.current;
    setToasts(prev => [...prev.slice(-3), { id, text, color }]);
    setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 1400);
  }, []);

  const onMessage = useCallback(
    (_instance: unknown, raw: unknown) => {
      if (!isGodotMessage(raw)) return;
      const msg: GodotMessage = raw;
      switch (msg.type) {
        case 'ready':
        case 'state': {
          const { type: _type, ...rest } = msg;
          setState(rest as GameState);
          if (msg.type === 'ready') {
            setReady(true);
            // HUD рисуем в React Native, внутренний HUD Godot скрываем.
            godot.current?.emitMessage({ type: 'set_hud', visible: false } satisfies RnMessage);
          }
          break;
        }
        case 'break':
          if (msg.count >= 5) {
            pushToast(`+${msg.coins}  группа ×${msg.count}${msg.gold ? ' ✨' : ''}`, shapeColors[msg.shape] ?? colors.gold);
          }
          break;
        case 'upgrade_result':
          if (!msg.ok) pushToast('Недостаточно монет', colors.danger);
          break;
        case 'shuffle':
          pushToast('Ходов нет — перемешиваем!', colors.text);
          break;
        case 'offline':
          pushToast(`Пока вас не было: +${msg.coins} 🪙`);
          break;
      }
    },
    [pushToast],
  );

  useEffect(() => {
    GodotView.startDrawing();
    return () => GodotView.stopDrawing();
  }, []);

  const buy = useCallback((id: UpgradeId) => send({ type: 'buy_upgrade', id }), [send]);

  return (
    <View style={[styles.root, { paddingTop: insets.top, paddingBottom: insets.bottom }]}>
      <GodotView
        ref={godot}
        style={styles.godot}
        source={GAME_PCK}
        scene={MAIN_SCENE}
        onMessage={onMessage}
        onReady={() => send({ type: 'get_state' })}
      />

      <Hud state={state} ready={ready} onOpenShop={() => setShopOpen(true)} />

      <View pointerEvents="none" style={styles.toasts}>
        {toasts.map(t => (
          <Text key={t.id} style={[styles.toast, { color: t.color }]}>
            {t.text}
          </Text>
        ))}
      </View>

      <ShopModal visible={shopOpen} state={state} onBuy={buy} onClose={() => setShopOpen(false)} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  godot: { flex: 1 },
  toasts: {
    position: 'absolute',
    top: '18%',
    left: 0,
    right: 0,
    alignItems: 'center',
    gap: 6,
  },
  toast: {
    fontSize: 20,
    fontWeight: '800',
    textShadowColor: 'rgba(0,0,0,0.6)',
    textShadowRadius: 6,
  },
});
