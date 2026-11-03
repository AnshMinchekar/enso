import 'dart:io';

import 'package:enso/engine/parser.dart';
import 'package:enso/ui/app.dart';
import 'package:enso/ui/app_state.dart';
import 'package:enso/ui/widgets/screen_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime at(int h, int m) => DateTime(2026, 10, 26, h, m);

void main() {
  testWidgets('glass on the background draws the pre-blurred artwork; sheets blur live', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var now = at(6, 15);
    final schedule = parseSchedule(File('test/fixtures/sample.md').readAsStringSync()).schedule!;
    final state = AppState(clock: () => now, initialSchedule: schedule);
    await tester.pumpWidget(EnsoApp(state: state));
    state.buildDay(wake: at(6, 15), dayTypes: {'gym'}, errands: const []);
    now = at(11, 0);
    state.tick();
    await tester.pumpAndSettle();

    // Hero card glass and the bottom fade use screen-aligned images, and no
    // live blur runs while the day is on screen.
    final glassImages = find.byWidgetPredicate(
      (w) => w is ScreenImage && w.asset.endsWith('morning_glass.webp'),
    );
    expect(glassImages, findsWidgets);
    expect(find.byType(BackdropFilter), findsNothing);

    // The block sheet blurs what is really behind it.
    await tester.tap(find.text('Deep work').first);
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsWidgets);
  });
}
