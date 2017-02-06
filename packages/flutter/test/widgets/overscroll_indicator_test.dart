// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../rendering/mock_canvas.dart';
import 'test_widgets.dart';

final Matcher doesNotOverscroll = isNot(paints..circle());

Future<Null> slowDrag(WidgetTester tester, Point start, Offset offset) async {
  TestGesture gesture = await tester.startGesture(start);
  for (int index = 0; index < 10; index += 1) {
    await gesture.moveBy(offset);
    await tester.pump(const Duration(milliseconds: 20));
  }
  await gesture.up();
}

void main() {
  testWidgets('Overscroll indicator color', (WidgetTester tester) async {
    await tester.pumpWidget(
      new TestScrollable(
        slivers: <Widget>[
          new SliverToBoxAdapter(child: new SizedBox(height: 2000.0)),
        ],
      ),
    );
    RenderObject painter = tester.renderObject(find.byType(CustomPaint));

    expect(painter, doesNotOverscroll);

    // the scroll gesture from tester.scroll happens in zero time, so nothing should appear:
    await tester.scroll(find.byType(Scrollable2), const Offset(0.0, 100.0));
    expect(painter, doesNotOverscroll);
    await tester.pump(); // allow the ticker to register itself
    expect(painter, doesNotOverscroll);
    await tester.pump(const Duration(milliseconds: 100)); // animate
    expect(painter, doesNotOverscroll);

    TestGesture gesture = await tester.startGesture(const Point(200.0, 200.0));
    await tester.pump(const Duration(milliseconds: 100)); // animate
    expect(painter, doesNotOverscroll);
    await gesture.up();
    expect(painter, doesNotOverscroll);

    await slowDrag(tester, const Point(200.0, 200.0), const Offset(0.0, 5.0));
    expect(painter, paints..circle(color: const Color(0x0DFFFFFF)));

    await tester.pumpUntilNoTransientCallbacks(const Duration(seconds: 1));
    expect(painter, doesNotOverscroll);
  });

  testWidgets('Overscroll indicator changes side when you drag on the other side', (WidgetTester tester) async {
    await tester.pumpWidget(
      new TestScrollable(
        slivers: <Widget>[
          new SliverToBoxAdapter(child: new SizedBox(height: 2000.0)),
        ],
      ),
    );
    RenderObject painter = tester.renderObject(find.byType(CustomPaint));

    await slowDrag(tester, const Point(400.0, 200.0), const Offset(0.0, 10.0));
    expect(painter, paints..circle(x: 400.0));
    await slowDrag(tester, const Point(100.0, 200.0), const Offset(0.0, 10.0));
    expect(painter, paints..something((Symbol method, List<dynamic> arguments) {
      if (method != #drawCircle)
        return false;
      final Point center = arguments[0];
      if (center.x < 400.0)
        return true;
      throw 'Dragging on left hand side did not overscroll on left hand side.';
    }));
    await slowDrag(tester, const Point(700.0, 200.0), const Offset(0.0, 10.0));
    expect(painter, paints..something((Symbol method, List<dynamic> arguments) {
      if (method != #drawCircle)
        return false;
      final Point center = arguments[0];
      if (center.x > 400.0)
        return true;
      throw 'Dragging on right hand side did not overscroll on right hand side.';
    }));

    await tester.pumpUntilNoTransientCallbacks(const Duration(seconds: 1));
    expect(painter, doesNotOverscroll);
  });

  testWidgets('Overscroll indicator changes side when you shift sides', (WidgetTester tester) async {
    await tester.pumpWidget(
      new TestScrollable(
        slivers: <Widget>[
          new SliverToBoxAdapter(child: new SizedBox(height: 2000.0)),
        ],
      ),
    );
    RenderObject painter = tester.renderObject(find.byType(CustomPaint));
    TestGesture gesture = await tester.startGesture(const Point(300.0, 200.0));
    await gesture.moveBy(const Offset(0.0, 10.0));
    await tester.pump(const Duration(milliseconds: 20));
    double oldX = 0.0;
    for (int index = 0; index < 10; index += 1) {
      await gesture.moveBy(const Offset(50.0, 50.0));
      await tester.pump(const Duration(milliseconds: 20));
      expect(painter, paints..something((Symbol method, List<dynamic> arguments) {
        if (method != #drawCircle)
          return false;
        final Point center = arguments[0];
        if (center.x <= oldX)
          throw 'Sliding to the right did not make the center of the radius slide to the right.';
        oldX = center.x;
        return true;
      }));
    }
    await gesture.up();

    await tester.pumpUntilNoTransientCallbacks(const Duration(seconds: 1));
    expect(painter, doesNotOverscroll);
  });

  group('Flipping direction of scrollable doesn\'t change overscroll behavior', () {
    testWidgets('down', (WidgetTester tester) async {
      await tester.pumpWidget(
        new TestScrollable(
          axisDirection: AxisDirection.down,
          slivers: <Widget>[
            new SliverToBoxAdapter(child: new SizedBox(height: 20.0)),
          ],
        ),
      );
      RenderObject painter = tester.renderObject(find.byType(CustomPaint));
      await slowDrag(tester, const Point(200.0, 200.0), const Offset(0.0, 5.0));
      expect(painter, paints..save()..circle()..restore()..save()..scale(y: -1.0)..restore()..restore());

      await tester.pumpUntilNoTransientCallbacks(const Duration(seconds: 1));
      expect(painter, doesNotOverscroll);
    });

    testWidgets('up', (WidgetTester tester) async {
      await tester.pumpWidget(
        new TestScrollable(
          axisDirection: AxisDirection.up,
          slivers: <Widget>[
            new SliverToBoxAdapter(child: new SizedBox(height: 20.0)),
          ],
        ),
      );
      RenderObject painter = tester.renderObject(find.byType(CustomPaint));
      await slowDrag(tester, const Point(200.0, 200.0), const Offset(0.0, 5.0));
      expect(painter, paints..save()..scale(y: -1.0)..restore()..save()..circle()..restore()..restore());

      await tester.pumpUntilNoTransientCallbacks(const Duration(seconds: 1));
      expect(painter, doesNotOverscroll);
    });
  });

  testWidgets('Overscroll in both directions', (WidgetTester tester) async {
    await tester.pumpWidget(
      new TestScrollable(
        axisDirection: AxisDirection.down,
        slivers: <Widget>[
          new SliverToBoxAdapter(child: new SizedBox(height: 20.0)),
        ],
      ),
    );
    RenderObject painter = tester.renderObject(find.byType(CustomPaint));
    await slowDrag(tester, const Point(200.0, 200.0), const Offset(0.0, 5.0));
    expect(painter, paints..circle());
    expect(painter, isNot(paints..circle()..circle()));
    await slowDrag(tester, const Point(200.0, 200.0), const Offset(0.0, -5.0));
    expect(painter, paints..circle()..circle());

    await tester.pumpUntilNoTransientCallbacks(const Duration(seconds: 1));
    expect(painter, doesNotOverscroll);
  });

  testWidgets('Overscroll horizontally', (WidgetTester tester) async {
    await tester.pumpWidget(
      new TestScrollable(
        axisDirection: AxisDirection.right,
        slivers: <Widget>[
          new SliverToBoxAdapter(child: new SizedBox(height: 20.0)),
        ],
      ),
    );
    RenderObject painter = tester.renderObject(find.byType(CustomPaint));
    await slowDrag(tester, const Point(200.0, 200.0), const Offset(5.0, 0.0));
    expect(painter, paints..rotate(angle: -math.PI / 2.0)..circle()..scale(y: -1.0));
    expect(painter, isNot(paints..circle()..circle()));
    await slowDrag(tester, const Point(200.0, 200.0), const Offset(-5.0, 0.0));
    expect(painter, paints..rotate(angle: -math.PI / 2.0)..circle()
                          ..rotate(angle: -math.PI / 2.0)..scale(y: -1.0)..circle());

    await tester.pumpUntilNoTransientCallbacks(const Duration(seconds: 1));
    expect(painter, doesNotOverscroll);
  });

  testWidgets('Changing settings', (WidgetTester tester) async {
    RenderObject painter;

    await tester.pumpWidget(
      new ScrollConfiguration2(
        behavior: new TestScrollBehavior1(),
        child: new TestScrollable(
          axisDirection: AxisDirection.left,
          slivers: <Widget>[
            new SliverToBoxAdapter(child: new SizedBox(height: 20.0)),
          ],
        ),
      ),
    );
    painter = tester.renderObject(find.byType(CustomPaint));
    await slowDrag(tester, const Point(200.0, 200.0), const Offset(5.0, 0.0));
    expect(painter, paints..scale(y: -1.0)..rotate(angle: -math.PI / 2.0)..circle(color: const Color(0x0A00FF00)));
    expect(painter, isNot(paints..circle()..circle()));

    await tester.pumpUntilNoTransientCallbacks(const Duration(seconds: 1));
    await tester.pumpWidget(
      new ScrollConfiguration2(
        behavior: new TestScrollBehavior2(),
        child: new TestScrollable(
          axisDirection: AxisDirection.right,
          slivers: <Widget>[
            new SliverToBoxAdapter(child: new SizedBox(height: 20.0)),
          ],
        ),
      ),
    );
    painter = tester.renderObject(find.byType(CustomPaint));
    await slowDrag(tester, const Point(200.0, 200.0), const Offset(5.0, 0.0));
    expect(painter, paints..rotate(angle: -math.PI / 2.0)..circle(color: const Color(0x0A0000FF))..scale(y: -1.0));
    expect(painter, isNot(paints..circle()..circle()));
  });
}

class TestScrollBehavior1 extends ScrollBehavior2 {
  @override
  Color getGlowColor(BuildContext context) {
    return const Color(0xFF00FF00);
  }
}

class TestScrollBehavior2 extends ScrollBehavior2 {
  @override
  Color getGlowColor(BuildContext context) {
    return const Color(0xFF0000FF);
  }
}
