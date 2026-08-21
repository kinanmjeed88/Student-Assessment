# Windows 7 Compatibility Findings

## External sources

- Flutter issue: https://github.com/flutter/flutter/issues/149124
- Flutter issue: https://github.com/flutter/flutter/issues/130554
- Flutter supported platforms: https://docs.flutter.dev/reference/supported-platforms
- Flutter Windows building: https://docs.flutter.dev/platform-integration/windows/building
- flutter_local_notifications package API: https://pub.dev/packages/flutter_local_notifications

## Findings gathered on 2026-08-21

- The current project uses Dart >=3.10.0 and Flutter >=3.38.1.
- The current project uses flutter_local_notifications 22.3.0, file_picker 12.0.0, path_provider 2.1.6, pdf 3.13.0, excel_plus 2.14.2, timezone 0.11.0, url_launcher 6.3.1, and xml 7.0.1.
- Flutter issues report that Flutter 3.13 and later Windows engine builds depend on GetHostNameW and do not support Windows 7; Flutter 3.12 was reported as working for Windows 7.
- flutter_local_notifications 17.2.4 supports Flutter >=3.0.0 and Dart >=2.17, but its pubspec does not include the Windows implementation dependency used by later releases. Version 18.0.1 requires Flutter >=3.13.0, so it cannot be used with a Flutter 3.12 Windows 7 branch.
- file_picker 8.0.7 supports Flutter >=3.7.0 and Dart >=2.19; file_picker 9.0.0 requires Flutter >=3.22.0.
- path_provider 2.1.1 supports Flutter >=3.7.0 and Dart >=2.19; path_provider 2.1.2 requires Flutter >=3.10.0, while 2.1.3 requires Flutter >=3.13.0.
- pdf 3.10.8 supports Dart >=2.18 and uses xml <7; pdf 3.11.1 supports Dart >=2.19.
- excel_plus 2.0.0, 2.5.0, 2.8.0, 2.9.0, and 2.10.0 require Dart >=3.11.4 and xml 7, so excel_plus cannot be used with Flutter 3.12/Dart 3.1. The Windows 7 branch must either replace excel_plus with an older compatible Excel library or temporarily disable/rewrite Excel export.
- url_launcher 6.1.14 supports Dart >=3.0 and Flutter >=3.10; url_launcher 6.2.4 requires Flutter >=3.13.0.
- xml 6.4.2 supports Dart >=3.0; xml 6.4.1 requires Dart ^3.1.0.
- timezone 0.9.x is old and some releases require Dart <3; it may need a compatible 0.10.x release or a local adjustment depending on Flutter 3.12 resolution.
- Isar community 3.3.1 and isar_community_flutter_libs 3.3.1 support Dart >=2.17 and Flutter >=3.0, so they are potential candidates for the Windows 7 branch.

## Project usage

- Excel export is imported in lib/core/services/import_export_service.dart and lib/core/services/report_service.dart.
- File picking and saving are used throughout reports, settings, backup, and student details pages.
- url_launcher is used in settings_page.dart.
- flutter_local_notifications is initialized in main.dart and notification_service.dart.

## Preliminary conclusion

A true Windows 7 build needs a separate Flutter 3.12-era dependency graph. It cannot simply reuse the current pubspec. The largest blocker is excel_plus, which requires Dart 3.11.4, and the current notification package 22.3.0, which requires Flutter 3.38.1. A separate Windows 7 branch can be attempted, but it will require a replacement/compatibility implementation for Excel export and a separate notification strategy; the modern Windows notification implementation cannot be carried over unchanged.

## Windows 7 branch implementation

The dedicated branch `feat/windows-7-support` uses Flutter `3.12.0-1.1.pre` and Dart 3.1-era packages. The Android platform directory and MSIX packaging are intentionally absent from this branch so the Windows 7 deliverable remains separate from Android and the Windows 10/11 branch.

The `excel_plus` dependency was replaced with `excel 4.0.6`, which preserves XLSX import/export support. DOCX parsing uses `ArchiveFile.content` from `archive 3.6.1`. File selection and saving are centralized in `FileStorageService` for the older `file_picker 7.0.2` API, so JSON, Excel, PDF, and backup exports continue to write to the path selected by the user.

Windows 7 has no toast notification implementation in this branch. The notification service is a safe no-op that preserves the provider interface used by the application, while Android and Windows 10/11 notification code remain in their original branches.

The branch includes `.github/workflows/build-windows-7.yml`, which runs on a Windows GitHub runner, installs Flutter 3.12, verifies that Android and MSIX files are absent, runs dependency resolution and analysis, builds `flutter build windows --release`, and uploads `student-assessment-windows-7.zip`. The workflow is scoped to the Windows 7 branch and does not alter the Windows 10/11 workflow.

Local validation completed with Flutter 3.12 analysis: no errors were reported; only seven non-blocking lint information messages remain. A real Windows 7 runtime test still requires executing the uploaded artifact on Windows 7 or a compatible virtual machine, because the current sandbox is Linux and cannot run the Windows executable.

## Final Windows 7 dependency set

| Area | Windows 7 branch choice |
|---|---|
| Flutter/Dart | Flutter `3.12.0-1.1.pre` / Dart 3.1-era SDK |
| Excel | `excel 4.0.6` |
| File selection | `file_picker 7.0.2` |
| PDF | `pdf 3.10.8` and `printing 5.12.0` |
| XML/DOCX | `xml 6.4.2` and `archive 3.6.1` |
| Database | `isar_community 3.3.1` and `isar_community_flutter_libs 3.3.1` |
| Notifications | Disabled through a no-op service |
| Packaging | ZIP of the Windows release directory; no MSIX |

## CI runner note

GitHub officially retired the `windows-2019` hosted runner on 2025-06-30 and recommends `windows-2022` or `windows-2025` instead: https://github.blog/changelog/2025-04-15-upcoming-breaking-changes-and-releases-for-github-actions/ and https://github.com/actions/runner-images/issues/12045. The workflow therefore uses `windows-2022`; `windows-latest` was not suitable for Flutter 3.12 because the current latest image exposed a newer Visual Studio installation that Flutter 3.12 could not select.

## Isar workaround for Dart 3.1

The hosted `isar_community 3.3.1` package declares a broad SDK constraint but its native Dart implementation uses `Pointer + offset`, which is not available to the Dart 3.1 toolchain. This Windows 7 branch vendors the package under `third_party/isar_community` and replaces only those pointer-offset expressions with `Pointer.elementAt`, while retaining the official `isar_community_flutter_libs 3.3.1` Windows native DLL through a local path package. The application API and generated schemas remain unchanged.

## Final CI verification

GitHub Actions run `32498306117` completed successfully on commit `59346445c05d67800c0cdac4eb4a7b30de7bdc82`: https://github.com/kinanmjeed88/Student-Assessment/actions/runs/32498306117. The run passed dependency installation, Windows 7 branch checks, Dart analysis, `flutter build windows --release`, packaging, and artifact upload. The artifact is `student-assessment-windows-7-8`; its ZIP was downloaded and passed `unzip -t` validation locally. The generated Flutter 3.12 output is packaged from `build/windows/runner/Release`.
