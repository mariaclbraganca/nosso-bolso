import 'package:flutter/material.dart';

// Chave global para navegar sem BuildContext (usada por notificações).
final navigatorKey = GlobalKey<NavigatorState>();

// Chave global do ScaffoldMessenger — permite mostrar SnackBar sem depender
// do BuildContext de um sheet que já foi fechado (evita erro de árvore).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Índices da barra de Finanças: Início, Envelopes, [+], Contas e Mais.
const int navHome = 0;
const int navPlanos = 1;
const int navContas = 2;

/// Lugares que outras partes do app (notificações, atalhos do Início) abrem,
/// trocando de módulo se preciso.
enum Destino { modulos, financas, envelopes, contas, extrato, compras, alimentacao, jejum, exercicios }

void Function(Destino)? _abrir;

void registrarDestinos(void Function(Destino) cb) => _abrir = cb;
void cancelarDestinos() => _abrir = null;

/// Abre [d] (no módulo certo). Sem o app montado, não faz nada.
void abrirDestino(Destino d) => _abrir?.call(d);

/// Atalho para as abas de Finanças.
void navegarParaAba(int index) => abrirDestino(switch (index) {
      navPlanos => Destino.envelopes,
      navContas => Destino.contas,
      _ => Destino.financas,
    });
