import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Invisible widget that fires [onFirstMount] once per session per [screenId].
/// For ConsumerStatefulWidget screens, use [shouldShow] in initState instead.
class UnicornScreenGuard extends ConsumerStatefulWidget {
  static final _shown = <String>{};

  /// Returns true (and marks as shown) the first time called for [id] per session.
  static bool shouldShow(String id) {
    if (_shown.contains(id)) return false;
    _shown.add(id);
    return true;
  }

  final String screenId;
  final void Function(WidgetRef ref) onFirstMount;

  const UnicornScreenGuard({
    super.key,
    required this.screenId,
    required this.onFirstMount,
  });

  @override
  ConsumerState<UnicornScreenGuard> createState() => _UnicornScreenGuardState();
}

class _UnicornScreenGuardState extends ConsumerState<UnicornScreenGuard> {
  @override
  void initState() {
    super.initState();
    if (UnicornScreenGuard.shouldShow(widget.screenId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFirstMount(ref);
      });
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
