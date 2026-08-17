import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { Alert, ScrollView, StyleSheet, Text, View } from "react-native";
import { Field, PrimaryButton, ScreenHeader, SecondaryButton, colors } from "@/components/app-ui";
import { ScreenContainer } from "@/components/screen-container";
import { DEFAULT_BEHAVIOR_SETTINGS, useStudentStore, type BehaviorViolationType, type Settings } from "@/lib/student-store";
import { required } from "@/lib/validation";
import { useEffect, useState } from "react";

const PENALTY_FIELDS: { type: BehaviorViolationType; label: string; help: string }[] = [
  { type: "absence", label: "خصم الغياب غير المبرر", help: "يطبق عند تسجيل مخالفة غياب غير مبرر." },
  { type: "lessonDisruption", label: "خصم الإخلال بسير الدرس", help: "يطبق للمشكلات داخل الحصة أو تعطيل الدرس." },
  { type: "seriousMisconduct", label: "خصم المخالفة الجسيمة", help: "للمخالفات التي تستدعي خصمًا أكبر." },
  { type: "other", label: "خصم المخالفة الأخرى", help: "قيمة افتراضية لأي مخالفة لا تنتمي للأنواع السابقة." },
];

const numberOrZero = (value: string) => {
  const parsed = Number(value.replace(/[^0-9.]/g, ""));
  return Number.isFinite(parsed) ? parsed : 0;
};

export default function SettingsScreen() {
  const { data, updateSettings, resetAll } = useStudentStore();
  const [form, setForm] = useState<Settings>(data.settings);
  const [error, setError] = useState("");
  const [saved, setSaved] = useState(false);

  useEffect(() => setForm(data.settings), [data.settings]);
  const setPenalty = (type: BehaviorViolationType, value: string) => setForm((current) => ({ ...current, behavior: { ...current.behavior, penalties: { ...current.behavior.penalties, [type]: numberOrZero(value) } } }));
  const save = () => {
    const behavior = form.behavior ?? DEFAULT_BEHAVIOR_SETTINGS;
    const issue = required(form.schoolName, "اسم المدرسة") ?? required(form.teacherName, "اسم المدرس") ??
      (behavior.dismissalThreshold <= 0 ? "حد الفصل يجب أن يكون أكبر من صفر." : undefined) ??
      (behavior.warningThreshold <= 0 || behavior.warningThreshold > behavior.dismissalThreshold ? "حد التنبيه يجب أن يكون أكبر من صفر وأقل من أو يساوي حد الفصل." : undefined) ??
      (Object.values(behavior.penalties).some((value) => value < 0) ? "قيم الخصم لا يمكن أن تكون سالبة." : undefined);
    setError(issue ?? "");
    if (issue) return;
    updateSettings({ ...form, behavior });
    setSaved(true);
    setTimeout(() => setSaved(false), 2200);
  };

  return <ScreenContainer><ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
    <ScreenHeader title="الإعدادات" subtitle="بيانات المدرسة وقواعد السلوك والخصم" />
    <View style={styles.card}>
      <CardHeading icon="school" title="هوية المدرسة" />
      <Field label="اسم المدرسة" value={form.schoolName} onChangeText={(schoolName) => setForm({ ...form, schoolName })} error={error.includes("المدرسة") ? error : undefined} placeholder="مثال: مدرسة النور الأساسية" />
      <Field label="اسم المدرس" value={form.teacherName} onChangeText={(teacherName) => setForm({ ...form, teacherName })} error={error.includes("المدرس") ? error : undefined} placeholder="الاسم الثلاثي" />
      <Field label="العام الدراسي" value={form.academicYear} onChangeText={(academicYear) => setForm({ ...form, academicYear })} placeholder="2026 / 2027" />
      <Field label="المرحلة التعليمية" value={form.stage} onChangeText={(stage) => setForm({ ...form, stage })} placeholder="مثال: المرحلة الابتدائية" />
    </View>

    <View style={styles.card}>
      <CardHeading icon="gavel" title="نظام السلوك والفصل" />
      <View style={styles.info}><MaterialIcons name="info-outline" color={colors.blue} size={20} /><Text style={styles.infoText}>تُثبّت قيمة الخصم داخل كل سجل مخالفة عند الحفظ. تغيير القيم هنا يؤثر في المخالفات الجديدة فقط ويحافظ على سجل الطالب السابق.</Text></View>
      <Field label="حد الفصل بالنقاط" value={String(form.behavior.dismissalThreshold)} onChangeText={(value) => setForm({ ...form, behavior: { ...form.behavior, dismissalThreshold: numberOrZero(value) } })} keyboardType="number-pad" error={error.includes("الفصل") ? error : undefined} placeholder="50" />
      <Field label="حد التنبيه المبكر بالنقاط" value={String(form.behavior.warningThreshold)} onChangeText={(value) => setForm({ ...form, behavior: { ...form.behavior, warningThreshold: numberOrZero(value) } })} keyboardType="number-pad" error={error.includes("التنبيه") ? error : undefined} placeholder="40" />
      <Text style={styles.subheading}>خصم النقاط لكل مخالفة</Text>
      {PENALTY_FIELDS.map(({ type, label, help }) => <View key={type}><Field label={label} value={String(form.behavior.penalties[type])} onChangeText={(value) => setPenalty(type, value)} keyboardType="number-pad" /><Text style={styles.help}>{help}</Text></View>)}
    </View>

    {error ? <Text style={styles.formError}>{error}</Text> : null}
    {saved ? <View style={styles.saved}><MaterialIcons name="check-circle" size={18} color={colors.success} /><Text style={styles.savedText}>تم حفظ الإعدادات وقواعد السلوك.</Text></View> : null}
    <PrimaryButton label="حفظ الإعدادات" icon="save" onPress={save} />

    <View style={styles.card}>
      <CardHeading icon="delete-sweep" title="إدارة البيانات" danger />
      <Text style={styles.warning}>سيؤدي الحذف إلى إزالة جميع الصفوف والطلاب والسجلات من هذا الجهاز، ولا يمكن التراجع عنه.</Text>
      <SecondaryButton label="حذف جميع البيانات" icon="delete-forever" danger onPress={() => Alert.alert("حذف جميع البيانات", "هل أنت متأكد؟ لا يمكن استرجاع الصفوف والطلاب والسجلات بعد الحذف.", [{ text: "إلغاء", style: "cancel" }, { text: "حذف نهائي", style: "destructive", onPress: resetAll }])} />
    </View>
    <Text style={styles.privacy}>جميع البيانات محفوظة محليًا على هذا الجهاز. احتفظ بنسخة من التقارير عند الحاجة.</Text>
  </ScrollView></ScreenContainer>;
}

function CardHeading({ icon, title, danger = false }: { icon: keyof typeof MaterialIcons.glyphMap; title: string; danger?: boolean }) {
  return <View style={styles.cardHead}><View style={[styles.icon, danger && styles.dangerIcon]}><MaterialIcons name={icon} color={danger ? colors.danger : colors.blue} size={23} /></View><Text style={styles.cardTitle}>{title}</Text></View>;
}

const styles = StyleSheet.create({
  content: { padding: 16, gap: 15, paddingBottom: 42 }, card: { backgroundColor: colors.white, borderRadius: 18, borderWidth: 1, borderColor: colors.border, padding: 15 },
  cardHead: { flexDirection: "row", alignItems: "center", columnGap: 10, marginBottom: 15 }, icon: { width: 42, height: 42, borderRadius: 21, backgroundColor: "#E9F1FA", alignItems: "center", justifyContent: "center" }, dangerIcon: { backgroundColor: "#FCE8E8" }, cardTitle: { flex: 1, color: colors.ink, fontSize: 16, fontWeight: "800", textAlign: "right" },
  info: { flexDirection: "row", alignItems: "flex-start", columnGap: 8, backgroundColor: "#EEF6FF", borderRadius: 12, padding: 11, marginBottom: 14 }, infoText: { flex: 1, color: colors.navy, textAlign: "right", fontSize: 12, lineHeight: 19 },
  subheading: { color: colors.ink, textAlign: "right", fontSize: 14, fontWeight: "800", marginTop: 3, marginBottom: 9 }, help: { color: colors.muted, fontSize: 11, lineHeight: 16, textAlign: "right", marginTop: -9, marginBottom: 12 },
  warning: { color: colors.muted, textAlign: "right", fontSize: 13, lineHeight: 20, marginBottom: 13 }, privacy: { color: colors.muted, fontSize: 12, lineHeight: 19, textAlign: "center", paddingHorizontal: 12 }, formError: { color: colors.danger, fontSize: 12, lineHeight: 18, textAlign: "right" },
  saved: { flexDirection: "row", alignItems: "center", justifyContent: "center", columnGap: 6, backgroundColor: "#E6F6ED", padding: 11, borderRadius: 12 }, savedText: { color: colors.success, fontWeight: "700", fontSize: 12 },
});
