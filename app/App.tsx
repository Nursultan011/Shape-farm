/**
 * Shape Farm — фармилка на Godot внутри React Native.
 * Игра (поле, фигурки, экономика) живёт в ../godot, здесь — оболочка приложения.
 */

import React from 'react';
import { StatusBar } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GodotProvider } from 'react-native-godot';
import { GameScreen } from './src/GameScreen';

function App() {
  return (
    <GodotProvider>
      <SafeAreaProvider>
        <StatusBar barStyle="light-content" />
        <GameScreen />
      </SafeAreaProvider>
    </GodotProvider>
  );
}

export default App;
