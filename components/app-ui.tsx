import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import type { ReactNode } from "react";
import { ActivityIndicator, KeyboardAvoidingView, Modal, Platform, Pressable, StyleSheet, Text, TextInput, View, type TextInputProps } from "react-native";

export const colors = {
  navy: "#12355B", blue: "#1769D1", pale: "#F4F7FB", ink: "#102A43", muted: "#52677F", border: "#D7E0EA",
  success: "#16835D", warning: "#B76B09", danger: "#C83B3B", white: "#FFFFFF", overlay: "rgba(12, 32, 55, 0.44)",
} as const;

export function ScreenHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: ReactNode }) {
  return <View style={styles.header}><View style={styles.headerText}><Text style={styles.title} numberOfLines={2}>{title}</Text>{subtitle ? <Text style={styles.subtitle} numberOfLines={2}>{subtitle}</Text> : null}</View>{action ? <View style={styles.headerAction}>{action}</View> : null}</View>;
}

export function PrimaryButton({ label, icon, onPress, disabled, compact = false }: { label: string; icon?: keyof typeof MaterialIcons.glyphMap; onPress: () => void; disabled?: boolean; compact?: boolean }) {
  return <Pressable accessibilityRole="button" accessibilityState={{ disabled: Boolean(disabled) }} disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.primary, compact && styles.compact, (pressed || disabled) && styles.dim, disabled && styles.disabled]}><Text style={styles.primaryText} numberOfLines={1}>{label}</Text>{icon ? <MaterialIcons name={icon} color={colors.white} size={19} /> : null}</Pressable>;
}

export function SecondaryButton({ label, icon, onPress, danger = false }: { label: string; icon?: keyof typeof MaterialIcons.glyphMap; onPress: () => void; danger?: boolean }) {
  return <Pressable accessibilityRole="button" onPress={onPress} style={({ pressed }) => [styles.secondary, danger && styles.dangerOutline, pressed && styles.dim]}>{icon ? <MaterialIcons name={icon} color={danger ? colors.danger : colors.navy} size={18} /> : null}<Text style={[styles.secondaryText, danger && styles.dangerText]} numberOfLines={1}>{label}</Text></Pressable>;
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

export function Field({ label, error, multiline, style, ...props }: TextInputProps & { label: string; error?: string; multiline?: boolean }) {
  return <View style={styles.field}><Text style={styles.fieldLabel}>{label}</Text><TextInput {...props} multiline={multiline} placeholderTextColor="#71839A" selectionColor={colors.blue} textAlign="right" style={[styles.input, multiline && styles.multiline, error && styles.inputError, style]} />{error ? <Text style={styles.errorText}>{error}</Text> : null}</View>;
}

export function EmptyState({ title, description, icon = "inbox", action }: { title: string; description: string; icon?: keyof typeof MaterialIcons.glyphMap; action?: ReactNode }) {
  return <View style={styles.empty}><View style={styles.emptyIcon}><MaterialIcons name={icon} size={30} color={colors.blue} /></View><Text style={styles.emptyTitle}>{title}</Text><Text style={styles.emptyText}>{description}</Text>{action ? <View style={styles.emptyAction}>{action}</View> : null}</View>;
}

export function Sheet({ visible, title, onClose, children }: { visible: boolean; title: string; onClose: () => void; children: ReactNode }) {
  return <Modal animationType="slide" transparent visible={visible} statusBarTranslucent onRequestClose={onClose}><KeyboardAvoidingView style={styles.modalBackdrop} behavior={Platform.OS === "ios" ? "padding" : undefined}><View style={styles.sheet}><View style={styles.sheetHeader}><Text style={styles.sheetTitle} numberOfLines={1}>{title}</Text><Pressable accessibilityRole="button" accessibilityLabel="إغلاق" onPress={onClose} style={styles.close}><MaterialIcons name="close" size={22} color={colors.ink} /></Pressable></View><View style={styles.sheetContent}>{children}</View></View></KeyboardAvoidingView></Modal>;
}

export function LoadingScreen() { return <View style={styles.loading}><ActivityIndicator size="large" color={colors.blue} /><Text style={styles.loadingText}>يتم تجهيز بيانات المدرسة...</Text></View>; }

const styles = StyleSheet.create({
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start", columnGap: 12, marginBottom: 18 }, headerText: { flex: 1, minWidth: 0, alignItems: "flex-end" }, headerAction: { flexShrink: 0 },
  title: { color: colors.ink, fontSize: 27, lineHeight: 35, fontWeight: "800", textAlign: "right" }, subtitle: { color: colors.muted, fontSize: 13, lineHeight: 20, textAlign: "right", marginTop: 2 },
  primary: { backgroundColor: colors.navy, minHeight: 46, paddingHorizontal: 16, borderRadius: 13, flexDirection: "row", alignItems: "center", justifyContent: "center", columnGap: 7, alignSelf: "stretch" }, compact: { minHeight: 40, paddingHorizontal: 12, alignSelf: "auto" }, primaryText: { color: colors.white, fontSize: 14, lineHeight: 20, fontWeight: "800", textAlign: "center", flexShrink: 1 }, disabled: { backgroundColor: "#8EA0B3" }, dim: { opacity: 0.76, transform: [{ scale: 0.985 }] },
  secondary: { minHeight: 40, borderRadius: 11, paddingHorizontal: 11, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.white, flexDirection: "row", alignItems: "center", justifyContent: "center", columnGap: 5, flexShrink: 1 }, secondaryText: { color: colors.navy, fontWeight: "700", fontSize: 13, lineHeight: 18, textAlign: "center", flexShrink: 1 }, dangerOutline: { borderColor: "#E7B6B6", backgroundColor: "#FFF9F9" }, dangerText: { color: colors.danger },
  statCard: { flex: 1, minWidth: 0, backgroundColor: colors.white, borderRadius: 16, borderWidth: 1, borderColor: colors.border, padding: 12, alignItems: "flex-end", rowGap: 4 }, iconCircle: { width: 36, height: 36, borderRadius: 18, alignItems: "center", justifyContent: "center", alignSelf: "flex-end" }, statValue: { color: colors.ink, fontSize: 22, fontWeight: "800", lineHeight: 28, textAlign: "right" }, statLabel: { color: colors.muted, fontSize: 11, lineHeight: 16, textAlign: "right" },
  badge: { borderRadius: 20, paddingHorizontal: 9, paddingVertical: 4, maxWidth: "100%" }, badgeBlue: { backgroundColor: "#E3F0FF" }, badgeGreen: { backgroundColor: "#DCF5E8" }, badgeOrange: { backgroundColor: "#FFF0D5" }, badgeRed: { backgroundColor: "#FCE2E2" }, badgeText: { color: colors.ink, fontSize: 11, lineHeight: 15, fontWeight: "700", textAlign: "center" },
  pill: { borderWidth: 1, borderColor: colors.border, backgroundColor: colors.white, borderRadius: 18, minHeight: 36, paddingHorizontal: 12, alignItems: "center", justifyContent: "center", flexShrink: 0 }, pillSelected: { borderColor: colors.navy, backgroundColor: colors.navy }, pillText: { color: colors.navy, fontSize: 12, lineHeight: 17, fontWeight: "700", textAlign: "center" }, pillTextSelected: { color: colors.white },
  field: { rowGap: 5, marginBottom: 13 }, fieldLabel: { color: colors.ink, textAlign: "right", fontWeight: "700", fontSize: 13, lineHeight: 19 }, input: { minHeight: 48, backgroundColor: colors.white, borderWidth: 1, borderColor: colors.border, borderRadius: 12, color: colors.ink, paddingHorizontal: 13, fontSize: 15, lineHeight: 21, writingDirection: "rtl" }, multiline: { minHeight: 92, textAlignVertical: "top", paddingTop: 12 }, inputError: { borderColor: colors.danger }, errorText: { color: colors.danger, textAlign: "right", fontSize: 11, lineHeight: 16 },
  empty: { borderWidth: 1, borderColor: colors.border, borderStyle: "dashed", backgroundColor: colors.white, borderRadius: 18, padding: 24, alignItems: "center", rowGap: 8 }, emptyIcon: { backgroundColor: "#E6F1FF", width: 56, height: 56, borderRadius: 28, alignItems: "center", justifyContent: "center" }, emptyTitle: { color: colors.ink, fontSize: 16, lineHeight: 23, fontWeight: "800", textAlign: "center" }, emptyText: { color: colors.muted, fontSize: 13, lineHeight: 20, textAlign: "center" }, emptyAction: { marginTop: 6, alignSelf: "stretch" },
  modalBackdrop: { flex: 1, backgroundColor: colors.overlay, justifyContent: "flex-end" }, sheet: { backgroundColor: colors.pale, borderTopLeftRadius: 26, borderTopRightRadius: 26, maxHeight: "90%", paddingHorizontal: 18, paddingTop: 16, paddingBottom: 24 }, sheetHeader: { minHeight: 40, alignItems: "center", justifyContent: "center", marginBottom: 15, position: "relative" }, sheetTitle: { color: colors.ink, fontWeight: "800", fontSize: 19, lineHeight: 27, textAlign: "center", paddingHorizontal: 44 }, close: { position: "absolute", left: 0, width: 36, height: 36, borderRadius: 18, backgroundColor: colors.white, alignItems: "center", justifyContent: "center", borderWidth: 1, borderColor: "#E8EEF5" }, sheetContent: { flexShrink: 1 },
  loading: { flex: 1, alignItems: "center", justifyContent: "center", rowGap: 12, backgroundColor: colors.pale }, loadingText: { color: colors.muted, fontSize: 14 },
});
