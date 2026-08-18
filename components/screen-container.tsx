import { StyleSheet, View, type ViewProps } from "react-native";
import { SafeAreaView, type Edge } from "react-native-safe-area-context";

import { colors } from "@/components/app-ui";

export interface ScreenContainerProps extends ViewProps {
  /** SafeArea edges to apply. Bottom is typically handled by the tab bar. */
  edges?: Edge[];
}

export function ScreenContainer({
  children,
  edges = ["top", "left", "right"],
  style,
  ...props
}: ScreenContainerProps) {
  return (
    <View style={styles.background} {...props}>
      <SafeAreaView edges={edges} style={styles.safeArea}>
        <View style={[styles.content, style]}>{children}</View>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
    backgroundColor: colors.pale,
    writingDirection: "rtl",
  },
  safeArea: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
  },
});
