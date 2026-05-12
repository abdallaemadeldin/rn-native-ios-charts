import type { ColorValue, ViewStyle } from "react-native";

/* ────────────────────────── Data ────────────────────────── */

export type DataPoint = {
  /**
   * X value. Three accepted shapes:
   *   - **string** — categorical or stringified-numeric ("Q1", "2024", "AAPL")
   *   - **Date** — time-series; serialized to ISO 8601 on the bridge.
   *     Pair with `xAxis.valueFormat: "date"` and `xAxis.dateFormat`
   *     (default "MMM yy") for nicely formatted tick labels.
   *
   * Internally the chart always normalizes to a categorical string
   * axis — Date input gives you ISO-precision sorting + per-locale
   * tick label formatting without changing the chart's scale model.
   * True Date-domain axes (auto month/year tick aggregation, etc.)
   * are on the roadmap for a follow-up release.
   */
  x: string | Date;
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
  /**
   * Bar positioning when multiple bar marks share an X category:
   *   - "auto"    — SwiftUI's default
   *   - "stacked" — explicit stacking
   *   - "grouped" — side-by-side via `position(by: category)`
   * Only meaningful for `bar` marks.
   */
  position?: "auto" | "stacked" | "grouped";
  /**
   * Horizontal bars — swaps the X and Y axes for `bar` marks. Use
   * for Top-N lists / ranked leaderboards.
   */
  horizontal?: boolean;

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
  /**
   * Scale type. Default `"linear"`. `"log"` maps to SwiftUI's
   * `chartYScale(type: .log)` — useful for long-horizon growth
   * charts where linear flattens the early years. Y-only for now;
   * `xAxis.scaleType` is accepted but ignored (X is categorical or
   * date-stringly-typed in this release).
   *
   * Caveat: log scales require all values strictly > 0. Pass a
   * positive `domainMin` to clip outliers if your data contains
   * zeros or negatives.
   */
  scaleType?: "linear" | "log";

  /* ────── Value formatters ────── */

  /**
   * Format style for axis tick labels:
   *   - "raw" (default) — `value.toLocaleString()` with `valueDecimals`
   *   - "currency"      — locale-aware, uses `currencyCode`
   *   - "percent"       — SwiftUI multiplies by 100 (pass 0.5 → "50%")
   *   - "abbreviated"   — "1K", "1.2M", "3.4B"
   *   - "decimal"       — plain number, `valueDecimals` fraction digits
   *   - "date"          — parses ISO-8601 X strings as dates and
   *                       formats with `dateFormat` (default "MMM yy",
   *                       e.g. "Jan 26"). Use when you've passed
   *                       `Date` objects as `x` values.
   */
  valueFormat?:
    | "raw"
    | "currency"
    | "percent"
    | "abbreviated"
    | "decimal"
    | "date";
  /** Used when `valueFormat: "currency"`. Default "USD". */
  currencyCode?: string;
  /** Fraction digits for formatters that respect it. Default 0. */
  valueDecimals?: number;
  /** Prepended to the formatted value, e.g. "$" or "≈ ". */
  valuePrefix?: string;
  /** Appended to the formatted value, e.g. "%" or " yrs". */
  valueSuffix?: string;
  /**
   * Date format string for `valueFormat: "date"`. Uses Apple's
   * `DateFormatter` format syntax (UTS #35 / Unicode date format).
   *   - "MMM yy"     → "Jan 26"            (default)
   *   - "MMM d"      → "Jan 15"            (day-of-month)
   *   - "yyyy"       → "2026"
   *   - "MMM d, yyyy"→ "Jan 15, 2026"
   *   - "HH:mm"      → "14:30"             (intraday)
   *
   * See https://nsdateformatter.com for a live preview.
   */
  dateFormat?: string;
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
  /**
   * Render one row per cartesian mark at the selected X (color dot +
   * series name + value). When the chart has only one mark, behaves
   * the same as the single-series tooltip. Default false. Useful for
   * OHLC stock charts and series comparisons.
   */
  multiSeries?: boolean;
  backgroundColor?: ColorValue;
  textColor?: ColorValue;
  borderColor?: ColorValue;
  /** Decimal places for the y value. Default 0. */
  valueDecimals?: number;
  /** Prepended to the y value, e.g. "$". */
  valuePrefix?: string;
  /** Appended to the y value, e.g. "%". */
  valueSuffix?: string;
  /**
   * Opacity applied to non-selected slices (pie / donut) while
   * another slice is selected. 0–1. Default 0.3.
   *
   * Engages on any selection, including taps that only fire
   * `onSelect` — `tooltip.enabled` is NOT required. (`enabled`
   * controls the leader-line + callout overlay, not the slice
   * dim/scale.) So a `DonutCard`-style UI that drives its own
   * center label gets the "tap a slice, others fade" feedback for
   * free.
   *
   * Cartesian charts use `animation.cartesianDimOnSelect` for the
   * equivalent behavior — see that field.
   */
  dimOpacity?: number;
  /**
   * Pie / donut only. Scale factor applied to the selected slice
   * relative to the others. Achieved by shrinking the unselected
   * slices in tandem so the selected one appears to bump outward —
   * which means there's no overflow past the chart frame. Default
   * 1.05.
   *
   * Same engagement rule as `dimOpacity`: fires on any selection,
   * regardless of `tooltip.enabled`.
   */
  sliceScale?: number;
};

/**
 * Payload emitted by `onSelect`. `null` when the selection is cleared.
 * `markIndex` and `pointIndex` locate the datum in the caller's
 * `marks` array deterministically — value-only matching is fragile
 * when multiple slices/points share the same y value.
 */
export type SelectedPoint =
  | { x: string; y: number; markIndex: number; pointIndex: number }
  | null;

/**
 * Chart-level animation config. Drives both the data-change
 * animation (when marks update) and the optional entrance animation
 * (when the chart first mounts). Supersedes the boolean `animate`
 * shorthand from v0.x — `animate: true` is still honored as a
 * legacy alias for `{ enabled: true }`.
 *
 * Selection animations (pie slice scale + dim, cartesian dim-on-
 * select) use a fixed spring tuned for tap feedback; they're not
 * driven by this config because per-tap snappiness shouldn't track
 * data-change duration.
 */
/**
 * Annotation on a chart. Two flavors:
 *
 *   - **Datum-anchored** — pass `x` (and optionally `yRange` to set
 *     vertical extent). Renders a text label at that X. Use for
 *     "Earnings", "Rate cut", "ATH" callouts on specific dates.
 *
 *   - **Range band** — pass `xRange: [from, to]`. Renders a shaded
 *     vertical band spanning that X range. Use for highlighting a
 *     quarter, a recession period, a hold-window. Optional `text`
 *     is centered inside the band.
 *
 * Annotations live outside `marks` so you can toggle commentary
 * without touching data. Pair with `xAxis.valueFormat: "date"` and
 * pass `Date` objects to `x` / `xRange` for time-series. The chart
 * does no auto-clamping — labels can extend slightly past the plot
 * frame.
 */
export type Annotation = {
  /** Datum-anchored x. Mutually exclusive with `xRange`. */
  x?: string | Date;
  /** Range-anchored start + end. Mutually exclusive with `x`. */
  xRange?: [string | Date, string | Date];
  /**
   * Optional vertical bounds in Y data coordinates. When omitted,
   * range bands fill the full plot height and datum labels float
   * near the top of the plot.
   */
  yRange?: [number, number];
  /** Text shown inside the band or at the datum. Optional. */
  text?: string;
  /** Fill color for bands, text color for labels. Defaults to system blue / label. */
  color?: ColorValue;
  /**
   * Where the label sits relative to its anchor. Default "top".
   *   - "top"    — above the band / data point
   *   - "bottom" — below
   *   - "inside" — centered (most useful for range bands)
   */
  position?: "top" | "bottom" | "inside";
  /** Label font size in pt. Default 11. */
  fontSize?: number;
};

export type AnimationConfig = {
  /** Master toggle. Default true. */
  enabled?: boolean;
  /**
   * Duration of data-change animations in milliseconds. Default 400.
   * Ignored when `curve === "spring"` (springs are timing-free).
   */
  duration?: number;
  /** Easing curve for data-change transitions. Default "easeInOut". */
  curve?: "easeInOut" | "easeIn" | "easeOut" | "linear" | "spring";
  /**
   * Entrance animation on first mount — fade in + scale from 0.96
   * to 1.0 over `duration` (capped at 600ms). Default false (opt-
   * in). Set true for a polished first-render feel.
   */
  entrance?: boolean;
  /**
   * For multi-series cartesian charts (line / bar / area / point):
   * when the scrubber tooltip is active, dim the non-active marks
   * to `tooltip.dimOpacity`. Mirrors the pie's slice-dim behavior
   * but for line charts. Default false. Pie ignores this — pies
   * always dim unselected slices whenever there's a selected
   * slice (see `TooltipConfig.dimOpacity` for the rule).
   */
  cartesianDimOnSelect?: boolean;
};

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
  /**
   * Enable native horizontal scrolling via SwiftUI's
   * `chartScrollableAxes(.horizontal)`. Better than wrapping the
   * chart in an RN `<ScrollView horizontal>` — keeps tooltip
   * coordinates correct and avoids scrubber gesture conflicts.
   */
  scrollableX?: boolean;
  /**
   * When `scrollableX` is true, caps how many X categories are
   * visible at once. Omit (or pass 0) to let SwiftUI auto-decide.
   * Maps to `chartXVisibleDomain(length:)`.
   */
  visibleXCount?: number;
  /**
   * Trading-chart X mode — removes SwiftUI Charts' default plot-
   * dimension padding so the first and last data points sit flush
   * against the chart's left and right edges. Pair with hidden
   * axes for the Robinhood / Apple Stocks look.
   */
  tightX?: boolean;
  /**
   * Maps a `point.category` string → fill color. Translates to
   * SwiftUI's `chartForegroundStyleScale`. Define your palette once
   * at the chart level instead of repeating `color` on every datum.
   * Empty (or omitted) falls back to SwiftUI's auto palette.
   */
  categoryColors?: Record<string, ColorValue>;
  /**
   * Legacy boolean shorthand. `animate: true` is equivalent to
   * `animation: { enabled: true }` with framework defaults; `false`
   * disables every animation including entrance + selection. When
   * both `animate` and `animation` are passed, `animation` takes
   * effect and `animate` is ignored.
   */
  animate?: boolean;
  /**
   * Full animation config. See `AnimationConfig`. Controls data-
   * change animations (curve, duration), the optional entrance
   * animation, and the cartesian dim-on-select toggle.
   */
  animation?: AnimationConfig;
  /**
   * Annotations overlayed on top of the marks — datum-anchored
   * labels or shaded range bands. Independent of `marks` so you
   * can toggle annotations without rebuilding data. See
   * `Annotation`.
   */
  annotations?: Annotation[];
  /**
   * Imperative clear-selection signal. The wrappers (e.g.
   * `PieChart`) drive this internally — increment to clear the
   * scrubber's `selectedX` and the pie's `selectedAngleY` on the
   * native side. Pair with `useImperativeHandle` to expose a
   * `clearSelection()` method to consumers.
   */
  clearSelectionToken?: number;
  style?: ViewStyle;
};
