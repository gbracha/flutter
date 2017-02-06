// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'framework.dart';
import 'navigator.dart';
import 'overlay.dart';
import 'routes.dart';

/// A modal route that replaces the entire screen.
abstract class PageRoute<T> extends ModalRoute<T> {
  /// Creates a modal route that replaces the entire screen.
  PageRoute({
    RouteSettings settings: const RouteSettings()
  }) : super(settings: settings);

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissable => false;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => nextRoute is PageRoute<dynamic>;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> nextRoute) => nextRoute is PageRoute<dynamic>;

  @override
  AnimationController createAnimationController() {
    AnimationController controller = super.createAnimationController();
    if (settings.isInitialRoute)
      controller.value = 1.0;
    return controller;
  }

  /// Subclasses can override this method to customize how heroes are inserted.
  void insertHeroOverlayEntry(OverlayEntry entry, Object tag, OverlayState overlay) {
    overlay.insert(entry);
  }
}

/// Signature for the [PageRouteBuilder] function that builds the route's
/// primary contents.
///
/// See [ModalRoute.buildPage] for complete definition of the parameters.
typedef Widget RoutePageBuilder(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation);

/// Signature for the [PageRouteBuilder] function that builds the route's
/// transitions.
///
/// See [ModalRoute.buildTransitions] for complete definition of the parameters.
typedef Widget RouteTransitionsBuilder(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation, Widget child);

Widget _defaultTransitionsBuilder(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation, Widget child) {
  return child;
}

/// A utility class for defining one-off page routes in terms of callbacks.
///
/// Callers must define the [pageBuilder] function which creates the route's
/// primary contents. To add transitions define the [transitionsBuilder] function.
class PageRouteBuilder<T> extends PageRoute<T> {
  PageRouteBuilder({
    RouteSettings settings: const RouteSettings(),
    this.pageBuilder,
    this.transitionsBuilder: _defaultTransitionsBuilder,
    this.transitionDuration: const Duration(milliseconds: 300),
    this.opaque: true,
    this.barrierDismissable: false,
    this.barrierColor: null,
    this.maintainState: true,
  }) : super(settings: settings) {
    assert(pageBuilder != null);
    assert(transitionsBuilder != null);
    assert(opaque != null);
    assert(barrierDismissable != null);
    assert(maintainState != null);
  }

  final RoutePageBuilder pageBuilder;
  final RouteTransitionsBuilder transitionsBuilder;

  @override
  final Duration transitionDuration;

  @override
  final bool opaque;

  @override
  final bool barrierDismissable;

  @override
  final Color barrierColor;

  @override
  final bool maintainState;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation) {
    return pageBuilder(context, animation, forwardAnimation);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation, Widget child) {
    return transitionsBuilder(context, animation, forwardAnimation, child);
  }

}
