#!/usr/bin/env bash
# ينقل إصلاح ترتيب أعمدة تصدير Excel إلى فرعي ويندوز:
#   سجل-الطالب-للوندوز-٧        (حزمة excel + FileStorageService + Flutter 3.12)
#   سجل-الطالب-للوندوز-١٠-و-١١   (مطابق للفرع الرئيسي في ملفات التصدير)
#
# لا يدمج الفرع الرئيسي في فرعي ويندوز؛ بل يلتقط (cherry-pick) commit الإصلاح
# وحده، لأن الفرعين يحذفان عمداً مزايا موجودة في الرئيسي (الإشعارات والتنبيهات
# ومجلد android) ويدقّق CI في كل فرع على غياب واجهات برمجية غير مدعومة فيه.
#
# الاستخدام:
#   scripts/sync_windows_branches.sh <commit-ish>            # تطبيق تجريبي
#   scripts/sync_windows_branches.sh <commit-ish> --push     # تطبيق ثم دفع
#
# في الوضع التجريبي تُحفظ رقعة كل فرع في build/sync-<slug>.patch ولا يُدفع شيء.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMMIT="${1:-}"
MODE="${2:-dry}"
if [ -z "$COMMIT" ]; then
  echo "الاستخدام: $0 <commit-ish> [--push]" >&2
  exit 2
fi

PUSH=0
if [ "$MODE" = "--push" ]; then
  PUSH=1
elif [ "$MODE" != "dry" ]; then
  echo "خيار غير معروف: $MODE" >&2
  exit 2
fi

# يُحوَّل المرجع إلى بصمة مطلقة قبل أي انتقال بين المجلدات، وإلا أعاد
# `git cherry-pick HEAD` داخل worktree التقاط رأس ذلك الفرع بدل commit الإصلاح.
if ! COMMIT="$(git rev-parse --verify --quiet "$COMMIT^{commit}")"; then
  echo "لا يوجد commit بالمعرّف: $1" >&2
  exit 2
fi

WIN7_REF='سجل-الطالب-للوندوز-٧'
WIN10_REF='سجل-الطالب-للوندوز-١٠-و-١١'
WIN7_SLUG='win7'
WIN10_SLUG='win10-11'
# واجهات يرفضها CI في فرع وندوز ٧ (Flutter 3.12 وحزمة excel القديمة).
WIN7_FORBIDDEN=('excel_plus' 'surfaceContainerHighest' 'WidgetStatePropertyAll' 'withValues(' 'FillPatternType')
# التعارض الوحيد المتوقع: فرع وندوز ٧ يضيف استيراد file_storage_service.dart في
# المكان نفسه الذي يضيف فيه الإصلاح استيراد workbook_names_reader.dart.
KNOWN_CONFLICT_FILE='lib/core/services/import_export_service.dart'

PATCH_DIR="$ROOT/build"
mkdir -p "$PATCH_DIR"
WORK="$(mktemp -d)"
trap 'cd "$ROOT" 2>/dev/null || true; git worktree remove --force "$WORK/$WIN7_SLUG" 2>/dev/null || true; git worktree remove --force "$WORK/$WIN10_SLUG" 2>/dev/null || true; rm -rf "$WORK"; git worktree prune' EXIT

# يحلّ تعارض كتل الاستيراد فقط: يبقي استيرادات الفرع واستيراد الإصلاح معاً
# مرتبة أبجدياً. يرفض أي تعارض آخر ليُحلّ يدوياً.
resolve_import_conflict() {
  local unmerged
  unmerged="$(git diff --name-only --diff-filter=U)"
  if [ "$unmerged" != "$KNOWN_CONFLICT_FILE" ]; then
    echo "  تعارض غير متوقع في: $(echo "$unmerged" | tr '\n' ' ')" >&2
    return 1
  fi

  if ! python3 - "$KNOWN_CONFLICT_FILE" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
pattern = re.compile(r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n", re.S)
blocks = pattern.findall(text)
if not blocks:
    sys.exit("لا توجد كتل تعارض في الملف")

merged_parts = []
for ours, theirs in blocks:
    lines = [line for line in (ours + theirs).splitlines() if line.strip()]
    # يُسمح فقط بأسطر الاستيراد، وإلا يبقى التعارض ليُحلّ يدوياً.
    if not all(line.startswith("import '") and line.endswith("';") for line in lines):
        sys.exit("كتلة التعارض ليست أسطر استيراد فقط")
    merged_parts.append("\n".join(sorted(set(lines))) + "\n")

resolved = pattern.sub(lambda _: merged_parts.pop(0), text)
if "<<<<<<<" in resolved or ">>>>>>>" in resolved:
    sys.exit("بقيت علامات تعارض بعد الحل")
path.write_text(resolved, encoding="utf-8")
PY
  then
    return 1
  fi

  git add "$KNOWN_CONFLICT_FILE"
  if ! git diff --cached --quiet; then
    return 0
  fi
  echo "  لم يبقَ تغيير بعد حل التعارض." >&2
  return 1
}

sync_branch() {
  local remote_ref="$1" slug="$2"
  echo
  echo "==================== $remote_ref ===================="

  git fetch --quiet origin "+refs/heads/$remote_ref:refs/remotes/origin/$slug"
  local dir="$WORK/$slug"
  git worktree add --quiet --detach "$dir" "refs/remotes/origin/$slug"

  cd "$dir"
  if ! git cherry-pick -x "$COMMIT"; then
    echo "  تعارض أثناء التقاط الإصلاح، تُجرى محاولة حلّ تعارض الاستيراد المعروف..."
    if resolve_import_conflict; then
      GIT_EDITOR=true git cherry-pick --continue
      echo "  حُلّ التعارض: أُبقي استيراد الفرع مع استيراد القارئ الجديد."
    else
      echo "فشل التقاط الإصلاح في $remote_ref — راجع رسالة git أعلاه." >&2
      git cherry-pick --abort || true
      cd "$ROOT"
      exit 1
    fi
  fi

  if [ "$slug" = "$WIN7_SLUG" ]; then
    # مطابق لفحص CI في فرع وندوز ٧: يبحث في النص الكامل لأسطر ملفات lib،
    # لذلك يُرفض حتى ذكر الواجهة داخل تعليق.
    for term in "${WIN7_FORBIDDEN[@]}"; do
      if grep -RIn --include='*.dart' -F "$term" lib; then
        echo "واجهة غير مدعومة في فرع وندوز ٧: $term" >&2
        cd "$ROOT"
        exit 1
      fi
    done
  fi

  git show --stat --oneline HEAD | sed 's/^/  /'
  git format-patch -1 --stdout > "$PATCH_DIR/sync-$slug.patch"
  echo "  الرقعة محفوظة في: build/sync-$slug.patch"

  if [ "$PUSH" -eq 1 ]; then
    git push origin "HEAD:refs/heads/$remote_ref"
    echo "  دُفع التعديل إلى $remote_ref"
  else
    echo "  وضع تجريبي: لم يُدفع شيء. للدفع نفّذ:"
    echo "    $0 $COMMIT --push"
  fi

  cd "$ROOT"
}

echo "commit المصدر: $(git log -1 --oneline "$COMMIT")"
sync_branch "$WIN7_REF" "$WIN7_SLUG"
sync_branch "$WIN10_REF" "$WIN10_SLUG"

echo
echo "تم تطبيق الإصلاح على فرعي ويندوز بنجاح."
