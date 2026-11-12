import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_erp/core/app_update_service.dart';

void main() {
  group('AppUpdateService.isVersionNewer', () {
    test('detects patch, minor, and major upgrades', () {
      expect(AppUpdateService.isVersionNewer('1.0.17', '1.0.16'), isTrue);
      expect(AppUpdateService.isVersionNewer('v1.1.0', '1.0.99'), isTrue);
      expect(AppUpdateService.isVersionNewer('V2.0.0', '1.9.9'), isTrue);
    });

    test('returns false when remote is equal or older', () {
      expect(AppUpdateService.isVersionNewer('1.0.16', '1.0.16'), isFalse);
      expect(AppUpdateService.isVersionNewer('v1.0.16+17', '1.0.16'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.0.15', '1.0.16'), isFalse);
      expect(AppUpdateService.isVersionNewer('0.9.9', '1.0.0'), isFalse);
    });
  });

  group('AppUpdateService availableUpdateNotifier and Badge tests', () {
    tearDown(() {
      AppUpdateService.availableUpdateNotifier.value = null;
    });

    test('latestVersion getter returns version string', () {
      const info = AppUpdateInfo(
        version: '1.0.18',
        tagName: 'v1.0.18',
        downloadUrl: 'https://github.com/emontal90/el-alfy-90/releases/download/v1.0.18/app-release.apk',
        releasePageUrl: 'https://github.com/emontal90/el-alfy-90/releases/tag/v1.0.18',
        releaseNotes: 'تحسينات جديدة',
        apkSize: 25000000,
      );
      expect(info.latestVersion, equals('1.0.18'));
    });

    testWidgets('gear icon badge appears when update is available and hides when cleared', (tester) async {
      AppUpdateService.availableUpdateNotifier.value = null;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ValueListenableBuilder<AppUpdateInfo?>(
                  valueListenable: AppUpdateService.availableUpdateNotifier,
                  builder: (context, update, child) {
                    return Badge(
                      isLabelVisible: update != null,
                      label: const Text('1'),
                      backgroundColor: const Color(0xFFE53935),
                      child: const Icon(Icons.settings_rounded),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      // Initially no update -> badge label '1' is not visible
      expect(find.text('1'), findsNothing);

      // Set available update -> badge label '1' appears
      AppUpdateService.availableUpdateNotifier.value = const AppUpdateInfo(
        version: '1.0.18',
        tagName: 'v1.0.18',
        downloadUrl: 'https://github.com/emontal90/el-alfy-90/releases/download/v1.0.18/app-release.apk',
        releasePageUrl: 'https://github.com/emontal90/el-alfy-90/releases/tag/v1.0.18',
        releaseNotes: 'تحسينات جديدة',
        apkSize: 25000000,
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);

      // Clear update -> badge disappears
      AppUpdateService.availableUpdateNotifier.value = null;
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNothing);
    });
  });
}
