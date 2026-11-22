#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
if grep -RInE 'GestureDetector|textAlign|Transform\.scale\(.*-1|EdgeInsets\.only\(.*left|EdgeInsets\.only\(.*right' lib; then
  echo 'Forbidden manual RTL or non-Material interaction pattern found.'
  fail=1
fi
if ! grep -RInq 'Directionality' lib/main.dart; then
  echo 'Root Directionality is missing.'
  fail=1
fi
if ! grep -RInq 'ListView.builder' lib; then
  echo 'ListView.builder is missing.'
  fail=1
fi
if ! grep -q '^  isar_community:' pubspec.yaml || ! grep -q '^  isar_community_flutter_libs:' pubspec.yaml; then
  echo 'Isar dependencies are missing.'
  fail=1
fi
if ! grep -q '^  flutter_local_notifications: 22.3.0' pubspec.yaml; then
  echo 'Pinned flutter_local_notifications 22.3.0 is missing.'
  fail=1
fi
if ! grep -q "applicationId 'com.almoktaber'" android/app/build.gradle || ! grep -q "namespace 'com.almoktaber'" android/app/build.gradle; then
  echo 'Android package identity is missing from the Android Gradle source set.'
  fail=1
fi

NATIVE_DIR="android/app/src/main/kotlin/com/almoktaber"
if [ ! -f "$NATIVE_DIR/MainActivity.kt" ] || [ ! -f "$NATIVE_DIR/GuardianReportFileProvider.kt" ]; then
  echo 'Native WhatsApp channel sources are missing.'
  fail=1
fi
if [ ! -f android/app/src/main/res/xml/file_paths.xml ]; then
  echo 'FileProvider paths configuration is missing.'
  fail=1
fi
if ! grep -q 'com.almoktaber.fileprovider' android/app/src/main/AndroidManifest.xml; then
  echo 'FileProvider authority is missing from the manifest.'
  fail=1
fi
if ! grep -q 'android:name="com.whatsapp"' android/app/src/main/AndroidManifest.xml || ! grep -q 'android:name="com.whatsapp.w4b"' android/app/src/main/AndroidManifest.xml; then
  echo 'Limited WhatsApp package queries are missing from the manifest.'
  fail=1
fi
if grep -RInq 'QUERY_ALL_PACKAGES' android; then
  echo 'QUERY_ALL_PACKAGES is not allowed for this feature.'
  fail=1
fi
if grep -RInE 'Uri\.fromFile|file://' "$NATIVE_DIR"; then
  echo 'Unsafe file:// URI found in native share code.'
  fail=1
fi
if grep -RInE 'مشاركة التقرير والملف|فتح محادثة واتساب بالنص فقط|توجيه مباشر' lib; then
  echo 'Obsolete guardian report send buttons are still present.'
  fail=1
fi
if [ "$(grep -Roh 'إرسال التقرير والملف' lib | wc -l)" -ne 1 ]; then
  echo 'The unified guardian report send button is missing or duplicated.'
  fail=1
fi
for required in 'نسخ الرقم' 'تم نسخ رقم ولي الأمر' 'إرسال ملف التقرير' 'إذا لم تظهر المحادثة في واتساب'; do
  if ! grep -Rq "$required" lib; then
    echo "Missing guardian two-step UI text: $required"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

python3 scripts/verify_android_icon.py

echo 'Static Flutter baseline checks passed.'
