// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../framework/adb.dart';
import '../framework/framework.dart';
import '../framework/utils.dart';

TaskFunction createGalleryTransitionTest() {
  return new GalleryTransitionTest();
}

class GalleryTransitionTest {

  Future<TaskResult> call() async {
    Device device = await devices.workingDevice;
    await device.unlock();
    String deviceId = device.deviceId;
    Directory galleryDirectory =
        dir('${flutterDirectory.path}/examples/flutter_gallery');
    await inDirectory(galleryDirectory, () async {
      await flutter('packages', options: <String>['get']);

      if (deviceOperatingSystem == DeviceOperatingSystem.ios) {
        // This causes an Xcode project to be created.
        await flutter('build', options: <String>['ios', '--profile']);
      }

      await flutter('drive', options: <String>[
        '--profile',
        '--trace-startup',
        '-t',
        'test_driver/transitions_perf.dart',
        '-d',
        deviceId,
      ]);
    });

    // Route paths contains slashes, which Firebase doesn't accept in keys, so we
    // remove them.
    Map<String, List<int>> original = JSON.decode(file(
            '${galleryDirectory.path}/build/transition_durations.timeline.json')
        .readAsStringSync());
    Map<String, List<int>> transitions = new Map<String, List<int>>.fromIterable(
        original.keys,
        key: (String key) => key.replaceAll('/', ''),
        value: (String key) => original[key]);

    Map<String, dynamic> summary = JSON.decode(file('${galleryDirectory.path}/build/transitions.timeline_summary.json').readAsStringSync());

    Map<String, dynamic> data = <String, dynamic>{
      'transitions': transitions,
      'missed_transition_count': _countMissedTransitions(transitions),
    };
    data.addAll(summary);

    return new TaskResult.success(data, benchmarkScoreKeys: <String>[
      'missed_transition_count',
      'average_frame_build_time_millis',
      'worst_frame_build_time_millis',
      'missed_frame_build_budget_count',
      'average_frame_rasterizer_time_millis',
      'worst_frame_rasterizer_time_millis',
      'missed_frame_rasterizer_budget_count',
    ]);
  }
}

int _countMissedTransitions(Map<String, List<int>> transitions) {
  const int _kTransitionBudget = 100000; // µs
  int count = 0;
  transitions.forEach((String demoName, List<int> durations) {
    int longestDuration = durations.reduce(math.max);
    if (longestDuration > _kTransitionBudget) {
      print('$demoName missed transition time budget ($longestDuration µs > $_kTransitionBudget µs)');
      count++;
    }
  });
  return count;
}
