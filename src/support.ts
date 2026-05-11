import { Platform } from "react-native";

/**
 * Runtime feature-detection helper. Returns true only on devices
 * that can actually render the charts — iOS 17 and above. Use it to
 * mount a fallback chart library (or a placeholder) on older iOS
 * versions and on Android / web:
 *
 * ```tsx
 * import { isChartSupported, LineChart } from "rn-native-ios-charts";
 * import { OtherLineChart } from "some-cross-platform-chart-lib";
 *
 * export function MyLineChart(props) {
 *   if (isChartSupported()) return <LineChart {...props} />;
 *   return <OtherLineChart {...props} />;
 * }
 * ```
 *
 * The check is cheap (a parse of `Platform.Version`) and stable
 * across the lifetime of the process — safe to call inline in render.
 */
export function isChartSupported(): boolean {
  if (Platform.OS !== "ios") return false;
  // Platform.Version on iOS is a string like "17.4". Parsing the
  // leading integer is enough; SwiftUI Charts' unified API
  // (`Chart {}`, `SectorMark`, `chartBackground`,
  // `chartXSelection`) all became available in iOS 17.0.
  const major = parseInt(String(Platform.Version), 10);
  return Number.isFinite(major) && major >= 17;
}
