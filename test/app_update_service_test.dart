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
}

