// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:test/test.dart';

import '../common.dart';
import '../context.dart';

void main() {
  group('ensureDirectoryExists', () {
    MemoryFileSystem fs;

    setUp(() {
      fs = new MemoryFileSystem();
    });

    testUsingContext('recursively creates a directory if it does not exist', () async {
      ensureDirectoryExists('foo/bar/baz.flx');
      expect(fs.isDirectorySync('foo/bar'), true);
    }, overrides: <Type, Generator>{ FileSystem: () => fs } );

    testUsingContext('throws tool exit on failure to create', () async {
      fs.file('foo').createSync();
      expect(() => ensureDirectoryExists('foo/bar.flx'), throwsToolExit());
    }, overrides: <Type, Generator>{ FileSystem: () => fs } );
  });

  group('copyDirectorySync', () {
    /// Test file_systems.copyDirectorySync() using MemoryFileSystem.
    /// Copies between 2 instances of file systems which is also supported by copyDirectorySync().
    test('test directory copy', () async {
      MemoryFileSystem sourceMemoryFs = new MemoryFileSystem();
      String sourcePath = '/some/origin';
      Directory sourceDirectory = await sourceMemoryFs.directory(sourcePath).create(recursive: true);
      sourceMemoryFs.currentDirectory = sourcePath;
      File sourceFile1 = sourceMemoryFs.file('some_file.txt')..writeAsStringSync('bleh');
      DateTime writeTime = sourceFile1.lastModifiedSync();
      sourceMemoryFs.file('sub_dir/another_file.txt').createSync(recursive: true);
      sourceMemoryFs.directory('empty_directory').createSync();

      // Copy to another memory file system instance.
      MemoryFileSystem targetMemoryFs = new MemoryFileSystem();
      String targetPath = '/some/non-existent/target';
      Directory targetDirectory = targetMemoryFs.directory(targetPath);
      copyDirectorySync(sourceDirectory, targetDirectory);

      expect(targetDirectory.existsSync(), true);
      targetMemoryFs.currentDirectory = targetPath;
      expect(targetMemoryFs.directory('empty_directory').existsSync(), true);
      expect(targetMemoryFs.file('sub_dir/another_file.txt').existsSync(), true);
      expect(targetMemoryFs.file('some_file.txt').readAsStringSync(), 'bleh');

      // Assert that the copy operation hasn't modified the original file in some way.
      expect(sourceMemoryFs.file('some_file.txt').lastModifiedSync(), writeTime);
      // There's still 3 things in the original directory as there were initially.
      expect(sourceMemoryFs.directory(sourcePath).listSync().length, 3);
    });
  });
}
