import { formatCoins, isGodotMessage } from '../src/bridge';

describe('bridge helpers', () => {
  test('formatCoins', () => {
    expect(formatCoins(0)).toBe('0');
    expect(formatCoins(9999)).toBe('9999');
    expect(formatCoins(12_345)).toBe('12.3K');
    expect(formatCoins(2_500_000)).toBe('2.50M');
    expect(formatCoins(3_000_000_000)).toBe('3.00B');
  });

  test('isGodotMessage accepts only objects with a string type', () => {
    expect(isGodotMessage({ type: 'state', coins: 1 })).toBe(true);
    expect(isGodotMessage({ coins: 1 })).toBe(false);
    expect(isGodotMessage(null)).toBe(false);
    expect(isGodotMessage('state')).toBe(false);
  });
});
