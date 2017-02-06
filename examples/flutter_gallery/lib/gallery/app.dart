// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;

import 'item.dart';
import 'home.dart';
import 'updates.dart';

final Map<String, WidgetBuilder> _kRoutes = new Map<String, WidgetBuilder>.fromIterable(
  kAllGalleryItems,
  key: (GalleryItem item) => item.routeName,
  value: (GalleryItem item) => item.buildRoute,
);

final ThemeData _kGalleryLightTheme = new ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.lightBlue,
);

final ThemeData _kGalleryDarkTheme = new ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.lightBlue,
);

class GalleryApp extends StatefulWidget {
  GalleryApp({
    this.updateUrlFetcher,
    this.enablePerformanceOverlay: true,
    this.checkerboardRasterCacheImages: true,
    this.onSendFeedback,
    Key key}
  ) : super(key: key);

  final UpdateUrlFetcher updateUrlFetcher;

  final bool enablePerformanceOverlay;

  final bool checkerboardRasterCacheImages;

  final VoidCallback onSendFeedback;

  @override
  GalleryAppState createState() => new GalleryAppState();
}

class GalleryAppState extends State<GalleryApp> {
  bool _useLightTheme = true;
  bool _showPerformanceOverlay = false;
  bool _checkerboardRasterCacheImages = false;
  double _timeDilation = 1.0;
  TargetPlatform _platform = defaultTargetPlatform;

  Timer _timeDilationTimer;

  @override
  void initState() {
    _timeDilation = timeDilation;
    super.initState();
  }

  @override
  void dispose() {
    _timeDilationTimer?.cancel();
    _timeDilationTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget home = new GalleryHome(
      useLightTheme: _useLightTheme,
      onThemeChanged: (bool value) {
        setState(() {
          _useLightTheme = value;
        });
      },
      showPerformanceOverlay: _showPerformanceOverlay,
      onShowPerformanceOverlayChanged: config.enablePerformanceOverlay ? (bool value) {
        setState(() {
          _showPerformanceOverlay = value;
        });
      } : null,
      checkerboardRasterCacheImages: _checkerboardRasterCacheImages,
      onCheckerboardRasterCacheImagesChanged: config.checkerboardRasterCacheImages ? (bool value) {
        setState(() {
          _checkerboardRasterCacheImages = value;
        });
      } : null,
      onPlatformChanged: (TargetPlatform value) {
        setState(() {
          _platform = value;
        });
      },
      timeDilation: _timeDilation,
      onTimeDilationChanged: (double value) {
        setState(() {
          _timeDilationTimer?.cancel();
          _timeDilationTimer = null;
          _timeDilation = value;
          if (_timeDilation > 1.0) {
            // We delay the time dilation change long enough that the user can see
            // that the checkbox in the drawer has started reacting, then we slam
            // on the brakes so that they see that the time is in fact now dilated.
            _timeDilationTimer = new Timer(const Duration(milliseconds: 150), () {
              timeDilation = _timeDilation;
            });
          } else {
            timeDilation = _timeDilation;
          }
        });
      },
      onSendFeedback: config.onSendFeedback,
    );

    if (config.updateUrlFetcher != null) {
      home = new Updater(
        updateUrlFetcher: config.updateUrlFetcher,
        child: home,
      );
    }

    return new MaterialApp(
      title: 'Flutter Gallery',
      color: Colors.grey[500],
      theme: (_useLightTheme ? _kGalleryLightTheme : _kGalleryDarkTheme).copyWith(platform: _platform),
      showPerformanceOverlay: _showPerformanceOverlay,
      checkerboardRasterCacheImages: _checkerboardRasterCacheImages,
      routes: _kRoutes,
      home: home,
    );
  }
}
