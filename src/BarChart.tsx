import * as React from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type { AxisConfig, DataPoint, LegendConfig } from "./types";

export type BarDatum = {
  x: string;
  y: number;
  /** Optional series key for grouped / colored bars. */
  category?: string;
  color?: ColorValue;
};

export type BarChartProps = {
  data: BarDatum[];
  color?: ColorValue;
  cornerRadius?: number;
  /** Fixed width per bar in pt. 0 = auto. */
  barWidth?: number;
  xAxis?: AxisConfig;
  yAxis?: AxisConfig;
  legend?: LegendConfig;
  animate?: boolean;
  style?: ViewStyle;
};

export function BarChart({
  data,
  color,
  cornerRadius = 4,
  barWidth,
  xAxis,
  yAxis,
  legend,
  animate,
  style,
}: BarChartProps) {
  const points: DataPoint[] = data.map((d) => ({
    x: d.x,
    y: d.y,
    category: d.category,
    color: d.color,
  }));
  return (
    <Chart
      style={style}
      animate={animate}
      xAxis={xAxis}
      yAxis={yAxis}
      legend={legend}
      marks={[
        {
          type: "bar",
          data: points,
          color,
          cornerRadius,
          barWidth,
        },
      ]}
    />
  );
}
