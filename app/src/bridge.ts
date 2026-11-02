/**
 * Контракт сообщений между React Native и Godot.
 * Godot-сторона: godot/scripts/bridge.gd (singleton "ReactNative" из react-native-godot).
 */

export type UpgradeId = 'value' | 'combo' | 'gold' | 'auto' | 'kinds';

export interface UpgradeInfo {
  id: UpgradeId;
  name: string;
  desc: string;
  level: number;
  max: number;
  cost: number;
  can_buy: boolean;
}

export interface GameState {
  coins: number;
  total_coins: number;
  total_broken: number;
  taps: number;
  best_group: number;
  per_tile: number;
  combo_bonus: number;
  gold_chance: number;
  auto_interval: number;
  kinds: number;
  upgrades: UpgradeInfo[];
}

/** Godot -> React Native */
export type GodotMessage =
  | ({ type: 'ready' } & GameState)
  | ({ type: 'state' } & GameState)
  | {
      type: 'break';
      count: number;
      shape: 'circle' | 'square' | 'triangle' | 'diamond' | 'star' | 'hexagon';
      gold: number;
      coins: number;
      by_player: boolean;
    }
  | { type: 'upgrade_result'; id: UpgradeId; ok: boolean; level: number }
  | { type: 'shuffle' }
  | { type: 'offline'; coins: number; seconds: number };

/** React Native -> Godot */
export type RnMessage =
  | { type: 'get_state' }
  | { type: 'buy_upgrade'; id: UpgradeId }
  | { type: 'set_hud'; visible: boolean }
  | { type: 'reset' }
  | { type: 'toast'; text: string };

export const EMPTY_STATE: GameState = {
  coins: 0,
  total_coins: 0,
  total_broken: 0,
  taps: 0,
  best_group: 0,
  per_tile: 1,
  combo_bonus: 0,
  gold_chance: 0,
  auto_interval: 0,
  kinds: 6,
  upgrades: [],
};

export function isGodotMessage(value: unknown): value is GodotMessage {
  return (
    typeof value === 'object' &&
    value !== null &&
    typeof (value as { type?: unknown }).type === 'string'
  );
}

export function formatCoins(n: number): string {
  if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(2)}B`;
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
  if (n >= 10_000) return `${(n / 1_000).toFixed(1)}K`;
  return String(n);
}
