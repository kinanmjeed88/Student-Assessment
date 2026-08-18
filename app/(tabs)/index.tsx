import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { router } from "expo-router";
import { useMemo, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { EmptyState, PrimaryButton, ScreenHeader, Sheet, StatCard, StatusBadge, colors } from "@/components/app-ui";
import { ScreenContainer } from "@/components/screen-container";
import { calculateBehaviorSummary } from "@/lib/behavior";
import { isoToday, useStudentStore } from "@/lib/student-store";

type QuickActionProps = {
  icon: keyof typeof MaterialIcons.glyphMap;
  title: string;
  onPress: () => void;
};

export default function HomeScreen() {
  const { data, hydrated } = useStudentStore();
  const [alertsOpen, setAlertsOpen] = useState(false);
  const today = isoToday();
  const todayRecords = data.attendance.filter((record) => record.date === today);
  const presentCount = todayRecords.filter((record) => record.status === "present").length;
  const absentCount = todayRecords.filter((record) => record.status === "absent").length;
  const alerts = useMemo(
    () => data.students
      .map((student) => ({ student, summary: calculateBehaviorSummary(data, student.id) }))
      .filter((item) => item.summary.risk !== "clear")
      .sort((a, b) => (a.summary.risk === "dismissed" ? -1 : 1) - (b.summary.risk === "dismissed" ? -1 : 1) || b.summary.totalPoints - a.summary.totalPoints),
    [data],
  );
  const dismissedCount = alerts.filter((item) => item.summary.risk === "dismissed").length;
  const followUps = data.behaviors.filter((record) => record.category === "followup").slice(0, 3);

  return (
    <ScreenContainer>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <ScreenHeader
          title={data.settings.schoolName || "سجل الطالب"}
          subtitle={data.settings.teacherName ? `مرحبًا ${data.settings.teacherName}` : "ابدأ بإضافة المدرسة والمدرس من الإعدادات"}
          action={
            <View style={styles.headerActions}>
              <Pressable accessibilityRole="button" accessibilityLabel="تنبيهات السلوك" onPress={() => setAlertsOpen(true)} style={styles.headerButton}>
                <MaterialIcons name="notifications" size={21} color={alerts.length ? colors.danger : colors.navy} />
                {alerts.length ? <View style={styles.count}><Text style={styles.countText}>{alerts.length > 99 ? "99+" : alerts.length}</Text></View> : null}
              </Pressable>
              <Pressable accessibilityRole="button" accessibilityLabel="الإعدادات" onPress={() => router.push("/settings" as any)} style={styles.headerButton}>
                <MaterialIcons name="settings" size={21} color={colors.navy} />
              </Pressable>
            </View>
          }
        />

        <View style={styles.stats}>
          <StatCard label="إجمالي الطلاب" value={data.students.length} icon="groups" color={colors.navy} />
          <StatCard label="حضور اليوم" value={presentCount} icon="check-circle" color={colors.success} />
          <StatCard label="غياب اليوم" value={absentCount} icon="event-busy" color={colors.danger} />
        </View>

        {alerts.length ? (
          <Pressable accessibilityRole="button" onPress={() => setAlertsOpen(true)} style={({ pressed }) => [styles.alertBanner, dismissedCount > 0 && styles.alertBannerDanger, pressed && styles.pressed]}>
            <MaterialIcons name={dismissedCount > 0 ? "gavel" : "warning"} size={23} color={dismissedCount > 0 ? colors.danger : colors.warning} />
            <View style={styles.alertBannerText}>
              <Text style={styles.alertBannerTitle}>{dismissedCount ? `${dismissedCount} طالب بلغ حد الفصل` : `${alerts.length} طالب يقترب من حد الفصل`}</Text>
              <Text style={styles.alertBannerSub}>اضغط لفتح تفاصيل التنبيهات السلوكية.</Text>
            </View>
            <MaterialIcons name="chevron-left" size={21} color={colors.muted} />
          </Pressable>
        ) : null}

        <Text style={styles.sectionTitle}>إجراءات سريعة</Text>
        <View style={styles.actionList}>
          <ListTile icon="fact-check" title="تسجيل حضور اليوم" onPress={() => router.push("/attendance" as any)} />
          <ListTile icon="person-add" title="إضافة طالب" onPress={() => router.push("/students?add=1" as any)} />
          <ListTile icon="account-tree" title="الصفوف والشعب" onPress={() => router.push("/classes" as any)} />
          <ListTile icon="groups" title="قائمة الطلاب" onPress={() => router.push("/students" as any)} />
          <ListTile icon="analytics" title="التقارير" onPress={() => router.push("/reports" as any)} />
        </View>

        <View style={styles.sectionHead}>
          <Text style={styles.sectionTitle}>متابعة تحتاج انتباهًا</Text>
          <Text style={styles.hint}>آخر السجلات</Text>
        </View>
        {followUps.length ? (
          <View style={styles.followBox}>
            {followUps.map((item) => {
              const student = data.students.find((candidate) => candidate.id === item.studentId);
              return (
                <View style={styles.followRow} key={item.id}>
                  <View style={styles.followText}>
                    <Text style={styles.followName}>{student?.fullName ?? "طالب محذوف"}</Text>
                    <Text style={styles.followDetail} numberOfLines={1}>{item.title}</Text>
                  </View>
                  <StatusBadge label="متابعة" tone="orange" />
                </View>
              );
            })}
          </View>
        ) : (
          <EmptyState title={hydrated ? "لا توجد تنبيهات متابعة" : "جارٍ تحميل البيانات"} description={hydrated ? "ستظهر هنا السجلات السلوكية التي تحتاج متابعة." : ""} icon="task-alt" />
        )}

        {!data.classes.length ? (
          <View style={styles.startBox}>
            <Text style={styles.startTitle}>خطوة البداية</Text>
            <Text style={styles.startText}>أضف الصفوف والشُعب أولًا، ثم اربط كل طالب بصفه وشعبته.</Text>
            <PrimaryButton label="إدارة الصفوف والشعب" icon="account-tree" onPress={() => router.push("/classes" as any)} />
          </View>
        ) : null}
      </ScrollView>

      <Sheet visible={alertsOpen} title="تنبيهات السلوك والفصل" onClose={() => setAlertsOpen(false)}>
        <ScrollView contentContainerStyle={styles.alertSheet} showsVerticalScrollIndicator={false}>
          {alerts.length ? alerts.map(({ student, summary }) => (
            <Pressable key={student.id} accessibilityRole="button" onPress={() => { setAlertsOpen(false); router.push(`/student/${student.id}` as any); }} style={({ pressed }) => [styles.alertRow, summary.risk === "dismissed" && styles.alertRowDismissed, pressed && styles.pressed]}>
              <View style={styles.alertRowIcon}><MaterialIcons name={summary.risk === "dismissed" ? "gavel" : "warning"} size={21} color={summary.risk === "dismissed" ? colors.danger : colors.warning} /></View>
              <View style={styles.alertRowText}>
                <Text style={styles.alertRowName} numberOfLines={1}>{student.fullName}</Text>
                <Text style={styles.alertRowDetail} numberOfLines={2}>{summary.risk === "dismissed" ? `مفصول: ${summary.totalPoints} من ${summary.dismissalThreshold} نقطة.` : `تنبيه مبكر: ${summary.totalPoints} من ${summary.dismissalThreshold} نقطة.`}</Text>
              </View>
              <StatusBadge label={summary.risk === "dismissed" ? "فصل" : "تنبيه"} tone={summary.risk === "dismissed" ? "red" : "orange"} />
            </Pressable>
          )) : <EmptyState title="لا توجد تنبيهات سلوك" description="سيظهر هنا الطلاب الذين يصلون إلى حد التنبيه أو حد الفصل المحدد في الإعدادات." icon="notifications-none" />}
        </ScrollView>
      </Sheet>
    </ScreenContainer>
  );
}

function ListTile({ icon, title, onPress }: QuickActionProps) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={title} accessibilityHint="يفتح الصفحة المرتبطة" onPress={onPress} style={({ pressed }) => [styles.listTile, pressed && styles.pressed]}>
      <MaterialIcons name={icon} size={23} color={colors.blue} />
      <Text style={styles.listTileTitle} numberOfLines={1}>{title}</Text>
      <MaterialIcons name="chevron-left" size={22} color="#8B9AAF" />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  content: { padding: 16, paddingBottom: 42, rowGap: 16 },
  headerActions: { flexDirection: "row", columnGap: 8 },
  headerButton: { width: 42, height: 42, borderRadius: 21, backgroundColor: "#E9F1FA", alignItems: "center", justifyContent: "center", position: "relative" },
  count: { position: "absolute", top: -4, right: -3, minWidth: 18, height: 18, paddingHorizontal: 3, borderRadius: 9, backgroundColor: colors.danger, alignItems: "center", justifyContent: "center" },
  countText: { color: colors.white, fontSize: 9, fontWeight: "800" },
  stats: { flexDirection: "row", columnGap: 8 },
  alertBanner: { backgroundColor: "#FFF3DE", borderRadius: 15, padding: 13, flexDirection: "row", alignItems: "center", columnGap: 10 },
  alertBannerDanger: { backgroundColor: "#FDEAEA" },
  alertBannerText: { flex: 1, minWidth: 0 },
  alertBannerTitle: { color: colors.ink, fontWeight: "800", fontSize: 13 },
  alertBannerSub: { color: colors.muted, fontSize: 11, lineHeight: 17, marginTop: 2 },
  sectionHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 4 },
  sectionTitle: { color: colors.ink, fontSize: 17, lineHeight: 24, fontWeight: "800" },
  hint: { color: colors.muted, fontSize: 12 },
  actionList: { rowGap: 8 },
  listTile: { minHeight: 64, backgroundColor: colors.white, borderColor: colors.border, borderWidth: 1, borderRadius: 16, paddingHorizontal: 16, flexDirection: "row", alignItems: "center", columnGap: 12 },
  listTileTitle: { flex: 1, minWidth: 0, color: colors.ink, fontSize: 16, lineHeight: 23, fontWeight: "800" },
  pressed: { opacity: 0.75 },
  followBox: { backgroundColor: colors.white, borderRadius: 15, borderWidth: 1, borderColor: colors.border, overflow: "hidden" },
  followRow: { minHeight: 57, paddingHorizontal: 13, flexDirection: "row", alignItems: "center", justifyContent: "space-between", columnGap: 12, borderBottomWidth: 1, borderColor: "#EEF2F6" },
  followText: { flex: 1, minWidth: 0 },
  followName: { color: colors.ink, fontSize: 14, fontWeight: "700" },
  followDetail: { color: colors.muted, fontSize: 12, marginTop: 2 },
  startBox: { rowGap: 10, backgroundColor: "#E9F1FA", borderRadius: 16, padding: 16 },
  startTitle: { color: colors.navy, fontWeight: "800", fontSize: 15 },
  startText: { color: colors.muted, lineHeight: 20, fontSize: 13 },
  alertSheet: { rowGap: 9, paddingBottom: 20 },
  alertRow: { minHeight: 70, padding: 12, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.white, borderRadius: 15, flexDirection: "row", alignItems: "center", columnGap: 10 },
  alertRowDismissed: { borderColor: "#E7B6B6", backgroundColor: "#FFF9F9" },
  alertRowIcon: { width: 38, height: 38, borderRadius: 19, backgroundColor: "#FDEAEA", alignItems: "center", justifyContent: "center" },
  alertRowText: { flex: 1, minWidth: 0 },
  alertRowName: { color: colors.ink, fontSize: 14, fontWeight: "800" },
  alertRowDetail: { color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 2 },
});
