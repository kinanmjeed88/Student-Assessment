import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { router, useLocalSearchParams } from "expo-router";
import { useEffect, useMemo, useState } from "react";
import { FlatList, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { ChoicePill, EmptyState, Field, PrimaryButton, ScreenHeader, SecondaryButton, Sheet, colors } from "@/components/app-ui";
import { ScreenContainer } from "@/components/screen-container";
import { calculateBehaviorSummary } from "@/lib/behavior";
import { toArabicDigits } from "@/lib/arabic-numbers-extension";
import { attentionFilterLabel, countStudentAbsences, filterStudentsByAttention, REPEATED_ABSENCE_THRESHOLD, type StudentAttentionFilter } from "@/lib/student-attention-filter";
import { sortStudentsArabic } from "@/lib/student-order";
import { useStudentStore, type Student } from "@/lib/student-store";
import { required, validPhone } from "@/lib/validation";

const BLUE_RIPPLE = { color: "rgba(23, 105, 209, 0.14)" } as const;

type Form = { studentNumber: string; firstName: string; fatherName: string; lastName: string; gender: "ذكر" | "أنثى"; classId: string; sectionId: string; guardianName: string; guardianPhone: string };
const emptyForm: Form = { studentNumber: "", firstName: "", fatherName: "", lastName: "", gender: "ذكر", classId: "", sectionId: "", guardianName: "", guardianPhone: "" };

export default function StudentsScreen() {
  const { data, addStudent } = useStudentStore();
  const params = useLocalSearchParams<{ add?: string }>();
  const [query, setQuery] = useState("");
  const [classId, setClassId] = useState("");
  const [sectionId, setSectionId] = useState("");
  const [attentionFilter, setAttentionFilter] = useState<StudentAttentionFilter>("all");
  const [filterOpen, setFilterOpen] = useState(false);
  const [formOpen, setFormOpen] = useState(false);
  const [form, setForm] = useState<Form>(emptyForm);
  const [errors, setErrors] = useState<Record<string, string>>({});

  useEffect(() => {
    if (params.add === "1") setFormOpen(true);
  }, [params.add]);

  const students = useMemo(() => {
    const scoped = data.students.filter((student) =>
      (!classId || student.classId === classId) &&
      (!sectionId || student.sectionId === sectionId) &&
      (!query || `${student.fullName} ${student.studentNumber}`.includes(query.trim())),
    );
    return sortStudentsArabic(filterStudentsByAttention(data, scoped, attentionFilter));
  }, [attentionFilter, classId, data, query, sectionId]);

  const classLabel = data.classes.find((item) => item.id === classId)?.name;
  const sectionLabel = data.sections.find((item) => item.id === sectionId)?.name;
  const activeScopeLabel = [
    sectionLabel ? `${classLabel} — ${sectionLabel}` : classLabel || "كل الصفوف",
    attentionFilter !== "all" ? attentionFilterLabel(attentionFilter) : "",
  ].filter(Boolean).join(" · ");

  const save = () => {
    const next = {
      firstName: required(form.firstName, "الاسم الأول"),
      lastName: required(form.lastName, "اسم العائلة"),
      classId: required(form.classId, "الصف"),
      sectionId: required(form.sectionId, "الشعبة"),
      guardianPhone: validPhone(form.guardianPhone),
    };
    const active = Object.fromEntries(Object.entries(next).filter(([, value]) => value)) as Record<string, string>;
    setErrors(active);
    if (Object.keys(active).length) return;
    const id = addStudent({ ...form, status: "نشط" });
    setForm(emptyForm);
    setFormOpen(false);
    router.push(`/student/${id}` as any);
  };

  return (
    <ScreenContainer edges={["top", "left", "right"]} className="p-4">
      <ScreenHeader title="الطلاب" subtitle={`${toArabicDigits(data.students.length)} طالبًا مسجلًا`} />

      <View style={styles.addStudentAction}>
        <PrimaryButton label="إضافة طالب" icon="person-add" onPress={() => setFormOpen(true)} />
      </View>
      <View style={styles.importAction}>
        <SecondaryButton label="استيراد الطلاب من ملف" icon="file-upload" onPress={() => router.push("/import-students" as any)} />
      </View>

      <View style={styles.searchRow}>
        <Pressable accessibilityRole="button" accessibilityLabel="تصفية الطلاب" onPress={() => setFilterOpen(true)} android_ripple={BLUE_RIPPLE} style={({ pressed }) => [styles.filter, pressed && styles.pressed]}>
          <MaterialIcons name="tune" color={colors.navy} size={21} />
        </Pressable>
        <View style={styles.search}>
          <MaterialIcons name="search" color={colors.muted} size={20} />
          <TextInput value={query} onChangeText={setQuery} placeholder="ابحث بالاسم أو الرقم" placeholderTextColor="#96A4B8" style={styles.searchInput} />
        </View>
      </View>

      <View style={styles.scopeRow}>
        <Text style={styles.filterText}>{activeScopeLabel}</Text>
        <Text style={styles.sortLabel}>ترتيب أبجدي</Text>
      </View>

      {students.length ? (
        <FlatList
          data={students}
          keyExtractor={(item) => item.id}
          style={styles.studentList}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          renderItem={({ item, index }) => <StudentListTile item={item} index={index} />}
        />
      ) : (
        <View style={styles.emptyWrap}>
          <EmptyState title="لا توجد نتائج" description="غيّر التصفية أو البحث، أو أضف طالبًا جديدًا." icon="group-off" action={<PrimaryButton label="إضافة طالب" icon="person-add" onPress={() => setFormOpen(true)} />} />
        </View>
      )}

      <Sheet visible={filterOpen} title="تصفية الطلاب" onClose={() => setFilterOpen(false)}>
        <ScrollView showsVerticalScrollIndicator={false}>
          <Text style={styles.sheetHint}>اختر الصف والشعبة، أو حالة المتابعة التي تريد عرضها.</Text>
          <Text style={styles.choiceLabel}>الصف</Text>
          <View style={styles.choices}>
            <ChoicePill label="الكل" selected={!classId} onPress={() => { setClassId(""); setSectionId(""); }} />
            {data.classes.map((item) => <ChoicePill key={item.id} label={item.name} selected={classId === item.id} onPress={() => { setClassId(item.id); setSectionId(""); }} />)}
          </View>
          <Text style={styles.choiceLabel}>الشعبة</Text>
          <View style={styles.choices}>
            <ChoicePill label="الكل" selected={!sectionId} onPress={() => setSectionId("")} />
            {data.sections.filter((item) => !classId || item.classId === classId).map((item) => <ChoicePill key={item.id} label={item.name} selected={sectionId === item.id} onPress={() => setSectionId(item.id)} />)}
          </View>
          <Text style={styles.choiceLabel}>حالة المتابعة</Text>
          <View style={styles.choices}>
            <ChoicePill label="كل الطلاب" selected={attentionFilter === "all"} onPress={() => setAttentionFilter("all")} />
            <ChoicePill label="تنبيه سلوكي" selected={attentionFilter === "behavior-alert"} onPress={() => setAttentionFilter("behavior-alert")} />
            <ChoicePill label={`غيابات متكررة (${toArabicDigits(REPEATED_ABSENCE_THRESHOLD)}+)`} selected={attentionFilter === "repeated-absence"} onPress={() => setAttentionFilter("repeated-absence")} />
          </View>
          <View style={styles.filterActions}>
            <SecondaryButton label="إعادة الضبط" icon="restart-alt" onPress={() => { setClassId(""); setSectionId(""); setAttentionFilter("all"); }} />
            <PrimaryButton label="تطبيق التصفية" icon="check" onPress={() => setFilterOpen(false)} />
          </View>
        </ScrollView>
      </Sheet>

      <StudentForm visible={formOpen} onClose={() => { setFormOpen(false); setErrors({}); }} data={data} form={form} setForm={setForm} errors={errors} onSave={save} />
    </ScreenContainer>
  );
}

function StudentListTile({ item, index }: { item: Student; index: number }) {
  const { data } = useStudentStore();
  const behavior = calculateBehaviorSummary(data, item.id);
  const absences = countStudentAbsences(data, item.id);
  const position = toArabicDigits(index + 1);
  const subtitle = `السلوك: ${toArabicDigits(behavior.totalPoints)} نقطة · الغيابات: ${toArabicDigits(absences)}`;

  return (
    <Pressable accessibilityRole="button" accessibilityLabel={`الطالب ${position}: ${item.fullName}`} onPress={() => router.push(`/student/${item.id}` as any)} android_ripple={BLUE_RIPPLE} style={({ pressed }) => [styles.listTile, pressed && styles.pressed]}>
      <View style={styles.numberCircle}>
        <Text style={styles.numberText}>{position}</Text>
      </View>
      <View style={styles.tileText}>
        <Text style={styles.studentName} numberOfLines={1}>{item.fullName}</Text>
        <Text style={[styles.studentSubtitle, behavior.risk !== "clear" && styles.warningSubtitle]} numberOfLines={1}>{subtitle}</Text>
      </View>
      <MaterialIcons name="chevron-left" size={23} color="#8B9AAF" />
    </Pressable>
  );
}

function StudentForm({ visible, onClose, data, form, setForm, errors, onSave }: { visible: boolean; onClose: () => void; data: ReturnType<typeof useStudentStore>["data"]; form: Form; setForm: (form: Form) => void; errors: Record<string, string>; onSave: () => void }) {
  const sections = data.sections.filter((item) => item.classId === form.classId);
  const set = (key: keyof Form, value: string) => setForm({ ...form, [key]: value, ...(key === "classId" ? { sectionId: "" } : {}) });

  return (
    <Sheet visible={visible} title="إضافة طالب" onClose={onClose}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.formContent}>
        <Field label="رقم الطالب" value={form.studentNumber} onChangeText={(value) => set("studentNumber", value)} keyboardType="numeric" placeholder="اختياري" />
        <Field label="الاسم الأول" value={form.firstName} onChangeText={(value) => set("firstName", value)} error={errors.firstName} />
        <Field label="اسم الأب" value={form.fatherName} onChangeText={(value) => set("fatherName", value)} placeholder="اختياري" />
        <Field label="اسم العائلة" value={form.lastName} onChangeText={(value) => set("lastName", value)} error={errors.lastName} />
        <Text style={styles.choiceLabel}>الجنس</Text>
        <View style={styles.choices}><ChoicePill label="ذكر" selected={form.gender === "ذكر"} onPress={() => set("gender", "ذكر")} /><ChoicePill label="أنثى" selected={form.gender === "أنثى"} onPress={() => set("gender", "أنثى")} /></View>
        <Text style={styles.choiceLabel}>الصف</Text>
        <View style={styles.choices}>{data.classes.map((item) => <ChoicePill key={item.id} label={item.name} selected={form.classId === item.id} onPress={() => set("classId", item.id)} />)}</View>
        {errors.classId ? <Text style={styles.formError}>{errors.classId}</Text> : null}
        <Text style={styles.choiceLabel}>الشعبة</Text>
        <View style={styles.choices}>{sections.map((item) => <ChoicePill key={item.id} label={item.name} selected={form.sectionId === item.id} onPress={() => set("sectionId", item.id)} />)}</View>
        {errors.sectionId ? <Text style={styles.formError}>{errors.sectionId}</Text> : null}
        <Field label="اسم ولي الأمر" value={form.guardianName} onChangeText={(value) => set("guardianName", value)} placeholder="اختياري" />
        <Field label="هاتف ولي الأمر" value={form.guardianPhone} onChangeText={(value) => set("guardianPhone", value)} keyboardType="phone-pad" error={errors.guardianPhone} placeholder="اختياري" />
        <PrimaryButton label="حفظ الطالب" icon="save" onPress={onSave} disabled={!data.classes.length || !data.sections.length} />
      </ScrollView>
    </Sheet>
  );
}

const styles = StyleSheet.create({
  addStudentAction: { marginBottom: 10 },
  importAction: { marginBottom: 12 },
  searchRow: { flexDirection: "row", gap: 9, marginBottom: 12 },
  filter: { width: 48, height: 48, borderRadius: 14, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.white, alignItems: "center", justifyContent: "center", overflow: "hidden" },
  search: { flex: 1, flexDirection: "row", alignItems: "center", gap: 8, backgroundColor: colors.white, borderColor: colors.border, borderWidth: 1, borderRadius: 14, paddingHorizontal: 14 },
  searchInput: { flex: 1, minHeight: 46, color: colors.ink, fontSize: 16, textAlign: "right", writingDirection: "rtl" },
  scopeRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8, marginBottom: 12 },
  filterText: { flex: 1, color: colors.muted, fontSize: 14, lineHeight: 20, textAlign: "right" },
  sortLabel: { color: colors.navy, fontSize: 13, fontWeight: "800" },
  studentList: { flex: 1 },
  listContent: { rowGap: 9, paddingBottom: 112 },
  listTile: { minHeight: 78, paddingHorizontal: 14, paddingVertical: 10, borderRadius: 16, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.white, flexDirection: "row", alignItems: "center", columnGap: 12, overflow: "hidden" },
  numberCircle: { width: 40, height: 40, borderRadius: 20, backgroundColor: colors.blueSurface, alignItems: "center", justifyContent: "center" },
  numberText: { color: colors.navy, fontSize: 15, fontWeight: "800" },
  tileText: { flex: 1, minWidth: 0, rowGap: 3, alignItems: "flex-end" },
  studentName: { color: colors.ink, fontSize: 16, lineHeight: 23, fontWeight: "800", textAlign: "right" },
  studentSubtitle: { color: colors.muted, fontSize: 12, lineHeight: 18, textAlign: "right" },
  warningSubtitle: { color: colors.danger, fontWeight: "700" },
  pressed: { opacity: 0.72 },
  emptyWrap: { flex: 1, justifyContent: "center", paddingBottom: 112 },
  sheetHint: { color: colors.muted, fontSize: 15, lineHeight: 22, marginBottom: 12, textAlign: "right" },
  choiceLabel: { color: colors.ink, fontSize: 15, fontWeight: "800", marginBottom: 8, textAlign: "right" },
  choices: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginBottom: 16 },
  filterActions: { flexDirection: "row", gap: 10, marginTop: 16 },
  formContent: { paddingBottom: 22 },
  formError: { color: colors.danger, fontSize: 14, lineHeight: 20, marginTop: -9, marginBottom: 13, textAlign: "right" },
});
