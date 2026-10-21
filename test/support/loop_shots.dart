import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _loaded = false;

Future<void> _loadFonts() async {
  if (_loaded) return;
  _loaded = true;
  const families = <String, List<String>>{
    'Anton': <String>['assets/fonts/Anton-Regular.ttf'],
    'Arimo': <String>[
      'assets/fonts/Arimo-Regular.ttf',
      'assets/fonts/Arimo-Bold.ttf',
    ],
    'Noto Sans SC Display': <String>['assets/fonts/NotoSansSC-Bold.ttf'],
    'Noto Sans SC': <String>[
      'assets/fonts/NotoSansSC-Regular.ttf',
      'assets/fonts/NotoSansSC-Bold.ttf',
    ],
    'IBM Plex Mono': <String>[
      'assets/fonts/IBMPlexMono-Regular.ttf',
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// S241b-G1 visual check only: writes the current frame to
/// docs/integration/S241b-G1/shots/`name`.png, in slices of [slice] logical
/// pixels so a tall page stays readable.
Future<void> loopShot(
  WidgetTester tester,
  String name, {
  double slice = 900,
  String dir = 'docs/integration/S241b-G1/shots',
}) async {
  await tester.runAsync(_loadFonts);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    var index = 0;
    for (var top = 0.0; top < h; top += slice) {
      final height = (h - top) < slice ? h - top : slice;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        Rect.fromLTWH(0, top, w, height),
        Rect.fromLTWH(0, 0, w, height),
        Paint(),
      );
      final part = await recorder.endRecording().toImage(
        w.toInt(),
        height.toInt(),
      );
      final bytes = await part.toByteData(format: ui.ImageByteFormat.png);
      final suffix = h <= slice ? '' : '-${index + 1}';
      File('${Directory.current.path}/$dir/$name$suffix.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
      index += 1;
    }
  });
}
