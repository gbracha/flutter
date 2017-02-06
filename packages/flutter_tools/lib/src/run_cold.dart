// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:stack_trace/stack_trace.dart';

import 'application_package.dart';
import 'base/file_system.dart';
import 'base/utils.dart';
import 'build_info.dart';
import 'commands/trace.dart';
import 'device.dart';
import 'globals.dart';
import 'resident_runner.dart';

class ColdRunner extends ResidentRunner {
  ColdRunner(
    Device device, {
    String target,
    DebuggingOptions debuggingOptions,
    bool usesTerminalUI: true,
    this.traceStartup: false,
    this.applicationBinary,
    bool stayResident: true,
  }) : super(device,
             target: target,
             debuggingOptions: debuggingOptions,
             usesTerminalUI: usesTerminalUI,
             stayResident: stayResident);

  LaunchResult _result;
  final bool traceStartup;
  final String applicationBinary;

  bool get prebuiltMode => applicationBinary != null;

  @override
  Future<int> run({
    Completer<DebugConnectionInfo> connectionInfoCompleter,
    Completer<Null> appStartedCompleter,
    String route,
    bool shouldBuild: true
  }) {
    // Don't let uncaught errors kill the process.
    return Chain.capture(() {
      return _run(
        traceStartup: traceStartup,
        connectionInfoCompleter: connectionInfoCompleter,
        appStartedCompleter: appStartedCompleter,
        route: route,
        shouldBuild: shouldBuild
      );
    }, onError: (dynamic error, StackTrace stackTrace) {
      printError('Exception from flutter run: $error', stackTrace);
    });
  }

  Future<int> _run({
    bool traceStartup: false,
    Completer<DebugConnectionInfo> connectionInfoCompleter,
    Completer<Null> appStartedCompleter,
    String route,
    bool shouldBuild: true
  }) async {
    if (!prebuiltMode) {
      if (!fs.isFileSync(mainPath)) {
        String message = 'Tried to run $mainPath, but that file does not exist.';
        if (target == null)
          message += '\nConsider using the -t option to specify the Dart file to start.';
        printError(message);
        return 1;
      }
    }

    package = getApplicationPackageForPlatform(device.platform, applicationBinary: applicationBinary);

    if (package == null) {
      String message = 'No application found for ${device.platform}.';
      String hint = getMissingPackageHintForPlatform(device.platform);
      if (hint != null)
        message += '\n$hint';
      printError(message);
      return 1;
    }

    Stopwatch startTime = new Stopwatch()..start();

    Map<String, dynamic> platformArgs;
    if (traceStartup != null)
      platformArgs = <String, dynamic>{ 'trace-startup': traceStartup };

    await startEchoingDeviceLog(package);

    String modeName = getModeName(debuggingOptions.buildMode);
    if (mainPath == null) {
      assert(prebuiltMode);
      printStatus('Launching ${package.displayName} on ${device.name} in $modeName mode...');
    } else {
      printStatus('Launching ${getDisplayPath(mainPath)} on ${device.name} in $modeName mode...');
    }

    _result = await device.startApp(
      package,
      debuggingOptions.buildMode,
      mainPath: mainPath,
      debuggingOptions: debuggingOptions,
      platformArgs: platformArgs,
      route: route,
      prebuiltApplication: prebuiltMode,
      applicationNeedsRebuild: shouldBuild || hasDirtyDependencies()
    );

    if (!_result.started) {
      printError('Error running application on ${device.name}.');
      await stopEchoingDeviceLog();
      return 2;
    }

    startTime.stop();

    // Connect to observatory.
    if (debuggingOptions.debuggingEnabled) {
      await connectToServiceProtocol(_result.observatoryUri);
    }

    if (_result.hasObservatory) {
      connectionInfoCompleter?.complete(new DebugConnectionInfo(
        httpUri: _result.observatoryUri,
        wsUri: vmService.wsAddress,
      ));
    }

    printTrace('Application running.');

    if (vmService != null) {
      await vmService.vm.refreshViews();
      printTrace('Connected to ${vmService.vm.mainView}\.');
    }

    if (vmService != null && traceStartup) {
      printStatus('Downloading startup trace info...');
      try {
        await downloadStartupTrace(vmService);
      } catch(error) {
        printError(error);
        return 2;
      }
      appFinished();
    } else if (stayResident) {
      setupTerminal();
      registerSignalHandlers();
    }

    appStartedCompleter?.complete();

    if (stayResident)
      return waitForAppToFinish();
    await cleanupAtFinish();
    return 0;
  }

  @override
  Future<Null> handleTerminalCommand(String code) async => null;

  @override
  Future<Null> cleanupAfterSignal() async {
    await stopEchoingDeviceLog();
    await stopApp();
  }

  @override
  Future<Null> cleanupAtFinish() async {
    await stopEchoingDeviceLog();
  }

  @override
  void printHelp({ @required bool details }) {
    bool haveDetails = false;
    if (_result.hasObservatory)
      printStatus('The Observatory debugger and profiler is available at: ${_result.observatoryUri}');
    if (supportsServiceProtocol) {
      haveDetails = true;
      if (details)
        printHelpDetails();
    }
    if (haveDetails && !details) {
      printStatus('For a more detailed help message, press "h" or F1. To quit, press "q", F10, or Ctrl-C.');
    } else {
      printStatus('To repeat this help message, press "h" or F1. To quit, press "q", F10, or Ctrl-C.');
    }
  }

  @override
  Future<Null> preStop() async {
    // If we're running in release mode, stop the app using the device logic.
    if (vmService == null)
      await device.stopApp(package);
  }
}
