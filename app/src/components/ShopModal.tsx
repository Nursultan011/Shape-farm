import React from 'react';
import { Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { GameState, UpgradeId, formatCoins } from '../bridge';
import { colors } from '../theme';

interface Props {
  visible: boolean;
  state: GameState;
  onBuy: (id: UpgradeId) => void;
  onClose: () => void;
}

/** Магазин улучшений. Покупка отправляется в Godot, состояние приходит обратно сообщением "state". */
export function ShopModal({ visible, state, onBuy, onClose }: Props) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <View style={styles.panel}>
          <Text style={styles.header}>Улучшения</Text>
          <Text style={styles.balance}>Баланс: {formatCoins(state.coins)} 🪙</Text>

          <ScrollView style={styles.list} contentContainerStyle={{ gap: 12 }}>
            {state.upgrades.map(u => {
              const maxed = u.level >= u.max;
              return (
                <View key={u.id} style={styles.row}>
                  <View style={styles.rowText}>
                    <Text style={styles.name}>
                      {u.name} <Text style={styles.level}>ур. {u.level}/{u.max}</Text>
                    </Text>
                    <Text style={styles.desc}>{u.desc}</Text>
                  </View>
                  <Pressable
                    disabled={maxed || !u.can_buy}
                    onPress={() => onBuy(u.id)}
                    style={({ pressed }) => [
                      styles.buy,
                      maxed && styles.buyMaxed,
                      !maxed && !u.can_buy && styles.buyDisabled,
                      pressed && styles.pressed,
                    ]}
                  >
                    <Text style={styles.buyText}>{maxed ? 'MAX' : `${formatCoins(u.cost)} 🪙`}</Text>
                  </Pressable>
                </View>
              );
            })}
          </ScrollView>

          <Pressable onPress={onClose} style={({ pressed }) => [styles.close, pressed && styles.pressed]}>
            <Text style={styles.closeText}>Закрыть</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    padding: 20,
  },
  panel: {
    backgroundColor: colors.panel,
    borderRadius: 24,
    padding: 20,
    maxHeight: '85%',
    borderWidth: 1,
    borderColor: colors.panelBorder,
  },
  header: { color: colors.text, fontSize: 26, fontWeight: '800', textAlign: 'center' },
  balance: { color: colors.gold, fontSize: 16, textAlign: 'center', marginTop: 4, marginBottom: 14 },
  list: { flexGrow: 0 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderRadius: 16,
    padding: 12,
  },
  rowText: { flex: 1 },
  name: { color: colors.text, fontSize: 17, fontWeight: '700' },
  level: { color: colors.textDim, fontSize: 13, fontWeight: '500' },
  desc: { color: colors.textDim, fontSize: 13, marginTop: 2 },
  buy: {
    backgroundColor: colors.success,
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    minWidth: 104,
    alignItems: 'center',
  },
  buyDisabled: { backgroundColor: 'rgba(255,255,255,0.12)' },
  buyMaxed: { backgroundColor: colors.gold },
  buyText: { color: '#10142a', fontWeight: '800', fontSize: 14 },
  close: {
    marginTop: 16,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 14,
    paddingVertical: 12,
    alignItems: 'center',
  },
  closeText: { color: colors.text, fontSize: 16, fontWeight: '600' },
  pressed: { opacity: 0.8 },
});
