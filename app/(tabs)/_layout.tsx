import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { Tabs } from "expo-router";
import { Platform } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { colors } from "@/components/app-ui";

const iconFor: Record<string, keyof typeof MaterialIcons.glyphMap> = { index: "space-dashboard", students: "groups", attendance: "fact-check", reports: "analytics", settings: "settings" };

export default function TabLayout() {
  const insets = useSafeAreaInsets();
  const bottom = Platform.OS === "web" ? 10 : Math.max(8, insets.bottom);
  return <Tabs screenOptions={({ route }) => ({ headerShown: false, tabBarActiveTintColor: colors.navy, tabBarInactiveTintColor: "#8795A8", tabBarStyle: { height: 58 + bottom, paddingTop: 7, paddingBottom: bottom, borderTopColor: colors.border, backgroundColor: colors.white }, tabBarLabelStyle: { fontSize: 10, fontWeight: "700" }, tabBarIcon: ({ color, size }) => <MaterialIcons name={iconFor[route.name] ?? "circle"} color={color} size={size} /> })}>
    <Tabs.Screen name="index" options={{ title: "الرئيسية" }} />
    <Tabs.Screen name="students" options={{ title: "الطلاب" }} />
    <Tabs.Screen name="attendance" options={{ title: "الحضور" }} />
    <Tabs.Screen name="reports" options={{ title: "التقارير" }} />
    <Tabs.Screen name="settings" options={{ title: "الإعدادات" }} />
  </Tabs>;
}
