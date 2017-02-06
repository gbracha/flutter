// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:stream_channel/stream_channel.dart';

import 'package:test/src/backend/test_platform.dart'; // ignore: implementation_imports
import 'package:test/src/runner/plugin/platform.dart'; // ignore: implementation_imports
import 'package:test/src/runner/plugin/hack_register_platform.dart' as hack; // ignore: implementation_imports

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/process_manager.dart';
import '../dart/package_map.dart';
import '../globals.dart';
import 'coverage_collector.dart';

/// The timeout we give the test process to connect to the test harness
/// once the process has entered its main method.
const Duration _kTestStartupTimeout = const Duration(seconds: 5);

/// The timeout we give the test process to start executing Dart code. When the
/// CPU is under severe load, this can take a while, but it's not indicative of
/// any problem with Flutter, so we give it a large timeout.
const Duration _kTestProcessTimeout = const Duration(minutes: 5);

/// Message logged by the test process to signal that its main method has begun
/// execution.
///
/// The test harness responds by starting the [_kTestStartupTimeout] countdown.
/// The CPU may be throttled, which can cause a long delay in between when the
/// process is spawned and when dart code execution begins; we don't want to
/// hold that against the test.
const String _kStartTimeoutTimerMessage = 'sky_shell test process has entered main method';

/// The address at which our WebSocket server resides and at which the sky_shell
/// processes will host the Observatory server.
final InternetAddress _kHost = InternetAddress.LOOPBACK_IP_V4;

/// Configure the `test` package to work with Flutter.
///
/// On systems where each [_FlutterPlatform] is only used to run one test suite
/// (that is, one Dart file with a `*_test.dart` file name and a single `void
/// main()`), you can set an observatory port and a diagnostic port explicitly.
void installHook({
  @required String shellPath,
  CoverageCollector collector,
  bool debuggerMode: false,
  int observatoryPort,
  int diagnosticPort,
}) {
  hack.registerPlatformPlugin(
    <TestPlatform>[TestPlatform.vm],
    () => new _FlutterPlatform(
      shellPath: shellPath,
      collector: collector,
      debuggerMode: debuggerMode,
      explicitObservatoryPort: observatoryPort,
      explicitDiagnosticPort: diagnosticPort,
    ),
  );
}

enum _InitialResult { crashed, timedOut, connected }
enum _TestResult { crashed, harnessBailed, testBailed }
typedef Future<Null> _Finalizer();

class _FlutterPlatform extends PlatformPlugin {
  _FlutterPlatform({ this.shellPath, this.collector, this.debuggerMode, this.explicitObservatoryPort, this.explicitDiagnosticPort }) {
    assert(shellPath != null);
  }

  final String shellPath;
  final CoverageCollector collector;
  final bool debuggerMode;
  final int explicitObservatoryPort;
  final int explicitDiagnosticPort;

  // Each time loadChannel() is called, we spin up a local WebSocket server,
  // then spin up the engine in a subprocess. We pass the engine a Dart file
  // that connects to our WebSocket server, then we proxy JSON messages from
  // the test harness to the engine and back again. If at any time the engine
  // crashes, we inject an error into that stream. When the process closes,
  // we clean everything up.

  int _testCount = 0;

  @override
  StreamChannel<dynamic> loadChannel(String testPath, TestPlatform platform) {
    if (explicitObservatoryPort != null || explicitDiagnosticPort != null || debuggerMode) {
      if (_testCount > 0)
        throwToolExit('installHook() was called with an observatory port, a diagnostic port, both, or debugger mode enabled, but then more than one test suite was run.');
    }
    int ourTestCount = _testCount;
    _testCount += 1;
    StreamController<dynamic> localController = new StreamController<dynamic>();
    StreamController<dynamic> remoteController = new StreamController<dynamic>();
    Completer<Null> testCompleteCompleter = new Completer<Null>();
    _FlutterPlatformStreamSinkWrapper<dynamic> remoteSink = new _FlutterPlatformStreamSinkWrapper<dynamic>(
      remoteController.sink,
      testCompleteCompleter.future,
    );
    StreamChannel<dynamic> localChannel = new StreamChannel<dynamic>.withGuarantees(
      remoteController.stream,
      localController.sink,
    );
    StreamChannel<dynamic> remoteChannel = new StreamChannel<dynamic>.withGuarantees(
      localController.stream,
      remoteSink,
    );
    _startTest(testPath, localChannel, ourTestCount).whenComplete(() {
      testCompleteCompleter.complete();
    });
    return remoteChannel;
  }

  Future<Null> _startTest(String testPath, StreamChannel<dynamic> controller, int ourTestCount) async {
    printTrace('test $ourTestCount: starting test $testPath');

    final List<_Finalizer> finalizers = <_Finalizer>[];
    bool subprocessActive = false;
    bool controllerSinkClosed = false;
    try {
      controller.sink.done.whenComplete(() { controllerSinkClosed = true; });

      // Prepare our WebSocket server to talk to the engine subproces.
      HttpServer server = await HttpServer.bind(_kHost, 0);
      finalizers.add(() async {
        printTrace('test $ourTestCount: shutting down test harness socket server');
        await server.close(force: true);
      });
      Completer<WebSocket> webSocket = new Completer<WebSocket>();
      server.listen(
        (HttpRequest request) {
          webSocket.complete(WebSocketTransformer.upgrade(request));
        },
        onError: (dynamic error, dynamic stack) {
          // If you reach here, it's unlikely we're going to be able to really handle this well.
          printTrace('test $ourTestCount: test harness socket server experienced an unexpected error: $error');
          if (!controllerSinkClosed) {
            controller.sink.addError(error, stack);
            controller.sink.close();
          } else {
            printError('unexpected error from test harness socket server: $error');
          }
        },
        cancelOnError: true,
      );

      // Prepare a temporary directory to store the Dart file that will talk to us.
      Directory temporaryDirectory = fs.systemTempDirectory.createTempSync('dart_test_listener');
      finalizers.add(() async {
        printTrace('test $ourTestCount: deleting temporary directory');
        temporaryDirectory.deleteSync(recursive: true);
      });

      // Prepare the Dart file that will talk to us and start the test.
      File listenerFile = fs.file('${temporaryDirectory.path}/listener.dart');
      listenerFile.createSync();
      listenerFile.writeAsStringSync(_generateTestMain(
        testUrl: path.toUri(path.absolute(testPath)).toString(),
        encodedWebsocketUrl: Uri.encodeComponent("ws://${_kHost.address}:${server.port}"),
      ));

      // Start the engine subprocess.
      printTrace('test $ourTestCount: starting shell process');
      Process process = await _startProcess(
        shellPath,
        listenerFile.path,
        packages: PackageMap.globalPackagesPath,
        enableObservatory: collector != null || debuggerMode,
        startPaused: debuggerMode,
        observatoryPort: explicitObservatoryPort,
        diagnosticPort: explicitDiagnosticPort,
      );
      subprocessActive = true;
      finalizers.add(() async {
        if (subprocessActive) {
          printTrace('test $ourTestCount: ensuring end-of-process for shell');
          process.kill();
          final int exitCode = await process.exitCode;
          subprocessActive = false;
          if (!controllerSinkClosed && exitCode != -15) { // ProcessSignal.SIGTERM
            // We expect SIGTERM (15) because we tried to terminate it.
            // It's negative because signals are returned as negative exit codes.
            String message = _getErrorMessage(_getExitCodeMessage(exitCode, 'after tests finished'), testPath, shellPath);
            controller.sink.addError(message);
          }
        }
      });

      Completer<Null> timeout = new Completer<Null>();

      // Pipe stdout and stderr from the subprocess to our printStatus console.
      // We also keep track of what observatory port the engine used, if any.
      int processObservatoryPort;
      _pipeStandardStreamsToConsole(
        process,
        reportObservatoryPort: (int detectedPort) {
          assert(processObservatoryPort == null);
          assert(explicitObservatoryPort == null ||
                 explicitObservatoryPort == detectedPort);
          if (debuggerMode) {
            printStatus('The test process has been started.');
            printStatus('You can now connect to it using observatory. To connect, load the following Web site in your browser:');
            printStatus('  http://${_kHost.address}:$detectedPort/');
            printStatus('You should first set appropriate breakpoints, then resume the test in the debugger.');
          } else {
            printTrace('test $ourTestCount: using observatory port $detectedPort from pid ${process.pid} to collect coverage');
          }
          processObservatoryPort = detectedPort;
        },
        startTimeoutTimer: () {
          new Future<_InitialResult>.delayed(_kTestStartupTimeout, () => timeout.complete());
        },
      );

      // At this point, three things can happen next:
      // The engine could crash, in which case process.exitCode will complete.
      // The engine could connect to us, in which case webSocket.future will complete.
      // The local test harness could get bored of us.

      printTrace('test $ourTestCount: awaiting initial result for pid ${process.pid}');
      _InitialResult initialResult = await Future.any(<Future<_InitialResult>>[
        process.exitCode.then<_InitialResult>((int exitCode) => _InitialResult.crashed),
        timeout.future.then<_InitialResult>((Null _) => _InitialResult.timedOut),
        new Future<_InitialResult>.delayed(_kTestProcessTimeout, () => _InitialResult.timedOut),
        webSocket.future.then<_InitialResult>((WebSocket webSocket) => _InitialResult.connected),
      ]);

      switch (initialResult) {
        case _InitialResult.crashed:
          printTrace('test $ourTestCount: process with pid ${process.pid} crashed before connecting to test harness');
          int exitCode = await process.exitCode;
          subprocessActive = false;
          String message = _getErrorMessage(_getExitCodeMessage(exitCode, 'before connecting to test harness'), testPath, shellPath);
          controller.sink.addError(message);
          controller.sink.close();
          printTrace('test $ourTestCount: waiting for controller sink to close');
          await controller.sink.done;
          break;
        case _InitialResult.timedOut:
          printTrace('test $ourTestCount: timed out waiting for process with pid ${process.pid} to connect to test harness');
          String message = _getErrorMessage('Test never connected to test harness.', testPath, shellPath);
          controller.sink.addError(message);
          controller.sink.close();
          printTrace('test $ourTestCount: waiting for controller sink to close');
          await controller.sink.done;
          break;
        case _InitialResult.connected:
          printTrace('test $ourTestCount: process with pid ${process.pid} connected to test harness');
          WebSocket testSocket = await webSocket.future;

          Completer<Null> harnessDone = new Completer<Null>();
          StreamSubscription<dynamic> harnessToTest = controller.stream.listen(
            (dynamic event) { testSocket.add(JSON.encode(event)); },
            onDone: () { harnessDone.complete(); },
            onError: (dynamic error, dynamic stack) {
              // If you reach here, it's unlikely we're going to be able to really handle this well.
              printError('test harness controller stream experienced an unexpected error\ntest: $testPath\nerror: $error');
              if (!controllerSinkClosed) {
                controller.sink.addError(error, stack);
                controller.sink.close();
              } else {
                printError('unexpected error from test harness controller stream: $error');
              }
            },
            cancelOnError: true,
          );

          Completer<Null> testDone = new Completer<Null>();
          StreamSubscription<dynamic> testToHarness = testSocket.listen(
            (dynamic encodedEvent) {
              assert(encodedEvent is String); // we shouldn't ever get binary messages
              controller.sink.add(JSON.decode(encodedEvent));
            },
            onDone: () { testDone.complete(); },
            onError: (dynamic error, dynamic stack) {
              // If you reach here, it's unlikely we're going to be able to really handle this well.
              printError('test socket stream experienced an unexpected error\ntest: $testPath\nerror: $error');
              if (!controllerSinkClosed) {
                controller.sink.addError(error, stack);
                controller.sink.close();
              } else {
                printError('unexpected error from test socket stream: $error');
              }
            },
            cancelOnError: true,
          );

          printTrace('test $ourTestCount: awaiting test result for pid ${process.pid}');
          _TestResult testResult = await Future.any(<Future<_TestResult>>[
            process.exitCode.then<_TestResult>((int exitCode) { return _TestResult.crashed; }),
            harnessDone.future.then<_TestResult>((Null _) { return _TestResult.harnessBailed; }),
            testDone.future.then<_TestResult>((Null _) { return _TestResult.testBailed; }),
          ]);

          harnessToTest.cancel();
          testToHarness.cancel();

          switch (testResult) {
            case _TestResult.crashed:
              printTrace('test $ourTestCount: process with pid ${process.pid} crashed');
              int exitCode = await process.exitCode;
              subprocessActive = false;
              String message = _getErrorMessage(_getExitCodeMessage(exitCode, 'before test harness closed its WebSocket'), testPath, shellPath);
              controller.sink.addError(message);
              controller.sink.close();
              printTrace('test $ourTestCount: waiting for controller sink to close');
              await controller.sink.done;
              break;
            case _TestResult.harnessBailed:
              printTrace('test $ourTestCount: process with pid ${process.pid} no longer needed by test harness');
              break;
            case _TestResult.testBailed:
              printTrace('test $ourTestCount: process with pid ${process.pid} no longer needs test harness');
              break;
          }
          break;
      }

      if (subprocessActive && collector != null) {
        printTrace('test $ourTestCount: collecting coverage');
        await collector.collectCoverage(process, _kHost, processObservatoryPort);
      }
    } catch (error, stack) {
      printTrace('test $ourTestCount: error caught during test; ${controllerSinkClosed ? "reporting to console" : "sending to test framework"}');
      if (!controllerSinkClosed) {
        controller.sink.addError(error, stack);
      } else {
        printError('unhandled error during test:\n$testPath\n$error');
      }
    } finally {
      printTrace('test $ourTestCount: cleaning up...');
      for (_Finalizer finalizer in finalizers) {
        try {
          await finalizer();
        } catch (error, stack) {
          printTrace('test $ourTestCount: error while cleaning up; ${controllerSinkClosed ? "reporting to console" : "sending to test framework"}');
          if (!controllerSinkClosed) {
            controller.sink.addError(error, stack);
          } else {
            printError('unhandled error during finalization of test:\n$testPath\n$error');
          }
        }
      }
      if (!controllerSinkClosed) {
        controller.sink.close();
        printTrace('test $ourTestCount: waiting for controller sink to close');
        await controller.sink.done;
      }
    }
    assert(!subprocessActive);
    assert(controllerSinkClosed);
    printTrace('test $ourTestCount: finished');
    return null;
  }

  String _generateTestMain({
    String testUrl,
    String encodedWebsocketUrl,
  }) {
    return '''
import 'dart:convert';
import 'dart:io'; // ignore: dart_io_import

// We import this library first in order to trigger an import error for
// package:test (rather than package:stream_channel) when the developer forgets
// to add a dependency on package:test.
import 'package:test/src/runner/plugin/remote_platform_helpers.dart';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/src/runner/vm/catch_isolate_errors.dart';

import '$testUrl' as test;

void main() {
  print('$_kStartTimeoutTimerMessage');
  String server = Uri.decodeComponent('$encodedWebsocketUrl');
  StreamChannel channel = serializeSuite(() {
    catchIsolateErrors();
    return test.main;
  });
  WebSocket.connect(server).then((WebSocket socket) {
    socket.map(JSON.decode).pipe(channel.sink);
    socket.addStream(channel.stream.map(JSON.encode));
  });
}
''';
  }

  File _cachedFontConfig;

  /// Returns a Fontconfig config file that limits font fallback to the
  /// artifact cache directory.
  File get _fontConfigFile {
    if (_cachedFontConfig != null)
      return _cachedFontConfig;

    StringBuffer sb = new StringBuffer();
    sb.writeln('<fontconfig>');
    sb.writeln('  <dir>${cache.getCacheArtifacts().path}</dir>');
    sb.writeln('  <cachedir>/var/cache/fontconfig</cachedir>');
    sb.writeln('</fontconfig>');

    Directory fontsDir = fs.systemTempDirectory.createTempSync('flutter_fonts');
    _cachedFontConfig = fs.file('${fontsDir.path}/fonts.conf');
    _cachedFontConfig.createSync();
    _cachedFontConfig.writeAsStringSync(sb.toString());
    return _cachedFontConfig;
  }

  Future<Process> _startProcess(
    String executable,
    String testPath, {
    String packages,
    bool enableObservatory: false,
    bool startPaused: false,
    int observatoryPort,
    int diagnosticPort,
  }) {
    assert(executable != null); // Please provide the path to the shell in the SKY_SHELL environment variable.
    assert(!startPaused || enableObservatory);
    List<String> command = <String>[executable];
    if (enableObservatory) {
      // Some systems drive the _FlutterPlatform class in an unusual way, where
      // only one test file is processed at a time, and the operating
      // environment hands out specific ports ahead of time in a cooperative
      // manner, where we're only allowed to open ports that were given to us in
      // advance like this. For those esoteric systems, we have this feature
      // whereby you can create _FlutterPlatform with a pair of ports.
      //
      // I mention this only so that you won't be tempted, as I was, to apply
      // the obvious simplification to this code and remove this entire feature.
      if (observatoryPort != null)
        command.add('--observatory-port=$observatoryPort');
      if (diagnosticPort != null)
        command.add('--diagnostic-port=$diagnosticPort');
      if (startPaused)
        command.add('--start-paused');
    } else {
      command.addAll(<String>['--disable-observatory', '--disable-diagnostic']);
    }
    command.addAll(<String>[
      '--enable-dart-profiling',
      '--non-interactive',
      '--enable-checked-mode',
      '--use-test-fonts',
      '--packages=$packages',
      testPath,
    ]);
    printTrace(command.join(' '));
    Map<String, String> environment = <String, String>{
      'FLUTTER_TEST': 'true',
      'FONTCONFIG_FILE': _fontConfigFile.path,
    };
    return processManager.start(command, environment: environment);
  }

  String get observatoryPortString => 'Observatory listening on http://${_kHost.address}:';
  String get diagnosticPortString => 'Diagnostic server listening on http://${_kHost.address}:';

  void _pipeStandardStreamsToConsole(
    Process process, {
    void startTimeoutTimer(),
    void reportObservatoryPort(int port),
  }) {
    for (Stream<List<int>> stream in
        <Stream<List<int>>>[process.stderr, process.stdout]) {
      stream.transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen(
          (String line) {
            if (line == _kStartTimeoutTimerMessage) {
              if (startTimeoutTimer != null)
                startTimeoutTimer();
            } else if (line.startsWith('error: Unable to read Dart source \'package:test/')) {
              printTrace('Shell: $line');
              printError('\n\nFailed to load test harness. Are you missing a dependency on flutter_test?\n');
            } else if (line.startsWith(observatoryPortString)) {
              printTrace('Shell: $line');
              try {
                int port = int.parse(line.substring(observatoryPortString.length, line.length - 1)); // last character is a slash
                if (reportObservatoryPort != null)
                  reportObservatoryPort(port);
              } catch (error) {
                printError('Could not parse shell observatory port message: $error');
              }
            } else if (line.startsWith(diagnosticPortString)) {
              printTrace('Shell: $line');
            } else if (line != null) {
              printStatus('Shell: $line');
            }
          },
          onError: (dynamic error) {
            printError('shell console stream for process pid ${process.pid} experienced an unexpected error: $error');
          },
          cancelOnError: true,
        );
    }
  }

  String _getErrorMessage(String what, String testPath, String shellPath) {
    return '$what\nTest: $testPath\nShell: $shellPath\n\n';
  }

  String _getExitCodeMessage(int exitCode, String when) {
    switch (exitCode) {
      case 1:
        return 'Shell subprocess cleanly reported an error $when. Check the logs above for an error message.';
      case 0:
        return 'Shell subprocess ended cleanly $when. Did main() call exit()?';
      case -0x0f: // ProcessSignal.SIGTERM
        return 'Shell subprocess crashed with SIGTERM ($exitCode) $when.';
      case -0x0b: // ProcessSignal.SIGSEGV
        return 'Shell subprocess crashed with segmentation fault $when.';
      case -0x06: // ProcessSignal.SIGABRT
        return 'Shell subprocess crashed with SIGABRT ($exitCode) $when.';
      case -0x02: // ProcessSignal.SIGINT
        return 'Shell subprocess terminated by ^C (SIGINT, $exitCode) $when.';
      default:
        return 'Shell subprocess crashed with unexpected exit code $exitCode $when.';
    }
  }
}

class _FlutterPlatformStreamSinkWrapper<S> implements StreamSink<S> {
  _FlutterPlatformStreamSinkWrapper(this._parent, this._shellProcessClosed);
  final StreamSink<S> _parent;
  final Future<Null> _shellProcessClosed;

  @override
  Future<Null> get done => _done.future;
  final Completer<Null> _done = new Completer<Null>();

  @override
  Future<dynamic> close() {
   Future.wait<dynamic>(<Future<dynamic>>[
      _parent.close(),
      _shellProcessClosed,
    ]).then<Null>(
      (List<dynamic> value) {
        _done.complete();
      },
      onError: (dynamic error, StackTrace stack) {
        _done.completeError(error, stack);
      },
    );
    return done;
  }

  @override
  void add(S event) => _parent.add(event);
  @override
  void addError(dynamic errorEvent, [ StackTrace stackTrace ]) => _parent.addError(errorEvent, stackTrace);
  @override
  Future<dynamic> addStream(Stream<S> stream) => _parent.addStream(stream);
}
