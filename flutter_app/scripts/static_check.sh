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
if ! grep -q '^  flutter_local_notifications: 17.2.4' pubspec.yaml; then
  echo 'Pinned flutter_local_notifications 17.2.4 is missing.'
  fail=1
fi
if ! grep -q "applicationId 'com.almoktaber'" android/app/build.gradle || ! grep -q "namespace 'com.almoktaber'" android/app/build.gradle; then
  echo 'Android package identity is missing from the Android Gradle source set.'
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo 'Static Flutter baseline checks passed.'
