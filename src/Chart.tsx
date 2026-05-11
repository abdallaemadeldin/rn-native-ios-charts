import { requireNativeView } from "expo";
import * as React from "react";
import { Platform, View } from "react-native";
import type { ChartProps } from "./types";

/**
 * Generic SwiftUI Charts view. Render any combination of bar / line /
 * area / point / rectangle / rule / sector marks by passing them in
 * the `marks` array. iOS-only — on other platforms this is a no-op
 * placeholder `View`, so consuming code can mount it unconditionally
 * and feature-detect via `Platform.OS`.
 *
 * Use the convenience wrappers (`PieChart`, `LineChart`, `BarChart`,
 * etc.) for common single-mark cases — they all delegate here.
 */
const NativeChart =
  Platform.OS === "ios"
    ? requireNativeView<ChartProps>("NativeIosCharts", "ChartView")
    : null;

export function Chart(props: ChartProps) {
  if (!NativeChart) {
    return <View style={props.style} />;
  }
  return <NativeChart {...props} />;
}
