// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:flutter_tools/src/base/common.dart';

import '../common.dart';

void main() {
  group('throwToolExit', () {
    test('throws ToolExit', () {
      expect(() => throwToolExit('message'), throwsToolExit());
    });

    test('throws ToolExit with exitCode', () {
      expect(() => throwToolExit('message', exitCode: 42), throwsToolExit(42));
    });
  });
}
