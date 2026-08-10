import 'package:flutter/material.dart';

/// A [MaterialPageRoute] that appears immediately, with no transition.
///
/// PM report: opening a screen from the Home shortcuts made the Home screen
/// fade out and slide away to the left, and on a phone it left a visible
/// smear behind. Switching tabs from the bottom nav bar has never done that,
/// because that swaps an `IndexedStack` index rather than pushing a route --
/// so the two ways of leaving Home looked inconsistent.
///
/// Zeroing the duration is what actually removes the Home screen's exit
/// animation, not the overridden [buildTransitions]: the outgoing page runs
/// *its own* transition driven by this route's animation as a secondary
/// animation, so it only stops moving once this route stops animating.
class InstantPageRoute<T> extends MaterialPageRoute<T> {
  InstantPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
