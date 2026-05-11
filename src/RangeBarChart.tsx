import * as React from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type { AxisConfig, DataPoint, LegendConfig } from "./types";

export type RangeDatum = {
  x: string;
  yStart: number;
  yEnd: number;
  category?: string;
  color?: ColorValue;
};

export type RangeBarChartProps = {
  data: RangeDatum[];
  color?: ColorValue;
  cornerRadius?: number;
  xAxis?: AxisConfig;
  yAxis?: AxisConfig;
  legend?: LegendConfig;
  animate?: boolean;
  style?: ViewStyle;
};

/**
 * Range bars — drawn as `RectangleMark` between `yStart` and `yEnd`.
 * Use for candlestick / OHLC visualisations, Gantt-style timelines,
 * or low/high bands.
 */
export function RangeBarChart({
  data,
  color,
  cornerRadius = 2,
  xAxis,
  yAxis,
  legend,
  animate,
  style,
}: RangeBarChartProps) {
  const points: DataPoint[] = data.map((d) => ({
    x: d.x,
    y: d.yStart,
    yEnd: d.yEnd,
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
          type: "rectangle",
          data: points,
          color,
          cornerRadius,
        },
      ]}
    />
  );
}
