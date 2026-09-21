# External implementation references

1. Isar community package documentation: https://pub.dev/packages/isar_community
   - The maintained community fork preserves the Isar v3 API (`@collection`, `@embedded`, `part '*.g.dart'`, `Isar.open([...Schema])`, transactions, and watchers) while adding Android namespace support.
   - The implementation uses the generated-schema workflow and keeps `isar_community_generator`/`build_runner` as development dependencies.

2. Isar community generator: https://pub.dev/packages/isar_community_generator
   - Code generator for Isar community collection schemas.

3. flutter_local_notifications 17.2.4: https://pub.dev/packages/flutter_local_notifications/versions/17.2.4
   - The version documentation covers Android initialization, notification channels, Android 13+ notification permission, scheduled notifications, pending requests, and release-build configuration.
   - The implementation keeps notification initialization isolated in a service and exposes permission/scheduling methods for later domain workflows.

4. Riverpod Notifier guidance: https://riverpod.dev/docs/migration/from_state_notifier
   - The official guidance favors `Notifier`/`AsyncNotifier` APIs for centralized state and async mutations over legacy `StateNotifier` patterns.

5. Excel package: https://pub.dev/packages/excel
   - The official package documentation covers XLSX reading and writing with `Excel.decodeBytes` and typed `CellValue` variants.

6. excel_plus: https://pub.dev/packages/excel_plus
   - The package README states support for reading legacy XLS and modern XLSX workbooks and CSV import/export. It is selected at the boundary so the first release can preserve XLS/XLSX/CSV import scope.

7. PDF: https://pub.dev/packages/pdf
   - The package documentation covers `pw.Document`, `pw.MultiPage`, and Arabic-capable TrueType font loading.

8. Printing: https://pub.dev/packages/printing
   - The package documentation covers sharing generated PDF bytes with `Printing.sharePdf` and printing via `Printing.layoutPdf`.


## file_picker 12.0.0 API verification

- Official API reference: https://pub.dev/documentation/file_picker/latest/file_picker/FilePicker-class.html
- Official changelog: https://pub.dev/packages/file_picker/changelog
- In 12.0.0, the public API uses static `FilePicker.pickFile`, `FilePicker.pickFiles`, and `FilePicker.saveFile`; `saveFile` requires `fileName` and `bytes`, while `PlatformFile.readAsBytes()` is the supported deferred-read path.
- The 12.0.0 changelog states that the package requires Flutter 3.38 / Dart 3.10, so CI pins Flutter 3.47.0.

## timezone compatibility verification

- Pub package metadata: https://pub.dev/api/packages/timezone
- `flutter_local_notifications` 17.2.4 requires `timezone ^0.9.0`; the project therefore pins `timezone: ^0.9.4` instead of the incompatible 0.11.x line.


## Isar Android namespace compatibility

- The original `isar_flutter_libs` 3.1.0+1 fails with AGP 8+ because its Android library module has no namespace; the failure is documented in https://github.com/isar/isar/issues/1354 and https://github.com/isar/isar/issues/1729.
- Maintained community fork: https://pub.dev/packages/isar_community
- Community Flutter binary package: https://pub.dev/packages/isar_community_flutter_libs
- `isar_community` 3.3.1 changelog states that Android Namespaces support was added and also addresses Android 16KB page-size compatibility: https://pub.dev/packages/isar_community/versions/3.3.1/changelog
- This is a clean dependency-level compatibility fix, preferable to mutating the pub cache or injecting a Gradle namespace workaround.
