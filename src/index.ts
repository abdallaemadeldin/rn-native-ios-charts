// ── Runtime feature detection ──
export { isChartSupported } from "./support";

// ── Generic chart (any combination of marks) ──
export { Chart } from "./Chart";

// ── Convenience wrappers for the common single-mark cases ──
export { PieChart } from "./PieChart";
export type { PieChartProps, PieSlice } from "./PieChart";

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
