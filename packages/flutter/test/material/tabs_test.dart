// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class StateMarker extends StatefulWidget {
  StateMarker({ Key key, this.child }) : super(key: key);

  final Widget child;

  @override
  StateMarkerState createState() => new StateMarkerState();
}

class StateMarkerState extends State<StateMarker> {
  String marker;

  @override
  Widget build(BuildContext context) {
    if (config.child != null)
      return config.child;
    return new Container();
  }
}

Widget buildFrame({ List<String> tabs, String value, bool isScrollable: false, Key tabBarKey }) {
  return new Material(
    child: new DefaultTabController(
      initialIndex: tabs.indexOf(value),
      length: tabs.length,
      child: new TabBar(
        key: tabBarKey,
        tabs: tabs.map((String tab) => new Tab(text: tab)).toList(),
        isScrollable: isScrollable,
      ),
    ),
  );
}

typedef Widget TabControllerFrameBuilder(BuildContext context, TabController controller);

class TabControllerFrame extends StatefulWidget {
  TabControllerFrame({ this.length, this.initialIndex: 0, this.builder });

  final int length;
  final int initialIndex;
  final TabControllerFrameBuilder builder;

  @override
  TabControllerFrameState createState() => new TabControllerFrameState();
}

class TabControllerFrameState extends State<TabControllerFrame> with SingleTickerProviderStateMixin {
  TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = new TabController(
      vsync: this,
      length: config.length,
      initialIndex: config.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return config.builder(context, _controller);
  }
}

Widget buildLeftRightApp({ List<String> tabs, String value }) {
  return new MaterialApp(
    theme: new ThemeData(platform: TargetPlatform.android),
    home: new DefaultTabController(
      initialIndex: tabs.indexOf(value),
      length: tabs.length,
      child: new Scaffold(
        appBar: new AppBar(
          title: new Text('tabs'),
          bottom: new TabBar(
            tabs: tabs.map((String tab) => new Tab(text: tab)).toList(),
          ),
        ),
        body: new TabBarView(
          children: <Widget>[
            new Center(child: new Text('LEFT CHILD')),
            new Center(child: new Text('RIGHT CHILD'))
          ]
        )
      )
    )
  );
}

void main() {
  testWidgets('TabBar tap selects tab', (WidgetTester tester) async {
    List<String> tabs = <String>['A', 'B', 'C'];

    await tester.pumpWidget(buildFrame(tabs: tabs, value: 'C', isScrollable: false));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    TabController controller = DefaultTabController.of(tester.element(find.text('A')));
    expect(controller, isNotNull);
    expect(controller.index, 2);
    expect(controller.previousIndex, 2);

    await tester.pumpWidget(buildFrame(tabs: tabs, value: 'C', isScrollable: false));
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(controller.indexIsChanging, true);
    await tester.pump(const Duration(seconds: 1)); // finish the animation
    expect(controller.index, 1);
    expect(controller.previousIndex, 2);
    expect(controller.indexIsChanging, false);

    await tester.pumpWidget(buildFrame(tabs: tabs, value: 'C', isScrollable: false));
    await tester.tap(find.text('C'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.index, 2);
    expect(controller.previousIndex, 1);

    await tester.pumpWidget(buildFrame(tabs: tabs, value: 'C', isScrollable: false));
    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.index, 0);
    expect(controller.previousIndex, 2);
  });

  testWidgets('Scrollable TabBar tap selects tab', (WidgetTester tester) async {
    List<String> tabs = <String>['A', 'B', 'C'];

    await tester.pumpWidget(buildFrame(tabs: tabs, value: 'C', isScrollable: true));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    TabController controller = DefaultTabController.of(tester.element(find.text('A')));
    expect(controller.index, 2);
    expect(controller.previousIndex, 2);

    await tester.tap(find.text('C'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.index, 2);

    await tester.tap(find.text('B'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.index, 1);

    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.index, 0);
  });

  testWidgets('Scrollable TabBar tap centers selected tab', (WidgetTester tester) async {
    List<String> tabs = <String>['AAAAAA', 'BBBBBB', 'CCCCCC', 'DDDDDD', 'EEEEEE', 'FFFFFF', 'GGGGGG', 'HHHHHH', 'IIIIII', 'JJJJJJ', 'KKKKKK', 'LLLLLL'];
    Key tabBarKey = new Key('TabBar');
    await tester.pumpWidget(buildFrame(tabs: tabs, value: 'AAAAAA', isScrollable: true, tabBarKey: tabBarKey));
    TabController controller = DefaultTabController.of(tester.element(find.text('AAAAAA')));
    expect(controller, isNotNull);
    expect(controller.index, 0);

    expect(tester.getSize(find.byKey(tabBarKey)).width, equals(800.0));
    // The center of the FFFFFF item is to the right of the TabBar's center
    expect(tester.getCenter(find.text('FFFFFF')).x, greaterThan(401.0));

    await tester.tap(find.text('FFFFFF'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the scroll animation
    expect(controller.index, 5);
    // The center of the FFFFFF item is now at the TabBar's center
    expect(tester.getCenter(find.text('FFFFFF')).x, closeTo(400.0, 1.0));
  });


  testWidgets('TabBar can be scrolled independent of the selection', (WidgetTester tester) async {
    List<String> tabs = <String>['AAAA', 'BBBB', 'CCCC', 'DDDD', 'EEEE', 'FFFF', 'GGGG', 'HHHH', 'IIII', 'JJJJ', 'KKKK', 'LLLL'];
    Key tabBarKey = new Key('TabBar');
    await tester.pumpWidget(buildFrame(tabs: tabs, value: 'AAAA', isScrollable: true, tabBarKey: tabBarKey));
    TabController controller = DefaultTabController.of(tester.element(find.text('AAAA')));
    expect(controller, isNotNull);
    expect(controller.index, 0);

    // Fling-scroll the TabBar to the left
    expect(tester.getCenter(find.text('HHHH')).x, lessThan(700.0));
    await tester.fling(find.byKey(tabBarKey), const Offset(-200.0, 0.0), 10000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the scroll animation
    expect(tester.getCenter(find.text('HHHH')).x, lessThan(500.0));

    // Scrolling the TabBar doesn't change the selection
    expect(controller.index, 0);
  });

  testWidgets('TabBarView maintains state', (WidgetTester tester) async {
    List<String> tabs = <String>['AAAAAA', 'BBBBBB', 'CCCCCC', 'DDDDDD', 'EEEEEE'];
    String value = tabs[0];

    Widget builder() {
      return new Material(
        child: new DefaultTabController(
          initialIndex: tabs.indexOf(value),
          length: tabs.length,
          child: new TabBarView(
            children: tabs.map((String name) {
              return new StateMarker(
                child: new Text(name)
              );
            }).toList()
          ),
        ),
      );
    }

    StateMarkerState findStateMarkerState(String name) {
      return tester.state(find.widgetWithText(StateMarker, name));
    }

    await tester.pumpWidget(builder());
    TabController controller = DefaultTabController.of(tester.element(find.text('AAAAAA')));

    TestGesture gesture = await tester.startGesture(tester.getCenter(find.text(tabs[0])));
    await gesture.moveBy(const Offset(-600.0, 0.0));
    await tester.pump();
    expect(value, equals(tabs[0]));
    findStateMarkerState(tabs[1]).marker = 'marked';
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    value = tabs[controller.index];
    expect(value, equals(tabs[1]));
    await tester.pumpWidget(builder());
    expect(findStateMarkerState(tabs[1]).marker, equals('marked'));

    // Move to the third tab.

    gesture = await tester.startGesture(tester.getCenter(find.text(tabs[1])));
    await gesture.moveBy(const Offset(-600.0, 0.0));
    await gesture.up();
    await tester.pump();
    expect(findStateMarkerState(tabs[1]).marker, equals('marked'));
    await tester.pump(const Duration(seconds: 1));
    value = tabs[controller.index];
    expect(value, equals(tabs[2]));
    await tester.pumpWidget(builder());

    // The state is now gone.

    expect(find.text(tabs[1]), findsNothing);

    // Move back to the second tab.

    gesture = await tester.startGesture(tester.getCenter(find.text(tabs[2])));
    await gesture.moveBy(const Offset(600.0, 0.0));
    await tester.pump();
    StateMarkerState markerState = findStateMarkerState(tabs[1]);
    expect(markerState.marker, isNull);
    markerState.marker = 'marked';
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    value = tabs[controller.index];
    expect(value, equals(tabs[1]));
    await tester.pumpWidget(builder());
    expect(findStateMarkerState(tabs[1]).marker, equals('marked'));
  });

  testWidgets('TabBar left/right fling', (WidgetTester tester) async {
    List<String> tabs = <String>['LEFT', 'RIGHT'];

    await tester.pumpWidget(buildLeftRightApp(tabs: tabs, value: 'LEFT'));
    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('RIGHT'), findsOneWidget);
    expect(find.text('LEFT CHILD'), findsOneWidget);
    expect(find.text('RIGHT CHILD'), findsNothing);

    TabController controller = DefaultTabController.of(tester.element(find.text('LEFT')));
    expect(controller.index, 0);

    // Fling to the left, switch from the 'LEFT' tab to the 'RIGHT'
    Point flingStart = tester.getCenter(find.text('LEFT CHILD'));
    await tester.flingFrom(flingStart, const Offset(-200.0, 0.0), 10000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the scroll animation
    expect(controller.index, 1);
    expect(find.text('LEFT CHILD'), findsNothing);
    expect(find.text('RIGHT CHILD'), findsOneWidget);

    // Fling to the right, switch back to the 'LEFT' tab
    flingStart = tester.getCenter(find.text('RIGHT CHILD'));
    await tester.flingFrom(flingStart, const Offset(200.0, 0.0), 10000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the scroll animation
    expect(controller.index, 0);
    expect(find.text('LEFT CHILD'), findsOneWidget);
    expect(find.text('RIGHT CHILD'), findsNothing);
  });

  // A regression test for https://github.com/flutter/flutter/issues/5095
  testWidgets('TabBar left/right fling reverse', (WidgetTester tester) async {
    List<String> tabs = <String>['LEFT', 'RIGHT'];

    await tester.pumpWidget(buildLeftRightApp(tabs: tabs, value: 'LEFT'));
    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('RIGHT'), findsOneWidget);
    expect(find.text('LEFT CHILD'), findsOneWidget);
    expect(find.text('RIGHT CHILD'), findsNothing);

    TabController controller = DefaultTabController.of(tester.element(find.text('LEFT')));
    expect(controller.index, 0);

    // End the fling by reversing direction. This should cause not cause
    // a change to the selected tab, everything should just settle back to
    // to where it started.
    Point flingStart = tester.getCenter(find.text('LEFT CHILD'));
    await tester.flingFrom(flingStart, const Offset(-200.0, 0.0), -10000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the scroll animation
    expect(controller.index, 0);
    expect(find.text('LEFT CHILD'), findsOneWidget);
    expect(find.text('RIGHT CHILD'), findsNothing);
  });

  // A regression test for https://github.com/flutter/flutter/issues/7133
  testWidgets('TabBar fling velocity', (WidgetTester tester) async {
    List<String> tabs = <String>['AAAAAA', 'BBBBBB', 'CCCCCC', 'DDDDDD', 'EEEEEE', 'FFFFFF', 'GGGGGG', 'HHHHHH', 'IIIIII', 'JJJJJJ', 'KKKKKK', 'LLLLLL'];
    int index = 0;

    await tester.pumpWidget(
      new MaterialApp(
        home: new Align(
          alignment: FractionalOffset.topLeft,
          child: new SizedBox(
            width: 300.0,
            height: 200.0,
            child: new DefaultTabController(
              length: tabs.length,
              child: new Scaffold(
                appBar: new AppBar(
                  title: new Text('tabs'),
                  bottom: new TabBar(
                    isScrollable: true,
                    tabs: tabs.map((String tab) => new Tab(text: tab)).toList(),
                  ),
                ),
                body: new TabBarView(
                  children: tabs.map((String name) => new Text('${index++}')).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // After a small slow fling to the left, we expect the second item to still be visible.
    await tester.fling(find.text('AAAAAA'), const Offset(-25.0, 0.0), 100.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the scroll animation
    final RenderBox box = tester.renderObject(find.text('BBBBBB'));
    expect(box.localToGlobal(Point.origin).x, greaterThan(0.0));
  });

  testWidgets('TabController change notification', (WidgetTester tester) async {
    List<String> tabs = <String>['LEFT', 'RIGHT'];

    await tester.pumpWidget(buildLeftRightApp(tabs: tabs, value: 'LEFT'));
    TabController controller = DefaultTabController.of(tester.element(find.text('LEFT')));

    expect(controller, isNotNull);
    expect(controller.index, 0);

    String value;
    controller.addListener(() {
      value = tabs[controller.index];
    });

    // TODO(hixie) - the new scrolling framework should eliminate most of the pump
    // calls that follow. Currently they exist to complete chains of future.then
    // in the implementation.

    await tester.tap(find.text('RIGHT'));
    await tester.pump(); // start the animation
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(value, 'RIGHT');

    await tester.tap(find.text('LEFT'));
    await tester.pump(); // start the animation
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(value, 'LEFT');

    Point leftFlingStart = tester.getCenter(find.text('LEFT CHILD'));
    await tester.flingFrom(leftFlingStart, const Offset(-200.0, 0.0), 10000.0);
    await tester.pump(); // start the animation
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(value, 'RIGHT');

    Point rightFlingStart = tester.getCenter(find.text('RIGHT CHILD'));
    await tester.flingFrom(rightFlingStart, const Offset(200.0, 0.0), 10000.0);
    await tester.pump(); // start the animation
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(value, 'LEFT');
  });

  testWidgets('Explicit TabController', (WidgetTester tester) async {
    List<String> tabs = <String>['LEFT', 'RIGHT'];
    TabController tabController;

    Widget buildTabControllerFrame(BuildContext context, TabController controller) {
      tabController = controller;
      return new MaterialApp(
        theme: new ThemeData(platform: TargetPlatform.android),
        home: new Scaffold(
          appBar: new AppBar(
            title: new Text('tabs'),
            bottom: new TabBar(
              controller: controller,
              tabs: tabs.map((String tab) => new Tab(text: tab)).toList(),
            ),
          ),
          body: new TabBarView(
            controller: controller,
            children: <Widget>[
              new Center(child: new Text('LEFT CHILD')),
              new Center(child: new Text('RIGHT CHILD'))
            ]
          ),
        ),
      );
    }

    await tester.pumpWidget(new TabControllerFrame(
      builder: buildTabControllerFrame,
      length: tabs.length,
      initialIndex: 1,
    ));

    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('RIGHT'), findsOneWidget);
    expect(find.text('LEFT CHILD'), findsNothing);
    expect(find.text('RIGHT CHILD'), findsOneWidget);
    expect(tabController.index, 1);
    expect(tabController.previousIndex, 1);
    expect(tabController.indexIsChanging, false);
    expect(tabController.animation.value, 1.0);
    expect(tabController.animation.status, AnimationStatus.completed);

    tabController.index = 0;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LEFT CHILD'), findsOneWidget);
    expect(find.text('RIGHT CHILD'), findsNothing);

    tabController.index = 1;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LEFT CHILD'), findsNothing);
    expect(find.text('RIGHT CHILD'), findsOneWidget);
  });

  testWidgets('TabController listener resets index', (WidgetTester tester) async {
    // This is a regression test for the scenario brought up here
    // https://github.com/flutter/flutter/pull/7387#pullrequestreview-15630946

    List<String> tabs = <String>['A', 'B', 'C'];
    TabController tabController;

    Widget buildTabControllerFrame(BuildContext context, TabController controller) {
      tabController = controller;
      return new MaterialApp(
        theme: new ThemeData(platform: TargetPlatform.android),
        home: new Scaffold(
          appBar: new AppBar(
            title: new Text('tabs'),
            bottom: new TabBar(
              controller: controller,
              tabs: tabs.map((String tab) => new Tab(text: tab)).toList(),
            ),
          ),
          body: new TabBarView(
            controller: controller,
            children: <Widget>[
              new Center(child: new Text('CHILD A')),
              new Center(child: new Text('CHILD B')),
              new Center(child: new Text('CHILD C')),
            ]
          ),
        ),
      );
    }

    await tester.pumpWidget(new TabControllerFrame(
      builder: buildTabControllerFrame,
      length: tabs.length,
    ));

    tabController.animation.addListener(() {
      if (tabController.animation.status == AnimationStatus.forward)
        tabController.index = 2;
      expect(tabController.indexIsChanging, true);
    });

    expect(tabController.index, 0);
    expect(tabController.indexIsChanging, false);

    tabController.animateTo(1, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tabController.index, 2);
    expect(tabController.indexIsChanging, false);
  });

  testWidgets('TabBarView child disposed during animation', (WidgetTester tester) async {
    // This is a regression test for the scenario brought up here
    // https://github.com/flutter/flutter/pull/7387#discussion_r95089191x

    List<String> tabs = <String>['LEFT', 'RIGHT'];
    await tester.pumpWidget(buildLeftRightApp(tabs: tabs, value: 'LEFT'));

    // Fling to the left, switch from the 'LEFT' tab to the 'RIGHT'
    Point flingStart = tester.getCenter(find.text('LEFT CHILD'));
    await tester.flingFrom(flingStart, const Offset(-200.0, 0.0), 10000.0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the scroll animation
  });

  testWidgets('TabBar unselectedLabelColor control test', (WidgetTester tester) async {
    TabController controller = new TabController(
      vsync: const TestVSync(),
      length: 2,
    );

    Color firstColor;
    Color secondColor;

    await tester.pumpWidget(
      new Material(
        child: new TabBar(
          controller: controller,
          labelColor: Colors.green[500],
          unselectedLabelColor: Colors.blue[500],
          tabs: <Widget>[
            new Builder(
              builder: (BuildContext context) {
                firstColor = IconTheme.of(context).color;
                return new Text('First');
              }
            ),
            new Builder(
              builder: (BuildContext context) {
                secondColor = IconTheme.of(context).color;
                return new Text('Second');
              }
            ),
          ],
        ),
      ),
    );

    expect(firstColor, equals(Colors.green[500]));
    expect(secondColor, equals(Colors.blue[500]));
  });

}
