import 'package:flutter_test/flutter_test.dart';
import 'package:guarded_go_router/guarded_go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// `StateProvider` is a legacy provider as of Riverpod 3 and moved to `legacy.dart`.
import 'package:hooks_riverpod/legacy.dart';

// Example providers
final authStateProvider = StateProvider<bool>((ref) => false);

// Modern (non-legacy) equivalent, to cover the Riverpod 3 Notifier API.
class AuthNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setAuthenticated({required bool value}) => state = value;
}

final authNotifierProvider = NotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

// Example guard implementation
class TestAuthGuard extends GoGuard {
  TestAuthGuard(super.read);

  @override
  bool passes() => read(authStateProvider);
}

// Helper provider to create GoNotifier with access to Ref
final goNotifierProvider = Provider.family<GoNotifier, List<ProviderListenable<Object?>>>((ref, dependencies) {
  return GoNotifier(
    ref,
    dependencies: dependencies,
  );
});

void main() {
  group('GoNotifier Riverpod 3 compatibility', () {
    test('accepts any ProviderListenable type', () {
      final container = ProviderContainer.test();
      final testProvider = StateProvider<int>((ref) => 0);
      final asyncProvider = FutureProvider<String>((ref) => 'test');

      final notifier = container.read(goNotifierProvider([
        testProvider,
        asyncProvider,
      ]));

      expect(notifier.dependencies.length, 2);
    });

    test('responds to provider changes', () async {
      final container = ProviderContainer.test();

      final notifier = container.read(goNotifierProvider([authStateProvider]));

      var notificationCount = 0;
      notifier.addListener(() => notificationCount++);

      // Change state
      container.read(authStateProvider.notifier).state = true;
      await Future.microtask(() {}); // Allow notifications to propagate

      expect(notificationCount, 1);
    });

    test('responds to changes of a modern NotifierProvider', () async {
      final container = ProviderContainer.test();

      final notifier = container.read(goNotifierProvider([authNotifierProvider]));

      var notificationCount = 0;
      notifier.addListener(() => notificationCount++);

      container.read(authNotifierProvider.notifier).setAuthenticated(value: true);
      await Future.microtask(() {});

      expect(notificationCount, 1);
    });

    test('uses == operator for update filtering (Riverpod 3 behavior)', () async {
      final container = ProviderContainer.test();
      final notifier = container.read(goNotifierProvider([authStateProvider]));

      var notificationCount = 0;
      notifier.addListener(() => notificationCount++);

      // Set to true
      container.read(authStateProvider.notifier).state = true;
      await Future.microtask(() {});
      expect(notificationCount, 1);

      // Set to true again - should not trigger due to == operator
      container.read(authStateProvider.notifier).state = true;
      await Future.microtask(() {});
      expect(notificationCount, 1);
    });

    test('Guards can read from providers', () {
      final container = ProviderContainer.test();
      final guard = TestAuthGuard(container.read);

      expect(guard.passes(), false);
      expect(guard.blocks(), true);

      container.read(authStateProvider.notifier).state = true;

      expect(guard.passes(), true);
      expect(guard.blocks(), false);
    });

    test('Multiple provider types work with GoNotifier', () async {
      final container = ProviderContainer.test();
      final counterProvider = StateProvider<int>((ref) => 0);
      final asyncProvider = FutureProvider<String>((ref) => 'data');

      final notifier = container.read(goNotifierProvider([
        authStateProvider,
        counterProvider,
        asyncProvider,
      ]));

      var notificationCount = 0;
      notifier.addListener(() => notificationCount++);

      // Change different provider types
      container.read(counterProvider.notifier).state++;
      await Future.microtask(() {});

      expect(notificationCount, greaterThan(0));
    });

    test('closes its subscriptions when disposed', () async {
      final container = ProviderContainer.test();
      final notifier = container.read(goNotifierProvider([authStateProvider]));

      var notificationCount = 0;
      notifier.addListener(() => notificationCount++);
      notifier.dispose();

      container.read(authStateProvider.notifier).state = true;
      await Future.microtask(() {});

      expect(notificationCount, 0);
    });
  });
}
