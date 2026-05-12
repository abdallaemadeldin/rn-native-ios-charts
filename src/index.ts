// ── Runtime feature detection ──
export { isChartSupported } from "./support";

// ── Generic chart (any combination of marks) ──
export { Chart } from "./Chart";

// ── Shared imperative-ref handle for every wrapper ──
export type { ChartHandle } from "./useChartHandle";
export { useChartHandle } from "./useChartHandle";

// ── Scroll-driven scale wrapper (requires react-native-reanimated) ──
//    Importing this entrypoint pulls in react-native-reanimated.
//    If the consumer's app doesn't have it installed, they'll get
//    a clear module-not-found at the import site rather than at
//    runtime — see CHANGELOG / README for the install + Info.plist
//    setup needed for ProMotion 120Hz.
export { ScrollAwareChart } from "./ScrollAwareChart";
export type { ScrollAwareChartProps } from "./ScrollAwareChart";
export { useChartScrollScale } from "./useChartScrollScale";
export type {
  ChartScrollScaleOptions,
  ChartScrollScaleResult,
} from "./useChartScrollScale";

// ── Convenience wrappers for the common single-mark cases ──
export { PieChart } from "./PieChart";
export type {
  PieChartHandle,
  PieChartProps,
  PieSlice,
} from "./PieChart";

export { LineChart } from "./LineChart";
export type { LineChartProps, LinePoint, LineSeries } from "./LineChart";

export { AreaChart } from "./AreaChart";
export type { AreaChartProps, AreaDatum } from "./AreaChart";

export { BarChart } from "./BarChart";
export type { BarChartProps, BarDatum } from "./BarChart";

export { ScatterChart } from "./ScatterChart";
export type { ScatterChartProps, ScatterDatum } from "./ScatterChart";

export { RangeBarChart } from "./RangeBarChart";
export type { RangeBarChartProps, RangeDatum } from "./RangeBarChart";

// ── Public types — use these to assemble your own marks for the
//    generic `<Chart>` component or to type-share data across screens.
export type {
  AnimationConfig,
  Annotation,
  AxisConfig,
  CenterLabel,
  ChartProps,
  DataPoint,
  Gradient,
  GradientStop,
  Interpolation,
  LegendConfig,
  LineCap,
  Mark,
  MarkType,
  SelectedPoint,
  Symbol,
  TooltipConfig,
} from "./types";
