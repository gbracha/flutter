// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';

import 'gesture_tester.dart';

class TestDrag extends Drag {
}

void main() {
  setUp(ensureGestureBinding);

  testGesture('Should recognize pan', (GestureTester tester) {
    MultiTapGestureRecognizer tap = new MultiTapGestureRecognizer(longTapDelay: kLongPressTimeout);

    List<String> log = <String>[];

    tap.onTapDown = (int pointer, TapDownDetails details) { log.add('tap-down $pointer'); };
    tap.onTapUp = (int pointer, TapUpDetails details) { log.add('tap-up $pointer'); };
    tap.onTap = (int pointer) { log.add('tap $pointer'); };
    tap.onLongTapDown = (int pointer, TapDownDetails details) { log.add('long-tap-down $pointer'); };
    tap.onTapCancel = (int pointer) { log.add('tap-cancel $pointer'); };


    TestPointer pointer5 = new TestPointer(5);
    PointerDownEvent down5 = pointer5.down(const Point(10.0, 10.0));
    tap.addPointer(down5);
    tester.closeArena(5);
    expect(log, <String>['tap-down 5']);
    log.clear();
    tester.route(down5);
    expect(log, isEmpty);

    TestPointer pointer6 = new TestPointer(6);
    PointerDownEvent down6 = pointer6.down(const Point(15.0, 15.0));
    tap.addPointer(down6);
    tester.closeArena(6);
    expect(log, <String>['tap-down 6']);
    log.clear();
    tester.route(down6);
    expect(log, isEmpty);

    tester.route(pointer5.move(const Point(11.0, 12.0)));
    expect(log, isEmpty);

    tester.route(pointer6.move(const Point(14.0, 13.0)));
    expect(log, isEmpty);

    tester.route(pointer5.up());
    expect(log, <String>[
      'tap-up 5',
      'tap 5',
    ]);
    log.clear();

    tester.async.elapse(kLongPressTimeout + kPressTimeout);
    expect(log, <String>['long-tap-down 6']);
    log.clear();

    tester.route(pointer6.move(const Point(4.0, 3.0)));
    expect(log, <String>['tap-cancel 6']);
    log.clear();

    tester.route(pointer6.up());
    expect(log, isEmpty);

    tap.dispose();
  });
}
