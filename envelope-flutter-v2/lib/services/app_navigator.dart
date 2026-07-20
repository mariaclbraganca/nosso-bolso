import 'package:flutter/material.dart';

// Chave global para navegar sem BuildContext (usada por notificações).
final navigatorKey = GlobalKey<NavigatorState>();

// Chave global do ScaffoldMessenger — permite mostrar SnackBar sem depender
// do BuildContext de um sheet que já foi fechado (evita erro de árvore).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Índices do IndexedStack do MainNavigationScreen
const int navHome     = 0;
const int navExtrato  = 1;
const int navPlanos   = 2;
const int navVida     = 3;

void navegarParaAba(int index) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  // Emite um evento que o MainNavigationScreen ouve
  _PendingNavigation._instance?.navegarPara(index);
}

// Notifier simples — MainNavigationScreen registra o callback no initState
class _PendingNavigation {
  static _PendingNavigation? _instance;
  void Function(int)? _callback;

  static void register(void Function(int) cb) {
    _instance ??= _PendingNavigation();
    _instance!._callback = cb;
  }

  static void unregister() {
    _instance?._callback = null;
  }

  void navegarPara(int index) => _callback?.call(index);
}

void registerNavCallback(void Function(int) cb) => _PendingNavigation.register(cb);
void unregisterNavCallback() => _PendingNavigation.unregister();
