// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class TestStatefulWidget extends StatefulWidget {
  TestStatefulWidget({ Key key }) : super(key: key);

  @override
  TestStatefulWidgetState createState() => new TestStatefulWidgetState();
}

class TestStatefulWidgetState extends State<TestStatefulWidget> {
  @override
  Widget build(BuildContext context) => new Container();
}

void main() {
  testWidgets('Table widget - control test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('AAAAAA'), new Text('B'), new Text('C')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('D'), new Text('EEE'), new Text('F')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('G'), new Text('H'), new Text('III')
            ]
          ),
        ]
      )
    );
    RenderBox boxA = tester.renderObject(find.text('AAAAAA'));
    RenderBox boxD = tester.renderObject(find.text('D'));
    RenderBox boxG = tester.renderObject(find.text('G'));
    RenderBox boxB = tester.renderObject(find.text('B'));
    expect(boxA.size, equals(boxD.size));
    expect(boxA.size, equals(boxG.size));
    expect(boxA.size, equals(boxB.size));
  });

  testWidgets('Table widget - changing table dimensions', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('A'), new Text('B'), new Text('C')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('D'), new Text('E'), new Text('F')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('G'), new Text('H'), new Text('I')
            ]
          ),
        ]
      )
    );
    RenderBox boxA1 = tester.renderObject(find.text('A'));
    RenderBox boxG1 = tester.renderObject(find.text('G'));
    expect(boxA1, isNotNull);
    expect(boxG1, isNotNull);
    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('a'), new Text('b'), new Text('c'), new Text('d')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('e'), new Text('f'), new Text('g'), new Text('h')
            ]
          ),
        ]
      )
    );
    RenderBox boxA2 = tester.renderObject(find.text('a'));
    RenderBox boxG2 = tester.renderObject(find.text('g'));
    expect(boxA2, isNotNull);
    expect(boxG2, isNotNull);
    expect(boxA1, equals(boxA2));
    expect(boxG1, isNot(equals(boxG2)));
  });

  testWidgets('Table widget - repump test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('AAAAAA'), new Text('B'), new Text('C')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('D'), new Text('EEE'), new Text('F')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('G'), new Text('H'), new Text('III')
            ]
          ),
        ]
      )
    );
    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('AAA'), new Text('B'), new Text('C')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('D'), new Text('E'), new Text('FFFFFF')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('G'), new Text('H'), new Text('III')
            ]
          ),
        ]
      )
    );
    RenderBox boxA = tester.renderObject(find.text('AAA'));
    RenderBox boxD = tester.renderObject(find.text('D'));
    RenderBox boxG = tester.renderObject(find.text('G'));
    RenderBox boxB = tester.renderObject(find.text('B'));
    expect(boxA.size, equals(boxD.size));
    expect(boxA.size, equals(boxG.size));
    expect(boxA.size, equals(boxB.size));
  });

  testWidgets('Table widget - intrinsic sizing test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('AAA'), new Text('B'), new Text('C')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('D'), new Text('E'), new Text('FFFFFF')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('G'), new Text('H'), new Text('III')
            ]
          ),
        ]
      )
    );
    RenderBox boxA = tester.renderObject(find.text('AAA'));
    RenderBox boxD = tester.renderObject(find.text('D'));
    RenderBox boxG = tester.renderObject(find.text('G'));
    RenderBox boxB = tester.renderObject(find.text('B'));
    expect(boxA.size, equals(boxD.size));
    expect(boxA.size, equals(boxG.size));
    expect(boxA.size.width, greaterThan(boxB.size.width));
    expect(boxA.size.height, equals(boxB.size.height));
  });

  testWidgets('Table widget - intrinsic sizing test, resizing', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('AAAAAA'), new Text('B'), new Text('C')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('D'), new Text('EEE'), new Text('F')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('G'), new Text('H'), new Text('III')
            ]
          ),
        ]
      )
    );
    await tester.pumpWidget(
      new Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('A'), new Text('B'), new Text('C')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('D'), new Text('EEE'), new Text('F')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('G'), new Text('H'), new Text('III')
            ]
          ),
        ]
      )
    );
    RenderBox boxA = tester.renderObject(find.text('A'));
    RenderBox boxD = tester.renderObject(find.text('D'));
    RenderBox boxG = tester.renderObject(find.text('G'));
    RenderBox boxB = tester.renderObject(find.text('B'));
    expect(boxA.size, equals(boxD.size));
    expect(boxA.size, equals(boxG.size));
    expect(boxA.size.width, lessThan(boxB.size.width));
    expect(boxA.size.height, equals(boxB.size.height));
  });

  testWidgets('Table widget - intrinsic sizing test, changing column widths', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('AAA'), new Text('B'), new Text('C')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('D'), new Text('E'), new Text('FFFFFF')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('G'), new Text('H'), new Text('III')
            ]
          ),
        ]
      )
    );
    await tester.pumpWidget(
      new Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('AAA'), new Text('B'), new Text('C')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('D'), new Text('E'), new Text('FFFFFF')
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('G'), new Text('H'), new Text('III')
            ]
          ),
        ]
      )
    );
    RenderBox boxA = tester.renderObject(find.text('AAA'));
    RenderBox boxD = tester.renderObject(find.text('D'));
    RenderBox boxG = tester.renderObject(find.text('G'));
    RenderBox boxB = tester.renderObject(find.text('B'));
    expect(boxA.size, equals(boxD.size));
    expect(boxA.size, equals(boxG.size));
    expect(boxA.size.width, greaterThan(boxB.size.width));
    expect(boxA.size.height, equals(boxB.size.height));
  });

  testWidgets('Table widget - moving test', (WidgetTester tester) async {
    List<BuildContext> contexts = <BuildContext>[];
    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            key: const ValueKey<int>(1),
            children: <Widget>[
              new StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  contexts.add(context);
                  return new Text('A');
                }
              )
            ]
          ),
          new TableRow(
            children: <Widget>[
              new Text('b')
            ]
          ),
        ]
      )
    );
    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            children: <Widget>[
              new Text('b')
            ]
          ),
          new TableRow(
            key: const ValueKey<int>(1),
            children: <Widget>[
              new StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  contexts.add(context);
                  return new Text('A');
                }
              )
            ]
          ),
        ]
      )
    );
    expect(contexts.length, equals(2));
    expect(contexts[0], equals(contexts[1]));
  });

  testWidgets('Table widget - keyed rows', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            key: const ValueKey<int>(1),
            children: <Widget>[
              new TestStatefulWidget(key: const ValueKey<int>(11)),
              new TestStatefulWidget(key: const ValueKey<int>(12)),
            ],
          ),
          new TableRow(
            key: const ValueKey<int>(2),
            children: <Widget>[
              new TestStatefulWidget(key: const ValueKey<int>(21)),
              new TestStatefulWidget(key: const ValueKey<int>(22)),
            ],
          ),
        ]
      )
    );

    TestStatefulWidgetState state11 = tester.state(find.byKey(const ValueKey<int>(11)));
    TestStatefulWidgetState state12 = tester.state(find.byKey(const ValueKey<int>(12)));
    TestStatefulWidgetState state21 = tester.state(find.byKey(const ValueKey<int>(21)));
    TestStatefulWidgetState state22 = tester.state(find.byKey(const ValueKey<int>(22)));

    expect(state11.mounted, isTrue);
    expect(state12.mounted, isTrue);
    expect(state21.mounted, isTrue);
    expect(state22.mounted, isTrue);

    await tester.pumpWidget(
      new Table(
        children: <TableRow>[
          new TableRow(
            key: const ValueKey<int>(2),
            children: <Widget>[
              new TestStatefulWidget(key: const ValueKey<int>(21)),
              new TestStatefulWidget(key: const ValueKey<int>(22)),
            ],
          ),
        ]
      )
    );

    expect(state11.mounted, isFalse);
    expect(state12.mounted, isFalse);
    expect(state21.mounted, isTrue);
    expect(state22.mounted, isTrue);
  });

  testWidgets('Table widget - global key reparenting', (WidgetTester tester) async {
    GlobalKey key = new GlobalKey();
    Key tableKey = new UniqueKey();

    await tester.pumpWidget(
      new Column(
        children: <Widget> [
          new Expanded(
            key: tableKey,
            child: new Table(
              children: <TableRow>[
                new TableRow(
                  children: <Widget>[
                    new Container(key: const ValueKey<int>(1)),
                    new TestStatefulWidget(key: key),
                    new Container(key: const ValueKey<int>(2)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    RenderTable table = tester.renderObject(find.byType(Table));
    expect(table.row(0).length, 3);

    await tester.pumpWidget(
      new Column(
        children: <Widget> [
          new Expanded(child: new TestStatefulWidget(key: key)),
          new Expanded(
            key: tableKey,
            child: new Table(
              children: <TableRow>[
                new TableRow(
                  children: <Widget>[
                    new Container(key: const ValueKey<int>(1)),
                    new Container(key: const ValueKey<int>(2)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    expect(tester.renderObject(find.byType(Table)), equals(table));
    expect(table.row(0).length, 2);

    await tester.pumpWidget(
      new Column(
        children: <Widget> [
          new Expanded(
            key: tableKey,
            child: new Table(
              children: <TableRow>[
                new TableRow(
                  children: <Widget>[
                    new Container(key: const ValueKey<int>(1)),
                    new TestStatefulWidget(key: key),
                    new Container(key: const ValueKey<int>(2)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    expect(tester.renderObject(find.byType(Table)), equals(table));
    expect(table.row(0).length, 3);

    await tester.pumpWidget(
      new Column(
        children: <Widget> [
          new Expanded(
            key: tableKey,
            child: new Table(
              children: <TableRow>[
                new TableRow(
                  children: <Widget>[
                    new Container(key: const ValueKey<int>(1)),
                    new Container(key: const ValueKey<int>(2)),
                  ],
                ),
              ],
            ),
          ),
          new Expanded(child: new TestStatefulWidget(key: key)),
        ],
      ),
    );

    expect(tester.renderObject(find.byType(Table)), equals(table));
    expect(table.row(0).length, 2);
  });

  // TODO(ianh): Test handling of TableCell object
}
