import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { router } from "expo-router";
import { useMemo, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, StyleSheet, Text, View } from "react-native";
import { ChoicePill, EmptyState, PrimaryButton, ScreenHeader, SecondaryButton, colors } from "@/components/app-ui";
import { ScreenContainer } from "@/components/screen-container";
import { chooseStudentImportFile, type StudentImportPreview } from "@/lib/import-students";
import { useStudentStore } from "@/lib/student-store";

export default function ImportStudentsScreen() {
  const { data, importStudents, showSuccess } = useStudentStore();
  const [classId, setClassId] = useState("");
  const [sectionId, setSectionId] = useState("");
  const [preview, setPreview] = useState<StudentImportPreview | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const sections = useMemo(() => data.sections.filter((section) => section.classId === classId), [classId, data.sections]);
  const className = data.classes.find((item) => item.id === classId)?.name ?? "";
  const sectionName = sections.find((item) => item.id === sectionId)?.name ?? "";
  const readyToChoose = Boolean(classId && sectionId);

  const chooseFile = async () => {
    if (!readyToChoose || busy) return;
    setBusy(true);
    setError(null);
    try {
      const result = await chooseStudentImportFile(data.students.map((student) => student.fullName));
      if (!result.canceled) setPreview(result.preview);
    } catch (caught) {
      setPreview(null);
      setError(caught instanceof Error ? caught.message : "تعذر قراءة الملف. تأكد من صيغته وحاول مرة أخرى.");
    } finally {
      setBusy(false);
    }
  };

  const removeName = (index: number) => setPreview((current) => current ? { ...current, names: current.names.filter((_, itemIndex) => itemIndex !== index) } : current);
  const importAll = () => {
    if (!preview || !classId || !sectionId) return;
    const imported = importStudents(preview.names, classId, sectionId);
    if (!imported) {
      setError("لا توجد أسماء جديدة قابلة للاستيراد.");
      return;
    }
    showSuccess(`تم استيراد ${imported} طالبًا إلى ${className} — الشعبة ${sectionName} بنجاح.`);
    router.replace("/(tabs)/students" as any);
  };

  return <ScreenContainer className="px-4" edges={["top", "bottom", "left", "right"]}>
    <FlatList
      data={preview?.names ?? []}
      keyExtractor={(name, index) => `${name}-${index}`}
      keyboardShouldPersistTaps="handled"
      contentContainerStyle={styles.content}
      ListHeaderComponent={<View>
        <ScreenHeader title="استيراد الطلاب" subtitle="اختر الصف والشعبة، ثم راجع الأسماء قبل حفظها." action={<Pressable accessibilityRole="button" accessibilityLabel="رجوع" onPress={() => router.back()} style={styles.back}><MaterialIcons name="arrow-forward" size={23} color={colors.navy} /></Pressable>} />
        {!data.classes.length || !data.sections.length ? <EmptyState title="أضف الصفوف والشُعب أولًا" description="لا يمكن ربط الأسماء المستوردة دون تحديد صف وشعبة." icon="account-tree" action={<PrimaryButton label="إدارة الصفوف" icon="account-tree" onPress={() => router.push("/classes" as any)} />} /> : <>
          <View style={styles.infoCard}><View style={styles.infoIcon}><MaterialIcons name="description" size={22} color={colors.blue} /></View><View style={styles.infoText}><Text style={styles.infoTitle}>الصيغ المدعومة</Text><Text style={styles.infoBody}>Excel ‏(.xlsx و.xls) وWord الحديث ‏(.docx) وTXT أو CSV. اجعل كل سطر أو صف اسم طالب كاملًا.</Text></View></View>
          <Text style={styles.label}>الصف</Text>
          <View style={styles.choices}>{data.classes.map((item) => <ChoicePill key={item.id} label={item.name} selected={classId === item.id} onPress={() => { setClassId(item.id); setSectionId(""); setPreview(null); setError(null); }} />)}</View>
          <Text style={styles.label}>الشعبة</Text>
          <View style={styles.choices}>{sections.length ? sections.map((item) => <ChoicePill key={item.id} label={item.name} selected={sectionId === item.id} onPress={() => { setSectionId(item.id); setPreview(null); setError(null); }} />) : <Text style={styles.muted}>اختر الصف أولًا لعرض شُعبه.</Text>}</View>
          <PrimaryButton label={busy ? "يتم تحليل الملف..." : "اختيار ملف الطلاب"} icon={busy ? undefined : "file-upload"} onPress={chooseFile} disabled={!readyToChoose || busy} />
          {!readyToChoose ? <Text style={styles.hint}>يجب اختيار الصف والشعبة قبل فتح الملف، لضمان تنظيم الطلاب بصورة صحيحة.</Text> : null}
          {busy ? <View style={styles.loading}><ActivityIndicator color={colors.blue} size="small" /><Text style={styles.loadingText}>يتم قراءة أسماء الطلاب محليًا...</Text></View> : null}
          {error ? <View style={styles.errorBox}><MaterialIcons name="error-outline" color={colors.danger} size={20} /><Text style={styles.errorText}>{error}</Text></View> : null}
          {preview ? <View style={styles.previewHeader}><View style={styles.fileLine}><MaterialIcons name={preview.format === "excel" ? "table-chart" : preview.format === "word" ? "article" : "notes"} size={22} color={colors.blue} /><Text style={styles.filename} numberOfLines={1}>{preview.filename}</Text></View><Text style={styles.previewTitle}>معاينة الأسماء المستخرجة</Text><Text style={styles.previewSubtitle}>إلى {className} — الشعبة {sectionName}. يمكنك حذف أي اسم قبل الاستيراد.</Text><View style={styles.summaryRow}><Summary label="جاهز للاستيراد" value={preview.names.length} tone="blue" />{preview.duplicateNames.length ? <Summary label="مكرر تم تجاوزه" value={preview.duplicateNames.length} tone="red" /> : null}{preview.skippedRows ? <Summary label="سطر غير صالح" value={preview.skippedRows} tone="gray" /> : null}</View></View> : null}
        </>}</View>}
      renderItem={({ item, index }) => <View style={styles.nameRow}><Pressable accessibilityRole="button" accessibilityLabel={`حذف ${item}`} onPress={() => removeName(index)} style={({ pressed }) => [styles.remove, pressed && styles.pressed]}><MaterialIcons name="close" size={20} color={colors.danger} /></Pressable><Text style={styles.nameIndex}>{index + 1}</Text><Text style={styles.nameText}>{item}</Text></View>}
      ListEmptyComponent={preview ? <EmptyState title="لا توجد أسماء جديدة" description="كل الأسماء مكررة أو غير صالحة. اختر ملفًا آخر أو راجع محتواه." icon="group-off" /> : null}
      ListFooterComponent={preview && preview.names.length ? <View style={styles.footer}><SecondaryButton label="اختيار ملف آخر" icon="refresh" onPress={chooseFile} /><View style={styles.footerGap} /><PrimaryButton label={`استيراد ${preview.names.length} طالبًا`} icon="group-add" onPress={importAll} /></View> : <View style={styles.bottomSpace} />}
    />
  </ScreenContainer>;
}

function Summary({ label, value, tone }: { label: string; value: number; tone: "blue" | "red" | "gray" }) {
  const color = tone === "red" ? colors.danger : tone === "blue" ? colors.blue : colors.muted;
  const surface = tone === "red" ? colors.dangerSurface : tone === "blue" ? colors.blueSurface : "#EEF2F6";
  return <View style={[styles.summary, { backgroundColor: surface }]}><Text style={[styles.summaryValue, { color }]}>{value}</Text><Text style={styles.summaryLabel}>{label}</Text></View>;
}

const styles = StyleSheet.create({
  content: { paddingTop: 12, paddingBottom: 32, gap: 10 },
  back: { width: 44, height: 44, borderRadius: 14, borderColor: colors.border, borderWidth: 1, backgroundColor: colors.white, alignItems: "center", justifyContent: "center" },
  infoCard: { flexDirection: "row", alignItems: "flex-start", gap: 12, borderRadius: 18, borderWidth: 1, borderColor: "#AECEEE", backgroundColor: "#EEF6FF", padding: 15, marginBottom: 18 },
  infoIcon: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.blueSurface, alignItems: "center", justifyContent: "center" },
  infoText: { flex: 1, minWidth: 0, alignItems: "flex-end" }, infoTitle: { color: colors.ink, fontSize: 16, lineHeight: 23, fontWeight: "800", textAlign: "right" }, infoBody: { color: colors.muted, fontSize: 14, lineHeight: 21, textAlign: "right", marginTop: 3 },
  label: { color: colors.ink, textAlign: "right", fontWeight: "800", fontSize: 16, lineHeight: 23, marginBottom: 8 }, choices: { flexDirection: "row", flexWrap: "wrap", justifyContent: "flex-end", gap: 8, marginBottom: 16 }, muted: { color: colors.muted, fontSize: 15, lineHeight: 22, textAlign: "right", width: "100%" }, hint: { color: colors.muted, fontSize: 14, lineHeight: 21, textAlign: "right", marginTop: 9 },
  loading: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 10, paddingVertical: 15 }, loadingText: { color: colors.muted, fontSize: 15, lineHeight: 22, textAlign: "right" }, errorBox: { flexDirection: "row", alignItems: "center", gap: 9, backgroundColor: colors.dangerSurface, borderRadius: 14, borderWidth: 1, borderColor: "#E6A8AE", padding: 13, marginTop: 12 }, errorText: { flex: 1, color: colors.danger, fontSize: 14, lineHeight: 21, fontWeight: "700", textAlign: "right" },
  previewHeader: { backgroundColor: colors.white, borderColor: colors.border, borderWidth: 1, borderRadius: 18, padding: 15, marginTop: 20, marginBottom: 10 }, fileLine: { flexDirection: "row", alignItems: "center", gap: 8, justifyContent: "flex-end", marginBottom: 12 }, filename: { color: colors.navy, fontWeight: "800", fontSize: 14, lineHeight: 21, textAlign: "right", flexShrink: 1 }, previewTitle: { color: colors.ink, fontSize: 18, lineHeight: 26, fontWeight: "800", textAlign: "right" }, previewSubtitle: { color: colors.muted, fontSize: 14, lineHeight: 21, textAlign: "right", marginTop: 3 }, summaryRow: { flexDirection: "row", flexWrap: "wrap", justifyContent: "flex-end", gap: 8, marginTop: 14 }, summary: { minWidth: 104, borderRadius: 13, paddingHorizontal: 11, paddingVertical: 8, alignItems: "flex-end" }, summaryValue: { fontSize: 19, lineHeight: 25, fontWeight: "800", textAlign: "right" }, summaryLabel: { color: colors.ink, fontSize: 12, lineHeight: 17, fontWeight: "700", textAlign: "right" },
  nameRow: { minHeight: 58, borderWidth: 1, borderColor: colors.border, borderRadius: 14, backgroundColor: colors.white, paddingHorizontal: 12, flexDirection: "row", alignItems: "center", gap: 10, marginBottom: 8 }, remove: { width: 38, height: 38, borderRadius: 12, backgroundColor: colors.dangerSurface, alignItems: "center", justifyContent: "center" }, nameIndex: { color: colors.muted, fontSize: 14, fontWeight: "800", minWidth: 25, textAlign: "center" }, nameText: { flex: 1, minWidth: 0, color: colors.ink, fontSize: 16, lineHeight: 23, fontWeight: "700", textAlign: "right" }, pressed: { opacity: 0.7 },
  footer: { marginTop: 10, paddingBottom: 18 }, footerGap: { height: 10 }, bottomSpace: { height: 16 },
});
