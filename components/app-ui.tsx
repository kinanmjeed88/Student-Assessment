import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import type { ReactNode } from "react";
import { ActivityIndicator, Modal, Pressable, StyleSheet, Text, TextInput, View, type TextInputProps } from "react-native";

export const colors = { navy: "#12355B", blue: "#2F80ED", pale: "#F7F9FC", ink: "#172B4D", muted: "#607084", border: "#D7E0EA", success: "#1F9D70", warning: "#E9A23B", danger: "#D64545", white: "#FFFFFF" };

export function ScreenHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: ReactNode }) {
  return <View style={styles.header}><View style={styles.headerText}><Text style={styles.title}>{title}</Text>{subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}</View>{action}</View>;
}

export function PrimaryButton({ label, icon, onPress, disabled, compact = false }: { label: string; icon?: keyof typeof MaterialIcons.glyphMap; onPress: () => void; disabled?: boolean; compact?: boolean }) {
  return <Pressable accessibilityRole="button" disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.primary, compact && styles.compact, (pressed || disabled) && styles.dim, disabled && styles.disabled]}><Text style={styles.primaryText}>{label}</Text>{icon ? <MaterialIcons name={icon} color={colors.white} size={19} /> : null}</Pressable>;
}

export function SecondaryButton({ label, icon, onPress, danger = false }: { label: string; icon?: keyof typeof MaterialIcons.glyphMap; onPress: () => void; danger?: boolean }) {
  return <Pressable accessibilityRole="button" onPress={onPress} style={({ pressed }) => [styles.secondary, danger && styles.dangerOutline, pressed && styles.dim]}>{icon ? <MaterialIcons name={icon} color={danger ? colors.danger : colors.navy} size={18} /> : null}<Text style={[styles.secondaryText, danger && { color: colors.danger }]}>{label}</Text></Pressable>;
}

export function StatCard({ label, value, icon, color = colors.blue }: { label: string; value: string | number; icon: keyof typeof MaterialIcons.glyphMap; color?: string }) {
  return <View style={styles.statCard}><View style={[styles.iconCircle, { backgroundColor: `${color}18` }]}><MaterialIcons name={icon} color={color} size={20} /></View><Text style={styles.statValue}>{value}</Text><Text style={styles.statLabel}>{label}</Text></View>;
}

export function StatusBadge({ label, tone = "blue" }: { label: string; tone?: "blue" | "green" | "orange" | "red" }) {
  const toneStyles = { blue: [styles.badge, styles.badgeBlue], green: [styles.badge, styles.badgeGreen], orange: [styles.badge, styles.badgeOrange], red: [styles.badge, styles.badgeRed] };
  return <View style={toneStyles[tone]}><Text style={styles.badgeText}>{label}</Text></View>;
}

export function ChoicePill({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return <Pressable accessibilityRole="button" onPress={onPress} style={({ pressed }) => [styles.pill, selected && styles.pillSelected, pressed && styles.dim]}><Text style={[styles.pillText, selected && styles.pillTextSelected]}>{label}</Text></Pressable>;
}

export function Field({ label, error, multiline, ...props }: TextInputProps & { label: string; error?: string; multiline?: boolean }) {
  return <View style={styles.field}><Text style={styles.fieldLabel}>{label}</Text><TextInput placeholderTextColor="#96A4B8" textAlign="right" style={[styles.input, multiline && styles.multiline, error && styles.inputError]} multiline={multiline} {...props} />{error ? <Text style={styles.errorText}>{error}</Text> : null}</View>;
}

export function EmptyState({ title, description, icon = "inbox", action }: { title: string; description: string; icon?: keyof typeof MaterialIcons.glyphMap; action?: ReactNode }) {
  return <View style={styles.empty}><View style={styles.emptyIcon}><MaterialIcons name={icon} size={30} color={colors.blue} /></View><Text style={styles.emptyTitle}>{title}</Text><Text style={styles.emptyText}>{description}</Text>{action ? <View style={{ marginTop: 12 }}>{action}</View> : null}</View>;
}

export function Sheet({ visible, title, onClose, children }: { visible: boolean; title: string; onClose: () => void; children: ReactNode }) {
  return <Modal animationType="slide" transparent visible={visible} onRequestClose={onClose}><View style={styles.modalBackdrop}><View style={styles.sheet}><View style={styles.sheetHeader}><Pressable accessibilityLabel="إغلاق" onPress={onClose} style={styles.close}><MaterialIcons name="close" size={22} color={colors.ink} /></Pressable><Text style={styles.sheetTitle}>{title}</Text><View style={{ width: 34 }} /></View>{children}</View></View></Modal>;
}

export function LoadingScreen() { return <View style={styles.loading}><ActivityIndicator size="large" color={colors.blue} /><Text style={styles.loadingText}>يتم تجهيز بيانات المدرسة...</Text></View>; }

const styles = StyleSheet.create({
  header: { flexDirection: "row-reverse", justifyContent: "space-between", alignItems: "flex-start", gap: 12, marginBottom: 18 }, headerText: { flex: 1, alignItems: "flex-end" }, title: { color: colors.ink, fontSize: 27, lineHeight: 35, fontWeight: "800", textAlign: "right" }, subtitle: { color: colors.muted, fontSize: 13, lineHeight: 20, textAlign: "right", marginTop: 2 },
  primary: { backgroundColor: colors.navy, minHeight: 44, paddingHorizontal: 15, borderRadius: 13, flexDirection: "row-reverse", alignItems: "center", justifyContent: "center", gap: 7 }, compact: { minHeight: 38, paddingHorizontal: 12 }, primaryText: { color: colors.white, fontSize: 14, fontWeight: "800" }, disabled: { backgroundColor: "#9AAAB9" }, dim: { opacity: 0.75, transform: [{ scale: 0.98 }] },
  secondary: { minHeight: 40, borderRadius: 11, paddingHorizontal: 11, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.white, flexDirection: "row-reverse", alignItems: "center", justifyContent: "center", gap: 5 }, secondaryText: { color: colors.navy, fontWeight: "700", fontSize: 13 }, dangerOutline: { borderColor: "#F1C4C4" },
  statCard: { flex: 1, minWidth: 100, backgroundColor: colors.white, borderRadius: 16, borderWidth: 1, borderColor: colors.border, padding: 12, alignItems: "flex-end", gap: 4 }, iconCircle: { width: 34, height: 34, borderRadius: 17, alignItems: "center", justifyContent: "center", alignSelf: "flex-end" }, statValue: { color: colors.ink, fontSize: 22, fontWeight: "800", lineHeight: 28 }, statLabel: { color: colors.muted, fontSize: 11, lineHeight: 16, textAlign: "right" },
  badge: { borderRadius: 20, paddingHorizontal: 9, paddingVertical: 4, alignSelf: "flex-start" }, badgeBlue: { backgroundColor: "#E9F1FA" }, badgeGreen: { backgroundColor: "#DFF3E9" }, badgeOrange: { backgroundColor: "#FFF0D7" }, badgeRed: { backgroundColor: "#FDE8E7" }, badgeText: { color: colors.ink, fontSize: 11, fontWeight: "700" },
  pill: { borderWidth: 1, borderColor: colors.border, backgroundColor: colors.white, borderRadius: 18, minHeight: 35, paddingHorizontal: 12, alignItems: "center", justifyContent: "center" }, pillSelected: { borderColor: colors.navy, backgroundColor: colors.navy }, pillText: { color: colors.muted, fontSize: 12, fontWeight: "700" }, pillTextSelected: { color: colors.white },
  field: { gap: 5, marginBottom: 12 }, fieldLabel: { color: colors.ink, textAlign: "right", fontWeight: "700", fontSize: 13 }, input: { minHeight: 46, backgroundColor: colors.white, borderWidth: 1, borderColor: colors.border, borderRadius: 12, color: colors.ink, paddingHorizontal: 12, fontSize: 15, writingDirection: "rtl" }, multiline: { minHeight: 86, textAlignVertical: "top", paddingTop: 11 }, inputError: { borderColor: colors.danger }, errorText: { color: colors.danger, textAlign: "right", fontSize: 11 },
  empty: { borderWidth: 1, borderColor: colors.border, borderStyle: "dashed", backgroundColor: colors.white, borderRadius: 18, padding: 24, alignItems: "center", gap: 7 }, emptyIcon: { backgroundColor: "#E9F1FA", width: 56, height: 56, borderRadius: 28, alignItems: "center", justifyContent: "center" }, emptyTitle: { color: colors.ink, fontSize: 16, fontWeight: "800", textAlign: "center" }, emptyText: { color: colors.muted, fontSize: 13, lineHeight: 20, textAlign: "center" },
  modalBackdrop: { flex: 1, backgroundColor: "rgba(17,35,60,0.42)", justifyContent: "flex-end" }, sheet: { backgroundColor: colors.pale, borderTopLeftRadius: 24, borderTopRightRadius: 24, minHeight: "42%", maxHeight: "88%", padding: 18 }, sheetHeader: { flexDirection: "row-reverse", alignItems: "center", justifyContent: "space-between", marginBottom: 15 }, sheetTitle: { color: colors.ink, fontWeight: "800", fontSize: 18 }, close: { width: 34, height: 34, borderRadius: 17, backgroundColor: colors.white, alignItems: "center", justifyContent: "center" },
  loading: { flex: 1, alignItems: "center", justifyContent: "center", gap: 12, backgroundColor: colors.pale }, loadingText: { color: colors.muted, fontSize: 14 },
});
