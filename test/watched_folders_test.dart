import 'package:flutter_test/flutter_test.dart';
import 'package:airfile_mac/services/transfer_server.dart';

void main() {
  group('Watched Folders Smart Prefix Generation', () {
    test('Prefix resolves project name for generic flutter-apk folder', () {
      final path = '/Users/developer/Projects/food_delivery_app/build/app/outputs/flutter-apk';
      final prefix = TransferServer.generateFolderPrefix(path);
      expect(prefix, 'food_delivery_app • flutter-apk');
    });

    test('Prefix resolves project name for flutter-apks custom build folder', () {
      final path = '/Users/developer/workspace/rider_flutter/flutter-apks';
      final prefix = TransferServer.generateFolderPrefix(path);
      expect(prefix, 'rider_flutter • flutter-apks');
    });

    test('Prefix resolves project name for apk/release outputs', () {
      final path = '/home/user/mobile_apps/ecommerce_client/build/outputs/apk/release';
      final prefix = TransferServer.generateFolderPrefix(path);
      expect(prefix, 'ecommerce_client • release');
    });

    test('Prefix returns folder name for non-generic custom folder', () {
      final path = '/Users/developer/Desktop/MyCompiledApks';
      final prefix = TransferServer.generateFolderPrefix(path);
      expect(prefix, 'MyCompiledApks');
    });
  });
}
