import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_platform_mobile/app_version.dart';
import 'package:furniture_platform_mobile/locale_store.dart';
import 'package:furniture_platform_mobile/screens/update_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> json({
  String platform = 'android',
  String current = '2.4.0',
  String latest = '2.5.0',
  String min = '2.0.0',
  String status = 'ACTIVE',
  bool available = false,
  bool force = false,
  String store = 'https://play.google.com/store/apps/details?id=uz.vida',
  String message = '',
}) =>
    {
      'platform': platform,
      'current_version': current,
      'latest_version': latest,
      'minimum_supported_version': min,
      'status': status,
      'update_available': available,
      'force_update': force,
      'store_url': store,
      'message': message,
    };

AppVersionPolicy p(Map<String, dynamic> j) => AppVersionPolicy.fromJson(j);

void main() {
  group('parsing', () {
    test('fromJson maps all fields, store url from response', () {
      final a = p(json(platform: 'android', store: 'https://play/x'));
      final i = p(json(platform: 'ios', store: 'https://apps.apple.com/y'));
      expect(a.storeUrl, 'https://play/x');
      expect(i.storeUrl, 'https://apps.apple.com/y');
      expect(i.platform, 'ios');
      expect(a.latestVersion, '2.5.0');
    });
    test('non-map throws FormatException', () {
      expect(() => AppVersionPolicy.fromJson('<html>'),
          throwsA(isA<FormatException>()));
    });
    test('version compare is numeric', () {
      expect(compareVersions('2.10.0', '2.9.0'), 1);
      expect(compareVersions('2.4.0+24', '2.4'), 0);
      expect(compareVersions('x', '1.0.0'), isNull);
    });
  });

  group('decideAction', () {
    test('ACTIVE -> proceed', () {
      expect(decideAction(p(json())), UpdateAction.proceed);
    });
    test('ACTIVE + update_available -> optional', () {
      expect(decideAction(p(json(available: true))), UpdateAction.optional);
    });
    test('UPDATE_REQUIRED + force -> forced', () {
      expect(
          decideAction(p(json(status: 'UPDATE_REQUIRED', force: true))),
          UpdateAction.forced);
    });
    test('UPDATE_REQUIRED without force -> optional', () {
      expect(decideAction(p(json(status: 'UPDATE_REQUIRED'))),
          UpdateAction.optional);
    });
    test('BLOCKED -> forced', () {
      expect(decideAction(p(json(status: 'BLOCKED'))), UpdateAction.forced);
    });
  });

  group('cache fallback', () {
    final blocked = p(json(status: 'BLOCKED', current: '2.4.0', min: '2.5.0'));
    test('no cache -> proceed', () {
      expect(decideFromCache(null, '2.4.0'), UpdateAction.proceed);
    });
    test('cached forced for same version -> forced', () {
      expect(decideFromCache(blocked, '2.4.0'), UpdateAction.forced);
    });
    test('cached forced but app already updated -> proceed', () {
      expect(decideFromCache(blocked, '2.6.0'), UpdateAction.proceed);
    });
    test('cached non-forced -> proceed', () {
      expect(decideFromCache(p(json(available: true)), '2.4.0'),
          UpdateAction.proceed);
    });
  });

  group('AppVersionStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    AppVersionStore make(PolicyFetcher f, {String v = '2.4.0'}) =>
        AppVersionStore(fetcher: f, runningVersion: () => v);

    test('network error with empty cache does not block', () async {
      final s = make(() async => throw Exception('offline'));
      expect(await s.recheck(), isFalse);
      expect(s.action, UpdateAction.proceed);
    });

    test('forced result is cached and honored when offline later', () async {
      final ok = make(() async => p(json(status: 'BLOCKED')));
      await ok.recheck();
      expect(ok.isForced, isTrue);
      final off = make(() async => throw Exception('5xx'));
      await off.recheck();
      expect(off.isForced, isTrue);
    });

    test('forced -> ACTIVE after recheck clears block', () async {
      var blocked = true;
      final s = make(() async =>
          p(json(status: blocked ? 'BLOCKED' : 'ACTIVE')));
      await s.recheck();
      expect(s.isForced, isTrue);
      blocked = false;
      await s.recheck();
      expect(s.action, UpdateAction.proceed);
    });

    test('426 published via forcedSource blocks immediately', () async {
      final n = ValueNotifier<AppVersionPolicy?>(null);
      final s = AppVersionStore(
        fetcher: () async => p(json()),
        runningVersion: () => '2.4.0',
        forcedSource: n,
      );
      n.value = p(json(status: 'UPDATE_REQUIRED', force: true));
      expect(s.isForced, isTrue);
    });

    test('optional shown only once per launch', () async {
      final s = make(() async => p(json(available: true)));
      await s.recheck();
      expect(s.shouldShowOptional, isTrue);
      s.markOptionalHandled();
      expect(s.shouldShowOptional, isFalse);
    });
  });

  testWidgets('forced screen: no skip, back blocked, backend message',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppVersionStore(
      fetcher: () async => p(json(
          status: 'BLOCKED', message: 'Backend xabari', latest: '2.5.0')),
      runningVersion: () => '2.4.0',
    );
    await store.recheck();
    Uri? launched;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleStore()),
        ChangeNotifierProvider.value(value: store),
      ],
      child: MaterialApp(
        home: UpdateScreen(launcher: (u) async {
          launched = u;
          return true;
        }),
      ),
    ));
    expect(find.text('Backend xabari'), findsOneWidget);
    expect(find.textContaining('2.5.0'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Keyinroq'), findsNothing);
    final pop = tester.widget<PopScope>(find.byType(PopScope));
    expect(pop.canPop, isFalse);

    await tester.tap(find.byKey(const Key('update_button')));
    await tester.pump();
    expect(launched.toString(),
        'https://play.google.com/store/apps/details?id=uz.vida');
  });

  testWidgets('empty store_url shows error', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppVersionStore(
      fetcher: () async => p(json(status: 'BLOCKED', store: '')),
      runningVersion: () => '2.4.0',
    );
    await store.recheck();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleStore()),
        ChangeNotifierProvider.value(value: store),
      ],
      child: const MaterialApp(home: UpdateScreen()),
    ));
    await tester.tap(find.byKey(const Key('update_button')));
    await tester.pump();
    expect(find.textContaining('Do‘kon'), findsOneWidget);
  });
}
