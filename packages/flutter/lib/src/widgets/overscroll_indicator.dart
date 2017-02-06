// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async' show Timer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class GlowingOverscrollIndicator extends StatefulWidget {
  GlowingOverscrollIndicator({
    Key key,
    this.showLeading: true,
    this.showTrailing: true,
    @required this.axisDirection,
    @required this.color,
    this.child,
  }) : super(key: key) {
    assert(showLeading != null);
    assert(showTrailing != null);
    assert(axisDirection != null);
    assert(color != null);
  }

  /// Whether to show the overscroll glow on the side with negative scroll
  /// offsets.
  ///
  /// For a vertical downwards viewport, this is the top side.
  ///
  /// Defaults to true.
  ///
  /// See [showTrailing] for the corresponding control on the other side of the
  /// viewport.
  final bool showLeading;

  /// Whether to show the overscroll glow on the side with positive scroll
  /// offsets.
  ///
  /// For a vertical downwards viewport, this is the bottom side.
  ///
  /// Defaults to true.
  ///
  /// See [showLeading] for the corresponding control on the other side of the
  /// viewport.
  final bool showTrailing;

  /// The direction of positive scroll offsets in the viewport of the
  /// [Scrollable2] whose overscrolls are to be visualized.
  final AxisDirection axisDirection;

  Axis get axis => axisDirectionToAxis(axisDirection);

  /// The color of the glow. The alpha channel is ignored.
  final Color color;

  /// The subtree to place inside the overscroll indicator. This should include
  /// a source of [ScrollNotification2] notifications, typically a [Scrollable2]
  /// widget.
  ///
  /// Typically a [GlowingOverscrollIndicator] is created by a
  /// [ScrollBehavior2.buildViewportChrome] method, in which case
  /// the child is usually the one provided as an argument to that method.
  final Widget child;

  @override
  _GlowingOverscrollIndicatorState createState() => new _GlowingOverscrollIndicatorState();

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('$axisDirection');
    if (showLeading && showTrailing) {
      description.add('show: both sides');
    } else if (showLeading) {
      description.add('show: leading side only');
    } else if (showTrailing) {
      description.add('show: trailing side only');
    } else {
      description.add('show: neither side (!)');
    }
    description.add('$color');
  }
}

class _GlowingOverscrollIndicatorState extends State<GlowingOverscrollIndicator> with TickerProviderStateMixin {
  _GlowController _leadingController;
  _GlowController _trailingController;

  @override
  void initState() {
    super.initState();
    _leadingController = new _GlowController(vsync: this, color: config.color, axis: config.axis);
    _trailingController = new _GlowController(vsync: this, color: config.color, axis: config.axis);
  }

  @override
  void didUpdateConfig(GlowingOverscrollIndicator oldConfig) {
    if (oldConfig.color != config.color || oldConfig.axis != config.axis) {
      _leadingController.color = config.color;
      _leadingController.axis = config.axis;
      _trailingController.color = config.color;
      _trailingController.axis = config.axis;
    }
  }

  bool _handleScrollNotification(ScrollNotification2 notification) {
    if (notification is OverscrollNotification) {
      _GlowController controller;
      if (notification.overscroll < 0.0) {
        controller = _leadingController;
      } else if (notification.overscroll > 0.0) {
        controller = _trailingController;
      } else {
        assert(false);
      }
      assert(controller != null);
      assert(notification.axis == config.axis);
      if (notification.velocity != 0.0) {
        assert(notification.dragDetails == null);
        controller.absorbImpact(notification.velocity.abs());
      } else {
        assert(notification.overscroll != 0.0);
        if (notification.dragDetails != null) {
          assert(notification.dragDetails.globalPosition != null);
          final RenderBox renderer = notification.context.findRenderObject();
          assert(renderer != null);
          assert(renderer.hasSize);
          final Size size = renderer.size;
          final Point position = renderer.globalToLocal(notification.dragDetails.globalPosition);
          switch (notification.axis) {
            case Axis.horizontal:
              controller.pull(notification.overscroll.abs(), size.width, position.y.clamp(0.0, size.height), size.height);
              break;
            case Axis.vertical:
              controller.pull(notification.overscroll.abs(), size.height, position.x.clamp(0.0, size.width), size.width);
              break;
          }
        }
      }
    } else if (notification is ScrollEndNotification || notification is ScrollUpdateNotification) {
      if (notification.dragDetails != null) { // ignore: undefined_getter
        _leadingController.scrollEnd();
        _trailingController.scrollEnd();
      }
    }
    return false;
  }

  @override
  void dispose() {
    _leadingController.dispose();
    _trailingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new NotificationListener<ScrollNotification2>(
      onNotification: _handleScrollNotification,
      child: new RepaintBoundary(
        child: new CustomPaint(
          foregroundPainter: new _GlowingOverscrollIndicatorPainter(
            leadingController: config.showLeading ? _leadingController : null,
            trailingController: config.showTrailing ? _trailingController : null,
            axisDirection: config.axisDirection,
          ),
          child: new RepaintBoundary(
            child: config.child,
          ),
        ),
      ),
    );
  }
}

// The Glow logic is a port of the logic in the following file:
// https://android.googlesource.com/platform/frameworks/base/+/master/core/java/android/widget/EdgeEffect.java
// as of December 2016.

enum _GlowState { idle, absorb, pull, recede }

class _GlowController extends ChangeNotifier {
  _GlowController({
    TickerProvider vsync,
    @required Color color,
    @required Axis axis,
  }) : _color = color,
       _axis = axis {
    assert(vsync != null);
    assert(color != null);
    assert(axis != null);
    _glowController = new AnimationController(vsync: vsync)
      ..addStatusListener(_changePhase);
    Animation<double> decelerator = new CurvedAnimation(
      parent: _glowController,
      curve: Curves.decelerate,
    )..addListener(notifyListeners);
    _glowOpacity = _glowOpacityTween.animate(decelerator);
    _glowSize = _glowSizeTween.animate(decelerator);
    _displacementTicker = vsync.createTicker(_tickDisplacement);
  }

  // animation of the main axis direction
  _GlowState _state = _GlowState.idle;
  AnimationController _glowController;
  Timer _pullRecedeTimer;

  // animation values
  final Tween<double> _glowOpacityTween = new Tween<double>(begin: 0.0, end: 0.0);
  Animation<double> _glowOpacity;
  final Tween<double> _glowSizeTween = new Tween<double>(begin: 0.0, end: 0.0);
  Animation<double> _glowSize;

  // animation of the cross axis position
  Ticker _displacementTicker;
  Duration _displacementTickerLastElapsed;
  double _displacementTarget = 0.5;
  double _displacement = 0.5;

  // tracking the pull distance
  double _pullDistance = 0.0;

  Color get color => _color;
  Color _color;
  set color(Color value) {
    assert(color != null);
    if (color == value)
      return;
    _color = value;
    notifyListeners();
  }

  Axis get axis => _axis;
  Axis _axis;
  set axis(Axis value) {
    assert(axis != null);
    if (axis == value)
      return;
    _axis = value;
    notifyListeners();
  }

  static const Duration _recedeTime = const Duration(milliseconds: 600);
  static const Duration _pullTime = const Duration(milliseconds: 167);
  static const Duration _pullHoldTime = const Duration(milliseconds: 167);
  static const Duration _pullDecayTime = const Duration(milliseconds: 2000);
  static final Duration _crossAxisHalfTime = new Duration(microseconds: (Duration.MICROSECONDS_PER_SECOND / 60.0).round());

  static const double _maxOpacity = 0.5;
  static const double _pullOpacityGlowFactor = 0.8;
  static const double _velocityGlowFactor = 0.00006;
  static const double _SQRT3 = 1.73205080757; // const math.sqrt(3)
  static const double _kWidthToHeightFactor = (3.0 / 4.0) * (2.0 - _SQRT3);

  // absorbed velocities are clamped to the range _minVelocity.._maxVelocity
  static const double _minVelocity = 100.0; // logical pixels per second
  static const double _maxVelocity = 10000.0; // logical pixels per second

  @override
  void dispose() {
    _glowController.dispose();
    _displacementTicker.dispose();
    _pullRecedeTimer?.cancel();
    super.dispose();
  }

  /// Handle a scroll slamming into the edge at a particular velocity.
  ///
  /// The velocity must be positive.
  void absorbImpact(double velocity) {
    assert(velocity >= 0.0);
    _pullRecedeTimer?.cancel();
    _pullRecedeTimer = null;
    velocity = velocity.clamp(_minVelocity, _maxVelocity);
    _glowOpacityTween.begin = _state == _GlowState.idle ? 0.3 : _glowOpacity.value;
    _glowOpacityTween.end = (velocity * _velocityGlowFactor).clamp(_glowOpacityTween.begin, _maxOpacity);
    _glowSizeTween.begin = _glowSize.value;
    _glowSizeTween.end = math.min(0.025 + 7.5e-7 * velocity * velocity, 1.0);
    _glowController.duration = new Duration(milliseconds: (0.15 + velocity * 0.02).round());
    _glowController.forward(from: 0.0);
    _displacement = 0.5;
    _state = _GlowState.absorb;
  }

  /// Handle a user-driven overscroll.
  ///
  /// The `overscroll` argument should be the scroll distance in logical pixels,
  /// the `extent` argument should be the total dimension of the viewport in the
  /// main axis in logical pixels, the `crossAxisOffset` argument should be the
  /// distance from the leading (left or top) edge of the cross axis of the
  /// viewport, and the `crossExtent` should be the size of the cross axis. For
  /// example, a pull of 50 pixels up the middle of a 200 pixel high and 100
  /// pixel wide vertical viewport should result in a call of `pull(50.0, 200.0,
  /// 50.0, 100.0)`. The `overscroll` value should be positive regardless of the
  /// direction.
  void pull(double overscroll, double extent, double crossAxisOffset, double crossExtent) {
    _pullRecedeTimer?.cancel();
    _pullDistance += overscroll / 200.0; // This factor is magic. Not clear why we need it to match Android.
    _glowOpacityTween.begin = _glowOpacity.value;
    _glowOpacityTween.end = math.min(_glowOpacity.value + overscroll / extent * _pullOpacityGlowFactor, _maxOpacity);
    final double height = math.min(extent, crossExtent * _kWidthToHeightFactor);
    _glowSizeTween.begin = _glowSize.value;
    _glowSizeTween.end = math.max((1.0 - 1.0 / (0.7 * math.sqrt(_pullDistance * height))), _glowSize.value);
    _displacementTarget = crossAxisOffset / crossExtent;
    if (_displacementTarget != _displacement) {
      if (!_displacementTicker.isTicking) {
        assert(_displacementTickerLastElapsed == null);
        _displacementTicker.start();
      }
    } else {
      _displacementTicker.stop();
      _displacementTickerLastElapsed = null;
    }
    _glowController.duration = _pullTime;
    if (_state != _GlowState.pull) {
      _glowController.forward(from: 0.0);
      _state = _GlowState.pull;
    } else {
      if (!_glowController.isAnimating) {
        assert(_glowController.value == 1.0);
        notifyListeners();
      }
    }
    _pullRecedeTimer = new Timer(_pullHoldTime, () => _recede(_pullDecayTime));
  }

  void scrollEnd() {
    if (_state == _GlowState.pull)
      _recede(_recedeTime);
  }

  void _changePhase(AnimationStatus status) {
    if (status != AnimationStatus.completed)
      return;
    switch (_state) {
      case _GlowState.absorb:
        _recede(_recedeTime);
        break;
      case _GlowState.recede:
        _state = _GlowState.idle;
        _pullDistance = 0.0;
        break;
      case _GlowState.pull:
      case _GlowState.idle:
        break;
    }
  }

  void _recede(Duration duration) {
    if (_state == _GlowState.recede || _state == _GlowState.idle)
      return;
    _pullRecedeTimer?.cancel();
    _pullRecedeTimer = null;
    _glowOpacityTween.begin = _glowOpacity.value;
    _glowOpacityTween.end = 0.0;
    _glowSizeTween.begin = _glowSize.value;
    _glowSizeTween.end = 0.0;
    _glowController.duration = duration;
    _glowController.forward(from: 0.0);
    _state = _GlowState.recede;
  }

  void _tickDisplacement(Duration elapsed) {
    if (_displacementTickerLastElapsed != null) {
      double t = (elapsed.inMicroseconds - _displacementTickerLastElapsed.inMicroseconds).toDouble();
      _displacement = _displacementTarget - (_displacementTarget - _displacement) * math.pow(2.0, -t / _crossAxisHalfTime.inMicroseconds);
      notifyListeners();
    }
    if (nearEqual(_displacementTarget, _displacement, Tolerance.defaultTolerance.distance)) {
      _displacementTicker.stop();
      _displacementTickerLastElapsed = null;
    } else {
      _displacementTickerLastElapsed = elapsed;
    }
  }

  void paint(Canvas canvas, Size size) {
    if (_glowOpacity.value == 0.0)
      return;
    final double baseGlowScale = size.width > size.height ? size.height / size.width : 1.0;
    final double radius = size.width * 3.0 / 2.0;
    final double height = math.min(size.height, size.width * _kWidthToHeightFactor);
    final double scaleY = _glowSize.value * baseGlowScale;
    final Rect rect = new Rect.fromLTWH(0.0, 0.0, size.width, height);
    final Point center = new Point((size.width / 2.0) * (0.5 + _displacement), height - radius);
    final Paint paint = new Paint()..color = color.withOpacity(_glowOpacity.value);
    canvas.save();
    canvas.scale(1.0, scaleY);
    canvas.clipRect(rect);
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }
}

class _GlowingOverscrollIndicatorPainter extends CustomPainter {
  _GlowingOverscrollIndicatorPainter({
    this.leadingController,
    this.trailingController,
    this.axisDirection,
  }) : super(
    repaint: new Listenable.merge(<Listenable>[leadingController, trailingController])
  );

  /// The controller for the overscroll glow on the side with negative scroll offsets.
  ///
  /// For a vertical downwards viewport, this is the top side.
  final _GlowController leadingController;

  /// The controller for the overscroll glow on the side with positive scroll offsets.
  ///
  /// For a vertical downwards viewport, this is the bottom side.
  final _GlowController trailingController;

  /// The direction of the viewport.
  final AxisDirection axisDirection;

  static const double piOver2 = math.PI / 2.0;

  void _paintSide(Canvas canvas, Size size, _GlowController controller, AxisDirection axisDirection, GrowthDirection growthDirection) {
    if (controller == null)
      return;
    switch (applyGrowthDirectionToAxisDirection(axisDirection, growthDirection)) {
      case AxisDirection.up:
        controller.paint(canvas, size);
        break;
      case AxisDirection.down:
        canvas.save();
        canvas.translate(0.0, size.height);
        canvas.scale(1.0, -1.0);
        controller.paint(canvas, size);
        canvas.restore();
        break;
      case AxisDirection.left:
        canvas.save();
        canvas.translate(0.0, size.height);
        canvas.rotate(-piOver2);
        controller.paint(canvas, new Size(size.height, size.width));
        canvas.restore();
        break;
      case AxisDirection.right:
        canvas.save();
        canvas.translate(size.width, size.height);
        canvas.rotate(-piOver2);
        canvas.scale(1.0, -1.0);
        controller.paint(canvas, new Size(size.height, size.width));
        canvas.restore();
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintSide(canvas, size, leadingController, axisDirection, GrowthDirection.reverse);
    _paintSide(canvas, size, trailingController, axisDirection, GrowthDirection.forward);
  }

  @override
  bool shouldRepaint(_GlowingOverscrollIndicatorPainter oldDelegate) {
    return oldDelegate.leadingController != leadingController
        || oldDelegate.trailingController != trailingController;
  }
}
