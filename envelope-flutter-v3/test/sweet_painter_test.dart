import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/unicorn_team.dart';
import 'package:nosso_bolso_v3/ui/unicorn/sweet_painter.dart';

void main() {
  test('SweetPainter paint executa sem excecoes', () {
    final painter = SweetPainter(
      mood: UnicornMood.love,
      t: 0.5,
      blink: 0.0,
      tailWag: 0.2,
      sparkle: 0.5,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(40, 46.4));
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
  });
}
