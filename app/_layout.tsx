import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useEffect } from "react";
import { I18nManager, KeyboardAvoidingView, Platform, StyleSheet, View } from "react-native";
import { SuccessNotice } from "@/components/app-ui";
import { StudentStoreProvider, useStudentStore } from "@/lib/student-store";
import { appTheme } from "@/lib/theme";

// الإعداد العام المكافئ لـ locale: const Locale("ar", "AE") في Flutter.
I18nManager.allowRTL(true);
I18nManager.forceRTL(true);

export default function RootLayout() {
  useEffect(() => {
    if (Platform.OS !== "web" || typeof document === "undefined") return;
    document.documentElement.dir = "rtl";
    document.documentElement.lang = "ar-AE";
    document.body.dir = "rtl";
    document.body.lang = "ar-AE";

    return () => {
      document.documentElement.dir = "ltr";
      document.documentElement.lang = "en-US";
      document.body.dir = "ltr";
      document.body.lang = "en-US";
    };
  }, []);

  return (
    <StudentStoreProvider>
      <KeyboardAvoidingView style={styles.root} behavior={Platform.select({ ios: "padding", android: "height" })}>
        <View style={styles.rtlShell}>
          <StatusBar style="dark" />
          <Stack screenOptions={{ headerShown: false, animation: "slide_from_left" }}>
            <Stack.Screen name="(tabs)" />
            <Stack.Screen name="classes" />
            <Stack.Screen name="import-students" />
            <Stack.Screen name="student/[id]" />
          </Stack>
          <SaveFeedback />
        </View>
      </KeyboardAvoidingView>
    </StudentStoreProvider>
  );
}

function SaveFeedback() {
  const { successMessage, clearSuccess } = useStudentStore();

  useEffect(() => {
    if (!successMessage) return;
    const timer = setTimeout(clearSuccess, 3200);
    return () => clearTimeout(timer);
  }, [clearSuccess, successMessage]);

  return successMessage ? (
    <View pointerEvents="none" style={styles.feedback}>
      <SuccessNotice message={successMessage} />
    </View>
  ) : null;
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: appTheme.colors.background },
  rtlShell: { flex: 1, backgroundColor: appTheme.colors.background },
  feedback: { position: "absolute", top: 56, left: 20, right: 20, zIndex: 1000, elevation: 20 },
});
