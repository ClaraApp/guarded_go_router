import 'package:flutter/foundation.dart';
import 'package:guarded_go_router/src/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show ProviderListenable;

class GoNotifier extends ChangeNotifier {
  final Ref _ref;
  final List<ProviderListenable<Object?>> dependencies;
  final LogCallback? logger;

  final List<ProviderSubscription<Object?>> _subscriptions = [];

  GoNotifier(
    this._ref, {
    this.dependencies = const [],
    this.logger,
  }) {
    for (final provider in dependencies) {
      _subscriptions.add(
        _ref.listen<Object?>(
          provider,
          (Object? prev, Object? next) {
            logger?.call('⚪️ [$prev => $next] - ${provider.runtimeType}');
            notifyListeners();
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      // `close` is idempotent, so this is safe even when the owning provider
      // has already torn the subscriptions down.
      subscription.close();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
