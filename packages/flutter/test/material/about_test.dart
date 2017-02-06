// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AboutDrawerItem control test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new MaterialApp(
        title: 'Pirate app',
        home: new Scaffold(
          appBar: new AppBar(
            title: new Text('Home'),
          ),
          drawer: new Drawer(
            child: new ListView(
              children: <Widget>[
                new AboutDrawerItem(
                  applicationVersion: '0.1.2',
                  applicationIcon: new FlutterLogo(),
                  applicationLegalese: 'I am the very model of a modern major general.',
                  aboutBoxChildren: <Widget>[
                    new Text('About box'),
                  ]
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('About Pirate app'), findsNothing);
    expect(find.text('0.1.2'), findsNothing);
    expect(find.text('About box'), findsNothing);

    await tester.tap(find.byType(IconButton));
    await tester.pumpUntilNoTransientCallbacks(const Duration(milliseconds: 100));

    expect(find.text('About Pirate app'), findsOneWidget);
    expect(find.text('0.1.2'), findsNothing);
    expect(find.text('About box'), findsNothing);

    await tester.tap(find.text('About Pirate app'));
    await tester.pumpUntilNoTransientCallbacks(const Duration(milliseconds: 100));

    expect(find.text('About Pirate app'), findsOneWidget);
    expect(find.text('0.1.2'), findsOneWidget);
    expect(find.text('About box'), findsOneWidget);

    LicenseRegistry.addLicense(() {
      return new Stream<LicenseEntry>.fromIterable(<LicenseEntry>[
        new LicenseEntryWithLineBreaks(<String>[ 'Pirate package '], 'Pirate license')
      ]);
    });

    await tester.tap(find.text('VIEW LICENSES'));
    await tester.pumpUntilNoTransientCallbacks(const Duration(milliseconds: 100));

    expect(find.text('Pirate license'), findsOneWidget);
  });

  testWidgets('About box logic defaults to executable name for app name', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Material(child: new AboutDrawerItem()),
    );
    expect(find.text('About sky_shell'), findsOneWidget);
  });

  testWidgets('AboutDrawerItem control test', (WidgetTester tester) async {
    List<String> log = <String>[];

    Future<Null> licenseFuture;
    LicenseRegistry.addLicense(() {
      log.add('license1');
      licenseFuture = tester.pumpWidget(new Container());
      return new Stream<LicenseEntry>.fromIterable(<LicenseEntry>[]);
    });

    LicenseRegistry.addLicense(() {
      log.add('license2');
      return new Stream<LicenseEntry>.fromIterable(<LicenseEntry>[
        new LicenseEntryWithLineBreaks(<String>[ 'Another package '], 'Another license')
      ]);
    });

    await tester.pumpWidget(new Center(
      child: new LicensePage()
    ));

    expect(licenseFuture, isNotNull);
    await licenseFuture;

    // We should not hit an exception here.
    await tester.idle();

    expect(log, equals(<String>['license1', 'license2']));
  });
}
