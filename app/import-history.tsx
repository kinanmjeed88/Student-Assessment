import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { router } from "expo-router";
import { Alert, FlatList, Pressable, StyleSheet, Text, View } from "react-native";
import { EmptyState, ScreenHeader, SecondaryButton, StatusBadge, colors } from "@/components/app-ui";
import { ScreenContainer } from "@/components/screen-container";
import { useStudentStore, type StudentImportRecord } from "@/lib/student-store";

function formatImportDate(value: string) {
  try { return new Intl.DateTimeFormat("ar-IQ", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)); }
  catch { return value.slice(0, 16).replace("T", " "); }
}

export default function ImportHistoryScreen() {
  const { data, undoStudentImport } = useStudentStore();
  const confirmUndo = (item: StudentImportRecord) => {
    if (item.revertedAt) return;
    const remaining = data.students.filter((student) => item.studentIds.includes(student.id)).length;
    Alert.alert("التراجع عن الاستيراد", `سيُحذف ${remaining} طالبًا أُضيفوا من الملف «${item.sourceFilename}» فقط. لن تتأثر أي أسماء أُضيفت يدويًا أو من عمليات أخرى.`, [
      { text: "إلغاء", style: "cancel" },
      { text: "تراجع عن الاستيراد", style: "destructive", onPress: () => undoStudentImport(item.id) },
    ]);
  };

  return <ScreenContainer edges={["top", "bottom", "left", "right"]}>
    <FlatList
      data={data.importHistory}
      keyExtractor={(item) => item.id}
      contentContainerStyle={styles.content}
      ListHeaderComponent={<ScreenHeader title="سجل الاستيراد" subtitle="آخر عمليات إضافة الطلاب من الملفات، مع تراجع آمن لكل عملية." action={<Pressable accessibilityRole="button" accessibilityLabel="رجوع" onPress={() => router.back()} style={styles.back}><MaterialIcons name="arrow-forward" size={23} color={colors.navy} /></Pressable>} />}
      renderItem={({ item }) => <ImportHistoryCard item={item} onUndo={() => confirmUndo(item)} data={data} />}
      ListEmptyComponent={<EmptyState title="لا توجد عمليات استيراد" description="ستظهر هنا تفاصيل كل عملية استيراد بعد إضافة طلاب من ملف." icon="history" />}
    />
  </ScreenContainer>;
}

function ImportHistoryCard({ item, onUndo, data }: { item: StudentImportRecord; onUndo: () => void; data: ReturnType<typeof useStudentStore>["data"] }) {
  const className = data.classes.find((entry) => entry.id === item.classId)?.name ?? "صف محذوف";
  const sectionName = data.sections.find((entry) => entry.id === item.sectionId)?.name ?? "شعبة محذوفة";
  const availableCount = data.students.filter((student) => item.studentIds.includes(student.id)).length;
  const formatLabel = item.sourceFormat === "excel" ? "Excel" : item.sourceFormat === "word" ? "Word" : "نص";
  return <View style={styles.card}>
    <View style={styles.cardHead}><View style={styles.fileIcon}><MaterialIcons name={item.sourceFormat === "excel" ? "table-chart" : item.sourceFormat === "word" ? "article" : "notes"} size={22} color={colors.blue} /></View><View style={styles.headText}><Text style={styles.filename} numberOfLines={1}>{item.sourceFilename}</Text><Text style={styles.date}>{formatImportDate(item.createdAt)}</Text></View><StatusBadge label={item.revertedAt ? "تم التراجع" : "نشط"} tone={item.revertedAt ? "red" : "green"} /></View>
    <View style={styles.details}><Detail icon="class" label="الصف والشعبة" value={`${className} — ${sectionName}`} /><Detail icon="groups" label="الطلاب المضافون" value={`${item.addedCount} طالبًا`} /><Detail icon="description" label="نوع الملف" value={formatLabel} /></View>
    {!item.revertedAt ? <SecondaryButton label={availableCount ? "التراجع عن هذه العملية" : "تم حذف طلاب العملية"} icon="undo" danger onPress={onUndo} /> : <View style={styles.reverted}><MaterialIcons name="undo" size={18} color={colors.danger} /><Text style={styles.revertedText}>تم التراجع في {formatImportDate(item.revertedAt)}</Text></View>}
  </View>;
}

function Detail({ icon, label, value }: { icon: keyof typeof MaterialIcons.glyphMap; label: string; value: string }) {
  return <View style={styles.detail}><MaterialIcons name={icon} size={18} color={colors.muted} /><Text style={styles.detailLabel}>{label}</Text><Text style={styles.detailValue} numberOfLines={1}>{value}</Text></View>;
}

const styles = StyleSheet.create({
  content: { paddingTop: 12, paddingBottom: 32, gap: 10 },
  back: { width: 44, height: 44, borderRadius: 14, borderColor: colors.border, borderWidth: 1, backgroundColor: colors.white, alignItems: "center", justifyContent: "center" },
  card: { backgroundColor: colors.white, borderWidth: 1, borderColor: colors.border, borderRadius: 18, padding: 14, gap: 13 },
  cardHead: { flexDirection: "row-reverse", alignItems: "center", gap: 10 },
  fileIcon: { width: 42, height: 42, borderRadius: 21, alignItems: "center", justifyContent: "center", backgroundColor: colors.blueSurface },
  headText: { flex: 1, minWidth: 0, alignItems: "flex-end" }, filename: { color: colors.ink, fontSize: 16, lineHeight: 23, fontWeight: "800", textAlign: "right" }, date: { color: colors.muted, fontSize: 13, lineHeight: 20, textAlign: "right", marginTop: 2 },
  details: { borderTopWidth: 1, borderTopColor: "#E8EEF5", paddingTop: 8, gap: 8 }, detail: { flexDirection: "row-reverse", alignItems: "center", gap: 7 }, detailLabel: { color: colors.muted, fontSize: 13, textAlign: "right" }, detailValue: { flex: 1, color: colors.ink, fontSize: 14, fontWeight: "700", textAlign: "right" },
  reverted: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "center", gap: 7, backgroundColor: colors.dangerSurface, borderRadius: 13, paddingVertical: 11, paddingHorizontal: 12 }, revertedText: { color: colors.danger, fontSize: 14, fontWeight: "800", textAlign: "right" },
});
