export const appTheme = {
  colors: {
    primary: "#1769D1",
    primaryDark: "#12355B",
    primarySurface: "#DCEBFF",
    background: "#F4F7FB",
    surface: "#FBFCFF",
    ink: "#102A43",
    muted: "#52677F",
    border: "#C9D6E3",
    success: "#087A50",
    successSurface: "#DDF5E9",
    warning: "#A85E00",
    danger: "#B4232D",
    dangerSurface: "#FCE5E7",
    overlay: "rgba(12, 32, 55, 0.44)",
  },
  splashColor: "rgba(23, 105, 209, 0.18)",
  highlightColor: "rgba(23, 105, 209, 0.12)",
} as const;

export type AppTheme = typeof appTheme;
