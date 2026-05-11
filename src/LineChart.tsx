import * as React from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type {
  AxisConfig,
  DataPoint,
  Gradient,
  Interpolation,
  LegendConfig,
  Mark,
  SelectedPoint,
  Symbol,
  TooltipConfig,
} from "./types";

export type LinePoint = {
  x: string;
  y: number;
  category?: string;
  /** Per-point color override. */
  color?: ColorValue;
};

/**
 * One series in a multi-line chart. Pass an array of these as
 * `<LineChart series={...} />` to draw multiple lines on the same
 * plot — each series gets its own stroke + (optional) area fill.
 *
 * Per-series fields fall back to the chart-level value when omitted:
 * `lineWidth`, `dashArray`, `interpolation`, `showPoints`, `symbol`,
 * `symbolSize`, `area`.
 */
export type LineSeries = {
  /** Series name — used as the `category` key, the legend label,
   *  and the row label in the multi-series tooltip. */
  name: string;
  data: { x: string; y: number }[];
  color?: ColorValue;
  lineWidth?: number;
  dashArray?: number[];
  interpolation?: Interpolation;
  showPoints?: boolean;
  symbol?: Symbol;
  symbolSize?: number;
  /** Area fill under this series. Same shape as the chart-level prop. */
  area?: Gradient | boolean;
};

export type LineChartProps = {
  /**
   * Single-series data. Mutually exclusive with `series` — if both
   * are passed, `series` wins.
   */
  data?: LinePoint[];
  /**
   * Multi-series data — each entry renders as its own line on the
   * same plot. Pair with `tooltip={{ multiSeries: true }}` for a
   * stacked-row tooltip showing every series at the active X.
   */
  series?: LineSeries[];
  /** Chart-level default stroke color. Per-series `color` overrides. */
  color?: ColorValue;
  lineWidth?: number;
  interpolation?: Interpolation;
  dashArray?: number[];
  /**
   * Chart-level area fill. Applied to every line that doesn't
   * specify its own `area`. Same shape as the generic `Gradient`.
   */
  area?: Gradient | boolean;
  showPoints?: boolean;
  symbol?: Symbol;
  symbolSize?: number;
  xAxis?: AxisConfig;
  yAxis?: AxisConfig;
  legend?: LegendConfig;
  tooltip?: TooltipConfig;
  onSelect?: (point: SelectedPoint) => void;
  scrollableX?: boolean;
  visibleXCount?: number;
  tightX?: boolean;
  /** Custom category → color palette. Useful when `series` is set. */
  categoryColors?: Record<string, ColorValue>;
  animate?: boolean;
  style?: ViewStyle;
};

export function LineChart({
  data,
  series,
  color,
  lineWidth = 2.5,
  interpolation = "catmullRom",
  dashArray,
  area,
  showPoints,
  symbol,
  symbolSize,
  xAxis,
  yAxis,
  legend,
  tooltip,
  onSelect,
  scrollableX,
  visibleXCount,
  tightX,
  categoryColors,
  animate,
  style,
}: LineChartProps) {
  const marks: Mark[] = [];

  if (series && series.length > 0) {
    // Multi-series path. Each series produces (optionally) an area
    // mark + a line mark. The series' `name` is set on every point's
    // `category` so SwiftUI groups them correctly and the multi-
    // series tooltip can label each row.
    for (const s of series) {
      const points: DataPoint[] = s.data.map((p) => ({
        x: p.x,
        y: p.y,
        category: s.name,
      }));
      const seriesArea = s.area ?? area;
      if (seriesArea) {
        const gradient: Gradient =
          typeof seriesArea === "object"
            ? seriesArea
            : { startOpacity: 0.35, endOpacity: 0.02 };
        marks.push({
          type: "area",
          data: points,
          color: s.color ?? color,
          gradient,
          interpolation: s.interpolation ?? interpolation,
        });
      }
      marks.push({
        type: "line",
        data: points,
        color: s.color ?? color,
        lineWidth: s.lineWidth ?? lineWidth,
        dashArray: s.dashArray ?? dashArray,
        interpolation: s.interpolation ?? interpolation,
        showPoints: s.showPoints ?? showPoints,
        symbol: s.symbol ?? symbol,
        symbolSize: s.symbolSize ?? symbolSize,
      });
    }
  } else {
    // Single-series path — preserves v0.1 behavior so existing code
    // upgrades without changes.
    const points: DataPoint[] = (data ?? []).map((p) => ({
      x: p.x,
      y: p.y,
      category: p.category,
      color: p.color,
    }));

    if (area) {
      const gradient: Gradient =
        typeof area === "object"
          ? area
          : { startOpacity: 0.35, endOpacity: 0.02 };
      marks.push({
        type: "area",
        data: points,
        color,
        gradient,
        interpolation,
      });
    }

    marks.push({
      type: "line",
      data: points,
      color,
      lineWidth,
      dashArray,
      interpolation,
      showPoints,
      symbol,
      symbolSize,
    });
  }

  return (
    <Chart
      style={style}
      animate={animate}
      xAxis={xAxis}
      yAxis={yAxis}
      legend={legend}
      tooltip={tooltip}
      onSelect={onSelect}
      scrollableX={scrollableX}
      visibleXCount={visibleXCount}
      tightX={tightX}
      categoryColors={categoryColors}
      marks={marks}
    />
  );
}
