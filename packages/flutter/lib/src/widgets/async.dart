// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Widgets that handle interaction with asynchronous computations.
///
/// Asynchronous computations are represented by [Future]s and [Stream]s.

import 'dart:async' show Future, Stream, StreamSubscription;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart' show required;

/// Base class for widgets that build themselves based on interaction with
/// a specified [Stream].
///
/// A [StreamBuilderBase] is stateful and maintains a summary of the interaction
/// so far. The type of the summary and how it is updated with each interaction
/// is defined by sub-classes.
///
/// Examples of summaries include:
///
/// * the running average of a stream of integers;
/// * the current direction and speed based on a stream of geolocation data;
/// * a graph displaying data points from a stream.
///
/// In general, the summary is the result of a fold computation over the data
/// items and errors received from the stream along with pseudo-events
/// representing termination or change of stream. The initial summary is
/// specified by sub-classes by overriding [initial]. The summary updates on
/// receipt of stream data and errors are specified by overriding [afterData] and
/// [afterError], respectively. If needed, the summary may be updated on stream
/// termination by overriding [afterDone]. Finally, the summary may be updated
/// on change of stream by overriding [afterConnected] and [afterConnected].
///
/// [T] is the type of stream events.
/// [S] is the type of interaction summary.
///
/// See also:
///
///  * [StreamBuilder], which is specialized to the case where only the most
///  recent interaction is needed for widget building.
abstract class StreamBuilderBase<T, S> extends StatefulWidget {
  /// Creates a [StreamBuilderBase] connected to the specified [stream].
  StreamBuilderBase({ Key key, this.stream }) : super(key: key);

  /// The asynchronous computation to which this builder is currently connected,
  /// possibly `null`. When changed, the current summary is updated using
  /// [afterDisconnecting], if the previous stream was not `null`, followed by
  /// [afterConnecting], if the new stream is not `null`.
  final Stream<T> stream;

  /// Returns the initial summary of stream interaction, typically representing
  /// the fact that no interaction has happened at all.
  ///
  /// Sub-classes must override this method to provide the initial value for
  /// the fold computation.
  S initial();

  /// Returns an updated version of the [current] summary reflecting that we
  /// are now connected to a stream.
  ///
  /// The default implementation returns [current] as is.
  S afterConnected(S current) => current;

  /// Returns an updated version of the [current] summary following a data event.
  ///
  /// Sub-classes must override this method to specify how the current summary
  /// is combined with the new data item in the fold computation.
  S afterData(S current, T data);

  /// Returns an updated version of the [current] summary following an error.
  ///
  /// The default implementation returns [current] as is.
  S afterError(S current, Object error) => current;

  /// Returns an updated version of the [current] summary following stream
  /// termination.
  ///
  /// The default implementation returns [current] as is.
  S afterDone(S current) => current;

  /// Returns an updated version of the [current] summary reflecting that we
  /// are no longer connected to a stream.
  ///
  /// The default implementation returns [current] as is.
  S afterDisconnected(S current) => current;

  /// Returns a Widget based on the [currentSummary].
  Widget build(BuildContext context, S currentSummary);

  @override
  State<StreamBuilderBase<T, S>> createState() => new _StreamBuilderBaseState<T, S>();
}

/// State for [StreamBuilderBase].
class _StreamBuilderBaseState<T, S> extends State<StreamBuilderBase<T, S>> {
  StreamSubscription<T> _subscription;
  S _summary;

  @override
  void initState() {
    super.initState();
    _summary = config.initial();
    _subscribe();
  }

  @override
  void didUpdateConfig(StreamBuilderBase<T, S> oldConfig) {
    if (oldConfig.stream != config.stream) {
      if (_subscription != null) {
        _unsubscribe();
        _summary = config.afterDisconnected(_summary);
      }
      _subscribe();
    }
  }

  @override
  Widget build(BuildContext context) => config.build(context, _summary);

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    if (config.stream != null) {
      _subscription = config.stream.listen((T data) {
        setState(() {
          _summary = config.afterData(_summary, data);
        });
      }, onError: (Object error) {
        setState(() {
          _summary = config.afterError(_summary, error);
        });
      }, onDone: () {
        setState(() {
          _summary = config.afterDone(_summary);
        });
      });
      _summary = config.afterConnected(_summary);
    }
  }

  void _unsubscribe() {
    if (_subscription != null) {
      _subscription.cancel();
      _subscription = null;
    }
  }
}

/// The state of connection to an asynchronous computation.
///
/// See also:
///
/// * [AsyncSnapshot], which augments a connection state with information
/// received from the asynchronous computation.
enum ConnectionState {
  /// Not currently connected to any asynchronous computation.
  none,

  /// Connected to an asynchronous computation and awaiting interaction.
  waiting,

  /// Connected to an active asynchronous computation.
  active,

  /// Connected to a terminated asynchronous computation.
  done,
}

/// Immutable representation of the most recent interaction with an asynchronous
/// computation.
///
/// See also:
///
/// * [StreamBuilder], which builds itself based on a snapshot from interacting
/// with a [Stream].
/// * [FutureBuilder], which builds itself based on a snapshot from interacting
/// with a [Future].
class AsyncSnapshot<T> {
  /// Creates an [AsyncSnapshot] with the specified [connectionState],
  /// and optionally either [data] or [error] (but not both).
  AsyncSnapshot._(this.connectionState, this.data, this.error) {
    assert(connectionState != null);
    assert(data == null || error == null);
  }

  /// Creates an [AsyncSnapshot] in [ConnectionState.none] with `null` data and error.
  AsyncSnapshot.nothing() : this._(ConnectionState.none, null, null);

  /// Creates an [AsyncSnapshot] in the specified [state] and with the specified [data].
  AsyncSnapshot.withData(ConnectionState state, T data) : this._(state, data, null);

  /// Creates an [AsyncSnapshot] in the specified [state] and with the specified [error].
  AsyncSnapshot.withError(ConnectionState state, Object error) : this._(state, null, error);

  /// Current state of connection to the asynchronous computation.
  final ConnectionState connectionState;

  /// Latest data received. Is `null`, if [error] is not.
  final T data;

  /// Latest error object received. Is `null`, if [data] is not.
  final Object error;

  /// Returns a snapshot like this one, but in the specified [state].
  AsyncSnapshot<T> inState(ConnectionState state) => new AsyncSnapshot<T>._(state, data, error);

  /// Returns whether this snapshot contains a non-`null` data value.
  bool get hasData => data != null;

  /// Returns whether this snapshot contains a non-`null` error value.
  bool get hasError => error != null;

  @override
  String toString() => 'AsyncSnapshot($connectionState, $data, $error)';

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (other is! AsyncSnapshot<T>)
      return false;
    final AsyncSnapshot<T> typedOther = other;
    return connectionState == typedOther.connectionState
        && data == typedOther.data
        && error == typedOther.error;
  }

  @override
  int get hashCode => hashValues(connectionState, data, error);
}

/// Signature for strategies that build widgets based on asynchronous
/// interaction.
///
/// See also:
///
/// * [StreamBuilder], which delegates to an [AsyncWidgetBuilder] to build
/// itself based on a snapshot from interacting with a [Stream].
/// * [FutureBuilder], which delegates to an [AsyncWidgetBuilder] to build
/// itself based on a snapshot from interacting with a [Future].
typedef Widget AsyncWidgetBuilder<T>(BuildContext context, AsyncSnapshot<T> snapshot);

/// Widget that builds itself based on the latest snapshot of interaction with
/// a [Stream].
///
/// Widget rebuilding is scheduled by each interaction, using [State.setState],
/// but is otherwise decoupled from the timing of the stream. The [build] method
/// is called at the discretion of the Flutter pipeline, and will thus receive a
/// timing-dependent sub-sequence of the snapshots that represent the
/// interaction with the stream.
///
/// As an example, when interacting with a stream producing the integers
/// 0 through 9, the [build] method may be called with any ordered sub-sequence
/// of the following snapshots that includes the last one (the one with
/// ConnectionState.done):
///
/// * `new AsyncSnapshot<int>(ConnectionState.waiting, null, null)`
/// * `new AsyncSnapshot<int>(ConnectionState.active, 0, null)`
/// * `new AsyncSnapshot<int>(ConnectionState.active, 1, null)`
/// * ...
/// * `new AsyncSnapshot<int>(ConnectionState.active, 9, null)`
/// * `new AsyncSnapshot<int>(ConnectionState.done, 9, null)`
///
/// The actual sequence of invocations of [build] depends on the relative timing
/// of events produced by the stream and the build rate of the Flutter pipeline.
///
/// Changing the [StreamBuilder] configuration to another stream during event
/// generation introduces snapshot pairs of the form
///
/// * `new AsyncSnapshot<int>(ConnectionState.none, 5, null)`
/// * `new AsyncSnapshot<int>(ConnectionState.waiting, 5, null)`
///
/// The latter will be produced only when the new stream is non-`null`. The former
/// only when the old stream is non-`null`.
///
/// The stream may produce errors, resulting in snapshots of the form
///
/// * `new AsyncSnapshot<int>(ConnectionState.active, null, 'some error')`
///
/// The data and error fields of snapshots produced are only changed when the
/// state is `ConnectionState.active`.
///
/// See also:
///
/// * [StreamBuilderBase], which supports widget building based on a computation
/// that spans all interactions made with the stream.
class StreamBuilder<T> extends StreamBuilderBase<T, AsyncSnapshot<T>> {
  /// Creates a new [StreamBuilder] that builds itself based on the latest
  /// snapshot of interaction with the specified [stream] and whose build
  /// strategy is given by [builder].
  StreamBuilder({
    Key key,
    Stream<T> stream,
    @required this.builder
  }) : super(key: key, stream: stream) {
    assert(builder != null);
  }

  /// The build strategy currently used by this builder. Cannot be `null`.
  final AsyncWidgetBuilder<T> builder;

  @override
  AsyncSnapshot<T> initial() => new AsyncSnapshot<T>.nothing();

  @override
  AsyncSnapshot<T> afterConnected(AsyncSnapshot<T> current) => current.inState(ConnectionState.waiting);

  @override
  AsyncSnapshot<T> afterData(AsyncSnapshot<T> current, T data) {
    return new AsyncSnapshot<T>.withData(ConnectionState.active, data);
  }

  @override
  AsyncSnapshot<T> afterError(AsyncSnapshot<T> current, Object error) {
    return new AsyncSnapshot<T>.withError(ConnectionState.active, error);
  }

  @override
  AsyncSnapshot<T> afterDone(AsyncSnapshot<T> current) => current.inState(ConnectionState.done);

  @override
  AsyncSnapshot<T> afterDisconnected(AsyncSnapshot<T> current) => current.inState(ConnectionState.none);

  @override
  Widget build(BuildContext context, AsyncSnapshot<T> currentSummary) => builder(context, currentSummary);
}

/// Widget that builds itself based on the latest snapshot of interaction with
/// a [Future].
///
/// Widget rebuilding is scheduled by the completion of the future, using
/// [State.setState], but is otherwise decoupled from the timing of the future.
/// The [build] method is called at the discretion of the Flutter pipeline, and
/// will thus receive a timing-dependent sub-sequence of the snapshots that
/// represent the interaction with the future.
///
/// For a future that completes successfully with data, the [build] method may
/// be called with either both or only the latter of the following snapshots:
///
/// * `new AsyncSnapshot<String>(ConnectionState.waiting, null, null)`
/// * `new AsyncSnapshot<String>(ConnectionState.done, 'some data', null)`
///
/// For a future completing with an error, the [build] method may be called with
/// either both or only the latter of:
///
/// * `new AsyncSnapshot<String>(ConnectionState.waiting, null, null)`
/// * `new AsyncSnapshot<String>(ConnectionState.done, null, 'some error')`
///
/// The data and error fields of the snapshot change only as the connection
/// state field transitions from `waiting` to `done`, and they will be retained
/// when changing the [FutureBuilder] configuration to another future. If the
/// old future has already completed successfully with data as above, changing
/// configuration to a new future results in snapshot pairs of the form:
///
/// * `new AsyncSnapshot<String>(ConnectionState.none, 'some data', null)`
/// * `new AsyncSnapshot<String>(ConnectionState.waiting, 'some data', null)`
///
/// In general, the latter will be produced only when the new future is
/// non-`null`. The former only when the old future is non-`null`.
///
/// A [FutureBuilder] behaves identically to a [StreamBuilder] configured with
/// `future?.asStream()`, except that snapshots with `ConnectionState.active`
/// may appear for the latter, depending on how the stream is implemented.
class FutureBuilder<T> extends StatefulWidget {
  FutureBuilder({
    Key key,
    this.future,
    @required this.builder
  }) : super(key: key) {
    assert(builder != null);
  }

  /// The asynchronous computation to which this builder is currently connected,
  /// possibly `null`.
  final Future<T> future;

  /// The build strategy currently used by this builder. Cannot be `null`.
  final AsyncWidgetBuilder<T> builder;

  @override
  State<FutureBuilder<T>> createState() => new _FutureBuilderState<T>();
}

/// State for [FutureBuilder].
class _FutureBuilderState<T> extends State<FutureBuilder<T>> {
  /// An object that identifies the currently active callbacks. Used to avoid
  /// calling setState from stale callbacks, e.g. after disposal of this state,
  /// or after widget reconfiguration to a new Future.
  Object _activeCallbackIdentity;
  AsyncSnapshot<T> _snapshot = new AsyncSnapshot<T>.nothing();

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateConfig(FutureBuilder<T> oldConfig) {
    if (oldConfig.future != config.future) {
      if (_activeCallbackIdentity != null) {
        _unsubscribe();
        _snapshot = _snapshot.inState(ConnectionState.none);
      }
      _subscribe();
    }
  }

  @override
  Widget build(BuildContext context) => config.builder(context, _snapshot);

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    if (config.future != null) {
      final Object callbackIdentity = new Object();
      _activeCallbackIdentity = callbackIdentity;
      config.future.then<Null>((T data) {
        if (_activeCallbackIdentity == callbackIdentity) {
          setState(() {
            _snapshot = new AsyncSnapshot<T>.withData(ConnectionState.done, data);
          });
        }
      }, onError: (Object error) {
        if (_activeCallbackIdentity == callbackIdentity) {
          setState(() {
            _snapshot = new AsyncSnapshot<T>.withError(ConnectionState.done, error);
          });
        }
      });
      _snapshot = _snapshot.inState(ConnectionState.waiting);
    }
  }

  void _unsubscribe() {
    _activeCallbackIdentity = null;
  }
}
