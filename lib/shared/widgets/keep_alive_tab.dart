import 'package:flutter/material.dart';

/// Keeps a tab's content alive while another tab is showing.
///
/// The sections used an IndexedStack, which builds every tab once and keeps
/// them all mounted -- so scroll position, a half-typed filter and an
/// in-flight stream all survived switching away. [TabBarView] does not do
/// that on its own: it disposes what scrolls out of view, and the tab you
/// come back to has forgotten where it was.
///
/// Swapping to TabBarView is what makes the tabs swipeable (PM request,
/// 2026-08-18). This is the piece that keeps the old behaviour while
/// gaining the gesture.
class KeepAliveTab extends StatefulWidget {
  const KeepAliveTab({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
