import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { router } from "expo-router";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { EmptyState, PrimaryButton, ScreenHeader, StatCard, StatusBadge, colors } from "@/components/app-ui";
import { isoToday, useStudentStore } from "@/lib/student-store";
import { ScreenContainer } from "@/components/screen-container";

export default function HomeScreen() {
  const { data, hydrated } = useStudentStore();
  const today = isoToday();
  const todayRecords = data.attendance.filter((record) => record.date === today);
  const presentCount = todayRecords.filter((record) => record.status === "present").length;
  const absentCount = todayRecords.filter((record) => record.status === "absent").length;
  const followUps = data.behaviors.filter((record) => record.category !== "positive").slice(0, 3);

  return <ScreenContainer className="p-4" containerClassName="bg-background">
    <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
      <ScreenHeader title={data.settings.schoolName || "سجل الطالب"} subtitle={data.settings.teacherName ? `مرحبًا ${data.settings.teacherName}` : "ابدأ بإضافة المدرسة والمدرس من الإعدادات"} action={<Pressable onPress={() => router.push("/settings" as any)} style={styles.settings}><MaterialIcons name="settings" size={21} color={colors.navy} /></Pressable>} />
      <View style={styles.stats}><StatCard label="إجمالي الطلاب" value={data.students.length} icon="groups" color={colors.navy} /><StatCard label="حضور اليوم" value={presentCount} icon="check-circle" color={colors.success} /><StatCard label="غياب اليوم" value={absentCount} icon="event-busy" color={colors.danger} /></View>
      <View style={styles.quickWrap}><PrimaryButton label="تسجيل حضور اليوم" icon="fact-check" onPress={() => router.push("/attendance" as any)} /><PrimaryButton label="إضافة طالب" icon="person-add" onPress={() => router.push("/students?add=1" as any)} /></View>
      <View style={styles.sectionHead}><Text style={styles.sectionTitle}>إجراءات سريعة</Text></View>
      <View style={styles.actions}><QuickAction icon="account-tree" label="الصفوف والشعب" onPress={() => router.push("/classes" as any)} /><QuickAction icon="groups" label="قائمة الطلاب" onPress={() => router.push("/students" as any)} /><QuickAction icon="analytics" label="التقارير" onPress={() => router.push("/reports" as any)} /></View>
      <View style={styles.sectionHead}><Text style={styles.sectionTitle}>متابعة تحتاج انتباهًا</Text><Text style={styles.hint}>آخر السجلات</Text></View>
      {followUps.length ? <View style={styles.followBox}>{followUps.map((item) => { const student = data.students.find((candidate) => candidate.id === item.studentId); return <View style={styles.followRow} key={item.id}><View style={styles.followText}><Text style={styles.followName}>{student?.fullName ?? "طالب محذوف"}</Text><Text style={styles.followDetail} numberOfLines={1}>{item.title}</Text></View><StatusBadge label={item.category === "negative" ? "سلوك سلبي" : "متابعة"} tone={item.category === "negative" ? "red" : "orange"} /></View>; })}</View> : <EmptyState title={hydrated ? "لا توجد تنبيهات متابعة" : "جارٍ تحميل البيانات"} description={hydrated ? "ستظهر هنا السجلات السلوكية التي تحتاج متابعة." : ""} icon="task-alt" />}
      {!data.classes.length ? <View style={styles.startBox}><Text style={styles.startTitle}>خطوة البداية</Text><Text style={styles.startText}>أضف الصفوف والشُعب أولًا، ثم اربط كل طالب بصفه وشعبته.</Text><PrimaryButton label="إدارة الصفوف والشعب" icon="account-tree" onPress={() => router.push("/classes" as any)} /></View> : null}
    </ScrollView>
  </ScreenContainer>;
}

function QuickAction({ icon, label, onPress }: { icon: keyof typeof MaterialIcons.glyphMap; label: string; onPress: () => void }) {
  return <Pressable onPress={onPress} style={({ pressed }) => [styles.quick, pressed && styles.pressed]}><View style={styles.quickIcon}><MaterialIcons name={icon} size={23} color={colors.blue} /></View><Text style={styles.quickLabel}>{label}</Text><MaterialIcons name="chevron-left" size={20} color="#8B9AAF" /></Pressable>;
}

const styles = StyleSheet.create({ content: { paddingBottom: 30, gap: 16 }, settings: { width: 42, height: 42, borderRadius: 21, backgroundColor: "#E9F1FA", alignItems: "center", justifyContent: "center" }, stats: { flexDirection: "row-reverse", gap: 8 }, quickWrap: { gap: 10 }, sectionHead: { flexDirection: "row-reverse", justifyContent: "space-between", alignItems: "center", marginTop: 4 }, sectionTitle: { color: colors.ink, fontSize: 17, fontWeight: "800" }, hint: { color: colors.muted, fontSize: 12 }, actions: { gap: 8 }, quick: { minHeight: 62, backgroundColor: colors.white, borderColor: colors.border, borderWidth: 1, borderRadius: 15, paddingHorizontal: 13, flexDirection: "row-reverse", alignItems: "center", gap: 11 }, quickIcon: { width: 38, height: 38, borderRadius: 19, backgroundColor: "#EDF5FF", alignItems: "center", justifyContent: "center" }, quickLabel: { flex: 1, textAlign: "right", color: colors.ink, fontSize: 14, fontWeight: "700" }, pressed: { opacity: 0.75 }, followBox: { backgroundColor: colors.white, borderRadius: 15, borderWidth: 1, borderColor: colors.border, overflow: "hidden" }, followRow: { minHeight: 57, paddingHorizontal: 13, flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", gap: 12, borderBottomWidth: 1, borderColor: "#EEF2F6" }, followText: { alignItems: "flex-end", flex: 1 }, followName: { color: colors.ink, fontSize: 14, fontWeight: "700" }, followDetail: { color: colors.muted, fontSize: 12, marginTop: 2 }, startBox: { gap: 10, backgroundColor: "#E9F1FA", borderRadius: 16, padding: 16, alignItems: "flex-end" }, startTitle: { color: colors.navy, fontWeight: "800", fontSize: 15 }, startText: { color: colors.muted, textAlign: "right", lineHeight: 20, fontSize: 13 } });
