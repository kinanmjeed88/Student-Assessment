import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { I18nManager } from "react-native";
import { StudentStoreProvider } from "@/lib/student-store";

I18nManager.allowRTL(true);
I18nManager.forceRTL(true);

export default function RootLayout() {
  return <StudentStoreProvider><StatusBar style="dark" /><Stack screenOptions={{ headerShown: false, animation: "slide_from_left" }}><Stack.Screen name="(tabs)" /><Stack.Screen name="classes" /><Stack.Screen name="student/[id]" /></Stack></StudentStoreProvider>;
}
