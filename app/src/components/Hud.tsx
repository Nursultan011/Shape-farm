import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { GameState, formatCoins } from '../bridge';
import { colors } from '../theme';

interface Props {
  state: GameState;
  ready: boolean;
  onOpenShop: () => void;
}

/** Верхняя и нижняя панели поверх Godot-поля. */
export function Hud({ state, ready, onOpenShop }: Props) {
  const income: string[] = [`+${state.per_tile} за фигурку`];
  if (state.combo_bonus > 0) income.push(`комбо +${state.combo_bonus}`);
  if (state.auto_interval > 0) income.push(`авто ${state.auto_interval.toFixed(1)}с`);

  return (
    <>
      <View pointerEvents="none" style={styles.top}>
        <Text style={styles.title}>SHAPE FARM</Text>
        <Text style={styles.coins}>{ready ? formatCoins(state.coins) : '…'}</Text>
        <Text style={styles.income}>{income.join('  ·  ')}</Text>
      </View>

      <View style={styles.bottom}>
        <Text style={styles.stats}>
          Разбито: {formatCoins(state.total_broken)}   ·   Лучшая группа: {state.best_group}   ·   Видов:{' '}
          {state.kinds}
        </Text>
        <Pressable
          onPress={onOpenShop}
          disabled={!ready}
          style={({ pressed }) => [styles.shopButton, pressed && styles.pressed, !ready && styles.disabled]}
        >
          <Text style={styles.shopText}>🛒  Улучшения</Text>
        </Pressable>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  top: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    alignItems: 'center',
    paddingTop: 12,
  },
  title: { color: 'rgba(255,255,255,0.45)', fontSize: 13, letterSpacing: 3, fontWeight: '700' },
  coins: { color: colors.gold, fontSize: 44, fontWeight: '800', marginTop: 2 },
  income: { color: 'rgba(255,255,255,0.75)', fontSize: 14, marginTop: 2 },
  bottom: {
    position: 'absolute',
    bottom: 0,
    left: 20,
    right: 20,
    gap: 10,
    paddingBottom: 8,
  },
  stats: { color: colors.textDim, fontSize: 12, textAlign: 'center' },
  shopButton: {
    backgroundColor: colors.accent,
    borderRadius: 16,
    paddingVertical: 14,
    alignItems: 'center',
  },
  shopText: { color: '#fff', fontSize: 18, fontWeight: '700' },
  pressed: { opacity: 0.8 },
  disabled: { opacity: 0.4 },
});
