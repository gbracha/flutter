// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:test/src/executable.dart' as test; // ignore: implementation_imports

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/platform.dart';
import '../base/process_manager.dart';
import '../base/os.dart';
import '../cache.dart';
import '../dart/package_map.dart';
import '../globals.dart';
import '../runner/flutter_command.dart';
import '../test/coverage_collector.dart';
import '../test/flutter_platform.dart' as loader;
import '../toolchain.dart';

class TestCommand extends FlutterCommand {
  TestCommand() {
    usesPubOption();
    argParser.addFlag('start-paused',
        defaultsTo: false,
        negatable: false,
        help: 'Start in a paused mode and wait for a debugger to connect.\n'
              'You must specify a single test file to run, explicitly.\n'
              'Instructions for connecting with a debugger and printed to the\n'
              'console once the test has started.'
    );
    argParser.addFlag('coverage',
      defaultsTo: false,
      negatable: false,
      help: 'Whether to collect coverage information.'
    );
    argParser.addFlag('merge-coverage',
      defaultsTo: false,
      negatable: false,
      help: 'Whether to merge converage data with "coverage/lcov.base.info".\n'
            'Implies collecting coverage data. (Requires lcov)'
    );
    argParser.addOption('coverage-path',
      defaultsTo: 'coverage/lcov.info',
      help: 'Where to store coverage information (if coverage is enabled).'
    );
    commandValidator = () {
      if (!fs.isFileSync('pubspec.yaml')) {
        throwToolExit(
          'Error: No pubspec.yaml file found in the current working directory.\n'
          'Run this command from the root of your project. Test files must be\n'
          'called *_test.dart and must reside in the package\'s \'test\'\n'
          'directory (or one of its subdirectories).');
      }
    };
  }

  @override
  String get name => 'test';

  @override
  String get description => 'Run Flutter unit tests for the current project.';

  Iterable<String> _findTests(Directory directory) {
    return directory.listSync(recursive: true, followLinks: false)
                    .where((FileSystemEntity entity) => entity.path.endsWith('_test.dart') &&
                      fs.isFileSync(entity.path))
                    .map((FileSystemEntity entity) => path.absolute(entity.path));
  }

  Directory get _currentPackageTestDir {
    // We don't scan the entire package, only the test/ subdirectory, so that
    // files with names like like "hit_test.dart" don't get run.
    return fs.directory('test');
  }

  Future<int> _runTests(List<String> testArgs, Directory testDirectory) async {
    Directory currentDirectory = fs.currentDirectory;
    try {
      if (testDirectory != null) {
        printTrace('switching to directory $testDirectory to run tests');
        PackageMap.globalPackagesPath = path.normalize(path.absolute(PackageMap.globalPackagesPath));
        fs.currentDirectory = testDirectory;
      }
      printTrace('running test package with arguments: $testArgs');
      await test.main(testArgs);
      // test.main() sets dart:io's exitCode global.
      printTrace('test package returned with exit code $exitCode');
      return exitCode;
    } finally {
      fs.currentDirectory = currentDirectory;
    }
  }

  Future<bool> _collectCoverageData(CoverageCollector collector, { bool mergeCoverageData: false }) async {
    Status status = logger.startProgress('Collecting coverage information...');
    String coverageData = await collector.finalizeCoverage(
      timeout: new Duration(seconds: 30),
    );
    status.stop();
    printTrace('coverage information collection complete');
    if (coverageData == null)
      return false;

    String coveragePath = argResults['coverage-path'];
    File coverageFile = fs.file(coveragePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(coverageData, flush: true);
    printTrace('wrote coverage data to $coveragePath (size=${coverageData.length})');

    String baseCoverageData = 'coverage/lcov.base.info';
    if (mergeCoverageData) {
      if (!os.isLinux) {
        printError(
          'Merging coverage data is supported only on Linux because it '
          'requires the "lcov" tool.'
        );
        return false;
      }

      if (!fs.isFileSync(baseCoverageData)) {
        printError('Missing "$baseCoverageData". Unable to merge coverage data.');
        return false;
      }

      if (os.which('lcov') == null) {
        String installMessage = 'Please install lcov.';
        if (os.isLinux)
          installMessage = 'Consider running "sudo apt-get install lcov".';
        else if (os.isMacOS)
          installMessage = 'Consider running "brew install lcov".';
        printError('Missing "lcov" tool. Unable to merge coverage data.\n$installMessage');
        return false;
      }

      Directory tempDir = fs.systemTempDirectory.createTempSync('flutter_tools');
      try {
        File sourceFile = coverageFile.copySync(path.join(tempDir.path, 'lcov.source.info'));
        ProcessResult result = processManager.runSync(<String>[
          'lcov',
          '--add-tracefile', baseCoverageData,
          '--add-tracefile', sourceFile.path,
          '--output-file', coverageFile.path,
        ]);
        if (result.exitCode != 0)
          return false;
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }
    return true;
  }

  @override
  Future<Null> runCommand() async {
    List<String> testArgs = <String>[];

    commandValidator();

    if (!terminal.supportsColor)
      testArgs.addAll(<String>['--no-color', '-rexpanded']);

    CoverageCollector collector;
    if (argResults['coverage'] || argResults['merge-coverage']) {
      collector = new CoverageCollector();
      testArgs.add('--concurrency=1');
    }

    testArgs.add('--');

    Directory testDir;
    Iterable<String> files = argResults.rest.map((String testPath) => path.absolute(testPath)).toList();
    if (argResults['start-paused']) {
      if (files.length != 1)
        throwToolExit('When using --start-paused, you must specify a single test file to run.', exitCode: 1);
    } else if (files.isEmpty) {
      testDir = _currentPackageTestDir;
      if (!testDir.existsSync())
        throwToolExit('Test directory "${testDir.path}" not found.');
      files = _findTests(testDir);
      if (files.isEmpty) {
        throwToolExit(
          'Test directory "${testDir.path}" does not appear to contain any test files.\n'
          'Test files must be in that directory and end with the pattern "_test.dart".'
        );
      }
    }
    testArgs.addAll(files);

    final String shellPath = tools.getHostToolPath(HostTool.SkyShell) ?? platform.environment['SKY_SHELL'];
    if (!fs.isFileSync(shellPath))
      throwToolExit('Cannot find Flutter shell at $shellPath');
    loader.installHook(shellPath: shellPath, collector: collector, debuggerMode: argResults['start-paused']);

    Cache.releaseLockEarly();

    int result = await _runTests(testArgs, testDir);

    if (collector != null) {
      if (!await _collectCoverageData(collector, mergeCoverageData: argResults['merge-coverage']))
        throwToolExit(null);
    }

    if (result != 0)
      throwToolExit(null);
  }
}
