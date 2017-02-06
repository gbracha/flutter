// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_table_test_utils.dart';

class TestDataSource extends DataTableSource {
  int get generation => _generation;
  int _generation = 0;
  set generation(int value) {
    if (_generation == value)
      return;
    _generation = value;
    notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    final Dessert dessert = kDesserts[index % kDesserts.length];
    final int page = index ~/ kDesserts.length;
    return new DataRow.byIndex(
      index: index,
      cells: <DataCell>[
        new DataCell(new Text('${dessert.name} ($page)')),
        new DataCell(new Text('${dessert.calories}')),
        new DataCell(new Text('$generation')),
      ],
    );
  }

  @override
  int get rowCount => 500 * kDesserts.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

void main() {
  testWidgets('PaginatedDataTable control test', (WidgetTester tester) async {
    TestDataSource source = new TestDataSource()
      ..generation = 42;

    List<String> log = <String>[];

    Widget buildTable(TestDataSource source) {
      return new PaginatedDataTable(
        header: new Text('Test table'),
        source: source,
        onPageChanged: (int rowIndex) {
          log.add('page-changed: $rowIndex');
        },
        columns: <DataColumn>[
          new DataColumn(
            label: new Text('Name'),
            tooltip: 'Name',
          ),
          new DataColumn(
            label: new Text('Calories'),
            tooltip: 'Calories',
            numeric: true,
            onSort: (int columnIndex, bool ascending) {
              log.add('column-sort: $columnIndex $ascending');
            }
          ),
          new DataColumn(
            label: new Text('Generation'),
            tooltip: 'Generation',
          ),
        ],
        actions: <Widget>[
          new IconButton(
            icon: new Icon(Icons.adjust),
            onPressed: () {
              log.add('action: adjust');
            },
          ),
        ],
      );
    }

    await tester.pumpWidget(new MaterialApp(
      home: buildTable(source),
    ));

    expect(find.text('Gingerbread (0)'), findsOneWidget);
    expect(find.text('Gingerbread (1)'), findsNothing);
    expect(find.text('42'), findsNWidgets(10));

    source.generation = 43;
    await tester.pump();

    expect(find.text('42'), findsNothing);
    expect(find.text('43'), findsNWidgets(10));

    source = new TestDataSource()
      ..generation = 15;

    await tester.pumpWidget(new MaterialApp(
      home: buildTable(source),
    ));

    expect(find.text('42'), findsNothing);
    expect(find.text('43'), findsNothing);
    expect(find.text('15'), findsNWidgets(10));

    PaginatedDataTableState state = tester.state(find.byType(PaginatedDataTable));

    expect(log, isEmpty);
    state.pageTo(23);
    expect(log, <String>['page-changed: 20']);
    log.clear();

    await tester.pump();

    expect(find.text('Gingerbread (0)'), findsNothing);
    expect(find.text('Gingerbread (1)'), findsNothing);
    expect(find.text('Gingerbread (2)'), findsOneWidget);

    await tester.tap(find.icon(Icons.adjust));
    expect(log, <String>['action: adjust']);
    log.clear();
  });

  testWidgets('PaginatedDataTable paging', (WidgetTester tester) async {
    TestDataSource source = new TestDataSource();

    List<String> log = <String>[];

    await tester.pumpWidget(new MaterialApp(
      home: new PaginatedDataTable(
        header: new Text('Test table'),
        source: source,
        rowsPerPage: 2,
        availableRowsPerPage: <int>[
          2, 4, 8, 16,
        ],
        onRowsPerPageChanged: (int rowsPerPage) {
          log.add('rows-per-page-changed: $rowsPerPage');
        },
        onPageChanged: (int rowIndex) {
          log.add('page-changed: $rowIndex');
        },
        columns: <DataColumn>[
          new DataColumn(label: new Text('Name')),
          new DataColumn(label: new Text('Calories'), numeric: true),
          new DataColumn(label: new Text('Generation')),
        ],
      )
    ));

    await tester.tap(find.byTooltip('Next page'));

    expect(log, <String>['page-changed: 2']);
    log.clear();

    await tester.pump();

    expect(find.text('Frozen yogurt (0)'), findsNothing);
    expect(find.text('Eclair (0)'), findsOneWidget);
    expect(find.text('Gingerbread (0)'), findsNothing);

    await tester.tap(find.icon(Icons.chevron_left));

    expect(log, <String>['page-changed: 0']);
    log.clear();

    await tester.pump();

    expect(find.text('Frozen yogurt (0)'), findsOneWidget);
    expect(find.text('Eclair (0)'), findsNothing);
    expect(find.text('Gingerbread (0)'), findsNothing);

    await tester.tap(find.icon(Icons.chevron_left));

    expect(log, isEmpty);

    await tester.tap(find.text('2'));
    await tester.pumpUntilNoTransientCallbacks(const Duration(milliseconds: 200));

    await tester.tap(find.text('8').last);
    await tester.pumpUntilNoTransientCallbacks(const Duration(milliseconds: 200));

    expect(log, <String>['rows-per-page-changed: 8']);
    log.clear();
  });
}
