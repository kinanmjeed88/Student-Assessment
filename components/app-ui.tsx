import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import type { ReactNode } from "react";
import { ActivityIndicator, KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View, type TextInputProps } from "react-native";

export const colors = {
  navy: "#12355B", blue: "#1769D1", blueSurface: "#DCEBFF", pale: "#F4F7FB", ink: "#102A43", muted: "#52677F", border: "#C9D6E3",
  success: "#087A50", successSurface: "#DDF5E9", warning: "#A85E00", danger: "#B4232D", dangerSurface: "#FCE5E7", white: "#FBFCFF", overlay: "rgba(12, 32, 55, 0.44)",
} as const;

export function ScreenHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: ReactNode }) {
  return <View style={styles.header}><View style={styles.headerText}><Text style={styles.title} numberOfLines={2}>{title}</Text>{subtitle ? <Text style={styles.subtitle} numberOfLines={2}>{subtitle}</Text> : null}</View>{action ? <View style={styles.headerAction}>{action}</View> : null}</View>;
}

export function PrimaryButton({ label, icon, onPress, disabled, compact = false }: { label: string; icon?: keyof typeof MaterialIcons.glyphMap; onPress: () => void; disabled?: boolean; compact?: boolean }) {
  return <Pressable accessibilityRole="button" accessibilityState={{ disabled: Boolean(disabled) }} disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.primary, compact && styles.compact, (pressed || disabled) && styles.dim, disabled && styles.disabled]}><Text style={styles.primaryText} numberOfLines={1}>{label}</Text>{icon ? <MaterialIcons name={icon} color={colors.navy} size={20} /> : null}</Pressable>;
}

export function SecondaryButton({ label, icon, onPress, danger = false }: { label: string; icon?: keyof typeof MaterialIcons.glyphMap; onPress: () => void; danger?: boolean }) {
  return <Pressable accessibilityRole="button" onPress={onPress} style={({ pressed }) => [styles.secondary, danger && styles.dangerOutline, pressed && styles.dim]}>{icon ? <MaterialIcons name={icon} color={danger ? colors.danger : colors.navy} size={20} /> : null}<Text style={[styles.secondaryText, danger && styles.dangerText]} numberOfLines={1}>{label}</Text></Pressable>;
}

export function StatCard({ label, value, icon, color = colors.blue }: { label: string; value: string | number; icon: keyof typeof MaterialIcons.glyphMap; color?: string }) {
  return <View style={styles.statCard}><View style={[styles.iconCircle, { backgroundColor: `${color}1A` }]}><MaterialIcons name={icon} color={color} size={20} /></View><Text style={styles.statValue} numberOfLines={1}>{value}</Text><Text style={styles.statLabel} numberOfLines={2}>{label}</Text></View>;
}

export function StatusBadge({ label, tone = "blue" }: { label: string; tone?: "blue" | "green" | "orange" | "red" }) {
  const toneStyles = { blue: [styles.badge, styles.badgeBlue], green: [styles.badge, styles.badgeGreen], orange: [styles.badge, styles.badgeOrange], red: [styles.badge, styles.badgeRed] };
  return <View style={toneStyles[tone]}><Text style={styles.badgeText} numberOfLines={1}>{label}</Text></View>;
}

export function ChoicePill({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return <Pressable accessibilityRole="button" accessibilityState={{ selected }} onPress={onPress} style={({ pressed }) => [styles.pill, selected && styles.pillSelected, pressed && styles.dim]}><Text style={[styles.pillText, selected && styles.pillTextSelected]} numberOfLines={1}>{label}</Text></Pressable>;
}

export function SuccessNotice({ message }: { message: string }) {
  return <View accessibilityRole="alert" style={styles.successNotice}><MaterialIcons name="check-circle" color={colors.success} size={22} /><Text style={styles.successNoticeText}>{message}</Text></View>;
}

export function Field({ label, error, multiline, style, ...props }: TextInputProps & { label: string; error?: string; multiline?: boolean }) {
  return <View style={styles.field}><Text style={styles.fieldLabel}>{label}</Text><TextInput {...props} multiline={multiline} placeholderTextColor="#71839A" selectionColor={colors.blue} textAlign="right" style={[styles.input, multiline && styles.multiline, error && styles.inputError, style]} />{error ? <Text style={styles.errorText}>{error}</Text> : null}</View>;
}

export function EmptyState({ title, description, icon = "inbox", action }: { title: string; description: string; icon?: keyof typeof MaterialIcons.glyphMap; action?: ReactNode }) {
  return <View style={styles.empty}><View style={styles.emptyIcon}><MaterialIcons name={icon} size={30} color={colors.blue} /></View><Text style={styles.emptyTitle}>{title}</Text><Text style={styles.emptyText}>{description}</Text>{action ? <View style={styles.emptyAction}>{action}</View> : null}</View>;
}

export function Sheet({ visible, title, onClose, children }: { visible: boolean; title: string; onClose: () => void; children: ReactNode }) {
  return <Modal animationType="slide" transparent visible={visible} statusBarTranslucent onRequestClose={onClose}><KeyboardAvoidingView style={styles.modalBackdrop} behavior={Platform.select({ ios: "padding", android: "height" })}><View style={styles.sheet}><View style={styles.sheetHeader}><Text style={styles.sheetTitle} numberOfLines={1}>{title}</Text><Pressable accessibilityRole="button" accessibilityLabel="إغلاق" onPress={onClose} style={styles.close}><MaterialIcons name="close" size={22} color={colors.ink} /></Pressable></View><ScrollView style={styles.sheetContent} contentContainerStyle={styles.sheetScrollContent} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>{children}</ScrollView></View></KeyboardAvoidingView></Modal>;
}

export function LoadingScreen() { return <View style={styles.loading}><ActivityIndicator size="large" color={colors.blue} /><Text style={styles.loadingText}>يتم تجهيز بيانات المدرسة...</Text></View>; }

const styles = StyleSheet.create({
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start", columnGap: 14, marginBottom: 22 }, headerText: { flex: 1, minWidth: 0, alignItems: "flex-end" }, headerAction: { flexShrink: 0 },
  title: { color: colors.ink, fontSize: 29, lineHeight: 38, fontWeight: "800", textAlign: "right" }, subtitle: { color: colors.muted, fontSize: 16, lineHeight: 24, textAlign: "right", marginTop: 3 },
  primary: { backgroundColor: colors.blueSurface, borderColor: colors.blue, borderWidth: 1.5, minHeight: 52, paddingHorizontal: 18, borderRadius: 14, flexDirection: "row", alignItems: "center", justifyContent: "center", columnGap: 8, alignSelf: "stretch" }, compact: { minHeight: 44, paddingHorizontal: 14, alignSelf: "auto" }, primaryText: { color: colors.navy, fontSize: 16, lineHeight: 23, fontWeight: "800", textAlign: "center", flexShrink: 1 }, disabled: { backgroundColor: "#E5EBF2", borderColor: "#C9D6E3" }, dim: { opacity: 0.72, transform: [{ scale: 0.985 }] },
  secondary: { minHeight: 46, borderRadius: 13, paddingHorizontal: 14, borderWidth: 1, borderColor: "#9DBCE2", backgroundColor: "#EDF5FF", flexDirection: "row", alignItems: "center", justifyContent: "center", columnGap: 7, flexShrink: 1 }, secondaryText: { color: colors.navy, fontWeight: "800", fontSize: 15, lineHeight: 21, textAlign: "center", flexShrink: 1 }, dangerOutline: { borderColor: "#E6A8AE", backgroundColor: colors.dangerSurface }, dangerText: { color: colors.danger },
  statCard: { flex: 1, minWidth: 0, backgroundColor: colors.white, borderRadius: 18, borderWidth: 1, borderColor: colors.border, padding: 14, alignItems: "flex-end", rowGap: 6 }, iconCircle: { width: 42, height: 42, borderRadius: 21, alignItems: "center", justifyContent: "center", alignSelf: "flex-end" }, statValue: { color: colors.ink, fontSize: 23, fontWeight: "800", lineHeight: 30, textAlign: "right" }, statLabel: { color: colors.muted, fontSize: 14, lineHeight: 20, textAlign: "right" },
  badge: { borderRadius: 20, paddingHorizontal: 11, paddingVertical: 6, maxWidth: "100%" }, badgeBlue: { backgroundColor: colors.blueSurface }, badgeGreen: { backgroundColor: colors.successSurface }, badgeOrange: { backgroundColor: "#FFF0D5" }, badgeRed: { backgroundColor: colors.dangerSurface }, badgeText: { color: colors.ink, fontSize: 13, lineHeight: 18, fontWeight: "800", textAlign: "center" },
  pill: { borderWidth: 1.25, borderColor: colors.border, backgroundColor: "#F8FAFD", borderRadius: 18, minHeight: 42, paddingHorizontal: 14, alignItems: "center", justifyContent: "center", flexShrink: 0 }, pillSelected: { borderColor: colors.blue, backgroundColor: colors.blueSurface }, pillText: { color: colors.navy, fontSize: 14, lineHeight: 20, fontWeight: "800", textAlign: "center" }, pillTextSelected: { color: colors.navy },
  field: { rowGap: 6, marginBottom: 16 }, fieldLabel: { color: colors.ink, textAlign: "right", fontWeight: "800", fontSize: 15, lineHeight: 22 }, input: { minHeight: 52, backgroundColor: "#F8FAFD", borderWidth: 1.25, borderColor: colors.border, borderRadius: 14, color: colors.ink, paddingHorizontal: 15, fontSize: 17, lineHeight: 24, writingDirection: "rtl" }, multiline: { minHeight: 112, textAlignVertical: "top", paddingTop: 14 }, inputError: { borderColor: colors.danger, backgroundColor: "#FFF6F6" }, errorText: { color: colors.danger, textAlign: "right", fontSize: 14, lineHeight: 20, fontWeight: "700" },
  empty: { borderWidth: 1, borderColor: colors.border, borderStyle: "dashed", backgroundColor: colors.white, borderRadius: 20, padding: 28, alignItems: "center", rowGap: 10 }, emptyIcon: { backgroundColor: colors.blueSurface, width: 60, height: 60, borderRadius: 30, alignItems: "center", justifyContent: "center" }, emptyTitle: { color: colors.ink, fontSize: 19, lineHeight: 27, fontWeight: "800", textAlign: "center" }, emptyText: { color: colors.muted, fontSize: 15, lineHeight: 23, textAlign: "center" }, emptyAction: { marginTop: 8, alignSelf: "stretch" },
  successNotice: { flexDirection: "row", alignItems: "center", justifyContent: "flex-start", columnGap: 9, backgroundColor: colors.successSurface, borderRadius: 14, borderWidth: 1, borderColor: "#9AD6BA", paddingHorizontal: 14, paddingVertical: 12 }, successNoticeText: { flex: 1, color: colors.success, fontSize: 15, lineHeight: 22, fontWeight: "800", textAlign: "right" },
  modalBackdrop: { flex: 1, backgroundColor: colors.overlay, justifyContent: "flex-end" }, sheet: { backgroundColor: colors.pale, borderTopLeftRadius: 28, borderTopRightRadius: 28, maxHeight: "92%", paddingHorizontal: 22, paddingTop: 18, paddingBottom: 30 }, sheetHeader: { minHeight: 44, alignItems: "center", justifyContent: "center", marginBottom: 18, position: "relative" }, sheetTitle: { color: colors.ink, fontWeight: "800", fontSize: 21, lineHeight: 30, textAlign: "center", paddingHorizontal: 48 }, close: { position: "absolute", left: 0, width: 42, height: 42, borderRadius: 21, backgroundColor: "#F8FAFD", alignItems: "center", justifyContent: "center", borderWidth: 1, borderColor: colors.border }, sheetContent: { flexGrow: 0 }, sheetScrollContent: { paddingBottom: 8 },
  loading: { flex: 1, alignItems: "center", justifyContent: "center", rowGap: 12, backgroundColor: colors.pale }, loadingText: { color: colors.muted, fontSize: 16 },
});
