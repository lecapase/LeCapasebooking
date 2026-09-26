import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/widgets/booking_card_heading.dart';

void main() {
  setUpAll(() async {
    final fontPath = Platform.environment['BOOKING_PREVIEW_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('Roboto');
      loader.addFont(
        File(
          fontPath,
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });
  testWidgets('covers stay at the right edge for long names and larger text', (
    tester,
  ) async {
    for (final width in [240.0, 360.0, 800.0]) {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: width,
                    child: const BookingCardHeading(
                      name:
                          'Un nome e cognome estremamente lungo che deve essere troncato',
                      guests: 19,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.text('19p')).right, closeTo(width, 0.01));
        expect(find.byIcon(Icons.person_outline), findsNothing);
        final name = tester.widget<Text>(
          find.text(
            'Un nome e cognome estremamente lungo che deve essere troncato',
          ),
        );
        expect(name.overflow, TextOverflow.ellipsis);
      }
    }
  });

  testWidgets('different cover counts share the same right edge', (
    tester,
  ) async {
    const boundaryKey = ValueKey('preview');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                width: 360,
                color: const Color(0xFF111111),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in {
                      'Camille Zuliani': 2,
                      'Antonio Ancona': 19,
                      'Un nome e cognome molto lungo da visualizzare': 100,
                    }.entries)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF191919),
                          border: Border.all(color: const Color(0xFFC8A45D)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: BookingCardHeading(
                          name: entry.key,
                          guests: entry.value,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final edge = tester.getRect(find.text('2p')).right;
    expect(tester.getRect(find.text('19p')).right, edge);
    expect(tester.getRect(find.text('100p')).right, edge);
    final preview = Platform.environment['BOOKING_HEADING_PREVIEW'];
    if (preview != null) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
