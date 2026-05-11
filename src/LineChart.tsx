import * as React from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type {
  AxisConfig,
  DataPoint,
  Gradient,
  Interpolation,
  LegendConfig,
  Symbol,
} from "./types";

export type LinePoint = { x: string; y: number; category?: string };

export type LineChartProps = {
  data: LinePoint[];
  color?: ColorValue;
  lineWidth?: number;
  interpolation?: Interpolation;
  dashArray?: number[];
  /**
   * Set this to render a gradient-filled area beneath the line as
   * well — the standard "shaded line chart" pattern. Same shape as
   * the generic `Gradient`.
   */
  area?: Gradient | boolean;
  showPoints?: boolean;
  symbol?: Symbol;
  symbolSize?: number;
  xAxis?: AxisConfig;
  yAxis?: AxisConfig;
  legend?: LegendConfig;
  animate?: boolean;
  style?: ViewStyle;
};

export function LineChart({
  data,
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
  animate,
  style,
}: LineChartProps) {
  const points: DataPoint[] = data.map((p) => ({
    x: p.x,
    y: p.y,
    category: p.category,
  }));

  const marks = [];

  // Render the area FIRST (so the line draws on top).
  if (area) {
    const gradient: Gradient =
      typeof area === "object" ? area : { startOpacity: 0.35, endOpacity: 0.02 };
    marks.push({
      type: "area" as const,
      data: points,
      color,
      gradient,
      interpolation,
    });
  }

  marks.push({
    type: "line" as const,
    data: points,
    color,
    lineWidth,
    dashArray,
    interpolation,
    showPoints,
    symbol,
    symbolSize,
  });

  return (
    <Chart
      style={style}
      animate={animate}
      xAxis={xAxis}
      yAxis={yAxis}
      legend={legend}
      marks={marks}
    />
  );
}
