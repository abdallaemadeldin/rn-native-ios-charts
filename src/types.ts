import type { ColorValue, ViewStyle } from "react-native";

/* ────────────────────────── Data ────────────────────────── */

export type DataPoint = {
  /** Categorical or stringified-numeric x value. */
  x: string;
  /** Primary numeric value. */
  y: number;
  /** Second value, used by range bars and rectangle marks. */
  yEnd?: number;
  /**
   * Optional series/group key. When set, SwiftUI Charts auto-colors
   * by this value (so the legend stays consistent across marks).
   */
  category?: string;
  /** Per-point color override. Beats mark-level color when both set. */
  color?: ColorValue;
};

/* ────────────────────────── Mark types ────────────────────────── */

export type Interpolation =
  | "linear"
  | "catmullRom"
  | "monotone"
  | "stepStart"
  | "stepEnd"
  | "stepCenter";

export type Symbol =
  | "circle"
  | "square"
  | "triangle"
  | "diamond"
  | "pentagon"
  | "plus"
  | "cross"
  | "asterisk";

export type LineCap = "butt" | "round" | "square";

export type GradientStop = {
  /** Position along the gradient, 0–1. */
  offset: number;
  /** Stop color. Defaults to the mark's `color` when omitted. */
  color?: ColorValue;
  /** Multiplied with the stop's color alpha. 0 = transparent. */
  opacity?: number;
};

export type Gradient = {
  kind?: "linear";
  /** Linear gradient start point in unit coords. Default top: { x: 0.5, y: 0 }. */
  startX?: number;
  startY?: number;
  /** Linear gradient end point in unit coords. Default bottom: { x: 0.5, y: 1 }. */
  endX?: number;
  endY?: number;
  /** Two-stop shorthand — used when `stops` is empty. Default 0.35. */
  startOpacity?: number;
  /** Two-stop shorthand — used when `stops` is empty. Default 0.02. */
  endOpacity?: number;
  /** Explicit stops. Overrides the two-stop shorthand. */
  stops?: GradientStop[];
};

export type MarkType =
  | "bar"
  | "line"
  | "area"
  | "point"
  | "rectangle"
  | "rule"
  | "sector";

export type Mark = {
  type: MarkType;
  data: DataPoint[];

  /** Solid fill color. Falls back to system accent if neither this nor `gradient` is set. */
  color?: ColorValue;
  /** Multiplier on the resolved fill alpha. 0–1. Default 1. */
  opacity?: number;
  /**
   * Gradient fill. Wins over solid `color`. Most useful on `area`
   * marks for the standard "shaded under the curve" look.
   */
  gradient?: Gradient;

  // ─── Stroke (line / rule) ───
  lineWidth?: number;
  /** Dash pattern in pt. Empty = solid line. */
  dashArray?: number[];
  lineCap?: LineCap;

  // ─── Line / area interpolation ───
  interpolation?: Interpolation;

  // ─── Symbol marks ───
  symbol?: Symbol;
  symbolSize?: number;
  /** When set on a `line` mark, also draws point symbols at each datum. */
  showPoints?: boolean;

  // ─── Bar / rectangle ───
  cornerRadius?: number;
  /** Fixed bar width in pt. 0 = auto. */
  barWidth?: number;

  // ─── Sector (pie / donut) ───
  /** Donut hole ratio, 0–1. 0 = full pie, 0.62 = thin donut. */
  innerRadius?: number;
  /** Outer radius ratio, 0–1. 0 = auto-fill. */
  outerRadius?: number;
  /** Gap between adjacent sectors in pt. */
  angularInset?: number;

  // ─── Rule mark ───
  orientation?: "horizontal" | "vertical";
  /** Constant value the rule draws at. With this set, `data` can be empty. */
  ruleValue?: number;
};

/* ────────────────────────── Chart-level config ────────────────────────── */

export type AxisConfig = {
  hidden?: boolean;
  gridLines?: boolean;
  tickLabels?: boolean;
  labelColor?: ColorValue;
  gridColor?: ColorValue;
  labelFontSize?: number;
  /** Numeric domain. Both must be set to take effect. */
  domainMin?: number;
  domainMax?: number;
};

export type LegendConfig = {
  hidden?: boolean;
  placement?:
    | "automatic"
    | "top"
    | "bottom"
    | "leading"
    | "trailing"
    | "overlay";
};

export type CenterLabel = {
  value?: string;
  label?: string;
  valueColor?: ColorValue;
  labelColor?: ColorValue;
  valueFontSize?: number;
  labelFontSize?: number;
};

/**
 * Interactive tooltip config. Drives SwiftUI Charts' native
 * `chartXSelection` — the scrubber snaps to the nearest data point
 * automatically and the callout is drawn inside the plot frame.
 *
 * For pie / sector marks, only the `onSelect` event fires (no
 * built-in visual callout) — use the event to drive a `centerLabel`.
 */
export type TooltipConfig = {
  enabled?: boolean;
  /** Vertical dashed rule at the selected X. Default true. */
  showRule?: boolean;
  /** Filled dot at the selected point. Default true. */
  showDot?: boolean;
  /** Show the x label above the y value in the callout. Default true. */
  showTitle?: boolean;
  backgroundColor?: ColorValue;
  textColor?: ColorValue;
  borderColor?: ColorValue;
  /** Decimal places for the y value. Default 0. */
  valueDecimals?: number;
  /** Prepended to the y value, e.g. "$". */
  valuePrefix?: string;
  /** Appended to the y value, e.g. "%". */
  valueSuffix?: string;
};

/** Payload emitted by `onSelect`. `null` when the selection is cleared. */
export type SelectedPoint = { x: string; y: number } | null;

export type ChartProps = {
  /** One or more marks to render. Mix freely (e.g. area + line + points). */
  marks: Mark[];
  xAxis?: AxisConfig;
  yAxis?: AxisConfig;
  legend?: LegendConfig;
  /**
   * Center label rendered inside the chart's plot frame (via
   * SwiftUI's `chartBackground`). Tracks the plot center natively —
   * works especially well with `sector` marks for donut center text.
   */
  centerLabel?: CenterLabel;
  /**
   * Interactive tooltip overlay. Defaults to disabled so charts stay
   * static unless you opt in. Enable by passing `{ enabled: true }`.
   */
  tooltip?: TooltipConfig;
  /**
   * Fires when the user picks a point via the scrubber, or taps a
   * pie sector. Receives `null` when selection clears.
   */
  onSelect?: (point: SelectedPoint) => void;
  animate?: boolean;
  style?: ViewStyle;
};
