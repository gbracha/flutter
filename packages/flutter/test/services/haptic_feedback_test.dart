// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:test/test.dart';

void main() {
  test('Haptic feedback control test', () async {
    List<String> log = <String>[];

    PlatformMessages.setMockStringMessageHandler('flutter/platform', (String message) async {
      log.add(message);
    });

    await HapticFeedback.vibrate();

    expect(log, equals(<String>['{"method":"HapticFeedback.vibrate","args":[]}']));
  });
}
