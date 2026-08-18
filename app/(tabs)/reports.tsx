import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { Modal, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { useState } from "react";
import { EmptyState, PrimaryButton, ScreenHeader, SecondaryButton, colors } from "@/components/app-ui";
import { ScreenContainer } from "@/components/screen-container";
import { buildSchoolReport, sharePdf, shareWorkbook } from "@/lib/reporting";
import { useStudentStore } from "@/lib/student-store";
import { toArabicDigits } from "@/lib/arabic-numbers-extension";

export default function ReportsScreen() {
  const { data, showSuccess } = useStudentStore();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const exportPdf = async () => {
    try {
      await sharePdf(buildSchoolReport(data), "تقرير المدرسة");
      showSuccess("تم إنشاء تقرير PDF بنجاح.");
    } catch {
      setErrorMessage("تعذر إنشاء التقرير. تحقق من صلاحية مشاركة الملفات وحاول مرة أخرى.");
    }
  };

  const exportExcel = async () => {
    try {
      await shareWorkbook(data, "بيانات_المدرسة");
      showSuccess("تم إنشاء ملف Excel بنجاح.");
    } catch {
      setErrorMessage("تعذر إنشاء ملف Excel. حاول مرة أخرى بعد إضافة بعض البيانات.");
    }
  };

  return (
    <ScreenContainer edges={["top", "left", "right"]}>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <ScreenHeader title="التقارير والتصدير" subtitle="ملفات منظمة قابلة للطباعة والمشاركة" />

        <View style={styles.hero}>
          <View style={styles.heroIcon}>
            <MaterialIcons name="description" size={29} color={colors.blue} />
          </View>
          <Text style={styles.heroTitle}>تقرير المدرسة العام</Text>
          <Text style={styles.heroText}>
            يشمل كشف الطلاب وإجماليات اليوم، ويستخدم اسم المدرسة والمدرس في رأس التقرير.
          </Text>
          <View style={styles.heroButtons}>
            <PrimaryButton label="PDF بحجم A4" icon="picture-as-pdf" onPress={exportPdf} />
            <SecondaryButton label="Excel" icon="table-view" onPress={exportExcel} />
          </View>
        </View>

        <Text style={styles.sectionTitle}>ماذا يتضمن التصدير؟</Text>
        <View style={styles.rows}>
          <ReportRow icon="groups" title="كشف الطلاب" text={`${toArabicDigits(data.students.length)} طالبًا مع الصف والشعبة والحالة.`} />
          <ReportRow icon="fact-check" title="الحضور والغياب" text={`${toArabicDigits(data.attendance.length)} سجل حضور محفوظ.`} />
          <ReportRow icon="grade" title="الدرجات" text={`${toArabicDigits(data.grades.length)} درجة مسجلة ضمن حقول تقييم مرنة.`} />
        </View>

        {!data.students.length ? (
          <EmptyState title="التقرير بانتظار البيانات" description="أضف الصفوف والشعب والطلاب أولًا لتنتج تقارير مفيدة." icon="analytics" />
        ) : null}

        <View style={styles.note}>
          <MaterialIcons name="info-outline" size={19} color={colors.navy} />
          <Text style={styles.noteText}>
            يمكنك تصدير ملف الطالب المفصل مباشرةً من داخل ملفه الشخصي، أما هذه الشاشة فتنتج تقرير المدرسة العام وملف Excel متعدد الأوراق.
          </Text>
        </View>
      </ScrollView>
      <ReportErrorModal message={errorMessage} onClose={() => setErrorMessage(null)} />
    </ScreenContainer>
  );
}

function ReportErrorModal({ message, onClose }: { message: string | null; onClose: () => void }) {
  return (
    <Modal transparent visible={Boolean(message)} animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={styles.errorModal}>
          <View style={styles.errorIcon}><MaterialIcons name="error-outline" size={28} color={colors.danger} /></View>
          <Text style={styles.errorTitle}>تعذر تنفيذ العملية</Text>
          <Text style={styles.errorMessage}>{message}</Text>
          <Pressable accessibilityRole="button" onPress={onClose} style={({ pressed }) => [styles.errorButton, pressed && styles.errorButtonPressed]}>
            <Text style={styles.errorButtonText}>حسنًا</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

function ReportRow({ icon, title, text }: { icon: keyof typeof MaterialIcons.glyphMap; title: string; text: string }) {
  return (
    <View style={styles.reportRow}>
      <View style={styles.rowIcon}>
        <MaterialIcons name={icon} size={21} color={colors.blue} />
      </View>
      <View style={styles.rowText}>
        <Text style={styles.rowTitle}>{title}</Text>
        <Text style={styles.rowSub}>{text}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  content: { gap: 18, paddingBottom: 48 },
  hero: { backgroundColor: colors.white, borderRadius: 22, borderWidth: 1.5, borderColor: colors.blue, padding: 20, alignItems: "flex-end", gap: 10 },
  heroIcon: { width: 48, height: 48, borderRadius: 24, backgroundColor: colors.blueSurface, alignItems: "center", justifyContent: "center" },
  heroTitle: { color: colors.ink, fontSize: 21, lineHeight: 29, fontWeight: "800", textAlign: "right" },
  heroText: { color: colors.muted, fontSize: 15, lineHeight: 23, textAlign: "right" },
  heroButtons: { flexDirection: "row-reverse", gap: 10, width: "100%" },
  sectionTitle: { color: colors.ink, fontSize: 18, lineHeight: 26, fontWeight: "800", textAlign: "right", marginTop: 6 },
  rows: { backgroundColor: colors.white, borderRadius: 18, borderWidth: 1, borderColor: colors.border, overflow: "hidden" },
  reportRow: { minHeight: 74, paddingHorizontal: 16, flexDirection: "row-reverse", alignItems: "center", gap: 12, borderBottomWidth: 1, borderBottomColor: "#EEF2F6" },
  rowIcon: { width: 42, height: 42, borderRadius: 21, alignItems: "center", justifyContent: "center", backgroundColor: "#E9F1FA" },
  rowText: { flex: 1, alignItems: "flex-end" },
  rowTitle: { color: colors.ink, fontSize: 16, lineHeight: 22, fontWeight: "800", textAlign: "right" },
  rowSub: { color: colors.muted, fontSize: 14, lineHeight: 20, marginTop: 3, textAlign: "right" },
  note: { borderRadius: 16, backgroundColor: "#E9F1FA", padding: 16, flexDirection: "row-reverse", alignItems: "flex-start", gap: 10 },
  noteText: { flex: 1, color: colors.navy, textAlign: "right", fontSize: 14, lineHeight: 22 },
  modalBackdrop: { flex: 1, backgroundColor: "rgba(12, 32, 55, 0.44)", alignItems: "center", justifyContent: "center", paddingHorizontal: 24 },
  errorModal: { width: "100%", maxWidth: 420, backgroundColor: colors.white, borderRadius: 22, padding: 24, alignItems: "center", gap: 10, borderWidth: 1, borderColor: colors.border },
  errorIcon: { width: 56, height: 56, borderRadius: 28, backgroundColor: colors.dangerSurface, alignItems: "center", justifyContent: "center" },
  errorTitle: { color: colors.ink, fontSize: 19, lineHeight: 27, fontWeight: "800", textAlign: "center" },
  errorMessage: { color: colors.muted, fontSize: 15, lineHeight: 23, textAlign: "center" },
  errorButton: { minHeight: 46, minWidth: 130, borderRadius: 13, backgroundColor: colors.blue, alignItems: "center", justifyContent: "center", paddingHorizontal: 24, marginTop: 6 },
  errorButtonPressed: { opacity: 0.78 },
  errorButtonText: { color: colors.white, fontSize: 16, lineHeight: 22, fontWeight: "800" },
});
